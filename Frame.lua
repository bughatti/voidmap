----------------------------------------------------------------------
-- Frame.lua — VoidMap's window around Blizzard's map engine.
--
-- WorldMapFrame stays the engine (canvas, zoom / pan, every pin, Esc / M / L
-- handling by Blizzard's panel code). We:
--   * hide Blizzard's chrome: border art, portrait, title, nav bar, floor
--     dropdown, coordinates, side-panel toggle, the size buttons, the quest log
--     (they stay where they are and hide again whenever shown, so Blizzard's own code keeps
--     working on them; nothing is replaced in Blizzard's tables)
--   * build our own: title bar, World / Continent / Zone navigation with
--     sibling menus, floor picker, zoom, footer with coordinates, resize grip
--   * keep Blizzard's filter and map-pin buttons (their menus and behavior),
--     moved into our toolbar and drawn in our style
--   * size and place the frame ourselves after Blizzard does (post-hooks only)
-- The world map has no protected parts, so none of this can block an action.
----------------------------------------------------------------------
local _, ns = ...
local M = ns.M
local U = ns.UI
local F = {}
ns.Frame = F

local TITLE_H, TOOL_H, FOOT_H, PAD = 26, 28, 20, 6
F.SIDE_W = 340   -- wide enough for Blizzard's quest details when they open in it
local MIN_W, MIN_H = 600, 420
local DEF_CANVAS_H = 600
local ASPECT = 1.5   -- map art is 1002 x 668

local W                          -- WorldMapFrame
local applying, sizing
local ui = {}                    -- our chrome

local function sideW() return M:Config().questPanel and F.SIDE_W or 0 end
-- Keep a Blizzard piece hidden without moving it: Blizzard's code still calls it and
-- asks it for its parent (moving it under another frame broke the map on open), so it
-- stays where it is and hides again whenever anything shows it.
local function stash(f)
    if not (f and f.HookScript) then return end
    f:HookScript("OnShow", f.Hide)
    f:Hide()
end

----------------------------------------------------------------------
-- Size and place
----------------------------------------------------------------------
function F:Layout()
    if not W or applying then return end
    applying = true
    local c = M:Config()
    local s = math.max(0.5, math.min(1.5, c.scale or 1))
    if math.abs((W:GetScale() or 1) - s) > 0.001 then W:SetScale(s) end

    -- The map picture is 3:2: the window follows its height so the map always fills
    -- its area (no empty bands at the sides), like Blizzard's own big map.
    local side = sideW()
    local chromeH = TITLE_H + TOOL_H + FOOT_H
    local w, h
    W:ClearAllPoints()
    if c.big then
        local uw, uh = UIParent:GetSize()
        local availW, availH = uw * 0.96 / s, uh * 0.92 / s
        local ch = availH - chromeH
        local cw = ch * ASPECT
        if cw + 2 * PAD + side > availW then cw = availW - 2 * PAD - side; ch = cw / ASPECT end
        w, h = cw + 2 * PAD + side, ch + chromeH
        W:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    else
        local g = c.geo
        h = math.max(MIN_H, (g and g.h) or (DEF_CANVAS_H + chromeH))
        w = (h - chromeH) * ASPECT + 2 * PAD + side
        local es = W:GetEffectiveScale()
        if g and g.x and g.y and es and es > 0 then
            W:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", g.x / es, g.y / es)
        else
            W:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
        end
    end
    W:SetSize(math.floor(w), math.floor(h))

    local sc = W.ScrollContainer
    sc:ClearAllPoints()
    sc:SetPoint("TOPLEFT", W, "TOPLEFT", PAD, -(TITLE_H + TOOL_H))
    sc:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -(PAD + side), FOOT_H)
    sc:SetAlpha(c.mapAlpha or 1)
    if ui.backing then ui.backing:SetAlpha(c.mapAlpha or 1) end
    -- Tell the canvas only when its size really changed: Blizzard resets the zoom on
    -- every size change, so moving the window must not count as one.
    local cw, ch = sc:GetSize()
    if cw and ch and (math.abs(cw - (ui.toldW or 0)) > 0.5 or math.abs(ch - (ui.toldH or 0)) > 0.5) then
        W:OnFrameSizeChanged()
    end

    -- Blizzard's quest log stays "open" whenever Blizzard opens it (its own L / M logic and
    -- the objective tracker depend on that; hiding it from addon code would taint the
    -- tracker's quest-item buttons). It is only moved: out of sight, or over our quest list
    -- while it shows a quest's details (from the tracker), with Blizzard's Back button.
    local Q = W.QuestLog
    if Q then
        Q:ClearAllPoints()
        local details = Q.DetailsFrame and Q.DetailsFrame:IsShown()
        if details then
            Q:SetPoint("TOPRIGHT", W, "TOPRIGHT", -PAD, -(TITLE_H + TOOL_H))
            Q:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -PAD, FOOT_H)
            Q:SetAlpha(1)
        else
            Q:SetPoint("TOPRIGHT", UIParent, "TOPLEFT", -3000, 3000)
            Q:SetAlpha(0)
        end
    end

    local close = W.BorderFrame and W.BorderFrame.CloseButton
    if close and ui.title then
        close:ClearAllPoints()
        close:SetPoint("RIGHT", ui.title, "RIGHT", -3, 0)
    end
    if ui.grip then ui.grip:SetShown(not c.big) end
    if ui.bigBtn then ui.bigBtn:SetLabel(c.big and "Small" or "Big") end
    if ui.questBtn then ui.questBtn:SetSelected(side > 0) end
    if ui.sideTab then
        -- Blizzard-style tab on the map's right edge: fold the quest list away / bring it back
        ui.sideTab:ClearAllPoints()
        ui.sideTab:SetPoint("RIGHT", sc, "RIGHT", 0, 0)
        -- the texture points down; turned to point right (fold away) or left (bring back)
        ui.sideTab.arrow:SetRotation(side > 0 and math.pi / 2 or -math.pi / 2)
    end
    if ns.Quests then ns.Quests:Place(side > 0, TITLE_H + TOOL_H, FOOT_H, PAD) end
    applying = false
