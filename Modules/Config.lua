-- B.O.L.T Configuration UI (Brittle and Occasionally Lethal Tweaks)
-- Settings interface for easy module management

local ADDON_NAME, BOLT = ...

-- Config module
local Config = {}

function Config:OnInitialize()
    self.widgets = {} -- Store widget references instead of creating globals
    self:CreateInterfaceOptionsPanel()
    -- Don't create standalone frame during init
    
    -- Register events for initial toy list population only
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:RegisterEvent("TOYS_UPDATED")
    self.toyListPopulated = false -- Track if we've already populated the toy list
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            local addonName = ...
            if addonName == ADDON_NAME then
                -- Let TOYS_UPDATED handle population
            end
        elseif event == "TOYS_UPDATED" then
            if not self.toyListPopulated and self.toyFrame then
                self:PopulateToyList()
                self.toyListPopulated = true
                self.parent:Print("Toy list populated successfully")
            end
        end
    end)
end

    -- Shared keybinding capture helper (defined once and reused)
    local _bindingCaptureFrame = nil
    local function StartKeybindingCapture(button, bindingAction, updateFunc)
        if not button then return end
        if button._isBinding then return end
        button._isBinding = true
        button:SetText("Press a key...")

        if not _bindingCaptureFrame then
            _bindingCaptureFrame = CreateFrame("Frame", nil, UIParent)
            _bindingCaptureFrame:SetFrameStrata("DIALOG")
            _bindingCaptureFrame:EnableKeyboard(true)
            _bindingCaptureFrame:SetPropagateKeyboardInput(false)
        end

        local frame = _bindingCaptureFrame
        frame:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then
                button._isBinding = false
                frame:Hide()
                frame:SetScript("OnKeyDown", nil)
                if updateFunc then updateFunc() end
                return
            end
            if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
                return
            end
            key = key:upper()
            local keyCombo = ""
            if IsControlKeyDown() then keyCombo = "CTRL-" end
            if IsAltKeyDown() then keyCombo = keyCombo .. "ALT-" end
            if IsShiftKeyDown() then keyCombo = keyCombo .. "SHIFT-" end
            keyCombo = keyCombo .. key
            local k1, k2 = GetBindingKey(bindingAction)
            if k1 then SetBinding(k1, nil) end
            if k2 then SetBinding(k2, nil) end
            local result = SetBinding(keyCombo, bindingAction)
            if result then
                SaveBindings(GetCurrentBindingSet())
                if updateFunc then C_Timer.After(0.5, updateFunc) end
            else
                button:SetText("Binding failed - try another key")
                if updateFunc then C_Timer.After(1.5, updateFunc) end
            end
            button._isBinding = false
            frame:Hide()
            frame:SetScript("OnKeyDown", nil)
        end)
        frame:Show()
        frame:SetFocus()
    end

    function Config:CreateReloadIndicator(parent, anchorFrame)
        local indicator = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        indicator:SetPoint("LEFT", anchorFrame.Text, "RIGHT", 10, 0)
        indicator:SetText("|cFFFF6B6B(Requires /reload)|r")
        indicator:Hide() -- Hidden by default, show only when needed
        return indicator
    end

    function Config:CreateInterfaceOptionsPanel()
        -- Create the main options panel that integrates with WoW's Interface > AddOns
        local panel = CreateFrame("Frame", "BOLTOptionsPanel")
        panel.name = "B.O.L.T"
        
        -- Add OnShow script to refresh all UI states
        panel:SetScript("OnShow", function()
            self:RefreshAll()
        end)
        
        -- Create a scroll frame for the content
        local scrollFrame = CreateFrame("ScrollFrame", "BOLTScrollFrame", panel, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
        
        -- Create the scroll child (the actual content container)
        local content = CreateFrame("Frame", "BOLTScrollChild", scrollFrame)
        content:SetSize(scrollFrame:GetWidth() - 20, 1) -- Width minus scrollbar space, height will be set dynamically
        scrollFrame:SetScrollChild(content)
        
        -- Store references for later use (use distinct names to avoid collision with toy scroll frame)
        self.optionsScrollFrame = scrollFrame
        self.optionsScrollChild = content
    
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
    local gameMenuCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    gameMenuCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    gameMenuCheckbox.Text:SetText("Enable Game Menu Module")
    self.widgets.gameMenuCheckbox = gameMenuCheckbox
    
    -- Add reload indicator
    local gameMenuReloadIndicator = self:CreateReloadIndicator(content, gameMenuCheckbox)
    gameMenuReloadIndicator:Show() -- This setting requires reload
    self.widgets.gameMenuReloadIndicator = gameMenuReloadIndicator
    
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
    local leaveGroupCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    leaveGroupCheckbox.Text:SetText("Show Leave Group/Delve Button")
    self.widgets.leaveGroupCheckbox = leaveGroupCheckbox
    
    -- Add reload indicator
    local leaveGroupReloadIndicator = self:CreateReloadIndicator(content, leaveGroupCheckbox)
    leaveGroupReloadIndicator:Show() -- This setting requires reload
    self.widgets.leaveGroupReloadIndicator = leaveGroupReloadIndicator
    
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
    local reloadCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    reloadCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    reloadCheckbox.Text:SetText("Show Reload UI Button")
    self.widgets.reloadCheckbox = reloadCheckbox
    
    -- Add reload indicator
    local reloadUIReloadIndicator = self:CreateReloadIndicator(content, reloadCheckbox)
    reloadUIReloadIndicator:Show() -- This setting requires reload
    self.widgets.reloadUIReloadIndicator = reloadUIReloadIndicator
    
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
    local groupToolsCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    groupToolsCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    groupToolsCheckbox.Text:SetText("Show Group Tools (Ready/Countdown/Raid Marker)")
    self.widgets.groupToolsCheckbox = groupToolsCheckbox
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
    local markerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    markerLabel:SetText("Raid marker for the button:")
    self.widgets.raidMarkerLabel = markerLabel

    local dropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", markerLabel, "BOTTOMLEFT", -16, -6)
    self.widgets.raidMarkerDropdown = dropdown

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
    local battleTextCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    battleTextCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    battleTextCheckbox.Text:SetText("Show Battle Text Toggles (Damage/Healing Numbers)")
    self.widgets.battleTextCheckbox = battleTextCheckbox
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
    local volumeButtonCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    volumeButtonCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    volumeButtonCheckbox.Text:SetText("Show Volume Control Button")
    self.widgets.volumeButtonCheckbox = volumeButtonCheckbox
    volumeButtonCheckbox:SetScript("OnShow", function()
        volumeButtonCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showVolumeButton"))
    end)
    volumeButtonCheckbox:SetScript("OnClick", function()
        local enabled = volumeButtonCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "gameMenu", "showVolumeButton")
        self.parent:Print("Volume button " .. (enabled and "enabled" or "disabled") .. ". Type /reload to apply if needed.")
    end)
    yOffset = yOffset - 40
    
    -- Keybinding section for toggle master volume
    local keybindingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keybindingLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    keybindingLabel:SetText("Toggle Master Volume Keybinding:")
    yOffset = yOffset - 25
    
    -- Keybinding button
    local keybindButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    keybindButton:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    keybindButton:SetSize(200, 25)
    self.widgets.keybindButton = keybindButton
    
    local function UpdateKeybindButtonText()
        local key1, key2 = GetBindingKey("BOLT_TOGGLE_MASTER_VOLUME")
        if key1 then
            local displayText = key1:gsub("%-", " + ")
            if key2 then
                displayText = displayText .. ", " .. key2:gsub("%-", " + ")
            end
            keybindButton:SetText(displayText)
        else
            keybindButton:SetText("Click to bind")
        end
    end
    
    -- Store the update function for refresh
    self.UpdateKeybindButtonText = UpdateKeybindButtonText
    
    -- Refresh on show
    keybindButton:SetScript("OnShow", function()
        UpdateKeybindButtonText()
    end)
    
    UpdateKeybindButtonText()
    
    local bindingFrame = nil
    local isBinding = false
    
    keybindButton:SetScript("OnClick", function(self)
        if isBinding then return end
        
        isBinding = true
        self:SetText("Press a key...")
        
        -- Create invisible frame to capture key input
        if not bindingFrame then
            bindingFrame = CreateFrame("Frame", nil, UIParent)
            bindingFrame:SetFrameStrata("DIALOG")
            bindingFrame:EnableKeyboard(true)
            bindingFrame:SetPropagateKeyboardInput(false)
        end
        
        bindingFrame:SetScript("OnKeyDown", function(frame, key)
            -- Allow ESC to cancel
            if key == "ESCAPE" then
                isBinding = false
                bindingFrame:Hide()
                bindingFrame:SetScript("OnKeyDown", nil)
                UpdateKeybindButtonText()
                return
            end
            
            -- Ignore modifier keys by themselves
            if key == "LSHIFT" or key == "RSHIFT" or 
               key == "LCTRL" or key == "RCTRL" or 
               key == "LALT" or key == "RALT" then
                return
            end
            
            -- Normalize key to uppercase
            key = key:upper()
            
            -- Build the key combination
            local keyCombo = ""
            if IsControlKeyDown() then
                keyCombo = "CTRL-"
            end
            if IsAltKeyDown() then
                keyCombo = keyCombo .. "ALT-"
            end
            if IsShiftKeyDown() then
                keyCombo = keyCombo .. "SHIFT-"
            end
            keyCombo = keyCombo .. key
            
            -- Clear existing bindings for this action
            local key1, key2 = GetBindingKey("BOLT_TOGGLE_MASTER_VOLUME")
            if key1 then SetBinding(key1, nil) end
            if key2 then SetBinding(key2, nil) end
            
            -- Set the new binding
            local result = SetBinding(keyCombo, "BOLT_TOGGLE_MASTER_VOLUME")
            if result then
                SaveBindings(GetCurrentBindingSet())
                keybindButton:SetText(keyCombo:gsub("%-", " + "))
                C_Timer.After(0.5, UpdateKeybindButtonText)
            else
                keybindButton:SetText("Binding failed - try another key")
                C_Timer.After(1.5, UpdateKeybindButtonText)
            end
            
            isBinding = false
            bindingFrame:Hide()
            bindingFrame:SetScript("OnKeyDown", nil)
        end)
        
        bindingFrame:Show()
        bindingFrame:SetFocus()
    end)
    
    -- Clear keybinding button
    local clearKeybindButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearKeybindButton:SetPoint("LEFT", keybindButton, "RIGHT", 10, 0)
    clearKeybindButton:SetSize(80, 25)
    clearKeybindButton:SetText("Clear")
    self.widgets.clearKeybindButton = clearKeybindButton
    clearKeybindButton:SetScript("OnClick", function()
        local key1, key2 = GetBindingKey("BOLT_TOGGLE_MASTER_VOLUME")
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SaveBindings(GetCurrentBindingSet())
        UpdateKeybindButtonText()
    end)
    
    yOffset = yOffset - 35
    
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
    local skyridingCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    skyridingCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    skyridingCheckbox.Text:SetText("Enable Skyriding Module")
    self.widgets.skyridingCheckbox = skyridingCheckbox
    
    -- Add reload indicator
    local skyridingReloadIndicator = self:CreateReloadIndicator(content, skyridingCheckbox)
    skyridingReloadIndicator:Show() -- This setting requires reload
    self.widgets.skyridingReloadIndicator = skyridingReloadIndicator
    
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
    local pitchControlCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    pitchControlCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    pitchControlCheckbox.Text:SetText("Enable pitch control (W/S for up/down while holding mouse)")
    self.widgets.pitchControlCheckbox = pitchControlCheckbox
    pitchControlCheckbox:SetScript("OnShow", function()
        pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl"))
    end)
    pitchControlCheckbox:SetScript("OnClick", function()
        local enabled = pitchControlCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "enablePitchControl")
        self.parent:Print("Skyriding pitch control " .. (enabled and "enabled" or "disabled") .. ".")
        -- HOT SWAP bindings immediately if module is live
        if self.parent.modules and self.parent.modules.skyriding and self.parent.modules.skyriding.OnPitchSettingChanged then
            self.parent.modules.skyriding:OnPitchSettingChanged()
        end
        -- Update child controls when toggled
        self:UpdateSkyridingChildControls()
    end)
    yOffset = yOffset - 30
    
    -- Invert Pitch Checkbox
    local invertPitchCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    invertPitchCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    invertPitchCheckbox.Text:SetText("Invert pitch (W=dive, S=climb)")
    self.widgets.invertPitchCheckbox = invertPitchCheckbox
    invertPitchCheckbox:SetScript("OnShow", function()
        invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding", "invertPitch"))
    end)
    invertPitchCheckbox:SetScript("OnClick", function()
        local enabled = invertPitchCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "skyriding", "invertPitch")
        self.parent:Print("Skyriding pitch " .. (enabled and "inverted" or "normal") .. ".")
        -- HOT SWAP bindings immediately if module is live
        if self.parent.modules and self.parent.modules.skyriding and self.parent.modules.skyriding.OnPitchSettingChanged then
            self.parent.modules.skyriding:OnPitchSettingChanged()
        end
    end)
    yOffset = yOffset - 30
    
    -- Spacer (Always-on mode removed)
    yOffset = yOffset - 30
    
    -- Description text for Skyriding module
    local skyridingDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    skyridingDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    skyridingDesc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -50, yOffset)
    skyridingDesc:SetText("Hold Left Mouse while Skyriding: A/D turn horizontally; optionally W/S pitch up/down. Release LMB to restore normal movement.")
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
    local playgroundCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    playgroundCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 30, yOffset)
    playgroundCheckbox.Text:SetText("Enable Playground Module")
    self.widgets.playgroundCheckbox = playgroundCheckbox
    
    -- Add reload indicator
    local playgroundReloadIndicator = self:CreateReloadIndicator(content, playgroundCheckbox)
    playgroundReloadIndicator:Show() -- This setting requires reload
    self.widgets.playgroundReloadIndicator = playgroundReloadIndicator
    
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
    local favoriteToyCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    favoriteToyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    favoriteToyCheckbox.Text:SetText("Show Favorite Toy Button")
    self.widgets.favoriteToyCheckbox = favoriteToyCheckbox
    
    -- Add reload indicator
    local favoriteToyReloadIndicator = self:CreateReloadIndicator(content, favoriteToyCheckbox)
    favoriteToyReloadIndicator:Show() -- This setting requires reload
    self.widgets.favoriteToyReloadIndicator = favoriteToyReloadIndicator
    
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
    local chooseToyButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    chooseToyButton:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    chooseToyButton:SetSize(120, 25)
    chooseToyButton:SetText("Choose Toy")
    chooseToyButton:SetScript("OnClick", function()
        self:ShowToySelectionPopup()
    end)
    self.widgets.chooseToyButton = chooseToyButton
    
    -- Current selected toy display (inline with button)
    local currentToyDisplay = CreateFrame("Frame", nil, content)
    currentToyDisplay:SetPoint("LEFT", chooseToyButton, "RIGHT", 10, 0)
    currentToyDisplay:SetSize(250, 25)
    self.widgets.currentToyDisplay = currentToyDisplay
    
    -- Toy icon
    local toyIcon = currentToyDisplay:CreateTexture(nil, "ARTWORK")
    toyIcon:SetPoint("LEFT", currentToyDisplay, "LEFT", 0, 0)
    toyIcon:SetSize(20, 20)
    toyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.widgets.currentToyIcon = toyIcon
    
    -- Toy name text
    local toyText = currentToyDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toyText:SetPoint("LEFT", toyIcon, "RIGHT", 5, 0)
    toyText:SetPoint("RIGHT", currentToyDisplay, "RIGHT", 0, 0)
    toyText:SetJustifyH("LEFT")
    toyText:SetText("None selected")
    self.widgets.currentToyText = toyText
    
    yOffset = yOffset - 35

    -- Show FPS Counter
    local fpsCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    fpsCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    fpsCheckbox.Text:SetText("Show FPS Counter")
    self.widgets.fpsCheckbox = fpsCheckbox
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
    local speedometerCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    speedometerCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    speedometerCheckbox.Text:SetText("Show Speedometer (speed %)")
    self.widgets.speedometerCheckbox = speedometerCheckbox
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
    local statsPositionLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsPositionLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    statsPositionLabel:SetText("Stats position:")
    self.widgets.statsPositionLabel = statsPositionLabel

    local statsPositionDropdown = CreateFrame("Frame", nil, content, "UIDropDownMenuTemplate")
    statsPositionDropdown:SetPoint("TOPLEFT", statsPositionLabel, "BOTTOMLEFT", -16, -6)
    self.widgets.statsPositionDropdown = statsPositionDropdown

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
    
    -- Copy Target Mount Feature
    local copyTargetMountCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    copyTargetMountCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, yOffset)
    copyTargetMountCheckbox.Text:SetText("Enable Copy Target Mount")
    self.widgets.copyTargetMountCheckbox = copyTargetMountCheckbox
    copyTargetMountCheckbox:SetScript("OnShow", function()
        copyTargetMountCheckbox:SetChecked(self.parent:GetConfig("playground", "copyTargetMount"))
    end)
    copyTargetMountCheckbox:SetScript("OnClick", function()
        local enabled = copyTargetMountCheckbox:GetChecked()
        self.parent:SetConfig(enabled, "playground", "copyTargetMount")
        self.parent:Print("Copy Target Mount " .. (enabled and "enabled" or "disabled") .. ".")
    end)
    yOffset = yOffset - 30
    
    -- Add description text for the feature
    local copyMountDesc = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    copyMountDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    copyMountDesc:SetText("Copies your target's mount if you have it learned. Use keybind or /copymount command.")
    copyMountDesc:SetTextColor(0.7, 0.7, 0.7)
    copyMountDesc:SetWidth(500)
    copyMountDesc:SetJustifyH("LEFT")
    copyMountDesc:SetWordWrap(true)
    self.widgets.copyMountDesc = copyMountDesc
    yOffset = yOffset - 30
    
    -- Keybinding section for copy target mount
    local copyMountKeybindingLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyMountKeybindingLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    copyMountKeybindingLabel:SetText("Copy Target Mount Keybinding:")
    self.widgets.copyMountKeybindingLabel = copyMountKeybindingLabel
    yOffset = yOffset - 25
    
    -- Keybinding button
    local copyMountKeybindButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    copyMountKeybindButton:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    copyMountKeybindButton:SetSize(200, 25)
    self.widgets.copyMountKeybindButton = copyMountKeybindButton
    
    local function UpdateCopyMountKeybindButtonText()
        local key1, key2 = GetBindingKey("BOLT_COPY_TARGET_MOUNT")
        if key1 then
            local displayText = key1:gsub("%-", " + ")
            if key2 then
                displayText = displayText .. ", " .. key2:gsub("%-", " + ")
            end
            copyMountKeybindButton:SetText(displayText)
        else
            copyMountKeybindButton:SetText("Click to bind")
        end
    end
    
    -- Store the update function for refresh
    self.UpdateCopyMountKeybindButtonText = UpdateCopyMountKeybindButtonText
    
    -- Refresh on show
    copyMountKeybindButton:SetScript("OnShow", function()
        UpdateCopyMountKeybindButtonText()
    end)
    
    UpdateCopyMountKeybindButtonText()
    
    local copyMountBindingFrame = nil
    local isCopyMountBinding = false
    
    copyMountKeybindButton:SetScript("OnClick", function(self)
        if isCopyMountBinding then return end
        
        isCopyMountBinding = true
        self:SetText("Press a key...")
        
        -- Create invisible frame to capture key input
        if not copyMountBindingFrame then
            copyMountBindingFrame = CreateFrame("Frame", nil, UIParent)
            copyMountBindingFrame:SetFrameStrata("DIALOG")
            copyMountBindingFrame:EnableKeyboard(true)
            copyMountBindingFrame:SetPropagateKeyboardInput(false)
        end
        
        copyMountBindingFrame:SetScript("OnKeyDown", function(frame, key)
            -- Allow ESC to cancel
            if key == "ESCAPE" then
                isCopyMountBinding = false
                copyMountBindingFrame:Hide()
                copyMountBindingFrame:SetScript("OnKeyDown", nil)
                UpdateCopyMountKeybindButtonText()
                return
            end
            
            -- Ignore modifier keys by themselves
            if key == "LSHIFT" or key == "RSHIFT" or 
               key == "LCTRL" or key == "RCTRL" or 
               key == "LALT" or key == "RALT" then
                return
            end
            
            -- Normalize key to uppercase
            key = key:upper()
            
            -- Build the key combination
            local keyCombo = ""
            if IsControlKeyDown() then
                keyCombo = "CTRL-"
            end
            if IsAltKeyDown() then
                keyCombo = keyCombo .. "ALT-"
            end
            if IsShiftKeyDown() then
                keyCombo = keyCombo .. "SHIFT-"
            end
            keyCombo = keyCombo .. key
            
            -- Clear existing bindings for this action
            local key1, key2 = GetBindingKey("BOLT_COPY_TARGET_MOUNT")
            if key1 then SetBinding(key1, nil) end
            if key2 then SetBinding(key2, nil) end
            
            -- Set the new binding
            local result = SetBinding(keyCombo, "BOLT_COPY_TARGET_MOUNT")
            if result then
                SaveBindings(GetCurrentBindingSet())
                copyMountKeybindButton:SetText(keyCombo:gsub("%-", " + "))
                C_Timer.After(0.5, UpdateCopyMountKeybindButtonText)
            else
                copyMountKeybindButton:SetText("Binding failed - try another key")
                C_Timer.After(1.5, UpdateCopyMountKeybindButtonText)
            end
            
            isCopyMountBinding = false
            copyMountBindingFrame:Hide()
            copyMountBindingFrame:SetScript("OnKeyDown", nil)
        end)
        
        copyMountBindingFrame:Show()
    end)
    
    -- Clear keybinding button
    local clearCopyMountKeybindButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearCopyMountKeybindButton:SetPoint("LEFT", copyMountKeybindButton, "RIGHT", 10, 0)
    clearCopyMountKeybindButton:SetSize(80, 25)
    clearCopyMountKeybindButton:SetText("Clear")
    self.widgets.clearCopyMountKeybindButton = clearCopyMountKeybindButton
    clearCopyMountKeybindButton:SetScript("OnClick", function()
        local key1, key2 = GetBindingKey("BOLT_COPY_TARGET_MOUNT")
        if key1 then SetBinding(key1, nil) end
        if key2 then SetBinding(key2, nil) end
        SaveBindings(GetCurrentBindingSet())
        UpdateCopyMountKeybindButtonText()
    end)
    
    yOffset = yOffset - 35
    
    -- Slash command note
    local copyMountSlashNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    copyMountSlashNote:SetPoint("TOPLEFT", content, "TOPLEFT", 70, yOffset)
    copyMountSlashNote:SetText("You can also use |cffFFD100/copymount|r or |cffFFD100/cm|r")
    copyMountSlashNote:SetTextColor(0.7, 0.7, 0.7)
    self.widgets.copyMountSlashNote = copyMountSlashNote
    
    yOffset = yOffset - 30
          
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
    else
        local legacyAdd = rawget(_G, "InterfaceOptions_AddCategory")
        if type(legacyAdd) == "function" then
            legacyAdd(panel)
        end
    end
    
    self.optionsPanel = panel
