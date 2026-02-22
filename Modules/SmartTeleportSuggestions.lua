-- B.O.L.T Smart Teleport Suggestions Module
-- Shows context-relevant teleports the player owns when viewing the World Map

local ADDON_NAME, BOLT = ...

local SmartTeleport = {}

-- ────────────────────────────────────────────────────────────────────────────
-- Static teleport dataset
-- Each entry: name, mapID (destination zone), x/y (normalised 0-1),
--             spellIDs = {}, itemIDs = {}
-- ────────────────────────────────────────────────────────────────────────────
SmartTeleport.TeleportData = {
    -- ── Alliance Capitals ──────────────────────────────────────────────
    { name = "Stormwind",         mapID = 84,   x = 0.49, y = 0.87, spellIDs = {3561, 10059},  itemIDs = {} },
    { name = "Ironforge",         mapID = 87,   x = 0.47, y = 0.86, spellIDs = {3562, 11416},  itemIDs = {} },
    { name = "Darnassus",         mapID = 89,   x = 0.44, y = 0.78, spellIDs = {3565, 11419},  itemIDs = {} },
    { name = "Exodar",            mapID = 103,  x = 0.48, y = 0.63, spellIDs = {32271, 32266}, itemIDs = {} },

    -- ── Horde Capitals ─────────────────────────────────────────────────
    { name = "Orgrimmar",         mapID = 85,   x = 0.45, y = 0.63, spellIDs = {3567, 11417},  itemIDs = {} },
    { name = "Thunder Bluff",     mapID = 88,   x = 0.47, y = 0.49, spellIDs = {3566, 11420},  itemIDs = {} },
    { name = "Undercity",         mapID = 90,   x = 0.66, y = 0.38, spellIDs = {3563, 11418},  itemIDs = {} },
    { name = "Silvermoon",        mapID = 110,  x = 0.58, y = 0.19, spellIDs = {32272, 32267}, itemIDs = {} },

    -- ── Neutral / Expansion Hubs ───────────────────────────────────────
    { name = "Shattrath",         mapID = 111,  x = 0.51, y = 0.42, spellIDs = {33690, 35715}, itemIDs = {} },
    { name = "Dalaran (Northrend)", mapID = 125, x = 0.50, y = 0.50, spellIDs = {53140, 53142}, itemIDs = {} },
    { name = "Dalaran (Broken Isles)", mapID = 627, x = 0.50, y = 0.50, spellIDs = {224869, 224871}, itemIDs = {} },
    { name = "Shrine of Two Moons",   mapID = 391, x = 0.74, y = 0.43, spellIDs = {132627},  itemIDs = {} },
    { name = "Shrine of Seven Stars",  mapID = 393, x = 0.85, y = 0.63, spellIDs = {132621},  itemIDs = {} },
    { name = "Warspear",          mapID = 624,  x = 0.52, y = 0.47, spellIDs = {176244},      itemIDs = {} },
    { name = "Stormshield",       mapID = 622,  x = 0.36, y = 0.50, spellIDs = {176248},      itemIDs = {} },
    { name = "Boralus",           mapID = 1161, x = 0.70, y = 0.15, spellIDs = {281403, 281400}, itemIDs = {} },
    { name = "Dazar'alor",        mapID = 1165, x = 0.40, y = 0.12, spellIDs = {281404, 281402}, itemIDs = {} },
    { name = "Oribos",            mapID = 1670, x = 0.50, y = 0.50, spellIDs = {344587},      itemIDs = {} },
    { name = "Valdrakken",        mapID = 2112, x = 0.58, y = 0.35, spellIDs = {395277},      itemIDs = {} },
    { name = "Dornogal",          mapID = 2339, x = 0.47, y = 0.60, spellIDs = {446540},      itemIDs = {} },

    -- ── Class / Special ────────────────────────────────────────────────
    { name = "Hall of the Guardian (Mage)", mapID = 735, x = 0.50, y = 0.50, spellIDs = {193759}, itemIDs = {} },
    { name = "Dreamwalk (Druid)",           mapID = 747, x = 0.50, y = 0.50, spellIDs = {193753}, itemIDs = {} },
    { name = "Death Gate (DK)",             mapID = 647, x = 0.50, y = 0.50, spellIDs = {50977},  itemIDs = {} },
    { name = "Zen Pilgrimage (Monk)",       mapID = 809, x = 0.50, y = 0.50, spellIDs = {126892}, itemIDs = {} },

    -- ── Engineering Wormholes ──────────────────────────────────────────
    { name = "Wormhole: Northrend",       mapID = 113,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {48933} },
    { name = "Wormhole: Pandaria",        mapID = 424,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {87215} },
    { name = "Wormhole: Draenor",         mapID = 572,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {112059} },
    { name = "Wormhole: Argus",           mapID = 905,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {151652} },
    { name = "Wormhole: Kul Tiras",       mapID = 876,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {168807} },
    { name = "Wormhole: Zandalar",        mapID = 875,  x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {168808} },
    { name = "Wormhole: Shadowlands",     mapID = 1550, x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {172924} },
    { name = "Wormhole: Dragon Isles",    mapID = 1978, x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {198156} },
    { name = "Wormhole: Khaz Algar",      mapID = 2274, x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {221966} },

    -- ── Hero's Path: MoP (Challenge Mode Gold) ───────────────────────
    { name = "Temple of the Jade Serpent",  mapID = 371,  x = 0.56, y = 0.58, spellIDs = {131204}, itemIDs = {} },
    { name = "Stormstout Brewery",          mapID = 376,  x = 0.36, y = 0.69, spellIDs = {131205}, itemIDs = {} },
    { name = "Shado-Pan Monastery",         mapID = 379,  x = 0.36, y = 0.48, spellIDs = {131206}, itemIDs = {} },
    { name = "Mogu'shan Palace",            mapID = 390,  x = 0.80, y = 0.33, spellIDs = {131222}, itemIDs = {} },
    { name = "Gate of the Setting Sun",     mapID = 390,  x = 0.16, y = 0.77, spellIDs = {131225}, itemIDs = {} },
    { name = "Siege of Niuzao Temple",      mapID = 388,  x = 0.35, y = 0.81, spellIDs = {131228}, itemIDs = {} },
    { name = "Scarlet Monastery",           mapID = 18,   x = 0.85, y = 0.31, spellIDs = {131229}, itemIDs = {} },
    { name = "Scarlet Halls",               mapID = 18,   x = 0.85, y = 0.31, spellIDs = {131231}, itemIDs = {} },
    { name = "Scholomance",                 mapID = 22,   x = 0.69, y = 0.73, spellIDs = {131232}, itemIDs = {} },

    -- ── Hero's Path: WoD (Challenge Mode Gold) ────────────────────────
    { name = "Bloodmaul Slag Mines",        mapID = 525,  x = 0.50, y = 0.50, spellIDs = {159895}, itemIDs = {} },
    { name = "Iron Docks",                  mapID = 543,  x = 0.45, y = 0.14, spellIDs = {159896}, itemIDs = {} },
    { name = "Auchindoun",                  mapID = 535,  x = 0.44, y = 0.74, spellIDs = {159897}, itemIDs = {} },
    { name = "Skyreach",                    mapID = 542,  x = 0.36, y = 0.34, spellIDs = {159898}, itemIDs = {} },
    { name = "Shadowmoon Burial Grounds",   mapID = 539,  x = 0.32, y = 0.43, spellIDs = {159899}, itemIDs = {} },
    { name = "Grimrail Depot",              mapID = 543,  x = 0.55, y = 0.32, spellIDs = {159900}, itemIDs = {} },
    { name = "The Everbloom",               mapID = 543,  x = 0.59, y = 0.46, spellIDs = {159901}, itemIDs = {} },
    { name = "Upper Blackrock Spire",       mapID = 36,   x = 0.29, y = 0.38, spellIDs = {159902}, itemIDs = {} },

    -- ── Hero's Path: Shadowlands (Keystone Hero) ──────────────────────
    { name = "The Necrotic Wake",           mapID = 1533, x = 0.52, y = 0.65, spellIDs = {354462}, itemIDs = {} },
    { name = "Plaguefall",                  mapID = 1536, x = 0.60, y = 0.40, spellIDs = {354463}, itemIDs = {} },
    { name = "Mists of Tirna Scithe",       mapID = 1565, x = 0.33, y = 0.53, spellIDs = {354464}, itemIDs = {} },
    { name = "Halls of Atonement",          mapID = 1525, x = 0.73, y = 0.40, spellIDs = {354465}, itemIDs = {} },
    { name = "Spires of Ascension",         mapID = 1533, x = 0.59, y = 0.35, spellIDs = {354466}, itemIDs = {} },
    { name = "Theater of Pain",             mapID = 1536, x = 0.50, y = 0.52, spellIDs = {354467}, itemIDs = {} },
    { name = "De Other Side",               mapID = 1565, x = 0.20, y = 0.55, spellIDs = {354468}, itemIDs = {} },
    { name = "Sanguine Depths",             mapID = 1525, x = 0.51, y = 0.69, spellIDs = {354469}, itemIDs = {} },
    { name = "Tazavesh",                    mapID = 1670, x = 0.50, y = 0.50, spellIDs = {367416}, itemIDs = {} },
    { name = "Return to Karazhan",          mapID = 42,   x = 0.47, y = 0.75, spellIDs = {373262}, itemIDs = {} },
    { name = "Operation: Mechagon",         mapID = 1462, x = 0.72, y = 0.36, spellIDs = {373274}, itemIDs = {} },

    -- ── Hero's Path: Dragonflight S1 (Keystone Hero) ──────────────────
    { name = "Uldaman: Legacy of Tyr",      mapID = 15,   x = 0.42, y = 0.12, spellIDs = {393222}, itemIDs = {} },
    { name = "Ruby Life Pools",             mapID = 2022, x = 0.60, y = 0.37, spellIDs = {393256}, itemIDs = {} },
    { name = "The Nokhud Offensive",        mapID = 2023, x = 0.62, y = 0.41, spellIDs = {393262}, itemIDs = {} },
    { name = "Brackenhide Hollow",          mapID = 2024, x = 0.12, y = 0.49, spellIDs = {393267}, itemIDs = {} },
    { name = "Algeth'ar Academy",           mapID = 2025, x = 0.58, y = 0.42, spellIDs = {393273}, itemIDs = {} },
    { name = "Neltharus",                   mapID = 2022, x = 0.25, y = 0.57, spellIDs = {393276}, itemIDs = {} },
    { name = "The Azure Vault",             mapID = 2024, x = 0.39, y = 0.65, spellIDs = {393279}, itemIDs = {} },
    { name = "Halls of Infusion",           mapID = 2025, x = 0.59, y = 0.60, spellIDs = {393283}, itemIDs = {} },
    { name = "Halls of Valor",              mapID = 634,  x = 0.68, y = 0.66, spellIDs = {393764}, itemIDs = {} },
    { name = "Court of Stars",              mapID = 680,  x = 0.50, y = 0.65, spellIDs = {393766}, itemIDs = {} },

    -- ── Hero's Path: Dragonflight S2 (Keystone Hero) ──────────────────
    { name = "Freehold",                    mapID = 895,  x = 0.84, y = 0.79, spellIDs = {410071}, itemIDs = {} },
    { name = "The Underrot",                mapID = 863,  x = 0.51, y = 0.66, spellIDs = {410074}, itemIDs = {} },
    { name = "Neltharion's Lair",           mapID = 650,  x = 0.50, y = 0.65, spellIDs = {410078}, itemIDs = {} },
    { name = "The Vortex Pinnacle",         mapID = 249,  x = 0.77, y = 0.84, spellIDs = {410080}, itemIDs = {} },

    -- ── Hero's Path: Dragonflight S3 (Keystone Hero) ──────────────────
    { name = "Throne of the Tides",         mapID = 204,  x = 0.69, y = 0.25, spellIDs = {424142}, itemIDs = {} },
    { name = "Black Rook Hold",             mapID = 641,  x = 0.38, y = 0.53, spellIDs = {424153}, itemIDs = {} },
    { name = "Darkheart Thicket",           mapID = 641,  x = 0.59, y = 0.31, spellIDs = {424163}, itemIDs = {} },
    { name = "Waycrest Manor",              mapID = 896,  x = 0.33, y = 0.13, spellIDs = {424167}, itemIDs = {} },
    { name = "Atal'Dazar",                  mapID = 862,  x = 0.44, y = 0.39, spellIDs = {424187}, itemIDs = {} },
    { name = "Dawn of the Infinite",        mapID = 2025, x = 0.64, y = 0.80, spellIDs = {424197}, itemIDs = {} },

    -- ── Hero's Path: The War Within S1 (Keystone Hero) ────────────────
    { name = "The Stonevault",              mapID = 2248, x = 0.50, y = 0.50, spellIDs = {445269}, itemIDs = {} },
    { name = "The Dawnbreaker",             mapID = 2215, x = 0.50, y = 0.50, spellIDs = {445414}, itemIDs = {} },
    { name = "City of Threads",             mapID = 2255, x = 0.50, y = 0.50, spellIDs = {445416}, itemIDs = {} },
    { name = "Ara-Kara, City of Echoes",    mapID = 2255, x = 0.50, y = 0.50, spellIDs = {445417}, itemIDs = {} },
    { name = "Siege of Boralus",            mapID = 895,  x = 0.73, y = 0.24, spellIDs = {445418, 464256}, itemIDs = {} },
    { name = "Grim Batol",                  mapID = 241,  x = 0.19, y = 0.54, spellIDs = {445424}, itemIDs = {} },
    { name = "Cinderbrew Meadery",          mapID = 2248, x = 0.50, y = 0.50, spellIDs = {445440}, itemIDs = {} },
    { name = "Darkflame Cleft",             mapID = 2214, x = 0.50, y = 0.50, spellIDs = {445441}, itemIDs = {} },
    { name = "The Rookery",                 mapID = 2214, x = 0.50, y = 0.50, spellIDs = {445443}, itemIDs = {} },
    { name = "Priory of the Sacred Flame",  mapID = 2215, x = 0.50, y = 0.50, spellIDs = {445444}, itemIDs = {} },

    -- ── Hero's Path: The War Within S2 (Keystone Hero) ────────────────
    { name = "The MOTHERLODE!!",            mapID = 862,  x = 0.56, y = 0.60, spellIDs = {467553, 467555}, itemIDs = {} },
    { name = "Operation: Floodgate",        mapID = 2346, x = 0.50, y = 0.50, spellIDs = {1216786}, itemIDs = {} },

    -- ── Hearthstone (dynamic location) ─────────────────────────────────
    { name = "Hearthstone", mapID = 0, x = 0, y = 0, spellIDs = {8690}, itemIDs = {6948}, isHearthstone = true },
}

