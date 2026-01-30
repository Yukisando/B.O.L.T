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
        local k1, k2 = GetBindingKey(bindingAction)
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

local function TrimWhitespace(text)
    if type(text) ~= "string" then
        return ""
    end

    local trimmed = text:match("^%s*(.-)%s*$")
    return trimmed or ""
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
    -- When the options panel shows, mark the GameMenu module so it won't re-show widgets.
    panel:SetScript("OnShow", function()
        self:RefreshAll()
        if self.parent and self.parent.modules and self.parent.modules.gameMenu then
            self.parent.modules.gameMenu.settingsPanelOpen = true
            -- Ensure all widgets are hidden immediately when the panel opens
            self.parent.modules.gameMenu:EnsureHiddenIfMenuNotShown()
        end
    end)
    panel:SetScript("OnHide", function()
        if self.parent and self.parent.modules and self.parent.modules.gameMenu then
            self.parent.modules.gameMenu.settingsPanelOpen = nil
        end
    end)

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
    gmEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("gameMenu", checked)
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.gameMenuCheckbox = gmEnable
    self.widgets.gameMenuReloadIndicator = self:CreateReloadIndicator(content, gmEnable)

    -- Game Menu options
    y = y - 30

    local leaveGroupEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    leaveGroupEnable.Text:SetText("Show Leave Group Button")
    leaveGroupEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showLeaveGroup")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.leaveGroupCheckbox = leaveGroupEnable
    y = y - 30

    local reloadEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    reloadEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    reloadEnable.Text:SetText("Show Reload UI Button")
    reloadEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showReloadButton")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.reloadCheckbox = reloadEnable
    y = y - 30

    local groupToolsEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    groupToolsEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    groupToolsEnable.Text:SetText("Enable Group Tools (Ready/Countdown/Raid Marker)")
    groupToolsEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "groupToolsEnabled")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.groupToolsCheckbox = groupToolsEnable
    y = y - 30

    local battleTextEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    battleTextEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    battleTextEnable.Text:SetText("Show Battle Text Toggles")
    battleTextEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showBattleTextToggles")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.battleTextCheckbox = battleTextEnable
    y = y - 30

    local volumeEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    volumeEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    volumeEnable.Text:SetText("Show Volume Control Button")
    volumeEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showVolumeButton")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.volumeButtonCheckbox = volumeEnable
    y = y - 36

    -- Raid marker selector (for Group Tools)
    local markerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    markerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    markerLabel:SetText("Raid Marker Icon:")
    y = y - 22

    local MARKER_TEXCOORDS = {
        [1] = { 0, 0.25, 0, 0.25 },
        [2] = { 0.25, 0.5, 0, 0.25 },
        [3] = { 0.5, 0.75, 0, 0.25 },
        [4] = { 0.75, 1, 0, 0.25 },
        [5] = { 0, 0.25, 0.25, 0.5 },
        [6] = { 0.25, 0.5, 0.25, 0.5 },
        [7] = { 0.5, 0.75, 0.25, 0.5 },
        [8] = { 0.75, 1, 0.25, 0.5 },
    }

    self.widgets.raidMarkerButtons = self.widgets.raidMarkerButtons or {}
    local buttons = self.widgets.raidMarkerButtons
    local btnSize = 22
    local startX = 50
    local startY = y
    for i = 1, 8 do
        local b = buttons[i]
        if not b then
            b = CreateFrame("Button", nil, content)
            b:SetSize(btnSize, btnSize)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetAllPoints(b)
            b.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            buttons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", content, "TOPLEFT", startX + ((i - 1) * (btnSize + 4)), startY)
        local tc = MARKER_TEXCOORDS[i]
        b.tex:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        b:SetScript("OnClick", function()
            self.parent:SetConfig(i, "gameMenu", "raidMarkerIndex")
            self:RefreshOptionsPanel()
            self:UpdateGameMenuChildControls()
        end)
        b:Show()
    end

    local clearBtn = self.widgets.raidMarkerClearButton
    if not clearBtn then
        clearBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        clearBtn:SetSize(48, btnSize)
        clearBtn:SetText("Clear")
        clearBtn:SetScript("OnClick", function()
            self.parent:SetConfig(0, "gameMenu", "raidMarkerIndex")
            self:RefreshOptionsPanel()
            self:UpdateGameMenuChildControls()
        end)
        self.widgets.raidMarkerClearButton = clearBtn
    end
    clearBtn:ClearAllPoints()
    clearBtn:SetPoint("TOPLEFT", content, "TOPLEFT", startX + (8 * (btnSize + 4)) + 8, startY + 1)

    y = y - 40

    -- Playground section
    local pgLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pgLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    pgLabel:SetText("Playground")
    y = y - 24

    local pgEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    pgEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    pgEnable.Text:SetText("Enable Playground Module")
    pgEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("playground", checked)
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.playgroundCheckbox = pgEnable
    self.widgets.playgroundReloadIndicator = self:CreateReloadIndicator(content, pgEnable)
    y = y - 30

    -- Favorite Toy row: checkbox + button + current toy display
    local favToyEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    favToyEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    favToyEnable.Text:SetText("Favorite Toy Button")
    favToyEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "playground", "showFavoriteToy")
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.favoriteToyCheckbox = favToyEnable

    local chooseToyBtn = self.widgets.chooseToyButton
    if not chooseToyBtn then
        chooseToyBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        chooseToyBtn:SetSize(120, 24)
        chooseToyBtn:SetText("Choose Toy")
        chooseToyBtn:SetScript("OnClick", function() self:ShowToySelectionPopup() end)
        self.widgets.chooseToyButton = chooseToyBtn

        local toyRow = CreateFrame("Frame", nil, content)
        toyRow:SetSize(360, 24)
        self.widgets.currentToyRow = toyRow

        local icon = toyRow:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("LEFT", toyRow, "LEFT", 0, 0)
        icon:SetSize(20, 20)
        self.widgets.currentToyIcon = icon

        local text = toyRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        text:SetJustifyH("LEFT")
        text:SetText("None selected")
        self.widgets.currentToyText = text
    end

    chooseToyBtn:ClearAllPoints()
    chooseToyBtn:SetPoint("LEFT", favToyEnable.Text, "RIGHT", 10, 0)
    self.widgets.currentToyRow:ClearAllPoints()
    self.widgets.currentToyRow:SetPoint("LEFT", chooseToyBtn, "RIGHT", 12, 0)
    y = y - 30

    -- Speedometer row: checkbox + position dropdown
    local speedometerEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    speedometerEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    speedometerEnable.Text:SetText("Speedometer")
    speedometerEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "playground", "showSpeedometer")
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.speedometerCheckbox = speedometerEnable

    local posLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    posLabel:SetPoint("LEFT", speedometerEnable.Text, "RIGHT", 10, 0)
    posLabel:SetText("Position:")

    local posDropdown = self.widgets.speedometerPositionDropdown
    if not posDropdown then
        posDropdown = CreateFrame("Frame", "BOLTSpeedometerPositionDropdown", content, "UIDropDownMenuTemplate")
        self.widgets.speedometerPositionDropdown = posDropdown

        UIDropDownMenu_SetWidth(posDropdown, 110)
        UIDropDownMenu_Initialize(posDropdown, function(dropdown, level)
            local positions = {
                { text = "Top Left",     value = "TOPLEFT" },
                { text = "Top Right",    value = "TOPRIGHT" },
                { text = "Bottom Left",  value = "BOTTOMLEFT" },
                { text = "Bottom Right", value = "BOTTOMRIGHT" },
            }

            for _, pos in ipairs(positions) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = pos.text
                info.value = pos.value
                info.func = function(btn)
                    self.parent:SetConfig(btn.value, "playground", "statsPosition")
                    UIDropDownMenu_SetSelectedValue(posDropdown, btn.value)
                    if self.parent.modules.playground and self.parent.modules.playground.UpdateStatsPosition then
                        self.parent.modules.playground:UpdateStatsPosition()
                    end
                end
                info.checked = (self.parent:GetConfig("playground", "statsPosition") == pos.value)
                UIDropDownMenu_AddButton(info, level)
            end
        end)
    end

    posDropdown:ClearAllPoints()
    posDropdown:SetPoint("LEFT", posLabel, "RIGHT", -15, -2)

    local currentPos = self.parent:GetConfig("playground", "statsPosition") or "TOPRIGHT"
    UIDropDownMenu_SetSelectedValue(posDropdown, currentPos)
    local posNames = {
        TOPLEFT = "Top Left",
        TOPRIGHT = "Top Right",
        BOTTOMLEFT = "Bottom Left",
        BOTTOMRIGHT =
        "Bottom Right"
    }
    UIDropDownMenu_SetText(posDropdown, posNames[currentPos] or "Top Right")

    y = y - 36

    -- Skyriding section
    local skLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    skLabel:SetText("Skyriding")
    y = y - 24

    local skEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    skEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    skEnable.Text:SetText("Enable Skyriding Module")
    skEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("skyriding", checked)
        self:UpdateSkyridingChildControls()
    end)
    self.widgets.skyridingCheckbox = skEnable
    self.widgets.skyridingReloadIndicator = self:CreateReloadIndicator(content, skEnable)
    y = y - 30

    local pitchEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    pitchEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    pitchEnable.Text:SetText("Enable Pitch Control (W/S)")
    pitchEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "skyriding", "enablePitchControl")
        self:UpdateSkyridingChildControls()
    end)
    self.widgets.pitchControlCheckbox = pitchEnable
    y = y - 30

    local invertEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    invertEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    invertEnable.Text:SetText("Invert Pitch")
    invertEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "skyriding", "invertPitch")
    end)
    self.widgets.invertPitchCheckbox = invertEnable
    y = y - 40

    -- Teleports section
    local tpLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tpLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    tpLabel:SetText("Teleports")
    y = y - 24

    local tpEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    tpEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    tpEnable.Text:SetText("Enable Teleports Module")
    tpEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("teleports", checked)
        self:UpdateTeleportsChildControls()
    end)
    self.widgets.teleportsCheckbox = tpEnable
    self.widgets.teleportsReloadIndicator = self:CreateReloadIndicator(content, tpEnable)
    y = y - 30

    local editModeEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    editModeEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    editModeEnable.Text:SetText("Edit Mode (Allow adding/removing teleport pins)")
    editModeEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "teleports", "editMode")
    end)
    self.widgets.teleportsEditModeCheckbox = editModeEnable
    y = y - 30

    -- Teleport list label
    local tpListLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tpListLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    tpListLabel:SetText("Saved Teleports (click to edit, right-click to delete):")
    self.widgets.teleportListLabel = tpListLabel
    y = y - 20

    -- Teleport list scroll frame background (for visual containment)
    local tpScrollBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    tpScrollBg:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    tpScrollBg:SetSize(520, 200)
    tpScrollBg:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    tpScrollBg:SetBackdropColor(0, 0, 0, 0.5)
    tpScrollBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    
    -- Teleport list scroll frame (contained scrollable window)
    local tpScrollFrame = CreateFrame("ScrollFrame", "BOLTTeleportListScrollFrame", tpScrollBg, "UIPanelScrollFrameTemplate")
    tpScrollFrame:SetPoint("TOPLEFT", tpScrollBg, "TOPLEFT", 4, -4)
    tpScrollFrame:SetPoint("BOTTOMRIGHT", tpScrollBg, "BOTTOMRIGHT", -4, 4)
    
    -- Create scroll child container
    local tpListContainer = CreateFrame("Frame", nil, tpScrollFrame)
    tpListContainer:SetSize(500, 200) -- Height will be adjusted dynamically
    tpScrollFrame:SetScrollChild(tpListContainer)
    
    self.widgets.teleportListScrollFrame = tpScrollFrame
    self.widgets.teleportListContainer = tpListContainer
    self.widgets.teleportListRows = {}
    y = y - 210 -- Account for fixed scroll frame height

    -- Store the Y position reference so we can update content height
    self.widgets.teleportListYOffset = y

    -- WowheadLink section
    local wlLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wlLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    wlLabel:SetText("Wowhead Link")
    y = y - 24

    local wlEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    wlEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    wlEnable.Text:SetText("Enable Wowhead Link Module")
    wlEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("wowheadLink", checked)
    end)
    self.widgets.wowheadLinkCheckbox = wlEnable
    self.widgets.wowheadLinkReloadIndicator = self:CreateReloadIndicator(content, wlEnable)
    y = y - 30

    local wlDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wlDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    wlDesc:SetWidth(520)
    wlDesc:SetJustifyH("LEFT")
    wlDesc:SetText("Press Ctrl+C while hovering over an item to copy its Wowhead link. Default keybind is Ctrl+C.")
    y = y - 36

    -- Auto Rep Switch section
    local arsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    arsLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    arsLabel:SetText("Auto Rep Switch")
    y = y - 24

    local arsEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    arsEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    arsEnable.Text:SetText("Enable Auto Rep Switch Module")
    arsEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("autoRepSwitch", checked)
    end)
    self.widgets.autoRepSwitchCheckbox = arsEnable
    self.widgets.autoRepSwitchReloadIndicator = self:CreateReloadIndicator(content, arsEnable)
    y = y - 30

    local arsDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arsDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    arsDesc:SetWidth(520)
    arsDesc:SetJustifyH("LEFT")
    arsDesc:SetText("Automatically switch the watched reputation to the faction you just gained reputation with.")
    y = y - 36

    -- Reload button and version
    local reloadBtn = CreateFrame("Button", "BOLTOptionsReloadButton", content, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 25); reloadBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y); reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", ReloadUI)
    y = y - 40
    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    versionText:SetText("B.O.L.T v" .. (self.parent and self.parent.version or "?"))
    y = y - 30

    content:SetHeight(math.abs(y) + 100)
    scrollFrame:SetScript("OnSizeChanged", function(frame, w, h) content:SetWidth(w - 20) end)

    -- Register Settings category (modern API for 10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "B.O.L.T")
        self.settingsCategory = category
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        -- Fallback for older clients (pre-10.0)
        InterfaceOptions_AddCategory(panel)
        self.settingsCategory = panel
    else
        if self.parent and self.parent.Print then
            self.parent:Print("B.O.L.T: Settings API not available on this client version.")
        end
    end

    self.optionsPanel = panel