end

-- Convenience method to refresh all UI states
function Config:RefreshAll()
    self:RefreshOptionsPanel()
    self:UpdateGameMenuChildControls()
    self:UpdatePlaygroundChildControls()
    self:UpdateSkyridingChildControls()
    self:UpdateCurrentToyDisplay()
    
    -- Refresh keybind buttons
    if self.UpdateKeybindButtonText then
        self.UpdateKeybindButtonText()
    end
    if self.UpdateCopyMountKeybindButtonText then
        self.UpdateCopyMountKeybindButtonText()
    end
end

function Config:RefreshOptionsPanel()
    -- Small delay to ensure UI is ready
    C_Timer.After(0.05, function()
        local w = self.widgets
        
        -- Refresh all checkbox states in the main options panel
        if w.gameMenuCheckbox then
            local enabled = self.parent:IsModuleEnabled("gameMenu")
            w.gameMenuCheckbox:SetChecked(enabled)
        end
        
        if w.leaveGroupCheckbox then
            w.leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup"))
        end
        
        if w.reloadCheckbox then
            w.reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton"))
        end

        if w.groupToolsCheckbox then
            w.groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "groupToolsEnabled"))
        end
        
        if w.raidMarkerDropdown then
            local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
            -- Set the text again in case marker changed elsewhere
            if idx == 0 then
                UIDropDownMenu_SetText(w.raidMarkerDropdown, "Clear (no marker)")
            else
                local names = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"}
                UIDropDownMenu_SetText(w.raidMarkerDropdown, names[idx] or "Star")
            end
        end
        
        if w.playgroundCheckbox then
            local enabled = self.parent:IsModuleEnabled("playground")
            w.playgroundCheckbox:SetChecked(enabled)
        end
        
        if w.favoriteToyCheckbox then
            w.favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground", "showFavoriteToy"))
        end
        
        if w.skyridingCheckbox then
            local enabled = self.parent:IsModuleEnabled("skyriding")
            w.skyridingCheckbox:SetChecked(enabled)
        end
        
        if w.pitchControlCheckbox then
            w.pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl"))
        end
        
        if w.invertPitchCheckbox then
            w.invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding", "invertPitch"))
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
        
        -- Update keybinding button display
        if self.UpdateKeybindButtonText then
            self.UpdateKeybindButtonText()
        end
    end)
