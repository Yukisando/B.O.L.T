-- B.O.L.T Configuration UI
local ADDON_NAME, BOLT = ...

local Config = {}

-- Centralized keybinding capture helper
local _bindingCaptureFrame
local function StartKeybindingCapture(button, bindingAction, updateFunc)
    if not button or button._isBinding then return end
    button._isBinding = true
    button:SetText("Press a key...")
    if not _bindingCaptureFrame then
        _bindingCaptureFrame = CreateFrame("Frame", nil, UIParent)
        _bindingCaptureFrame:SetFrameStrata("DIALOG")
        _bindingCaptureFrame:EnableKeyboard(true)
        _bindingCaptureFrame:SetPropagateKeyboardInput(false)
    end
    local f = _bindingCaptureFrame
    f:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            button._isBinding = false
            f:Hide()
            f:SetScript("OnKeyDown", nil)
            if updateFunc then updateFunc() end
            return
        end
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
            return
        end
        local combo = ""
        if IsControlKeyDown() then combo = "CTRL-" end
        if IsAltKeyDown() then combo = combo .. "ALT-" end
        if IsShiftKeyDown() then combo = combo .. "SHIFT-" end
        combo = combo .. key:upper()
        local k1,k2 = GetBindingKey(bindingAction)
        if k1 then SetBinding(k1, nil) end
        if k2 then SetBinding(k2, nil) end
        if SetBinding(combo, bindingAction) then
            SaveBindings(GetCurrentBindingSet())
            if updateFunc then C_Timer.After(0.5, updateFunc) end
        else
            button:SetText("Binding failed - try another key")
            if updateFunc then C_Timer.After(1.5, updateFunc) end
        end
        button._isBinding = false
        f:Hide()
        f:SetScript("OnKeyDown", nil)
    end)
    f:Show()
    f:SetFocus()
end

function Config:OnInitialize()
    self.widgets = {}
    self:CreateInterfaceOptionsPanel()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("TOYS_UPDATED")
    -- Also listen for login so we can attempt an initial population when the player logs in
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.toyListPopulated = false
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if self._toyDebug and self.parent and self.parent.Print then self.parent:Print(("Config Event: %s"):format(tostring(event))) end
        if (event == "TOYS_UPDATED" or event == "PLAYER_LOGIN") and self.toyFrame then
            -- On login or when the toy API signals an update, try to populate.
            -- Delay slightly on login to allow Blizzard Collections to finish initializing.
            C_Timer.After(0.1, function()
                if not self then return end
                -- If we haven't successfully populated yet, try again
                self:PopulateToyList()
                self.toyListPopulated = true
                if self.toyPopup and self.toyPopup:IsShown() then
                    self:UpdateToySelection()
                end
            end)
        end
    end)
end

function Config:CreateReloadIndicator(parent, anchor)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", anchor.Text, "RIGHT", 10, 0)
    label:SetText("|cFFFF6B6B(Requires /reload)|r")
    label:Hide()
    return label
end

