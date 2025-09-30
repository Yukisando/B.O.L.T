-- B.O.L.T Configuration UI (Brittle and Occasionally Lethal Tweaks)
-- Settings interface for easy module management

local ADDON_NAME, BOLT = ...

-- Create the Config module
local Config = {}

function Config:OnInitialize()
    self:CreateInterfaceOptionsPanel()
    -- Don't create standalone frame during init
    
    -- Register events for initial toy list population only
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.toyListPopulated = false -- Track if we've already populated the toy list
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == ADDON_NAME then
                -- Delay toy list population to ensure game data is ready
                C_Timer.After(2.0, function()
                    self:PopulateToyListOnce()
                end)
            end
        end
    end)
end

function Config:OnEnable()
    -- Module enabled
end

-- Helper function to create a "Need reload" indicator next to checkboxes
function Config:CreateReloadIndicator(parent, anchorFrame)
    local indicator = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    indicator:SetPoint("LEFT", anchorFrame.Text, "RIGHT", 10, 0)
    indicator:SetText("|cFFFF6B6B(Need reload)|r")
    indicator:SetTextColor(1, 0.42, 0.42) -- Light red color
    return indicator
end

function Config:PopulateToyListOnce()
    -- Only populate the toy list once to avoid lag
    if self.toyListPopulated then
        return
    end
    
    -- Populate toy list if the toy selection frame exists
    if self.toyFrame then
        self:PopulateToyList()
        self.toyListPopulated = true
        print("BOLT: Toy list populated successfully")
    end
end

