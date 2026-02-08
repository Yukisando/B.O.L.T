-- B.O.L.T Teleports Module (Main Entry Point)
-- Data management, events, and coordination
-- Follows 12.0 architecture: data here, pins in PinMixin, secure in SecureUI

local ADDON_NAME, BOLT = ...

local Teleports = {}
BOLT:RegisterModule("teleports", Teleports)

-- Data provider instance (created in OnInitialize)
local dataProvider = nil

-- Event frame for map events
local eventFrame = nil

-------------------------------------------------
-- Coordinate Projection
-------------------------------------------------

local function SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

-- Project coordinates from entry's mapID to the specified map
-- Returns (x, y, true) if successful, or (nil, nil, false) if not visible
function Teleports:ProjectToMap(entry, targetMapID)
    if not entry or not targetMapID then return nil, nil, false end
    
    local entryMapID = entry.mapID
    local entryX = entry.x or 0.5
    local entryY = entry.y or 0.5

    -- If entry has no mapID, treat as "show anywhere" at given coords
    if not entryMapID then
        return entryX, entryY, true
    end

    -- Exact match: use coords directly
    if entryMapID == targetMapID then
        return entryX, entryY, true
    end

    -- Try to project via world coordinates
    if C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
        -- Convert entry's map-relative coords to world position
        local continentID, worldPos = SafeCall(C_Map.GetWorldPosFromMapPos, entryMapID, CreateVector2D(entryX, entryY))
        if continentID and worldPos then
            -- Now convert world position back to the target map's coordinates
            local mapPos = SafeCall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, targetMapID)
            if mapPos then
                local projX, projY = mapPos:GetXY()
                -- Only valid if within [0,1] range (visible on target map)
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

-- Get the combined list of default + user teleports
function Teleports:GetTeleportList()
    local defaultTeleports = BOLT.DefaultTeleports or {}
    
    -- Use global storage for account-wide teleports
    if not BOLTDB then BOLTDB = {} end
    if not BOLTDB.teleports then
        BOLTDB.teleports = {}
    end
    local userTeleports = BOLTDB.teleports or {}
    
    -- Merge both lists (defaults first, then user additions)
    local combined = {}
    for _, entry in ipairs(defaultTeleports) do
        table.insert(combined, entry)
    end
    for _, entry in ipairs(userTeleports) do
        table.insert(combined, entry)
    end
    
    return combined
end

-- Delete a teleport entry by index
function Teleports:DeleteTeleport(index)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end
    
    local entry = combined[index]
    
    -- Only allow deleting user-added teleports
    if not entry.isUserAdded then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Cannot delete default teleport.")
        end
        return
    end
    
    -- Find and remove from BOLTDB.teleports
    if BOLTDB.teleports then
        for i, e in ipairs(BOLTDB.teleports) do
            if e == entry then
                table.remove(BOLTDB.teleports, i)
                break
            end
        end
    end
    
    if self.parent and self.parent.Print then
        self.parent:Print("Teleports: Removed '" .. tostring(entry.name) .. "'")
    end
    
    -- Refresh pins immediately
    self:RefreshPins()
end

-- Update an existing teleport entry
function Teleports:UpdateTeleport(index, newData)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end
    
    local entry = combined[index]
    if not entry.isUserAdded then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Cannot edit default teleport.")
        end
        return
    end
    
    -- Find and update in BOLTDB.teleports
    if BOLTDB.teleports then
        for i, e in ipairs(BOLTDB.teleports) do
            if e == entry then
                for k, v in pairs(newData) do
                    BOLTDB.teleports[i][k] = v
                end
                -- Refresh pins immediately
                self:RefreshPins()
                return
            end
        end
    end
end

-------------------------------------------------
-- Debug Logging
-------------------------------------------------

function Teleports:Debug(msg)
    if not msg then return end
    if self.parent and self.parent.GetConfig and self.parent:GetConfig("debug") then
        if self.parent and type(self.parent.Debug) == "function" then
            self.parent:Debug("Teleports: " .. tostring(msg))
        end
    end
end

-------------------------------------------------
-- Pin Refresh (via Data Provider)
-------------------------------------------------

function Teleports:RefreshPins()
    if dataProvider then
        dataProvider:RefreshAllData()
    end
end