end

function Config:UpdateGameMenuChildControls()
    local enabled = false
    if self.parent and self.parent.IsModuleEnabled then
        enabled = self.parent:IsModuleEnabled("gameMenu")
    end
    local w = self.widgets

    -- Generic checkboxes
    if w and w.leaveGroupCheckbox then
        w.leaveGroupCheckbox:SetEnabled(enabled); w.leaveGroupCheckbox:SetAlpha(enabled and 1 or 0.5)
    end
    if w and w.reloadCheckbox then
        w.reloadCheckbox:SetEnabled(enabled); w.reloadCheckbox:SetAlpha(enabled and 1 or 0.5)
    end
    if w and w.groupToolsCheckbox then
        w.groupToolsCheckbox:SetEnabled(enabled); w.groupToolsCheckbox:SetAlpha(enabled and 1 or 0.5)
    end
    if w and w.battleTextCheckbox then
        w.battleTextCheckbox:SetEnabled(enabled); w.battleTextCheckbox:SetAlpha(enabled and 1 or 0.5)
    end
    if w and w.volumeButtonCheckbox then
        w.volumeButtonCheckbox:SetEnabled(enabled); w.volumeButtonCheckbox:SetAlpha(enabled and 1 or 0.5)
    end

    -- Raid marker buttons (may be a list of buttons and a clear button)
    local groupToolsEnabled = false
    if enabled and self.parent and self.parent.GetConfig then
        groupToolsEnabled = self.parent:GetConfig("gameMenu", "groupToolsEnabled")
    end
    if w and w.raidMarkerButtons then
        for _, b in ipairs(w.raidMarkerButtons) do
            if b then
                b:SetEnabled(groupToolsEnabled); b:SetAlpha(groupToolsEnabled and 1 or 0.5)
            end
        end
        if w.raidMarkerClearButton then
            w.raidMarkerClearButton:SetEnabled(groupToolsEnabled); w.raidMarkerClearButton:SetAlpha(groupToolsEnabled and
                1 or 0.5)
        end
    end

    -- If the GameMenu module is loaded, ask it to refresh its internal state for consistency
    if self.parent and self.parent.modules and self.parent.modules.gameMenu and self.parent.modules.gameMenu.UpdateGameMenu then
        self.parent.modules.gameMenu:UpdateGameMenu()
    end
