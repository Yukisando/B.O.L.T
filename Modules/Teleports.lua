-- B.O.L.T Teleports Module
-- Map pins for teleport locations with secure button execution.
-- Static data lives in Data/TeleportData.lua; runtime additions in BOLTDB.teleports.
-- Use "/bolt export-teleports" to dump runtime teleports for pasting into TeleportData.lua.

local ADDON_NAME, BOLT = ...

local Teleports = {}
BOLT:RegisterModule("teleports", Teleports)

local dataProvider = nil
local eventFrame = nil

local DEFAULT_ICON = "Interface\\Icons\\Spell_Arcane_TeleportDalaran"

-------------------------------------------------
-- Pin Mixin (referenced by TeleportPins.xml)
-------------------------------------------------

---@class BOLTTeleportPinMixin : MapCanvasPinMixin
BOLTTeleportPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BOLTTeleportPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function BOLTTeleportPinMixin:OnAcquired(entry, x, y)
    self.entry = entry

    if not self.Icon then
        self.Icon = self:CreateTexture(nil, "ARTWORK")
        self.Icon:SetSize(24, 24)
        self.Icon:SetPoint("CENTER")
        self.Icon:SetDrawLayer("ARTWORK", 7)
    end

    if self.Icon and entry then
        self.Icon:SetTexture(entry.icon or DEFAULT_ICON)
        self.Icon:Show()
        self.Icon:SetVertexColor(1, 1, 1, 1)
    end

    self:SetSize(24, 24)
    self:Show()
    self:EnableMouse(true)
    self:SetAlpha(1.0)

    if x and y then
        self:SetPosition(x, y)
    end
end

function BOLTTeleportPinMixin:OnReleased()
    self.entry = nil
    if self.Icon then self.Icon:Hide() end
end

function BOLTTeleportPinMixin:OnMouseEnter()
    if not self.entry then return end

    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()

    local entry = self.entry
    if entry.type == "item" and entry.id and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(entry.id)
    elseif entry.type == "spell" and entry.id and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(entry.id)
    else
        GameTooltip:AddLine(entry.name or "Teleport", 1, 1, 1, true)
        if entry.desc then
            GameTooltip:AddLine(entry.desc, 0.8, 0.8, 0.8, true)
        end
    end

    local cfg = BOLT:GetConfig("teleports") or {}
    if cfg.editMode and entry.isUserAdded then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-click to delete", 0.7, 0.7, 0.7)
    end

    GameTooltip:Show()
end

function BOLTTeleportPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function BOLTTeleportPinMixin:OnMouseDown(button)
    if not self.entry then return end

    if button == "RightButton" then
        local cfg = BOLT:GetConfig("teleports") or {}
        if cfg.editMode and self.entry.isUserAdded then
            local teleportsModule = BOLT.modules and BOLT.modules.teleports
            if teleportsModule then
                local combined = teleportsModule:GetTeleportList()
                for i, e in ipairs(combined) do
                    if e == self.entry then
                        teleportsModule:DeleteTeleport(i)
                        return
                    end
                end
            end
        end
    elseif button == "LeftButton" then
        local teleportsModule = BOLT.modules and BOLT.modules.teleports
        if teleportsModule then
            teleportsModule:OpenTeleportPopup(self.entry)
        end
    end
end

-------------------------------------------------
-- Data Provider Mixin
-------------------------------------------------

---@class BOLTTeleportDataProviderMixin : MapCanvasDataProviderMixin
BOLTTeleportDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

function BOLTTeleportDataProviderMixin:OnAdded(mapCanvas)
    MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)
    self:RefreshAllData()
end

function BOLTTeleportDataProviderMixin:OnRemoved(mapCanvas)
    self:RemoveAllData()
    MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas)
end

function BOLTTeleportDataProviderMixin:OnMapChanged()
    self:RefreshAllData()
end

function BOLTTeleportDataProviderMixin:RemoveAllData()
    local map = self:GetMap()
    if map then
        map:RemoveAllPinsByTemplate("BOLTTeleportPinTemplate")
    end
end

