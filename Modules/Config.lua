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

function Config:CreateStandaloneConfigFrame()
    -- Ensure any existing frame is properly cleaned up
    if configFrame then
        configFrame:Hide()
        configFrame = nil
    end
    
    -- Create a standalone config window that we can reliably open
    configFrame = CreateFrame("Frame", "ColdSnapConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    configFrame:SetSize(520, 650)
    configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    configFrame:SetMovable(true)
    configFrame:EnableMouse(true)
    configFrame:RegisterForDrag("LeftButton")
    configFrame:SetScript("OnDragStart", configFrame.StartMoving)
    configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
    configFrame:SetFrameStrata("DIALOG")
    configFrame:SetFrameLevel(100)
    configFrame:Hide() -- Ensure it starts hidden
    
    -- Set the title
    configFrame.title = configFrame:CreateFontString(nil, "OVERLAY")
    configFrame.title:SetFontObject("GameFontHighlight")
    configFrame.title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 5, 0)
    configFrame.title:SetText("ColdSnap Settings")
    
    -- Create close button functionality
    configFrame.CloseButton:SetScript("OnClick", function()
        configFrame:Hide()
    end)
    
    -- Create scroll frame within the inset area
    local scrollFrame = CreateFrame("ScrollFrame", "ColdSnapConfigScrollFrame", configFrame.Inset, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", configFrame.Inset, "TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", configFrame.Inset, "BOTTOMRIGHT", -26, 8)
    
    -- Create content frame with fixed width
    local contentFrame = CreateFrame("Frame", "ColdSnapConfigContentFrame", scrollFrame)
    contentFrame:SetWidth(460) -- Fixed width to prevent sizing issues
    contentFrame:SetHeight(100) -- Start small, will grow as needed
    scrollFrame:SetScrollChild(contentFrame)
    
    -- Store references for content creation
    configFrame.scrollFrame = scrollFrame
    configFrame.contentFrame = contentFrame
    
    -- Create the content
    self:CreateStandaloneContent()
    
    self.configFrame = configFrame
end

function Config:CreateStandaloneContent()
    -- Get the content frame from the scroll frame
    local content = configFrame.contentFrame
    if not content then
        self.parent:Debug("Error: No content frame found")
        return
    end
    
    local yOffset = -20
    
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
    
    -- Mythic Plus Module Section
    local mythicPlusHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicPlusHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    mythicPlusHeader:SetText("Mythic Plus Enhancements")
    yOffset = yOffset - 30
    
    -- Enable/Disable Mythic Plus Module
    local mythicPlusCheckbox = CreateFrame("CheckButton", "ColdSnapStandaloneMythicPlusCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    local autoReadyCheckbox = CreateFrame("CheckButton", "ColdSnapStandaloneAutoReadyCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    yOffset = yOffset - 25
    
    -- Description for Auto Ready Check
    local autoReadyDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    autoReadyDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    autoReadyDesc:SetText("Automatically initiates a ready check when you insert a keystone as group leader")
    autoReadyDesc:SetTextColor(0.8, 0.8, 0.8)
    autoReadyDesc:SetWidth(350)
    autoReadyDesc:SetJustifyH("LEFT")
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
    yOffset = yOffset - 40
    
    -- Reload UI Button
    local reloadButton = CreateFrame("Button", "ColdSnapStandaloneReloadButton", content, "UIPanelButtonTemplate")
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
    yOffset = yOffset - 30
    
    -- Set the content frame height based on actual content
    local contentHeight = math.abs(yOffset) + 40 -- Add some padding at the bottom
    content:SetHeight(contentHeight)
end

function Config:ShowConfig()
    -- Show our standalone config window
    if not self.configFrame then
        self.parent:Print("Configuration window not available. Try /reload and then /cs again.")
        return
    end
    
    -- Ensure it's properly positioned and visible
    self.configFrame:ClearAllPoints()
    self.configFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.configFrame:Show()
    self.configFrame:Raise()
end

function Config:HideConfig()
    if self.configFrame and self.configFrame:IsShown() then
        self.configFrame:Hide()
    end
end

function Config:ToggleConfig()
    if not self.configFrame then
        self.parent:Print("Configuration window not available. Try /reload and then /cs again.")
        return
    end
    
    if self.configFrame:IsShown() then
        self:HideConfig()
    else
        self:ShowConfig()
    end
end

-- Register the module
ColdSnap:RegisterModule("Config", Config)
