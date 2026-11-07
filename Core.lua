----------------------------------------------------------------------
-- VoidMap — the world map in a Void window of our own.
--
-- The map engine stays Blizzard's (WorldMapFrame's canvas: the map picture,
-- zoom / pan, and every pin from Blizzard and from other addons). Everything
-- around it is ours: window, title bar, World / Continent / Zone navigation,
-- floor picker, zoom buttons, footer with coordinates, the quest list beside
-- the map (Quests.lua). Blizzard's filter and map-pin buttons are kept, in our
-- toolbar and our style, so their menus work exactly as Blizzard's.
--
-- Trails.lua records where you walk (the path network VoidGPS will route on).
--
-- Settings are per character (CharSettings.lua); the window's spot and size and
-- the recorded trails are account-wide.
----------------------------------------------------------------------
local ADDON, ns = ...
VoidMap = VoidMap or {}   -- global: other Void addons (VoidGPS) look for it
local M = VoidMap
ns.M = M

M.DEFAULTS = {
    movable    = true,   -- drag the window by its title bar
    scale      = 1.0,    -- window scale
    mapAlpha   = 1.0,    -- the map picture and its pins
    questPanel = true,   -- our quest list beside the map
    coords     = true,   -- your and the cursor's coordinates in the footer
    big        = false,  -- big window (fills most of the screen)
    trails     = true,   -- record where you walk
}

ns.CharSettings.Register(ADDON, "VoidMapDB", { "config" }, { "config.geo" })

function M:Config() return VoidMapDB.config end

function M:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00c7ff[VoidMap]|r " .. tostring(msg))
end

local readyFns = {}
function M:OnReady(fn) readyFns[#readyFns + 1] = fn end

local started
local function start()
    if started or not WorldMapFrame then return end
    started = true
    for _, fn in ipairs(readyFns) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        VoidMapDB = VoidMapDB or {}
        VoidMapDB.config = VoidMapDB.config or {}
        local c = VoidMapDB.config
        for k, v in pairs(M.DEFAULTS) do
            if c[k] == nil then c[k] = v end
        end
        -- 0.1.0 keys
        c.scaleSmall, c.scaleBig, c.posSmall, c.posBig, c.showCoords, c.blackout = nil, nil, nil, nil, nil, nil
    elseif event == "ADDON_LOADED" and name == "Blizzard_WorldMap" then
        start()
    elseif event == "PLAYER_LOGIN" then
        start()   -- the world map is usually loaded by now
    end
end)

SLASH_VOIDMAP1 = "/vmap"
SlashCmdList.VOIDMAP = function()
    if ns.Settings then ns.Settings:Toggle() end
end
