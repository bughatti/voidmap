----------------------------------------------------------------------
-- PinGuard.lua — no "Interface action failed" from map pins in combat.
--
-- Placing a pin, Blizzard's map calls pin:SetPassThroughButtons() (and, on some POI pins,
-- SetPropagateMouseClicks()). Both are blocked in combat when the code running is tainted, and
-- the world map's zoom state gets tainted for the whole session as soon as ANY addon changes the
-- map (WorldMapFrame:SetMapID from a quest list or a search box, a resize, a zoom button):
-- ResetZoom reads the old currentScale before writing the new one, so the taint never wears off.
-- Then opening the map in combat (M) or a quest update with the map open blocks once per pin,
-- named after whichever addon touched the map first (seen as VoidMap and VoidQuest, 2026-11).
--
-- Fix: in combat only, every pin a map pool hands out gets its own copy of those two methods that
-- only records what was asked. When combat ends the copies are removed (Blizzard's own methods
-- run as usual again) and the recorded settings are applied.
----------------------------------------------------------------------
local GUARDED = { "SetPassThroughButtons", "SetPropagateMouseClicks" }

local function realMethod(pin, m)
    local mt = getmetatable(pin)
    return mt and type(mt.__index) == "table" and mt.__index[m]
end

-- what Blizzard asked for in combat, applied when combat ends: pin -> { [method] = args }
local pending = {}

local guard = {}
for _, m in ipairs(GUARDED) do
    guard[m] = function(self, ...)
        if InCombatLockdown() then
            pending[self] = pending[self] or {}
            pending[self][m] = { n = select("#", ...), ... }
            return
        end
        local real = realMethod(self, m)
        if real then return real(self, ...) end
    end
end

local patched = {}   -- pin -> true while it carries the guards
local function patch(pin)
    if type(pin) ~= "table" or patched[pin] then return end
    for m, f in pairs(guard) do
        if pin[m] then pin[m] = f end
    end
    patched[pin] = true
end

local function unpatchAll()
    for pin in pairs(patched) do
        for m in pairs(guard) do pin[m] = nil end   -- back to the frame's own method
    end
    wipe(patched)
    -- now out of combat: give pins placed in combat the mouse settings Blizzard asked for
    for pin, calls in pairs(pending) do
        for m, a in pairs(calls) do
            local real = realMethod(pin, m)
            if real then pcall(real, pin, unpack(a, 1, a.n)) end
        end
    end
    wipe(pending)
end

-- every pool the map makes: guard pins as they are handed out. The map's pools are secure
-- proxies (CreateFramePool = CreateSecureFramePool) that expose Acquire / EnumerateActive but
-- not AddObject. A post-hook on Acquire runs before AcquirePin goes on to OnAcquired and
-- CheckMouseButtonPassthrough; it doesn't get the new pin, so it guards every active pin of
-- that pool that isn't guarded yet (a few dozen at most, and only in combat).
-- Limit: a pool made for the first time in combat misses its first pin: it is created inside
-- AcquirePin, before any add-on can reach it (Blizzard makes the common ones on the first map
-- open, normally out of combat).
local hooked = {}
local function hookPool(pool)
    if type(pool) ~= "table" or hooked[pool] or type(pool.Acquire) ~= "function"
        or type(pool.EnumerateActive) ~= "function" then return end
    hooked[pool] = true
    hooksecurefunc(pool, "Acquire", function(p)
        if not InCombatLockdown() then return end
        for pin in p:EnumerateActive() do patch(pin) end
    end)
end

local function setup()
    local W = WorldMapFrame
    if not (W and W.pinPools and W.AcquirePin) then return false end
    for _, pool in pairs(W.pinPools) do hookPool(pool) end
    -- a pool is made the first time a pin template is used: hook it right after
    hooksecurefunc(W, "AcquirePin", function(map, template)
        local pools = map.pinPools
        local pool = pools and pools[template]
        if pool and not hooked[pool] then hookPool(pool) end
    end)
    return true
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
local ready = false
ev:SetScript("OnEvent", function(_, event)
    if not ready then ready = setup() end
    if event == "PLAYER_REGEN_DISABLED" and ready then
        -- pools made since login without an AcquirePin we saw (defensive)
        for _, pool in pairs(WorldMapFrame.pinPools) do hookPool(pool) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        unpatchAll()
    end
end)
