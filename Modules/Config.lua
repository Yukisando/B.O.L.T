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
    
    -- Create a scroll frame for the content
    local scrollFrame = CreateFrame("ScrollFrame", "ColdSnapScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
    
    -- Create the scroll child (the actual content container)
    local content = CreateFrame("Frame", "ColdSnapScrollChild", scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 20, 1) -- Width minus scrollbar space, height will be set dynamically
    scrollFrame:SetScrollChild(content)
    
    -- Store references for later use
    self.scrollFrame = scrollFrame
    self.scrollChild = content
    
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
    
    -- Add separator line after Game Menu module
    local gameMenuSeparator = content:CreateTexture(nil, "ARTWORK")
    gameMenuSeparator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    gameMenuSeparator:SetSize(400, 8)
    gameMenuSeparator:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset - 10)
    yOffset = yOffset - 30
    
    -- Mythic Plus Module Section
    local mythicPlusHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mythicPlusHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    mythicPlusHeader:SetText("Mythic Plus Module")
    yOffset = yOffset - 30
    
    -- Enable/Disable Mythic Plus Module
    local mythicPlusCheckbox = CreateFrame("CheckButton", "ColdSnapMythicPlusCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    mythicPlusCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    mythicPlusCheckbox.Text:SetText("Enable Mythic Plus Module")
    mythicPlusCheckbox:SetScript("OnShow", function()
        local enabled = self.parent:IsModuleEnabled("mythicPlus")
        mythicPlusCheckbox:SetChecked(enabled)
        -- Update child controls when shown
        self:UpdateMythicPlusChildControls()
    end)
    mythicPlusCheckbox:SetScript("OnClick", function()
        local enabled = mythicPlusCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "enabled")
        self.parent:Print("Mythic Plus module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdateMythicPlusChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Show Ready Check Button
    local readyCheckCheckbox = CreateFrame("CheckButton", "ColdSnapReadyCheckCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    readyCheckCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    readyCheckCheckbox.Text:SetText("Show Ready Check & Countdown Buttons")
    readyCheckCheckbox:SetScript("OnShow", function()
        readyCheckCheckbox:SetChecked(self.parent:GetConfig("mythicPlus", "showReadyCheckButton"))
    end)
    readyCheckCheckbox:SetScript("OnClick", function()
        local enabled = readyCheckCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "mythicPlus", "showReadyCheckButton")
        self.parent:Print("Mythic Plus buttons " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30
    
    -- Description text for Mythic Plus module
    local mythicPlusDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mythicPlusDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    mythicPlusDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, yOffset)
    mythicPlusDesc:SetText("Adds ready check and countdown timer buttons to the keystone window for quick group coordination.")
    mythicPlusDesc:SetTextColor(0.8, 0.8, 0.8)
    mythicPlusDesc:SetJustifyH("LEFT")
    mythicPlusDesc:SetWordWrap(true)
    yOffset = yOffset - 45
    
    -- Add separator line after Mythic Plus module
    local mythicPlusSeparator = content:CreateTexture(nil, "ARTWORK")
    mythicPlusSeparator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    mythicPlusSeparator:SetSize(400, 8)
    mythicPlusSeparator:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset - 10)
    yOffset = yOffset - 30
    
    -- Skyriding Module Section
    local skyridingHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skyridingHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    skyridingHeader:SetText("Skyriding Module")
    yOffset = yOffset - 30
    
    -- Enable/Disable Skyriding Module
    local skyridingCheckbox = CreateFrame("CheckButton", "ColdSnapSkyridingCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    skyridingCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    skyridingCheckbox.Text:SetText("Enable Skyriding Module")
    skyridingCheckbox:SetScript("OnShow", function()
        local enabled = self.parent:IsModuleEnabled("skyriding")
        skyridingCheckbox:SetChecked(enabled)
        -- Update child controls when shown
        self:UpdateSkyridingChildControls()
    end)
    skyridingCheckbox:SetScript("OnClick", function()
        local enabled = skyridingCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "enabled")
        self.parent:Print("Skyriding module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdateSkyridingChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Enable Pitch Control Checkbox
    local pitchControlCheckbox = CreateFrame("CheckButton", "ColdSnapPitchControlCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    pitchControlCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    pitchControlCheckbox.Text:SetText("Enable pitch control (W/S for up/down movement)")
    pitchControlCheckbox:SetScript("OnShow", function()
        pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl"))
    end)
    pitchControlCheckbox:SetScript("OnClick", function()
        local enabled = pitchControlCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "enablePitchControl")
        self.parent:Print("Skyriding pitch control " .. (enabled and "enabled" or "disabled") .. ".")
        -- Update child controls when toggled
        self:UpdateSkyridingChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Invert Pitch Checkbox
    local invertPitchCheckbox = CreateFrame("CheckButton", "ColdSnapInvertPitchCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    invertPitchCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    invertPitchCheckbox.Text:SetText("Invert pitch (W=dive, S=climb)")
    invertPitchCheckbox:SetScript("OnShow", function()
        invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding", "invertPitch"))
    end)
    invertPitchCheckbox:SetScript("OnClick", function()
        local enabled = invertPitchCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "invertPitch")
        self.parent:Print("Skyriding pitch " .. (enabled and "inverted" or "normal") .. ".")
    end)
    yOffset = yOffset - 30
    
    -- Description text for Skyriding module
    local skyridingDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skyridingDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    skyridingDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, yOffset)
    skyridingDesc:SetText("Changes strafe keybinds to horizontal movement. Optionally remaps W/S to pitch up/down for full 3D control while skyriding.")
    skyridingDesc:SetTextColor(0.8, 0.8, 0.8)
    skyridingDesc:SetJustifyH("LEFT")
    skyridingDesc:SetWordWrap(true)
    yOffset = yOffset - 45
    
    -- Add separator line after Skyriding module
    local skyridingSeparator = content:CreateTexture(nil, "ARTWORK")
    skyridingSeparator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    skyridingSeparator:SetSize(400, 8)
    skyridingSeparator:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset - 10)
    yOffset = yOffset - 30
    
    -- Playground Module Section
    local playgroundHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    playgroundHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    playgroundHeader:SetText("Playground Module (Fun Features)")
    yOffset = yOffset - 30
    
    -- Enable/Disable Playground Module
    local playgroundCheckbox = CreateFrame("CheckButton", "ColdSnapPlaygroundCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    playgroundCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    playgroundCheckbox.Text:SetText("Enable Playground Module")
    playgroundCheckbox:SetScript("OnShow", function()
        local enabled = self.parent:IsModuleEnabled("playground")
        playgroundCheckbox:SetChecked(enabled)
        -- Update child controls when shown
        self:UpdatePlaygroundChildControls()
    end)
    playgroundCheckbox:SetScript("OnClick", function()
        local enabled = playgroundCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "playground", "enabled")
        self.parent:Print("Playground module " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdatePlaygroundChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Show Favorite Toy Button
    local favoriteToyCheckbox = CreateFrame("CheckButton", "ColdSnapFavoriteToyCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    favoriteToyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    favoriteToyCheckbox.Text:SetText("Show Favorite Toy Button")
    favoriteToyCheckbox:SetScript("OnShow", function()
        favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground", "showFavoriteToy"))
    end)
    favoriteToyCheckbox:SetScript("OnClick", function()
        local enabled = favoriteToyCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "playground", "showFavoriteToy")
        self.parent:Print("Favorite Toy button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
        -- Update child controls when toggled
        self:UpdatePlaygroundChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Favorite Toy Selection (only show if feature is enabled)
    local toyLabel = content:CreateFontString("ColdSnapToyLabel", "OVERLAY", "GameFontNormal")
    toyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    toyLabel:SetText("Favorite Toy:")
    yOffset = yOffset - 25
    
    -- Create a custom toy selection frame with search
    self:CreateToySelectionFrame(content, 50, yOffset)
    yOffset = yOffset - 200  -- Reserve space for the larger toy selection frame
    
    -- Add separator line after Playground module
    local playgroundSeparator = content:CreateTexture(nil, "ARTWORK")
    playgroundSeparator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    playgroundSeparator:SetSize(400, 8)
    playgroundSeparator:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset - 10)
    yOffset = yOffset - 30
       
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
    yOffset = yOffset - 30
    
    -- Set the scroll child height based on total content height
    content:SetHeight(math.abs(yOffset) + 100) -- Add some padding at the bottom
    
    -- Update content width when scroll frame size changes
    scrollFrame:SetScript("OnSizeChanged", function(frame, width, height)
        content:SetWidth(width - 20) -- Account for scrollbar
    end)
    
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
        
        local mythicPlusCheckbox = _G["ColdSnapMythicPlusCheckbox"]
        if mythicPlusCheckbox then
            local enabled = self.parent:IsModuleEnabled("mythicPlus")
            mythicPlusCheckbox:SetChecked(enabled)
        end
        
        local readyCheckCheckbox = _G["ColdSnapReadyCheckCheckbox"]
        if readyCheckCheckbox then
            readyCheckCheckbox:SetChecked(self.parent:GetConfig("mythicPlus", "showReadyCheckButton"))
        end
        
        local playgroundCheckbox = _G["ColdSnapPlaygroundCheckbox"]
        if playgroundCheckbox then
            local enabled = self.parent:IsModuleEnabled("playground")
            playgroundCheckbox:SetChecked(enabled)
        end
        
        local favoriteToyCheckbox = _G["ColdSnapFavoriteToyCheckbox"]
        if favoriteToyCheckbox then
            favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground", "showFavoriteToy"))
        end
        
        local skyridingCheckbox = _G["ColdSnapSkyridingCheckbox"]
        if skyridingCheckbox then
            local enabled = self.parent:IsModuleEnabled("skyriding")
            skyridingCheckbox:SetChecked(enabled)
        end
        
        local pitchControlCheckbox = _G["ColdSnapPitchControlCheckbox"]
        if pitchControlCheckbox then
            pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl"))
        end
        
        local invertPitchCheckbox = _G["ColdSnapInvertPitchCheckbox"]
        if invertPitchCheckbox then
            invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding", "invertPitch"))
        end
        
        -- Update toy selection frame
        if self.allToys then
            self:PopulateToyList()
        end
        self:UpdateToySelection()
        
        -- Update child control states
        self:UpdateGameMenuChildControls()
        self:UpdatePlaygroundChildControls()
        self:UpdateSkyridingChildControls()
    end)
end

-- Update child control states based on parent module status
function Config:UpdateGameMenuChildControls()
    local gameMenuEnabled = self.parent:IsModuleEnabled("gameMenu")
    
    -- Get references to child controls
    local leaveGroupCheckbox = _G["ColdSnapLeaveGroupCheckbox"]
    local reloadCheckbox = _G["ColdSnapReloadCheckbox"]
    
    -- Enable/disable child controls based on parent module
    if leaveGroupCheckbox then
        leaveGroupCheckbox:SetEnabled(gameMenuEnabled)
        leaveGroupCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if reloadCheckbox then
        reloadCheckbox:SetEnabled(gameMenuEnabled)
        reloadCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
end

-- Update child control states for Mythic Plus module
function Config:UpdateMythicPlusChildControls()
    local mythicPlusEnabled = self.parent:IsModuleEnabled("mythicPlus")
    
    -- Get references to child controls
    local readyCheckCheckbox = _G["ColdSnapReadyCheckCheckbox"]
    
    -- Enable/disable child controls based on parent module
    if readyCheckCheckbox then
        readyCheckCheckbox:SetEnabled(mythicPlusEnabled)
        readyCheckCheckbox:SetAlpha(mythicPlusEnabled and 1.0 or 0.5)
    end
end

-- Update child control states for Playground module
function Config:UpdatePlaygroundChildControls()
    local playgroundEnabled = self.parent:IsModuleEnabled("playground")
    
    -- Get references to child controls
    local favoriteToyCheckbox = _G["ColdSnapFavoriteToyCheckbox"]
    local toyFrame = _G["ColdSnapToySelectionFrame"]
    local toyLabel = _G["ColdSnapToyLabel"]
    
    -- Enable/disable child controls based on parent module
    if favoriteToyCheckbox then
        favoriteToyCheckbox:SetEnabled(playgroundEnabled)
        favoriteToyCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end
    
    -- Show/hide toy selection based on both module and feature being enabled
    local favoriteToyEnabled = playgroundEnabled and self.parent:GetConfig("playground", "showFavoriteToy")
    
    if toyLabel then
        if favoriteToyEnabled then
            toyLabel:Show()
        else
            toyLabel:Hide()
        end
    end
    
    if toyFrame then
        if favoriteToyEnabled then
            toyFrame:Show()
        else
            toyFrame:Hide()
        end
        
        -- Enable/disable interaction with toy frame components
        if self.searchBox then
            self.searchBox:SetEnabled(favoriteToyEnabled)
        end
        
        if self.currentToyButton then
            self.currentToyButton:SetEnabled(favoriteToyEnabled)
        end
        
        -- Enable/disable toy list buttons
        for _, button in pairs(self.toyButtons or {}) do
            button:SetEnabled(favoriteToyEnabled)
        end
    end
end

-- Update child control states for Skyriding module
function Config:UpdateSkyridingChildControls()
    local skyridingEnabled = self.parent:IsModuleEnabled("skyriding")
    local pitchControlEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
    
    -- Get references to child controls
    local pitchControlCheckbox = _G["ColdSnapPitchControlCheckbox"]
    local invertPitchCheckbox = _G["ColdSnapInvertPitchCheckbox"]
    
    -- Enable/disable child controls based on parent module
    if pitchControlCheckbox then
        pitchControlCheckbox:SetEnabled(skyridingEnabled)
        pitchControlCheckbox:SetAlpha(skyridingEnabled and 1.0 or 0.5)
    end
    
    if invertPitchCheckbox then
        -- Invert pitch is only available when both skyriding and pitch control are enabled
        local shouldEnable = skyridingEnabled and pitchControlEnabled
        invertPitchCheckbox:SetEnabled(shouldEnable)
        invertPitchCheckbox:SetAlpha(shouldEnable and 1.0 or 0.5)
    end
end

function Config:CreateToySelectionFrame(parent, xOffset, yOffset)
    -- Create the main container frame
    local toyFrame = CreateFrame("Frame", "ColdSnapToySelectionFrame", parent)
    toyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    toyFrame:SetSize(420, 170)
    
    -- Create a background
    local bg = toyFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)
    
    -- Create border
    local border = CreateFrame("Frame", nil, toyFrame, "DialogBorderTemplate")
    border:SetAllPoints()
    
    -- Search box
    local searchLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -15)
    searchLabel:SetText("Search:")
    
    local searchBox = CreateFrame("EditBox", "ColdSnapToySearchBox", toyFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", searchLabel, "TOPRIGHT", 15, 0)
    searchBox:SetSize(220, 20)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function()
        self:FilterToyList()
    end)
    
    -- Clear search button
    local clearButton = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate")
    clearButton:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    clearButton:SetSize(50, 22)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function()
        searchBox:SetText("")
        self:FilterToyList()
    end)
    
    -- Current selection display
    local currentLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -50)
    currentLabel:SetText("Current:")
    
    local currentToy = CreateFrame("Button", "ColdSnapCurrentToyButton", toyFrame)
    currentToy:SetPoint("LEFT", currentLabel, "RIGHT", 15, 0)
    currentToy:SetSize(220, 28)
    
    -- Create textures for current toy button
    local currentBg = currentToy:CreateTexture(nil, "BACKGROUND")
    currentBg:SetAllPoints()
    currentBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
    
    local currentIcon = currentToy:CreateTexture(nil, "ARTWORK")
    currentIcon:SetPoint("LEFT", currentToy, "LEFT", 4, 0)
    currentIcon:SetSize(20, 20)
    
    local currentText = currentToy:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentText:SetPoint("LEFT", currentIcon, "RIGHT", 8, 0)
    currentText:SetPoint("RIGHT", currentToy, "RIGHT", -8, 0)
    currentText:SetJustifyH("LEFT")
    currentText:SetText("None selected")
    
    currentToy:SetScript("OnClick", function()
        -- Clear selection
        self.parent:SetConfig(nil, "playground", "favoriteToyId")
        self:UpdateToySelection()
        if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then
            self.parent.modules.playground:UpdateFavoriteToyButton()
        end
    end)
    
    -- Scrollable toy list
    local scrollFrame = CreateFrame("ScrollFrame", "ColdSnapToyScrollFrame", toyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -85)
    scrollFrame:SetPoint("BOTTOMRIGHT", toyFrame, "BOTTOMRIGHT", -35, 15)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetSize(370, 1) -- Height will be set dynamically
    
    -- Store references for later use
    self.toyFrame = toyFrame
    self.searchBox = searchBox
    self.currentToyButton = currentToy
    self.currentToyIcon = currentIcon
    self.currentToyText = currentText
    self.scrollFrame = scrollFrame
    self.scrollChild = scrollChild
    self.toyButtons = {}
    
    -- Initial setup
    self:PopulateToyList()
    self:UpdateToySelection()
end

function Config:PopulateToyList()
    if not self.scrollChild then return end
    
    -- Clear existing buttons
    for _, button in pairs(self.toyButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    self.toyButtons = {}
    
    -- Get all toys
    self.allToys = {}
    for i = 1, C_ToyBox.GetNumToys() do
        local toyId = C_ToyBox.GetToyFromIndex(i)
        if toyId and PlayerHasToy(toyId) then
            local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                table.insert(self.allToys, {
                    id = toyId,
                    name = toyName,
                    icon = icon
                })
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(self.allToys, function(a, b) return a.name < b.name end)
    
    self:FilterToyList()
end

function Config:FilterToyList()
    if not self.scrollChild or not self.allToys then return end
    
    local searchText = ""
    if self.searchBox then
        searchText = self.searchBox:GetText():lower()
    end
    
    -- Filter toys based on search
    local filteredToys = {}
    for _, toy in ipairs(self.allToys) do
        if searchText == "" or toy.name:lower():find(searchText, 1, true) then
            table.insert(filteredToys, toy)
        end
    end
    
    -- Create buttons for filtered toys
    local yOffset = 0
    local buttonHeight = 30
    
    for i, toy in ipairs(filteredToys) do
        local button = self.toyButtons[i]
        if not button then
            button = CreateFrame("Button", nil, self.scrollChild)
            button:SetSize(360, buttonHeight)
            
            -- No background - cleaner look
            
            -- Highlight on hover only
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            
            -- Icon
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", button, "LEFT", 5, 0)
            icon:SetSize(22, 22)
            
            -- Text
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
            text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
            text:SetJustifyH("LEFT")
            
            button.icon = icon
            button.text = text
            
            self.toyButtons[i] = button
        end
        
        button:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -yOffset)
        button.icon:SetTexture(toy.icon)
        button.text:SetText(toy.name)
        
        button:SetScript("OnClick", function()
            self.parent:SetConfig(toy.id, "playground", "favoriteToyId")
            self.parent:Print("Favorite toy set to: " .. toy.name)
            self:UpdateToySelection()
            if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then
                self.parent.modules.playground:UpdateFavoriteToyButton()
            end
        end)
        
        button:Show()
        yOffset = yOffset + buttonHeight
    end
    
    -- Hide unused buttons
    for i = #filteredToys + 1, #self.toyButtons do
        if self.toyButtons[i] then
            self.toyButtons[i]:Hide()
        end
    end
    
    -- Update scroll child height
    self.scrollChild:SetHeight(math.max(yOffset, 1))
end

function Config:UpdateToySelection()
    if not self.currentToyButton then return end
    
    local currentToyId = self.parent:GetConfig("playground", "favoriteToyId")
    if currentToyId then
        local _, toyName, toyIcon = C_ToyBox.GetToyInfo(currentToyId)
        if toyName then
            self.currentToyIcon:SetTexture(toyIcon)
            self.currentToyText:SetText(toyName)
            return
        end
    end
    
    -- No toy selected or invalid toy
    self.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.currentToyText:SetText("None selected (click to clear)")
end

-- Register the module
ColdSnap:RegisterModule("config", Config)
