-- B.O.L.T Teleports Module
-- Shows teleport sources on the main world map

local ADDON_NAME, BOLT = ...

local Teleports = {}
BOLT:RegisterModule("teleports", Teleports)

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Rune_01"

local function SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

function Teleports:OnInitialize()
    -- Nothing heavy on init; data comes from saved profile defaults
    self.pinPool = {}
    self.pinsShown = {}
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

function Teleports:CreateContainer()
    if self.container then return end
    local parent = nil
    -- Prefer the Map ScrollContainer (modern UI), fall back to WorldMapFrame canvas or the frame itself
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvas then
        parent = WorldMapFrame.ScrollContainer:GetCanvas() -- anchor directly to the canvas for correct scaling and zoom behavior
    elseif WorldMapFrame and WorldMapFrame.GetCanvas then
        parent = WorldMapFrame:GetCanvas()
    elseif WorldMapFrame then
        parent = WorldMapFrame
    else
        parent = UIParent
    end

    local c = CreateFrame("Frame", "BOLTTeleportMapOverlay", parent)
    c:SetAllPoints(parent)
    c:SetFrameStrata("MEDIUM")
    c:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
    c:SetScale(1)
    c:EnableMouse(false) -- Don't block mouse events for native map pins
    c:Hide()
    self.container = c

    -- Hook parent size changes in case canvas is not initialized immediately
    if parent and type(parent.HookScript) == "function" then
        parent:HookScript("OnSizeChanged", function()
            C_Timer.After(0.01, function()
                if self and self.RefreshPins then
                    self:RefreshPins()
                end
            end)
        end)
    end

    -- Create "Add Teleport" button anchored to World Map (bottom right)
    self:CreateAddTeleportButton()
end