function Config:CreateInterfaceOptionsPanel()
    local panel = CreateFrame("Frame", "BOLTOptionsPanel")
    panel.name = "B.O.L.T"
    panel:SetScript("OnShow", function() self:RefreshAll() end)

    local scrollFrame = CreateFrame("ScrollFrame", "BOLTScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", "BOLTScrollChild", scrollFrame)
    scrollFrame:SetScrollChild(content)
    content:SetWidth(700)

    self.optionsScrollFrame = scrollFrame
    self.optionsScrollChild = content

    -- Title
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
    title:SetText("B.O.L.T")

    local y = -60

    -- Game Menu section
    local gmLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gmLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    gmLabel:SetText("Game Menu")
    y = y - 24

    local gmEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    gmEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    gmEnable.Text:SetText("Enable Game Menu Module")
    gmEnable:SetScript("OnClick", function()
        local v = gmEnable:GetChecked()
        self.parent:SetConfig(v, "gameMenu", "enabled")
        self:RefreshAll()
    end)
    self.widgets.gameMenuCheckbox = gmEnable
    y = y - 30

    -- Raid marker: modern icon buttons
    local markerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    markerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, y)
    markerLabel:SetText("Raid marker for the button:")
    y = y - 26

    local markerContainer = CreateFrame("Frame", nil, content)
    markerContainer:SetPoint("TOPLEFT", markerLabel, "BOTTOMLEFT", 0, -4)
    markerContainer:SetSize(220, 24)
    self.widgets.raidMarkerContainer = markerContainer

    local function GetMarkerTexCoords(i)
        local map = {
            [1] = {0,0.25,0,0.25}, [2] = {0.25,0.5,0,0.25}, [3] = {0.5,0.75,0,0.25}, [4] = {0.75,1,0,0.25},
            [5] = {0,0.25,0.25,0.5}, [6] = {0.25,0.5,0.25,0.5}, [7] = {0.5,0.75,0.25,0.5}, [8] = {0.75,1,0.25,0.5}
        }
        return unpack(map[i])
    end

    local markerButtons = {}
    for i=1,8 do
        local b = CreateFrame("Button", nil, markerContainer)
        b:SetSize(20,20)
        b:SetPoint("LEFT", markerContainer, "LEFT", (i-1)*24, 0)
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        icon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
        icon:SetTexCoord(GetMarkerTexCoords(i))
        b:SetScript("OnClick", function()
            self.parent:SetConfig(i, "gameMenu", "raidMarkerIndex")
            for _,rb in ipairs(markerButtons) do rb:SetAlpha(0.6) end
            b:SetAlpha(1)
        end)
        markerButtons[i] = b
    end
    local clearBtn = CreateFrame("Button", nil, markerContainer, "UIPanelButtonTemplate")
    clearBtn:SetSize(60,20)
    clearBtn:SetPoint("LEFT", markerContainer, "LEFT", 8*24, 0)
    clearBtn:SetText("Clear")
    clearBtn:SetScript("OnClick", function()
        self.parent:SetConfig(0, "gameMenu", "raidMarkerIndex")
        for _,rb in ipairs(markerButtons) do rb:SetAlpha(0.6) end
        clearBtn:SetAlpha(1)
    end)
    self.widgets.raidMarkerButtons = markerButtons
    self.widgets.raidMarkerClearButton = clearBtn

    y = y - 36

    -- Battle text toggles, volume etc. (checkboxes only here)
    local battleCB = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    battleCB:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); battleCB.Text:SetText("Show Battle Text Toggles")
    self.widgets.battleTextCheckbox = battleCB
    battleCB:SetScript("OnClick", function()
        self.parent:SetConfig(battleCB:GetChecked(), "gameMenu", "showBattleTextToggles")
    end)
    y = y - 26

    local volCB = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    volCB:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); volCB.Text:SetText("Show Volume Control Button")
    self.widgets.volumeButtonCheckbox = volCB
    volCB:SetScript("OnClick", function()
        self.parent:SetConfig(volCB:GetChecked(), "gameMenu", "showVolumeButton")
    end)
    y = y - 36

    -- Keybinding for master volume
    local kbLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    kbLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    kbLabel:SetText("Toggle Master Volume Keybinding:")
    y = y - 26
    local keybindButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    keybindButton:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); keybindButton:SetSize(200,25)
    self.widgets.keybindButton = keybindButton
    local function UpdateKeybindButtonText()
        local k1,k2 = GetBindingKey("BOLT_TOGGLE_MASTER_VOLUME")
        if k1 then
            local s = k1:gsub("%-"," + ")
            if k2 then s = s .. ", " .. k2:gsub("%-"," + ") end
            keybindButton:SetText(s)
        else
            keybindButton:SetText("Click to bind")
        end
    end
    self.UpdateKeybindButtonText = UpdateKeybindButtonText
    keybindButton:SetScript("OnClick", function() StartKeybindingCapture(keybindButton, "BOLT_TOGGLE_MASTER_VOLUME", UpdateKeybindButtonText) end)
    keybindButton:SetScript("OnShow", UpdateKeybindButtonText); UpdateKeybindButtonText()
    local clearKB = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearKB:SetPoint("LEFT", keybindButton, "RIGHT", 10, 0); clearKB:SetSize(80,25); clearKB:SetText("Clear")
    clearKB:SetScript("OnClick", function()
        local k1,k2 = GetBindingKey("BOLT_TOGGLE_MASTER_VOLUME"); if k1 then SetBinding(k1,nil) end; if k2 then SetBinding(k2,nil) end; SaveBindings(GetCurrentBindingSet()); UpdateKeybindButtonText()
    end)
    self.widgets.clearKeybindButton = clearKB
    y = y - 40

    -- Skyriding options
    local skyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    skyLabel:SetText("Skyriding")
    y = y - 26
    local skyEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    skyEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y); skyEnable.Text:SetText("Enable Skyriding Module")
    skyEnable:SetScript("OnClick", function() self.parent:SetConfig(skyEnable:GetChecked(), "skyriding", "enabled"); self:RefreshAll() end)
    self.widgets.skyridingCheckbox = skyEnable
    y = y - 26
    local pitchCB = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    pitchCB:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); pitchCB.Text:SetText("Enable pitch control (W/S)")
    pitchCB:SetScript("OnClick", function() self.parent:SetConfig(pitchCB:GetChecked(), "skyriding", "enablePitchControl"); if self.parent.modules and self.parent.modules.skyriding and self.parent.modules.skyriding.OnPitchSettingChanged then self.parent.modules.skyriding:OnPitchSettingChanged() end end)
    self.widgets.pitchControlCheckbox = pitchCB
    y = y - 26
    local invertCB = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    invertCB:SetPoint("TOPLEFT", content, "TOPLEFT", 70, y); invertCB.Text:SetText("Invert pitch (W=dive)")
    invertCB:SetScript("OnClick", function() self.parent:SetConfig(invertCB:GetChecked(), "skyriding", "invertPitch"); if self.parent.modules and self.parent.modules.skyriding and self.parent.modules.skyriding.OnPitchSettingChanged then self.parent.modules.skyriding:OnPitchSettingChanged() end end)
    self.widgets.invertPitchCheckbox = invertCB
    y = y - 36
    local pgLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pgLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    pgLabel:SetText("Playground")
    y = y - 26
    local pgEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    pgEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y); pgEnable.Text:SetText("Enable Playground Module")
    pgEnable:SetScript("OnClick", function() self.parent:SetConfig(pgEnable:GetChecked(), "playground", "enabled"); self:RefreshAll() end)
    self.widgets.playgroundCheckbox = pgEnable
    y = y - 26
    
    -- FPS and Speedometer toggles
    local fpsCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    fpsCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); fpsCheckbox.Text:SetText("Show FPS Counter")
    fpsCheckbox:SetScript("OnClick", function() self.parent:SetConfig(fpsCheckbox:GetChecked(), "playground", "showFPS"); self:RefreshAll() end)
    fpsCheckbox:SetScript("OnShow", function() fpsCheckbox:SetChecked(self.parent:GetConfig("playground","showFPS")) end)
    self.widgets.fpsCheckbox = fpsCheckbox
    y = y - 26

    local speedometerCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    speedometerCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y); speedometerCheckbox.Text:SetText("Show Speedometer (speed %)")
    speedometerCheckbox:SetScript("OnClick", function() self.parent:SetConfig(speedometerCheckbox:GetChecked(), "playground", "showSpeedometer"); self:RefreshAll() end)
    speedometerCheckbox:SetScript("OnShow", function() speedometerCheckbox:SetChecked(self.parent:GetConfig("playground","showSpeedometer")) end)
    self.widgets.speedometerCheckbox = speedometerCheckbox
    y = y - 26
    
    local statsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statsLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, y)
    statsLabel:SetText("Stats position:")
    y = y - 24
    local posContainer = CreateFrame("Frame", nil, content)
    posContainer:SetPoint("TOPLEFT", statsLabel, "BOTTOMLEFT", 0, -6)
    posContainer:SetSize(220, 36)
    self.widgets.statsPositionContainer = posContainer
    -- Fixed order: top positions on top row, bottom positions on bottom row
    local posValues = {"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}
    local posNames = {"Top Left","Top Right","Bottom Left","Bottom Right"}
    local posButtons = {}
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, posContainer, "UIPanelButtonTemplate")
        btn:SetSize(100, 18)
        if i <= 2 then
            btn:SetPoint("TOPLEFT", posContainer, "TOPLEFT", (i-1)*104, 0)
        else
            btn:SetPoint("TOPLEFT", posContainer, "TOPLEFT", (i-3)*104, -20)
        end
        btn:SetText(posNames[i])
        btn:SetScript("OnClick", function()
            self.parent:SetConfig(posValues[i], "playground", "statsPosition")
            if self.parent.modules and self.parent.modules.playground and self.parent.modules.playground.UpdateStatsPosition then
                self.parent.modules.playground:UpdateStatsPosition()
            end
            for _,b in ipairs(posButtons) do b:SetAlpha(0.7) end
            btn:SetAlpha(1)
        end)
        posButtons[i] = btn
    end
    self.widgets.statsPositionButtons = posButtons
    y = y - 70

    -- Favorite Toy toggle and chooser
    local favoriteToyCheckbox = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    favoriteToyCheckbox:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    favoriteToyCheckbox.Text:SetText("Show Favorite Toy Button")
    favoriteToyCheckbox:SetScript("OnClick", function()
        self.parent:SetConfig(favoriteToyCheckbox:GetChecked(), "playground", "showFavoriteToy")
        self:RefreshAll()
    end)
    favoriteToyCheckbox:SetScript("OnShow", function() favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground","showFavoriteToy")) end)
    self.widgets.favoriteToyCheckbox = favoriteToyCheckbox
    y = y - 26

    local chooseToyButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    chooseToyButton:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    chooseToyButton:SetSize(120, 25)
    chooseToyButton:SetText("Choose Toy")
    chooseToyButton:SetScript("OnClick", function() self:ShowToySelectionPopup() end)
    self.widgets.chooseToyButton = chooseToyButton

    local currentToyDisplay = CreateFrame("Frame", nil, content)
    currentToyDisplay:SetPoint("LEFT", chooseToyButton, "RIGHT", 10, 0)
    currentToyDisplay:SetSize(250, 25)
    local currentToyIcon = currentToyDisplay:CreateTexture(nil, "ARTWORK")
    currentToyIcon:SetPoint("LEFT", currentToyDisplay, "LEFT", 0, 0)
    currentToyIcon:SetSize(20, 20)
    currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    local currentToyText = currentToyDisplay:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentToyText:SetPoint("LEFT", currentToyIcon, "RIGHT", 5, 0)
    currentToyText:SetPoint("RIGHT", currentToyDisplay, "RIGHT", 0, 0)
    currentToyText:SetJustifyH("LEFT")
    currentToyText:SetText("None selected")
    self.widgets.currentToyDisplay = currentToyDisplay
    self.widgets.currentToyIcon = currentToyIcon
    self.widgets.currentToyText = currentToyText
    y = y - 36

    -- Copy target mount keybind
    local copyKBLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    copyKBLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 70, y)
    copyKBLabel:SetText("Copy Target Mount Keybinding:")
    y = y - 26
    local copyKB = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    copyKB:SetPoint("TOPLEFT", content, "TOPLEFT", 70, y); copyKB:SetSize(200,25)
    self.widgets.copyMountKeybindButton = copyKB
    local function UpdateCopyKB()
        local k1,k2 = GetBindingKey("BOLT_COPY_TARGET_MOUNT")
        if k1 then
            local s = k1:gsub("%-"," + ")
            if k2 then s = s .. ", " .. k2:gsub("%-"," + ") end
            copyKB:SetText(s)
        else copyKB:SetText("Click to bind") end
    end
    self.UpdateCopyMountKeybindButtonText = UpdateCopyKB
    copyKB:SetScript("OnClick", function() StartKeybindingCapture(copyKB, "BOLT_COPY_TARGET_MOUNT", UpdateCopyKB) end)
    copyKB:SetScript("OnShow", UpdateCopyKB); UpdateCopyKB()
    local clearCopyKB = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    clearCopyKB:SetPoint("LEFT", copyKB, "RIGHT", 10, 0); clearCopyKB:SetSize(80,25); clearCopyKB:SetText("Clear")
    clearCopyKB:SetScript("OnClick", function() local k1,k2 = GetBindingKey("BOLT_COPY_TARGET_MOUNT"); if k1 then SetBinding(k1,nil) end; if k2 then SetBinding(k2,nil) end; SaveBindings(GetCurrentBindingSet()); UpdateCopyKB() end)
    self.widgets.clearCopyMountKeybindButton = clearCopyKB
    y = y - 40

    -- Reload button and version
    local reloadBtn = CreateFrame("Button", "BOLTOptionsReloadButton", content, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120,25); reloadBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y); reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", ReloadUI)
    y = y - 40
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    versionText:SetText("B.O.L.T v" .. (self.parent and self.parent.version or "?"))
    y = y - 30

    content:SetHeight(math.abs(y) + 100)
    scrollFrame:SetScript("OnSizeChanged", function(frame,w,h) content:SetWidth(w - 20) end)

    -- Register Settings category
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "B.O.L.T")
        self.settingsCategory = category
        Settings.RegisterAddOnCategory(category)
    else
        if self.parent and self.parent.Print then self.parent:Print("B.O.L.T: Settings API not found; options not registered.") end
    end

    self.optionsPanel = panel
