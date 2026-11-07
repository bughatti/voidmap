----------------------------------------------------------------------
-- Quests.lua — our quest list beside the map (replaces Blizzard's quest log panel).
--
-- "On this map" first (quests whose objectives are on the map you're looking
-- at), then the rest of your log under its own headers. Level colors like the
-- quest log, progress on the right, the tracked quest marked.
--   hover        highlights the quest on the map; tooltip with its objectives
--   click        shows its map and the whole quest (QuestPage.lua); ctrl-click tracks it
--   shift-click  links it in chat
--   right-click  stops tracking it
----------------------------------------------------------------------
local _, ns = ...
local M = ns.M
local U = ns.UI
local Q = {}
ns.Quests = Q

local ROW_H = 18
local panel, rows, offset, entries = nil, {}, 0, {}
local W

local function levelColor(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level or 0)
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function progress(qid)
    if C_QuestLog.IsComplete(qid) then return "|cff33ff33Done|r" end
    local objs = C_QuestLog.GetQuestObjectives(qid)
    if not objs or #objs == 0 then return "" end
    if #objs == 1 and objs[1].numRequired and objs[1].numRequired > 1 then
        return ("%d/%d"):format(objs[1].numFulfilled or 0, objs[1].numRequired)
    end
    local done = 0
    for _, o in ipairs(objs) do if o.finished then done = done + 1 end end
    return ("%d/%d"):format(done, #objs)
end

-- quests whose objectives / turn-in are on this map
local function onMap(mapID)
    local set = {}
    if not mapID then return set end
    local list = C_QuestLog.GetQuestsOnMap and C_QuestLog.GetQuestsOnMap(mapID)
    for _, q in ipairs(list or {}) do if q.questID then set[q.questID] = true end end
    return set
end

local function build()
    entries = {}
    local here = onMap(W and W:GetMapID())
    local hereList, rest = {}, {}
    local header
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        if info then
            if info.isHeader then
                header = info.title
            elseif not info.isHidden and info.questID and info.questID > 0 then
                local e = { qid = info.questID, title = info.title, level = info.level }
                if here[info.questID] then
                    hereList[#hereList + 1] = e
                else
                    rest[#rest + 1] = { header = header, e = e }
                end
            end
        end
    end
    if #hereList > 0 then
        entries[#entries + 1] = { head = "On this map" }
        for _, e in ipairs(hereList) do entries[#entries + 1] = e end
    end
    local last
    for _, r in ipairs(rest) do
        if r.header ~= last then
            entries[#entries + 1] = { head = r.header or "Other" }
            last = r.header
        end
        entries[#entries + 1] = r.e
    end
end

local function showTooltip(row)
    local e = row.e
    if not e or not e.qid then return end
    GameTooltip:SetOwner(row, "ANCHOR_LEFT")
    local r, g, b = levelColor(e.level)
    GameTooltip:SetText(e.title or "?", r, g, b)
    if e.level then GameTooltip:AddLine(("Level %d"):format(e.level), 0.7, 0.7, 0.7) end
    for _, o in ipairs(C_QuestLog.GetQuestObjectives(e.qid) or {}) do
        if o.text and o.text ~= "" then
            if o.finished then GameTooltip:AddLine(o.text, 0.3, 1, 0.3, true)
            else GameTooltip:AddLine(o.text, 0.9, 0.9, 0.9, true) end
        end
    end
    if C_QuestLog.IsComplete(e.qid) then GameTooltip:AddLine("Ready to turn in.", 0.3, 1, 0.3) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click: read the whole quest and see its map", 0, 0.78, 1)
    GameTooltip:AddLine("Ctrl-click: track it · Shift-click: link in chat · Right-click: stop tracking", 0.55, 0.55, 0.6, true)
    GameTooltip:Show()
    if W.SetHighlightedQuestID then W:SetHighlightedQuestID(e.qid) end
end

local function onClick(row, button)
    local e = row.e
    if not e or not e.qid then return end
    if IsShiftKeyDown() then
        local link = GetQuestLink and GetQuestLink(e.qid)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
    end
    if button == "RightButton" then
        if C_SuperTrack.GetSuperTrackedQuestID() == e.qid then C_SuperTrack.SetSuperTrackedQuestID(0) end
        if C_QuestLog.RemoveQuestWatch then C_QuestLog.RemoveQuestWatch(e.qid) end
    elseif IsControlKeyDown() then
        -- ctrl-click: track it straight away
        if C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(e.qid) end
        C_SuperTrack.SetSuperTrackedQuestID(e.qid)
    else
        -- click: its map, and the whole quest to read (QuestPage.lua)
        local mapID = GetQuestUiMapID and GetQuestUiMapID(e.qid)
        if mapID and mapID > 0 then W:SetMapID(mapID) end
        if ns.QuestPage then ns.QuestPage:Show(e.qid) end
    end
    Q:Refresh()
end

local function row(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Button", nil, panel.list)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("RIGHT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.hl = U.Fill(r, 1, 1, 1, 0.06, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.mark = U.Fill(r, U.A[1], U.A[2], U.A[3], 1, "ARTWORK")
    r.mark:SetPoint("TOPLEFT", 0, -2); r.mark:SetPoint("BOTTOMLEFT", 0, 2); r.mark:SetWidth(2)
    r.title = U.Text(r, 11)
    r.title:SetPoint("LEFT", 8, 0)
    r.prog = U.Text(r, 10)
    r.prog:SetPoint("RIGHT", -6, 0)
    r.prog:SetJustifyH("RIGHT")
    r.title:SetPoint("RIGHT", r.prog, "LEFT", -6, 0)
    r:SetScript("OnEnter", showTooltip)
    r:SetScript("OnLeave", function()
        GameTooltip:Hide()
        if W.ClearHighlightedQuestID then W:ClearHighlightedQuestID() end
    end)
    r:SetScript("OnClick", onClick)
    rows[i] = r
    return r
end

function Q:Refresh()
    if not (panel and panel:IsShown()) then return end
    build()
    local tracked = C_SuperTrack.GetSuperTrackedQuestID()
    local n = math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
    offset = math.max(0, math.min(offset, #entries - n))
    local quests = 0
    for _, e in ipairs(entries) do if e.qid then quests = quests + 1 end end
    local maxQ = C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept() or 25
    panel.head:SetText(("Quests  |cff8c8c9e%d/%d|r"):format(quests, maxQ))
    for i = 1, n do
        local r, e = row(i), entries[i + offset]
        r.e = e
        if not e then
            r:Hide()
        else
            r:Show()
            r.mark:SetShown(e.qid and e.qid == tracked or false)
            if e.head then
                r.title:SetText(e.head)
                r.title:SetTextColor(U.A[1], U.A[2], U.A[3])
                r.title:SetFont(U.FONT, 10, "OUTLINE")
                r.prog:SetText("")
                r:EnableMouse(false)
            else
                local cr, cg, cb = levelColor(e.level)
                r.title:SetFont(U.FONT, 11, "")
                r.title:SetText(("[%d] %s"):format(e.level or 0, e.title or "?"))
                r.title:SetTextColor(cr, cg, cb)
                r.prog:SetText(progress(e.qid))
                r:EnableMouse(true)
            end
        end
    end
    for i = n + 1, #rows do rows[i]:Hide() end
    panel.more:SetShown(#entries > n)
end

-- Called by Frame.lua on every layout.
function Q:Place(shown, top, bottom, pad)
    if not panel then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", W, "TOPRIGHT", -pad, -top)
    panel:SetPoint("BOTTOMRIGHT", W, "BOTTOMRIGHT", -pad, bottom)
    panel:SetWidth(ns.Frame.SIDE_W - pad)
    panel:SetShown(shown)
    if ns.QuestPage then ns.QuestPage:Place(panel, shown) end
    if shown then Q:Refresh() end
end

M:OnReady(function()
    W = WorldMapFrame
    panel = CreateFrame("Frame", nil, W)
    panel:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 20)
    U.Fill(panel, U.BAR[1], U.BAR[2], U.BAR[3], 1):SetAllPoints()
    local edge = U.Fill(panel, U.A[1], U.A[2], U.A[3], 0.35, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
    panel.head = U.Text(panel, 12, "OUTLINE")
    panel.head:SetPoint("TOPLEFT", 10, -7)
    panel.head:SetTextColor(U.A[1], U.A[2], U.A[3])
    panel.list = CreateFrame("Frame", nil, panel)
    panel.list:SetPoint("TOPLEFT", 4, -26)
    panel.list:SetPoint("BOTTOMRIGHT", -2, 16)
    panel.more = U.Text(panel, 9)
    panel.more:SetPoint("BOTTOM", 0, 3)
    panel.more:SetTextColor(0.5, 0.5, 0.56)
    panel.more:SetText("scroll for more")
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, d)
        offset = math.max(0, offset - d * 3)
        Q:Refresh()
    end)
    panel:SetScript("OnSizeChanged", function() Q:Refresh() end)
    panel:Hide()

    local pending
    local function later()
        if pending then return end
        pending = true
        C_Timer.After(0.2, function() pending = nil; Q:Refresh() end)
    end
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED", "SUPER_TRACKING_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", later)
    if W.OnMapChanged then hooksecurefunc(W, "OnMapChanged", later) end
end)