-- ────────────────────────────────────────────────────────────────────────────
-- Caches
-- ────────────────────────────────────────────────────────────────────────────
local ownedCache = {}   -- rebuilt on SPELLS_CHANGED / BAG_UPDATE
local panelFrame = nil
local entryButtons = {}
local MAX_ENTRIES = 5
local PANEL_WIDTH = 250
local ENTRY_HEIGHT = 32
local isVisible = false

-- ────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:OnInitialize() end

function SmartTeleport:OnEnable()
    self:RebuildOwnershipCache()
    self:CreatePanel()
    self:RegisterEvents()
end            

function SmartTeleport:OnDisable()
    if panelFrame then panelFrame:Hide() end
    isVisible = false
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
    if self._mapHooked then
        self._mapHooked = false
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Ownership detection
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:RebuildOwnershipCache()
    wipe(ownedCache)
    for i, entry in ipairs(self.TeleportData) do
        local owned = false
        for _, sid in ipairs(entry.spellIDs) do
            if C_SpellBook.IsSpellKnown(sid) then owned = true; break end
        end
        if not owned then
            for _, iid in ipairs(entry.itemIDs) do
                if C_Item.GetItemCount(iid) > 0 or PlayerHasToy(iid) then owned = true; break end
            end
        end
        ownedCache[i] = owned
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Hearthstone location helper
-- ────────────────────────────────────────────────────────────────────────────

