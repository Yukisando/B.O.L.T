-- B.O.L.T Admin Module
-- Password-protected admin panel for hidden features

local ADDON_NAME, BOLT = ...

local Admin = {}
local ADMIN_PASSWORD = "prout"

function Admin:OnInitialize()
    self.authenticated = false

    -- Register slash command
    SLASH_BOLTADMIN1 = "/boltadmin"
    SlashCmdList["BOLTADMIN"] = function(msg)
        self:ShowPasswordPopup()
    end

    -- Defer hooksecurefunc to PLAYER_LOGIN. Calling hooksecurefunc during ADDON_LOADED
    -- runs during Blizzard's secure UI initialisation phase. In Midnight (12.0) this taints
    -- GameMenuFrame_Setup, causing every GameMenuButton.callback to be tainted and
    -- ADDON_ACTION_FORBIDDEN when the user clicks Log Out / Disconnect.
    -- (See NameplatesEnhancement.lua for the same pattern and explanation.)
    local deferFrame = CreateFrame("Frame")
    deferFrame:RegisterEvent("PLAYER_LOGIN")
    deferFrame:SetScript("OnEvent", function()
        deferFrame:UnregisterAllEvents()
        deferFrame:SetScript("OnEvent", nil)
        self:SetupPasswordDetection()
    end)
end

function Admin:OnEnable()
    -- Module enabled
end

function Admin:SetupPasswordDetection()
    -- Hook into the chat edit box to detect password typing
    if not self.chatHooked then
        hooksecurefunc("ChatEdit_SendText", function(editBox, addHistory)
            local text = editBox:GetText()
            if text and string.lower(text) == ADMIN_PASSWORD then
                -- Clear the chat box to prevent sending the password
                editBox:SetText("")
                -- Show the admin panel directly (password was typed)
                self:OnPasswordCorrect()
                return
            end
        end)
        self.chatHooked = true
    end
end

function Admin:ShowPasswordPopup()
    if self.passwordPopup and self.passwordPopup:IsShown() then
        self.passwordPopup:Hide()
        return
    end
    
    if not self.passwordPopup then
        self:CreatePasswordPopup()
    end
    
    self.passwordPopup.input:SetText("")
    self.passwordPopup:Show()
    self.passwordPopup.input:SetFocus()
end

