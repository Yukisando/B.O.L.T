-- B.O.L.T Admin Module
-- Password-protected panel for the hidden prank features (see SpecialGamemode).
-- Open it with /boltadmin, or by typing the password into the chat box.

local ADDON_NAME, BOLT = ...

local Admin = {
    displayName = "Admin",
    alwaysOn = true,
}

local ADMIN_PASSWORD = "prout"
local LABEL_X, INPUT_X = 25, 215

local function Gamemode()
    return BOLT.modules.specialGamemode
end

local function IsPassword(text)
    return type(text) == "string" and strtrim(text):lower() == ADMIN_PASSWORD
end

---------------------------------------------------------------------------
-- Password entry
---------------------------------------------------------------------------

function Admin:CreatePasswordPopup()
    local popup = BOLT:CreateDialog("BOLTAdminPasswordPopup", 300, 120, "Admin Access")
    popup:SetPoint("CENTER", 0, 100)

    local input = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    input:SetPoint("CENTER")
    input:SetSize(200, 20)
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetScript("OnEnterPressed", function() self:CheckPassword() end)
    input:SetScript("OnEscapePressed", function() popup:Hide() end)
    popup.input = input

    local enter = BOLT:CreateButton(popup, "Enter", 80, 22, function() self:CheckPassword() end)
    enter:SetPoint("BOTTOM", 0, 15)

    self.passwordPopup = popup
end

function Admin:ShowPasswordPopup()
    if not self.passwordPopup then
        self:CreatePasswordPopup()
    end
    local popup = self.passwordPopup
    if popup:IsShown() then
        popup:Hide()
        return
    end
    popup.input:SetText("")
    popup:Show()
    popup.input:SetFocus()
end

function Admin:CheckPassword()
    local popup = self.passwordPopup
    if IsPassword(popup.input:GetText()) then
        popup:Hide()
        self:ShowAdminPanel()
    else
        BOLT:Print("|cffff0000Invalid password|r")
        popup.input:SetText("")
    end
end

---------------------------------------------------------------------------
-- Admin panel
---------------------------------------------------------------------------

local function ChannelSummary(channels)
    local selected = {}
    for _, channel in ipairs(Gamemode().CHANNELS) do
        if channels[channel.value] then
            table.insert(selected, channel.label)
        end
    end
    return #selected > 0 and table.concat(selected, ", ") or "None"
end

function Admin:CreateAdminPanel()
    local panel = BOLT:CreateDialog("BOLTAdminPanel", 420, 440, "|cffff0000B.O.L.T Admin Panel|r")
    panel:SetPoint("CENTER", 0, 50)
    panel:SetBackdropColor(0.1, 0.1, 0.1, 1)
    panel.fields = {}
    panel.channelButtons = {}

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", panel.title, "BOTTOM", 0, -5)
    subtitle:SetText("Configure hidden trolling features")

    local y = -60
    local function Label(text)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", LABEL_X, y)
        label:SetText(text)
    end

    local enabled = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    enabled:SetPoint("TOPLEFT", LABEL_X - 4, y + 4)
    local enabledLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    enabledLabel:SetText("Chat triggers enabled")
    panel.triggersEnabled = enabled
    y = y - 32

    local function TextField(key, label, maxLetters)
        Label(label)
        local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
        input:SetPoint("TOPLEFT", INPUT_X, y + 4)
        input:SetSize(170, 20)
        input:SetAutoFocus(false)
        input:SetMaxLetters(maxLetters)
        panel.fields[key] = input
        y = y - 32
    end

    local function ChannelField(key, label)
        Label(label)
        local button = BOLT:CreateButton(panel, "", 175, 22)
        button:SetPoint("TOPLEFT", INPUT_X - 6, y + 4)
        button:SetScript("OnClick", function()
            MenuUtil.CreateContextMenu(button, function(_, root)
                for _, channel in ipairs(Gamemode().CHANNELS) do
                    root:CreateCheckbox(channel.label,
                        function() return panel.channels[key][channel.value] == true end,
                        function()
                            panel.channels[key][channel.value] = not panel.channels[key][channel.value] or nil
                            button:SetText(ChannelSummary(panel.channels[key]))
                        end)
                end
            end)
        end)
        panel.channelButtons[key] = button
        y = y - 32
    end

    TextField("dismountTrigger", "Dismount trigger word:", 50)
    ChannelField("dismountChannels", "Dismount channels:")
    TextField("hardcoreActivateTrigger", "Hardcore activate trigger:", 50)
    TextField("hardcoreDeactivateTrigger", "Hardcore deactivate trigger:", 50)
    ChannelField("hardcoreChannels", "Hardcore channels:")
    TextField("hardcoreEnableMsg", "Hardcore enable message:", 100)
    TextField("hardcoreDisableMsg", "Hardcore disable message:", 100)

    y = y - 8
    panel.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    panel.status:SetPoint("TOPLEFT", LABEL_X, y)

    local hotkeys = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hotkeys:SetPoint("TOPLEFT", LABEL_X, y - 20)
    hotkeys:SetText("|cffaaaaaaHotkeys:|r Ctrl+Shift+F1 = Enter  |  Ctrl+Shift+F2 = Exit")

    local save = BOLT:CreateButton(panel, "Save & Close", 120, 24, function()
        self:SaveSettings()
        panel:Hide()
    end)
    save:SetPoint("BOTTOM", 0, 20)

    self.adminPanel = panel
end

function Admin:RefreshAdminPanel()
    local panel = self.adminPanel
    local settings = Gamemode():GetSettings()

    panel.triggersEnabled:SetChecked(settings.triggersEnabled)
    for key, input in pairs(panel.fields) do
        input:SetText(settings[key] or "")
    end
    -- Edit copies so Close without saving discards channel changes.
    panel.channels = {}
    for key, button in pairs(panel.channelButtons) do
        panel.channels[key] = CopyTable(settings[key])
        button:SetText(ChannelSummary(panel.channels[key]))
    end

    if Gamemode():IsHardcoreModeActive() then
        panel.status:SetText("Hardcore mode: |cffff0000ACTIVE|r")
    else
        panel.status:SetText("Hardcore mode: |cff00ff00Inactive|r")
    end
end

function Admin:SaveSettings()
    local panel = self.adminPanel
    local settings = Gamemode():GetSettings()

    settings.triggersEnabled = panel.triggersEnabled:GetChecked()
    for key, input in pairs(panel.fields) do
        local text = strtrim(input:GetText())
        settings[key] = text ~= "" and text or Gamemode().DEFAULTS[key]
    end
    for key, channels in pairs(panel.channels) do
        settings[key] = channels
    end
    BOLT:Print("|cff00ff00Admin settings saved.|r")
end

function Admin:ShowAdminPanel()
    if not self.adminPanel then
        self:CreateAdminPanel()
    end
    self:RefreshAdminPanel()
    self.adminPanel:Show()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Admin:OnInitialize()
    -- Blizzard's sanctioned hook for editing chat text right before it is sent.
    -- Clearing the text here means the password never reaches the chat channel.
    EventRegistry:RegisterCallback("ChatFrame.OnEditBoxPreSendText", function(_, editBox)
        if IsPassword(editBox:GetText()) then
            editBox:SetText("")
            C_Timer.After(0, function() self:ShowAdminPanel() end)
        end
    end, self)
end

SLASH_BOLTADMIN1 = "/boltadmin"
SlashCmdList.BOLTADMIN = function()
    Admin:ShowPasswordPopup()
end

BOLT:RegisterModule("admin", Admin)
