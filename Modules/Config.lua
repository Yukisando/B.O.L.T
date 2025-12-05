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
    gmEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("gameMenu", checked)
        self:UpdateGameMenuChildControls()
    end)
    self.widgets.gameMenuCheckbox = gmEnable
    self.widgets.gameMenuReloadIndicator = self:CreateReloadIndicator(content, gmEnable)
    y = y - 36

    local chillLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chillLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    chillLabel:SetText("Chill Music")
    y = y - 24

    local chillEnable = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    chillEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    chillEnable.Text:SetText("Enable Chill Music Module")
    chillEnable:SetScript("OnClick", function(button)
        local checked = button:GetChecked()
        self.parent:SetModuleEnabled("chillMusic", checked)
        self:UpdateChillMusicChildControls()
    end)
    self.widgets.chillMusicCheckbox = chillEnable
    self.widgets.chillMusicReloadIndicator = self:CreateReloadIndicator(content, chillEnable)
    y = y - 30

    local chillDesc = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    chillDesc:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    chillDesc:SetWidth(520)
    chillDesc:SetJustifyH("LEFT")
    chillDesc:SetText("Replaces zone music with a curated chill playlist, automatically switching between indoor tavern tracks and outdoor ambience when you move around Azeroth.")
    self.widgets.chillMusicDescription = chillDesc
    y = y - 30

    y = self:CreateChillMusicSelectors(content, y)

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

function Config:CreateChillMusicSelectors(content, y)
    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        return y
    end

    local w = self.widgets
    w.chillMusicCategoryLabels = w.chillMusicCategoryLabels or {}
    w.chillMusicTrackContainers = w.chillMusicTrackContainers or {}
    w.chillMusicTrackCheckboxes = w.chillMusicTrackCheckboxes or {}
    w.chillMusicCustomFrames = w.chillMusicCustomFrames or {}
    w.chillMusicCustomInputs = w.chillMusicCustomInputs or {}

    local categories = {
        { key = "indoors", title = "Indoor Tracks" },
        { key = "outdoors", title = "Outdoor Tracks" },
    }

    for _, info in ipairs(categories) do
        local label = w.chillMusicCategoryLabels[info.key]
        if not label then
            label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            w.chillMusicCategoryLabels[info.key] = label
        end
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
        label:SetText(info.title)
        y = y - 24

        local container = w.chillMusicTrackContainers[info.key]
        if not container then
            container = CreateFrame("Frame", nil, content)
            container:SetWidth(520)
            w.chillMusicTrackContainers[info.key] = container
        end
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)

        local listHeight = self:RebuildChillMusicTrackList(info.key)
        y = y - listHeight - 12

        local customFrame, customHeight = self:CreateChillMusicCustomControls(content, info.key, y)
        y = y - customHeight - 24
    end

    local nowPlaying = w.chillMusicNowPlayingLabel
    if not nowPlaying then
        nowPlaying = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        w.chillMusicNowPlayingLabel = nowPlaying
    end
    nowPlaying:ClearAllPoints()
    nowPlaying:SetPoint("TOPLEFT", content, "TOPLEFT", 30, y)
    nowPlaying:SetWidth(520)
    nowPlaying:SetJustifyH("LEFT")
    y = y - 18

    self:RefreshChillMusicTrackCheckboxes()
    self:RefreshChillMusicNowPlaying()

    return y
end

