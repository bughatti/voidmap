----------------------------------------------------------------------
-- UI.lua — Void-style building blocks shared by VoidMap's files.
----------------------------------------------------------------------
local _, ns = ...
local U = {}
ns.UI = U

U.A = { 0, 0.78, 1 }   -- Void cyan
U.FONT = "Fonts\\FRIZQT__.TTF"
U.BG = { 0.05, 0.05, 0.07 }
U.BAR = { 0.07, 0.07, 0.09 }

function U.Text(parent, size, flags, layer)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(U.FONT, size or 11, flags or "")
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.92, 0.92, 0.95)
    fs:SetWordWrap(false)
    return fs
end

-- A filled rectangle on a frame.
function U.Fill(frame, r, g, b, a, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    t:SetColorTexture(r, g, b, a or 1)
    return t
end

-- 1-pixel cyan border made of four textures (works on any frame, no backdrop mixin).
function U.Border(frame, alpha, layer)
    local A = U.A
    local function edge() return U.Fill(frame, A[1], A[2], A[3], alpha or 0.55, layer or "BORDER") end
    local t, b, l, r = edge(), edge(), edge(), edge()
    t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
    b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
    return { t, b, l, r }
end

-- A small Void button: dark box, cyan edge, light text. width nil = fit the text.
function U.Button(parent, label, width, height, onClick, tip)
    local A = U.A
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height or 20)
    b.bg = U.Fill(b, 0.10, 0.12, 0.15, 1)
    b.bg:SetAllPoints()
    b.edges = U.Border(b, 0.45)
    b.text = U.Text(b, 10)
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    function b:SetLabel(s)
        self.text:SetText(s)
        if not width then self:SetWidth(math.max(20, self.text:GetStringWidth() + 14)) end
    end
    b:SetLabel(label or "")
    if width then b:SetWidth(width) end
    local function edgeAlpha(a) for _, e in ipairs(b.edges) do e:SetColorTexture(A[1], A[2], A[3], a) end end
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.18, 0.22, 0.28, 1)
        edgeAlpha(1)
        if self.tip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tip[1], 1, 1, 1)
            if self.tip[2] then GameTooltip:AddLine(self.tip[2], 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function(self)
        if not self.selected then
            self.bg:SetColorTexture(0.10, 0.12, 0.15, 1)
            edgeAlpha(0.45)
        end
        GameTooltip:Hide()
    end)
    function b:SetSelected(on)
        self.selected = on
        self.bg:SetColorTexture(on and A[1] * 0.3 or 0.10, on and A[2] * 0.3 or 0.12, on and A[3] * 0.3 or 0.15, 1)
        edgeAlpha(on and 1 or 0.45)
        self.text:SetTextColor(on and 1 or 0.85, on and 1 or 0.85, on and 1 or 0.9)
    end
    if tip then b.tip = tip end
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end
