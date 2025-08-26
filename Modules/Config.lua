-- ColdSnap Configuration UI
-- Settings interface for easy module management

local ADDON_NAME, ColdSnap = ...

-- Create the Config module
local Config = {}

-- Reference to the config frame
local configFrame = nil

function Config:OnInitialize()
    self.parent:Debug("Config module initializing...")
    self:CreateInterfaceOptionsPanel()
    self:CreateStandaloneConfigFrame()
end

function Config:OnEnable()
    self.parent:Debug("Config module enabling...")
end

function Config:CreateInterfaceOptionsPanel()
    -- Create the main options panel that integrates with WoW's Interface > AddOns
    local panel = CreateFrame("Frame", "ColdSnapOptionsPanel")
    panel.name = "ColdSnap"
    
    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ColdSnap")
    
    -- Subtitle
    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Quality of life improvements for World of Warcraft")
    
    local yOffset = -60
    
    -- Game Menu Module Section
    local gameMenuHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gameMenuHeader:SetPoint("TOPLEFT", 20, yOffset)
    gameMenuHeader:SetText("Game Menu Enhancements")
    yOffset = yOffset - 30
    
    -- Enable/Disable Game Menu Module
    local gameMenuCheckbox = CreateFrame("CheckButton", "ColdSnapGameMenuCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    gameMenuCheckbox:SetPoint("TOPLEFT", 30, yOffset)
    gameMenuCheckbox.Text:SetText("Enable Game Menu Module")
    gameMenuCheckbox:SetScript("OnShow", function()
        gameMenuCheckbox:SetChecked(self.parent:IsModuleEnabled("gameMenu"))
    end)
    gameMenuCheckbox:SetScript("OnClick", function()
        local enabled = gameMenuCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "enabled")
        self.parent:Print("Game Menu module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
    
    -- Show Leave Group Button
    local leaveGroupCheckbox = CreateFrame("CheckButton", "ColdSnapLeaveGroupCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupCheckbox:SetPoint("TOPLEFT", 50, yOffset)
    leaveGroupCheckbox.Text:SetText("Show Leave Group/Delve Button")
    leaveGroupCheckbox:SetScript("OnShow", function()
        leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
    end)
    leaveGroupCheckbox:SetScript("OnClick", function()
        local enabled = leaveGroupCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showLeaveGroup")
        self.parent:Print("Leave Group button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
    
    -- Show Reload UI Button
    local reloadCheckbox = CreateFrame("CheckButton", "ColdSnapReloadCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    reloadCheckbox:SetPoint("TOPLEFT", 50, yOffset)
    reloadCheckbox.Text:SetText("Show Reload UI Button")
    reloadCheckbox:SetScript("OnShow", function()
        reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
    end)
    reloadCheckbox:SetScript("OnClick", function()
        local enabled = reloadCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showReloadButton")
        self.parent:Print("Reload UI button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
       
    -- Future modules section
    local futureHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    futureHeader:SetPoint("TOPLEFT", 20, yOffset)
    futureHeader:SetText("Future Modules")
    futureHeader:SetTextColor(0.6, 0.6, 0.6)
    yOffset = yOffset - 25
    
    local futureText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    futureText:SetPoint("TOPLEFT", 30, yOffset)
    futureText:SetText("More quality of life modules will be added here...")
    futureText:SetTextColor(0.6, 0.6, 0.6)
    yOffset = yOffset - 60
    
    -- Console commands section
    local commandsHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsHeader:SetPoint("TOPLEFT", 20, yOffset)
    commandsHeader:SetText("Console Commands")
    yOffset = yOffset - 25
    
    local commandsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    commandsText:SetPoint("TOPLEFT", 30, yOffset)
    commandsText:SetText("/coldsnap or /cs - Show help and commands")
    commandsText:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 20
    
    -- Reload UI Button
    local reloadButton = CreateFrame("Button", "ColdSnapOptionsReloadButton", panel, "UIPanelButtonTemplate")
    reloadButton:SetSize(120, 25)
    reloadButton:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 30, 30)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    
    -- Version info
    local versionText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -20, 20)
    versionText:SetText("ColdSnap v" .. self.parent.version)
    versionText:SetTextColor(0.5, 0.5, 0.5)
    
    -- Register with Settings (modern) or InterfaceOptions (legacy)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "ColdSnap")
        self.settingsCategory = category
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    
    self.optionsPanel = panel
end

function Config:CreateStandaloneConfigFrame()
    -- Create a standalone config window that we can reliably open
    configFrame = CreateFrame("Frame", "ColdSnapConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(450, 400)
    configFrame:SetPoint("CENTER")
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:Hide()
    
    -- Set the title
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY")
    configFrame.title:SetFontObject("GameFontHighlight")
    configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
    configFrame.title:SetText("ColdSnap Settings")
    
    -- Create close button functionality
    configFrame.CloseButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    -- Debug: Print what children the frame has
    self.parent:Debug("Frame children: " .. tostring(configFrame.Inset))
    
    -- Create the content
    self:CreateStandaloneContent()
    
    self.configFrame = configFrame
end

function Config:CreateStandaloneContent()
    -- Find the content area - try Inset first, then fall back to the main frame
    local content = configFrame.Inset
    if not content then
        -- Create our own content area if Inset doesn't exist
        content = CreateFrame("Frame", nil, configFrame)
        content:SetPoint("TOPLEFT", configFrame, "TOPLEFT", 10, -30)
        content:SetPoint("BOTTOMRIGHT", configFrame, "BOTTOMRIGHT", -10, 10)
    end
    
    local yOffset = -30
    
    -- Header
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOP", content, "TOP", 0, yOffset)
    header:SetText("ColdSnap Configuration")
    yOffset = yOffset - 40
    
    -- Game Menu Module Section
    local gameMenuHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gameMenuHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    gameMenuHeader:SetText("Game Menu Enhancements")
    yOffset = yOffset - 30
    
    -- Enable/Disable Game Menu Module
    local gameMenuCheckbox = CreateFrame("CheckButton", "ColdSnapStandaloneGameMenuCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    gameMenuCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    gameMenuCheckbox.Text:SetText("Enable Game Menu Module")
    gameMenuCheckbox:SetScript("OnShow", function()
        gameMenuCheckbox:SetChecked(self.parent:IsModuleEnabled("gameMenu"))
    end)
    gameMenuCheckbox:SetScript("OnClick", function()
        local enabled = gameMenuCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "enabled")
        self.parent:Print("Game Menu module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
    
    -- Show Leave Group Button
    local leaveGroupCheckbox = CreateFrame("CheckButton", "ColdSnapStandaloneLeaveGroupCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    leaveGroupCheckbox.Text:SetText("Show Leave Group/Delve Button")
    leaveGroupCheckbox:SetScript("OnShow", function()
        leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
    end)
    leaveGroupCheckbox:SetScript("OnClick", function()
        local enabled = leaveGroupCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showLeaveGroup")
        self.parent:Print("Leave Group button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 25
    
    -- Description for Leave Group feature
    local leaveGroupDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    leaveGroupDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    leaveGroupDesc:SetText("Adds a Leave Group/Raid/Delve button below the ESC menu")
    leaveGroupDesc:SetTextColor(0.8, 0.8, 0.8)
    leaveGroupDesc:SetWidth(350)
    leaveGroupDesc:SetJustifyH("LEFT")
    yOffset = yOffset - 30
    
    -- Show Reload UI Button
    local reloadCheckbox = CreateFrame("CheckButton", "ColdSnapStandaloneReloadCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    reloadCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    reloadCheckbox.Text:SetText("Show Reload UI Button")
    reloadCheckbox:SetScript("OnShow", function()
        reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
    end)
    reloadCheckbox:SetScript("OnClick", function()
        local enabled = reloadCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showReloadButton")
        self.parent:Print("Reload UI button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 25
    
    -- Description for Reload Button
    local reloadDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    reloadDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    reloadDesc:SetText("Adds a Reload UI button in the top-right corner of the ESC menu")
    reloadDesc:SetTextColor(0.8, 0.8, 0.8)
    reloadDesc:SetWidth(350)
    reloadDesc:SetJustifyH("LEFT")
    yOffset = yOffset - 50
    
    -- Future modules section
    local futureHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    futureHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    futureHeader:SetText("Future Modules")
    futureHeader:SetTextColor(0.6, 0.6, 0.6)
    yOffset = yOffset - 25
    
    local futureText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    futureText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    futureText:SetText("More quality of life modules will be added here...")
    futureText:SetTextColor(0.6, 0.6, 0.6)
    yOffset = yOffset - 60
    
    -- Console commands section
    local commandsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    commandsHeader:SetText("Console Commands")
    yOffset = yOffset - 25
    
    local commandsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    commandsText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    commandsText:SetText("/cs - Open this window    /cs status - Show module status")
    commandsText:SetTextColor(1, 0.82, 0)
    
    -- Reload UI Button
    local reloadButton = CreateFrame("Button", "ColdSnapStandaloneReloadButton", content, "UIPanelButtonTemplate")
    reloadButton:SetSize(120, 25)
    reloadButton:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 30, 20)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    
    -- Version info
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -20, 15)
    versionText:SetText("ColdSnap v" .. self.parent.version)
    versionText:SetTextColor(0.5, 0.5, 0.5)
end

function Config:ShowConfig()
    -- Show our standalone config window
    if self.configFrame then
        self.configFrame:Show()
    else
        self.parent:Print("Configuration window not available. Try /reload and then /cs again.")
    end
end

function Config:HideConfig()
    if self.configFrame then
        self.configFrame:Hide()
    end
end

function Config:ToggleConfig()
    if self.configFrame then
        if self.configFrame:IsShown() then
            self.configFrame:Hide()
        else
            self.configFrame:Show()
        end
    end
end

-- Register the module
ColdSnap:RegisterModule("Config", Config)