end

-- Update child control states based on parent module status
function Config:UpdateGameMenuChildControls()
    local gameMenuEnabled = self.parent:IsModuleEnabled("gameMenu")
    local w = self.widgets
    
    -- Enable/disable child controls based on parent module
    if w.leaveGroupCheckbox then
        w.leaveGroupCheckbox:SetEnabled(gameMenuEnabled)
        w.leaveGroupCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if w.reloadCheckbox then
        w.reloadCheckbox:SetEnabled(gameMenuEnabled)
        w.reloadCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if w.groupToolsCheckbox then
        w.groupToolsCheckbox:SetEnabled(gameMenuEnabled)
        w.groupToolsCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if w.battleTextCheckbox then
        w.battleTextCheckbox:SetEnabled(gameMenuEnabled)
        w.battleTextCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    if w.volumeButtonCheckbox then
        w.volumeButtonCheckbox:SetEnabled(gameMenuEnabled)
        w.volumeButtonCheckbox:SetAlpha(gameMenuEnabled and 1.0 or 0.5)
    end
    
    local groupToolsEnabled = self.parent:GetConfig("gameMenu", "groupToolsEnabled") and gameMenuEnabled
    if w.raidMarkerDropdown then
        if groupToolsEnabled then
            if UIDropDownMenu_EnableDropDown then
                UIDropDownMenu_EnableDropDown(w.raidMarkerDropdown)
            end
            w.raidMarkerDropdown:SetAlpha(1.0)
        else
            if UIDropDownMenu_DisableDropDown then
                UIDropDownMenu_DisableDropDown(w.raidMarkerDropdown)
            end
            w.raidMarkerDropdown:SetAlpha(0.5)
        end
    end
    
    if w.raidMarkerLabel then
        w.raidMarkerLabel:SetAlpha(groupToolsEnabled and 1.0 or 0.5)
    end