end

function Config:UpdatePlaygroundChildControls()
    local enabled = self.parent:IsModuleEnabled("playground")
    local w = self.widgets

    if w.favoriteToyCheckbox then
        w.favoriteToyCheckbox:SetEnabled(enabled)
        w.favoriteToyCheckbox:SetAlpha(enabled and 1 or 0.5)
    end

    if w.speedometerCheckbox then
        w.speedometerCheckbox:SetEnabled(enabled)
        w.speedometerCheckbox:SetAlpha(enabled and 1 or 0.5)
    end

    if w.speedometerPositionDropdown then
        local speedometerEnabled = enabled and self.parent:GetConfig("playground", "showSpeedometer")
        if speedometerEnabled then
            UIDropDownMenu_EnableDropDown(w.speedometerPositionDropdown)
        else
            UIDropDownMenu_DisableDropDown(w.speedometerPositionDropdown)
        end
    end

    local canChooseToy = enabled and (self.parent:GetConfig("playground", "showFavoriteToy") ~= false)
    if w.chooseToyButton then
        w.chooseToyButton:SetEnabled(canChooseToy)
        w.chooseToyButton:SetAlpha(canChooseToy and 1 or 0.5)
    end
    if w.currentToyRow then
        w.currentToyRow:SetAlpha(canChooseToy and 1 or 0.5)
    end

    -- Update the actual speedometer visibility if module is loaded
    if self.parent.modules and self.parent.modules.playground and self.parent.modules.playground.UpdateSpeedometerVisibility then
        self.parent.modules.playground:UpdateSpeedometerVisibility()
    end