function Config:RebuildChillMusicTrackList(category)
    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        return 0
    end

    local w = self.widgets
    local container = w.chillMusicTrackContainers and w.chillMusicTrackContainers[category]
    if not container then
        return 0
    end

    local playlist = module:GetBasePlaylist(category) or {}
    local rowHeight = 24
    local rows = container.rows or {}
    container.rows = rows

    w.chillMusicTrackCheckboxes[category] = {}

    local rowIndex = 0
    local config = self
    local moduleEnabled = self.parent:IsModuleEnabled("chillMusic")

    for index, track in ipairs(playlist) do
        rowIndex = rowIndex + 1
        local row = rows[rowIndex]
        if not row then
            row = CreateFrame("Button", nil, container)
            row:SetSize(520, rowHeight)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            local highlight = row:GetHighlightTexture()
            if highlight then
                highlight:SetAlpha(0.35)
            end
            rows[rowIndex] = row

            local checkbox = CreateFrame("CheckButton", nil, row, "InterfaceOptionsCheckButtonTemplate")
            checkbox:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.checkbox = checkbox
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((rowIndex - 1) * rowHeight))
        row:Show()

        local checkbox = row.checkbox
        checkbox:SetEnabled(moduleEnabled)
        checkbox:SetScript("OnClick", function(button)
            config:SetChillMusicTrackEnabled(category, track.key, button:GetChecked())
        end)
        checkbox:SetChecked(module:IsTrackEnabled(category, track))

        checkbox.Text:SetText(track.label or track.file or track.key or ("Track " .. index))
        checkbox.Text:ClearAllPoints()
        checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        checkbox.Text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        checkbox.Text:SetJustifyH("LEFT")
        checkbox.Text:SetTextColor(1, 0.82, 0)

        local highlight = row:GetHighlightTexture()
        if track.isCustom then
            if highlight then
                highlight:SetAlpha(0.35)
            end
            row:SetScript("OnMouseUp", function(_, button)
                if button ~= "LeftButton" then
                    return
                end
                if not config.parent:IsModuleEnabled("chillMusic") then
                    return
                end
                if checkbox:IsMouseOver() then
                    return
                end
                config:RemoveCustomTrack(category, track.key)
            end)
        else
            if highlight then
                highlight:SetAlpha(0)
            end
            row:SetScript("OnMouseUp", nil)
        end

        if track.key then
            w.chillMusicTrackCheckboxes[category][track.key] = checkbox
        end
    end

    for i = rowIndex + 1, #rows do
        local row = rows[i]
        if row then
            row:Hide()
            row:SetScript("OnMouseUp", nil)
        end
    end

    if rowIndex == 0 then
        if not container.emptyLabel then
            container.emptyLabel = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            container.emptyLabel:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            container.emptyLabel:SetJustifyH("LEFT")
        end
        container.emptyLabel:SetText("No tracks available")
        container.emptyLabel:Show()
        container:SetHeight(18)
    else
        if container.emptyLabel then
            container.emptyLabel:Hide()
        end
        container:SetHeight(rowIndex * rowHeight)
    end

    return container:GetHeight()
end

function Config:CreateChillMusicCustomControls(content, category, y)
    local w = self.widgets
    w.chillMusicCustomFrames = w.chillMusicCustomFrames or {}
    w.chillMusicCustomInputs = w.chillMusicCustomInputs or {}

    local frame = w.chillMusicCustomFrames[category]
    if not frame then
        frame = CreateFrame("Frame", nil, content)
        frame:SetSize(520, 72)
        w.chillMusicCustomFrames[category] = frame

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        title:SetText("Add SoundKit Track")

        local idLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        idLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -18)
        idLabel:SetText("SoundKit ID:")

        local idInput = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        idInput:SetAutoFocus(false)
        idInput:SetSize(120, 24)
        idInput:SetPoint("LEFT", idLabel, "RIGHT", 6, 0)
        idInput:SetNumeric(true)
        idInput:SetMaxLetters(6)

        local addButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        addButton:SetSize(90, 24)
        addButton:SetPoint("LEFT", idInput, "RIGHT", 12, 0)
        addButton:SetText("Add ID")
        addButton:SetScript("OnClick", function()
            self:AddCustomTrackFromInputs(category)
        end)

        local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        clearButton:SetSize(70, 24)
        clearButton:SetPoint("LEFT", addButton, "RIGHT", 8, 0)
        clearButton:SetText("Clear")
        clearButton:SetScript("OnClick", function()
            idInput:SetText("")
            self:UpdateChillMusicCustomAddState(category)
        end)

        local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -14)
        hint:SetWidth(520)
        hint:SetJustifyH("LEFT")
        hint:SetText("Enter the SoundKit ID (number). Click a custom track above to remove it from the list.")

        w.chillMusicCustomInputs[category] = {
            soundKit = idInput,
            addButton = addButton,
            clearButton = clearButton,
        }

        idInput:SetScript("OnTextChanged", function()
            self:UpdateChillMusicCustomAddState(category)
        end)
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", 50, y)
    frame:SetWidth(520)

    self:UpdateChillMusicCustomAddState(category)

    return frame, frame:GetHeight() or 72
