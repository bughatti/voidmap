----------------------------------------------------------------------
-- Settings.lua — VoidMap's settings window.
--
-- Opened from the Settings button on the map's title bar, the Void hub icon by
-- the minimap, or /vmap. Same look as the other Void addons: dark panel,
-- cyan title bar, x or Esc to close, drag the title bar to move. Every
-- change shows on the map at once.
----------------------------------------------------------------------
-- Borders are one screen pixel (tools/cmd/pixelfix, 2026-11-09). WoW snaps each border
-- piece to the pixel grid, and a thin line on a fractional position can snap to 0 px: a side
-- of a box vanishes. VoidPX() asks for one real pixel, and the hook below (installed once, by
-- the first Void addon loaded) turns snapping off on the edges of flat WHITE8X8 borders, like
-- Blizzard's NineSliceUtil.DisableSharpening, so a 1 px line always covers a pixel. It also
-- moves the border 1/8 px up-left: a side sitting exactly on a pixel's middle (a box centred
-- in an odd-width window) covered no pixel and vanished (2026-11-12).
local function VoidPX()
    local s = UIParent and UIParent:GetEffectiveScale()
    if s and s > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor then return PixelUtil.GetPixelToUIUnitFactor() / s end
    return 1
end
if not _G.__VoidBorderHook2 and hooksecurefunc and NineSliceUtil and NineSliceUtil.ApplyLayout then
    _G.__VoidBorderHook2 = true
    local EDGES = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
                    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
    hooksecurefunc(NineSliceUtil, "ApplyLayout", function(c)
        local i = type(c) == "table" and c.backdropInfo
        local e = i and i.edgeFile
        if type(e) ~= "string" or not e:lower():find("white8x8", 1, true) or (tonumber(i.edgeSize) or 0) > 3 then return end
        for _, k in ipairs(EDGES) do
            local t = c[k]
            if t and t.SetSnapToPixelGrid then
                t:SetSnapToPixelGrid(false)
                t:SetTexelSnappingBias(0)
            end
        end
        -- the corners hold the box's own points; the edges and the background hang off them
        local sc = c.GetEffectiveScale and c:GetEffectiveScale()
        if not (sc and sc > 0 and PixelUtil and PixelUtil.GetPixelToUIUnitFactor) then return end
        local d = PixelUtil.GetPixelToUIUnitFactor() / sc / 8
        for n = 5, 8 do
            local t = c[EDGES[n]]
            if t and t.GetNumPoints and t:GetNumPoints() == 1 then
                local p, rel, rp, x, y = t:GetPoint(1)
                if rel == c then
                    t:ClearAllPoints()
                    t:SetPoint(p, c, rp, (x or 0) - d, (y or 0) + d)
                end
            end
        end
    end)
end
local _, ns = ...
local M = ns.M
local S = {}
ns.Settings = S

local A = { 0, 0.78, 1 }   -- Void cyan
local FONT = "Fonts\\FRIZQT__.TTF"
local W = 380
local PAD = 14
local panel
local rows = {}

local function text(parent, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 11, flags or "")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.92, 0.92, 0.95)
    return fs
end

local function backdrop(f, r, g, b, a, borderAlpha)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = VoidPX() })
    f:SetBackdropColor(r, g, b, a)
    f:SetBackdropBorderColor(A[1], A[2], A[3], borderAlpha or 0.5)
end

