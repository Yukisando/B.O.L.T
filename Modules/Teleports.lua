-- B.O.L.T Teleports Module
-- Shows teleport sources on the main world map

local ADDON_NAME, BOLT = ...

local Teleports = {}
BOLT:RegisterModule("teleports", Teleports)

local DEFAULT_ICON = "Interface\\Icons\\Spell_Arcane_TeleportDalaran"  -- Working teleport rune texture

-- Pin Template Mixin for WorldMap pins (modern approach)
BOLTTeleportPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BOLTTeleportPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

function BOLTTeleportPinMixin:OnAcquired()
    -- Set up the pin icon
    if not self.Icon then
        self.Icon = self:CreateTexture(nil, "ARTWORK")
        self.Icon:SetSize(24, 24)
        self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.Icon:SetDrawLayer("ARTWORK", 7)
    end
    
    if self.entry then
        local icon = self.entry.icon or DEFAULT_ICON
        -- Use SetTexture directly - simpler and more reliable
        self.Icon:SetTexture(icon)
        self.Icon:Show()
        self.Icon:SetVertexColor(1, 1, 1, 1)
    end
    
    -- Ensure the pin itself is visible and clickable
    self:SetSize(24, 24)
    self:Show()
    self:EnableMouse(true)
    self:SetMouseClickEnabled(true)
    self:SetAlpha(1.0)
end

function BOLTTeleportPinMixin:OnReleased()
    -- Clean up when pin is released back to pool
    self.entry = nil
    self.teleportsModule = nil
    if self.Icon then
        self.Icon:Hide()
    end
end

function BOLTTeleportPinMixin:OnMouseEnter()
    if not self.entry then return end
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    if self.entry.type == "item" and self.entry.id then
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.entry.id)
        else
            GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
            if self.entry.desc then
                GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
            end
        end
    elseif self.entry.type == "spell" and self.entry.id then
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self.entry.id)
        else
            GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
            if self.entry.desc then
                GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
            end
        end
    else
        GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
        if self.entry.desc then
            GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
        end
    end
    
    GameTooltip:Show()
end

function BOLTTeleportPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

function BOLTTeleportPinMixin:OnMouseClickAction(button)
    if not self.entry or not self.teleportsModule then return end
    
    if button == "RightButton" then
        -- Right-click to delete - only if edit mode is enabled
        local cfg = self.teleportsModule.parent:GetConfig("teleports") or {}
        if cfg.editMode then
            local combined = self.teleportsModule:GetTeleportList()
            for i, entry in ipairs(combined) do
                if entry == self.entry then
                    self.teleportsModule:DeleteTeleport(i)
                    return
                end
            end
        end
    elseif button == "LeftButton" then
        -- Left-click to teleport - always works regardless of edit mode
        local castName = self.entry.spellName or self.entry.name
        if not castName then return end
        
        if self.entry.type == "spell" then
            -- Use CastSpellByName for spell names
            CastSpellByName(castName)
        elseif self.entry.type == "toy" then
            if self.entry.id then
                C_ToyBox.PickupToyBoxItem(self.entry.id)
            end
        elseif self.entry.type == "item" then
            UseItemByName(castName)
        else
            -- Fallback - try casting by name
            CastSpellByName(castName)
        end
    end
end

local function SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

function Teleports:OnInitialize()
    -- Nothing heavy on init; data comes from saved profile defaults
    self:CreateDataProvider()
end

-- Get the combined list of default + user teleports
function Teleports:GetTeleportList()
    local defaultTeleports = BOLT.DefaultTeleports or {}
    local cfg = self.parent:GetConfig("teleports") or {}
    local userTeleports = cfg.userTeleportList or {}
    
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

-- Debug logging helper: only outputs when BOLT debug mode is enabled
function Teleports:Debug(msg)
    if not msg then return end
    if self.parent and self.parent.GetConfig and self.parent:GetConfig("debug") then
        if self.parent and type(self.parent.Debug) == "function" then
            self.parent:Debug("Teleports: " .. tostring(msg))
        end
    end
end

