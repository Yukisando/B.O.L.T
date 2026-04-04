local ADDON_NAME, BOLT = ...

local SoundMuter = {}
SoundMuter.alwaysInitialize = true

local POPUP_ROW_HEIGHT = 28

local function TrimWhitespace(text)
    if type(text) ~= "string" then
        return ""
    end

    local trimmed = text:match("^%s*(.-)%s*$")
    return trimmed or ""
end

local function GetNumericSoundID(value)
    local numericValue = tonumber(value)
    if not numericValue or numericValue < 1 then
        return nil
    end

    local integerValue = math.floor(numericValue)
    if integerValue ~= numericValue then
        return nil
    end

    return integerValue
end

local function SoundIDListsMatch(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then
        return false
    end

    local index = 1
    while true do
        if left[index] ~= right[index] then
            return false
        end
        if left[index] == nil then
            break
        end
        index = index + 1
    end

    for key in pairs(left) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
    end

    for key in pairs(right) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
    end

    return true
end

function SoundMuter:NormalizeMutedSoundIDs(soundIDs)
    local normalized = {}
    local seen = {}

    if type(soundIDs) ~= "table" then
        return normalized
    end

    for _, value in pairs(soundIDs) do
        local soundID = GetNumericSoundID(value)
        if soundID and not seen[soundID] then
            seen[soundID] = true
            table.insert(normalized, soundID)
        end
    end

    table.sort(normalized)
    return normalized
end

function SoundMuter:GetMutedSoundIDs()
    return self:NormalizeMutedSoundIDs(self.parent:GetConfig("soundMuter", "mutedSoundIDs") or {})
end

function SoundMuter:SaveMutedSoundIDs(soundIDs)
    self.parent:SetConfig(self:NormalizeMutedSoundIDs(soundIDs), "soundMuter", "mutedSoundIDs")
end

function SoundMuter:MuteSound(soundID)
    if type(MuteSoundFile) == "function" then
        pcall(MuteSoundFile, soundID)
    end
end

function SoundMuter:UnmuteSound(soundID)
    if type(UnmuteSoundFile) == "function" then
        pcall(UnmuteSoundFile, soundID)
    end
end

function SoundMuter:ApplyMutedSounds()
    for _, soundID in ipairs(self:GetMutedSoundIDs()) do
        self:MuteSound(soundID)
    end
end

function SoundMuter:ClearMutedSounds()
    for _, soundID in ipairs(self:GetMutedSoundIDs()) do
        self:UnmuteSound(soundID)
    end
end

function SoundMuter:SetPopupStatus(message, r, g, b)
    if not self.popup or not self.popup.statusText then
        return
    end

    self.popup.statusText:SetText(message or "")
    self.popup.statusText:SetTextColor(r or 1, g or 0.82, b or 0.3)
end

function SoundMuter:OnInitialize()
    self.isEnabled = false
    local savedSoundIDs = self.parent:GetConfig("soundMuter", "mutedSoundIDs") or {}
    local normalizedSoundIDs = self:NormalizeMutedSoundIDs(savedSoundIDs)
    if not SoundIDListsMatch(savedSoundIDs, normalizedSoundIDs) then
        self:SaveMutedSoundIDs(normalizedSoundIDs)
    end
end

function SoundMuter:OnEnable()
    self.isEnabled = true
    self:ApplyMutedSounds()
    self:SetPopupStatus("Muted sound IDs are active.", 0.45, 0.9, 0.45)
    self:RefreshPopupList()
end

function SoundMuter:OnDisable()
    self.isEnabled = false
    self:ClearMutedSounds()
    self:SetPopupStatus("Module disabled. Saved IDs will be muted again when re-enabled.", 1, 0.82, 0.3)
    self:RefreshPopupList()
end

function SoundMuter:AddMutedSoundID(soundID)
    local normalizedSoundID = GetNumericSoundID(soundID)
    if not normalizedSoundID then
        return false, "Enter a valid numeric sound ID."
    end

    local soundIDs = self:GetMutedSoundIDs()
    for _, existingSoundID in ipairs(soundIDs) do
        if existingSoundID == normalizedSoundID then
            return false, ("Sound ID %d is already in the list."):format(normalizedSoundID)
        end
    end

    table.insert(soundIDs, normalizedSoundID)
    self:SaveMutedSoundIDs(soundIDs)

    if self.isEnabled then
        self:MuteSound(normalizedSoundID)
        return true, ("Muted sound ID %d."):format(normalizedSoundID)
    end

    return true, ("Saved sound ID %d. Enable the module to mute it."):format(normalizedSoundID)
end

function SoundMuter:RemoveMutedSoundID(soundID)
    local normalizedSoundID = GetNumericSoundID(soundID)
    if not normalizedSoundID then
        return false, "Enter a valid numeric sound ID."
    end

    local soundIDs = self:GetMutedSoundIDs()
    local removeIndex = nil
    for index, existingSoundID in ipairs(soundIDs) do
        if existingSoundID == normalizedSoundID then
            removeIndex = index
            break
        end
    end

    if not removeIndex then
        return false, ("Sound ID %d is not in the list."):format(normalizedSoundID)
    end

    table.remove(soundIDs, removeIndex)
    self:SaveMutedSoundIDs(soundIDs)

    if self.isEnabled then
        self:UnmuteSound(normalizedSoundID)
        return true, ("Unmuted sound ID %d."):format(normalizedSoundID)
    end

    return true, ("Removed sound ID %d from the saved list."):format(normalizedSoundID)
end

function SoundMuter:ShowManagementPopup()
    if not self.popup then
        self:CreateManagementPopup()
    end

    self.popup.input:SetText("")
    if self.isEnabled then
        self:SetPopupStatus("Muted sound IDs are active.", 0.45, 0.9, 0.45)
    else
        self:SetPopupStatus("Module disabled. You can still edit the saved list.", 1, 0.82, 0.3)
    end
    self:RefreshPopupList()
    self.popup:Show()
    self.popup.input:SetFocus()
end

function SoundMuter:CreateManagementPopup()
    local popup = CreateFrame("Frame", "BOLTSoundMuterPopup", UIParent, "BackdropTemplate")
    popup:SetSize(430, 420)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    popup:SetBackdropColor(0.05, 0.05, 0.05, 1)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -18)
    title:SetText("Sound Muter")

    local subtitle = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetWidth(360)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetText("Add numeric sound file IDs to mute them, or remove IDs from the list to unmute them again.")

    local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    local inputLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 22, -76)
    inputLabel:SetText("Sound ID:")

    local input = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    input:SetPoint("TOPLEFT", popup, "TOPLEFT", 100, -72)
    input:SetSize(140, 24)
    input:SetAutoFocus(false)
    input:SetNumeric(true)
    input:SetMaxLetters(10)
    input:SetScript("OnEscapePressed", function()
        popup:Hide()
    end)
    popup.input = input

    local addButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    addButton:SetSize(80, 24)
    addButton:SetPoint("LEFT", input, "RIGHT", 10, 0)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
        local soundIDText = TrimWhitespace(input:GetText())
        local added, message = self:AddMutedSoundID(soundIDText)
        self:SetPopupStatus(message, added and 0.45 or 1, added and 0.9 or 0.35, added and 0.45 or 0.35)
        if added then
            input:SetText("")
            self:RefreshPopupList()
        end
    end)

    input:SetScript("OnEnterPressed", function()
        addButton:Click()
    end)

    local statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", popup, "TOPLEFT", 22, -106)
    statusText:SetWidth(386)
    statusText:SetJustifyH("LEFT")
    popup.statusText = statusText

    local listLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 22, -138)
    listLabel:SetText("Muted sound IDs")

    local scrollFrame = CreateFrame("ScrollFrame", "BOLTSoundMuterScrollFrame", popup, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -160)
    scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -32, 18)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(360, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 8, -10)
    emptyText:SetText("No muted sound IDs configured.")

    popup.scrollFrame = scrollFrame
    popup.scrollChild = scrollChild
    popup.emptyText = emptyText
    popup.rows = {}

    tinsert(UISpecialFrames, "BOLTSoundMuterPopup")

    self.popup = popup