end

function Config:UpdateChillMusicCustomAddState(category)
    local inputs = self.widgets and self.widgets.chillMusicCustomInputs and self.widgets.chillMusicCustomInputs[category]
    if not inputs then
        return
    end

    local enabled = self.parent:IsModuleEnabled("chillMusic")
    local soundKitText = TrimWhitespace(inputs.soundKit:GetText() or "")
    local soundKitValue = tonumber(soundKitText)

    if inputs.addButton then
        inputs.addButton:SetEnabled(enabled and soundKitValue and soundKitValue > 0)
    end
    if inputs.clearButton then
        inputs.clearButton:SetEnabled(enabled and soundKitText ~= "")
    end
    if inputs.soundKit then
        inputs.soundKit:SetEnabled(enabled)
    end
end

function Config:AddCustomTrackFromInputs(category)
    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        return
    end

    local inputs = self.widgets and self.widgets.chillMusicCustomInputs and self.widgets.chillMusicCustomInputs[category]
    if not inputs then
        return
    end

    local soundKitText = TrimWhitespace(inputs.soundKit:GetText() or "")
    local soundKitId = tonumber(soundKitText)

    if not soundKitId or soundKitId <= 0 then
        if self.parent and self.parent.Print then
            self.parent:Print("Chill Music: Please enter a valid SoundKit ID.")
        end
        return
    end

    local track, err = module:AddCustomTrack(category, soundKitId)
    if track then
        if self.parent and self.parent.Print then
            local label = track.label or track.file or track.key or "custom track"
            self.parent:Print(string.format("Chill Music: Added custom %s track '%s'.", category, label))
        end
        inputs.soundKit:SetText("")
        self:RebuildChillMusicTrackList(category)
        self:RefreshChillMusicTrackCheckboxes()
    else
        if self.parent and self.parent.Print then
            self.parent:Print("Chill Music: Unable to add track - " .. (err or "invalid data"))
        end
    end

    self:UpdateChillMusicCustomAddState(category)
end

function Config:RemoveCustomTrack(category, trackKey)
    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        return
    end

    local track = module:GetTrackByKey(category, trackKey)
    if module:RemoveCustomTrack(category, trackKey) then
        if self.parent and self.parent.Print then
            local label = track and (track.label or track.file or track.key) or trackKey or "track"
            self.parent:Print(string.format("Chill Music: Removed custom %s track '%s'.", category, label))
        end
        self:RebuildChillMusicTrackList(category)
        self:RefreshChillMusicTrackCheckboxes()
    else
        if self.parent and self.parent.Print then
            self.parent:Print("Chill Music: Unable to remove track.")
        end
    end

    self:UpdateChillMusicCustomAddState(category)
end

function Config:UpdateChillMusicChildControls()
    local enabled = self.parent:IsModuleEnabled("chillMusic")
    local w = self.widgets

    if w.chillMusicDescription then
        w.chillMusicDescription:SetAlpha(enabled and 1 or 0.5)
    end

    if w.chillMusicCategoryLabels then
        for _, label in pairs(w.chillMusicCategoryLabels) do
            if label then
                label:SetAlpha(enabled and 1 or 0.5)
            end
        end
    end

    if w.chillMusicTrackCheckboxes then
        for _, checkboxes in pairs(w.chillMusicTrackCheckboxes) do
            for _, checkbox in pairs(checkboxes) do
                if checkbox then
                    checkbox:SetEnabled(enabled)
                end
            end
        end
    end

    if w.chillMusicCustomInputs then
        for category in pairs(w.chillMusicCustomInputs) do
            self:UpdateChillMusicCustomAddState(category)
        end
    end

    if w.chillMusicNowPlayingLabel then
        w.chillMusicNowPlayingLabel:SetAlpha(enabled and 1 or 0.5)
    end

    self:RefreshChillMusicTrackCheckboxes()

    if enabled then
        self:RefreshChillMusicNowPlaying()
    end
