----------------------------------------------------------------------
-- ExploreView.lua — Explore Azeroth progress beside the map (WoW Forever)
--
-- The user, 2026-11-11: "do both, progress in voidmap and explore on the route". Explore Azeroth
-- (every zone on both continents) is a Legacy point. The title bar's "Explore" button turns the
-- side area into:
--   Explore Azeroth   Kalimdor 12/21 zones · Eastern Kingdoms 8/25 zones
--   <this zone>       9/12 areas; the ones still to find (click: the way there), then the found ones
--   <continent>       every zone with its count (click: open that zone's map)
-- While it's open, the map shows a marker on each area of the zone you're looking at that you
-- haven't discovered. The data: _shared/Explore.lua (the achievements) + ForeverAreas.lua.
----------------------------------------------------------------------
local _, ns = ...
local M = ns.M
local U = ns.UI
if (select(4, GetBuildInfo()) or 0) >= 100000 then return end   -- WoW Forever only

local X = {}
ns.Explore = X
local W, panel, child, scroll, btn
local rows, pins = {}, {}
local ROW_H = 16

local function E() return _G.VoidExplore end

local function goTo(a)
    if not (a and a.map and a.x) then return end
    if VoidGPS and VoidGPS.RouteTo then
        VoidGPS:RouteTo({ name = a.name, sub = "discover (Explore " .. (a.zone or "") .. ")", map = a.map, x = a.x, y = a.y })
    elseif C_Map.SetUserWaypoint and UiMapPoint then
        C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(a.map, a.x, a.y))
        if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
    end
end

