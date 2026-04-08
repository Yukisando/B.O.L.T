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
    { name = "Silvermoon",        mapID = 2393, x = 0.58, y = 0.19, spellIDs = {32272, 32267, 1259190, 1259194}, itemIDs = {} },

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
    { name = "The Arcantina",                mapID = 2393, x = 0.50, y = 0.50, spellIDs = {},        itemIDs = {253629} },

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
    { name = "Wormhole: Quel'Thalas",    mapID = 2537, x = 0.50, y = 0.50, spellIDs = {},  itemIDs = {248485} },

    -- ── Hero's Path: MoP (Challenge Mode Gold) ───────────────────────
    { name = "Temple of the Jade Serpent",  mapID = 371,  x = 0.56, y = 0.58, spellIDs = {131204}, itemIDs = {} },
    { name = "Stormstout Brewery",          mapID = 376,  x = 0.36, y = 0.69, spellIDs = {131205}, itemIDs = {} },
    { name = "Shado-Pan Monastery",         mapID = 379,  x = 0.36, y = 0.48, spellIDs = {131206}, itemIDs = {} },
    { name = "Mogu'shan Palace",            mapID = 390,  x = 0.80, y = 0.33, spellIDs = {131222}, itemIDs = {} },
    { name = "Gate of the Setting Sun",     mapID = 422,  x = 0.16, y = 0.77, spellIDs = {131225}, itemIDs = {} },
    { name = "Siege of Niuzao Temple",      mapID = 388,  x = 0.35, y = 0.81, spellIDs = {131228}, itemIDs = {} },
    { name = "Scarlet Monastery",           mapID = 18,   x = 0.85, y = 0.31, spellIDs = {131229}, itemIDs = {} },
    { name = "Scarlet Halls",               mapID = 18,   x = 0.85, y = 0.31, spellIDs = {131231}, itemIDs = {} },
    { name = "Scholomance",                 mapID = 22,   x = 0.69, y = 0.73, spellIDs = {131232}, itemIDs = {} },

    -- ── Hero's Path: WoD (Challenge Mode Gold) ────────────────────────
    { name = "Bloodmaul Slag Mines",        mapID = 525,  x = 0.496, y = 0.246, spellIDs = {159895}, itemIDs = {} },
    { name = "Iron Docks",                  mapID = 543,  x = 0.45, y = 0.14, spellIDs = {159896}, itemIDs = {} },
    { name = "Auchindoun",                  mapID = 535,  x = 0.44, y = 0.74, spellIDs = {159897}, itemIDs = {} },
    { name = "Skyreach",                    mapID = 542,  x = 0.36, y = 0.34, spellIDs = {159898}, itemIDs = {} },
    { name = "Shadowmoon Burial Grounds",   mapID = 539,  x = 0.32, y = 0.43, spellIDs = {159899}, itemIDs = {} },
    { name = "Grimrail Depot",              mapID = 543,  x = 0.55, y = 0.32, spellIDs = {159900}, itemIDs = {} },
    { name = "The Everbloom",               mapID = 543,  x = 0.59, y = 0.46, spellIDs = {159901}, itemIDs = {} },
    { name = "Upper Blackrock Spire",       mapID = 36,   x = 0.29, y = 0.38, spellIDs = {159902}, itemIDs = {} },

    -- ── Hero's Path: Shadowlands (Keystone Hero) ──────────────────────
    { name = "The Necrotic Wake",           mapID = 1533, x = 0.34, y = 0.26, spellIDs = {354462}, itemIDs = {} },
    { name = "Plaguefall",                  mapID = 1536, x = 0.63, y = 0.36, spellIDs = {354463}, itemIDs = {} },
    { name = "Mists of Tirna Scithe",       mapID = 1565, x = 0.33, y = 0.52, spellIDs = {354464}, itemIDs = {} },
    { name = "Halls of Atonement",          mapID = 1525, x = 0.73, y = 0.40, spellIDs = {354465}, itemIDs = {} },
    { name = "Spires of Ascension",         mapID = 1533, x = 0.58, y = 0.29, spellIDs = {354466}, itemIDs = {} },
    { name = "Theater of Pain",             mapID = 1536, x = 0.50, y = 0.52, spellIDs = {354467}, itemIDs = {} },
    { name = "De Other Side",               mapID = 1565, x = 0.20, y = 0.55, spellIDs = {354468}, itemIDs = {} },
    { name = "Sanguine Depths",             mapID = 1525, x = 0.51, y = 0.69, spellIDs = {354469}, itemIDs = {} },
    { name = "Tazavesh",                    mapID = 1670, x = 0.50, y = 0.50, spellIDs = {367416}, itemIDs = {} },
    { name = "Return to Karazhan",          mapID = 42,   x = 0.54, y = 0.78, spellIDs = {373262}, itemIDs = {} },
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
    { name = "Neltharion's Lair",           mapID = 650,  x = 0.49, y = 0.68, spellIDs = {410078}, itemIDs = {} },
    { name = "The Vortex Pinnacle",         mapID = 249,  x = 0.77, y = 0.84, spellIDs = {410080}, itemIDs = {} },

    -- ── Hero's Path: Dragonflight S3 (Keystone Hero) ──────────────────
    { name = "Throne of the Tides",         mapID = 204,  x = 0.71, y = 0.29, spellIDs = {424142}, itemIDs = {} },
    { name = "Black Rook Hold",             mapID = 641,  x = 0.38, y = 0.53, spellIDs = {424153}, itemIDs = {} },
    { name = "Darkheart Thicket",           mapID = 641,  x = 0.59, y = 0.31, spellIDs = {424163}, itemIDs = {} },
    { name = "Waycrest Manor",              mapID = 896,  x = 0.33, y = 0.13, spellIDs = {424167}, itemIDs = {} },
    { name = "Atal'Dazar",                  mapID = 862,  x = 0.44, y = 0.39, spellIDs = {424187}, itemIDs = {} },
    { name = "Dawn of the Infinite",        mapID = 2025, x = 0.61, y = 0.84, spellIDs = {424197}, itemIDs = {} },

    -- ── Hero's Path: The War Within S1 (Keystone Hero) ────────────────
    { name = "The Stonevault",              mapID = 2214, x = 0.427, y = 0.086, spellIDs = {445269}, itemIDs = {} },
    { name = "The Dawnbreaker",             mapID = 2215, x = 0.57, y = 0.62, spellIDs = {445414}, itemIDs = {} },
    { name = "City of Threads",             mapID = 2255, x = 0.481, y = 0.713, spellIDs = {445416}, itemIDs = {} },
    { name = "Ara-Kara, City of Echoes",    mapID = 2255, x = 0.51, y = 0.82, spellIDs = {445417}, itemIDs = {} },
    { name = "Siege of Boralus",            mapID = 895,  x = 0.73, y = 0.24, spellIDs = {445418, 464256}, itemIDs = {} },
    { name = "Grim Batol",                  mapID = 241,  x = 0.19, y = 0.56, spellIDs = {445424}, itemIDs = {} },
    { name = "Cinderbrew Meadery",          mapID = 2248, x = 0.81, y = 0.44, spellIDs = {445440}, itemIDs = {} },
    { name = "Darkflame Cleft",             mapID = 2214, x = 0.56, y = 0.22, spellIDs = {445441}, itemIDs = {} },
    { name = "The Rookery",                 mapID = 2248, x = 0.33, y = 0.35, spellIDs = {445443}, itemIDs = {} },
    { name = "Priory of the Sacred Flame",  mapID = 2215, x = 0.42, y = 0.50, spellIDs = {445444}, itemIDs = {} },

    -- ── Hero's Path: The War Within S2 (Keystone Hero) ────────────────
    { name = "The MOTHERLODE!!",            mapID = 862,  x = 0.56, y = 0.60, spellIDs = {467553, 467555}, itemIDs = {} },
    { name = "Operation: Floodgate",        mapID = 2214, x = 0.421, y = 0.395, spellIDs = {1216786}, itemIDs = {} },

    -- ── Hearthstone (dynamic location) ─────────────────────────────────
    { name = "Hearthstone", mapID = 0, x = 0, y = 0, spellIDs = {8690}, itemIDs = {6948}, isHearthstone = true },
}

