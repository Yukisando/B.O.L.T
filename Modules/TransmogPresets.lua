-- B.O.L.T Transmog Presets Module
-- Save and apply transmog sets globally across all characters.
-- Presets are stored in BOLTDB (account-wide) so any character can access them.
-- Applying a preset stages it at a Transmogrifier NPC; Blizzard's Apply button confirms.
local ADDON_NAME, BOLT = ...

local TransmogPresets = {
    displayName = "Transmog Presets",
    alwaysOn = true,
}

function TransmogPresets:IsSupported()
    -- Needs Midnight's outfit API; WoW: Forever has no transmogrification.
    return BOLT.has.transmogOutfits
end

-- Transmog-applicable equipment slots (excludes neck, rings, trinkets, ranged)
local TRANSMOG_SLOTS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 15, 16, 17, 19 }

local SLOT_NAMES = {
    [1]  = "Head",
    [3]  = "Shoulder",
    [4]  = "Shirt",
    [5]  = "Chest",
    [6]  = "Waist",
    [7]  = "Legs",
    [8]  = "Feet",
    [9]  = "Wrist",
    [10] = "Hands",
    [15] = "Cloak",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [19] = "Tabard",
}

local ROW_HEIGHT = 26

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function GetPresets()
    if not BOLTDB then BOLTDB = {} end
    if not BOLTDB.transmogPresets then BOLTDB.transmogPresets = {} end
    return BOLTDB.transmogPresets
end

local function GetPlayerKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

local function FormatDate(ts)
    if not ts then return "Unknown" end
    return date("%Y-%m-%d %H:%M", ts)
end

-- Midnight (12.0) replaced the transmog API with outfits (C_TransmogOutfitInfo).
-- Blizzard_TransmogShared (load-on-demand) builds the slot locations it expects.
local function EnsureTransmogUtil()
    if not TransmogUtil then
        C_AddOns.LoadAddOn("Blizzard_TransmogShared")
    end
    return TransmogUtil ~= nil
end

local function GetLocation(slotID)
    if not EnsureTransmogUtil() then return nil end
    return TransmogUtil.CreateTransmogLocation(slotID, Enum.TransmogType.Appearance, false)
end

-- The appearance (item modified appearance / source ID) a slot currently shows:
-- the applied transmog, or the item's own look when it isn't transmogrified.
local function GetSlotAppearanceID(slotID)
    local location = GetLocation(slotID)
    if not location then return nil end

    local info = C_Transmog.GetSlotVisualInfo(location:GetData())
    if not info or info.isHideVisual then return nil end
    local sourceID = info.appliedSourceID
    if sourceID == Constants.Transmog.NoTransmogID then
        sourceID = info.baseSourceID
    end
    return sourceID ~= Constants.Transmog.NoTransmogID and sourceID or nil
end

local function GetCurrentAppearances()
    local appearances, captured = {}, 0
    for _, slotID in ipairs(TRANSMOG_SLOTS) do
        local id = GetSlotAppearanceID(slotID)
        if id then
            appearances[slotID] = id
            captured = captured + 1
        end
    end
    return appearances, captured
end

local function HasAppearance(sourceID)
    return C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(sourceID)
end

local function GetAppearanceName(sourceID)
    local info = C_TransmogCollection.GetSourceInfo(sourceID)
    return info and info.name
end

---------------------------------------------------------------------------
-- Module lifecycle
---------------------------------------------------------------------------

function TransmogPresets:OnInitialize()
    self.atTransmogrifier = false
    self.selectedPreset   = nil

    local f = CreateFrame("Frame")
    f:RegisterEvent("TRANSMOGRIFY_OPEN")
    f:RegisterEvent("TRANSMOGRIFY_CLOSE")
    f:SetScript("OnEvent", function(_, event)
        self.atTransmogrifier = (event == "TRANSMOGRIFY_OPEN")
        self:RefreshStatusBar()
        self:RefreshButtons()
    end)
    self.eventFrame = f
end

---------------------------------------------------------------------------
-- Preset operations
---------------------------------------------------------------------------

