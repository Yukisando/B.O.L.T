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
    
    -- Add OnShow script to refresh checkbox states
    panel:SetScript("OnShow", function()
        self:RefreshOptionsPanel()
    end)
    
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
        local enabled = self.parent:IsModuleEnabled("gameMenu")
        gameMenuCheckbox:SetChecked(enabled)
        -- Update child controls when shown
        self:UpdateGameMenuChildControls()
    end)
    gameMenuCheckbox:SetScript("OnClick", function()
        local enabled = gameMenuCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "enabled")
        self.parent:Print("Game Menu module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdateGameMenuChildControls()
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
    yOffset = yOffset - 30
    
    -- Show Favorite Toy Button
    local favoriteToyCheckbox = CreateFrame("CheckButton", "ColdSnapFavoriteToyCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    favoriteToyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    favoriteToyCheckbox.Text:SetText("Show Favorite Toy Button")
    favoriteToyCheckbox:SetScript("OnShow", function()
        favoriteToyCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showFavoriteToy"))
    end)
    favoriteToyCheckbox:SetScript("OnClick", function()
        local enabled = favoriteToyCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showFavoriteToy")
        self.parent:Print("Favorite Toy button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdateGameMenuChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Favorite Toy Selection
    local toyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    toyLabel:SetText("Favorite Toy:")
    yOffset = yOffset - 20
    
    local toyDropdown = CreateFrame("Frame", "ColdSnapFavoriteToyDropdown", content, "UIDropDownMenuTemplate")
    toyDropdown:SetPoint("TOPLEFT", content, "TOPLEFT", 40, yOffset)
    UIDropDownMenu_SetWidth(toyDropdown, 250)
    UIDropDownMenu_SetText(toyDropdown, "Select a toy...")
    
    -- Initialize dropdown
    UIDropDownMenu_Initialize(toyDropdown, function(self, level)
        local function OnToySelect(toyInfo)
            local toyId = toyInfo.value
            Config.parent:SetConfig(toyId, "gameMenu", "favoriteToyId")
            UIDropDownMenu_SetText(toyDropdown, toyInfo.text)
            Config.parent:Print("Favorite toy set to: " .. toyInfo.text)
            
            -- Update the secure toy button if it exists
            if Config.parent.modules.GameMenu and Config.parent.modules.GameMenu.UpdateFavoriteToyButton then
                Config.parent.modules.GameMenu:UpdateFavoriteToyButton()
            end
        end
        
        -- Get player's toys
        local toys = {}
        for i = 1, C_ToyBox.GetNumToys() do
            local toyId = C_ToyBox.GetToyFromIndex(i)
            if toyId and PlayerHasToy(toyId) then
                local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)
                if toyName then
                    table.insert(toys, {
                        text = toyName,
                        value = toyId,
                        icon = icon,
                        func = OnToySelect
                    })
                end
            end
        end
        
        -- Sort toys alphabetically
        table.sort(toys, function(a, b) return a.text < b.text end)
        
        -- Add "None" option
        local info = UIDropDownMenu_CreateInfo()
        info.text = "None"
        info.value = nil
        info.func = OnToySelect
        UIDropDownMenu_AddButton(info)
        
        -- Add separator
        info = UIDropDownMenu_CreateInfo()
        info.text = ""
        info.isTitle = true
        info.notClickable = true
        UIDropDownMenu_AddButton(info)
        
        -- Add toys
        for _, toy in ipairs(toys) do
            info = UIDropDownMenu_CreateInfo()
            info.text = toy.text
            info.value = toy.value
            info.icon = toy.icon
            info.func = function() OnToySelect(toy) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    -- Set current selection on show
    toyDropdown:SetScript("OnShow", function()
        local currentToyId = self.parent:GetConfig("gameMenu", "favoriteToyId")
        if currentToyId then
            local _, toyName = C_ToyBox.GetToyInfo(currentToyId)
            if toyName then
                UIDropDownMenu_SetText(toyDropdown, toyName)
            else
                UIDropDownMenu_SetText(toyDropdown, "Select a toy...")
            end
        else
            UIDropDownMenu_SetText(toyDropdown, "Select a toy...")
        end
    end)
    
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
    commandsText:SetText("/coldsnap or /cs - Open Interface Options to ColdSnap")
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

function Config:RefreshOptionsPanel()
    -- Small delay to ensure UI is ready
    C_Timer.After(0.05, function()
        -- Refresh all checkbox states in the main options panel
        local gameMenuCheckbox = _G["ColdSnapGameMenuCheckbox"]
        if gameMenuCheckbox then
            local enabled = self.parent:IsModuleEnabled("gameMenu")
            gameMenuCheckbox:SetChecked(enabled)
        end
        
        local leaveGroupCheckbox = _G["ColdSnapLeaveGroupCheckbox"]
        if leaveGroupCheckbox then
            leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
        end
        
        local reloadCheckbox = _G["ColdSnapReloadCheckbox"]
        if reloadCheckbox then
            reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
        end
        
        local favoriteToyCheckbox = _G["ColdSnapFavoriteToyCheckbox"]
        if favoriteToyCheckbox then
            favoriteToyCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showFavoriteToy"))
        end
        
        local toyDropdown = _G["ColdSnapFavoriteToyDropdown"]
        if toyDropdown then
            local currentToyId = self.parent:GetConfig("gameMenu", "favoriteToyId")
            if currentToyId then
                local _, toyName = C_ToyBox.GetToyInfo(currentToyId)
                if toyName then
                    UIDropDownMenu_SetText(toyDropdown, toyName)
                else
                    UIDropDownMenu_SetText(toyDropdown, "Select a toy...")
                end
            else
                UIDropDownMenu_SetText(toyDropdown, "Select a toy...")
            end
        end
        
        -- Update child control states
        self:UpdateGameMenuChildControls()
    end)
end

-- Update child control states based on parent module status
function Config:UpdateGameMenuChildControls()
    local gameMenuEnabled = self.parent:IsModuleEnabled("gameMenu")
    
    -- Get references to child controls
    local leaveGroupCheckbox = _G["ColdSnapLeaveGroupCheckbox"]
    local reloadCheckbox = _G["ColdSnapReloadCheckbox"]
    local favoriteToyCheckbox = _G["ColdSnapFavoriteToyCheckbox"]
    local toyDropdown = _G["ColdSnapFavoriteToyDropdown"]
    
    -- Enable/disable child controls based on parent module
    if leaveGroupCheckbox then
        leaveGroupCheckbox:SetEnabled(gameMenuEnabled)
        leaveGroupCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if reloadCheckbox then
        reloadCheckbox:SetEnabled(gameMenuEnabled)
        reloadCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if favoriteToyCheckbox then
        favoriteToyCheckbox:SetEnabled(gameMenuEnabled)
        favoriteToyCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if toyDropdown then
        local favoriteToyEnabled = gameMenuEnabled and self.parent:GetConfig("gameMenu", "showFavoriteToy")
        UIDropDownMenu_EnableDropDown(toyDropdown)
        if not favoriteToyEnabled then
            UIDropDownMenu_DisableDropDown(toyDropdown)
        end
        toyDropdown:SetAlpha(favoriteToyEnabled and 1.0 or 0.5)
    end
end

-- Register the module
ColdSnap:RegisterModule("Config", Config)