function BOLTTeleportDataProviderMixin:RefreshAllData()
    local map = self:GetMap()
    if not map then return end

    self:RemoveAllData()

    local teleportsModule = BOLT.modules and BOLT.modules.teleports
    if not teleportsModule then return end
    if not BOLT:IsModuleEnabled("teleports") then return end

    local currentMapID = map:GetMapID()
    if not currentMapID then return end

    local ok, list = pcall(teleportsModule.GetTeleportList, teleportsModule)
    if not ok or not list or type(list) ~= "table" then return end

    for _, entry in ipairs(list) do
        local x, y, canProject = teleportsModule:ProjectToMap(entry, currentMapID)
        if canProject and x and y then
            map:AcquirePin("BOLTTeleportPinTemplate", entry, x, y)
        end
    end
end

-------------------------------------------------
-- Secure UI (single secure button + popup)
-------------------------------------------------

local SecureButton = nil
local TeleportPopup = nil

local function InitSecureButton()
    if SecureButton then return end
    if InCombatLockdown() then
        local w = CreateFrame("Frame")
        w:RegisterEvent("PLAYER_REGEN_ENABLED")
        w:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            InitSecureButton()
        end)
        return
    end

    SecureButton = CreateFrame("Button", "BOLTTeleportSecureButton", UIParent, "SecureActionButtonTemplate")
    SecureButton:SetSize(1, 1)
    SecureButton:SetPoint("CENTER")
    SecureButton:RegisterForClicks("AnyUp", "AnyDown")
    SecureButton:Hide()
    SecureButton:SetScript("PostClick", function()
        if TeleportPopup then TeleportPopup:Hide() end
    end)
end

local function InitTeleportPopup()
    if TeleportPopup then return end
    if not SecureButton then InitSecureButton() end
    if not SecureButton then return end

    local popup = CreateFrame("Frame", "BOLTTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(280, 160)
    popup:SetPoint("CENTER")
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

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", 0, -16)
    popup.title:SetText("Confirm Teleport")

    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.text:SetPoint("TOP", popup.title, "BOTTOM", 0, -10)
    popup.text:SetWidth(250)
    popup.text:SetJustifyH("CENTER")

    popup.combatWarning = popup:CreateFontString(nil, "OVERLAY", "GameFontRed")
    popup.combatWarning:SetPoint("TOP", popup.text, "BOTTOM", 0, -5)
    popup.combatWarning:SetWidth(250)
    popup.combatWarning:SetText("Cannot teleport during combat!")
    popup.combatWarning:Hide()

    local visualBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    visualBtn:SetSize(120, 26)
    visualBtn:SetPoint("BOTTOM", 0, 16)
    visualBtn:SetText("Teleport")
    popup.visualButton = visualBtn

    SecureButton:SetParent(popup)
    SecureButton:ClearAllPoints()
    SecureButton:SetAllPoints(visualBtn)
    SecureButton:SetFrameStrata("DIALOG")
    SecureButton:SetFrameLevel(visualBtn:GetFrameLevel() + 10)

    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    tinsert(UISpecialFrames, "BOLTTeleportPopup")

    popup:RegisterEvent("PLAYER_REGEN_DISABLED")
    popup:RegisterEvent("PLAYER_REGEN_ENABLED")
    popup:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            visualBtn:SetEnabled(false)
            popup.combatWarning:Show()
        elseif event == "PLAYER_REGEN_ENABLED" then
            visualBtn:SetEnabled(true)
            popup.combatWarning:Hide()
        end
    end)

    popup:SetScript("OnShow", function()
        SecureButton:Show()
        if InCombatLockdown() then
            visualBtn:SetEnabled(false)
            popup.combatWarning:Show()
        else
            visualBtn:SetEnabled(true)
            popup.combatWarning:Hide()
        end
    end)

    popup:SetScript("OnHide", function()
        SecureButton:Hide()
    end)

    TeleportPopup = popup
end