-- ────────────────────────────────────────────────────────────────────────────
-- Caches
-- ────────────────────────────────────────────────────────────────────────────
local ownedCache = {}   -- rebuilt on SPELLS_CHANGED / BAG_UPDATE
local drawerFrame = nil
local entryButtons = {}
local pendingDrawerHide = false
local pendingDrawerRefresh = false
local ICON_SIZE    = 32
local ICON_PAD     = 4
local DRAWER_PAD   = 6
local MAX_ICONS    = 8
local GetItemCooldown = C_Item and C_Item.GetItemCooldown
local GetItemSpellInfo = (C_Item and rawget(C_Item, "GetItemSpell")) or rawget(_G, "GetItemSpell")

-- ────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:OnInitialize() end

function SmartTeleport:OnEnable()
    self:RebuildOwnershipCache()
    self:CreateDrawer()
    self:RegisterEvents()
end

function SmartTeleport:HideDrawer()
    if not drawerFrame then return end
    if InCombatLockdown() then
        pendingDrawerHide = true
        pendingDrawerRefresh = false
        return
    end

    pendingDrawerHide = false
    pendingDrawerRefresh = false
    drawerFrame:Hide()
end

function SmartTeleport:RequestDrawerRefresh()
    if InCombatLockdown() then
        pendingDrawerHide = false
        pendingDrawerRefresh = true
        return
    end

    pendingDrawerHide = false
    pendingDrawerRefresh = false
    self:RefreshDrawer()