-- Called by settings UI to refresh immediately
function Teleports:UpdateMapDisplay()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshPins()
    end
end

-------------------------------------------------
-- Teleport Popup Interface (delegates to SecureUI)
-------------------------------------------------

-- Open the teleport confirmation popup
function Teleports:OpenTeleportPopup(entry)
    if not entry then return end
    
    -- Log the attempt
    if self.parent and self.parent.Print and self.parent:GetConfig("debug") then
        local entryName = entry.name or "Unknown"
        local entryType = entry.type or "unknown"
        local entryID = entry.id
        if entryID then
            self.parent:Print(string.format("Teleports: Opening popup for %s (ID: %d, Type: %s)", entryName, entryID, entryType))
        else
            self.parent:Print(string.format("Teleports: Opening popup for %s (Type: %s)", entryName, entryType))
        end
    end
    
    -- Delegate to SecureUI
    if BOLT.TeleportSecureUI then
        BOLT.TeleportSecureUI:ShowPopup(entry)
    end
end

-------------------------------------------------
-- Add Teleport Popup
-------------------------------------------------

function Teleports:ShowAddTeleportPopup()
    -- Check if edit mode is enabled
    local cfg = self.parent:GetConfig("teleports") or {}
    if not cfg.editMode then
        return  -- Edit mode is disabled
    end
    
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Open the World Map first.")
        end
        return
    end

    if not self.addPopup then
        self:CreateAddTeleportPopup()
    end

    -- Get current map info
    local mapID = WorldMapFrame:GetMapID()
    
    -- Get cursor position on the map (normalized 0-1)
    local cursorX, cursorY = 0.5, 0.5
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition then
        local cx, cy = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if cx and cy then
            cursorX, cursorY = cx, cy
        end
    end

    self.addPopup.mapID = mapID
    self.addPopup.x = cursorX
    self.addPopup.y = cursorY

    -- Update map info display
    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapName = mapInfo and mapInfo.name or ("Map " .. tostring(mapID))
    self.addPopup.mapLabel:SetText(string.format("Map: %s (%d) at %.1f%%, %.1f%%", mapName, mapID, cursorX * 100, cursorY * 100))

    -- Clear inputs
    self.addPopup.nameInput:SetText("")
    self.addPopup.idInput:SetText("")
    self.addPopup.selectedType = "spell"
    UIDropDownMenu_SetText(self.addPopup.typeDropdown, "Spell")

    self.addPopup:Show()
    -- Delay focus to prevent keybind letter from being captured in the input
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

    -- Title
    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -20)
    title:SetText("Add Teleport at Cursor")

    -- Map info label
    local mapLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapLabel:SetPoint("TOP", title, "BOTTOM", 0, -10)
    mapLabel:SetText("Map: Unknown")
    popup.mapLabel = mapLabel

    -- Display name input
    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 25, -70)
    nameLabel:SetText("Name (required):")

    local nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameInput:SetSize(230, 20)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(100)
    popup.nameInput = nameInput

    -- Type dropdown
    local typeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -25)
    typeLabel:SetText("Type:")

    local typeDropdown = CreateFrame("Frame", "BOLTTeleportTypeDropdown", popup, "UIDropDownMenuTemplate")
    typeDropdown:SetPoint("LEFT", typeLabel, "RIGHT", -10, -2)
    UIDropDownMenu_SetWidth(typeDropdown, 100)
    UIDropDownMenu_SetText(typeDropdown, "Spell")
    popup.typeDropdown = typeDropdown
    popup.selectedType = "spell"

    UIDropDownMenu_Initialize(typeDropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, t in ipairs({"spell", "item", "toy"}) do
            info.text = t:sub(1,1):upper() .. t:sub(2)
            info.value = t
            info.checked = (popup.selectedType == t)
            info.func = function()
                popup.selectedType = t
                UIDropDownMenu_SetText(typeDropdown, t:sub(1,1):upper() .. t:sub(2))
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- ID input
    local idLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -25)
    idLabel:SetText("ID (required):")

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
        self:SaveTeleportFromPopup()
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

    tinsert(UISpecialFrames, "BOLTAddTeleportPopup")

    self.addPopup = popup
end