end

-- Update child control states for Playground module
function Config:UpdatePlaygroundChildControls()
    local playgroundEnabled = self.parent:IsModuleEnabled("playground")
    local w = self.widgets
    
    -- Enable/disable child controls based on parent module
    if w.favoriteToyCheckbox then
        w.favoriteToyCheckbox:SetEnabled(playgroundEnabled)
        w.favoriteToyCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    if w.fpsCheckbox then
        w.fpsCheckbox:SetEnabled(playgroundEnabled)
        w.fpsCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    if w.speedometerCheckbox then
        w.speedometerCheckbox:SetEnabled(playgroundEnabled)
        w.speedometerCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end
    
    if w.copyTargetMountCheckbox then
        w.copyTargetMountCheckbox:SetEnabled(playgroundEnabled)
        w.copyTargetMountCheckbox:SetAlpha(playgroundEnabled and 1.0 or 0.5)
    end

    -- Show/hide stats position controls based on whether FPS or speedometer is enabled
    local showStatsControls = playgroundEnabled and (self.parent:GetConfig("playground", "showFPS") or self.parent:GetConfig("playground", "showSpeedometer"))
    
    if w.statsPositionLabel then
        if showStatsControls then
            w.statsPositionLabel:Show()
        else
            w.statsPositionLabel:Hide()
        end
    end
    
    if w.statsPositionDropdown then
        if showStatsControls then
            w.statsPositionDropdown:Show()
            if UIDropDownMenu_EnableDropDown then
                UIDropDownMenu_EnableDropDown(w.statsPositionDropdown)
            end
        else
            w.statsPositionDropdown:Hide()
        end
    end
    
    -- Show/hide choose toy button and current toy display based on both module and feature being enabled
    local favoriteToyEnabled = playgroundEnabled and self.parent:GetConfig("playground", "showFavoriteToy")
    
    if w.chooseToyButton then
        if favoriteToyEnabled then
            w.chooseToyButton:Show()
            w.chooseToyButton:SetEnabled(true)
        else
            w.chooseToyButton:Hide()
        end
    end
    
    if w.currentToyDisplay then
        if favoriteToyEnabled then
            w.currentToyDisplay:Show()
            -- Update the current toy display
            self:UpdateCurrentToyDisplay()
        else
            w.currentToyDisplay:Hide()
        end
    end