end

-- Refresh logic
function Config:RefreshAll()
    self:RefreshOptionsPanel()
    self:UpdateGameMenuChildControls()
    self:UpdatePlaygroundChildControls()
    self:UpdateSkyridingChildControls()
    self:UpdateTeleportsChildControls()
    self:UpdateCurrentToyDisplay()
end

function Config:RefreshOptionsPanel()
    C_Timer.After(0.05, function()
        local w = self.widgets
        if w.gameMenuCheckbox then w.gameMenuCheckbox:SetChecked(self.parent:IsModuleEnabled("gameMenu")) end
        if w.leaveGroupCheckbox then w.leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup")) end
        if w.reloadCheckbox then w.reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton")) end
        if w.groupToolsCheckbox then
            w.groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu",
                "groupToolsEnabled"))
        end
        if w.battleTextCheckbox then
            w.battleTextCheckbox:SetChecked(self.parent:GetConfig("gameMenu",
                "showBattleTextToggles"))
        end
        if w.volumeButtonCheckbox then
            w.volumeButtonCheckbox:SetChecked(self.parent:GetConfig("gameMenu",
                "showVolumeButton"))
        end
        -- Update raid marker visuals
        if w.raidMarkerButtons then
            local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
            for i, b in ipairs(w.raidMarkerButtons) do b:SetAlpha((i == idx) and 1 or 0.6) end
            if w.raidMarkerClearButton then w.raidMarkerClearButton:SetAlpha(idx == 0 and 1 or 0.6) end
        end
        if w.playgroundCheckbox then w.playgroundCheckbox:SetChecked(self.parent:IsModuleEnabled("playground")) end
        if w.favoriteToyCheckbox then
            w.favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground",
                "showFavoriteToy"))
        end
        if w.speedometerCheckbox then
            w.speedometerCheckbox:SetChecked(self.parent:GetConfig("playground",
                "showSpeedometer"))
        end
        if w.speedometerPositionDropdown then
            local currentPos = self.parent:GetConfig("playground", "statsPosition") or "TOPRIGHT"
            UIDropDownMenu_SetSelectedValue(w.speedometerPositionDropdown, currentPos)
            local posNames = {
                TOPLEFT = "Top Left",
                TOPRIGHT = "Top Right",
                BOTTOMLEFT = "Bottom Left",
                BOTTOMRIGHT =
                "Bottom Right"
            }
            UIDropDownMenu_SetText(w.speedometerPositionDropdown, posNames[currentPos] or "Top Right")
        end
        if w.skyridingCheckbox then w.skyridingCheckbox:SetChecked(self.parent:IsModuleEnabled("skyriding")) end
        if w.pitchControlCheckbox then
            w.pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding",
                "enablePitchControl"))
        end
        if w.wowheadLinkCheckbox then w.wowheadLinkCheckbox:SetChecked(self.parent:IsModuleEnabled("wowheadLink")) end
        if w.autoRepSwitchCheckbox then w.autoRepSwitchCheckbox:SetChecked(self.parent:IsModuleEnabled("autoRepSwitch")) end
        if w.teleportsCheckbox then w.teleportsCheckbox:SetChecked(self.parent:IsModuleEnabled("teleports")) end
        if w.teleportsEditModeCheckbox then
            local cfg = self.parent:GetConfig("teleports") or {}
            local editMode = cfg.editMode or false  -- Default to false
            w.teleportsEditModeCheckbox:SetChecked(editMode)
        end
    end)