local function PrepareTeleport(entry)
    if not entry then return false end
    if InCombatLockdown() then
        BOLT:Print("Cannot prepare teleport during combat.")
        return false
    end
    if not SecureButton then
        InitSecureButton()
        if not SecureButton then return false end
    end

    SecureButton:SetAttribute("type", nil)
    SecureButton:SetAttribute("spell", nil)
    SecureButton:SetAttribute("item", nil)
    SecureButton:SetAttribute("macrotext", nil)

    if entry.type == "spell" then
        SecureButton:SetAttribute("type", "spell")
        SecureButton:SetAttribute("spell", entry.id)
    elseif entry.type == "item" or entry.type == "toy" then
        SecureButton:SetAttribute("type", "macro")
        SecureButton:SetAttribute("macrotext", "/use item:" .. entry.id)
    end

    return true
end

-------------------------------------------------
-- Coordinate Projection
-------------------------------------------------

local function SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    return ok and res or nil
end

function Teleports:ProjectToMap(entry, targetMapID)
    if not entry or not targetMapID then return nil, nil, false end

    local entryMapID = entry.mapID
    local entryX = entry.x or 0.5
    local entryY = entry.y or 0.5

    if not entryMapID then return entryX, entryY, true end
    if entryMapID == targetMapID then return entryX, entryY, true end

    if C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
        local continentID, worldPos = SafeCall(C_Map.GetWorldPosFromMapPos, entryMapID, CreateVector2D(entryX, entryY))
        if continentID and worldPos then
            local mapPos = SafeCall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, targetMapID)
            if mapPos then
                local projX, projY = mapPos:GetXY()
                if projX and projY and projX >= 0 and projX <= 1 and projY >= 0 and projY <= 1 then
                    return projX, projY, true
                end
            end
        end
    end

    return nil, nil, false
end

-------------------------------------------------
-- Teleport List Management
-------------------------------------------------

function Teleports:GetTeleportList()
    local shipped = BOLT.TeleportData or {}

    if not BOLTDB then BOLTDB = {} end
    if not BOLTDB.teleports then BOLTDB.teleports = {} end
    local userAdded = BOLTDB.teleports

    local combined = {}
    for _, entry in ipairs(shipped) do
        table.insert(combined, entry)
    end
    for _, entry in ipairs(userAdded) do
        table.insert(combined, entry)
    end
    return combined
end

function Teleports:DeleteTeleport(index)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end

    local entry = combined[index]
    if not entry.isUserAdded then
        BOLT:Print("Teleports: Cannot delete a shipped teleport. Remove it from Data/TeleportData.lua instead.")
        return
    end

    if BOLTDB.teleports then
        for i, e in ipairs(BOLTDB.teleports) do
            if e == entry then
                table.remove(BOLTDB.teleports, i)
                break
            end
        end
    end

    BOLT:Print("Teleports: Removed '" .. tostring(entry.name) .. "'")
    self:RefreshPins()
end

function Teleports:UpdateTeleport(index, newData)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end

    local entry = combined[index]
    if not entry.isUserAdded then
        BOLT:Print("Teleports: Cannot edit a shipped teleport. Edit Data/TeleportData.lua instead.")
        return
    end

    if BOLTDB.teleports then
        for i, e in ipairs(BOLTDB.teleports) do
            if e == entry then
                for k, v in pairs(newData) do
                    BOLTDB.teleports[i][k] = v
                end
                self:RefreshPins()
                return
            end
        end
    end
end

-------------------------------------------------
-- Pin Refresh
-------------------------------------------------

function Teleports:RefreshPins()
    if dataProvider then dataProvider:RefreshAllData() end
end

function Teleports:UpdateMapDisplay()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshPins()
    end
end

-------------------------------------------------
-- Teleport Popup
-------------------------------------------------

function Teleports:OpenTeleportPopup(entry)
    if not entry then return end

    if not TeleportPopup then InitTeleportPopup() end
    if not TeleportPopup then return end

    local prepared = PrepareTeleport(entry)

    local displayName = entry.name or "Unknown"
    local typeLabel = entry.type and (entry.type:sub(1, 1):upper() .. entry.type:sub(2)) or "Unknown"
    TeleportPopup.text:SetText(string.format("Teleport to:\n|cff00ff00%s|r\n|cff888888(%s)|r", displayName, typeLabel))
    TeleportPopup:Show()

    if not prepared and InCombatLockdown() then
        TeleportPopup.combatWarning:Show()
        TeleportPopup.visualButton:SetEnabled(false)
    end