end

function Config:UpdateCurrentToyDisplay()
    local w = self.widgets
    
    if not w.currentToyIcon or not w.currentToyText then
        return
    end
    
    local selectedToyId = self.parent:GetConfig("playground", "favoriteToyId")
    
    if selectedToyId and PlayerHasToy(selectedToyId) then
        local _, toyName, toyIconPath = C_ToyBox.GetToyInfo(selectedToyId)
        if toyName and toyName ~= "" then
            w.currentToyIcon:SetTexture(toyIconPath)
            w.currentToyText:SetText(toyName)
            w.currentToyText:SetTextColor(1, 1, 1) -- White text for selected toy
        else
            w.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            w.currentToyText:SetText("Unknown toy")
            w.currentToyText:SetTextColor(1, 0.8, 0) -- Yellow text for unknown
        end
    else
        w.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        w.currentToyText:SetText("None selected")
        w.currentToyText:SetTextColor(0.5, 0.5, 0.5) -- Gray text for none selected
    end
end

-- Update child control states for Skyriding module
function Config:UpdateSkyridingChildControls()
    local skyridingEnabled = self.parent:IsModuleEnabled("skyriding")
    local pitchControlEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
    local w = self.widgets
    
    -- Enable/disable child controls based on parent module
    if w.pitchControlCheckbox then
        w.pitchControlCheckbox:SetEnabled(skyridingEnabled)
        w.pitchControlCheckbox:SetAlpha(skyridingEnabled and 1.0 or 0.5)
    end
    
    if w.invertPitchCheckbox then
        -- Invert pitch is only available when both skyriding and pitch control are enabled
        local shouldEnable = skyridingEnabled and pitchControlEnabled
        w.invertPitchCheckbox:SetEnabled(shouldEnable)
        w.invertPitchCheckbox:SetAlpha(shouldEnable and 1.0 or 0.5)
    end
    
    -- Toggle mode removed; nothing to update here
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
    
    -- Store references for later use (use distinct names to avoid collision with options scroll frame)
    self.toyFrame = toyFrame
    self.searchBox = searchBox
    self.currentToyButton = currentToy
    self.currentToyIcon = currentIcon
    self.currentToyText = currentText
    self.toyScrollFrame = scrollFrame
    self.toyScrollChild = scrollChild
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
    if not self.toyScrollChild then 
        return 
    end
    
    -- Clear existing buttons
    for _, button in pairs(self.toyButtons) do
        button:Hide()
        -- Keep parented for reuse
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
                    icon = icon,
                    lcname = toyName:lower() -- Cache lowercased name for performance
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
    if not self.toyScrollChild or not self.allToys then return end
    
    local searchText = ""
    if self.searchBox then
        searchText = self.searchBox:GetText():lower()
    end
    
    -- Filter toys based on search (using cached lowercased names for performance)
    local filteredToys = {}
    for _, toy in ipairs(self.allToys) do
        if searchText == "" or toy.lcname:find(searchText, 1, true) then
            table.insert(filteredToys, toy)
        end
    end
    
    -- Create buttons for filtered toys
    local yOffset = 0
    local buttonHeight = 30
    
    for i, toy in ipairs(filteredToys) do
        local button = self.toyButtons[i]
        if not button then
            button = CreateFrame("Button", nil, self.toyScrollChild)
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
        
        button:SetPoint("TOPLEFT", self.toyScrollChild, "TOPLEFT", 0, -yOffset)
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
    self.toyScrollChild:SetHeight(math.max(yOffset, 1))
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