function Teleports:SaveTeleportFromPopup()
    local popup = self.addPopup
    if not popup then return end

    local displayName = popup.nameInput:GetText()
    local entryType = popup.selectedType or "spell"
    local idText = popup.idInput:GetText()
    local id = tonumber(idText)

    -- Require both name and ID
    if not displayName or displayName == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a name.")
        end
        return
    end
    
    if not id then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a valid ID.")
        end
        return
    end

    -- Get icon from ID
    local icon = "Interface\\Icons\\INV_Misc_Rune_01"

    if entryType == "spell" then
        local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
        if spellInfo and spellInfo.iconID then
            icon = spellInfo.iconID
        elseif C_Spell and C_Spell.GetSpellTexture then
            local texture = C_Spell.GetSpellTexture(id)
            if texture then icon = texture end
        end
    elseif entryType == "toy" then
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local _, toyName, toyIcon = C_ToyBox.GetToyInfo(id)
            if toyIcon then icon = toyIcon end
        end
    elseif entryType == "item" then
        local itemIcon = C_Item.GetItemIconByID(id)
        if itemIcon then icon = itemIcon end
    end

    -- Create the entry
    local entry = {
        name = displayName,
        mapID = popup.mapID,
        x = popup.x,
        y = popup.y,
        icon = icon,
        type = entryType,
        id = id,
        isUserAdded = true
    }

    -- Save to global storage
    if not BOLTDB then BOLTDB = {} end
    if not BOLTDB.teleports then
        BOLTDB.teleports = {}
    end
    table.insert(BOLTDB.teleports, entry)

    if self.parent and self.parent.Print then
        self.parent:Print(string.format("Teleports: Added '%s' (ID: %d, Type: %s)", displayName, id, entryType))
    end

    popup:Hide()
    
    -- Refresh pins immediately
    self:RefreshPins()
end

-------------------------------------------------
-- Module Lifecycle
-------------------------------------------------

function Teleports:OnInitialize()
    -- Create the data provider (will be added to map in OnEnable)
    dataProvider = BOLT:CreateTeleportDataProvider()
    
    -- Create event frame for map events
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "ZONE_CHANGED_NEW_AREA" then
                if WorldMapFrame and WorldMapFrame:IsShown() then
                    self:RefreshPins()
                end
            end
        end)
    end
end

function Teleports:OnEnable()
    -- Initialize secure UI (must be done out of combat)
    if BOLT.TeleportSecureUI then
        BOLT.TeleportSecureUI:Initialize()
    end
    
    -- Register events
    if eventFrame then
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    end
    
    -- Add data provider to WorldMap
    if WorldMapFrame and dataProvider then
        WorldMapFrame:AddDataProvider(dataProvider)
    end
end

function Teleports:OnDisable()
    -- Remove data provider from WorldMap
    if WorldMapFrame and dataProvider then
        WorldMapFrame:RemoveDataProvider(dataProvider)
    end
    
    -- Unregister events
    if eventFrame then
        eventFrame:UnregisterAllEvents()
    end
end

-- Debug dump
function Teleports:Dump()
    local cfg = (self.parent and self.parent.GetConfig) and self.parent:GetConfig("teleports") or {}
    self:Debug(
        "Dump: enabled=" ..
        tostring((self.parent and self.parent:IsModuleEnabled("teleports"))) ..
        " showOnMap=" .. tostring(cfg.showOnMap) ..
        " dataProvider=" .. tostring(dataProvider ~= nil))
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
    if BOLT then
        local cfg = BOLT:GetConfig("teleports") or {}
        local editMode = cfg.editMode or false
        BOLT:SetConfig(not editMode, "teleports", "editMode")
        if BOLT.Print then
            BOLT:Print("Teleports Edit Mode: " .. (editMode and "OFF" or "ON"))
        end
        -- Refresh config UI if it exists
        if BOLT.modules.config and BOLT.modules.config.RefreshAll then
            BOLT.modules.config:RefreshAll()
        end
    end
end

-------------------------------------------------
-- Cleanup on logout
-------------------------------------------------

local cleanupFrame = CreateFrame("Frame")
cleanupFrame:RegisterEvent("PLAYER_LOGOUT")
cleanupFrame:SetScript("OnEvent", function()
    if Teleports.OnDisable then
        Teleports:OnDisable()
    end
end)

return Teleports