end

-------------------------------------------------
-- Add Teleport Popup
-------------------------------------------------

function Teleports:ShowAddTeleportPopup()
    local cfg = BOLT:GetConfig("teleports") or {}
    if not cfg.editMode then return end

    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        BOLT:Print("Teleports: Open the World Map first.")
        return
    end

    if not self.addPopup then self:CreateAddTeleportPopup() end

    local mapID = WorldMapFrame:GetMapID()
    local cursorX, cursorY = 0.5, 0.5
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition then
        local cx, cy = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if cx and cy then cursorX, cursorY = cx, cy end
    end

    self.addPopup.mapID = mapID
    self.addPopup.x = cursorX
    self.addPopup.y = cursorY

    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo and mapInfo.name or ("Map " .. tostring(mapID))
    self.addPopup.mapLabel:SetText(string.format("Map: %s (%d) at %.1f%%, %.1f%%", mapName, mapID, cursorX * 100, cursorY * 100))

    self.addPopup.nameInput:SetText("")
    self.addPopup.idInput:SetText("")
    self.addPopup.selectedType = "spell"
    UIDropDownMenu_SetText(self.addPopup.typeDropdown, "Spell")

    self.addPopup:Show()
    C_Timer.After(0.05, function()
        if self.addPopup and self.addPopup:IsShown() then
            self.addPopup.nameInput:SetText("")
            self.addPopup.nameInput:SetFocus()
        end
    end)
end

function Teleports:CreateAddTeleportPopup()
    local popup = CreateFrame("Frame", "BOLTAddTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(420, 240)
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

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Add Teleport at Cursor")

    popup.mapLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.mapLabel:SetPoint("TOP", title, "BOTTOM", 0, -10)
    popup.mapLabel:SetText("Map: Unknown")

    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 25, -70)
    nameLabel:SetText("Name (required):")

    popup.nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    popup.nameInput:SetSize(230, 20)
    popup.nameInput:SetAutoFocus(false)
    popup.nameInput:SetMaxLetters(100)

    local typeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -25)
    typeLabel:SetText("Type:")

    local typeDropdown = CreateFrame("Frame", "BOLTTeleportTypeDropdown", popup, "UIDropDownMenuTemplate")
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(typeDropdown, 100)
    UIDropDownMenu_SetText(typeDropdown, "Spell")
    popup.typeDropdown = typeDropdown
    popup.selectedType = "spell"

    UIDropDownMenu_Initialize(typeDropdown, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, t in ipairs({ "spell", "item", "toy" }) do
            info.text = t:sub(1, 1):upper() .. t:sub(2)
            info.value = t
            info.checked = (popup.selectedType == t)
            info.func = function()
                popup.selectedType = t
                UIDropDownMenu_SetText(typeDropdown, t:sub(1, 1):upper() .. t:sub(2))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local idLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -25)
    idLabel:SetText("ID (required):")

    popup.idInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    popup.idInput:SetPoint("LEFT", idLabel, "RIGHT", 10, 0)
    popup.idInput:SetSize(100, 20)
    popup.idInput:SetAutoFocus(false)
    popup.idInput:SetNumeric(true)

    local saveBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -10, 20)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function() self:SaveTeleportFromPopup() end)

    local cancelBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    cancelBtn:SetSize(100, 24)
    cancelBtn:SetPoint("BOTTOMLEFT", popup, "BOTTOM", 10, 20)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() popup:Hide() end)

    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    tinsert(UISpecialFrames, "BOLTAddTeleportPopup")
    self.addPopup = popup
end

