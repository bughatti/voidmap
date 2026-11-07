----------------------------------------------------------------------
-- Trails.lua — records where you walk, for VoidGPS's routes.
--
-- The world is cut into 10-yard cells per continent (world coordinates from
-- C_Map.GetWorldPosFromMapPos). Each cell you cross is stored with which of
-- its 8 neighbours you moved to or came from (a bitmask), so the data is a
-- walkable graph: a route can follow it around mountains and cliffs.
--   VoidMapDB.trails[continentID][cellKey] = neighbour bits
-- Not recorded: instances, taxis, vehicles, flying, ghosts (they walk on
-- water), and jumps faster than you can move (boats, zeppelins, teleports,
-- knockbacks) — those break the line instead of joining it.
-- Account-wide: every character's walking adds to the same network.
----------------------------------------------------------------------
local _, ns = ...
local M = ns.M
local T = {}
ns.Trails = T

local CELL = 10          -- yards
local OFF, MUL = 32768, 65536
local SAMPLE = 0.5       -- seconds

-- neighbour (dx, dy) -> bit
local BIT = {}
do
    local b = 1
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then BIT[dx .. "," .. dy] = b; b = b * 2 end
        end
    end
end

local function key(cx, cy) return (cx + OFF) * MUL + (cy + OFF) end
function T.Decode(k) return math.floor(k / MUL) - OFF, (k % MUL) - OFF end
T.CELL = CELL

local counts = {}   -- continent -> cells (counted once, then kept up to date)
local last          -- { cont, cx, cy, x, y, t }

local function store(cont)
    VoidMapDB.trails = VoidMapDB.trails or {}
    local s = VoidMapDB.trails[cont]
    if not s then s = {}; VoidMapDB.trails[cont] = s end
    if not counts[cont] then
        local n = 0
        for _ in pairs(s) do n = n + 1 end
        counts[cont] = n
    end
    return s
end

local function link(s, cont, ax, ay, bx, by)
    local ka, kb = key(ax, ay), key(bx, by)
    if s[ka] == nil then counts[cont] = counts[cont] + 1; s[ka] = 0 end
    if s[kb] == nil then counts[cont] = counts[cont] + 1; s[kb] = 0 end
    local ab, ba = BIT[(bx - ax) .. "," .. (by - ay)], BIT[(ax - bx) .. "," .. (ay - by)]
    if ab then s[ka] = bit.bor(s[ka], ab) end
    if ba then s[kb] = bit.bor(s[kb], ba) end
end

-- The cells the straight line (x0, y0) -> (x1, y1) really crosses, in order, each
-- linked to the next (grid traversal; a diagonal step only when it passes a corner).
local function walk(s, cont, x0, y0, x1, y1)
    local cx, cy = math.floor(x0 / CELL), math.floor(y0 / CELL)
    local ex, ey = math.floor(x1 / CELL), math.floor(y1 / CELL)
    local dx, dy = x1 - x0, y1 - y0
    local stepX = dx > 0 and 1 or (dx < 0 and -1 or 0)
    local stepY = dy > 0 and 1 or (dy < 0 and -1 or 0)
    local huge = math.huge
    local tMaxX = stepX == 0 and huge or ((stepX > 0 and ((cx + 1) * CELL - x0) or (x0 - cx * CELL)) / math.abs(dx))
    local tMaxY = stepY == 0 and huge or ((stepY > 0 and ((cy + 1) * CELL - y0) or (y0 - cy * CELL)) / math.abs(dy))
    local tDeltaX = stepX == 0 and huge or CELL / math.abs(dx)
    local tDeltaY = stepY == 0 and huge or CELL / math.abs(dy)
    local guard = 0
    while (cx ~= ex or cy ~= ey) and guard < 64 do
        guard = guard + 1
        local nx, ny = cx, cy
        if tMaxX < tMaxY then
            nx = cx + stepX; tMaxX = tMaxX + tDeltaX
        elseif tMaxY < tMaxX then
            ny = cy + stepY; tMaxY = tMaxY + tDeltaY
        else
            nx, ny = cx + stepX, cy + stepY
            tMaxX, tMaxY = tMaxX + tDeltaX, tMaxY + tDeltaY
        end
        link(s, cont, cx, cy, nx, ny)
        cx, cy = nx, ny
    end
end

local function canRecord()
    if not M:Config().trails then return false end
    if IsInInstance() then return false end
    if UnitOnTaxi("player") or UnitInVehicle("player") then return false end
    if IsFlying and IsFlying() then return false end
    if UnitIsGhost("player") then return false end
    return true
end

