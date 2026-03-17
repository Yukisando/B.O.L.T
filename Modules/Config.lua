-- B.O.L.T Configuration UI
local ADDON_NAME, BOLT = ...

local Config = {}
Config.alwaysInitialize = true

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
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("TOYS_UPDATED")
    -- Also listen for login so we can attempt an initial population when the player logs in
    self.eventFrame:RegisterEvent("PLAYER_LOGIN")
    self.toyListPopulated = false
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_LOGIN" and not self.optionsPanel then
            self:CreateInterfaceOptionsPanel()
        end
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

function Config:EnsureInterfaceOptionsPanel()
    if not self.optionsPanel then
        self:CreateInterfaceOptionsPanel()
    end
end

function Config:CreateReloadIndicator(parent, anchor)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", anchor.Text, "RIGHT", 10, 0)
    label:SetText("|cFFFF6B6B(Requires /reload)|r")
    label:Hide()
    return label
end

-- Reusable: create a section frame with header + collapsible options container.
-- Returns { section, header, container, headerHeight }
-- The container auto-hides when the module is disabled.
function Config:CreateSection(parent, labelText, moduleName, hasOptions)
    local section = CreateFrame("Frame", nil, parent)
    section:SetPoint("LEFT", parent, "LEFT", 0, 0)
    section:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    section.moduleName = moduleName

    -- Section label
    local label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", section, "TOPLEFT", 20, 0)
    label:SetText(labelText)

    -- Enable checkbox
    local checkbox = CreateFrame("CheckButton", nil, section, "InterfaceOptionsCheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", section, "TOPLEFT", 30, -24)
    checkbox.Text:SetText("Enable " .. labelText .. " Module")

    local reloadIndicator = self:CreateReloadIndicator(section, checkbox)
    reloadIndicator:Hide()

    -- Options container (collapsible)
    local container = nil
    if hasOptions then
        container = CreateFrame("Frame", nil, section)
        container:SetPoint("TOPLEFT", section, "TOPLEFT", 0, -54)
        container:SetPoint("RIGHT", section, "RIGHT", 0, 0)
        container:SetHeight(1)
    end

    local data = {
        section = section,
        label = label,
        checkbox = checkbox,
        reloadIndicator = reloadIndicator,
        container = container,
        moduleName = moduleName,
        headerHeight = hasOptions and 54 or 54,
        optionsHeight = 0,
    }

    if not self.sections then self.sections = {} end
    table.insert(self.sections, data)

    return data
end

-- Relayout all sections vertically, collapsing options when module is disabled
function Config:RelayoutPanel()
    if not self.sections then return end
    local y = -60 -- below title
    for _, sec in ipairs(self.sections) do
        sec.section:ClearAllPoints()
        sec.section:SetPoint("TOPLEFT", self.optionsScrollChild, "TOPLEFT", 0, y)
        sec.section:SetPoint("RIGHT", self.optionsScrollChild, "RIGHT", 0, 0)

        local enabled = self.parent:IsModuleEnabled(sec.moduleName)
        local showOptions = enabled and sec.container and sec.optionsHeight > 0
        if sec.container then
            if showOptions then
                sec.container:Show()
            else
                sec.container:Hide()
            end
        end

        local sectionHeight = sec.headerHeight + (showOptions and sec.optionsHeight or 0)
        sec.section:SetHeight(sectionHeight)
        y = y - sectionHeight - 10
    end

    -- Footer: Reload button + version
    if self.widgets.reloadButton then
        self.widgets.reloadButton:ClearAllPoints()
        self.widgets.reloadButton:SetPoint("TOPLEFT", self.optionsScrollChild, "TOPLEFT", 30, y)
        y = y - 40
    end
    if self.widgets.versionText then
        self.widgets.versionText:ClearAllPoints()
        self.widgets.versionText:SetPoint("TOPLEFT", self.optionsScrollChild, "TOPLEFT", 30, y)
        y = y - 30
    end

    self.optionsScrollChild:SetHeight(math.abs(y) + 100)
end