local function tooltip(owner, title, line)
    owner:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if line then GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function button(parent, label, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 20)
    backdrop(b, 0.10, 0.12, 0.15, 1, 0.6)
    b.text = text(b, 10)
    b.text:SetPoint("CENTER")
    b.text:SetText(label)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.18, 0.22, 0.28, 1)
        self:SetBackdropBorderColor(A[1], A[2], A[3], 1)
    end)
    b:SetScript("OnLeave", function(self)
        if not self.selected then
            self:SetBackdropColor(0.10, 0.12, 0.15, 1)
            self:SetBackdropBorderColor(A[1], A[2], A[3], 0.6)
        end
    end)
    b:SetScript("OnClick", onClick)
    function b:SetSelected(on)
        self.selected = on
        self:SetBackdropColor(on and A[1] * 0.3 or 0.10, on and A[2] * 0.3 or 0.12, on and A[3] * 0.3 or 0.15, 1)
        self:SetBackdropBorderColor(A[1], A[2], A[3], on and 1 or 0.6)
        self.text:SetTextColor(on and 1 or 0.8, on and 1 or 0.8, on and 1 or 0.85)
    end
    return b
end

local function checkbox(parent, label, get, toggle, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(18)
    local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
    box:SetSize(12, 12)
    box:SetPoint("LEFT")
    backdrop(box, 0.10, 0.12, 0.15, 1, 0.7)
    local fill = box:CreateTexture(nil, "OVERLAY")
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    fill:SetColorTexture(A[1], A[2], A[3], 1)
    b.label = text(b, 11)
    b.label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    b.label:SetPoint("RIGHT")
    b.label:SetText(label)
    b:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.label:SetTextColor(0.92, 0.92, 0.95) end)
    b:SetScript("OnClick", function() toggle(); S:Refresh() end)
    if tip then tooltip(b, label, tip) end
    function b:Update() fill:SetShown(get() and true or false) end
    return b
end