function Admin:CreatePasswordPopup()
    local popup = CreateFrame("Frame", "BOLTAdminPasswordPopup", UIParent, "BackdropTemplate")
    popup:SetSize(300, 120)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    popup:SetBackdropColor(0, 0, 0, 1)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()
    
    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Admin Access")
    
    -- Password input
    local input = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    input:SetPoint("CENTER", popup, "CENTER", 0, 0)
    input:SetSize(200, 20)
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetTextInsets(0, 0, 3, 3)
    popup.input = input
    
    -- Make password hidden
    input:SetScript("OnChar", function(self, char)
        -- We could mask with asterisks but for simplicity, just let them type
    end)
    
    input:SetScript("OnEnterPressed", function(self)
        Admin:CheckPassword()
    end)
    
    input:SetScript("OnEscapePressed", function(self)
        popup:Hide()
    end)
    
    -- Submit button
    local submitBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    submitBtn:SetSize(80, 22)
    submitBtn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 15)
    submitBtn:SetText("Enter")
    submitBtn:SetScript("OnClick", function()
        Admin:CheckPassword()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    
    tinsert(UISpecialFrames, "BOLTAdminPasswordPopup")
    
    self.passwordPopup = popup
end

function Admin:CheckPassword()
    local input = self.passwordPopup.input:GetText()
    if input and string.lower(input) == ADMIN_PASSWORD then
        self.passwordPopup:Hide()
        self:OnPasswordCorrect()
    else
        -- Wrong password - shake the popup
        if self.parent and self.parent.Print then
            self.parent:Print("|cFFFF0000Invalid password|r")
        end
        self.passwordPopup.input:SetText("")
    end
end

function Admin:OnPasswordCorrect()
    self.authenticated = true
    self:ShowAdminPanel()
end

function Admin:ShowAdminPanel()
    if self.adminPanel and self.adminPanel:IsShown() then
        self.adminPanel:Hide()
        return
    end
    
    if not self.adminPanel then
        self:CreateAdminPanel()
    end
    
    self:RefreshAdminPanel()
    self.adminPanel:Show()
end

function Admin:CreateAdminPanel()
    -- Channel options for dropdowns
    local channelOptions = {
        { value = "say", label = "Say" },
        { value = "yell", label = "Yell" },
        { value = "party", label = "Party" },
        { value = "raid", label = "Raid" },
        { value = "instance", label = "Instance" },
        { value = "whisper", label = "Whisper" },
    }
    
    local function GetChannelLabel(value)
        for _, opt in ipairs(channelOptions) do
            if opt.value == value then return opt.label end
        end
        return "Yell"
    end
    
    local panel = CreateFrame("Frame", "BOLTAdminPanel", UIParent, "BackdropTemplate")
    panel:SetSize(400, 420)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    panel:SetFrameStrata("DIALOG")
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    panel:SetBackdropColor(0.1, 0.1, 0.1, 1)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -20)
    title:SetText("|cFFFF0000B.O.L.T Admin Panel|r")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -5)
    subtitle:SetText("Configure hidden trolling features")
    
    local yOffset = -65
    
    -- Dismount Trigger
    local dismountLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dismountLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    dismountLabel:SetText("Dismount Trigger Word:")
    
    local dismountInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    dismountInput:SetPoint("LEFT", dismountLabel, "RIGHT", 10, 0)
    dismountInput:SetSize(150, 20)
    dismountInput:SetAutoFocus(false)
    dismountInput:SetMaxLetters(50)
    panel.dismountInput = dismountInput
    
    yOffset = yOffset - 30
    
    -- Dismount Channel Dropdown (Multi-select)
    local dismountChannelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dismountChannelLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    dismountChannelLabel:SetText("Dismount Channels:")
    
    local dismountChannelDropdown = CreateFrame("Button", "BOLTAdminDismountChannelDropdown", panel, "UIPanelButtonTemplate")
    dismountChannelDropdown:SetSize(160, 22)
    dismountChannelDropdown:SetPoint("LEFT", dismountChannelLabel, "RIGHT", 5, -2)
    panel.dismountChannelDropdown = dismountChannelDropdown
    panel.selectedDismountChannels = { yell = true }  -- Multi-select table

    local function UpdateDismountDropdownText()
        local selected = {}
        for _, opt in ipairs(channelOptions) do
            if panel.selectedDismountChannels[opt.value] then
                table.insert(selected, opt.label)
            end
        end
        dismountChannelDropdown:SetText(#selected > 0 and table.concat(selected, ", ") or "None")
    end
    UpdateDismountDropdownText()

    dismountChannelDropdown:SetScript("OnClick", function(btn)
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            for _, opt in ipairs(channelOptions) do
                local o = opt
                rootDescription:CreateCheckbox(o.label,
                    function() return panel.selectedDismountChannels[o.value] or false end,
                    function()
                        panel.selectedDismountChannels[o.value] = not (panel.selectedDismountChannels[o.value] or false)
                        UpdateDismountDropdownText()
                    end
                )
            end
        end)
    end)
    panel.UpdateDismountDropdownText = UpdateDismountDropdownText
    
    yOffset = yOffset - 35
    
    -- Hardcore Activate Trigger
    local activateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activateLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    activateLabel:SetText("Hardcore Activate Trigger:")
    
    local activateInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    activateInput:SetPoint("LEFT", activateLabel, "RIGHT", 10, 0)
    activateInput:SetSize(150, 20)
    activateInput:SetAutoFocus(false)
    activateInput:SetMaxLetters(50)
    panel.activateInput = activateInput
    
    yOffset = yOffset - 35
    
    -- Hardcore Deactivate Trigger
    local deactivateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    deactivateLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    deactivateLabel:SetText("Hardcore Deactivate Trigger:")
    
    local deactivateInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    deactivateInput:SetPoint("LEFT", deactivateLabel, "RIGHT", 10, 0)
    deactivateInput:SetSize(150, 20)
    deactivateInput:SetAutoFocus(false)
    deactivateInput:SetMaxLetters(50)
    panel.deactivateInput = deactivateInput
    
    yOffset = yOffset - 35
    
    -- Hardcore Mode Chat Message
    local msgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    msgLabel:SetText("Hardcore Enable Chat Msg:")
    
    local msgInput = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    msgInput:SetPoint("LEFT", msgLabel, "RIGHT", 10, 0)
    msgInput:SetSize(150, 20)
    msgInput:SetAutoFocus(false)
    msgInput:SetMaxLetters(100)
    panel.hardcoreEnableMsgInput = msgInput
    
    yOffset = yOffset - 35
    
    -- Hardcore Mode Disable Chat Message
    local msgLabel2 = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msgLabel2:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    msgLabel2:SetText("Hardcore Disable Chat Msg:")
    
    local msgInput2 = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    msgInput2:SetPoint("LEFT", msgLabel2, "RIGHT", 10, 0)
    msgInput2:SetSize(150, 20)
    msgInput2:SetAutoFocus(false)
    msgInput2:SetMaxLetters(100)
    panel.hardcoreDisableMsgInput = msgInput2
    
    yOffset = yOffset - 30
    
    -- Hardcore Channel Dropdown (Multi-select)
    local hardcoreChannelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hardcoreChannelLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    hardcoreChannelLabel:SetText("Hardcore Channels:")
    
    local hardcoreChannelDropdown = CreateFrame("Button", "BOLTAdminHardcoreChannelDropdown", panel, "UIPanelButtonTemplate")
    hardcoreChannelDropdown:SetSize(160, 22)
    hardcoreChannelDropdown:SetPoint("LEFT", hardcoreChannelLabel, "RIGHT", 5, -2)
    panel.hardcoreChannelDropdown = hardcoreChannelDropdown
    panel.selectedHardcoreChannels = { yell = true }  -- Multi-select table

    local function UpdateHardcoreDropdownText()
        local selected = {}
        for _, opt in ipairs(channelOptions) do
            if panel.selectedHardcoreChannels[opt.value] then
                table.insert(selected, opt.label)
            end
        end
        hardcoreChannelDropdown:SetText(#selected > 0 and table.concat(selected, ", ") or "None")
    end
    UpdateHardcoreDropdownText()

    hardcoreChannelDropdown:SetScript("OnClick", function(btn)
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            for _, opt in ipairs(channelOptions) do
                local o = opt
                rootDescription:CreateCheckbox(o.label,
                    function() return panel.selectedHardcoreChannels[o.value] or false end,
                    function()
                        panel.selectedHardcoreChannels[o.value] = not (panel.selectedHardcoreChannels[o.value] or false)
                        UpdateHardcoreDropdownText()
                    end
                )
            end
        end)
    end)
    panel.UpdateHardcoreDropdownText = UpdateHardcoreDropdownText
    
    yOffset = yOffset - 45
    
    -- Status display
    local statusLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    statusLabel:SetText("Hardcore Mode: |cFF888888Inactive|r")
    panel.statusLabel = statusLabel
    
    yOffset = yOffset - 20
    
    -- Keybind info
    local keybindInfo = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    keybindInfo:SetPoint("TOPLEFT", panel, "TOPLEFT", 25, yOffset)
    keybindInfo:SetText("|cFFAAAAAAKeybinds:|r Ctrl+Shift+F1 = Enter  |  Ctrl+Shift+F2 = Exit")
    
    yOffset = yOffset - 35
    
    -- Buttons row
    local saveBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    saveBtn:SetSize(120, 24)
    saveBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 20)
    saveBtn:SetText("Save & Quit")
    saveBtn:SetScript("OnClick", function()
        Admin:SaveSettings()
        panel:Hide()
    end)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
    
    tinsert(UISpecialFrames, "BOLTAdminPanel")
    
    self.adminPanel = panel