function Teleports:SaveTeleportFromPopup()
    local popup = self.addPopup
    if not popup then return end

    local displayName = popup.nameInput:GetText()
    local entryType = popup.selectedType or "spell"
    local id = tonumber(popup.idInput:GetText())

    if not displayName or displayName == "" then
        BOLT:Print("Teleports: Please enter a name.")
        return
    end
    if not id then
        BOLT:Print("Teleports: Please enter a valid ID.")
        return
    end

    -- Resolve icon from the spell/item/toy ID
    local icon = "Interface\\Icons\\INV_Misc_Rune_01"
    if entryType == "spell" then
        local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        if spellInfo and spellInfo.iconID then
            icon = spellInfo.iconID
        elseif C_Spell and C_Spell.GetSpellTexture then
            local tex = C_Spell.GetSpellTexture(id)
            if tex then icon = tex end
        end
    elseif entryType == "toy" then
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local _, _, toyIcon = C_ToyBox.GetToyInfo(id)
            if toyIcon then icon = toyIcon end
        end
    elseif entryType == "item" then
        local itemIcon = C_Item.GetItemIconByID(id)
        if itemIcon then icon = itemIcon end
    end

    local entry = {
        name = displayName,
        mapID = popup.mapID,
        x = popup.x,
        y = popup.y,
        icon = icon,
        type = entryType,
        id = id,
        isUserAdded = true,
    }

    if not BOLTDB then BOLTDB = {} end
    if not BOLTDB.teleports then BOLTDB.teleports = {} end
    table.insert(BOLTDB.teleports, entry)

    BOLT:Print(string.format("Teleports: Added '%s' (ID: %d, Type: %s). Use /bolt export-teleports to export for your repo.", displayName, id, entryType))
    popup:Hide()
    self:RefreshPins()
end

-------------------------------------------------
-- Export (runtime teleports -> Lua for the data file)
-------------------------------------------------

function Teleports:ExportTeleports()
    if not BOLTDB or not BOLTDB.teleports or #BOLTDB.teleports == 0 then
        BOLT:Print("No runtime-added teleports to export.")
        return
    end

    BOLT:Print("--- Copy the lines below into Data/TeleportData.lua ---")
    for _, e in ipairs(BOLTDB.teleports) do
        local iconStr
        if type(e.icon) == "number" then
            iconStr = tostring(e.icon)
        else
            iconStr = string.format("%q", tostring(e.icon))
        end
        local line = string.format(
            '    { name = %q, mapID = %d, x = %.4f, y = %.4f, icon = %s, type = %q, id = %d },',
            e.name or "Unknown",
            e.mapID or 0,
            e.x or 0,
            e.y or 0,
            iconStr,
            e.type or "spell",
            e.id or 0
        )
        print(line)
    end
    BOLT:Print("--- End of export ---")
end

-------------------------------------------------
-- Module Lifecycle
-------------------------------------------------

function Teleports:OnInitialize()
    dataProvider = CreateFromMixins(BOLTTeleportDataProviderMixin)

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event)
            if event == "ZONE_CHANGED_NEW_AREA" and WorldMapFrame and WorldMapFrame:IsShown() then
                self:RefreshPins()
            end
        end)
    end
end

function Teleports:OnEnable()
    InitSecureButton()

    if eventFrame then
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end

    if WorldMapFrame and dataProvider then
        WorldMapFrame:AddDataProvider(dataProvider)
    end
end

function Teleports:OnDisable()
    if WorldMapFrame and dataProvider then
        WorldMapFrame:RemoveDataProvider(dataProvider)
    end
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

-------------------------------------------------
-- Global Functions (for keybinds)
-------------------------------------------------

function BOLT_AddTeleportLocation()
    if BOLT and BOLT.modules and BOLT.modules.teleports then
        BOLT.modules.teleports:ShowAddTeleportPopup()
    end
end

function BOLT_ToggleTeleportEditMode()
    if not BOLT then return end
    local cfg = BOLT:GetConfig("teleports") or {}
    local editMode = cfg.editMode or false
    BOLT:SetConfig(not editMode, "teleports", "editMode")
    BOLT:Print("Teleports Edit Mode: " .. (editMode and "OFF" or "ON"))
    if BOLT.modules.config and BOLT.modules.config.RefreshAll then
        BOLT.modules.config:RefreshAll()
    end
end