end

-- Refresh logic
function Config:RefreshAll()
    self:RefreshOptionsPanel()
    self:UpdateGameMenuChildControls()
    self:UpdatePlaygroundChildControls()
    self:UpdateChillMusicChildControls()
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
        if w.chillMusicCheckbox then w.chillMusicCheckbox:SetChecked(self.parent:IsModuleEnabled("chillMusic")) end
        if w.favoriteToyCheckbox then w.favoriteToyCheckbox:SetChecked(self.parent:GetConfig("playground","showFavoriteToy")) end
        if w.skyridingCheckbox then w.skyridingCheckbox:SetChecked(self.parent:IsModuleEnabled("skyriding")) end
        if w.pitchControlCheckbox then w.pitchControlCheckbox:SetChecked(self.parent:GetConfig("skyriding","enablePitchControl")) end
        end)
    end

    function Config:SetChillMusicTrackEnabled(category, trackKey, enabled)
    if not category or not trackKey then
        return
    end

    local optionKey = (category == "indoors") and "indoorSelection" or "outdoorSelection"
    local current = self.parent:GetConfig("chillMusic", optionKey)
    if type(current) == "table" then
        current = CopyTable(current)
    else
        current = {}
    end

    if enabled then
        current[trackKey] = nil
    else
        current[trackKey] = false
    end

    if current and next(current) == nil then
        current = nil
    end

    self.parent:SetConfig(current, "chillMusic", optionKey)

    if self.parent.modules and self.parent.modules.chillMusic and self.parent.modules.chillMusic.OnTrackSelectionChanged then
        self.parent.modules.chillMusic:OnTrackSelectionChanged()
    end

    self:RefreshChillMusicTrackCheckboxes()
end

function Config:RefreshChillMusicTrackCheckboxes()
    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        return
    end

    local w = self.widgets
    if not w.chillMusicTrackCheckboxes then
        return
    end

    for category, checkboxes in pairs(w.chillMusicTrackCheckboxes) do
        for key, cb in pairs(checkboxes) do
            local track = module:GetTrackByKey(category, key)
            if cb and track then
                local checked = module:IsTrackEnabled(category, track)
                cb:SetChecked(checked)
            end
        end
    end
end

function Config:RefreshChillMusicNowPlaying()
    local label = self.widgets and self.widgets.chillMusicNowPlayingLabel
    if not label then
        return
    end

    local module = self.parent.modules and self.parent.modules.chillMusic
    if not module then
        label:SetText("Now Playing: (module not loaded)")
        return
    end

    if not self.parent:IsModuleEnabled("chillMusic") then
        label:SetText("Now Playing: (module disabled)")
        return
    end

    if not GetCVarBool("Sound_EnableMusic") then
        label:SetText("Now Playing: (music disabled in audio settings)")
        return
    end

    local track, environment = module:GetCurrentTrackInfo()
    if not track then
        label:SetText("Now Playing: (waiting for next track)")
        return
    end

    local envLabel = (environment == "indoors") and "Indoor" or "Outdoor"
    label:SetText(string.format("Now Playing: %s [%s]", track.label or track.file or track.key or "Unknown", envLabel))
end

function Config:UpdateChillMusicNowPlaying(track, environment)
    if not track then
        self:RefreshChillMusicNowPlaying()
        return
    end

    local label = self.widgets and self.widgets.chillMusicNowPlayingLabel
    if not label then
        return
    end

    local envLabel = (environment == "indoors") and "Indoor" or "Outdoor"
    label:SetText(string.format("Now Playing: %s [%s]", track.label or track.file or track.key or "Unknown", envLabel))
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
