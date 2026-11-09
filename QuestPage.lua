----------------------------------------------------------------------
-- QuestPage.lua — read a whole quest beside the map.
--
-- Click a quest in the list: this page covers the list with the quest's title,
-- objectives (done ones green), its whole text, and its rewards, with Track,
-- Share and Abandon at the bottom and "< Quests" to go back. Scroll with the
-- mouse wheel. Built from the quest APIs, never by opening Blizzard's quest log
-- from addon code (that path can taint the objective tracker's item buttons).
--
-- VoidMap.ShowQuest(questID): other addons (VoidQuest's right-click) open it.
----------------------------------------------------------------------
local _, ns = ...
local M = ns.M
local U = ns.UI
local P = {}
ns.QuestPage = P

local W, page, body, child, qid
local lines = {}

local function safe(fn, ...)
    if not fn then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end
local function secret(v) return issecretvalue and issecretvalue(v) end

local function levelColor(level)
    local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level or 0)
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

-- text blocks in the scroll child, top to bottom
local y
local function add(text, size, r, g, b, gap, flags)
    P.n = (P.n or 0) + 1
    local fs = lines[P.n]
    if not fs then
        fs = child:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetSpacing(2)
        lines[P.n] = fs
    end
    fs:SetFont(U.FONT, size or 11, flags or "")
    fs:SetTextColor(r or 0.9, g or 0.9, b or 0.92)
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    fs:SetWidth(child:GetWidth())
    fs:SetText(text)
    fs:Show()
    y = y - fs:GetStringHeight() - (gap or 8)
    return fs
end

local function head(text) return add(text, 11, U.A[1], U.A[2], U.A[3], 4, "OUTLINE") end

local function rewardsOf(id)
    local out = {}
    local xp = safe(GetQuestLogRewardXP, id)
    local money = safe(GetQuestLogRewardMoney, id)
    local bits = {}
    if xp and not secret(xp) and xp > 0 then bits[#bits + 1] = ("%s XP"):format(BreakUpLargeNumbers and BreakUpLargeNumbers(xp) or xp) end
    if money and not secret(money) and money > 0 and GetCoinTextureString then bits[#bits + 1] = GetCoinTextureString(money) end
    if #bits > 0 then out[#out + 1] = table.concat(bits, "    ") end
    local function items(count, info, label)
        local n = safe(count, id) or 0
        if n > 0 and label then out[#out + 1] = label end
        for i = 1, n do
            local name, tex, num = safe(info, i, id)
            if name and not secret(name) then
                out[#out + 1] = ("|T%s:16:16:0:0|t %s%s"):format(tex or 134400, name, (num and num > 1) and (" x" .. num) or "")
            end
        end
    end
    items(GetNumQuestLogRewards, GetQuestLogRewardInfo)
    items(GetNumQuestLogChoices, GetQuestLogChoiceInfo, "|cffffd200Choose one:|r")
    return out
end

function P:Render()
    if not (page and page:IsShown() and qid) then return end
    -- never twice at once: laying out the text can resize the page, whose size handler
    -- draws again; a nested draw mid-way doubled the text (seen in game 2026-11-07)
    if P.rendering then return end
    P.rendering = true
    local ok, err = pcall(P.Draw, P)
    P.rendering = false
    if not ok then geterrorhandler()(err) end
end

function P:Draw()
    for i = 1, #lines do lines[i]:Hide() end
    P.n, y = 0, -2
    local idx = safe(C_QuestLog.GetLogIndexForQuestID, qid)
    local info = idx and safe(C_QuestLog.GetInfo, idx)
    if not info then
        add("This quest is no longer in your log.", 11, 0.7, 0.7, 0.75)
        child:SetHeight(-y + 4)
        return
    end
    local r, g, b = levelColor(info.level)
    add(info.title or "?", 14, r, g, b, 4, "OUTLINE")
    local mapID = safe(GetQuestUiMapID, qid)
    local where = mapID and mapID > 0 and C_Map.GetMapInfo(mapID)
    add(("Level %d%s"):format(info.level or 0, where and (" · " .. where.name) or ""), 10, 0.6, 0.6, 0.66, 12)

    head(safe(C_QuestLog.IsComplete, qid) and "Ready to turn in" or "Objectives")
    local desc, todo = safe(GetQuestLogQuestText, idx)
    local objs = safe(C_QuestLog.GetQuestObjectives, qid) or {}
    if #objs > 0 then
        for _, o in ipairs(objs) do
            if o.text and o.text ~= "" then
                if o.finished then add("|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t " .. o.text, 11, 0.4, 1, 0.4, 3)
                else add("- " .. o.text, 11, 0.92, 0.92, 0.95, 3) end
            end
        end
        y = y - 6
    end
    if todo and not secret(todo) and todo ~= "" then add(todo, 11, 1, 1, 1, 12) end

    if desc and not secret(desc) and desc ~= "" then
        head("Description")
        add(desc, 11, 0.85, 0.85, 0.88, 12)
    end

    local rw = rewardsOf(qid)
    if #rw > 0 then
        head("Rewards")
        for _, l in ipairs(rw) do add(l, 11, 0.92, 0.92, 0.95, 4) end
    end
    child:SetHeight(-y + 8)
    page.track:SetLabel(C_SuperTrack.GetSuperTrackedQuestID() == qid and "Tracking" or "Track")
    page.track:SetSelected(C_SuperTrack.GetSuperTrackedQuestID() == qid)
    page.share:SetShown(C_QuestLog.IsPushableQuest and safe(C_QuestLog.IsPushableQuest, qid) and IsInGroup() or false)
end

function P:Show(id)
    if not page or not id then return false end
    qid = id
    page:Show()
    body:SetVerticalScroll(0)
    P:Render()
    return true
end

function P:Hide() if page then page:Hide() end end
function P:Shown() return page and page:IsShown() end

-- Called by Quests.lua on layout: the page covers the quest list exactly.
function P:Place(listPanel, shown)
    if not page then return end
    page:ClearAllPoints()
    page:SetAllPoints(listPanel)
    if not shown then page:Hide() end
end

function M.ShowQuest(id)
    if not (id and page) then return false end
    if not safe(C_QuestLog.GetLogIndexForQuestID, id) then return false end
    local c = M:Config()
    if not c.questPanel then c.questPanel = true end
    local mapID = safe(GetQuestUiMapID, id)
    if not W:IsShown() then
        if InCombatLockdown() or not OpenWorldMap then return false end   -- the game won't open it in combat
        OpenWorldMap(mapID and mapID > 0 and mapID or nil)
        if not W:IsShown() then return false end
    elseif mapID and mapID > 0 and W.GetMapID and W:GetMapID() ~= mapID and W.SetMapID then
        -- already open: go to this quest's zone too (the user, 2026-11-09: right-clicking a second
        -- quest showed its page but left the map on the first quest's zone)
        pcall(W.SetMapID, W, mapID)
    end
    if ns.Frame then ns.Frame:Layout() end
    return P:Show(id)
end

M:OnReady(function()
    W = WorldMapFrame
    page = CreateFrame("Frame", nil, W)
    page:SetFrameLevel(W.ScrollContainer:GetFrameLevel() + 40)
    page:EnableMouse(true)
    U.Fill(page, U.BAR[1], U.BAR[2], U.BAR[3], 1):SetAllPoints()
    local edge = U.Fill(page, U.A[1], U.A[2], U.A[3], 0.35, "BORDER")
    edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
    page:Hide()

    local back = U.Button(page, "< Quests", nil, 20, function() P:Hide() end, { "Back to your quests" })
    back:SetPoint("TOPLEFT", 8, -5)
    page.back = back

    body = CreateFrame("ScrollFrame", nil, page)
    body:SetPoint("TOPLEFT", 10, -32)
    body:SetPoint("BOTTOMRIGHT", -8, 34)
    child = CreateFrame("Frame", nil, body)
    child:SetSize(1, 1)
    body:SetScrollChild(child)
    body:SetScript("OnSizeChanged", function(self, w)
        child:SetWidth(w)
        C_Timer.After(0, function() P:Render() end)   -- after this layout pass
    end)
    body:EnableMouseWheel(true)
    body:SetScript("OnMouseWheel", function(self, d)
        local max = math.max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(max, self:GetVerticalScroll() - d * 40)))
    end)

    -- bottom buttons
    page.track = U.Button(page, "Track", 70, 20, function()
        if not qid then return end
        if C_SuperTrack.GetSuperTrackedQuestID() == qid then
            C_SuperTrack.SetSuperTrackedQuestID(0)
        else
            if C_QuestLog.AddQuestWatch then C_QuestLog.AddQuestWatch(qid) end
            C_SuperTrack.SetSuperTrackedQuestID(qid)
        end
        P:Render()
    end, { "Track", "The arrow points at this quest. Click again to stop." })
    page.track:SetPoint("BOTTOMLEFT", 8, 8)
    page.share = U.Button(page, "Share", 60, 20, function()
        if not qid then return end
        if InCombatLockdown() then M:Print("You can share quests after the fight."); return end
        local idx = C_QuestLog.GetLogIndexForQuestID(qid)   -- Blizzard's own QuestUtil.ShareQuest does this
        if idx and QuestLogPushQuest then QuestLogPushQuest(idx) end
    end, { "Share", "Offer this quest to your group." })
    page.share:SetPoint("LEFT", page.track, "RIGHT", 6, 0)
    -- Blizzard's own flow (QuestMapQuestOptions_AbandonQuest): select, mark, ask (the items
    -- version when the quest carries items), then put the old selection back. Leaving the
    -- abandoned quest selected is what the old version did.
    page.abandon = U.Button(page, "|cffff6060Abandon|r", 70, 20, function()
        if not qid then return end
        local old = C_QuestLog.GetSelectedQuest()
        C_QuestLog.SetSelectedQuest(qid)
        C_QuestLog.SetAbandonQuest()
        local title = safe(C_QuestLog.GetTitleForQuestID, C_QuestLog.GetAbandonQuest()) or ""
        local names = {}
        for _, item in ipairs(safe(C_QuestLog.GetAbandonQuestItems) or {}) do
            local n = C_Item and C_Item.GetItemNameByID and safe(C_Item.GetItemNameByID, item)
            if n then names[#names + 1] = n end
        end
        if #names > 0 then
            StaticPopup_Hide("ABANDON_QUEST")
            StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", title, table.concat(names, ", "))
        else
            StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
            StaticPopup_Show("ABANDON_QUEST", title)
        end
        C_QuestLog.SetSelectedQuest(old or 0)
    end, { "Abandon", "Asks first (Blizzard's own confirmation)." })
    page.abandon:SetPoint("BOTTOMRIGHT", -8, 8)

    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "SUPER_TRACKING_CHANGED", "GROUP_ROSTER_UPDATE" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function()
        if not page:IsShown() then return end
        -- the quest left the log (abandoned, turned in): back to the list, like Blizzard's own
        -- details panel (QuestMapFrame_ReturnFromQuestDetails)
        if qid and not safe(C_QuestLog.GetLogIndexForQuestID, qid) then
            qid = nil
            P:Hide()
            if ns.Quests and ns.Quests.Refresh then ns.Quests:Refresh() end
            return
        end
        P:Render()
    end)
end)