end

-- Refresh logic
function Config:RefreshAll()
    self:RefreshOptionsPanel()
    self:UpdateGameMenuChildControls()
    self:UpdatePlaygroundChildControls()
    self:UpdateSkyridingChildControls()
    self:UpdateCurrentToyDisplay()
end

function Config:RefreshOptionsPanel()
    C_Timer.After(0.05, function()
        local w = self.widgets
        if w.gameMenuCheckbox then w.gameMenuCheckbox:SetChecked(self.parent:IsModuleEnabled("gameMenu")) end
        if w.leaveGroupCheckbox then w.leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu","showLeaveGroup")) end
        if w.reloadCheckbox then w.reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu","showReloadButton")) end
        if w.groupToolsCheckbox then w.groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu","groupToolsEnabled")) end
        if w.battleTextCheckbox then w.battleTextCheckbox:SetChecked(self.parent:GetConfig("gameMenu","showBattleTextToggles")) end
        if w.volumeButtonCheckbox then w.volumeButtonCheckbox:SetChecked(self.parent:GetConfig("gameMenu","showVolumeButton")) end
        -- Update raid marker visuals
        if w.raidMarkerButtons then
            local idx = self.parent:GetConfig("gameMenu","raidMarkerIndex") or 1
            for i,b in ipairs(w.raidMarkerButtons) do b:SetAlpha((i==idx) and 1 or 0.6) end
            if w.raidMarkerClearButton then w.raidMarkerClearButton:SetAlpha(idx==0 and 1 or 0.6) end
        end
        if w.playgroundCheckbox then w.playgroundCheckbox:SetChecked(self.parent:IsModuleEnabled("playground")) end
        if w.favoriteToyCheckbox then w.favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground","showFavoriteToy")) end
        if w.skyridingCheckbox then w.skyridingCheckbox:SetChecked(self.parent:IsModuleEnabled("skyriding")) end
        if w.pitchControlCheckbox then w.pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding","enablePitchControl")) end
        if w.invertPitchCheckbox then w.invertPitchCheckbox:SetChecked(self.parent:GetConfig("skyriding","invertPitch")) end
        -- Update stats position buttons
        if w.statsPositionButtons then
            local cur = self.parent:GetConfig("playground","statsPosition") or "BOTTOMLEFT"
            for i,btn in ipairs(w.statsPositionButtons) do
                btn:SetAlpha((cur == ({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"})[i]) and 1 or 0.7)
            end
        end
        -- Keybind displays
        if self.UpdateKeybindButtonText then self.UpdateKeybindButtonText() end
        if self.UpdateCopyMountKeybindButtonText then self.UpdateCopyMountKeybindButtonText() end
    end)
end

function Config:UpdateGameMenuChildControls()
    local enabled = self.parent:IsModuleEnabled("gameMenu")
    local w = self.widgets
    if w.leaveGroupCheckbox then w.leaveGroupCheckbox:SetEnabled(enabled); w.leaveGroupCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.reloadCheckbox then w.reloadCheckbox:SetEnabled(enabled); w.reloadCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.groupToolsCheckbox then w.groupToolsCheckbox:SetEnabled(enabled); w.groupToolsCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.battleTextCheckbox then w.battleTextCheckbox:SetEnabled(enabled); w.battleTextCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.volumeButtonCheckbox then w.volumeButtonCheckbox:SetEnabled(enabled); w.volumeButtonCheckbox:SetAlpha(enabled and 1 or 0.5) end
    local groupTools = enabled and self.parent:GetConfig("gameMenu","groupToolsEnabled")
    if w.raidMarkerButtons then
        for _,b in ipairs(w.raidMarkerButtons) do b:SetEnabled(groupTools); b:SetAlpha(groupTools and b:GetAlpha() or 0.5) end
        if w.raidMarkerClearButton then w.raidMarkerClearButton:SetEnabled(groupTools); w.raidMarkerClearButton:SetAlpha(groupTools and w.raidMarkerClearButton:GetAlpha() or 0.5) end
    end
    if w.raidMarkerLabel then w.raidMarkerLabel:SetAlpha(groupTools and 1 or 0.5) end
end

function Config:UpdatePlaygroundChildControls()
    local enabled = self.parent:IsModuleEnabled("playground")
    local w = self.widgets
    if w.favoriteToyCheckbox then w.favoriteToyCheckbox:SetEnabled(enabled); w.favoriteToyCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.fpsCheckbox then w.fpsCheckbox:SetEnabled(enabled); w.fpsCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.speedometerCheckbox then w.speedometerCheckbox:SetEnabled(enabled); w.speedometerCheckbox:SetAlpha(enabled and 1 or 0.5) end
    if w.copyTargetMountCheckbox then w.copyTargetMountCheckbox:SetEnabled(enabled); w.copyTargetMountCheckbox:SetAlpha(enabled and 1 or 0.5) end
    local showStats = enabled and (self.parent:GetConfig("playground","showFPS") or self.parent:GetConfig("playground","showSpeedometer"))
    if w.statsPositionContainer then if showStats then w.statsPositionContainer:Show() else w.statsPositionContainer:Hide() end end
    -- Always expose the chooser so users can pick a favorite even if the UI toggle is off
    if w.chooseToyButton then if enabled then w.chooseToyButton:Show() else w.chooseToyButton:Hide() end end
    -- Current toy display is shown when module enabled AND a favorite toy is set
    if w.currentToyDisplay then
        local fav = self.parent:GetConfig("playground","favoriteToyId")
        if enabled and fav then w.currentToyDisplay:Show() else w.currentToyDisplay:Hide() end
    end
end

function Config:UpdateSkyridingChildControls()
    local sk = self.parent:IsModuleEnabled("skyriding")
    local pitch = self.parent:GetConfig("skyriding","enablePitchControl")
    local w = self.widgets
    if w.pitchControlCheckbox then w.pitchControlCheckbox:SetEnabled(sk); w.pitchControlCheckbox:SetAlpha(sk and 1 or 0.5) end
    if w.invertPitchCheckbox then local should = sk and pitch; w.invertPitchCheckbox:SetEnabled(should); w.invertPitchCheckbox:SetAlpha(should and 1 or 0.5) end
end

function Config:UpdateCurrentToyDisplay()
    local w = self.widgets
    if not w.currentToyIcon or not w.currentToyText then return end
    local toyID = self.parent:GetConfig("playground","favoriteToyId")
    if toyID then
        -- C_ToyBox.GetToyInfo returns: itemID, toyName, icon, isFavorite, hasFanfare, itemQuality
        local itemID, toyName, icon = C_ToyBox.GetToyInfo(toyID)
        if itemID and toyName and PlayerHasToy(itemID) then
            w.currentToyIcon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            w.currentToyText:SetText(toyName)
            return
        end
    end
    w.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    w.currentToyText:SetText("None selected")
end

-- Toy selection UI
function Config:ShowToySelectionPopup()
    if not self.toyPopup then 
        self:CreateToySelectionPopup() 
    end
    self.toyPopup:Show()
    self:PopulateToyList()
    self.toyListPopulated = true
    self:UpdateToySelection()
end

function Config:CreateToySelectionPopup()
    local popup = CreateFrame("Frame", "BOLTToySelectionPopup", UIParent, "DialogBoxFrame")
    popup:SetSize(450,400); popup:SetPoint("CENTER"); popup:SetFrameStrata("DIALOG")
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge") title:SetPoint("TOP", popup, "TOP", 0, -20) title:SetText("Choose Favorite Toy")
    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton") close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    self:CreateToySelectionFrame(popup, 15, -50)
    self.toyPopup = popup
    popup:Hide()
end

function Config:CreateToySelectionFrame(parent, xOffset, yOffset)
    local toyFrame = CreateFrame("Frame", "BOLTToySelectionFrame", parent)
    toyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset); toyFrame:SetSize(420,320)
    local searchLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") searchLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -15) searchLabel:SetText("Search:")
    local searchBox = CreateFrame("EditBox", "BOLTToySearchBox", toyFrame, "InputBoxTemplate") searchBox:SetPoint("TOPLEFT", searchLabel, "TOPRIGHT", 15, 0); searchBox:SetSize(220,28); searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function() self:FilterToyList() end)
    local clear = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate") clear:SetPoint("LEFT", searchBox, "RIGHT", 10, 0); clear:SetSize(50,28); clear:SetText("Clear"); clear:SetScript("OnClick", function() searchBox:SetText(""); self:FilterToyList() end)
    local refresh = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate") refresh:SetPoint("LEFT", clear, "RIGHT", 8, 0); refresh:SetSize(60,28); refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function() self:PopulateToyList(); self:UpdateToySelection() end)
    local currentLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal") currentLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -50); currentLabel:SetText("Current:")
    local currentToy = CreateFrame("Button", "BOLTCurrentToyButton", toyFrame); currentToy:SetPoint("LEFT", currentLabel, "RIGHT", 15, 0); currentToy:SetSize(220,28)
    local currentIcon = currentToy:CreateTexture(nil, "ARTWORK") currentIcon:SetPoint("LEFT", currentToy, "LEFT", 4, 0); currentIcon:SetSize(20,20)
    local currentText = currentToy:CreateFontString(nil, "OVERLAY", "GameFontHighlight") currentText:SetPoint("LEFT", currentIcon, "RIGHT", 8, 0) currentText:SetPoint("RIGHT", currentToy, "RIGHT", -8, 0) currentText:SetJustifyH("LEFT") currentText:SetText("None selected")
    currentToy:SetScript("OnClick", function() self.parent:SetConfig(nil, "playground", "favoriteToyId"); self:UpdateToySelection(); if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then self.parent.modules.playground:UpdateFavoriteToyButton() end end)
    local scrollFrame = CreateFrame("ScrollFrame", "BOLTToyScrollFrame", toyFrame, "UIPanelScrollFrameTemplate"); scrollFrame:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -85); scrollFrame:SetPoint("BOTTOMRIGHT", toyFrame, "BOTTOMRIGHT", -35, 15)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame); scrollFrame:SetScrollChild(scrollChild); scrollChild:SetSize(370,1)
    self.toyFrame = toyFrame; self.searchBox = searchBox; self.currentToyButton = currentToy; self.currentToyIcon = currentIcon; self.currentToyText = currentText; self.toyScrollFrame = scrollFrame; self.toyScrollChild = scrollChild; self.toyButtons = {}
    toyFrame:SetScript("OnShow", function()
        C_Timer.After(0.1, function()
            if not self.toyListPopulated then
                self:PopulateToyList()
                self.toyListPopulated = true
            end
            self:UpdateToySelection()
        end)
    end)
    self:UpdateToySelection()