function Config:CreateInterfaceOptionsPanel()
    -- Create the main options panel that integrates with WoW's Interface > AddOns
    local panel = CreateFrame("Frame", "BOLTOptionsPanel")
    panel.name = "B.O.L.T"
    
    -- Add OnShow script to refresh checkbox states
    panel:SetScript("OnShow", function()
        self:RefreshOptionsPanel()
    end)
    
    -- Create a scroll frame for the content
    local scrollFrame = CreateFrame("ScrollFrame", "BOLTScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
    
    -- Create the scroll child (the actual content container)
    local content = CreateFrame("Frame", "BOLTScrollChild", scrollFrame)
    content:SetSize(scrollFrame:GetWidth() - 20, 1) -- Width minus scrollbar space, height will be set dynamically
    scrollFrame:SetScrollChild(content)
    
    -- Store references for later use
    self.scrollFrame = scrollFrame
    self.scrollChild = content
    
    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("B.O.L.T")
    
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
    local gameMenuCheckbox = CreateFrame("CheckButton", "BOLTGameMenuCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    gameMenuCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    gameMenuCheckbox.Text:SetText("Enable Game Menu Module")
    
    -- Add reload indicator
    local gameMenuReloadIndicator = self:CreateReloadIndicator(content, gameMenuCheckbox)
    
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
    local leaveGroupCheckbox = CreateFrame("CheckButton", "BOLTLeaveGroupCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    leaveGroupCheckbox.Text:SetText("Show Leave Group/Delve Button")
    
    -- Add reload indicator
    local leaveGroupReloadIndicator = self:CreateReloadIndicator(content, leaveGroupCheckbox)
    
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
    local reloadCheckbox = CreateFrame("CheckButton", "BOLTReloadCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    reloadCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    reloadCheckbox.Text:SetText("Show Reload UI Button")
    
    -- Add reload indicator
    local reloadUIReloadIndicator = self:CreateReloadIndicator(content, reloadCheckbox)
    
    reloadCheckbox:SetScript("OnShow", function()
        reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
    end)
    reloadCheckbox:SetScript("OnClick", function()
        local enabled = reloadCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showReloadButton")
        self.parent:Print("Reload UI button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply changes.")
    end)
    yOffset = yOffset - 30

    -- Show Group Tools (Ready/Countdown/Raid Marker)
    local groupToolsCheckbox = CreateFrame("CheckButton", "BOLTGroupToolsCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    groupToolsCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    groupToolsCheckbox.Text:SetText("Show Group Tools (Ready/Countdown/Raid Marker)")
    groupToolsCheckbox:SetScript("OnShow", function()
        groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "groupToolsEnabled"))
    end)
    groupToolsCheckbox:SetScript("OnClick", function()
        local enabled = groupToolsCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "groupToolsEnabled")
        self.parent:Print("Group tools " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply if needed.")
    end)
    yOffset = yOffset - 30

    -- Raid Marker selection dropdown
    local markerLabel = content:CreateFontString("BOLTRaidMarkerLabel", "OVERLAY", "GameFontNormal")
    markerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    markerLabel:SetText("Raid marker for the button:")

    local dropdown = CreateFrame("Frame", "BOLTRaidMarkerDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", markerLabel, "BOTTOMLEFT", -16, -6)

    local markerNames = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull","Clear"}

    UIDropDownMenu_SetWidth(dropdown, 180)
    UIDropDownMenu_JustifyText(dropdown, "LEFT")

    local mod = self
    local function SetDropdownText(index)
        if index == 0 or index == 9 then
            UIDropDownMenu_SetText(dropdown, "Clear (no marker)")
        else
            UIDropDownMenu_SetText(dropdown, markerNames[index] or "Star")
        end
    end

    UIDropDownMenu_Initialize(dropdown, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, 9 do
            info = UIDropDownMenu_CreateInfo()
            local valueIndex = (i == 9) and 0 or i
            info.text = (i == 9) and "Clear (no marker)" or markerNames[i]
            info.func = function()
                mod.parent:SetConfig(valueIndex, "gameMenu", "raidMarkerIndex")
                SetDropdownText(valueIndex)
            end
            info.checked = (mod.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1) == valueIndex
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Refresh dropdown selection on show
    dropdown:SetScript("OnShow", function()
        local idx = mod.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
        SetDropdownText(idx)
    end)
    yOffset = yOffset - 70
    
    -- Show Battle Text Toggles
    local battleTextCheckbox = CreateFrame("CheckButton", "BOLTBattleTextCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    battleTextCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    battleTextCheckbox.Text:SetText("Show Battle Text Toggles (Damage/Healing Numbers)")
    battleTextCheckbox:SetScript("OnShow", function()
        battleTextCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showBattleTextToggles"))
    end)
    battleTextCheckbox:SetScript("OnClick", function()
        local enabled = battleTextCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showBattleTextToggles")
        self.parent:Print("Battle text toggles " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply if needed.")
    end)
    yOffset = yOffset - 30
    
    -- Show Volume Button
    local volumeButtonCheckbox = CreateFrame("CheckButton", "BOLTVolumeButtonCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    volumeButtonCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    volumeButtonCheckbox.Text:SetText("Show Volume Control Button")
    volumeButtonCheckbox:SetScript("OnShow", function()
        volumeButtonCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showVolumeButton"))
    end)
    volumeButtonCheckbox:SetScript("OnClick", function()
        local enabled = volumeButtonCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showVolumeButton")
        self.parent:Print("Volume button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply if needed.")
    end)
    yOffset = yOffset - 30
    
    -- Add separator line after Game Menu module
    local gameMenuSeparator = content:CreateTexture(nil, "ARTWORK")
    gameMenuSeparator:SetTexture("Interface\\Common\\UI-TooltipDivider-Transparent")
    gameMenuSeparator:SetSize(400, 8)
    gameMenuSeparator:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset - 10)
    yOffset = yOffset - 30
    
    -- Skyriding Module Section
    local skyridingHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skyridingHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    skyridingHeader:SetText("Skyriding Module")
    yOffset = yOffset - 30
    
    -- Enable/Disable Skyriding Module
    local skyridingCheckbox = CreateFrame("CheckButton", "BOLTSkyridingCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    skyridingCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    skyridingCheckbox.Text:SetText("Enable Skyriding Module")
    
    -- Add reload indicator
    local skyridingReloadIndicator = self:CreateReloadIndicator(content, skyridingCheckbox)
    
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
    local pitchControlCheckbox = CreateFrame("CheckButton", "BOLTPitchControlCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    pitchControlCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    pitchControlCheckbox.Text:SetText("Enable pitch control (W/S for up/down while holding mouse)")
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
    local invertPitchCheckbox = CreateFrame("CheckButton", "BOLTInvertPitchCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
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
    
    -- Toggle Mode Checkbox
    local toggleModeCheckbox = CreateFrame("CheckButton", "BOLTToggleModeCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    toggleModeCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    toggleModeCheckbox.Text:SetText("Always-on mode (no mouse button required)")
    toggleModeCheckbox:SetScript("OnShow", function()
        toggleModeCheckbox:SetChecked(self.parent:GetConfig("skyriding", "toggleMode"))
    end)
    toggleModeCheckbox:SetScript("OnClick", function()
        local enabled = toggleModeCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "toggleMode")
        self.parent:Print("Skyriding " .. (enabled and "always-on mode enabled" or "hold mode enabled") .. ".")
    end)
    yOffset = yOffset - 30
    
    -- Description text for Skyriding module
    local skyridingDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skyridingDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    skyridingDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, yOffset)
    skyridingDesc:SetText("While active, strafe keys (A/D) become horizontal turning, and optionally W/S control pitch up/down for full 3D movement. Always On Mode can lead to stuck keys.")
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
    local playgroundCheckbox = CreateFrame("CheckButton", "BOLTPlaygroundCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    playgroundCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    playgroundCheckbox.Text:SetText("Enable Playground Module")
    
    -- Add reload indicator
    local playgroundReloadIndicator = self:CreateReloadIndicator(content, playgroundCheckbox)
    
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
    local favoriteToyCheckbox = CreateFrame("CheckButton", "BOLTFavoriteToyCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    favoriteToyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    favoriteToyCheckbox.Text:SetText("Show Favorite Toy Button")
    
    -- Add reload indicator
    local favoriteToyReloadIndicator = self:CreateReloadIndicator(content, favoriteToyCheckbox)
    
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
    
    -- Choose Toy Button (only show if feature is enabled)
    local chooseToyButton = CreateFrame("Button", "BOLTChooseToyButton", content, "UIPanelButtonTemplate")
    chooseToyButton:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    chooseToyButton:SetSize(120, 25)
    chooseToyButton:SetText("Choose Toy")
    chooseToyButton:SetScript("OnClick", function()
        self:ShowToySelectionPopup()
    end)
    
    -- Current selected toy display (inline with button)
    local currentToyDisplay = CreateFrame("Frame", "BOLTCurrentToyDisplay", content)
    currentToyDisplay:SetPoint("LEFT", chooseToyButton, "RIGHT", 10, 0)
    currentToyDisplay:SetSize(250, 25)
    
    -- Toy icon
    local toyIcon = currentToyDisplay:CreateTexture("BOLTCurrentToyIcon", "ARTWORK")
    toyIcon:SetPoint("LEFT", currentToyDisplay, "LEFT", 0, 0)
    toyIcon:SetSize(20, 20)
    toyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    
    -- Toy name text
    local toyText = currentToyDisplay:CreateFontString("BOLTCurrentToyText", "OVERLAY", "GameFontHighlight")
    toyText:SetPoint("LEFT", toyIcon, "RIGHT", 5, 0)
    toyText:SetPoint("RIGHT", currentToyDisplay, "RIGHT", 0, 0)
    toyText:SetJustifyH("LEFT")
    toyText:SetText("None selected")
    
    yOffset = yOffset - 35

    -- Show FPS Counter
    local fpsCheckbox = CreateFrame("CheckButton", "BOLTFPSCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    fpsCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    fpsCheckbox.Text:SetText("Show FPS Counter")
    fpsCheckbox:SetScript("OnShow", function()
        fpsCheckbox:SetChecked(self.parent:GetConfig("playground", "showFPS"))
    end)
    fpsCheckbox:SetScript("OnClick", function()
        local enabled = fpsCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "playground", "showFPS")
        self.parent:Print("FPS counter " .. (enabled and "enabled" or "disabled") .. ".")
        -- Tell playground module to show/hide the speedometer frame immediately if loaded
        if self.parent.modules and self.parent.modules.playground and self.parent.modules.playground.ToggleFPS then
            self.parent.modules.playground:ToggleFPS(enabled)
        end
        -- Update child controls to show/hide stats position dropdown
        self:UpdatePlaygroundChildControls()
    end)
    yOffset = yOffset - 30

    -- Show Speedometer (speed %)
    local speedometerCheckbox = CreateFrame("CheckButton", "BOLTSpeedometerCheckbox", content, "InterfaceOptionsCheckButtonTemplate")
    speedometerCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    speedometerCheckbox.Text:SetText("Show Speedometer (speed %)")
    speedometerCheckbox:SetScript("OnShow", function()
        speedometerCheckbox:SetChecked(self.parent:GetConfig("playground", "showSpeedometer"))
    end)
    speedometerCheckbox:SetScript("OnClick", function()
        local enabled = speedometerCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "playground", "showSpeedometer")
        self.parent:Print("Speedometer " .. (enabled and "enabled" or "disabled") .. ".")
        -- Tell playground module to show/hide the speedometer frame immediately if loaded
        if self.parent.modules and self.parent.modules.playground and self.parent.modules.playground.ToggleSpeedometer then
            self.parent.modules.playground:ToggleSpeedometer(enabled)
        end
        -- Update child controls to show/hide stats position dropdown
        self:UpdatePlaygroundChildControls()
    end)
    yOffset = yOffset - 30


    -- Stats Position Dropdown
    local statsPositionLabel = content:CreateFontString("BOLTStatsPositionLabel", "OVERLAY", "GameFontNormal")
    statsPositionLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    statsPositionLabel:SetText("Stats position:")

    local statsPositionDropdown = CreateFrame("Frame", "BOLTStatsPositionDropdown", content, "UIDropDownMenuTemplate")
    statsPositionDropdown:SetPoint("TOPLEFT", statsPositionLabel, "BOTTOMLEFT", -16, -6)

    local positionOptions = {"Bottom Left", "Bottom Right", "Top Left", "Top Right"}
    local positionValues = {"BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT", "TOPRIGHT"}

    UIDropDownMenu_SetWidth(statsPositionDropdown, 180)
    UIDropDownMenu_JustifyText(statsPositionDropdown, "LEFT")

    local statsPositionMod = self
    local function SetStatsPositionDropdownText(value)
        for i, val in ipairs(positionValues) do
            if val == value then
                UIDropDownMenu_SetText(statsPositionDropdown, positionOptions[i])
                return
            end
        end
        UIDropDownMenu_SetText(statsPositionDropdown, "Bottom Left") -- Default fallback
    end

    UIDropDownMenu_Initialize(statsPositionDropdown, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()
        for i = 1, #positionOptions do
            info = UIDropDownMenu_CreateInfo()
            info.text = positionOptions[i]
            info.func = function()
                statsPositionMod.parent:SetConfig(positionValues[i], "playground", "statsPosition")
                SetStatsPositionDropdownText(positionValues[i])
                -- Update the stats position immediately if the playground module is loaded
                if statsPositionMod.parent.modules and statsPositionMod.parent.modules.playground and statsPositionMod.parent.modules.playground.UpdateStatsPosition then
                    statsPositionMod.parent.modules.playground:UpdateStatsPosition()
                end
            end
            info.checked = (statsPositionMod.parent:GetConfig("playground", "statsPosition") or "BOTTOMLEFT") == positionValues[i]
            UIDropDownMenu_AddButton(info)
        end
    end)

    -- Refresh dropdown selection on show
    statsPositionDropdown:SetScript("OnShow", function()
        local position = statsPositionMod.parent:GetConfig("playground", "statsPosition") or "BOTTOMLEFT"
        SetStatsPositionDropdownText(position)
    end)

    yOffset = yOffset - 70
          
    -- Console commands section
    local commandsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    commandsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
    commandsHeader:SetText("Console Commands")
    yOffset = yOffset - 25
    
    local commandsText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    commandsText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    commandsText:SetText("/bolt or /b - Open Interface Options to B.O.L.T")
    commandsText:SetTextColor(1, 0.82, 0)
    yOffset = yOffset - 40
    
    -- Reload UI Button
    local reloadButton = CreateFrame("Button", "BOLTOptionsReloadButton", content, "UIPanelButtonTemplate")
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
    versionText:SetText("B.O.L.T v" .. self.parent.version)
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
        local category = Settings.RegisterCanvasLayoutCategory(panel, "B.O.L.T")
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
        local gameMenuCheckbox = _G["BOLTGameMenuCheckbox"]
        if gameMenuCheckbox then
            local enabled = self.parent:IsModuleEnabled("gameMenu")
            gameMenuCheckbox:SetChecked(enabled)
        end
        
        local leaveGroupCheckbox = _G["BOLTLeaveGroupCheckbox"]
        if leaveGroupCheckbox then
            leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
        end
        
        local reloadCheckbox = _G["BOLTReloadCheckbox"]
        if reloadCheckbox then
            reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
        end

        local groupToolsCheckbox = _G["BOLTGroupToolsCheckbox"]
        if groupToolsCheckbox then
            groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "groupToolsEnabled"))
        end
        local raidMarkerDropdown = _G["BOLTRaidMarkerDropdown"]
        if raidMarkerDropdown then
            local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
            -- Set the text again in case marker changed elsewhere
            if idx == 0 then
                UIDropDownMenu_SetText(raidMarkerDropdown, "Clear (no marker)")
            else
                local names = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"}
                UIDropDownMenu_SetText(raidMarkerDropdown, names[idx] or "Star")
            end
        end
        
        local playgroundCheckbox = _G["BOLTPlaygroundCheckbox"]
        if playgroundCheckbox then
            local enabled = self.parent:IsModuleEnabled("playground")
            playgroundCheckbox:SetChecked(enabled)
        end
        
        local favoriteToyCheckbox = _G["BOLTFavoriteToyCheckbox"]
        if favoriteToyCheckbox then
            favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground", "showFavoriteToy"))
        end
        
        local skyridingCheckbox = _G["BOLTSkyridingCheckbox"]
        if skyridingCheckbox then
            local enabled = self.parent:IsModuleEnabled("skyriding")
            skyridingCheckbox:SetChecked(enabled)
        end
        
        local pitchControlCheckbox = _G["BOLTPitchControlCheckbox"]
        if pitchControlCheckbox then
            pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl"))
        end
        
        local invertPitchCheckbox = _G["BOLTInvertPitchCheckbox"]
        if invertPitchCheckbox then
            invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding", "invertPitch"))
        end
        
        -- Update toy selection frame
        if self.allToys then
            self:PopulateToyList()
        end
        self:UpdateToySelection()
        
        -- Update current toy display in main panel
        self:UpdateCurrentToyDisplay()
        
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
    local leaveGroupCheckbox = _G["BOLTLeaveGroupCheckbox"]
    local reloadCheckbox = _G["BOLTReloadCheckbox"]
    local groupToolsCheckbox = _G["BOLTGroupToolsCheckbox"]
    local battleTextCheckbox = _G["BOLTBattleTextCheckbox"]
    local volumeButtonCheckbox = _G["BOLTVolumeButtonCheckbox"]
    local raidMarkerDropdown = _G["BOLTRaidMarkerDropdown"]
    local raidMarkerLabel = _G["BOLTRaidMarkerLabel"]
    
    -- Enable/disable child controls based on parent module
    if leaveGroupCheckbox then
        leaveGroupCheckbox:SetEnabled(gameMenuEnabled)
        leaveGroupCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if reloadCheckbox then
        reloadCheckbox:SetEnabled(gameMenuEnabled)
        reloadCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    if groupToolsCheckbox then
        groupToolsCheckbox:SetEnabled(gameMenuEnabled)
        groupToolsCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    if battleTextCheckbox then
        battleTextCheckbox:SetEnabled(gameMenuEnabled)
        battleTextCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    if volumeButtonCheckbox then
        volumeButtonCheckbox:SetEnabled(gameMenuEnabled)
        volumeButtonCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    local groupToolsEnabled = self.parent:GetConfig("gameMenu", "groupToolsEnabled") and gameMenuEnabled
    if raidMarkerDropdown then
        if groupToolsEnabled then
            if UIDropDownMenu_EnableDropDown then UIDropDownMenu_EnableDropDown(raidMarkerDropdown) end
            raidMarkerDropdown:SetAlpha(1.0)
        else
            if UIDropDownMenu_DisableDropDown then UIDropDownMenu_DisableDropDown(raidMarkerDropdown) end
            raidMarkerDropdown:SetAlpha(0.5)
        end
    end
    if raidMarkerLabel then
        raidMarkerLabel:SetAlpha(groupToolsEnabled and 1.0 or 0.5)
    end
end

-- Update child control states for Playground module
function Config:UpdatePlaygroundChildControls()
    local playgroundEnabled = self.parent:IsModuleEnabled("playground")
    
    -- Get references to child controls
    local favoriteToyCheckbox = _G["BOLTFavoriteToyCheckbox"]
    local chooseToyButton = _G["BOLTChooseToyButton"]
    local currentToyDisplay = _G["BOLTCurrentToyDisplay"]
    local fpsCheckbox = _G["BOLTFPSCheckbox"]
    local speedometerCheckbox = _G["BOLTSpeedometerCheckbox"]
    local statsPositionLabel = _G["BOLTStatsPositionLabel"]
    local statsPositionDropdown = _G["BOLTStatsPositionDropdown"]
    
    -- Enable/disable child controls based on parent module
    if favoriteToyCheckbox then
        favoriteToyCheckbox:SetEnabled(playgroundEnabled)
        favoriteToyCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    if fpsCheckbox then
        fpsCheckbox:SetEnabled(playgroundEnabled)
        fpsCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    if speedometerCheckbox then
        speedometerCheckbox:SetEnabled(playgroundEnabled)
        speedometerCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    -- Show/hide stats position controls based on whether FPS or speedometer is enabled
    local showStatsControls = playgroundEnabled and (self.parent:GetConfig("playground", "showFPS") or self.parent:GetConfig("playground", "showSpeedometer"))
    
    if statsPositionLabel then
        if showStatsControls then
            statsPositionLabel:Show()
        else
            statsPositionLabel:Hide()
        end
    end
    
    if statsPositionDropdown then
        if showStatsControls then
            statsPositionDropdown:Show()
            UIDropDownMenu_EnableDropDown(statsPositionDropdown)
        else
            statsPositionDropdown:Hide()
        end
    end
    
    -- Show/hide choose toy button and current toy display based on both module and feature being enabled
    local favoriteToyEnabled = playgroundEnabled and self.parent:GetConfig("playground", "showFavoriteToy")
    
    if chooseToyButton then
        if favoriteToyEnabled then
            chooseToyButton:Show()
            chooseToyButton:SetEnabled(true)
        else
            chooseToyButton:Hide()
        end
    end
    
    if currentToyDisplay then
        if favoriteToyEnabled then
            currentToyDisplay:Show()
            -- Update the current toy display
            self:UpdateCurrentToyDisplay()
        else
            currentToyDisplay:Hide()
        end
    end
end

function Config:UpdateCurrentToyDisplay()
    local toyIcon = _G["BOLTCurrentToyIcon"]
    local toyText = _G["BOLTCurrentToyText"]
    
    if not toyIcon or not toyText then
        return
    end
    
    local selectedToyId = self.parent:GetConfig("playground", "favoriteToyId")
    
    if selectedToyId and PlayerHasToy(selectedToyId) then
        local _, toyName, toyIconPath = C_ToyBox.GetToyInfo(selectedToyId)
        if toyName and toyName ~= "" then
            _G["BOLTCurrentToyIcon"]:SetTexture(toyIconPath)
            toyText:SetText(toyName)
            toyText:SetTextColor(1, 1, 1) -- White text for selected toy
        else
            _G["BOLTCurrentToyIcon"]:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            toyText:SetText("Unknown toy")
            toyText:SetTextColor(1, 0.8, 0) -- Yellow text for unknown
        end
    else
        _G["BOLTCurrentToyIcon"]:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        toyText:SetText("None selected")
        toyText:SetTextColor(0.5, 0.5, 0.5) -- Gray text for none selected
    end
end

-- Update child control states for Skyriding module
function Config:UpdateSkyridingChildControls()
    local skyridingEnabled = self.parent:IsModuleEnabled("skyriding")
    local pitchControlEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
    
    -- Get references to child controls
    local pitchControlCheckbox = _G["BOLTPitchControlCheckbox"]
    local invertPitchCheckbox = _G["BOLTInvertPitchCheckbox"]
    local toggleModeCheckbox = _G["BOLTToggleModeCheckbox"]
    
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
    
    if toggleModeCheckbox then
        toggleModeCheckbox:SetEnabled(skyridingEnabled)
        toggleModeCheckbox:SetAlpha(skyridingEnabled and 1.0 or 0.5)
    end
end

function Config:ShowToySelectionPopup()
    -- Create or show existing popup
    if not self.toyPopup then
        self:CreateToySelectionPopup()
    end
    
    -- Show the popup
    self.toyPopup:Show()
    
    -- Populate toy list if not already done
    if not self.toyListPopulated then
        self:PopulateToyList()
        self.toyListPopulated = true
    end
    
    -- Update current selection display
    self:UpdateToySelection()
end

function Config:CreateToySelectionPopup()
    -- Create the main popup frame
    local popup = CreateFrame("Frame", "BOLTToySelectionPopup", UIParent, "DialogBoxFrame")
    popup:SetSize(450, 400)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    
    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Choose Favorite Toy")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    
    -- Create the toy selection content inside the popup
    self:CreateToySelectionFrame(popup, 15, -50)
    
    -- Store reference
    self.toyPopup = popup
    
    -- Hide by default
    popup:Hide()
end

function Config:CreateToySelectionFrame(parent, xOffset, yOffset)
    -- Create the main container frame
    local toyFrame = CreateFrame("Frame", "BOLTToySelectionFrame", parent)
    toyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset)
    toyFrame:SetSize(420, 320)
    
    -- Create border (only if not in a popup that already has a border)
    if parent ~= self.toyPopup then
        local border = CreateFrame("Frame", nil, toyFrame, "DialogBorderTemplate")
        border:SetAllPoints()
    end
    
    -- Search box
    local searchLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -15)
    searchLabel:SetText("Search:")
    
    local searchBox = CreateFrame("EditBox", "BOLTToySearchBox", toyFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", searchLabel, "TOPRIGHT", 15, 0)
    searchBox:SetSize(220, 28)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function()
        self:FilterToyList()
    end)
    
    -- Clear search button
    local clearButton = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate")
    clearButton:SetPoint("LEFT", searchBox, "RIGHT", 10, 0)
    clearButton:SetSize(50, 28)
    clearButton:SetText("Clear")
    clearButton:SetScript("OnClick", function()
        searchBox:SetText("")
        self:FilterToyList()
    end)
    
    -- Current selection display
    local currentLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -50)
    currentLabel:SetText("Current:")
    
    local currentToy = CreateFrame("Button", "BOLTCurrentToyButton", toyFrame)
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
    local scrollFrame = CreateFrame("ScrollFrame", "BOLTToyScrollFrame", toyFrame, "UIPanelScrollFrameTemplate")
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
    
    -- Set up frame show handler to populate toys when visible
    toyFrame:SetScript("OnShow", function()
        -- Delay population to ensure toy box data is loaded
        C_Timer.After(0.1, function()
            self:PopulateToyList()
            self:UpdateToySelection()
        end)
    end)
    
    -- Initial setup (will be refreshed when shown)
    self:UpdateToySelection()
end

function Config:PopulateToyList()
    if not self.scrollChild then 
        return 
    end
    
    -- Clear existing buttons
    for _, button in pairs(self.toyButtons) do
        button:Hide()
        button:SetParent(nil)
    end
    self.toyButtons = {}
    
    -- Get all toys
    self.allToys = {}
    local numToys = C_ToyBox.GetNumToys()
    
    local ownedCount = 0
    for i = 1, numToys do
        local toyId = C_ToyBox.GetToyFromIndex(i)
        if toyId and PlayerHasToy(toyId) then
            local _, toyName, icon = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                table.insert(self.allToys, {
                    id = toyId,
                    name = toyName,
                    icon = icon
                })
                ownedCount = ownedCount + 1
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
            -- Also update the main panel display
            self:UpdateCurrentToyDisplay()
            return
        end
    end
    
    -- No toy selected or invalid toy
    self.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.currentToyText:SetText("None selected (click to clear)")
    -- Also update the main panel display
    self:UpdateCurrentToyDisplay()
end

-- Register the module
BOLT:RegisterModule("config", Config)