local function GetHearthstoneInfo()
    local bindLoc = GetBindLocation()
    -- We can't reliably get map coords of the hearth location from the API,
    -- so we just return the name for display.  Hearthstone always gets lowest
    -- priority ("Alphabetical fallback") because its mapID won't match.
    return bindLoc or "Hearthstone"
end

-- ────────────────────────────────────────────────────────────────────────────
-- Context relevance scoring
-- ────────────────────────────────────────────────────────────────────────────

local PRIORITY_SAME_MAP    = 1000
local PRIORITY_SAME_PARENT = 500
local PRIORITY_SAME_CONTINENT = 200
local PRIORITY_QUEST_BASE  = 250

-- Walk up the map hierarchy to find the continent-level mapID.
-- Continent maps have mapType == 2 (Enum.UIMapType.Continent).
local continentCache = {}
local function GetContinentMapID(mapID)
    if not mapID or mapID == 0 then return nil end
    if continentCache[mapID] then return continentCache[mapID] end

    local current = mapID
    for _ = 1, 10 do -- safety limit
        local info = C_Map.GetMapInfo(current)
        if not info then break end
        if info.mapType == 2 then -- Enum.UIMapType.Continent
            continentCache[mapID] = current
            return current
        end
        if not info.parentMapID or info.parentMapID == 0 then break end
        current = info.parentMapID
    end
    continentCache[mapID] = nil
    return nil