function Config:CreateInterfaceOptionsPanel()
    local panel = CreateFrame("Frame", "BOLTOptionsPanel")
    panel.name = "B.O.L.T"
    panel:SetScript("OnShow", function()
        self:RefreshAll()
        if self.parent and self.parent.modules and self.parent.modules.gameMenu then
            self.parent.modules.gameMenu.settingsPanelOpen = true
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

    self.sections = {}

    ---------------------------------------------------------------------------
    -- GAME MENU
    ---------------------------------------------------------------------------
    local gm = self:CreateSection(content, "Game Menu", "gameMenu", true)
    local c = gm.container
    local cy = 0

    gm.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("gameMenu", button:GetChecked())
        self:RelayoutPanel()
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.gameMenuCheckbox = gm.checkbox
    self.widgets.gameMenuReloadIndicator = gm.reloadIndicator

    local leaveGroupEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    leaveGroupEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    leaveGroupEnable.Text:SetText("Show Leave Group Button")
    leaveGroupEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showLeaveGroup")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.leaveGroupCheckbox = leaveGroupEnable
    cy = cy - 30

    local reloadEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    reloadEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    reloadEnable.Text:SetText("Show Reload UI Button")
    reloadEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showReloadButton")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.reloadCheckbox = reloadEnable
    cy = cy - 30

    local groupToolsEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    groupToolsEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    groupToolsEnable.Text:SetText("Enable Group Tools (Ready/Countdown/Raid Marker)")
    groupToolsEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "groupToolsEnabled")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.groupToolsCheckbox = groupToolsEnable
    cy = cy - 30

    local battleTextEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    battleTextEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    battleTextEnable.Text:SetText("Show Battle Text Toggles")
    battleTextEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showBattleTextToggles")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.battleTextCheckbox = battleTextEnable
    cy = cy - 30

    local volumeEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    volumeEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    volumeEnable.Text:SetText("Show Volume Control Button")
    volumeEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "gameMenu", "showVolumeButton")
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.volumeButtonCheckbox = volumeEnable
    cy = cy - 36

    -- Raid marker selector
    local markerLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    markerLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    markerLabel:SetText("Raid Marker Icon:")
    cy = cy - 22

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
    for i = 1, 8 do
        local b = buttons[i]
        if not b then
            b = CreateFrame("Button", nil, c)
            b:SetSize(btnSize, btnSize)
            b.tex = b:CreateTexture(nil, "ARTWORK")
            b.tex:SetAllPoints(b)
            b.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
            b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            buttons[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", c, "TOPLEFT", 50 + ((i - 1) * (btnSize + 4)), cy)
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
        clearBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
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
    clearBtn:SetPoint("TOPLEFT", c, "TOPLEFT", 50 + (8 * (btnSize + 4)) + 8, cy + 1)
    cy = cy - 40

    gm.optionsHeight = math.abs(cy)
    c:SetHeight(gm.optionsHeight)

    ---------------------------------------------------------------------------
    -- PLAYGROUND
    ---------------------------------------------------------------------------
    local pg = self:CreateSection(content, "Playground", "playground", true)
    c = pg.container
    cy = 0

    pg.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("playground", button:GetChecked())
        self:RelayoutPanel()
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.playgroundCheckbox = pg.checkbox
    self.widgets.playgroundReloadIndicator = pg.reloadIndicator

    local favToyEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    favToyEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    favToyEnable.Text:SetText("Favorite Toy Button")
    favToyEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "playground", "showFavoriteToy")
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.favoriteToyCheckbox = favToyEnable

    local chooseToyBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    chooseToyBtn:SetSize(120, 24)
    chooseToyBtn:SetText("Choose Toy")
    chooseToyBtn:SetScript("OnClick", function() self:ShowToySelectionPopup() end)
    chooseToyBtn:SetPoint("LEFT", favToyEnable.Text, "RIGHT", 10, 0)
    self.widgets.chooseToyButton = chooseToyBtn

    local toyRow = CreateFrame("Frame", nil, c)
    toyRow:SetSize(360, 24)
    toyRow:SetPoint("LEFT", chooseToyBtn, "RIGHT", 12, 0)
    self.widgets.currentToyRow = toyRow

    local toyIcon = toyRow:CreateTexture(nil, "ARTWORK")
    toyIcon:SetPoint("LEFT", toyRow, "LEFT", 0, 0)
    toyIcon:SetSize(20, 20)
    self.widgets.currentToyIcon = toyIcon

    local toyText = toyRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    toyText:SetPoint("LEFT", toyIcon, "RIGHT", 8, 0)
    toyText:SetJustifyH("LEFT")
    toyText:SetText("None selected")
    self.widgets.currentToyText = toyText
    cy = cy - 30

    local speedometerEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    speedometerEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    speedometerEnable.Text:SetText("Speedometer")
    speedometerEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "playground", "showSpeedometer")
        self:UpdatePlaygroundChildControls()
    end)
    self.widgets.speedometerCheckbox = speedometerEnable

    local posLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    posLabel:SetPoint("LEFT", speedometerEnable.Text, "RIGHT", 10, 0)
    posLabel:SetText("Position:")

    local posNames = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right" }
    local posDropdown = CreateFrame("Button", "BOLTSpeedometerPositionDropdown", c, "UIPanelButtonTemplate")
    posDropdown:SetSize(130, 22)
    posDropdown:SetPoint("LEFT", posLabel, "RIGHT", 5, 0)
    self.widgets.speedometerPositionDropdown = posDropdown

    local function UpdatePosDropdownText()
        local cur = self.parent:GetConfig("playground", "statsPosition") or "TOPRIGHT"
        posDropdown:SetText(posNames[cur] or "Top Right")
    end
    UpdatePosDropdownText()

    posDropdown:SetScript("OnClick", function(btn)
        local positions = {
            { text = "Top Left",     value = "TOPLEFT" },
            { text = "Top Right",    value = "TOPRIGHT" },
            { text = "Bottom Left",  value = "BOTTOMLEFT" },
            { text = "Bottom Right", value = "BOTTOMRIGHT" },
        }
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            for _, pos in ipairs(positions) do
                local p = pos
                rootDescription:CreateRadio(p.text,
                    function() return self.parent:GetConfig("playground", "statsPosition") == p.value end,
                    function()
                        self.parent:SetConfig(p.value, "playground", "statsPosition")
                        UpdatePosDropdownText()
                        if self.parent.modules.playground and self.parent.modules.playground.UpdateStatsPosition then
                            self.parent.modules.playground:UpdateStatsPosition()
                        end
                    end
                )
            end
        end)
    end)
    cy = cy - 36

    pg.optionsHeight = math.abs(cy)
    c:SetHeight(pg.optionsHeight)

    ---------------------------------------------------------------------------
    -- SKYRIDING
    ---------------------------------------------------------------------------
    local sk = self:CreateSection(content, "Skyriding", "skyriding", true)
    c = sk.container
    cy = 0

    sk.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("skyriding", button:GetChecked())
        self:RelayoutPanel()
        self:UpdateSkyridingChildControls()
    end)
    self.widgets.skyridingCheckbox = sk.checkbox
    self.widgets.skyridingReloadIndicator = sk.reloadIndicator

    local pitchEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    pitchEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    pitchEnable.Text:SetText("Enable Pitch Control (W/S)")
    pitchEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "skyriding", "enablePitchControl")
        self:UpdateSkyridingChildControls()
    end)
    self.widgets.pitchControlCheckbox = pitchEnable
    cy = cy - 30

    local invertEnable = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    invertEnable:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    invertEnable.Text:SetText("Invert Pitch")
    invertEnable:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "skyriding", "invertPitch")
    end)
    self.widgets.invertPitchCheckbox = invertEnable
    cy = cy - 30

    sk.optionsHeight = math.abs(cy)
    c:SetHeight(sk.optionsHeight)

    ---------------------------------------------------------------------------
    -- WOWHEAD LINK (description only, no child options beyond desc)
    ---------------------------------------------------------------------------
    local wl = self:CreateSection(content, "Wowhead Link", "wowheadLink", true)
    c = wl.container
    cy = 0

    wl.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("wowheadLink", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.wowheadLinkCheckbox = wl.checkbox
    self.widgets.wowheadLinkReloadIndicator = wl.reloadIndicator

    local wlDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    wlDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    wlDesc:SetWidth(520)
    wlDesc:SetJustifyH("LEFT")
    wlDesc:SetText("Press Ctrl+C while hovering over an item to copy its Wowhead link. Default keybind is Ctrl+C.")
    cy = cy - 30

    wl.optionsHeight = math.abs(cy)
    c:SetHeight(wl.optionsHeight)

    ---------------------------------------------------------------------------
    -- AUTO REP SWITCH
    ---------------------------------------------------------------------------
    local ars = self:CreateSection(content, "Auto Rep Switch", "autoRepSwitch", true)
    c = ars.container
    cy = 0

    ars.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("autoRepSwitch", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.autoRepSwitchCheckbox = ars.checkbox
    self.widgets.autoRepSwitchReloadIndicator = ars.reloadIndicator

    local arsDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arsDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    arsDesc:SetWidth(520)
    arsDesc:SetJustifyH("LEFT")
    arsDesc:SetText("Automatically switch the watched reputation to the faction you just gained reputation with.")
    cy = cy - 30

    ars.optionsHeight = math.abs(cy)
    c:SetHeight(ars.optionsHeight)

    ---------------------------------------------------------------------------
    -- SMART TELEPORT SUGGESTIONS
    ---------------------------------------------------------------------------
    local st = self:CreateSection(content, "Smart Teleport Suggestions", "smartTeleport", true)
    c = st.container
    cy = 0

    st.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("smartTeleport", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.smartTeleportCheckbox = st.checkbox
    self.widgets.smartTeleportReloadIndicator = st.reloadIndicator

    local stDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    stDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    stDesc:SetWidth(520)
    stDesc:SetJustifyH("LEFT")
    stDesc:SetText("Shows context-relevant teleports you own when viewing the World Map. Toggle with a keybind while the map is open.")
    cy = cy - 30

    st.optionsHeight = math.abs(cy)
    c:SetHeight(st.optionsHeight)

    ---------------------------------------------------------------------------
    -- CHAT NOTIFIER
    ---------------------------------------------------------------------------
    local cn = self:CreateSection(content, "Chat Notifier", "chatNotifier", true)
    c = cn.container
    cy = 0

    cn.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("chatNotifier", button:GetChecked())
        self:RelayoutPanel()
        self:UpdateChatNotifierChildControls()
    end)
    self.widgets.chatNotifierCheckbox = cn.checkbox
    self.widgets.chatNotifierReloadIndicator = cn.reloadIndicator

    local cnDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cnDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    cnDesc:SetWidth(520)
    cnDesc:SetJustifyH("LEFT")
    cnDesc:SetText("Plays a notification sound when a new message appears in any checked channel below.")
    cy = cy - math.max(cnDesc:GetStringHeight() + 10, 24)

    local cnSoundLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cnSoundLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    cnSoundLabel:SetText("Sound:")

    local cnSoundDropdown = CreateFrame("Button", "BOLTChatNotifierSoundDropdown", c, "UIPanelButtonTemplate")
    cnSoundDropdown:SetSize(170, 22)
    cnSoundDropdown:SetPoint("LEFT", cnSoundLabel, "RIGHT", 5, 0)
    self.widgets.chatNotifierSoundDropdown = cnSoundDropdown

    local function UpdateSoundDropdownText()
        local chatMod = self.parent.modules.chatNotifier
        if not chatMod then cnSoundDropdown:SetText("(none)"); return end
        local curID = chatMod:GetSoundID()
        for _, snd in ipairs(chatMod.SOUND_OPTIONS) do
            if snd.soundID == curID then cnSoundDropdown:SetText(snd.label); return end
        end
        cnSoundDropdown:SetText("(none)")
    end
    UpdateSoundDropdownText()

    cnSoundDropdown:SetScript("OnClick", function(btn)
        local chatMod = self.parent.modules.chatNotifier
        if not chatMod then return end
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            for _, snd in ipairs(chatMod.SOUND_OPTIONS) do
                local s = snd
                rootDescription:CreateRadio(s.label,
                    function() return chatMod:GetSoundID() == s.soundID end,
                    function()
                        chatMod:SetSoundID(s.soundID)
                        UpdateSoundDropdownText()
                        PlaySound(s.soundID, "Master")
                    end
                )
            end
        end)
    end)

    local cnPreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    cnPreviewBtn:SetSize(70, 22)
    cnPreviewBtn:SetPoint("LEFT", cnSoundDropdown, "RIGHT", 6, 0)
    cnPreviewBtn:SetText("Preview")
    cnPreviewBtn:SetScript("OnClick", function()
        local chatMod = self.parent.modules.chatNotifier
        if chatMod then PlaySound(chatMod:GetSoundID(), "Master") end
    end)
    self.widgets.chatNotifierPreviewBtn = cnPreviewBtn
    cy = cy - 36

    local cnChannelsLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cnChannelsLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    cnChannelsLabel:SetText("Channels:")

    local chatMod = self.parent.modules.chatNotifier
    local channelTypes = chatMod and chatMod.CHANNEL_TYPES or {}

    self.widgets.chatNotifierSelectedChannels = {}
    if chatMod then
        for _, ch in ipairs(channelTypes) do
            if chatMod:IsChannelEnabled(ch.event) then
                self.widgets.chatNotifierSelectedChannels[ch.event] = true
            end
        end
    end

    local function UpdateChatNotifierDropdownText()
        local selected = {}
        for _, ch in ipairs(channelTypes) do
            if self.widgets.chatNotifierSelectedChannels[ch.event] then
                table.insert(selected, ch.label)
            end
        end
        local text = #selected > 0 and table.concat(selected, ", ") or "None"
        if self.widgets.chatNotifierChannelsDropdown then
            self.widgets.chatNotifierChannelsDropdown:SetText(text)
        end
    end
    self.widgets.UpdateChatNotifierDropdownText = UpdateChatNotifierDropdownText

    local cnChannelsDropdown = CreateFrame("Button", "BOLTChatNotifierChannelsDropdown", c, "UIPanelButtonTemplate")
    cnChannelsDropdown:SetSize(300, 22)
    cnChannelsDropdown:SetPoint("LEFT", cnChannelsLabel, "RIGHT", 5, -2)
    cnChannelsDropdown:SetScript("OnClick", function(btn)
        local mod = self.parent.modules.chatNotifier
        if not mod then return end
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            for _, ch in ipairs(channelTypes) do
                local evt = ch.event
                local lbl = ch.label
                rootDescription:CreateCheckbox(lbl,
                    function() return self.widgets.chatNotifierSelectedChannels[evt] or false end,
                    function()
                        local newVal = not (self.widgets.chatNotifierSelectedChannels[evt] or false)
                        self.widgets.chatNotifierSelectedChannels[evt] = newVal
                        mod:SetChannelEnabled(evt, newVal)
                        UpdateChatNotifierDropdownText()
                    end
                )
            end
        end)
    end)
    self.widgets.chatNotifierChannelsDropdown = cnChannelsDropdown
    UpdateChatNotifierDropdownText()
    cy = cy - 36

    cn.optionsHeight = math.abs(cy)
    c:SetHeight(cn.optionsHeight)

    ---------------------------------------------------------------------------
    -- ACHIEVEMENT TRACKER
    ---------------------------------------------------------------------------
    local at = self:CreateSection(content, "Achievement Progress Tracker", "achievementTracker", true)
    c = at.container
    cy = 0

    at.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("achievementTracker", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.achievementTrackerCheckbox = at.checkbox
    self.widgets.achievementTrackerReloadIndicator = at.reloadIndicator

    local atDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    atDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    atDesc:SetWidth(520)
    atDesc:SetJustifyH("LEFT")
    atDesc:SetText("Prints a chat message whenever an action you perform advances progress on any achievement (e.g. /love a critter, completing a quest, defeating a boss).")
    cy = cy - math.max(atDesc:GetStringHeight() + 10, 36)

    local atCatLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    atCatLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    atCatLabel:SetText("Track Categories:")

    local function UpdateAchCategoryDropdownText()
        local atMod = self.parent.modules.achievementTracker
        if not atMod then return end
        local topCats = atMod:GetTopLevelCategories()
        local selected = {}
        local allTracked = true
        for _, cat in ipairs(topCats) do
            if atMod:IsCategoryTracked(cat.id) then
                selected[#selected + 1] = cat.name
            else
                allTracked = false
            end
        end
        local text
        if allTracked or #selected == 0 then
            text = "All Categories"
        elseif #selected <= 3 then
            text = table.concat(selected, ", ")
        else
            text = selected[1] .. ", " .. selected[2] .. " + " .. (#selected - 2) .. " more"
        end
        if self.widgets.achievementCategoryDropdown then
            self.widgets.achievementCategoryDropdown:SetText(text)
        end
    end
    self.widgets.UpdateAchCategoryDropdownText = UpdateAchCategoryDropdownText

    local atCatDropdown = CreateFrame("Button", "BOLTAchievementCategoryDropdown", c, "UIPanelButtonTemplate")
    atCatDropdown:SetSize(300, 22)
    atCatDropdown:SetPoint("LEFT", atCatLabel, "RIGHT", 5, -2)
    atCatDropdown:SetScript("OnClick", function(btn)
        local atMod = self.parent.modules.achievementTracker
        if not atMod then return end
        local topCats = atMod:GetTopLevelCategories()
        MenuUtil.CreateContextMenu(btn, function(_, rootDescription)
            rootDescription:CreateButton("|cff00aaff-- None --|r", function()
                self.parent:SetConfig({ ["__none"] = true }, "achievementTracker", "trackedCategories")
                UpdateAchCategoryDropdownText()
            end)
            rootDescription:CreateDivider()
            for _, cat in ipairs(topCats) do
                local catRef = cat
                rootDescription:CreateCheckbox(catRef.name,
                    function() return atMod:IsCategoryTracked(catRef.id) end,
                    function()
                        atMod:SetCategoryTracked(catRef.id, not atMod:IsCategoryTracked(catRef.id))
                        UpdateAchCategoryDropdownText()
                    end
                )
            end
        end)
    end)
    self.widgets.achievementCategoryDropdown = atCatDropdown
    C_Timer.After(0.1, UpdateAchCategoryDropdownText)

    local atRescanBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    atRescanBtn:SetSize(80, 22)
    atRescanBtn:SetPoint("LEFT", atCatDropdown, "RIGHT", 6, 0)
    atRescanBtn:SetText("Rescan")
    atRescanBtn:SetScript("OnClick", function()
        local atMod = self.parent.modules.achievementTracker
        if atMod and self.parent:IsModuleEnabled("achievementTracker") then
            atMod:BuildSnapshot()
        end
    end)
    self.widgets.achievementRescanButton = atRescanBtn
    cy = cy - 36

    at.optionsHeight = math.abs(cy)
    c:SetHeight(at.optionsHeight)

    ---------------------------------------------------------------------------
    -- SAVED INSTANCES
    ---------------------------------------------------------------------------
    local si = self:CreateSection(content, "Saved Instances", "savedInstances", true)
    c = si.container
    cy = 0

    si.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("savedInstances", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.savedInstancesCheckbox = si.checkbox
    self.widgets.savedInstancesReloadIndicator = si.reloadIndicator

    local siDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    siDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    siDesc:SetWidth(520)
    siDesc:SetJustifyH("LEFT")
    siDesc:SetText("Lists current expansion dungeons and raids you haven't completed yet. Type /boltsaved to print the list.")
    cy = cy - 30

    si.optionsHeight = math.abs(cy)
    c:SetHeight(si.optionsHeight)

    ---------------------------------------------------------------------------
    -- SOUND MUTER
    ---------------------------------------------------------------------------
    local sm = self:CreateSection(content, "Sound Muter", "soundMuter", true)
    c = sm.container
    cy = 0

    sm.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("soundMuter", button:GetChecked())
        self:RefreshSoundMuterList()
        self:RelayoutPanel()
    end)
    self.widgets.soundMuterCheckbox = sm.checkbox
    self.widgets.soundMuterReloadIndicator = sm.reloadIndicator

    local smDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    smDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    smDesc:SetWidth(520)
    smDesc:SetJustifyH("LEFT")
    smDesc:SetText("Mute specific sound IDs so they never play in-game. Useful for silencing ambient music or annoying repeated sounds.")
    cy = cy - 30

    -- Input row: editbox + add button + preview
    local smInputLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    smInputLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    smInputLabel:SetText("Sound ID:")

    local smInput = CreateFrame("EditBox", "BOLTSoundMuterInput", c, "InputBoxTemplate")
    smInput:SetSize(100, 20)
    smInput:SetPoint("LEFT", smInputLabel, "RIGHT", 8, 0)
    smInput:SetAutoFocus(false)
    smInput:SetNumeric(true)
    smInput:SetMaxLetters(10)
    self.widgets.soundMuterInput = smInput

    local smAddBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    smAddBtn:SetSize(50, 22)
    smAddBtn:SetPoint("LEFT", smInput, "RIGHT", 6, 0)
    smAddBtn:SetText("Add")
    smAddBtn:SetScript("OnClick", function()
        local text = smInput:GetText()
        local soundID = tonumber(text)
        if not soundID or soundID <= 0 then return end
        local mod = self.parent.modules.soundMuter
        if mod and mod.AddSoundID then
            if mod:AddSoundID(soundID) then
                smInput:SetText("")
                self:RefreshSoundMuterList()
            end
        end
    end)
    self.widgets.soundMuterAddBtn = smAddBtn

    local smPreviewBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    smPreviewBtn:SetSize(70, 22)
    smPreviewBtn:SetPoint("LEFT", smAddBtn, "RIGHT", 4, 0)
    smPreviewBtn:SetText("Preview")
    smPreviewBtn:SetScript("OnClick", function()
        local text = smInput:GetText()
        local soundID = tonumber(text)
        if soundID and soundID > 0 then
            PlaySoundFile(soundID, "Master")
        end
    end)
    self.widgets.soundMuterPreviewBtn = smPreviewBtn

    local smRecentBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    smRecentBtn:SetSize(110, 22)
    smRecentBtn:SetPoint("LEFT", smPreviewBtn, "RIGHT", 4, 0)
    smRecentBtn:SetText("Recent Sounds")
    smRecentBtn:SetScript("OnClick", function()
        self:ShowRecentSoundsPopup()
    end)
    self.widgets.soundMuterRecentBtn = smRecentBtn
    cy = cy - 30

    -- Scrollable list of muted sound IDs
    local smListFrame = CreateFrame("Frame", nil, c, "BackdropTemplate")
    smListFrame:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    smListFrame:SetSize(400, 120)
    smListFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    smListFrame:SetBackdropColor(0, 0, 0, 0.6)
    smListFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    self.widgets.soundMuterListFrame = smListFrame

    local smScrollFrame = CreateFrame("ScrollFrame", "BOLTSoundMuterScrollFrame", smListFrame, "UIPanelScrollFrameTemplate")
    smScrollFrame:SetPoint("TOPLEFT", smListFrame, "TOPLEFT", 4, -4)
    smScrollFrame:SetPoint("BOTTOMRIGHT", smListFrame, "BOTTOMRIGHT", -24, 4)
    local smScrollChild = CreateFrame("Frame", "BOLTSoundMuterScrollChild", smScrollFrame)
    smScrollChild:SetWidth(360)
    smScrollChild:SetHeight(1)
    smScrollFrame:SetScrollChild(smScrollChild)
    self.widgets.soundMuterScrollChild = smScrollChild
    self.widgets.soundMuterRows = {}
    cy = cy - 130

    C_Timer.After(0.1, function() self:RefreshSoundMuterList() end)

    sm.optionsHeight = math.abs(cy)
    c:SetHeight(sm.optionsHeight)

    ---------------------------------------------------------------------------
    -- NAMEPLATES ENHANCEMENT
    ---------------------------------------------------------------------------
    local ne = self:CreateSection(content, "Nameplates Enhancement", "nameplatesEnhancement", true)
    c = ne.container
    cy = 0

    ne.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("nameplatesEnhancement", button:GetChecked())
        self:RelayoutPanel()
        self:UpdateNameplatesChildControls()
    end)
    self.widgets.nameplatesEnhancementCheckbox = ne.checkbox
    self.widgets.nameplatesEnhancementReloadIndicator = ne.reloadIndicator

    local neDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    neDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    neDesc:SetWidth(520)
    neDesc:SetJustifyH("LEFT")
    neDesc:SetText("Colors enemy nameplate health bars for mana users (healers/casters). Persists through combat and threat changes.")
    cy = cy - 30

    local neColorLabel = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    neColorLabel:SetPoint("TOPLEFT", c, "TOPLEFT", 50, cy)
    neColorLabel:SetText("Mana Color:")

    local neColorSwatch = CreateFrame("Button", nil, c, "BackdropTemplate")
    neColorSwatch:SetSize(20, 20)
    neColorSwatch:SetPoint("LEFT", neColorLabel, "RIGHT", 8, 0)
    neColorSwatch:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    neColorSwatch:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    self.widgets.neColorSwatch = neColorSwatch

    local function UpdateSwatchColor()
        local mc = self.parent:GetConfig("nameplatesEnhancement", "manaColor") or { r = 0.2, g = 0.4, b = 1.0 }
        neColorSwatch:SetBackdropColor(mc.r, mc.g, mc.b, 1)
    end
    UpdateSwatchColor()

    neColorSwatch:SetScript("OnClick", function()
        local mc = self.parent:GetConfig("nameplatesEnhancement", "manaColor") or { r = 0.2, g = 0.4, b = 1.0 }
        local function OnColorChanged()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            self.parent:SetConfig({ r = r, g = g, b = b }, "nameplatesEnhancement", "manaColor")
            UpdateSwatchColor()
            local mod = self.parent.modules.nameplatesEnhancement
            if mod and mod.LoadManaColor then mod:LoadManaColor() end
        end
        local function OnCancel(prev)
            self.parent:SetConfig({ r = prev.r, g = prev.g, b = prev.b }, "nameplatesEnhancement", "manaColor")
            UpdateSwatchColor()
            local mod = self.parent.modules.nameplatesEnhancement
            if mod and mod.LoadManaColor then mod:LoadManaColor() end
        end
        local info = {
            r = mc.r, g = mc.g, b = mc.b,
            swatchFunc = OnColorChanged,
            cancelFunc = OnCancel,
            previousValues = { r = mc.r, g = mc.g, b = mc.b },
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local neResetBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    neResetBtn:SetSize(55, 20)
    neResetBtn:SetPoint("LEFT", neColorSwatch, "RIGHT", 6, 0)
    neResetBtn:SetText("Reset")
    neResetBtn:SetScript("OnClick", function()
        self.parent:SetConfig({ r = 0.2, g = 0.4, b = 1.0 }, "nameplatesEnhancement", "manaColor")
        UpdateSwatchColor()
        local mod = self.parent.modules.nameplatesEnhancement
        if mod and mod.LoadManaColor then mod:LoadManaColor() end
    end)
    self.widgets.neResetBtn = neResetBtn
    self.widgets.UpdateNameplatesSwatchColor = UpdateSwatchColor
    cy = cy - 28

    local neInstanceOnly = CreateFrame("CheckButton", nil, c, "InterfaceOptionsCheckButtonTemplate")
    neInstanceOnly:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    neInstanceOnly.Text:SetText("Only in instances (dungeons, raids, scenarios)")
    neInstanceOnly.Text:SetFontObject("GameFontHighlightSmall")
    neInstanceOnly:SetChecked(self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false)
    neInstanceOnly:SetScript("OnClick", function(button)
        self.parent:SetConfig(button:GetChecked(), "nameplatesEnhancement", "instanceOnly")
        local mod = self.parent.modules.nameplatesEnhancement
        if mod then mod:RefreshInstanceOnly() end
    end)
    self.widgets.neInstanceOnly = neInstanceOnly
    cy = cy - 26

    ne.optionsHeight = math.abs(cy)
    c:SetHeight(ne.optionsHeight)

    ---------------------------------------------------------------------------
    -- PARTY FRAMES CENTER GROWTH
    ---------------------------------------------------------------------------
    local pfcg = self:CreateSection(content, "Party Frames Center Growth", "partyFramesCenterGrowth", true)
    c = pfcg.container
    cy = 0

    pfcg.checkbox:SetScript("OnClick", function(button)
        self.parent:SetModuleEnabled("partyFramesCenterGrowth", button:GetChecked())
        self:RelayoutPanel()
    end)
    self.widgets.partyFramesCenterGrowthCheckbox = pfcg.checkbox

    local pfcgDesc = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pfcgDesc:SetPoint("TOPLEFT", c, "TOPLEFT", 30, cy)
    pfcgDesc:SetWidth(560)
    pfcgDesc:SetJustifyH("LEFT")
    pfcgDesc:SetText("Keeps raid-style party frames center-aligned by nudging the party group anchor as members join or leave. Only affects party frames when Raid-Style Party Frames is enabled in Edit Mode.")
    cy = cy - 40

    pfcg.optionsHeight = math.abs(cy)
    c:SetHeight(pfcg.optionsHeight)

    ---------------------------------------------------------------------------
    -- FOOTER
    ---------------------------------------------------------------------------
    local reloadBtn = CreateFrame("Button", "BOLTOptionsReloadButton", content, "UIPanelButtonTemplate")
    reloadBtn:SetSize(120, 25)
    reloadBtn:SetText("Reload UI")
    reloadBtn:SetScript("OnClick", ReloadUI)
    self.widgets.reloadButton = reloadBtn

    local versionText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionText:SetText("B.O.L.T v" .. (self.parent and self.parent.version or "?"))
    self.widgets.versionText = versionText

    scrollFrame:SetScript("OnSizeChanged", function(frame, w, h) content:SetWidth(w - 20) end)

    -- Initial layout
    self:RelayoutPanel()

    -- Register Settings category (modern API for 10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "B.O.L.T")
        self.settingsCategory = category
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
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
    self:RelayoutPanel()
    local enabled = self.parent:IsModuleEnabled("gameMenu")
    local w = self.widgets

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

    local groupToolsEnabled = false
    if enabled and self.parent and self.parent.GetConfig then
        groupToolsEnabled = self.parent:GetConfig("gameMenu", "groupToolsEnabled")
    end
    if w and w.raidMarkerButtons then
        for _, b in ipairs(w.raidMarkerButtons) do
            if b then b:SetEnabled(groupToolsEnabled); b:SetAlpha(groupToolsEnabled and 1 or 0.5) end
        end
        if w.raidMarkerClearButton then
            w.raidMarkerClearButton:SetEnabled(groupToolsEnabled); w.raidMarkerClearButton:SetAlpha(groupToolsEnabled and 1 or 0.5)
        end
    end

    if self.parent and self.parent.modules and self.parent.modules.gameMenu and self.parent.modules.gameMenu.UpdateGameMenu then
        self.parent.modules.gameMenu:UpdateGameMenu()
    end
end

function Config:UpdatePlaygroundChildControls()
    self:RelayoutPanel()
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
            w.speedometerPositionDropdown:Enable()
        else
            w.speedometerPositionDropdown:Disable()
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
    self:UpdateChatNotifierChildControls()
    self:UpdateNameplatesChildControls()
    self:UpdateCurrentToyDisplay()
    self:RefreshSoundMuterList()
    self:RelayoutPanel()
end

function Config:RefreshOptionsPanel()
    C_Timer.After(0.05, function()
        local w = self.widgets
        if w.gameMenuCheckbox then w.gameMenuCheckbox:SetChecked(self.parent:IsModuleEnabled("gameMenu")) end
        if w.leaveGroupCheckbox then w.leaveGroupCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showLeaveGroup")) end
        if w.reloadCheckbox then w.reloadCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showReloadButton")) end
        if w.groupToolsCheckbox then w.groupToolsCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "groupToolsEnabled")) end
        if w.battleTextCheckbox then w.battleTextCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showBattleTextToggles")) end
        if w.volumeButtonCheckbox then w.volumeButtonCheckbox:SetChecked(self.parent:GetConfig("gameMenu", "showVolumeButton")) end
        if w.raidMarkerButtons then
            local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
            for i, b in ipairs(w.raidMarkerButtons) do b:SetAlpha((i == idx) and 1 or 0.6) end
            if w.raidMarkerClearButton then w.raidMarkerClearButton:SetAlpha(idx == 0 and 1 or 0.6) end
        end
        if w.playgroundCheckbox then w.playgroundCheckbox:SetChecked(self.parent:IsModuleEnabled("playground")) end
        if w.favoriteToyCheckbox then w.favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground", "showFavoriteToy")) end
        if w.speedometerCheckbox then w.speedometerCheckbox:SetChecked(self.parent:GetConfig("playground", "showSpeedometer")) end
        if w.speedometerPositionDropdown then
            local currentPos = self.parent:GetConfig("playground", "statsPosition") or "TOPRIGHT"
            local posNames = { TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right" }
            w.speedometerPositionDropdown:SetText(posNames[currentPos] or "Top Right")
        end
        if w.skyridingCheckbox then w.skyridingCheckbox:SetChecked(self.parent:IsModuleEnabled("skyriding")) end
        if w.pitchControlCheckbox then w.pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding", "enablePitchControl")) end
        if w.wowheadLinkCheckbox then w.wowheadLinkCheckbox:SetChecked(self.parent:IsModuleEnabled("wowheadLink")) end
        if w.autoRepSwitchCheckbox then w.autoRepSwitchCheckbox:SetChecked(self.parent:IsModuleEnabled("autoRepSwitch")) end
        if w.smartTeleportCheckbox then w.smartTeleportCheckbox:SetChecked(self.parent:IsModuleEnabled("smartTeleport")) end
        if w.chatNotifierCheckbox then w.chatNotifierCheckbox:SetChecked(self.parent:IsModuleEnabled("chatNotifier")) end
        if w.achievementTrackerCheckbox then w.achievementTrackerCheckbox:SetChecked(self.parent:IsModuleEnabled("achievementTracker")) end
        if w.UpdateAchCategoryDropdownText then w.UpdateAchCategoryDropdownText() end
        if w.savedInstancesCheckbox then w.savedInstancesCheckbox:SetChecked(self.parent:IsModuleEnabled("savedInstances")) end
        if w.soundMuterCheckbox then w.soundMuterCheckbox:SetChecked(self.parent:IsModuleEnabled("soundMuter")) end
        if w.nameplatesEnhancementCheckbox then w.nameplatesEnhancementCheckbox:SetChecked(self.parent:IsModuleEnabled("nameplatesEnhancement")) end
        if w.partyFramesCenterGrowthCheckbox then w.partyFramesCenterGrowthCheckbox:SetChecked(self.parent:IsModuleEnabled("partyFramesCenterGrowth")) end
        if w.neInstanceOnly then w.neInstanceOnly:SetChecked(self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false) end
        if w.UpdateNameplatesSwatchColor then w.UpdateNameplatesSwatchColor() end
        -- Chat Notifier channels dropdown
        if w.chatNotifierChannelsDropdown and w.chatNotifierSelectedChannels then
            local chatMod = self.parent.modules.chatNotifier
            if chatMod then
                local chTypes = chatMod.CHANNEL_TYPES or {}
                for _, ch in ipairs(chTypes) do
                    w.chatNotifierSelectedChannels[ch.event] = chatMod:IsChannelEnabled(ch.event)
                end
                if w.UpdateChatNotifierDropdownText then w.UpdateChatNotifierDropdownText() end
            end
        end
        -- Chat Notifier sound dropdown
        if w.chatNotifierSoundDropdown then
            local chatMod = self.parent.modules.chatNotifier
            if chatMod then
                local currentSoundID = chatMod:GetSoundID()
                for _, snd in ipairs(chatMod.SOUND_OPTIONS) do
                    if snd.soundID == currentSoundID then
                        w.chatNotifierSoundDropdown:SetText(snd.label)
                        break
                    end
                end
            end
        end
        self:RelayoutPanel()
    end)
end

function Config:UpdateSkyridingChildControls()
    self:RelayoutPanel()
    local sk = self.parent:IsModuleEnabled("skyriding")
    local pitch = self.parent:GetConfig("skyriding", "enablePitchControl")
    local w = self.widgets
    if w.pitchControlCheckbox then
        w.pitchControlCheckbox:SetEnabled(sk); w.pitchControlCheckbox:SetAlpha(sk and 1 or 0.5)
    end
    if w.invertPitchCheckbox then
        local should = sk and pitch; w.invertPitchCheckbox:SetEnabled(should); w.invertPitchCheckbox:SetAlpha(should and 1 or 0.5)
    end
end

function Config:UpdateChatNotifierChildControls()
    self:RelayoutPanel()
    local enabled = self.parent:IsModuleEnabled("chatNotifier")
    local w = self.widgets

    if w.chatNotifierSoundDropdown then
        if enabled then w.chatNotifierSoundDropdown:Enable()
        else w.chatNotifierSoundDropdown:Disable() end
    end
    if w.chatNotifierPreviewBtn then
        w.chatNotifierPreviewBtn:SetEnabled(enabled)
        w.chatNotifierPreviewBtn:SetAlpha(enabled and 1 or 0.5)
    end
    if w.chatNotifierChannelsDropdown then
        if enabled then w.chatNotifierChannelsDropdown:Enable()
        else w.chatNotifierChannelsDropdown:Disable() end
    end
end

function Config:UpdateNameplatesChildControls()
    self:RelayoutPanel()
    local enabled = self.parent:IsModuleEnabled("nameplatesEnhancement")
    local w = self.widgets

    if w.neColorSwatch then
        w.neColorSwatch:SetEnabled(enabled)
        w.neColorSwatch:SetAlpha(enabled and 1 or 0.5)
    end
    if w.neResetBtn then
        w.neResetBtn:SetEnabled(enabled)
        w.neResetBtn:SetAlpha(enabled and 1 or 0.5)
    end
    if w.neInstanceOnly then
        w.neInstanceOnly:SetEnabled(enabled)
        w.neInstanceOnly:SetAlpha(enabled and 1 or 0.5)
    end
    if w.UpdateNameplatesSwatchColor then w.UpdateNameplatesSwatchColor() end
end

function Config:RefreshSoundMuterList()
    local w = self.widgets
    local scrollChild = w.soundMuterScrollChild
    if not scrollChild then return end

    -- Clear existing rows
    for _, row in ipairs(w.soundMuterRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    w.soundMuterRows = {}

    local mod = self.parent.modules.soundMuter
    if not mod then return end
    local list = mod:GetMutedSoundIDs()
    local enabled = self.parent:IsModuleEnabled("soundMuter")
    local rowY = 0

    for i, soundID in ipairs(list) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(350, 20)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -rowY)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", row, "LEFT", 4, 0)
        label:SetText(tostring(soundID))

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(55, 18)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        removeBtn:SetText("Remove")
        removeBtn:SetEnabled(enabled)
        local capturedID = soundID
        removeBtn:SetScript("OnClick", function()
            mod:RemoveSoundID(capturedID)
            self:RefreshSoundMuterList()
        end)

        w.soundMuterRows[i] = row
        rowY = rowY + 22
    end

    scrollChild:SetHeight(math.max(rowY, 1))
end

-- Recent Sounds popup for Sound Muter
function Config:ShowRecentSoundsPopup()
    if not self.recentSoundsPopup then
        self:CreateRecentSoundsPopup()
    end
    self:PopulateRecentSoundsList()
    self.recentSoundsPopup:Show()
end

function Config:CreateRecentSoundsPopup()
    local popup = CreateFrame("Frame", "BOLTRecentSoundsPopup", UIParent, "DialogBoxFrame")
    popup:SetSize(520, 380)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Recent Sounds")

    local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    local desc = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -45)
    desc:SetWidth(480)
    desc:SetJustifyH("LEFT")
    desc:SetText("Sounds recently detected via PlaySound / PlaySoundFile hooks. Click |cff00ff00Mute|r to add a sound to your muted list.")

    local refreshBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    refreshBtn:SetSize(70, 22)
    refreshBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -40, -42)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function() self:PopulateRecentSoundsList() end)

    local listFrame = CreateFrame("Frame", nil, popup, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 15, -72)
    listFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -15, 40)
    listFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    listFrame:SetBackdropColor(0, 0, 0, 0.8)
    listFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    local scrollFrame = CreateFrame("ScrollFrame", "BOLTRecentSoundsScrollFrame", listFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -24, 4)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(440)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    self.recentSoundsPopup = popup
    self.recentSoundsScrollChild = scrollChild
    self.recentSoundsRows = {}
    popup:Hide()