end

function SmartTeleport:OnDisable()
    self:HideDrawer()
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
local PRIORITY_CHILD_MAP   = 800
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

-- Check if childMapID is a descendant of ancestorMapID in the map hierarchy.
local function IsDescendantMap(childMapID, ancestorMapID)
    if not childMapID or not ancestorMapID or childMapID == 0 or ancestorMapID == 0 then
        return false
    end
    local current = childMapID
    for _ = 1, 10 do
        local info = C_Map.GetMapInfo(current)
        if not info then return false end
        if info.parentMapID == ancestorMapID then return true end
        if not info.parentMapID or info.parentMapID == 0 then return false end
        current = info.parentMapID
    end
    return false
end

function SmartTeleport:ScoreEntries(viewedMapID)
    if not viewedMapID then return {} end

    local viewedInfo      = C_Map.GetMapInfo(viewedMapID)
    local viewedParent    = viewedInfo and viewedInfo.parentMapID
    local viewedContinent = GetContinentMapID(viewedMapID)

    -- Only allow sibling matching when the parent is continent-level or lower
    -- (mapType >= 2). This prevents all continent-level entries (e.g. wormholes)
    -- from matching each other just because they share the World map as parent.
    local parentInfo = viewedParent and viewedParent > 0 and C_Map.GetMapInfo(viewedParent)
    local parentIsZoneLevel = parentInfo and parentInfo.mapType and parentInfo.mapType >= 2

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

                -- Same map (exact match)
                if isSameMap then
                    score = score + PRIORITY_SAME_MAP
                end

                -- Entry is a child/descendant of the viewed map
                -- (e.g. viewing a continent, entry is in a zone within it)
                if not isSameMap and IsDescendantMap(entry.mapID, viewedMapID) then
                    score = score + PRIORITY_CHILD_MAP
                end

                -- Same direct parent (sibling zones) — only at zone level or below
                if viewedParent and viewedParent > 0 and parentIsZoneLevel then
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

    return scored
end