function TransmogPresets:SaveCurrentAsPreset(name)
    local appearances, captured = GetCurrentAppearances()
    GetPresets()[name] = {
        name      = name,
        createdBy = GetPlayerKey(),
        updatedAt = time(),
        slots     = appearances,
    }
    if captured == 0 then
        BOLT:Print("Transmog preset '" .. name .. "' saved, but no slot appearances were captured.")
    else
        BOLT:Print(string.format("Transmog preset '%s' saved (%d/%d slots).", name, captured, #TRANSMOG_SLOTS))
    end
    self:RefreshPresetList()
    self:SelectPreset(name)
end

-- Stages the preset as pending changes on the outfit open in the transmog window;
-- the player reviews the cost and confirms with Blizzard's own Apply button.
function TransmogPresets:ApplyPreset(presetName)
    local preset = GetPresets()[presetName]
    if not preset then return end
    if not C_Transmog.IsAtTransmogNPC() then
        BOLT:Print("You must be at a Transmogrifier to apply presets.")
        return
    end

    local staged, missing = 0, 0
    for slotID, sourceID in pairs(preset.slots) do
        local location = GetLocation(slotID)
        if location and HasAppearance(sourceID) then
            local slot = location:GetSlot()
            local option = C_TransmogOutfitInfo.GetEquippedSlotOptionFromTransmogSlot(slot)
                or Enum.TransmogOutfitSlotOption.None
            C_TransmogOutfitInfo.SetPendingTransmog(slot, Enum.TransmogType.Appearance, option, sourceID,
                Enum.TransmogOutfitDisplayType.Assigned)
            staged = staged + 1
        else
            missing = missing + 1
        end
    end

    if staged == 0 then
        BOLT:Print("No appearances from '" .. presetName .. "' could be staged.")
        return
    end
    local note = missing > 0 and (" %d not collected on this character."):format(missing) or ""
    BOLT:Print(("Staged '%s' (%d slots).%s Click Apply in the transmog window to confirm."):format(
        presetName, staged, note))
end

function TransmogPresets:DeletePreset(presetName)
    GetPresets()[presetName] = nil
    BOLT:Print("Transmog preset '" .. presetName .. "' deleted.")
    if self.selectedPreset == presetName then
        self.selectedPreset = nil
    end
    self:RefreshPresetList()
    self:RefreshPresetDetails(nil)
    self:RefreshButtons()
end

function TransmogPresets:RenamePreset(oldName, newName)
    local presets = GetPresets()
    local data    = presets[oldName]
    if not data then return end
    if presets[newName] then
        BOLT:Print("A preset named '" .. newName .. "' already exists.")
        return
    end
    data.name       = newName
    presets[newName] = data
    presets[oldName] = nil
    if self.selectedPreset == oldName then self.selectedPreset = newName end
    BOLT:Print("Preset renamed to '" .. newName .. "'.")
    self:RefreshPresetList()
    self:SelectPreset(newName)
end

---------------------------------------------------------------------------
-- Show / hide the main UI
---------------------------------------------------------------------------

function TransmogPresets:ShowUI()
    if not self.mainFrame then self:CreateUI() end
    if self.mainFrame:IsShown() then
        self.mainFrame:Hide()
        return
    end
    self:RefreshPresetList()
    self:RefreshPresetDetails(self.selectedPreset)
    self:RefreshStatusBar()
    self:RefreshButtons()
    self.mainFrame:Show()
end

---------------------------------------------------------------------------
-- UI creation
---------------------------------------------------------------------------

function TransmogPresets:CreateUI()
    local FRAME_W     = 660
    local FRAME_H     = 500
    local LIST_W      = 210
    local TOP_INSET   = -44   -- below title
    local BTM_INSET   = 52    -- above buttons

    ------------------------------------------------------------------
    -- Main frame
    ------------------------------------------------------------------
    local frame = BOLT:CreateDialog("BOLTTransmogPresetsFrame", FRAME_W, FRAME_H, "Transmog Presets")
    self.mainFrame = frame

    ------------------------------------------------------------------
    -- Left panel – preset list
    ------------------------------------------------------------------
    local listBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT",    frame, "TOPLEFT",    16, TOP_INSET)
    listBg:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 16, BTM_INSET)
    listBg:SetWidth(LIST_W)
    listBg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    listBg:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    listBg:SetBackdropBorderColor(0.4, 0.4, 0.5)

    local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    listLabel:SetPoint("BOTTOMLEFT", listBg, "TOPLEFT", 2, 2)
    listLabel:SetText("Saved Presets")

    local listScroll = CreateFrame("ScrollFrame", "BOLTTransmogListScroll", listBg, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT",     listBg, "TOPLEFT",     4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -22, 4)

    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetWidth(LIST_W - 30)
    listChild:SetHeight(1)
    listScroll:SetScrollChild(listChild)
    self.listChild   = listChild
    self.listRowPool = {}

    ------------------------------------------------------------------
    -- Right panel – preset details
    ------------------------------------------------------------------
    local detailBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    detailBg:SetPoint("TOPLEFT",     listBg,  "TOPRIGHT",    10, 0)
    detailBg:SetPoint("BOTTOMRIGHT", frame,   "BOTTOMRIGHT", -16, BTM_INSET)
    detailBg:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    detailBg:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
    detailBg:SetBackdropBorderColor(0.4, 0.4, 0.5)

    local detailLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detailLabel:SetPoint("BOTTOMLEFT", detailBg, "TOPLEFT", 2, 2)
    detailLabel:SetText("Preset Details")

    local detailScroll = CreateFrame("ScrollFrame", "BOLTTransmogDetailScroll", detailBg, "UIPanelScrollFrameTemplate")
    detailScroll:SetPoint("TOPLEFT",     detailBg, "TOPLEFT",     4, -4)
    detailScroll:SetPoint("BOTTOMRIGHT", detailBg, "BOTTOMRIGHT", -22, 4)

    local detailChild = CreateFrame("Frame", nil, detailScroll)
    detailChild:SetHeight(500)
    detailScroll:SetScrollChild(detailChild)
    detailScroll:SetScript("OnSizeChanged", function(_, w)
        detailChild:SetWidth(w - 4)
    end)
    self.detailChild = detailChild

    local metaText = detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    metaText:SetPoint("TOPLEFT", detailChild, "TOPLEFT", 10, -10)
    metaText:SetWidth(380)
    metaText:SetJustifyH("LEFT")
    metaText:SetText("Select a preset to view details.")
    self.detailMeta = metaText

    local slotHeader = detailChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotHeader:SetPoint("TOPLEFT", metaText, "BOTTOMLEFT", 0, -12)
    slotHeader:SetText("Slot Appearances:")
    slotHeader:Hide()
    self.detailSlotHeader = slotHeader

    -- One font-string row per transmog slot (lazily anchored in RefreshPresetDetails)
    self.detailSlotRows = {}
    for _, slotID in ipairs(TRANSMOG_SLOTS) do
        local row = detailChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetWidth(400)
        row:SetJustifyH("LEFT")
        row:Hide()
        self.detailSlotRows[slotID] = row
    end

    ------------------------------------------------------------------
    -- Status bar
    ------------------------------------------------------------------
    local statusBar = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 20)
    statusBar:SetJustifyH("LEFT")
    self.statusBar = statusBar

    ------------------------------------------------------------------
    -- Buttons (right-to-left layout along the bottom)
    ------------------------------------------------------------------
    local function Btn(label, w, rightAnchor, rightOffset, onClick)
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(w, 24)
        if rightAnchor then
            b:SetPoint("BOTTOMRIGHT", rightAnchor, "BOTTOMLEFT", rightOffset or -6, 0)
        else
            b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
        end
        b:SetText(label)
        b:SetScript("OnClick", onClick)
        return b
    end

    local closeBtn  = Btn("Close",  80,  nil,       nil, function() frame:Hide() end)
    local deleteBtn = Btn("Delete", 80,  closeBtn,  -6,  function()
        if self.selectedPreset then self:ConfirmDelete(self.selectedPreset) end
    end)
    local renameBtn = Btn("Rename", 80,  deleteBtn, -6,  function()
        if self.selectedPreset then
            self:ShowInputDialog("Rename Preset:", self.selectedPreset, function(newName)
                self:RenamePreset(self.selectedPreset, newName)
            end)
        end
    end)
    local applyBtn  = Btn("Stage",  80,  renameBtn, -6,  function()
        if self.selectedPreset then self:ApplyPreset(self.selectedPreset) end
    end)
    Btn("Save Current Set", 130, applyBtn,  -6,  function()
        self:ShowInputDialog("Save Preset As:", "", function(name)
            self:ConfirmSave(name)
        end)
    end)

    self.applyBtn  = applyBtn
    self.deleteBtn = deleteBtn
    self.renameBtn = renameBtn
end

---------------------------------------------------------------------------
-- Preset list
---------------------------------------------------------------------------

function TransmogPresets:RefreshPresetList()
    if not self.listChild then return end

    local presets = GetPresets()
    local names   = {}
    for name in pairs(presets) do table.insert(names, name) end
    table.sort(names)

    local pool = self.listRowPool
    for i = 1, #pool do pool[i]:Hide() end

    local y = 0
    for i, name in ipairs(names) do
        local row = pool[i]
        if not row then
            row = CreateFrame("Button", nil, self.listChild)
            row:SetHeight(ROW_HEIGHT)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(row)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT",  row, "LEFT",  8, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")
            row.text:SetWordWrap(false)
            row:SetScript("OnEnter", function(r)
                if r.presetName ~= self.selectedPreset then
                    r.bg:SetColorTexture(0.3, 0.3, 0.3, 0.5)
                end
            end)
            row:SetScript("OnLeave", function(r)
                if r.presetName ~= self.selectedPreset then
                    r.bg:SetColorTexture(1, 1, 1, 0)
                end
            end)
            row:SetScript("OnClick", function(r)
                self:SelectPreset(r.presetName)
            end)
            pool[i] = row
        end

        row.presetName = name
        row.text:SetText(name)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  self.listChild, "TOPLEFT",  0, -y)
        row:SetPoint("TOPRIGHT", self.listChild, "TOPRIGHT", 0, -y)
        self:_SetRowHighlight(row, name == self.selectedPreset)
        row:Show()
        y = y + ROW_HEIGHT
    end

    self.listChild:SetHeight(math.max(y, 1))

    if not self.emptyLabel then
        self.emptyLabel = self.listChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        self.emptyLabel:SetPoint("TOP", self.listChild, "TOP", 0, -20)
        self.emptyLabel:SetText("No presets saved")
    end
    self.emptyLabel:SetShown(#names == 0)
end

function TransmogPresets:_SetRowHighlight(row, selected)
    if selected then
        row.bg:SetColorTexture(0.2, 0.4, 0.8, 0.5)
    else
        row.bg:SetColorTexture(1, 1, 1, 0)
    end
end

function TransmogPresets:SelectPreset(presetName)
    self.selectedPreset = presetName
    for _, row in ipairs(self.listRowPool) do
        if row:IsShown() then
            self:_SetRowHighlight(row, row.presetName == presetName)
        end
    end
    self:RefreshPresetDetails(presetName)
    self:RefreshButtons()
end

---------------------------------------------------------------------------
-- Detail panel
---------------------------------------------------------------------------

function TransmogPresets:RefreshPresetDetails(presetName)
    if not self.detailMeta then return end

    if self.detailSlotHeader then self.detailSlotHeader:Hide() end
    for _, row in pairs(self.detailSlotRows or {}) do row:Hide() end

    if not presetName then
        self.detailMeta:SetText("Select a preset to view details.")
        return
    end

    local preset = GetPresets()[presetName]
    if not preset then
        self.detailMeta:SetText("Preset not found.")
        return
    end

    self.detailMeta:SetText(string.format(
        "|cffaaaaff%s|r\nSaved by: %s\nSaved on: %s",
        preset.name,
        preset.createdBy or "Unknown",
        FormatDate(preset.updatedAt)
    ))

    self.detailSlotHeader:Show()

    local prevAnchor = self.detailSlotHeader
    for _, slotID in ipairs(TRANSMOG_SLOTS) do
        local row        = self.detailSlotRows[slotID]
        local slotName   = SLOT_NAMES[slotID] or ("Slot " .. slotID)
        local appearance = preset.slots and preset.slots[slotID]

        if appearance and appearance > 0 then
            local name = GetAppearanceName(appearance) or ("ID " .. appearance)
            if HasAppearance(appearance) then
                row:SetText(string.format("|cff44ff44%s|r  %s", slotName, name))
            else
                row:SetText(string.format("|cffff8844%s|r  %s  |cffff4444not collected|r", slotName, name))
            end
        else
            row:SetText(string.format("|cff555555%s|r  —", slotName))
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", prevAnchor, "BOTTOMLEFT", 0, -5)
        row:Show()
        prevAnchor = row
    end

    local totalH = 100 + #TRANSMOG_SLOTS * 22 + 20
    self.detailChild:SetHeight(totalH)
end

---------------------------------------------------------------------------
-- Status bar & button state
---------------------------------------------------------------------------

function TransmogPresets:RefreshStatusBar()
    if not self.statusBar or not self.mainFrame then return end
    if self.atTransmogrifier then
        self.statusBar:SetText("|cff44ff44At Transmogrifier|r  —  Stage a preset, then click Apply in the transmog window")
    else
        self.statusBar:SetText("|cff888888Visit a Transmogrifier to stage presets|r")
    end
end

function TransmogPresets:RefreshButtons()
    if not self.applyBtn then return end
    local sel      = self.selectedPreset ~= nil
    local canApply = sel and self.atTransmogrifier

    self.applyBtn:SetEnabled(canApply)
    self.applyBtn:SetAlpha(canApply and 1 or 0.4)
    self.deleteBtn:SetEnabled(sel)
    self.deleteBtn:SetAlpha(sel and 1 or 0.4)
    self.renameBtn:SetEnabled(sel)
    self.renameBtn:SetAlpha(sel and 1 or 0.4)
end

---------------------------------------------------------------------------
-- Shared input dialog (used for Save and Rename)
---------------------------------------------------------------------------

function TransmogPresets:ShowInputDialog(labelText, prefill, onConfirm)
    if not self.inputDialog then
        local dlg = CreateFrame("Frame", "BOLTTransmogInputDialog", UIParent, "BackdropTemplate")
        dlg:SetSize(340, 130)
        dlg:SetPoint("CENTER")
        dlg:SetFrameStrata("FULLSCREEN_DIALOG")
        dlg:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        dlg:SetBackdropColor(0, 0, 0, 1)
        dlg:EnableMouse(true)
        dlg:SetMovable(true)
        dlg:RegisterForDrag("LeftButton")
        dlg:SetScript("OnDragStart", dlg.StartMoving)
        dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
        dlg:Hide()
        tinsert(UISpecialFrames, "BOLTTransmogInputDialog")
        self.inputDialog = dlg

        dlg.label = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dlg.label:SetPoint("TOP", dlg, "TOP", 0, -20)

        local eb = CreateFrame("EditBox", "BOLTTransmogInputEB", dlg, "InputBoxTemplate")
        eb:SetSize(280, 20)
        eb:SetPoint("TOP", dlg.label, "BOTTOM", 0, -10)
        eb:SetMaxLetters(64)
        eb:SetAutoFocus(true)
        eb:SetScript("OnEscapePressed", function() dlg:Hide() end)
        eb:SetScript("OnEnterPressed", function()
            local text = eb:GetText():match("^%s*(.-)%s*$")
            if text and #text > 0 then
                dlg:Hide()
                if dlg._onConfirm then dlg._onConfirm(text) end
            end
        end)
        dlg.editBox = eb

        local okBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        okBtn:SetSize(80, 22)
        okBtn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 14)
        okBtn:SetText("Confirm")
        okBtn:SetScript("OnClick", function()
            local text = dlg.editBox:GetText():match("^%s*(.-)%s*$")
            if text and #text > 0 then
                dlg:Hide()
                if dlg._onConfirm then dlg._onConfirm(text) end
            end
        end)

        local cancelBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
        cancelBtn:SetSize(80, 22)
        cancelBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 16, 14)
        cancelBtn:SetText("Cancel")
        cancelBtn:SetScript("OnClick", function() dlg:Hide() end)
    end

    self.inputDialog.label:SetText(labelText)
    self.inputDialog.editBox:SetText(prefill or "")
    self.inputDialog.editBox:HighlightText()
    self.inputDialog._onConfirm = onConfirm
    self.inputDialog:Show()
    self.inputDialog.editBox:SetFocus()
