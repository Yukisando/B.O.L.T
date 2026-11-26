-- B.O.L.T Mail Address Book Module (2026-11-26)
-- At a mailbox: opens your bags, and a small "Recent" list beside the Send Mail tab shows the last
-- characters you sent mail to. Click a name to put it in the To field. The list is account-wide
-- (BOLTDB.mailRecipients, most recent first), so every character sees the same names.

local ADDON_NAME, BOLT = ...

local MailBook = {
    displayName = "Mail Address Book",
}

local MAX_NAMES = 5
local ROW = 18
local WIDTH = 150

local function List()
    BOLTDB.mailRecipients = BOLTDB.mailRecipients or {}
    return BOLTDB.mailRecipients
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$")
end

local function Remember(name)
    name = Trim(name)
    if name == "" then return end
    local list = List()
    for i = #list, 1, -1 do
        if list[i]:lower() == name:lower() then table.remove(list, i) end
    end
    table.insert(list, 1, name)
    while #list > MAX_NAMES do table.remove(list) end
end

local function Forget(name)
    local list = List()
    for i = #list, 1, -1 do
        if list[i] == name then table.remove(list, i) end
    end
end

---------------------------------------------------------------------------
-- The "Recent" list beside the Send Mail tab
---------------------------------------------------------------------------

local panel

local function Fill(name)
    local box = SendMailNameEditBox
    if not box then return end
    box:SetText(name)
    box:SetCursorPosition(#name)
    if SendMailSubjectEditBox then SendMailSubjectEditBox:SetFocus() end
end

local function Refresh()
    if not panel then return end
    local list = List()
    local show = MailBook.active and #list > 0 and SendMailFrame and SendMailFrame:IsShown()
    panel:SetShown(show and true or false)
    if not show then return end
    for i, row in ipairs(panel.rows) do
        local name = list[i]
        row.name = name
        row.text:SetText(name or "")
        row:SetShown(name ~= nil)
    end
    panel:SetHeight(28 + #list * ROW)
end

local function BuildPanel()
    if panel or not (SendMailFrame and MailFrame) then return end
    panel = CreateFrame("Frame", nil, SendMailFrame, "BackdropTemplate")
    panel:SetWidth(WIDTH)
    panel:SetPoint("TOPLEFT", MailFrame, "TOPRIGHT", 4, -24)
    if BACKDROP_TOOLTIP_16_16_5555 then
        panel:SetBackdrop(BACKDROP_TOOLTIP_16_16_5555)
        panel:SetBackdropColor(0, 0, 0, 0.85)
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 10, -8)
    title:SetText("Recent")

    panel.rows = {}
    for i = 1, MAX_NAMES do
        local row = CreateFrame("Button", nil, panel)
        row:SetHeight(ROW)
        row:SetPoint("TOPLEFT", 6, -20 - (i - 1) * ROW)
        row:SetPoint("TOPRIGHT", -6, -20 - (i - 1) * ROW)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", 4, 0)
        text:SetPoint("RIGHT", -4, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        row.text = text
        local glow = row:CreateTexture(nil, "HIGHLIGHT")
        glow:SetAllPoints()
        glow:SetColorTexture(1, 0.82, 0, 0.15)
        row:SetScript("OnClick", function(self, button)
            if not self.name then return end
            if button == "RightButton" then
                Forget(self.name)
                Refresh()
            else
                Fill(self.name)
            end
        end)
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.name or "", 1, 1, 1)
            GameTooltip:AddLine("Click to send to this character.", nil, nil, nil, true)
            GameTooltip:AddLine("Right-click to take it off the list.", nil, nil, nil, true)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        panel.rows[i] = row
    end

    SendMailFrame:HookScript("OnShow", Refresh)
    panel:Hide()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function MailBook:OnInitialize()
    -- A send can fail (unknown name, no money): the name is only kept once the mail has gone.
    if SendMail then
        hooksecurefunc("SendMail", function(recipient) self.pending = recipient end)
    end

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "MAIL_SHOW" then
            BuildPanel()
            if self.active and BOLT:GetConfig("mailBook", "openBags") then
                -- After Blizzard's own mail handling, so the bags open beside the mail frame.
                C_Timer.After(0, function()
                    if MailFrame and MailFrame:IsShown() then OpenAllBags(MailFrame) end
                end)
            end
            Refresh()
        elseif event == "MAIL_CLOSED" then
            if self.active and BOLT:GetConfig("mailBook", "openBags") and MailFrame then
                CloseAllBags(MailFrame)
            end
            self.pending = nil
        elseif event == "MAIL_SEND_SUCCESS" then
            if self.pending then Remember(self.pending) end
            self.pending = nil
            Refresh()
        elseif event == "MAIL_FAILED" then
            self.pending = nil
        end
    end)
    for _, event in ipairs({ "MAIL_SHOW", "MAIL_CLOSED", "MAIL_SEND_SUCCESS", "MAIL_FAILED" }) do
        self.eventFrame:RegisterEvent(event)
    end
end

function MailBook:ClearList()
    wipe(List())
    Refresh()
end

function MailBook:OnEnable()
    Refresh()
end

function MailBook:OnDisable()
    Refresh()
end

BOLT:RegisterModule("mailBook", MailBook)