-- ────────────────────────────────────────────────────────────────────────────
-- UI
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:CreateDrawer()
    if drawerFrame then return end
    if not WorldMapFrame then return end

    local mapAnchor = WorldMapFrame.ScrollContainer or WorldMapFrame

    -- Parent to UIParent, NOT WorldMapFrame. Parenting an addon (non-secure) frame
    -- to WorldMapFrame taints the map's child-frame table, causing
    -- ADDON_ACTION_BLOCKED on SetPropagateMouseClicks (called by flight-point pins in
    -- secureexecuterange) and "secret value" taint on UIWidget font-string heights.
    -- We position the drawer below the map via SetPoint anchors (which can reference
    -- any frame for positioning regardless of parent) and hide it manually via an
    -- OnHide hook below.
    drawerFrame = CreateFrame("Frame", "BOLTSmartTeleportDrawer", UIParent, "BackdropTemplate")
    drawerFrame:SetHeight(ICON_SIZE + DRAWER_PAD * 2)
    drawerFrame:SetPoint("TOP", mapAnchor, "BOTTOM", 0, -6)
    drawerFrame:SetFrameStrata("DIALOG")
    drawerFrame:SetFrameLevel(500)

    drawerFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    drawerFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.88)
    drawerFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)

    drawerFrame:Hide()
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

local function GetSpellIDFromLink(spellLink)
    if type(spellLink) ~= "string" then
        return nil
    end

    local spellID = string.match(spellLink, "spell:(%d+)")
    return spellID and tonumber(spellID) or nil
end

local function GetAssociatedSpellID(itemID)
    if not itemID or not GetItemSpellInfo then
        return nil
    end

    local ok, _, spellLink = pcall(GetItemSpellInfo, itemID)
    if not ok or not spellLink then
        return nil
    end

    return GetSpellIDFromLink(spellLink)
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

local function GetPreferredTooltipAction(actionType, actionID)
    if actionType == "spell" then
        return "spell", actionID
    end

    if actionType == "toy" or actionType == "item" then
        local spellID = GetAssociatedSpellID(actionID)
        if spellID and C_SpellBook.IsSpellKnown(spellID) then
            return "spell", spellID
        end

        return "item", actionID
    end

    return nil, nil
end

local function GetActionCooldownInfo(actionType, actionID, tooltipType, tooltipID)
    if (actionType == "toy" or actionType == "item") and GetItemCooldown then
        local startTime, duration, enableCooldownTimer = GetItemCooldown(actionID)
        if startTime and duration and duration > 0 then
            return startTime, duration, enableCooldownTimer, 1
        end
    end

    if (actionType == "spell" or tooltipType == "spell") and C_Spell and C_Spell.GetSpellCooldown then
        local spellID = actionType == "spell" and actionID or tooltipID
        local info = spellID and C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration, info.isEnabled, info.modRate
        end
    end

    return nil, nil, nil, nil
end