local function worldPos()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local px, py = pos:GetXY()
    if issecretvalue and (issecretvalue(px) or issecretvalue(py)) then return nil end
    if not px or (px == 0 and py == 0) then return nil end
    local ok2, cont, wp = pcall(C_Map.GetWorldPosFromMapPos, mapID, pos)
    if not ok2 or not cont or not wp then return nil end
    return cont, wp.x, wp.y
end

----------------------------------------------------------------------
-- Boat and zeppelin rides, learned: standing still while the position keeps moving
-- is a ride. Where it started (the dock or tower you boarded at) and where you walk
-- off become a link VoidGPS can route through:
--   VoidMapDB.links = { { a = {c, x, y}, b = {c, x, y}, n = times ridden }, ... }
-- A ride shorter than 20 s or under 300 yards (elevators, carts) isn't saved;
-- one-jump teleports (hearthstone, portals) never start one.
----------------------------------------------------------------------
local ride   -- { c, x, y, t, moved }

local function near(p, c, x, y) return p.c == c and (p.x - x) ^ 2 + (p.y - y) ^ 2 < 120 * 120 end

local function endRide(cont, x, y, now)
    local r = ride
    ride = nil
    if not r or now - r.t < 20 then return end
    if cont == r.c and (x - r.x) ^ 2 + (y - r.y) ^ 2 < 300 * 300 then return end
    VoidMapDB.links = VoidMapDB.links or {}
    for _, l in ipairs(VoidMapDB.links) do
        if near(l.a, r.c, r.x, r.y) and near(l.b, cont, x, y) then
            l.n = (l.n or 1) + 1
            return
        end
    end
    table.insert(VoidMapDB.links, { a = { c = r.c, x = r.x, y = r.y }, b = { c = cont, x = x, y = y }, n = 1, t = time() })
end

local function sample()
    if not canRecord() then last = nil; return end
    local cont, x, y = worldPos()
    if not cont then last = nil; return end   -- (a loading screen mid-ride keeps the ride)
    local now = GetTime()
    local speed = GetUnitSpeed("player") or 0
    -- the game can hand back a secret speed (seen 2026-11-07, 1,668 errors while fighting):
    -- no speed means no way to tell walking from a ride, so skip it and restart the line after
    if issecretvalue and issecretvalue(speed) then last = nil; return end
    if ride and now - (ride.moved or ride.t) > 60 and speed == 0 then ride = nil end   -- wasn't a ride
    if last and last.cont == cont then
        -- speed between this sample and the previous one (both always updated together)
        local dt = now - last.t
        local d = math.sqrt((x - last.x) ^ 2 + (y - last.y) ^ 2)
        -- moved faster than the character can: transport, teleport or knockback -> break the line
        -- (standing still while the position moves = riding a boat or zeppelin)
        local jumped = (dt > 0 and d / dt > math.max(speed, 7) * 1.6 + 4) or (speed == 0 and d > 3)
        local carried = speed == 0 and d > 3 and d < 60
        if carried and not ride then ride = { c = cont, x = last.x, y = last.y, t = now } end
        if ride then
            if jumped then
                ride.moved = now
            elseif speed > 0 and now - (ride.moved or ride.t) > 1.5 then
                endRide(cont, x, y, now)   -- walking off: the ride ended here
            end
        end
        if not jumped and not ride and (math.floor(x / CELL) ~= math.floor(last.x / CELL) or math.floor(y / CELL) ~= math.floor(last.y / CELL)) then
            walk(store(cont), cont, last.x, last.y, x, y)
        end
    else
        if ride then ride.moved = now end   -- arrived on another continent mid-ride
        store(cont)
    end
    last = { cont = cont, x = x, y = y, t = now }
end

----------------------------------------------------------------------
-- For VoidGPS (VoidMap.Trails): the walked graph and the learned rides.
----------------------------------------------------------------------
-- The 8 neighbours as { dx, dy, bit }.
T.DIRS = {}
for dy = -1, 1 do
    for dx = -1, 1 do
        local b = BIT[dx .. "," .. dy]
        if b then T.DIRS[#T.DIRS + 1] = { dx, dy, b } end
    end
end
T.Key = key
function T:Graph(cont) return VoidMapDB and VoidMapDB.trails and VoidMapDB.trails[cont] end
function T:Links() return VoidMapDB and VoidMapDB.links or {} end
M.Trails = T

function T:Count(cont)
    if cont then store(cont); return counts[cont] or 0 end
    local n = 0
    for c in pairs(VoidMapDB.trails or {}) do store(c); n = n + (counts[c] or 0) end
    return n
end

function T:Status()
    if not M:Config().trails then return "Trail recording off" end
    local n = self:Count()
    local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
    return ("Trails: %s spots walked"):format(s)
end

M:OnReady(function()
    C_Timer.NewTicker(SAMPLE, sample)
end)