end

function SoundMuter:CreatePopupRow(index)
    local row = CreateFrame("Frame", nil, self.popup.scrollChild)
    row:SetSize(350, POPUP_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", self.popup.scrollChild, "TOPLEFT", 0, -((index - 1) * POPUP_ROW_HEIGHT))

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0.08)
    row.background = background

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 10, 0)
    label:SetJustifyH("LEFT")
    row.label = label

    local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    removeButton:SetSize(74, 20)
    removeButton:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    removeButton:SetText("Remove")
    removeButton:SetScript("OnClick", function(button)
        local removed, message = self:RemoveMutedSoundID(button.soundID)
        self:SetPopupStatus(message, removed and 0.45 or 1, removed and 0.9 or 0.35, removed and 0.45 or 0.35)
        self:RefreshPopupList()
    end)
    row.removeButton = removeButton

    self.popup.rows[index] = row
    return row
end

function SoundMuter:RefreshPopupList()
    if not self.popup then
        return
    end

    local soundIDs = self:GetMutedSoundIDs()
    for index, soundID in ipairs(soundIDs) do
        local row = self.popup.rows[index] or self:CreatePopupRow(index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.popup.scrollChild, "TOPLEFT", 0, -((index - 1) * POPUP_ROW_HEIGHT))
        row.label:SetText(("Sound ID %d"):format(soundID))
        row.removeButton.soundID = soundID
        row:Show()
    end

    for index = #soundIDs + 1, #self.popup.rows do
        self.popup.rows[index]:Hide()
    end

    if #soundIDs == 0 then
        self.popup.emptyText:Show()
    else
        self.popup.emptyText:Hide()
    end

    local height = math.max(#soundIDs * POPUP_ROW_HEIGHT, 60)
    self.popup.scrollChild:SetHeight(height)
end

BOLT:RegisterModule("soundMuter", SoundMuter)