function SmartTeleport:RefreshDrawer()
    if not drawerFrame then return end
    if InCombatLockdown() then return end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        self:HideDrawer()
        return
    end

    local mapID = WorldMapFrame:GetMapID()
    if not mapID then
        self:HideDrawer()
        return
    end

    local results = self:ScoreEntries(mapID)

    for i = 1, #entryButtons do
        entryButtons[i]:Hide()
    end

    if #results == 0 then
        self:HideDrawer()
        return
    end

    local displayCount = math.min(#results, MAX_ICONS)
    for i = 1, displayCount do
        local result = results[i]
        local btn = entryButtons[i]
        if not btn then
            btn = self:CreateIconButton(drawerFrame, i)
            entryButtons[i] = btn
        end

        local entry = result.entry
        btn.entryName = entry.isHearthstone
            and ("Hearthstone (" .. GetHearthstoneInfo() .. ")")
            or entry.name

        btn.icon:SetTexture(GetEntryIcon(entry))
        btn.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local actionType, actionID = GetUsableAction(entry)
        btn.actionType = actionType
        btn.actionID   = actionID
        btn.tooltipType, btn.tooltipID = GetPreferredTooltipAction(actionType, actionID)
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

        btn:SetSize(ICON_SIZE, ICON_SIZE)
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", drawerFrame, "LEFT", DRAWER_PAD + (i - 1) * (ICON_SIZE + ICON_PAD), 0)
        self:UpdateButtonCooldown(btn)
        btn:Show()
    end

    -- Size drawer to fit icons, centered at bottom of map
    local totalWidth = DRAWER_PAD * 2 + displayCount * ICON_SIZE + (displayCount - 1) * ICON_PAD
    drawerFrame:SetWidth(totalWidth)

    local mapAnchor = WorldMapFrame.ScrollContainer or WorldMapFrame
    drawerFrame:ClearAllPoints()
    drawerFrame:SetPoint("TOP", mapAnchor, "BOTTOM", 0, -6)
    drawerFrame:Show()
end

function SmartTeleport:UpdateButtonCooldown(button)
    if not button then
        return
    end

    local startTime, duration, isEnabled, modRate = GetActionCooldownInfo(
        button.actionType,
        button.actionID,
        button.tooltipType,
        button.tooltipID
    )

    BOLT.ButtonUtils:SetButtonCooldown(button, startTime, duration, isEnabled, modRate)
end

function SmartTeleport:UpdateVisibleButtonCooldowns()
    for _, button in ipairs(entryButtons) do
        if button and button:IsShown() then
            self:UpdateButtonCooldown(button)
        elseif button then
            BOLT.ButtonUtils:ClearButtonCooldown(button)
        end
    end
end

function SmartTeleport:CreateIconButton(parent, index)
    local btn = CreateFrame("Button", "BOLTSmartTP_Entry" .. index, parent, "SecureActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    btn.icon = icon

    -- Highlight border on hover
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.15)

    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.tooltipType == "spell" then
            GameTooltip:SetSpellByID(self.tooltipID)
        elseif self.tooltipType == "item" then
            GameTooltip:SetItemByID(self.tooltipID)
        else
            GameTooltip:SetText(self.entryName or "Teleport", 1, 1, 1)
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
    f:RegisterEvent("TOYS_UPDATED")
    f:RegisterEvent("QUEST_LOG_UPDATE")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    f:RegisterEvent("BAG_UPDATE_COOLDOWN")

    f:SetScript("OnEvent", function(_, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
            if drawerFrame and drawerFrame:IsShown() then
                self:UpdateVisibleButtonCooldowns()
            end
            return
        end

        if event == "SPELLS_CHANGED" or event == "BAG_UPDATE" or event == "TOYS_UPDATED" then
            self:RebuildOwnershipCache()
        end
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingDrawerHide or not WorldMapFrame or not WorldMapFrame:IsShown() then
                self:HideDrawer()
                return
            end
            if pendingDrawerRefresh then
                self:RequestDrawerRefresh()
                return
            end
        end
        if drawerFrame and drawerFrame:IsShown() then self:RequestDrawerRefresh() end
    end)

    self.eventFrame = f

    if WorldMapFrame and not self._mapHooked then
        -- Defer via C_Timer.After(0) so BOLT's code never runs inline inside the
        -- WorldMap's secure open sequence (secureexecuterange / SetMapID chain).
        -- Running addon code mid-sequence taints the environment, causing
        -- ADDON_ACTION_BLOCKED on SetPropagateMouseClicks for flight-point pins.
        hooksecurefunc(WorldMapFrame, "SetMapID", function()
            if drawerFrame then
                C_Timer.After(0, function() self:RequestDrawerRefresh() end)
            end
        end)

        WorldMapFrame:HookScript("OnShow", function()
            if not self.parent:IsModuleEnabled("smartTeleport") then return end
            C_Timer.After(0, function()
                self:RebuildOwnershipCache()
                self:RequestDrawerRefresh()
            end)
        end)

        -- Hide the drawer when the map closes. Because drawerFrame is parented to
        -- UIParent (not WorldMapFrame) it no longer auto-hides with the map.
        WorldMapFrame:HookScript("OnHide", function()
            self:HideDrawer()
        end)

        self._mapHooked = true
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Register
-- ────────────────────────────────────────────────────────────────────────────
BOLT:RegisterModule("smartTeleport", SmartTeleport)