-- Create Data Provider for WorldMap pins (modern approach)
function Teleports:CreateDataProvider()
    if self.dataProvider then return end
    
    -- Create the data provider
    local provider = CreateFromMixins(MapCanvasDataProviderMixin)
    provider.teleportsModule = self
    
    function provider:OnAdded(mapCanvas)
        MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)
    end
    
    function provider:OnRemoved(mapCanvas)
        MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas)
    end
    
    function provider:RefreshAllData()
        if not self:GetMap() then 
            return 
        end
        self:GetMap():RemoveAllPinsByTemplate("BOLTTeleportPinTemplate")
        
        local teleportsModule = self.teleportsModule
        if not teleportsModule then 
            return 
        end
        
        -- Always show teleports on map (showOnMap removed)
        
        local currentMapID = self:GetMap():GetMapID()
        if not currentMapID then 
            return 
        end
        
        -- Use the combined list (defaults + user additions)
        local success, list = pcall(function()
            return teleportsModule:GetTeleportList()
        end)
        
        if not success or not list or type(list) ~= "table" then
            return
        end
        
        local pinCount = 0
        for i, entry in ipairs(list) do
            -- Inline the projection logic to avoid function call issues
            local projX, projY, canProject = nil, nil, false
            
            if entry and entry.mapID and entry.x and entry.y then
                -- Entry coordinates are already normalized (0-1)
                if entry.mapID == currentMapID then
                    -- Exact match
                    projX, projY, canProject = entry.x, entry.y, true
                elseif C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
                    -- Try to project to parent map
                    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(entry.mapID, CreateVector2D(entry.x, entry.y))
                    if continentID and worldPos then
                        local mapPos = C_Map.GetMapPosFromWorldPos(continentID, worldPos, currentMapID)
                        if mapPos then
                            local px, py = mapPos:GetXY()
                            if px and py and px >= 0 and px <= 1 and py >= 0 and py <= 1 then
                                projX, projY, canProject = px, py, true
                            end
                        end
                    end
                end
            end
            
            if canProject and projX and projY then
                local pin = self:GetMap():AcquirePin("BOLTTeleportPinTemplate")
                if pin then
                    pin.entry = entry
                    pin.teleportsModule = teleportsModule
                    pin:SetPosition(projX, projY)
                    pin:Show()
                    pin:EnableMouse(true)
                    pin:SetAlpha(1.0)
                    pinCount = pinCount + 1
                end
            end
        end
    end
    
    function provider:RemoveAllData()
        if self:GetMap() then
            self:GetMap():RemoveAllPinsByTemplate("BOLTTeleportPinTemplate")
        end
    end
    
    self.dataProvider = provider
end

function Teleports:SetupMouseClickHandler()
    -- No custom mouse handler needed - use keybind from Bindings.xml instead
end

-- Project coordinates from entry's mapID to the currently displayed map.
-- Returns (x, y, true) if successful, or (nil, nil, false) if the entry isn't visible on currentMapID.
local function ProjectToCurrentMap(entry, currentMapID)
    if not entry or not currentMapID then return nil, nil, false end
    local entryMapID = entry.mapID
    local entryX = entry.x or 0.5
    local entryY = entry.y or 0.5

    -- If entry has no mapID, treat as "show anywhere" at given coords
    if not entryMapID then
        return entryX, entryY, true
    end

    -- Exact match: use coords directly
    if entryMapID == currentMapID then
        return entryX, entryY, true
    end

    -- Try to project via world coordinates
    if C_Map and C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos then
        -- Convert entry's map-relative coords to world position
        local continentID, worldPos = SafeCall(C_Map.GetWorldPosFromMapPos, entryMapID, CreateVector2D(entryX, entryY))
        if continentID and worldPos then
            -- Now convert world position back to the current map's coordinates
            local mapPos = SafeCall(C_Map.GetMapPosFromWorldPos, continentID, worldPos, currentMapID)
            if mapPos then
                local projX, projY = mapPos:GetXY()
                -- Only valid if within [0,1] range (i.e., visible on current map)
                if projX and projY and projX >= 0 and projX <= 1 and projY >= 0 and projY <= 1 then
                    return projX, projY, true
                end
            end
        end
    end

    return nil, nil, false
end

function Teleports:RefreshPins()
    -- Modern approach: just refresh the data provider
    if self.dataProvider and WorldMapFrame then
        self.dataProvider:RefreshAllData()
    end
end

function Teleports:UpdateMapDisplay()
    -- Called by settings UI to refresh immediately
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshPins()
    end
end

function Teleports:OnEnable()
    if not self.parent:GetConfig("teleports", "enabled") then
        return
    end
    
    -- Set default keybindings if not already set
    local key1, key2 = GetBindingKey("BOLT_ADD_TELEPORT")
    if not key1 and not key2 then
        -- Note: The actual Ctrl+Alt+Right-Click is handled by the mouse handler
        -- This keybind is for those who want to use keyboard shortcut instead
        -- We don't set a default keyboard binding to avoid conflicts
    end
    
    -- Setup Ctrl+Alt+Right-Click mouse handler for adding teleports
    self:SetupMouseClickHandler()

    -- Add the data provider to the WorldMap
    if WorldMapFrame and self.dataProvider then
        WorldMapFrame:AddDataProvider(self.dataProvider)
    end

    -- Event-driven refresh
    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("PLAYER_LOGIN")
        ef:RegisterEvent("PLAYER_ENTERING_WORLD")
        ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        ef:SetScript("OnEvent", function(_, event, ...)
            if WorldMapFrame and WorldMapFrame:IsShown() then
                self:RefreshPins()
            end
        end)
        self.eventFrame = ef
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            self:RefreshPins()
        end)
    end

    -- Refresh now in case map is already open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshPins()
    end
