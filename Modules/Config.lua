-- ColdSnap Configuration UI
-- Settings interface for easy module management

local ADDON_NAME, ColdSnap = ...

-- Create the Config module
local Config = {}

function Config:OnInitialize()
    self.parent:Debug("Config module initializing...")
    self:CreateInterfaceOptionsPanel()
    -- Don't create standalone frame during init
end

function Config:OnEnable()
    self.parent:Debug("Config module enabling...")
end

function Config:CreateInterfaceOptionsPanel()
    -- Create the main options panel that integrates with WoW's Interface > AddOns
    local panel = CreateFrame("Frame", "ColdSnapOptionsPanel")
    panel.name = "ColdSnap"
    
    -- For Interface Options, use a simpler approach without scroll frame initially
    -- Most interface options panels don't actually need scrolling
    local content = panel
    
    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("ColdSnap")
    
    -- Subtitle
    local subtitle = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Quality of life improvements for World of Warcraft")
    
    local yOffset = -60
    
    -- Game Menu Module Section
    local gameMenuHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gameMenuHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    gameMenuHeader:SetText("Game Menu Enhancements")
    yOffset = yOffset - 30
    
    -- Enable/Disable Game Menu Module
    local gameMenuCheckbox = CreateFrame("CheckButton", "ColdSnapGameMenuCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    local leaveGroupCheckbox = CreateFrame("CheckButton", "ColdSnapLeaveGroupCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    yOffset = yOffset - 30
    
    -- Show Reload UI Button
    local reloadCheckbox = CreateFrame("CheckButton", "ColdSnapReloadCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    yOffset = yOffset - 40
    
    -- Mythic Plus Module Section
    local mythicPlusHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicPlusHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    mythicPlusHeader:SetText("Mythic Plus Enhancements")
    yOffset = yOffset - 30
    
    -- Enable/Disable Mythic Plus Module
    local mythicPlusCheckbox = CreateFrame("CheckButton", "ColdSnapMythicPlusCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    mythicPlusCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    mythicPlusCheckbox.Text:SetText("Enable Mythic Plus Module")
    mythicPlusCheckbox:SetScript("OnShow", function()
        mythicPlusCheckbox:SetChecked(self.parent:IsModuleEnabled("mythicPlus"))
    end)
    mythicPlusCheckbox:SetScript("OnClick", function()
        local enabled = mythicPlusCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "enabled")
        self.parent:Print("Mythic Plus module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
    
    -- Auto Ready Check
    local autoReadyCheckbox = CreateFrame("CheckButton", "ColdSnapAutoReadyCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    autoReadyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    autoReadyCheckbox.Text:SetText("Auto ready check when inserting key")
    autoReadyCheckbox:SetScript("OnShow", function()
        autoReadyCheckbox:SetChecked(self.parent:GetConfig("mythicPlus", "autoReadyCheck"))
    end)
    autoReadyCheckbox:SetScript("OnClick", function()
        local enabled = autoReadyCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "autoReadyCheck")
        self.parent:Print("Auto ready check " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 40
       
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
    commandsText:SetText("/coldsnap or /cs - Show help and commands")
    commandsText:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 40
    
    -- Reload UI Button
    local reloadButton = CreateFrame("Button", "ColdSnapOptionsReloadButton", content, "UIPanelButtonTemplate")
    reloadButton:SetSize(120, 25)
    reloadButton:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    yOffset = yOffset - 40
    
    -- Version info
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
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

-- Completely new standalone config window implementation
function Config:CreateConfigWindow()
    -- Destroy any existing window first
    if self.configWindow then
        self.configWindow:Hide()
        self.configWindow:SetParent(nil)
        self.configWindow = nil
    end
    
    -- Create main window frame using a different approach
    local window = CreateFrame("Frame", "ColdSnapConfigWindow", UIParent)
    window:SetSize(500, 600)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetFrameLevel(100)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:Hide()
    
    -- Create background
    local bg = window:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.8)
    
    -- Create border
    local border = window:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0.3, 0.3, 0.3, 1)
    
    -- Create inner background
    local innerBg = window:CreateTexture(nil, "ARTWORK")
    innerBg:SetPoint("TOPLEFT", 2, -2)
    innerBg:SetPoint("BOTTOMRIGHT", -2, 2)
    innerBg:SetColorTexture(0.1, 0.1, 0.1, 1)
    
    -- Title bar
    local titleBar = window:CreateTexture(nil, "OVERLAY")
    titleBar:SetPoint("TOPLEFT", 2, -2)
    titleBar:SetPoint("TOPRIGHT", -2, -2)
    titleBar:SetHeight(30)
    titleBar:SetColorTexture(0.2, 0.2, 0.2, 1)
    
    -- Title text
    local titleText = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleText:SetText("ColdSnap Settings")
    titleText:SetTextColor(1, 1, 1)
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, window)
    closeButton:SetSize(28, 28)
    closeButton:SetPoint("RIGHT", titleBar, "RIGHT", -5, 0)
    closeButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    closeButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    closeButton:SetScript("OnClick", function()
        self:HideConfig()
    end)
    
    -- Content area
    local contentArea = CreateFrame("Frame", nil, window)
    contentArea:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 10, -10)
    contentArea:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -10, 10)
    
    window.contentArea = contentArea
    self.configWindow = window
    
    return window
end

function Config:PopulateConfigWindow()
    if not self.configWindow or not self.configWindow.contentArea then
        return
    end
    
    local content = self.configWindow.contentArea
    
    -- Clear existing content
    for i = 1, content:GetNumChildren() do
        local child = select(i, content:GetChildren())
        if child then
            child:Hide()
            child:SetParent(nil)
        end
    end
    
    local yPos = -10
    
    -- Game Menu Section
    local gameMenuHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gameMenuHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yPos)
    gameMenuHeader:SetText("Game Menu Enhancements")
    gameMenuHeader:SetTextColor(1, 0.8, 0)
    yPos = yPos - 30
    
    -- Game Menu Enable Checkbox
    local gameMenuCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    gameMenuCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yPos)
    gameMenuCheck.Text:SetText("Enable Game Menu Module")
    gameMenuCheck:SetChecked(self.parent:IsModuleEnabled("gameMenu"))
    gameMenuCheck:SetScript("OnClick", function()
        local enabled = gameMenuCheck:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "enabled")
        self.parent:Print("Game Menu module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yPos = yPos - 30
    
    -- Leave Group Button Checkbox
    local leaveGroupCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yPos)
    leaveGroupCheck.Text:SetText("Show Leave Group/Delve Button")
    leaveGroupCheck:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
    leaveGroupCheck:SetScript("OnClick", function()
        local enabled = leaveGroupCheck:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showLeaveGroup")
        self.parent:Print("Leave Group button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yPos = yPos - 40
    
    -- Reload UI Button Checkbox
    local reloadUICheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    reloadUICheck:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yPos)
    reloadUICheck.Text:SetText("Show Reload UI Button")
    reloadUICheck:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
    reloadUICheck:SetScript("OnClick", function()
        local enabled = reloadUICheck:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showReloadButton")
        self.parent:Print("Reload UI button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yPos = yPos - 50
    
    -- Mythic Plus Section
    local mythicHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yPos)
    mythicHeader:SetText("Mythic Plus Enhancements")
    mythicHeader:SetTextColor(1, 0.8, 0)
    yPos = yPos - 30
    
    -- Mythic Plus Enable Checkbox
    local mythicCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    mythicCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yPos)
    mythicCheck.Text:SetText("Enable Mythic Plus Module")
    mythicCheck:SetChecked(self.parent:IsModuleEnabled("mythicPlus"))
    mythicCheck:SetScript("OnClick", function()
        local enabled = mythicCheck:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "enabled")
        self.parent:Print("Mythic Plus module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yPos = yPos - 30
    
    -- Auto Ready Check Checkbox
    local autoReadyCheck = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    autoReadyCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yPos)
    autoReadyCheck.Text:SetText("Auto ready check when inserting key")
    autoReadyCheck:SetChecked(self.parent:GetConfig("mythicPlus", "autoReadyCheck"))
    autoReadyCheck:SetScript("OnClick", function()
        local enabled = autoReadyCheck:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "autoReadyCheck")
        self.parent:Print("Auto ready check " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yPos = yPos - 50
    
    -- Commands Section
    local commandsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yPos)
    commandsHeader:SetText("Console Commands")
    commandsHeader:SetTextColor(1, 0.8, 0)
    yPos = yPos - 30
    
    local commandsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    commandsText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yPos)
    commandsText:SetText("/cs - Open this window    /cs status - Show module status")
    commandsText:SetTextColor(0.8, 0.8, 0.8)
    yPos = yPos - 40
    
    -- Reload Button
    local reloadButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    reloadButton:SetSize(100, 25)
    reloadButton:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yPos)
    reloadButton:SetText("Reload UI")
    reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    yPos = yPos - 40
    
    -- Version
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yPos)
    versionText:SetText("ColdSnap v" .. self.parent.version)
    versionText:SetTextColor(0.5, 0.5, 0.5)
end

function Config:ShowConfig()
    if not self.configWindow then
        self:CreateConfigWindow()
    end
    
    self:PopulateConfigWindow()
    self.configWindow:Show()
    self.configWindow:Raise()
end

function Config:HideConfig()
    if self.configWindow then
        self.configWindow:Hide()
    end
end

function Config:ToggleConfig()
    if not self.configWindow or not self.configWindow:IsShown() then
        self:ShowConfig()
    else
        self:HideConfig()
    end
end

-- Register the module
ColdSnap:RegisterModule("Config", Config)