end

function Config:UpdateSkyridingChildControls()
    local sk = self.parent:IsModuleEnabled("skyriding")
    local pitch = self.parent:GetConfig("skyriding", "enablePitchControl")
    local w = self.widgets
    if w.pitchControlCheckbox then
        w.pitchControlCheckbox:SetEnabled(sk); w.pitchControlCheckbox:SetAlpha(sk and 1 or 0.5)
    end
    if w.invertPitchCheckbox then
        local should = sk and pitch; w.invertPitchCheckbox:SetEnabled(should); w.invertPitchCheckbox:SetAlpha(should and
            1 or 0.5)
    end
end

function Config:UpdateTeleportsChildControls()
    -- Refresh the teleport list display
    self:RefreshTeleportList()
end

function Config:RefreshTeleportList()
    local w = self.widgets
    local container = w.teleportListContainer
    if not container then return end

    -- Clear existing rows
    if w.teleportListRows then
        for _, row in ipairs(w.teleportListRows) do
            if row then row:Hide(); row:SetParent(nil) end
        end
    end
    w.teleportListRows = {}

    local enabled = self.parent:IsModuleEnabled("teleports")
    local teleportList = {}
    if self.parent.modules and self.parent.modules.teleports then
        teleportList = self.parent.modules.teleports:GetTeleportList() or {}
    end

    local rowHeight = 24
    local rowY = 0

    for i, entry in ipairs(teleportList) do
        local row = CreateFrame("Button", nil, container)
        row:SetSize(480, rowHeight)
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, rowY)
        row:EnableMouse(enabled)
        row:SetAlpha(enabled and 1 or 0.5)

        -- Hover highlight
        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints()
        highlight:SetColorTexture(1, 1, 1, 0.1)

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(20, 20)
        icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        local iconPath = entry.icon
        if tonumber(iconPath) then
            icon:SetTexture(tonumber(iconPath))
        elseif iconPath and iconPath ~= "" then
            icon:SetTexture(iconPath)
        else
            icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end

        -- Name
        local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        name:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        name:SetWidth(200)
        name:SetJustifyH("LEFT")
        name:SetText(entry.name or "Unknown")

        -- Map info
        local mapInfo = C_Map.GetMapInfo(entry.mapID or 0)
        local mapName = mapInfo and mapInfo.name or ("Map " .. tostring(entry.mapID or 0))
        local mapLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mapLabel:SetPoint("LEFT", name, "RIGHT", 10, 0)
        mapLabel:SetWidth(120)
        mapLabel:SetJustifyH("LEFT")
        mapLabel:SetTextColor(0.7, 0.7, 0.7)
        mapLabel:SetText(mapName)

        -- Spell/Item/Toy name (the castable name)
        local castLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        castLabel:SetPoint("LEFT", mapLabel, "RIGHT", 10, 0)
        castLabel:SetWidth(150)
        castLabel:SetJustifyH("LEFT")
        castLabel:SetTextColor(0.5, 0.8, 0.5)
        local castName = entry.spellName or entry.name or "?"
        castLabel:SetText(castName)

        -- Click handler - left click to edit
        row:SetScript("OnClick", function(_, button)
            if button == "LeftButton" then
                self:ShowEditTeleportPopup(i, entry)
            elseif button == "RightButton" then
                self:ConfirmDeleteTeleport(i, entry)
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        table.insert(w.teleportListRows, row)
        rowY = rowY - rowHeight
    end

    -- Update container height to fit all rows (enables scrolling)
    local totalHeight = math.max(200, #teleportList * rowHeight)
    container:SetHeight(totalHeight)
    
    -- Set width to match scroll frame content area
    if w.teleportListScrollFrame then
        local scrollFrameWidth = w.teleportListScrollFrame:GetWidth() or 500
        container:SetWidth(scrollFrameWidth - 20) -- Account for scrollbar
    end

    -- Show "No teleports saved" if empty
    if #teleportList == 0 then
        local emptyLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        emptyLabel:SetPoint("CENTER", container, "CENTER", 0, 0)
        emptyLabel:SetTextColor(0.6, 0.6, 0.6)
        emptyLabel:SetText("No teleports saved. Open the World Map and press your keybind to add one.")
        local emptyRow = CreateFrame("Frame", nil, container)
        emptyRow.label = emptyLabel
        table.insert(w.teleportListRows, emptyRow)
    end
end

function Config:ShowEditTeleportPopup(index, entry)
    if not self.editTeleportPopup then
        self:CreateEditTeleportPopup()
    end

    local popup = self.editTeleportPopup
    popup.editIndex = index
    popup.nameInput:SetText(entry.name or "")
    popup.spellNameInput:SetText(entry.spellName or entry.name or "")
    popup.idInput:SetText(entry.id and tostring(entry.id) or "")

    local mapInfo = C_Map.GetMapInfo(entry.mapID or 0)
    local mapName = mapInfo and mapInfo.name or ("Map " .. tostring(entry.mapID or 0))
    popup.mapLabel:SetText(string.format("Map: %s (%d) at %.2f, %.2f", mapName, entry.mapID or 0, entry.x or 0, entry.y or 0))

    popup:Show()
    popup.nameInput:SetFocus()
end

function Config:CreateEditTeleportPopup()
    local popup = CreateFrame("Frame", "BOLTEditTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(420, 220)
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
    title:SetText("Edit Teleport")

    -- Map info label
    local mapLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapLabel:SetPoint("TOP", title, "BOTTOM", 0, -10)
    mapLabel:SetText("Map: Unknown")
    popup.mapLabel = mapLabel

    -- Display Name input
    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 25, -60)
    nameLabel:SetText("Display Name:")

    local nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameInput:SetSize(230, 20)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(100)
    popup.nameInput = nameInput

    -- Spell/Item/Toy Name input
    local spellNameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellNameLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -20)
    spellNameLabel:SetText("Spell/Item/Toy Name:")

    local spellNameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    spellNameInput:SetPoint("LEFT", spellNameLabel, "RIGHT", 10, 0)
    spellNameInput:SetSize(200, 20)
    spellNameInput:SetAutoFocus(false)
    spellNameInput:SetMaxLetters(100)
    popup.spellNameInput = spellNameInput

    -- ID input (optional)
    local idLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", spellNameLabel, "BOTTOMLEFT", 0, -20)
    idLabel:SetText("ID (optional):")

    local idInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    idInput:SetPoint("LEFT", idLabel, "RIGHT", 10, 0)
    idInput:SetSize(100, 20)
    idInput:SetAutoFocus(false)
    idInput:SetNumeric(true)
    popup.idInput = idInput

    -- Save button
    local saveBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -10, 20)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        self:SaveEditedTeleport()
    end)

    -- Cancel button
    local cancelBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 10, 20)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function()
        popup:Hide()
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    -- ESC to close
    tinsert(UISpecialFrames, "BOLTEditTeleportPopup")

    self.editTeleportPopup = popup