end

function Admin:RefreshAdminPanel()
    if not self.adminPanel then return end
    
    local cfg = self:GetAdminConfig()
    
    self.adminPanel.dismountInput:SetText(cfg.dismountTrigger or "oops")
    self.adminPanel.activateInput:SetText(cfg.hardcoreActivateTrigger or "carrot")
    self.adminPanel.deactivateInput:SetText(cfg.hardcoreDeactivateTrigger or "feta")
    self.adminPanel.hardcoreEnableMsgInput:SetText(cfg.hardcoreEnableMsg or "Hardcore mode activated!")
    self.adminPanel.hardcoreDisableMsgInput:SetText(cfg.hardcoreDisableMsg or "Hardcore mode deactivated!")
    
    -- Update channel multi-selects
    local dismountChannels = cfg.dismountChannels or { yell = true }
    self.adminPanel.selectedDismountChannels = {}
    for k, v in pairs(dismountChannels) do
        self.adminPanel.selectedDismountChannels[k] = v
    end
    self.adminPanel.UpdateDismountDropdownText()
    
    local hardcoreChannels = cfg.hardcoreChannels or { yell = true }
    self.adminPanel.selectedHardcoreChannels = {}
    for k, v in pairs(hardcoreChannels) do
        self.adminPanel.selectedHardcoreChannels[k] = v
    end
    self.adminPanel.UpdateHardcoreDropdownText()
    
    -- Update status
    local specialGamemode = BOLT.modules.specialGamemode
    if specialGamemode and specialGamemode:IsHardcoreModeActive() then
        self.adminPanel.statusLabel:SetText("Hardcore Mode: |cFFFF0000ACTIVE|r")
    else
        self.adminPanel.statusLabel:SetText("Hardcore Mode: |cFF00FF00Inactive|r")
    end