function Teleports:CreateAddTeleportButton()
    if self.addButton then return end

    local btn = CreateFrame("Button", "BOLTAddTeleportMapButton", WorldMapFrame, "UIPanelButtonTemplate")
    btn:SetSize(140, 22)
    btn:SetPoint("BOTTOMRIGHT", WorldMapFrame, "BOTTOMRIGHT", -60, 30)
    btn:SetText("Add Teleport Here")
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(1000)
    btn:SetScript("OnClick", function()
        self:ShowAddTeleportPopup()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Add Teleport Location")
        GameTooltip:AddLine("Click to save a teleport at your cursor position.", 1, 1, 1, true)
        GameTooltip:AddLine("You can also use a keybind (set in Key Bindings).", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.addButton = btn
end

local function AcquirePin(self)
    for _, p in ipairs(self.pinPool) do
        if not p._inUse then
            p._inUse = true
            p:Show()
            return p
        end
    end
    local btn = CreateFrame("Button", nil, self.container, "SecureActionButtonTemplate")
    btn:SetSize(22, 22)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexCoord(0, 1, 0, 1)

    -- subtle border/background to improve visibility against map textures
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.bg:SetSize(22, 22)
    btn.bg:SetColorTexture(0, 0, 0, 0.6)

    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn._inUse = true
    table.insert(self.pinPool, btn)

    -- Ensure pin is visible above underlying map layers
    if self.container then
        btn:SetFrameLevel(self.container:GetFrameLevel() + 10)
    end

    btn:SetScript("OnEnter", function(b)
        local entry = b._entry
        if not entry then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        if entry.type == "item" and entry.id then
            if GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(entry.id)
            else
                local name = entry.name or (entry.id and GetItemInfo(entry.id)) or "Unknown"
                GameTooltip:SetText(name)
            end
        elseif entry.type == "spell" and entry.id then
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(entry.id)
            else
                GameTooltip:SetText(entry.name or "Spell")
            end
        else
            GameTooltip:SetText(entry.name or "Teleport")
            if entry.desc then GameTooltip:AddLine(entry.desc, 1, 1, 1) end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Register for clicks to use secure attributes
    btn:RegisterForClicks("AnyUp", "AnyDown")

    return btn
end

local function ReleaseAllPins(self)
    local count = 0
    for _, p in ipairs(self.pinPool) do
        if p._inUse then count = count + 1 end
        p._inUse = false
        p:Hide()
    end
    self.pinsShown = {}
    if self.parent and self.parent.Debug then
        self.parent:Debug("Teleports: released " .. tostring(count) .. " pins")
    end
end

local function CheckOwned(entry)
    if not entry then return false end
    if entry.type == "item" and entry.id then
        local count = GetItemCount(entry.id) or 0
        return count > 0
    elseif entry.type == "spell" and entry.id then
        if IsSpellKnown then
            return IsSpellKnown(entry.id)
        else
            -- Best effort: try GetSpellInfo
            local name = entry.spellName or entry.name
            return name and IsSpellKnown(name)
        end
    end
    return true
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
    if not self.container then self:CreateContainer() end
    if not self.container then return end

    ReleaseAllPins(self)

    local cfg = self.parent:GetConfig("teleports") or {}
    if not cfg or not cfg.showOnMap then
        return
    end

    -- Determine current map ID of the displayed world map
    local currentMapID = nil
    if WorldMapFrame and WorldMapFrame.GetMapID then
        currentMapID = SafeCall(WorldMapFrame.GetMapID, WorldMapFrame)
    end
    if not currentMapID and C_Map and C_Map.GetBestMapForUnit then
        currentMapID = C_Map.GetBestMapForUnit("player")
    end

    local list = cfg.teleportList or {}
    -- If saved list is empty, nothing to show
    if not list or not next(list) then
        self:Debug("RefreshPins: No teleports in list")
        return
    end
    
    self:Debug("RefreshPins: Found " .. #list .. " teleport(s), currentMapID=" .. tostring(currentMapID))

    -- Determine canvas dimensions with robust fallbacks
    local canvas = self.container
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    if (not w or w == 0) and canvas:GetParent() then w = canvas:GetParent():GetWidth() end
    if (not h or h == 0) and canvas:GetParent() then h = canvas:GetParent():GetHeight() end
    if not w or w == 0 then w = UIParent:GetWidth() or 1024 end
    if not h or h == 0 then h = UIParent:GetHeight() or 768 end

    -- If the container is hidden for any reason, show it while placing pins
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    end

    -- If the canvas has zero size, schedule a few retries (sometimes the map canvas isn't ready instantly)
    self._refreshAttempts = (self._refreshAttempts or 0) + 1
    if (not w or w == 0 or not h or h == 0) and (self._refreshAttempts or 0) < 6 then
        C_Timer.After(0.05, function()
            if self and self.RefreshPins then self:RefreshPins() end
        end)
        return
    end

    local placed = 0
    for _, entry in ipairs(list) do
        local debugBypass = false
        if self.parent and self.parent.GetConfig then
            debugBypass = self.parent:GetConfig("debug") or false
        end

        local showAny = cfg.showOnAnyMap or false

        -- Try to project entry coordinates onto the current map
        local projX, projY, canProject = ProjectToCurrentMap(entry, currentMapID)

        -- Determine if we should show this pin
        local mapMatch = debugBypass or canProject
        -- If showAnyMap is enabled and we couldn't project, use raw coords
        if showAny and not canProject then
            projX = entry.x or 0.5
            projY = entry.y or 0.5
            mapMatch = true
        end
        local owned = (not cfg.showOnlyOwned) or CheckOwned(entry)

        self:Debug(string.format("Entry '%s': mapMatch=%s, owned=%s, canProject=%s", 
            entry.name or "?", tostring(mapMatch), tostring(owned), tostring(canProject)))

        if entry and mapMatch then
            if owned then
                local p = AcquirePin(self)
                if not p then
                    break
                end
                p._entry = entry
                local icon = entry.icon or DEFAULT_ICON
                p.icon:SetTexture(icon)
                p:SetSize(20, 20)
                p.bg:SetSize(20, 20)

                -- Set up secure action button attributes based on entry type
                -- This allows clicking to cast spells / use items / toys like macros
                local castName = entry.spellName or entry.name
                if entry.type == "spell" then
                    p:SetAttribute("type", "spell")
                    p:SetAttribute("spell", castName)
                elseif entry.type == "toy" then
                    p:SetAttribute("type", "toy")
                    p:SetAttribute("toy", castName)
                elseif entry.type == "item" then
                    p:SetAttribute("type", "item")
                    p:SetAttribute("item", castName)
                else
                    -- Fallback to macro for flexibility
                    p:SetAttribute("type", "macro")
                    p:SetAttribute("macrotext", "/cast " .. castName)
                end

                local px, py = nil, nil
                -- Use projected coordinates for placement
                if w and h and w > 0 and h > 0 then
                    px = (projX or 0.5) * w
                    -- Y coordinate: WoW map coords have origin at top-left, so no inversion needed
                    py = (projY or 0.5) * h
                else
                    -- fallback: place in center (visible) and mark for retry
                    px = (projX or 0.5) * (UIParent:GetWidth() or 1024)
                    py = (projY or 0.5) * (UIParent:GetHeight() or 768)
                end

                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", canvas, "TOPLEFT", px - (p:GetWidth() / 2), -py + (p:GetHeight() / 2))
                p:Show()
                placed = placed + 1
            end
        end
    end

    -- Ensure container visible while World Map is open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    end

    -- Keep container visible while the World Map is open; otherwise hide it
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    else
        canvas:Hide()
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
    self:CreateContainer()

    -- Show the add button if it exists
    if self.addButton then
        self.addButton:Show()
    end

    -- Event-driven refresh (robust across UI versions)
    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("PLAYER_LOGIN")
        ef:RegisterEvent("PLAYER_ENTERING_WORLD")
        -- WORLD_MAP_UPDATE is not a valid event in some clients; remove to avoid spam
        ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        ef:RegisterEvent("BAG_UPDATE")
        ef:RegisterEvent("SPELLS_CHANGED")
        ef:RegisterEvent("TOYS_UPDATED")
        ef:SetScript("OnEvent", function(_, event, ...)
            -- Only refresh map pins when the main map is visible or on login
            if WorldMapFrame and WorldMapFrame:IsShown() then
                if self.container then self.container:Show() end
                self:RefreshPins()
            end
            if event == "PLAYER_LOGIN" then
                self:RefreshPins()
            end
        end)
        self.eventFrame = ef
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            if self.container then self.container:Show() end
            if self.addButton then self.addButton:Show() end
            self:RefreshPins()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            if self.container then self.container:Hide() end
            ReleaseAllPins(self)
        end)
    end

    -- Refresh now in case map is already open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if self.container then self.container:Show() end
        self:RefreshPins()
    end
end

function Teleports:OnDisable()
    if self.container then self.container:Hide() end
    if self.addButton then self.addButton:Hide() end
    ReleaseAllPins(self)
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
    local poolsize = t.pinPool and #t.pinPool or 0
    local cfg = (self.parent and self.parent.GetConfig) and self.parent:GetConfig("teleports") or {}
    self:Debug(
        "Dump: enabled=" ..
        tostring((self.parent and self.parent:IsModuleEnabled("teleports"))) ..
        " showOnMap=" .. tostring(cfg.showOnMap) .. " pool=" .. tostring(poolsize))
    if self.container then
        self:Debug(
            "Container shown=" ..
            tostring(self.container:IsShown()) ..
            " size=" .. tostring(self.container:GetWidth()) .. "x" .. tostring(self.container:GetHeight()))
    end
end

-------------------------------------------------
-- Teleport Location Add Popup
-------------------------------------------------

function Teleports:ShowAddTeleportPopup()
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Open the World Map first to add a teleport at your cursor location.")
        end
        return
    end

    if not self.addPopup then
        self:CreateAddTeleportPopup()
    end

    -- Get current map info
    local mapID = WorldMapFrame:GetMapID()
    
    -- Try to get cursor position on the map canvas
    local cursorX, cursorY = 0.5, 0.5
    if WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition then
        local cx, cy = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
        if cx and cy and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
            cursorX, cursorY = cx, cy
        end
    elseif WorldMapFrame.GetNormalizedCursorPosition then
        local cx, cy = WorldMapFrame:GetNormalizedCursorPosition()
        if cx and cy and cx >= 0 and cx <= 1 and cy >= 0 and cy <= 1 then
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
    title:SetText("Add Teleport Location")

    -- Map info label
    local mapLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapLabel:SetPoint("TOP", title, "BOTTOM", 0, -10)
    mapLabel:SetText("Map: Unknown")
    popup.mapLabel = mapLabel

    -- Display name input (for the pin label)
    local nameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 25, -70)
    nameLabel:SetText("Display Name:")

    local nameInput = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    nameInput:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameInput:SetSize(230, 20)
    nameInput:SetAutoFocus(false)
    nameInput:SetMaxLetters(100)
    popup.nameInput = nameInput

    -- Spell/Item/Toy Name input (macro-style, e.g. "Teleport: Stormwind")
    local spellNameLabel = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellNameLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -20)
    spellNameLabel:SetText("Spell/Item/Toy Name:")

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
    helpText:SetText("|cFFAAAAAATip: Use exact spell/item/toy names like macros.\nExamples: 'Teleport: Stormwind', 'Hearthstone', 'Dalaran Hearthstone'|r")

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

    -- Require at least display name and spell/item name
    if not displayName or displayName == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a display name.")
        end
        return
    end
    if not spellName or spellName == "" then
        if self.parent and self.parent.Print then
            self.parent:Print("Teleports: Please enter a spell/item/toy name (e.g. 'Teleport: Stormwind').")
        end
        return
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
        id = id  -- Optional, for tooltip/icon lookup
    }

    -- Get current list and add the entry
    local cfg = self.parent:GetConfig("teleports") or {}
    local list = cfg.teleportList or {}
    table.insert(list, entry)

    -- Save back to config
    self.parent:SetConfig(list, "teleports", "teleportList")

    if self.parent and self.parent.Print then
        self.parent:Print(string.format("Teleports: Added '%s' (%s) at map %d (%.1f%%, %.1f%%)", displayName, spellName, popup.mapID, popup.x * 100, popup.y * 100))
    end

    popup:Hide()
    self:RefreshPins()
end

-- Delete a teleport entry by index
function Teleports:DeleteTeleport(index)
    local cfg = self.parent:GetConfig("teleports") or {}
    local list = cfg.teleportList or {}
    if index > 0 and index <= #list then
        local removed = table.remove(list, index)
        self.parent:SetConfig(list, "teleports", "teleportList")
        if self.parent and self.parent.Print and removed then
            self.parent:Print("Teleports: Removed '" .. tostring(removed.name) .. "'")
        end
        self:RefreshPins()
    end
end

-- Update an existing teleport entry
function Teleports:UpdateTeleport(index, newData)
    local cfg = self.parent:GetConfig("teleports") or {}
    local list = cfg.teleportList or {}
    if index > 0 and index <= #list then
        for k, v in pairs(newData) do
            list[index][k] = v
        end
        self.parent:SetConfig(list, "teleports", "teleportList")
        self:RefreshPins()
    end
end

-- Get all teleport entries
function Teleports:GetTeleportList()
    local cfg = self.parent:GetConfig("teleports") or {}
    return cfg.teleportList or {}
end

-- Global function for keybind
function BOLT_AddTeleportLocation()
    if BOLT and BOLT.modules and BOLT.modules.teleports then
        BOLT.modules.teleports:ShowAddTeleportPopup()
    end
end

-- Clean up when player logs out/reloads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function() Teleports:OnDisable() end)

return Teleports