end

function Config:PopulateToyList()
    if not self.toyScrollChild then return end
    for _,b in pairs(self.toyButtons) do b:Hide() end
    self.toyButtons = {}
    self.allToys = {}

    if not C_ToyBox or type(C_ToyBox.GetNumToys) ~= "function" then
        return
    end

    local numToys = C_ToyBox.GetNumToys() or 0
    for i = 1, numToys do
        local toyID = C_ToyBox.GetToyFromIndex(i)
        if toyID and toyID > 0 then
            -- C_ToyBox.GetToyInfo returns: itemID, toyName, icon, isFavorite, hasFanfare, itemQuality
            local itemID, toyName, icon = C_ToyBox.GetToyInfo(toyID)
            
            -- Check ownership using PlayerHasToy with itemID
            if itemID and toyName and PlayerHasToy(itemID) then
                -- Icon fallback from item cache if needed
                if not icon and GetItemInfo then
                    icon = select(10, GetItemInfo(itemID))
                end
                
                table.insert(self.allToys, {
                    id = toyID,
                    itemId = itemID,
                    name = toyName,
                    icon = icon,
                    lcname = string.lower(toyName)
                })
            end
        end
    end

    table.sort(self.allToys, function(a,b) return a.name < b.name end)
    self:FilterToyList()

    -- Schedule icon-cache retry for toys missing icons
    local needsIcon = false
    for _,t in ipairs(self.allToys) do 
        if not t.icon and t.itemId then 
            needsIcon = true
            break 
        end 
    end
    
    if needsIcon then
        C_Timer.After(0.5, function()
            if not self or not self.allToys then return end
            local changed = false
            for _,t in ipairs(self.allToys) do
                if not t.icon and t.itemId and GetItemInfo then
                    local maybeIcon = select(10, GetItemInfo(t.itemId))
                    if maybeIcon then 
                        t.icon = maybeIcon
                        changed = true 
                    end
                end
            end
            if changed and self.FilterToyList then 
                self:FilterToyList() 
            end
        end)
    end