end

function Admin:SaveSettings()
    if not self.adminPanel then return end
    
    local cfg = {
        dismountTrigger = self.adminPanel.dismountInput:GetText() or "oops",
        dismountChannels = self.adminPanel.selectedDismountChannels or { yell = true },
        hardcoreActivateTrigger = self.adminPanel.activateInput:GetText() or "carrot",
        hardcoreDeactivateTrigger = self.adminPanel.deactivateInput:GetText() or "feta",
        hardcoreChannels = self.adminPanel.selectedHardcoreChannels or { yell = true },
        hardcoreEnableMsg = self.adminPanel.hardcoreEnableMsgInput:GetText() or "Hardcore mode activated!",
        hardcoreDisableMsg = self.adminPanel.hardcoreDisableMsgInput:GetText() or "Hardcore mode deactivated!"
    }
    
    if BOLTDB and BOLTDB.profile then
        BOLTDB.profile.admin = cfg
    end
    
    if self.parent and self.parent.Print then
        self.parent:Print("|cFF00FF00Admin settings saved!|r")
    end
    
    -- Apply to SpecialGamemode immediately
    local specialGamemode = BOLT.modules.specialGamemode
    if specialGamemode and specialGamemode.UpdateTriggers then
        specialGamemode:UpdateTriggers()
    end
end

function Admin:GetAdminConfig()
    if BOLTDB and BOLTDB.profile and BOLTDB.profile.admin then
        return BOLTDB.profile.admin
    end
    return {
        dismountTrigger = "oops",
        dismountChannels = { yell = true },
        hardcoreActivateTrigger = "carrot",
        hardcoreDeactivateTrigger = "feta",
        hardcoreChannels = { yell = true },
        hardcoreEnableMsg = "Hardcore mode activated!",
        hardcoreDisableMsg = "Hardcore mode deactivated!"
    }
end

function Admin:GetChannelLabel(value)
    local channelLabels = {
        say = "Say",
        yell = "Yell",
        party = "Party",
        raid = "Raid",
        instance = "Instance",
        whisper = "Whisper",
    }
    return channelLabels[value] or "Yell"
end

-- Convert channels table to list of selected channel names
function Admin:GetSelectedChannelsList(channelsTable)
    local list = {}
    for channel, enabled in pairs(channelsTable or {}) do
        if enabled then
            table.insert(list, channel)
        end
    end
    return list
end

-- Register the module
BOLT:RegisterModule("admin", Admin)