local function row(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW_H)
    r:SetPoint("LEFT", 0, 0); r:SetPoint("RIGHT", 0, 0)
    r.text = r:CreateFontString(nil, "OVERLAY")
    r.text:SetFont(U.FONT, 11, "")
    r.text:SetPoint("LEFT", 2, 0); r.text:SetPoint("RIGHT", -2, 0)
    r.text:SetJustifyH("LEFT"); r.text:SetWordWrap(false)
    local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.07)
    r:SetScript("OnClick", function(s) if s.onClick then s.onClick() end end)
    r:SetScript("OnEnter", function(s)
        if not s.tip then return end
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        for k, l in ipairs(s.tip) do GameTooltip:AddLine(l, 1, 1, 1, k > 1) end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = r
    return r
end

local function zoneMapShown()
    local m = W and W.GetMapID and W:GetMapID()
    if not m then return nil end
    local info = C_Map.GetMapInfo(m)
    local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    if info and info.mapType and info.mapType >= ZONE then return E():ZoneOf(m) end
    return nil
end

----------------------------------------------------------------------
-- Map markers: each undiscovered area of the zone you're looking at
----------------------------------------------------------------------
local function hidePins() for _, p in ipairs(pins) do p:Hide() end end
local function drawPins()
    hidePins()
    if not (X.on and E()) then return end
    local zm = zoneMapShown()
    if not zm or zm ~= (W:GetMapID() and E():ZoneOf(W:GetMapID())) or W:GetMapID() ~= zm then return end
    local canvas = W.GetCanvas and W:GetCanvas()
    if not canvas then return end
    local cw, ch = canvas:GetSize()
    for i, a in ipairs(E():Undiscovered(zm)) do
        local p = pins[i]
        if not p then
            p = CreateFrame("Button", nil, canvas)
            p:SetSize(28, 28)
            p.dot = p:CreateTexture(nil, "OVERLAY")
            p.dot:SetPoint("CENTER"); p.dot:SetSize(14, 14)
            p.dot:SetTexture("Interface\\Common\\Indicator-Yellow")
            p.label = p:CreateFontString(nil, "OVERLAY")
            p.label:SetFont(U.FONT, 12, "OUTLINE"); p.label:SetPoint("TOP", p, "BOTTOM", 0, 2)
            p.label:SetTextColor(1, 0.85, 0.3)
            p:SetScript("OnClick", function(s) goTo(s.area) end)
            p:SetScript("OnEnter", function(s)
                GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                GameTooltip:AddLine(s.area.name, 1, 0.85, 0.3)
                GameTooltip:AddLine("Not discovered yet (Explore " .. (s.area.zone or "") .. ")", 1, 1, 1)
                GameTooltip:AddLine("Click: the way there", .6, .6, .6)
                GameTooltip:Show()
            end)
            p:SetScript("OnLeave", function() GameTooltip:Hide() end)
            pins[i] = p
        end
        p.area = a
        p:SetFrameLevel(canvas:GetFrameLevel() + 30)
        p:ClearAllPoints()
        p:SetPoint("CENTER", canvas, "TOPLEFT", a.x * cw, -a.y * ch)
        p.label:SetText(a.name)
        p:Show()
    end
end

----------------------------------------------------------------------
-- The side panel
----------------------------------------------------------------------
function X:Render()
    if not (panel and panel:IsShown() and E()) then return end
    for _, r in ipairs(rows) do r:Hide(); r.onClick, r.tip = nil, nil end
    local n = 0
    local function line(text, onClick, tip, gap)
        n = n + 1
        local r = row(n)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((n - 1) * ROW_H) - (gap or 0))
        r:SetPoint("RIGHT", child, "RIGHT", 0, 0)
        r.text:SetText(text)
        r.onClick, r.tip = onClick, tip
        r:Show()
    end
    local all = E():Overall()
    if not all then
        line("|cffaaaaaaThe Explore achievements aren't loaded yet. Open this again in a moment.|r")
        child:SetHeight(n * ROW_H)
        return
    end
    line("|cff00c7ffExplore Azeroth|r " .. (all.done and "|cff55ff55done|r" or "|cffaaaaaa(1 Legacy point)|r"), nil,
        { "Explore Azeroth", "Every zone on both continents. Having it on any character gives a Legacy point." })
    for _, c in ipairs(all.conts) do
        line(("   %s: |cffffffff%d/%d|r zones explored"):format(c.name, c.zonesDone, c.total))
    end
    -- this zone
    local zm = zoneMapShown()
    local z = zm and E():Zone(zm)
    if z then
        line(" ")
        line(("|cff00c7ff%s|r  %d/%d areas%s"):format(z.name, z.done, z.total, z.complete and " |cff55ff55done|r" or ""))
        local found = {}
        for _, a in ipairs(z.areas) do
            if a.done then
                found[#found + 1] = a.name
            else
                local area = { name = a.name, map = a.map, x = a.x, y = a.y, zone = z.name }
                line(("   |cffffd200%s|r%s"):format(a.name, a.x and "" or " |cff888888(place not known)|r"),
                    a.x and function() goTo(area) end or nil,
                    { a.name, "Not discovered yet." .. (a.x and " Click: the way there." or "") })
            end
        end
        if #found > 0 then
            line(("   |cff888888Found: %s|r"):format(table.concat(found, ", ")), nil, { "Discovered", table.concat(found, ", ") })
        end
    end
    -- the continent's zones
    local contName
    local m = W:GetMapID()
    local info = m and C_Map.GetMapInfo(m)
    for _ = 1, 6 do
        if not info then break end
        if info.mapType == (Enum and Enum.UIMapType and Enum.UIMapType.Continent or 2) then contName = info.name; break end
        info = info.parentMapID and C_Map.GetMapInfo(info.parentMapID)
    end
    for _, c in ipairs(all.conts) do
        if c.name == contName then
            line(" ")
            line(("|cff00c7ff%s|r zones"):format(c.name))
            table.sort(c.zones, function(a, b)
                if a.done ~= b.done then return not a.done end
                return a.name < b.name
            end)
            for _, zz in ipairs(c.zones) do
                local zd = zz.map and E():Zone(zz.map)
                local count = zd and ("%d/%d"):format(zd.done, zd.total) or ""
                line(("   %s%s|r  |cffaaaaaa%s|r"):format(zz.done and "|cff55ff55" or "|cffffffff", zz.name, count),
                    zz.map and function() W:SetMapID(zz.map) end or nil,
                    zz.map and { zz.name, zz.done and "Explored." or "Click: open its map." } or nil)
            end
        end
    end
    child:SetHeight(math.max(1, n * ROW_H))
    drawPins()
end

function X:SetOn(on)
    X.on = on and true or false
    if not panel then return end
    M:SetSideOwner(X.on and panel or nil)
    if btn then btn:SetSelected(X.on) end
    if X.on then X:Render() else hidePins() end
end

M:OnReady(function()
    if not (M.SetSideOwner and M.AddTitleButton) then return end
    W = WorldMapFrame
    panel = CreateFrame("Frame", nil, W)
    panel:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 40)
    panel:EnableMouse(true)
    U.Fill(panel, U.BAR[1], U.BAR[2], U.BAR[3], 1):SetAllPoints()
    panel:Hide()
    scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", 8, -6); scroll:SetPoint("BOTTOMRIGHT", -6, 6)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll:SetScript("OnSizeChanged", function(_, w) child:SetWidth(w) end)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(s, d)
        local max = math.max(0, child:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(math.max(0, math.min(max, s:GetVerticalScroll() - d * 3 * ROW_H)))
    end)
    btn = M:AddTitleButton("Explore", { "Explore Azeroth", "Your exploring progress: zones and the areas you haven't discovered, with markers on the map. Explore Azeroth gives a Legacy point." },
        function() X:SetOn(not X.on) end)
    -- another view took the side area (VoidDungeon): off
    hooksecurefunc(M, "SetSideOwner", function(_, frame)
        if X.on and frame ~= panel then X.on = false; hidePins(); if btn then btn:SetSelected(false) end end
    end)
    if W.OnMapChanged then hooksecurefunc(W, "OnMapChanged", function() if X.on then X:Render() end end) end
    W:HookScript("OnHide", function() if X.on then X:SetOn(false) end end)
    if E() and E().OnChange then E():OnChange(function() if X.on then X:Render() end end) end
end)
