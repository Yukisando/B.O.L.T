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
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
    
    self.optionsPanel = panel
end

function Config:ShowConfig()
    -- Open the Interface Options to the ColdSnap panel
    if Settings and Settings.OpenToCategory then
        Settings.OpenToCategory("ColdSnap")
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    else
        self.parent:Print("Please open Interface > AddOns > ColdSnap to access settings.")
    end
end

-- Register the module
ColdSnap:RegisterModule("Config", Config)