end

function SmartTeleport:ScoreEntries(viewedMapID)
    if not viewedMapID then return {} end

    local viewedInfo      = C_Map.GetMapInfo(viewedMapID)
    local viewedParent    = viewedInfo and viewedInfo.parentMapID
    local viewedContinent = GetContinentMapID(viewedMapID)

    -- Quests on the currently viewed map (only useful for same-map proximity)
    local quests = C_QuestLog.GetQuestsOnMap(viewedMapID) or {}

    local scored = {}
    for i, entry in ipairs(self.TeleportData) do
        if ownedCache[i] then
            local score = 0

            -- Hearthstone: always include but lowest priority
            if entry.isHearthstone then
                score = 1
            else
                local isSameMap = (entry.mapID == viewedMapID)

                -- Same map
                if isSameMap then
                    score = score + PRIORITY_SAME_MAP
                end

                -- Same direct parent (sibling zones)
                if viewedParent and viewedParent > 0 then
                    local entryInfo = C_Map.GetMapInfo(entry.mapID)
                    if entryInfo and entryInfo.parentMapID == viewedParent then
                        score = score + PRIORITY_SAME_PARENT
                    end
                end

                -- Same continent (but not already matched above)
                if score == 0 and viewedContinent then
                    local entryContinent = GetContinentMapID(entry.mapID)
                    if entryContinent and entryContinent == viewedContinent then
                        score = score + PRIORITY_SAME_CONTINENT
                    end
                end

                -- Quest proximity bonus — only when teleport is on the SAME map
                if isSameMap and #quests > 0 then
                    local bestDist = math.huge
                    for _, q in ipairs(quests) do
                        if q.x and q.y and q.x > 0 and q.y > 0 then
                            local dx = q.x - entry.x
                            local dy = q.y - entry.y
                            local dist = math.sqrt(dx * dx + dy * dy)
                            if dist < bestDist then bestDist = dist end
                        end
                    end
                    if bestDist < math.huge then
                        score = score + math.max(0, PRIORITY_QUEST_BASE - bestDist * 500)
                    end
                end
            end

            if score > 0 then
                table.insert(scored, {
                    index = i,
                    entry = entry,
                    score = score,
                })
            end
        end
    end

    -- Sort: score desc, then alphabetical asc
    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.entry.name < b.entry.name
    end)

    -- Limit to MAX_ENTRIES
    local results = {}
    for i = 1, math.min(#scored, MAX_ENTRIES) do
        results[i] = scored[i]
    end
    return results
end

-- ────────────────────────────────────────────────────────────────────────────
-- UI
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:CreatePanel()
    if panelFrame then return end

    panelFrame = CreateFrame("Frame", "BOLTSmartTeleportPanel", UIParent, "BackdropTemplate")
    panelFrame:SetSize(PANEL_WIDTH, 50) -- height adjusted dynamically
    panelFrame:SetFrameStrata("DIALOG")
    panelFrame:SetFrameLevel(200)
    panelFrame:SetClampedToScreen(true)
    panelFrame:SetMovable(false)

    panelFrame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 32, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panelFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.92)
    panelFrame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    -- Title
    local title = panelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 10, -8)
    title:SetText("Useful Teleports You Have")
    title:SetTextColor(1, 0.82, 0)
    panelFrame.title = title

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panelFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", -2, -2)
    closeBtn:SetSize(20, 20)
    closeBtn:SetScript("OnClick", function()
        panelFrame:Hide()
        isVisible = false
    end)

    -- Entry container
    panelFrame.container = CreateFrame("Frame", nil, panelFrame)
    panelFrame.container:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 8, -28)
    panelFrame.container:SetPoint("RIGHT", panelFrame, "RIGHT", -8, 0)

    panelFrame:Hide()