-- "Label   [A] [B] [C]" — pick one.
local function choice(parent, label, options, get, set, tip)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(20)
    local fs = text(row, 11)
    fs:SetPoint("LEFT")
    fs:SetText(label)
    row.buttons = {}
    local x = 0
    for i = #options, 1, -1 do
        local o = options[i]
        local b = button(row, o[1], 44, function() set(o[2]); S:Refresh() end)
        b:SetPoint("RIGHT", -x, 0)
        b.value = o[2]
        row.buttons[#row.buttons + 1] = b
        x = x + 47
    end
    if tip then
        row:EnableMouse(true)
        tooltip(row, label, tip)
    end
    function row:Update()
        local v = get()
        for _, b in ipairs(self.buttons) do b:SetSelected(math.abs((b.value or 0) - (v or 0)) < 0.001) end
    end
    return row
end

local function section(parent, label)
    local fs = text(parent, 11, "OUTLINE")
    fs:SetTextColor(A[1], A[2], A[3])
    fs:SetText(label)
    return fs
end

local function applyMap()
    if ns.Frame then ns.Frame:Layout() end
end

local function cfg() return M:Config() end
local function setter(key) return function(v) cfg()[key] = v; applyMap() end end

local function build()
    panel = CreateFrame("Frame", "VoidMapSettings", UIParent, "BackdropTemplate")
    panel:SetSize(W, 100)
    panel:SetPoint("CENTER")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    backdrop(panel, 0.05, 0.05, 0.07, 0.97, 0.6)
    panel:Hide()
    tinsert(UISpecialFrames, "VoidMapSettings")

    local bar = CreateFrame("Frame", nil, panel)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT")
    bar:SetHeight(26)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() panel:StartMoving() end)
    bar:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    ns.Move(panel, { db = function() return VoidMapDB end, key = "settings", handle = bar })   -- drag + kept after a restart (VoidMove.lua)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(0.06, 0.06, 0.08, 1)
    local line = bar:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    line:SetColorTexture(A[1], A[2], A[3], 0.6)
    local title = text(bar, 13, "OUTLINE")
    title:SetPoint("LEFT", PAD, 0)
    title:SetTextColor(A[1], A[2], A[3])
    title:SetText("VoidMap")
    local close = CreateFrame("Button", nil, bar)
    close:SetSize(22, 22)
    close:SetPoint("RIGHT", -4, 0)
    local x = text(close, 14, "OUTLINE")
    x:SetPoint("CENTER")
    x:SetText("|cffff5555×|r")
    close:SetScript("OnClick", function() panel:Hide() end)

    local y = -36
    local function place(widget, h, gap)
        widget:SetPoint("TOPLEFT", PAD, y)
        if widget.SetPoint and widget.GetObjectType and widget:GetObjectType() ~= "FontString" then
            widget:SetPoint("RIGHT", -PAD, 0)
        end
        y = y - (h or 20) - (gap or 6)
        rows[#rows + 1] = widget
    end

    place(section(panel, "Window"), 14, 4)
    place(checkbox(panel, "Move the map by dragging its title bar",
        function() return cfg().movable end,
        function() cfg().movable = not cfg().movable end,
        "Drag the title bar to put the map anywhere; drag the corner at the bottom right to size it."))
    place(checkbox(panel, "Quest list beside the map",
        function() return cfg().questPanel end,
        function() ns.Frame:ToggleQuests() end,
        "Your quests, the ones on the map you're looking at first. Also the Quests button on the map."))
    local reset = button(panel, "Default spot and size", 170, function() ns.Frame:ResetGeo() end)
    tooltip(reset, "Default spot and size", "Puts the map back in the middle of the screen at its starting size.")
    place(reset, 20, 12)

    local SCALE = { { "80%", 0.8 }, { "90%", 0.9 }, { "100%", 1.0 }, { "115%", 1.15 }, { "130%", 1.3 } }
    local ALPHA = { { "50%", 0.5 }, { "70%", 0.7 }, { "85%", 0.85 }, { "100%", 1.0 } }
    place(section(panel, "Look"), 14, 4)
    place(choice(panel, "Scale", SCALE, function() return cfg().scale end, setter("scale"),
        "Everything in the window, text and buttons too. To make only the map bigger, drag the corner."))
    place(choice(panel, "Map opacity", ALPHA, function() return cfg().mapAlpha end, setter("mapAlpha"),
        "See the world through the map picture and its pins. Title bar, toolbar and quest list stay solid."))
    place(checkbox(panel, "Fade the map while you move (Blizzard's setting)",
        function() return GetCVarBool("mapFade") end,
        function() SetCVar("mapFade", GetCVarBool("mapFade") and "0" or "1") end,
        "Blizzard's own fade: the map turns see-through while you walk and comes back when you stop or point at it."))
    place(checkbox(panel, "Coordinates at the bottom (you and the cursor)",
        function() return cfg().coords end,
        function() cfg().coords = not cfg().coords end), 18, 10)

    place(section(panel, "Trails (for VoidGPS)"), 14, 4)
    place(checkbox(panel, "Record where I walk",
        function() return cfg().trails end,
        function() cfg().trails = not cfg().trails end,
        "Saves the paths you walk and ride (not flying, taxis, boats or instances), for every character. VoidGPS will route along them, around mountains and cliffs. Stays on this computer."), 18, 10)

    local note = text(panel, 9)
    note:SetTextColor(0.5, 0.5, 0.56)
    note:SetText("v" .. (C_AddOns.GetAddOnMetadata("VoidMap", "Version") or "?") .. " · /vmap · settings are per character")
    note:SetPoint("TOPLEFT", PAD, y)
    y = y - 18

    panel:SetHeight(-y + 4)
end

function S:Refresh()
    if not panel then return end
    for _, r in ipairs(rows) do if r.Update then r:Update() end end
end

function S:Toggle()
    if not panel then build() end
    if panel:IsShown() then panel:Hide() else S:Refresh(); panel:Show() end
end

----------------------------------------------------------------------
-- The Void hub launcher
----------------------------------------------------------------------
VoidHubLaunchers = VoidHubLaunchers or {}
VoidHubLaunchers.VoidMap = {
    icon = "Interface\\Icons\\INV_Misc_Map_01",
    onClick = function() S:Toggle() end,
}