end

function Config:PopulateRecentSoundsList()
    local scrollChild = self.recentSoundsScrollChild
    if not scrollChild then return end

    for _, row in ipairs(self.recentSoundsRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    self.recentSoundsRows = {}

    local mod = self.parent.modules.soundMuter
    if not mod then return end
    local sounds = mod:GetRecentSounds()

    if #sounds == 0 then
        local empty = CreateFrame("Frame", nil, scrollChild)
        empty:SetSize(440, 30)
        empty:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
        local label = empty:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        label:SetPoint("CENTER", empty, "CENTER")
        label:SetText("No sounds detected yet. Play some sounds and check back.")
        self.recentSoundsRows[1] = empty
        scrollChild:SetHeight(30)
        return
    end

    local mutedList = mod:GetMutedSoundIDs()
    local mutedSet = {}
    for _, id in ipairs(mutedList) do mutedSet[id] = true end

    local rowY = 0
    for i, entry in ipairs(sounds) do
        local row = CreateFrame("Frame", nil, scrollChild)
        row:SetSize(440, 24)
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -rowY)

        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(row)
            bg:SetColorTexture(1, 1, 1, 0.03)
        end

        local typeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        typeLabel:SetPoint("LEFT", row, "LEFT", 4, 0)
        local typeColor = entry.sourceType == "FileID" and "|cff00ff00" or "|cffffff00"
        typeLabel:SetText(typeColor .. entry.sourceType .. "|r")

        local idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        idLabel:SetPoint("LEFT", typeLabel, "RIGHT", 8, 0)
        idLabel:SetPoint("RIGHT", row, "RIGHT", -130, 0)
        idLabel:SetJustifyH("LEFT")
        local displayText = tostring(entry.id)
        if entry.name then
            displayText = displayText .. "  (" .. entry.name .. ")"
        end
        idLabel:SetText(displayText)

        local previewBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        previewBtn:SetSize(50, 20)
        previewBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        previewBtn:SetText("Play")
        local capturedEntry = entry
        previewBtn:SetScript("OnClick", function()
            if capturedEntry.sourceType == "SoundKit" then
                PlaySound(capturedEntry.id)
            else
                PlaySoundFile(capturedEntry.id, "Master")
            end
        end)

        local muteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        muteBtn:SetSize(55, 20)
        muteBtn:SetPoint("RIGHT", previewBtn, "LEFT", -4, 0)
        local isMuted = type(entry.id) == "number" and mutedSet[entry.id]
        if isMuted then
            muteBtn:SetText("|cff888888Muted|r")
            muteBtn:SetEnabled(false)
        else
            muteBtn:SetText("Mute")
            local capturedID = entry.id
            muteBtn:SetScript("OnClick", function()
                if type(capturedID) == "number" and capturedID > 0 then
                    mod:AddSoundID(capturedID)
                    self:RefreshSoundMuterList()
                    self:PopulateRecentSoundsList()
                end
            end)
        end

        self.recentSoundsRows[i] = row
        rowY = rowY + 26
    end

    scrollChild:SetHeight(math.max(rowY, 1))
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