end

function Config:SaveEditedTeleport()
    local popup = self.editTeleportPopup
    if not popup or not popup.editIndex then return end

    local name = popup.nameInput:GetText()
    local spellName = popup.spellNameInput:GetText()
    
    if not name or name == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a display name.")
        end
        return
    end
    
    if not spellName or spellName == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a spell/item/toy name.")
        end
        return
    end

    local idText = popup.idInput:GetText()
    local id = tonumber(idText)

    -- Update via Teleports module
    if self.parent.modules and self.parent.modules.teleports then
        self.parent.modules.teleports:UpdateTeleport(popup.editIndex, {
            name = name,
            spellName = spellName,
            id = id
        })
    end

    popup:Hide()
    self:RefreshTeleportList()
end

function Config:ConfirmDeleteTeleport(index, entry)
    StaticPopupDialogs["BOLT_CONFIRM_DELETE_TELEPORT"] = {
        text = "Delete teleport '" .. (entry.name or "Unknown") .. "'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            if self.parent.modules and self.parent.modules.teleports then
                self.parent.modules.teleports:DeleteTeleport(index)
            end
            self:RefreshTeleportList()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("BOLT_CONFIRM_DELETE_TELEPORT")
end

function Config:UpdateCurrentToyDisplay()
    local w = self.widgets
    if not w.currentToyIcon or not w.currentToyText then return end
    local toyID = self.parent:GetConfig("playground", "favoriteToyId")
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
    popup:SetSize(450, 400); popup:SetPoint("CENTER"); popup:SetFrameStrata("DIALOG")
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Choose Favorite Toy")
    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)
    self:CreateToySelectionFrame(popup, 15, -50)
    self.toyPopup = popup
    popup:Hide()
end