end

-- Resolve icon for an entry
local function GetEntryIcon(entry)
    for _, sid in ipairs(entry.spellIDs) do
        local info = C_Spell.GetSpellInfo(sid)
        if info and info.iconID then return info.iconID end
    end
    for _, iid in ipairs(entry.itemIDs) do
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(iid)
        if icon then return icon end
    end
    return 136235 -- default hearthstone icon
end

-- Resolve the first usable spellID or itemID
local function GetUsableAction(entry)
    for _, sid in ipairs(entry.spellIDs) do
        if C_SpellBook.IsSpellKnown(sid) then return "spell", sid end
    end
    for _, iid in ipairs(entry.itemIDs) do
        if PlayerHasToy(iid) then return "toy", iid end
        if C_Item.GetItemCount(iid) > 0 then return "item", iid end
    end
    return nil, nil
end

function SmartTeleport:RefreshPanel()
    if not panelFrame then return end
    if not isVisible then return end

    -- Require WorldMapFrame to be open
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        panelFrame:Hide()
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        panelFrame:Hide()
        return
    end

    local results = self:ScoreEntries(mapID)

    -- Hide all existing buttons beyond what we need
    for i = 1, #entryButtons do
        entryButtons[i]:Hide()
    end

    if #results == 0 then
        panelFrame:SetHeight(50)
        if not panelFrame.emptyText then
            panelFrame.emptyText = panelFrame.container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            panelFrame.emptyText:SetPoint("TOPLEFT", panelFrame.container, "TOPLEFT", 4, 0)
            panelFrame.emptyText:SetText("No relevant teleports for this map.")
        end
        panelFrame.emptyText:Show()
        self:AnchorToMapFrame()
        panelFrame:Show()
        return
    end

    if panelFrame.emptyText then panelFrame.emptyText:Hide() end

    for i, result in ipairs(results) do
        local btn = entryButtons[i]
        if not btn then
            btn = self:CreateEntryButton(panelFrame.container, i)
            entryButtons[i] = btn
        end

        local entry = result.entry
        local displayName = entry.name
        if entry.isHearthstone then
            displayName = "Hearthstone (" .. GetHearthstoneInfo() .. ")"
        end

        btn.icon:SetTexture(GetEntryIcon(entry))
        btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        btn.label:SetText(displayName)

        -- Set secure attributes (safe: map can't be open during combat)
        local actionType, actionID = GetUsableAction(entry)
        btn.actionType = actionType
        btn.actionID   = actionID
        if not InCombatLockdown() then
            if actionType == "spell" then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", actionID)
                btn:SetAttribute("macrotext", nil)
            elseif actionType == "toy" then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/use item:" .. actionID)
                btn:SetAttribute("spell", nil)
            elseif actionType == "item" then
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", "/use item:" .. actionID)
                btn:SetAttribute("spell", nil)
            else
                btn:SetAttribute("type", nil)
            end
        end

        btn:SetPoint("TOPLEFT", panelFrame.container, "TOPLEFT", 0, -(i - 1) * ENTRY_HEIGHT)
        btn:Show()
    end

    -- Dynamic height
    local totalH = 28 + (#results * ENTRY_HEIGHT) + 10
    panelFrame:SetHeight(totalH)
    panelFrame.container:SetHeight(#results * ENTRY_HEIGHT)

    self:AnchorToMapFrame()
    panelFrame:Show()
end

function SmartTeleport:AnchorToMapFrame()
    if not panelFrame or not WorldMapFrame then return end
    panelFrame:ClearAllPoints()
    panelFrame:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 4, 0)
end

function SmartTeleport:CreateEntryButton(parent, index)
    local btn = CreateFrame("Button", "BOLTSmartTP_Entry" .. index, parent, "SecureActionButtonTemplate")
    btn:SetSize(PANEL_WIDTH - 16, ENTRY_HEIGHT)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    -- Icon
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ENTRY_HEIGHT - 6, ENTRY_HEIGHT - 6)
    icon:SetPoint("LEFT", btn, "LEFT", 2, 0)
    btn.icon = icon

    -- Label
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    btn.label = label

    -- Tooltip (hooks work on secure buttons without breaking security)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.actionType == "spell" then
            GameTooltip:SetSpellByID(self.actionID)
        elseif self.actionType == "toy" or self.actionType == "item" then
            GameTooltip:SetItemByID(self.actionID)
        else
            GameTooltip:SetText("No usable action")
        end
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    return btn
end

-- ────────────────────────────────────────────────────────────────────────────
-- Events
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:RegisterEvents()
    if self.eventFrame then return end

    local f = CreateFrame("Frame")
    f:RegisterEvent("SPELLS_CHANGED")
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("QUEST_LOG_UPDATE")

    f:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" or event == "BAG_UPDATE" then
            self:RebuildOwnershipCache()
        end
        if isVisible then self:RefreshPanel() end
    end)

    self.eventFrame = f

    -- Hook WorldMapFrame map changes and show/hide
    if WorldMapFrame and not self._mapHooked then
        hooksecurefunc(WorldMapFrame, "SetMapID", function()
            if isVisible then self:RefreshPanel() end
        end)

        -- Auto-show when the map opens
        WorldMapFrame:HookScript("OnShow", function()
            if not self.parent:IsModuleEnabled("smartTeleport") then return end
            isVisible = true
            self:RebuildOwnershipCache()
            self:RefreshPanel()
        end)

        -- Auto-hide when the map closes
        WorldMapFrame:HookScript("OnHide", function()
            if panelFrame then panelFrame:Hide() end
            isVisible = false
        end)

        self._mapHooked = true
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Register
-- ────────────────────────────────────────────────────────────────────────────
BOLT:RegisterModule("smartTeleport", SmartTeleport)