end

function Teleports:OnDisable()
    if self.mouseHandler then 
        self.mouseHandler:Hide()
        self.mouseHandler = nil
    end
    
    -- Remove data provider from WorldMap
    if WorldMapFrame and self.dataProvider and WorldMapFrame.dataProviders then
        WorldMapFrame:RemoveDataProvider(self.dataProvider)
    end
    
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
end

-- Small utility to dump internal state for debugging (only outputs when debug enabled)
function Teleports:Dump()
    local t = self
    if not t then return end
    local cfg = (self.parent and self.parent.GetConfig) and self.parent:GetConfig("teleports") or {}
    self:Debug(
        "Dump: enabled=" ..
        tostring((self.parent and self.parent:IsModuleEnabled("teleports"))) ..
        " showOnMap=" .. tostring(cfg.showOnMap) ..
        " dataProvider=" .. tostring(self.dataProvider ~= nil))
end

-------------------------------------------------
-- Teleport Location Add Popup
-------------------------------------------------

function Teleports:ShowAddTeleportPopup()
    -- Check if edit mode is enabled
    local cfg = self.parent:GetConfig("teleports") or {}
    if not cfg.editMode then
        return  -- Edit mode is disabled, don't show popup
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
    self.addPopup.spellNameInput:SetText("")
    self.addPopup.idInput:SetText("")
    self.addPopup.selectedType = "spell"
    UIDropDownMenu_SetText(self.addPopup.typeDropdown, "Spell")

    self.addPopup:Show()
    self.addPopup.nameInput:SetFocus()
end