function Config:CreateToySelectionFrame(parent, xOffset, yOffset)
    local toyFrame = CreateFrame("Frame", "BOLTToySelectionFrame", parent)
    toyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yOffset); toyFrame:SetSize(420, 320)
    local searchLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -15)
    searchLabel:SetText("Search:")
    local searchBox = CreateFrame("EditBox", "BOLTToySearchBox", toyFrame, "InputBoxTemplate")
    searchBox:SetPoint("TOPLEFT", searchLabel, "TOPRIGHT", 15, 0); searchBox:SetSize(220, 28); searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function() self:FilterToyList() end)
    local clear = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate")
    clear:SetPoint("LEFT", searchBox, "RIGHT", 10, 0); clear:SetSize(50, 28); clear:SetText("Clear"); clear:SetScript(
        "OnClick", function()
            searchBox:SetText(""); self:FilterToyList()
        end)
    local refresh = CreateFrame("Button", nil, toyFrame, "UIPanelButtonTemplate")
    refresh:SetPoint("LEFT", clear, "RIGHT", 8, 0); refresh:SetSize(60, 28); refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        self:PopulateToyList(); self:UpdateToySelection()
    end)


    local currentLabel = toyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentLabel:SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -50); currentLabel:SetText("Current:")
    local currentToy = CreateFrame("Button", "BOLTCurrentToyButton", toyFrame); currentToy:SetPoint("LEFT", currentLabel,
        "RIGHT", 15, 0); currentToy:SetSize(220, 28)
    local currentIcon = currentToy:CreateTexture(nil, "ARTWORK")
    currentIcon:SetPoint("LEFT", currentToy, "LEFT", 4, 0); currentIcon:SetSize(20, 20)
    local currentText = currentToy:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    currentText:SetPoint("LEFT", currentIcon, "RIGHT", 8, 0)
    currentText:SetPoint("RIGHT", currentToy, "RIGHT", -8, 0)
    currentText:SetJustifyH("LEFT")
    currentText:SetText("None selected")
    currentToy:SetScript("OnClick",
        function()
            self.parent:SetConfig(nil, "playground", "favoriteToyId"); self:UpdateToySelection(); if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then
                self.parent.modules.playground:UpdateFavoriteToyButton()
            end
        end)
    local scrollFrame = CreateFrame("ScrollFrame", "BOLTToyScrollFrame", toyFrame, "UIPanelScrollFrameTemplate"); scrollFrame
        :SetPoint("TOPLEFT", toyFrame, "TOPLEFT", 15, -85); scrollFrame:SetPoint("BOTTOMRIGHT", toyFrame, "BOTTOMRIGHT",
        -35, 15)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame); scrollFrame:SetScrollChild(scrollChild); scrollChild
        :SetSize(370, 1)
    self.toyFrame = toyFrame; self.searchBox = searchBox; self.currentToyButton = currentToy; self.currentToyIcon =
        currentIcon; self.currentToyText = currentText; self.toyScrollFrame = scrollFrame; self.toyScrollChild =
        scrollChild; self.toyButtons = {}
    toyFrame:SetScript("OnShow", function()
        C_Timer.After(0.1, function()
            if not self.toyListPopulated then
                -- try to populate; may retry internally if data isn't ready
                self:PopulateToyList()
                self.toyListPopulated = true
            end
            self:UpdateToySelection()
        end)
    end)

    -- Ensure we refresh when the game's toy data updates
    if not self.toyEventFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("TOYS_UPDATED")
        f:RegisterEvent("PLAYER_LOGIN")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function(_, event)
            C_Timer.After(0.1, function()
                if self and self.PopulateToyList then
                    pcall(function()
                        self:PopulateToyList()
                        self.toyListPopulated = true
                        self:UpdateToySelection()
                    end)
                end
            end)
        end)
        self.toyEventFrame = f
    end

    self:UpdateToySelection()
end