end

-- Remember the window's top-left corner (screen pixels) and its size without the quest list.
function F:SaveGeo()
    local c = M:Config()
    if c.big then return end
    local es = W:GetEffectiveScale()
    local l, t = W:GetLeft(), W:GetTop()
    if not (l and t and es) then return end
    c.geo = { x = l * es, y = t * es, h = W:GetHeight() }   -- width follows the height (map shape)
end

function F:ResetGeo()
    M:Config().geo = nil
    M:Config().big = false
    self:Layout()
end

function F:ToggleBig()
    local c = M:Config()
    if not c.big then self:SaveGeo() end
    c.big = not c.big
    self:Layout()
end

function F:ToggleQuests()
    local c = M:Config()
    c.questPanel = not c.questPanel
    self:Layout()
    if ns.Settings then ns.Settings:Refresh() end
end

----------------------------------------------------------------------
-- Navigation: World > Continent v > Zone v, floor picker
----------------------------------------------------------------------
local crumbPool = {}

local function siblings(info)
    local list = {}
    local kids = info and info.parentMapID and C_Map.GetMapChildrenInfo(info.parentMapID)
    for _, k in ipairs(kids or {}) do
        if C_Map.IsMapValidForNavBarDropdown(k.mapID) then list[#list + 1] = k end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

local function goTo(mapID) if mapID then W:SetMapID(mapID) end end

local function menu(owner, list, current)
    if not (MenuUtil and MenuUtil.CreateContextMenu) or #list == 0 then return end
    GameTooltip:Hide()   -- the button's tooltip would cover the top of the menu
    MenuUtil.CreateContextMenu(owner, function(_, root)
        for _, e in ipairs(list) do
            root:CreateRadio(e.name, function(id) return id == current end, function(id) goTo(id) end, e.mapID)
        end
    end)
end

local function crumb(i)
    local c = crumbPool[i]
    if c then return c end
    c = U.Button(ui.tool, "", nil, 20)
    c.arrow = U.Button(ui.tool, "", 16, 20)
    local ico = c.arrow:CreateTexture(nil, "OVERLAY")
    ico:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    ico:SetSize(12, 12)
    ico:SetPoint("CENTER", 0, -3)
    ico:SetVertexColor(0.6, 0.9, 1)
    crumbPool[i] = c
    return c
end

function F:RefreshNav()
    if not (W and ui.tool) then return end
    local mapID = W:GetMapID()
    local chain = {}
    local info = mapID and C_Map.GetMapInfo(mapID)
    while info and info.parentMapID and info.parentMapID > 0 do
        table.insert(chain, 1, info)
        info = C_Map.GetMapInfo(info.parentMapID)
    end

    local x = 6
    -- "World": the top (cosmic) map
    local home = crumb(1)
    home:SetLabel(WORLD or "World")
    home:ClearAllPoints()
    home:SetPoint("LEFT", ui.tool, "LEFT", x, 0)
    home:SetScript("OnClick", function()
        local top = MapUtil.GetMapParentInfo(mapID, Enum.UIMapType.Cosmic, true)
        goTo(top and top.mapID)
    end)
    home:SetSelected(#chain == 0)
    home:Show()
    home.arrow:Hide()
    x = x + home:GetWidth() + 4

    for i, m in ipairs(chain) do
        local c = crumb(i + 1)
        c:SetLabel(m.name)
        c:ClearAllPoints()
        c:SetPoint("LEFT", ui.tool, "LEFT", x, 0)
        c:SetSelected(i == #chain)
        c:SetScript("OnClick", function() goTo(m.mapID) end)
        c:Show()
        x = x + c:GetWidth()
        local sib = siblings(m)
        if #sib > 1 then
            c.arrow:ClearAllPoints()
            c.arrow:SetPoint("LEFT", c, "RIGHT", -1, 0)
            c.arrow:SetScript("OnClick", function(self) menu(self, sib, m.mapID) end)
            c.arrow.tip = { "Other maps here", "Pick another " .. (m.mapType == Enum.UIMapType.Continent and "continent" or "map") .. " at this level." }
            c.arrow:Show()
            x = x + 15
        else
            c.arrow:Hide()
        end
        x = x + 4
    end
    for i = #chain + 2, #crumbPool do crumbPool[i]:Hide(); crumbPool[i].arrow:Hide() end

    -- floor picker (dungeons, cities with levels)
    local group = mapID and C_Map.GetMapGroupID(mapID)
    local members = group and C_Map.GetMapGroupMembersInfo(group)
    if members and #members > 1 then
        local name = "Floor"
        for _, mm in ipairs(members) do if mm.mapID == mapID then name = mm.name end end
        ui.floor:SetLabel("Floor: " .. name)
        ui.floor:ClearAllPoints()
        ui.floor:SetPoint("LEFT", ui.tool, "LEFT", x + 8, 0)
        ui.floor:SetScript("OnClick", function(self) menu(self, members, mapID) end)
        ui.floor:Show()
    else
        ui.floor:Hide()
    end

    local mi = mapID and C_Map.GetMapInfo(mapID)
    ui.titleText:SetText("|cff00c7ffVoidMap|r   " .. (mi and mi.name or ""))
end

----------------------------------------------------------------------
-- Blizzard's filter and map-pin buttons, in our toolbar and our style
----------------------------------------------------------------------
local function restyle(b, label, tipTitle)
    if not b then return end
    for _, r in ipairs({ b:GetRegions() }) do r:SetAlpha(0) end
    b:ClearAllPoints()
    b:SetSize(1, 20)
    b:SetFrameLevel(ui.tool:GetFrameLevel() + 5)
    local bg = U.Fill(b, 0.10, 0.12, 0.15, 1, "BACKGROUND", 7)
    bg:SetAllPoints()
    bg:SetAlpha(1)
    b.vmEdges = U.Border(b, 0.45, "OVERLAY")
    local t = U.Text(b, 10, nil, "OVERLAY")
    t:SetPoint("CENTER")
    t:SetText(label)
    local w = t:GetStringWidth() + 14
    -- the filter's active-filter counter and its "reset filters" x: counter hidden, x kept inside our button
    for _, k in ipairs({ "FilterCounter", "FilterCounterBanner" }) do
        if b[k] then b[k]:SetAlpha(0); if b[k].EnableMouse then b[k]:EnableMouse(false) end end
    end
    if b.ResetButton then
        b.ResetButton:ClearAllPoints()
        b.ResetButton:SetPoint("RIGHT", b, "RIGHT", -2, 0)
        b.ResetButton:SetSize(14, 14)
        t:ClearAllPoints()
        t:SetPoint("LEFT", 7, 0)
        w = w + 14
    end
    b:SetWidth(w)
    b.vmText, b.vmBg = t, bg
    b:HookScript("OnEnter", function() bg:SetColorTexture(0.18, 0.22, 0.28, 1) end)
    b:HookScript("OnLeave", function() if not b.vmActive then bg:SetColorTexture(0.10, 0.12, 0.15, 1) end end)
    return b
end

local function takeOverBlizzardChrome()
    local B = W.BorderFrame
    if B then
        B:SetAlpha(0)   -- border art, portrait, title: invisible (Blizzard restyles it on every open)
        if B.CloseButton then B.CloseButton:SetIgnoreParentAlpha(true) end
        stash(B.Tutorial)
        stash(B.MaximizeMinimizeFrame)
        if B.Bg then B.Bg:SetAlpha(0) end
    end
    stash(W.BlackoutFrame)
    stash(W.NavBar)
    stash(W.SidePanelToggle)
    -- W.QuestLog (Blizzard's quest log) is moved, never hidden: see F:Layout
    if W.QuestLog then W.QuestLog:SetClampedToScreen(false) end

    -- Recognised by their parts, not by mixin identity (WoW Forever loads its own copies of the templates).
    for _, o in ipairs(W.overlayFrames or {}) do
        if o.PlayerCoords or o.CursorCoords then
            stash(o)                                   -- coordinates (ours are in the footer)
        elseif o.BuildFilterTable or o.FilterCounter then
            ui.filter = o                              -- map filter dropdown
        elseif o.SetActive and o.ActiveTexture then
            ui.pin = o                                 -- "place a map pin" button
        elseif o.RefreshMenu then
            stash(o)                                   -- floor dropdown (ours is in the toolbar)
        end
    end

    -- Blizzard opens the map full-screen when this is 0; our window has its own Big mode.
    if not GetCVarBool("miniWorldMap") then SetCVar("miniWorldMap", "1") end
end

-- Restyle the close button (Blizzard's own, so Esc / close stay Blizzard's code).
local function styleClose()
    local b = W.BorderFrame and W.BorderFrame.CloseButton
    if not b then return end
    for _, r in ipairs({ b:GetRegions() }) do r:SetAlpha(0) end   -- normal / pushed / highlight art
    b:SetSize(20, 20)
    local x = U.Text(b, 15, "OUTLINE", "OVERLAY")
    x:SetPoint("CENTER", 0, 1)
    x:SetText("|cffff5555×|r")
    b:HookScript("OnEnter", function() x:SetText("|cffff9999×|r") end)
    b:HookScript("OnLeave", function() x:SetText("|cffff5555×|r") end)
end

----------------------------------------------------------------------
-- Build our chrome
----------------------------------------------------------------------
local function build()
    local A = U.A
    -- backing behind the map (fades with the map opacity) and the outer border
    ui.backing = U.Fill(W, U.BG[1], U.BG[2], U.BG[3], 0.97, "BACKGROUND", -8)
    ui.backing:SetAllPoints()
    U.Border(W, 0.6, "BORDER")

    -- title bar
    local title = CreateFrame("Frame", nil, W)
    title:SetPoint("TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", -1, -1)
    title:SetHeight(TITLE_H - 1)
    title:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 20)
    U.Fill(title, U.BAR[1], U.BAR[2], U.BAR[3], 1):SetAllPoints()
    local line = U.Fill(title, A[1], A[2], A[3], 0.6, "BORDER")
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    ui.titleText = U.Text(title, 13, "OUTLINE")
    ui.titleText:SetPoint("LEFT", 10, 0)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
        local c = M:Config()
        if not c.movable or c.big then return end
        W:SetMovable(true)
        W:StartMoving()
        title.moving = true
    end)
    title:SetScript("OnDragStop", function()
        if not title.moving then return end
        title.moving = false
        W:StopMovingOrSizing()
        W:SetUserPlaced(false)
        F:SaveGeo()
        F:Layout()
    end)
    ui.title = title

    -- title buttons (right to left; Blizzard's close button sits at the far right)
    local function tbtn(label, tip, onClick, anchorTo, gap)
        local b = U.Button(title, label, nil, 18, onClick, tip)
        b:SetPoint("RIGHT", anchorTo, anchorTo == title and "RIGHT" or "LEFT", gap or -4, 0)
        return b
    end
    ui.gear = tbtn("Settings", { "VoidMap settings", "Size, opacity, coordinates, trail recording." },
        function() if ns.Settings then ns.Settings:Toggle() end end, title, -28)
    ui.bigBtn = tbtn("Big", { "Big / small window", "Big fills most of the screen; small is the size you dragged it to." },
        function() F:ToggleBig() end, ui.gear)
    ui.questBtn = tbtn("Quests", { "Quest list", "Show or hide your quests beside the map." },
        function() F:ToggleQuests() end, ui.bigBtn)

    -- toolbar
    local tool = CreateFrame("Frame", nil, W)
    tool:SetPoint("TOPLEFT", 1, -TITLE_H)
    tool:SetPoint("TOPRIGHT", -1, -TITLE_H)
    tool:SetHeight(TOOL_H)
    tool:SetFrameLevel(title:GetFrameLevel())
    U.Fill(tool, U.BG[1], U.BG[2], U.BG[3], 1):SetAllPoints()
    ui.tool = tool
    ui.floor = U.Button(tool, "Floor", nil, 20, nil, { "Floor", "This map has several levels." })

    -- right side of the toolbar: zoom, then Blizzard's filter and pin buttons
    ui.zoomIn = U.Button(tool, "+", 22, 20, function() W.ScrollContainer:ZoomIn() end, { "Zoom in" })
    ui.zoomIn:SetPoint("RIGHT", tool, "RIGHT", -6, 0)
    ui.zoomOut = U.Button(tool, "-", 22, 20, function() W.ScrollContainer:ZoomOut() end, { "Zoom out" })
    ui.zoomOut:SetPoint("RIGHT", ui.zoomIn, "LEFT", -3, 0)
    local anchor = ui.zoomOut
    if restyle(ui.filter, "Filter") then
        ui.filter:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
        anchor = ui.filter
    end
    if restyle(ui.pin, "Pin") then
        ui.pin:SetPoint("RIGHT", anchor, "LEFT", -3, 0)
        hooksecurefunc(ui.pin, "SetActive", function(self, on)
            self.vmActive = on
            self.vmBg:SetColorTexture(on and A[1] * 0.35 or 0.10, on and A[2] * 0.35 or 0.12, on and A[3] * 0.35 or 0.15, 1)
        end)
    end

    -- for other Void addons (VoidGPS puts its search box here): the toolbar and its
    -- leftmost right-side button, to anchor left of
    M.toolbar = tool
    M.toolbarRight = (ui.pin and ui.pin:GetParent() == W and ui.pin) or anchor

    -- footer: coordinates (left), trail recording (right), resize grip
    local foot = CreateFrame("Frame", nil, W)
    foot:SetPoint("BOTTOMLEFT", 1, 1)
    foot:SetPoint("BOTTOMRIGHT", -1, 1)
    foot:SetHeight(FOOT_H - 1)
    foot:SetFrameLevel(title:GetFrameLevel())
    U.Fill(foot, U.BAR[1], U.BAR[2], U.BAR[3], 1):SetAllPoints()
    ui.coords = U.Text(foot, 10)
    ui.coords:SetPoint("LEFT", 10, 0)
    ui.trail = U.Text(foot, 10)
    ui.trail:SetPoint("RIGHT", -24, 0)
    ui.trail:SetTextColor(0.55, 0.55, 0.6)
    ui.foot = foot

    local grip = CreateFrame("Button", nil, foot)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        if M:Config().big then return end
        W:SetResizable(true)
        W:SetResizeBounds(MIN_W + sideW(), MIN_H)
        sizing = true
        W:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        if not sizing then return end
        sizing = false
        W:StopMovingOrSizing()
        W:SetUserPlaced(false)
        F:SaveGeo()
        F:Layout()
    end)
    ui.grip = grip

    -- the side tab (like the arrow on Blizzard's map that hides the quest log)
    local tab = CreateFrame("Button", nil, W)
    tab:SetSize(16, 56)
    tab:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 30)
    local tbg = U.Fill(tab, U.BAR[1], U.BAR[2], U.BAR[3], 0.92)
    tbg:SetAllPoints()
    U.Border(tab, 0.5)
    tab.arrow = tab:CreateTexture(nil, "OVERLAY")
    tab.arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    tab.arrow:SetSize(14, 14)
    tab.arrow:SetPoint("CENTER", 0, 0)
    tab.arrow:SetVertexColor(0.6, 0.9, 1)
    tab:SetScript("OnClick", function() F:ToggleQuests() end)
    tab:SetScript("OnEnter", function(self)
        tbg:SetColorTexture(0.18, 0.22, 0.28, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(M:Config().questPanel and "Hide the quest list" or "Show the quest list", 1, 1, 1)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() tbg:SetColorTexture(U.BAR[1], U.BAR[2], U.BAR[3], 0.92); GameTooltip:Hide() end)
    ui.sideTab = tab
    W:HookScript("OnSizeChanged", function() if sizing then W:OnFrameSizeChanged() end end)

    styleClose()
end

----------------------------------------------------------------------
-- Footer: coordinates and trail count
----------------------------------------------------------------------
local function playerXY(mapID)
    if not mapID then return nil end
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if issecretvalue and (issecretvalue(x) or issecretvalue(y)) then return nil end
    if not (x and y) or (x == 0 and y == 0) then return nil end
    return x, y
end

local tick = 0
local function onUpdate(_, dt)
    tick = tick + dt
    if tick < 0.05 then return end
    tick = 0
    local parts = {}
    if M:Config().coords then
        local px, py = playerXY(W:GetMapID())
        if px then parts[#parts + 1] = ("|cff00c7ffYou|r %.1f, %.1f"):format(px * 100, py * 100) end
        if W.ScrollContainer:IsMouseOver() then
            local cx, cy = W:GetNormalizedCursorPosition()
            if cx and cy and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
                parts[#parts + 1] = ("|cff00c7ffCursor|r %.1f, %.1f"):format(cx * 100, cy * 100)
            end
        end
    end
    ui.coords:SetText(table.concat(parts, "      "))
    if ns.Trails then ui.trail:SetText(ns.Trails:Status()) end
end

----------------------------------------------------------------------
-- Start
----------------------------------------------------------------------
M:OnReady(function()
    W = WorldMapFrame
    W:SetClampedToScreen(true)
    takeOverBlizzardChrome()
    build()

    -- Blizzard places and sizes the map on open, on L / M, and when other panels open: we follow up.
    hooksecurefunc(W, "SetPoint", function() if not applying and not sizing and not ui.title.moving then F:Layout() end end)
    if W.SetDisplayState then hooksecurefunc(W, "SetDisplayState", function() F:Layout() end) end
    if W.UpdateSpacerFrameAnchoring then hooksecurefunc(W, "UpdateSpacerFrameAnchoring", function() F:Layout() end) end
    if W.SetQuestLogPanelShown then
        -- L (quest log) opens the map with our quest list
        hooksecurefunc(W, "SetQuestLogPanelShown", function(_, shown)
            if shown and not M:Config().questPanel then M:Config().questPanel = true; F:Layout() end
        end)
    end
    if W.OnMapChanged then hooksecurefunc(W, "OnMapChanged", function() F:RefreshNav() end) end
    -- remember what size the canvas was last told (by Blizzard or by us)
    hooksecurefunc(W, "OnFrameSizeChanged", function()
        ui.toldW, ui.toldH = W.ScrollContainer:GetSize()
    end)
    -- quest details opened from the objective tracker: show them in our side area
    local D = W.QuestLog and W.QuestLog.DetailsFrame
    if D then
        D:HookScript("OnShow", function()
            if not M:Config().questPanel then M:Config().questPanel = true end
            F:Layout()
        end)
        D:HookScript("OnHide", function() F:Layout() end)
    end
    W:HookScript("OnShow", function()
        -- TomTom writes "Player / Cursor" across the map's top edge (our title bar); the footer has both
        if TomTomWorldFrame and not ui.tomtomHidden then
            ui.tomtomHidden = true
            stash(TomTomWorldFrame)
        end
        F:Layout()
        F:RefreshNav()
        C_Timer.After(0, function() F:Layout() end)   -- after the panel manager is done
    end)
    local ticker = CreateFrame("Frame", nil, W)
    ticker:SetScript("OnUpdate", onUpdate)

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("DISPLAY_SIZE_CHANGED")
    ev:RegisterEvent("UI_SCALE_CHANGED")
    ev:SetScript("OnEvent", function() if W:IsShown() then F:Layout() end end)

    F:Layout()
    F:RefreshNav()
end)