end

function Config:FilterToyList()
    if not self.toyScrollChild or not self.allToys then return end
    local searchText = ""
    if self.searchBox then searchText = self.searchBox:GetText():lower() end
    local filteredToys = {}
    for _, toy in ipairs(self.allToys) do
        if searchText == "" or toy.lcname:find(searchText, 1, true) then
            table.insert(filteredToys, toy)
        end
    end
    local yOffset = 0
    local buttonHeight = 30
    for i, toy in ipairs(filteredToys) do
        local button = self.toyButtons[i]
        if not button then
            button = CreateFrame("Button", nil, self.toyScrollChild)
            button:SetSize(360, buttonHeight)
            local highlight = button:CreateTexture(nil, "HIGHLIGHT")
            highlight:SetAllPoints()
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", button, "LEFT", 5, 0)
            icon:SetSize(22, 22)
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", icon, "RIGHT", 10, 0)
            text:SetPoint("RIGHT", button, "RIGHT", -10, 0)
            text:SetJustifyH("LEFT")
            button.icon = icon
            button.text = text
            self.toyButtons[i] = button
        end
        button:SetPoint("TOPLEFT", self.toyScrollChild, "TOPLEFT", 0, -yOffset)
        -- Safe texture set: use toy icon if present, otherwise a question mark placeholder
        if toy.icon then
            button.icon:SetTexture(toy.icon)
        else
            button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        -- Ensure full UVs so icon draws correctly
        button.icon:SetTexCoord(0,1,0,1)
        button.text:SetText(toy.name)
        button:SetScript("OnClick", function()
            self.parent:SetConfig(toy.id, "playground", "favoriteToyId")
            if self.parent and self.parent.Print then self.parent:Print("Favorite toy set to: " .. toy.name) end
            self:UpdateToySelection()
            if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then self.parent.modules.playground:UpdateFavoriteToyButton() end
        end)
        button:Show()
        yOffset = yOffset + buttonHeight
    end
    for i = #filteredToys + 1, #self.toyButtons do if self.toyButtons[i] then self.toyButtons[i]:Hide() end end
    self.toyScrollChild:SetHeight(math.max(yOffset, 1))
end

function Config:UpdateToySelection()
    if not self.currentToyButton then return end
    local currentToyID = self.parent:GetConfig("playground", "favoriteToyId")
    if currentToyID then
        -- C_ToyBox.GetToyInfo returns: itemID, toyName, icon, isFavorite, hasFanfare, itemQuality
        local itemID, toyName, toyIcon = C_ToyBox.GetToyInfo(currentToyID)
        if itemID and toyName then
            self.currentToyIcon:SetTexture(toyIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
            self.currentToyText:SetText(toyName)
            self:UpdateCurrentToyDisplay()
            return
        end
    end
    self.currentToyIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    self.currentToyText:SetText("None selected (click to clear)")
    self:UpdateCurrentToyDisplay()
end

BOLT:RegisterModule("config", Config)