function Config:PopulateToyList()
    if not self.toyScrollChild then return end
    -- Throttle repeated calls
    if self._lastToyScan and (GetTime() - self._lastToyScan) < 0.5 then return end
    self._lastToyScan = GetTime()

    for _, b in pairs(self.toyButtons) do b:Hide() end
    self.toyButtons = {}
    self.allToys = {}

    -- Try to ensure toy APIs are loaded
    if not C_ToyBox then
        pcall(LoadAddOn, "Blizzard_Collections")
        if not C_ToyBox then
            return
        end
    end

    -- Prefer unfiltered total count first; filtered count can be zero when UI filters hide items
    local getNum = (type(C_ToyBox.GetNumToys) == "function" and C_ToyBox.GetNumToys) or
        ((type(C_ToyBox.GetNumFilteredToys) == "function" and C_ToyBox.GetNumFilteredToys) or nil)
    if type(getNum) ~= "function" then
        return
    end

    -- Try to ensure filters include everything (if API supports these helpers)
    if C_ToyBox.SetAllSourceTypeFilters then
        pcall(C_ToyBox.SetAllSourceTypeFilters, true)
    end
    if C_ToyBox.SetAllExpansionTypeFilters then
        pcall(C_ToyBox.SetAllExpansionTypeFilters, true)
    end
    if C_ToyBox.SetUncollectedShown then pcall(C_ToyBox.SetUncollectedShown, false) end
    if C_ToyBox.SetUnusableShown then pcall(C_ToyBox.SetUnusableShown, true) end

    -- Re-query count after attempting to adjust filters
    local numToys = getNum() or 0



    -- If there are no toys yet, retry a few times (toy data may be loaded async)
    if numToys == 0 then
        self._toyPopulateRetries = (self._toyPopulateRetries or 0) + 1
        if self._toyPopulateRetries <= 3 then
            C_Timer.After(0.75, function()
                if self and self.PopulateToyList then pcall(function() self:PopulateToyList() end) end
            end)
            return
        else
            -- continue and allow empty list
        end
    end

    local added = 0
    local foundIDs = false

    -- Helper to process a toyID
    local function processToyID(toyID)
        if not toyID or toyID <= 0 then return false end
        local itemID, toyName, icon = C_ToyBox.GetToyInfo(toyID)
        if itemID and toyName and PlayerHasToy(itemID) then
            if not icon and C_Item and C_Item.GetItemIconByID then
                icon = C_Item.GetItemIconByID(itemID)
            end
            table.insert(self.allToys, {
                id = toyID,
                itemId = itemID,
                name = toyName,
                icon = icon,
                lcname = string.lower(toyName)
            })
            return true
        end
        return false
    end

    -- First attempt: try 0-based indices (some clients use 0..n-1)
    for i = 0, math.max(0, numToys - 1) do
        local ok, toyID = pcall(C_ToyBox.GetToyFromIndex, i)
        if ok and toyID and toyID > 0 then
            foundIDs = true
            if processToyID(toyID) then added = added + 1 end
        else
            -- ignore failures silently
        end
    end

    -- If none found with 0-based, try 1-based indexing (legacy)
    if not foundIDs then
        for i = 1, numToys do
            local ok, toyID = pcall(C_ToyBox.GetToyFromIndex, i)
            if ok and toyID and toyID > 0 then
                foundIDs = true
                if processToyID(toyID) then added = added + 1 end
            else
                -- ignore failure
            end
        end
    end

    if not foundIDs then
        if not self._toyFilterFixAttempted then
            pcall(function() if ToggleCollectionsJournal then ToggleCollectionsJournal() end end)
            -- Wait a moment for Collections UI to initialize, then attempt to clear filters and retry
            C_Timer.After(0.5, function()
                if not self then return end
                if C_ToyBox then
                    pcall(function()
                        if C_ToyBox.SetAllSourceTypeFilters then C_ToyBox.SetAllSourceTypeFilters(true) end
                        if C_ToyBox.SetAllExpansionTypeFilters then C_ToyBox.SetAllExpansionTypeFilters(true) end
                        if C_ToyBox.SetUncollectedShown then pcall(C_ToyBox.SetUncollectedShown, true) end
                        if C_ToyBox.SetUnusableShown then pcall(C_ToyBox.SetUnusableShown, true) end
                        -- Try a few possible search/clear APIs on C_ToyBox if present
                        local maybeClearFns = { "SetSearch", "SetFilterString", "ClearSearch", "SetSearchText" }
                        for _, fname in ipairs(maybeClearFns) do
                            if C_ToyBox[fname] and type(C_ToyBox[fname]) == "function" then
                                pcall(C_ToyBox[fname], "")
                            end
                        end
                    end)
                end
                -- mark that we attempted a fix so we don't loop infinitely
                self._toyFilterFixAttempted = true
                C_Timer.After(0.5, function()
                    if self and self.PopulateToyList then pcall(function() self:PopulateToyList() end) end
                end)
            end)
        else
            -- already attempted fix
        end
    end

    table.sort(self.allToys, function(a, b) return a.name < b.name end)

    self._toyPopulateRetries = 0
    
    -- Show warning if toy list is empty after all attempts
    if #self.allToys == 0 and self._toyFilterFixAttempted then
        if self.parent and self.parent.Print then
            self.parent:Print("|cFFFF8800Warning:|r No toys found in your collection. This may be due to filters applied in the WoW Toy Box. Please open your Toy Box (Shift+P) and clear any active filters.")
        end
    end

    self:FilterToyList()

    -- Schedule icon-cache retry for toys missing icons
    local needsIcon = false
    for _, t in ipairs(self.allToys) do
        if not t.icon and t.itemId then
            needsIcon = true
            break
        end
    end

    if needsIcon then
        C_Timer.After(0.5, function()
            if not self or not self.allToys then return end
            local changed = false
            for _, t in ipairs(self.allToys) do
                if not t.icon and t.itemId and C_Item and C_Item.GetItemIconByID then
                    local maybeIcon = C_Item.GetItemIconByID(t.itemId)
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
        button.icon:SetTexCoord(0, 1, 0, 1)
        button.text:SetText(toy.name)
        button:SetScript("OnClick", function()
            self.parent:SetConfig(toy.id, "playground", "favoriteToyId")
            self:UpdateToySelection()
            if self.parent.modules.playground and self.parent.modules.playground.UpdateFavoriteToyButton then
                self
                    .parent.modules.playground:UpdateFavoriteToyButton()
            end
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