end

---------------------------------------------------------------------------
-- Confirmation popups (overwrite / delete)
---------------------------------------------------------------------------

StaticPopupDialogs.BOLT_TRANSMOG_OVERWRITE = {
    text = "A preset named \"%s\" already exists.\nOverwrite it?",
    button1 = "Overwrite",
    button2 = CANCEL,
    OnAccept = function(_, name) TransmogPresets:SaveCurrentAsPreset(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs.BOLT_TRANSMOG_DELETE = {
    text = "Delete transmog preset \"%s\"?",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(_, name) TransmogPresets:DeletePreset(name) end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function TransmogPresets:ConfirmSave(name)
    if GetPresets()[name] then
        StaticPopup_Show("BOLT_TRANSMOG_OVERWRITE", name, nil, name)
    else
        self:SaveCurrentAsPreset(name)
    end
end

function TransmogPresets:ConfirmDelete(presetName)
    StaticPopup_Show("BOLT_TRANSMOG_DELETE", presetName, nil, presetName)
end

---------------------------------------------------------------------------
-- Debug helper  (/bolt transmog debug)
---------------------------------------------------------------------------

function TransmogPresets:PrintDebug()
    BOLT:Print("=== Transmog Presets Debug ===")
    BOLT:Print("TransmogUtil loaded: " .. tostring(EnsureTransmogUtil()))
    BOLT:Print("At transmogrifier: " .. tostring(C_Transmog.IsAtTransmogNPC()))
    for _, slotID in ipairs(TRANSMOG_SLOTS) do
        local sourceID = GetSlotAppearanceID(slotID)
        print(("  %s: %s"):format(SLOT_NAMES[slotID], sourceID
            and ("%d (%s)"):format(sourceID, GetAppearanceName(sourceID) or "?") or "-"))
    end
end

---------------------------------------------------------------------------
-- Registration
---------------------------------------------------------------------------

BOLT:RegisterModule("transmogPresets", TransmogPresets)