function Teleports:CreateAddTeleportPopup()
    local popup = CreateFrame("Frame", "BOLTAddTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(420, 280)
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

    -- Display name input (for the pin label)
    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 25, -70)
    nameLabel:SetText("Name (required):")

    local nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameInput:SetSize(230, 20)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(100)
    popup.nameInput = nameInput

    -- Spell/Item/Toy Name input (macro-style, e.g. "Teleport: Stormwind")
    local spellNameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellNameLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -20)
    spellNameLabel:SetText("Spell/Item Name (optional):")

    local spellNameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    spellNameInput:SetPoint("LEFT", spellNameLabel, "RIGHT", 10, 0)
    spellNameInput:SetSize(200, 20)
    spellNameInput:SetAutoFocus(false)
    spellNameInput:SetMaxLetters(100)
    popup.spellNameInput = spellNameInput

    -- Type dropdown (spell, item, toy)
    local typeLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", spellNameLabel, "BOTTOMLEFT", 0, -20)
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

    -- Optional ID input (for icon lookup)
    local idLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -25)
    idLabel:SetText("ID (optional):")

    local idInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    idInput:SetPoint("LEFT", idLabel, "RIGHT", 10, 0)
    idInput:SetSize(100, 20)
    idInput:SetAutoFocus(false)
    idInput:SetNumeric(true)
    popup.idInput = idInput

    -- Help text
    local helpText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    helpText:SetPoint("TOPLEFT", idLabel, "BOTTOMLEFT", 0, -10)
    helpText:SetWidth(350)
    helpText:SetJustifyH("LEFT")
    helpText:SetText("|cFFAAAAAATip: Use Ctrl+Alt+Right-Click on the map to add teleports.\nOnly name is required. Add spell/item name if you want it clickable.|r")

    -- Save button
    local saveBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    saveBtn:SetSize(100, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOM", -10, 20)
    saveBtn:SetText("Save")
    saveBtn:SetScript("OnClick", function()
        self:SaveTeleportFromPopup()
    end)
    popup.saveButton = saveBtn

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
    tinsert(UISpecialFrames, "BOLTAddTeleportPopup")

    self.addPopup = popup
end

function Teleports:SaveTeleportFromPopup()
    local popup = self.addPopup
    if not popup then return end

    local displayName = popup.nameInput:GetText()
    local spellName = popup.spellNameInput:GetText()
    local entryType = popup.selectedType or "spell"
    local idText = popup.idInput:GetText()
    local id = tonumber(idText)

    -- Only require display name
    if not displayName or displayName == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a name.")
        end
        return
    end
    
    -- Use display name as spell name if not provided
    if not spellName or spellName == "" then
        spellName = displayName
    end

    -- Try to get icon from ID if provided, otherwise use a default based on type
    local icon = "Interface\\Icons\\INV_Misc_Rune_01" ---@type string|number

    if id then
        if entryType == "spell" then
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
            if spellInfo and spellInfo.iconID then
                icon = spellInfo.iconID
            end
        elseif entryType == "toy" then
            if C_ToyBox and C_ToyBox.GetToyInfo then
                local toyItemID, toyName, toyIcon = C_ToyBox.GetToyInfo(id)
                if toyIcon then
                    icon = toyIcon
                end
            end
        elseif entryType == "item" then
            local itemName, _, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
            if itemIcon then
                icon = itemIcon
            end
        end
    else
        -- Default icons by type
        if entryType == "spell" then
            icon = "Interface\\Icons\\Spell_Arcane_TeleportStormwind"
        elseif entryType == "toy" then
            icon = "Interface\\Icons\\INV_Misc_Toy_07"
        elseif entryType == "item" then
            icon = "Interface\\Icons\\INV_Misc_Rune_01"
        end
    end

    -- Create the entry - store spellName for macro-style casting
    local entry = {
        name = displayName,
        spellName = spellName,  -- The actual name to cast (e.g. "Teleport: Stormwind")
        mapID = popup.mapID,
        x = popup.x,
        y = popup.y,
        icon = icon,
        type = entryType,
        id = id,  -- Optional, for tooltip/icon lookup
        isUserAdded = true  -- Mark as user-added
    }

    -- Get current user list and add the entry
    local cfg = self.parent:GetConfig("teleports") or {}
    local list = cfg.userTeleportList or {}
    table.insert(list, entry)

    -- Save back to config (only user additions, not defaults)
    self.parent:SetConfig(list, "teleports", "userTeleportList")

    if self.parent and self.parent.Print then
        self.parent:Print(string.format("Teleports: Added '%s' (%s) at map %d (%.1f%%, %.1f%%)", displayName, spellName, popup.mapID, popup.x * 100, popup.y * 100))
    end

    popup:Hide()
    
    -- Force immediate refresh
    self:RefreshPins()
    print("BOLT: Teleport added. Total teleports: " .. #list .. ". Refreshing map...")
end

-- Delete a teleport entry by index
function Teleports:DeleteTeleport(index)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end
    
    local entry = combined[index]
    
    -- Remove from the combined list regardless of whether it's user-added or default
    table.remove(combined, index)
    
    -- Now rebuild both lists from the modified combined list
    local defaultTeleports = BOLT.DefaultTeleports or {}
    local newUserList = {}
    
    -- Anything not in defaults goes to user list
    for _, e in ipairs(combined) do
        local isDefault = false
        for _, d in ipairs(defaultTeleports) do
            if d == e then
                isDefault = true
                break
            end
        end
        if not isDefault then
            table.insert(newUserList, e)
        end
    end
    
    -- Save the updated user list
    self.parent:SetConfig(newUserList, "teleports", "userTeleportList")
    if self.parent and self.parent.Print then
        self.parent:Print("Teleports: Removed '" .. tostring(entry.name) .. "'")
    end
    self:RefreshPins()
end

-- Update an existing teleport entry
function Teleports:UpdateTeleport(index, newData)
    local combined = self:GetTeleportList()
    if index <= 0 or index > #combined then return end
    
    local entry = combined[index]
    if entry.isUserAdded then
        -- Find and update in user list
        local cfg = self.parent:GetConfig("teleports") or {}
        local userList = cfg.userTeleportList or {}
        for i, userEntry in ipairs(userList) do
            if userEntry == entry then
                for k, v in pairs(newData) do
                    userList[i][k] = v
                end
                self.parent:SetConfig(userList, "teleports", "userTeleportList")
                self:RefreshPins()
                return
            end
        end
    else
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Cannot edit default teleport. Only user-added pins can be edited.")
        end
    end
end

-- Global function for keybind
function BOLT_AddTeleportLocation()
    if BOLT and BOLT.modules and BOLT.modules.teleports then
        BOLT.modules.teleports:ShowAddTeleportPopup()
    end
end

-- Global function for toggling edit mode
function BOLT_ToggleTeleportEditMode()
    if BOLT and BOLT.modules and BOLT.modules.teleports then
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

-- Clean up when player logs out/reloads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function() Teleports:OnDisable() end)

return Teleports
