-- B.O.L.T Smart Teleport Suggestions Module
-- Shows context-relevant teleports the player owns when viewing the World Map

local ADDON_NAME, BOLT = ...

local SmartTeleport = {
    displayName = "Smart Teleport",
}

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

function SmartTeleport:IsSupported()
    -- The dataset is modern-WoW destinations; WoW: Forever uses different maps.
    return not BOLT.isForever
end

-- ────────────────────────────────────────────────────────────────────────────
-- Ownership
-- ────────────────────────────────────────────────────────────────────────────

local ICON_SIZE = 32
local ICON_PAD = 4
local DRAWER_PAD = 6
local MAX_ICONS = 8
local DEFAULT_ICON = 136235

local PRIORITY_SAME_MAP = 1000
local PRIORITY_CHILD_MAP = 800
local PRIORITY_SAME_PARENT = 500
local PRIORITY_SAME_CONTINENT = 200
local PRIORITY_QUEST_BASE = 250

local ownedCache = {}
local drawer
local entryButtons = {}
local pendingRefresh = false

-- Returns the secure action for the first owned spell/toy/item of an entry.
local function GetUsableAction(entry)
    for _, spellID in ipairs(entry.spellIDs) do
        if C_SpellBook.IsSpellKnown(spellID) then return "spell", spellID end
    end
    for _, itemID in ipairs(entry.itemIDs) do
        if PlayerHasToy(itemID) then return "toy", itemID end
        if C_Item.GetItemCount(itemID) > 0 then return "item", itemID end
    end
    return nil
end

function SmartTeleport:RebuildOwnershipCache()
    for index, entry in ipairs(self.TeleportData) do
        ownedCache[index] = GetUsableAction(entry) ~= nil
    end
end

-- ────────────────────────────────────────────────────────────────────────────
-- Scoring
-- ────────────────────────────────────────────────────────────────────────────

local continentCache = {}
local function GetContinentMapID(mapID)
    if not mapID or mapID == 0 then return nil end
    if continentCache[mapID] ~= nil then return continentCache[mapID] or nil end

    local current, continent = mapID, false
    for _ = 1, 10 do
        local info = C_Map.GetMapInfo(current)
        if not info then break end
        if info.mapType == Enum.UIMapType.Continent then
            continent = current
            break
        end
        if not info.parentMapID or info.parentMapID == 0 then break end
        current = info.parentMapID
    end
    continentCache[mapID] = continent
    return continent or nil
end

local function IsDescendantMap(childMapID, ancestorMapID)
    local current = childMapID
    for _ = 1, 10 do
        local info = current and current ~= 0 and C_Map.GetMapInfo(current)
        if not info then return false end
        if info.parentMapID == ancestorMapID then return true end
        current = info.parentMapID
    end
    return false
end

local function QuestProximityBonus(entry, quests)
    local best = math.huge
    for _, quest in ipairs(quests) do
        if quest.x and quest.y and quest.x > 0 and quest.y > 0 then
            local dx, dy = quest.x - entry.x, quest.y - entry.y
            best = math.min(best, math.sqrt(dx * dx + dy * dy))
        end
    end
    if best == math.huge then return 0 end
    return math.max(0, PRIORITY_QUEST_BASE - best * 500)
end

function SmartTeleport:ScoreEntries(viewedMapID)
    local viewedInfo = C_Map.GetMapInfo(viewedMapID)
    local viewedParent = viewedInfo and viewedInfo.parentMapID
    local viewedContinent = GetContinentMapID(viewedMapID)

    -- Sibling matching only below continent level, so every continent-level entry
    -- (wormholes) doesn't match every other one through the shared World parent.
    local parentInfo = viewedParent and viewedParent > 0 and C_Map.GetMapInfo(viewedParent)
    local siblingsCount = parentInfo and parentInfo.mapType >= Enum.UIMapType.Continent

    local quests = C_QuestLog.GetQuestsOnMap(viewedMapID) or {}

    local scored = {}
    for index, entry in ipairs(self.TeleportData) do
        if ownedCache[index] then
            local score = 0
            if entry.isHearthstone then
                score = 1 -- always offered, lowest priority
            elseif entry.mapID == viewedMapID then
                score = PRIORITY_SAME_MAP + QuestProximityBonus(entry, quests)
            else
                if IsDescendantMap(entry.mapID, viewedMapID) then
                    score = score + PRIORITY_CHILD_MAP
                end
                if siblingsCount then
                    local entryInfo = C_Map.GetMapInfo(entry.mapID)
                    if entryInfo and entryInfo.parentMapID == viewedParent then
                        score = score + PRIORITY_SAME_PARENT
                    end
                end
                if score == 0 and viewedContinent and GetContinentMapID(entry.mapID) == viewedContinent then
                    score = PRIORITY_SAME_CONTINENT
                end
            end

            if score > 0 then
                table.insert(scored, { entry = entry, score = score })
            end
        end
    end

    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.entry.name < b.entry.name
    end)
    return scored
end

-- ────────────────────────────────────────────────────────────────────────────
-- Drawer UI
-- ────────────────────────────────────────────────────────────────────────────

local function GetEntryIcon(entry)
    for _, spellID in ipairs(entry.spellIDs) do
        local icon = C_Spell.GetSpellTexture(spellID)
        if icon then return icon end
    end
    for _, itemID in ipairs(entry.itemIDs) do
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    return DEFAULT_ICON
end

local function UpdateButtonCooldown(button)
    local startTime, duration, enabled, modRate
    if button.actionType == "spell" then
        local info = C_Spell.GetSpellCooldown(button.actionID)
        if info then
            startTime, duration, enabled, modRate = info.startTime, info.duration, info.isEnabled, info.modRate
        end
    elseif button.actionType then
        startTime, duration, enabled = C_Item.GetItemCooldown(button.actionID)
    end
    BOLT.ButtonUtils:SetButtonCooldown(button, startTime, duration, enabled, modRate)
end

local function CreateEntryButton(index)
    local button = CreateFrame("Button", "BOLTSmartTP_Entry" .. index, drawer, "SecureActionButtonTemplate")
    button:SetSize(ICON_SIZE, ICON_SIZE)
    button:SetPoint("LEFT", drawer, "LEFT", DRAWER_PAD + (index - 1) * (ICON_SIZE + ICON_PAD), 0)
    button:RegisterForClicks("AnyUp", "AnyDown")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)

    button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    button.cooldown:SetAllPoints()
    button.cooldown:SetDrawEdge(false)
    button.cooldown:SetDrawBling(false)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.actionType == "spell" then
            GameTooltip:SetSpellByID(self.actionID)
        elseif self.actionType == "toy" then
            GameTooltip:SetToyByItemID(self.actionID)
        elseif self.actionType == "item" then
            GameTooltip:SetItemByID(self.actionID)
        else
            GameTooltip:SetText(self.entryName or "Teleport", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function CreateDrawer()
    -- Parented to UIParent, not WorldMapFrame: addon children of the map taint its
    -- pin frames (ADDON_ACTION_BLOCKED on SetPropagateMouseClicks for flight points).
    -- The drawer is only anchored to the map and hidden manually with it.
    drawer = CreateFrame("Frame", "BOLTSmartTeleportDrawer", UIParent, "BackdropTemplate")
    drawer:SetHeight(ICON_SIZE + DRAWER_PAD * 2)
    drawer:SetFrameStrata("DIALOG")
    drawer:SetFrameLevel(500)
    drawer:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    drawer:SetBackdropColor(0.05, 0.05, 0.05, 0.88)
    drawer:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.9)
    drawer:Hide()
end

-- The drawer holds secure buttons, so showing, hiding and changing it waits for
-- the end of combat.
function SmartTeleport:HideDrawer()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    drawer:Hide()
end

function SmartTeleport:RefreshDrawer()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    pendingRefresh = false

    local mapID = WorldMapFrame:IsShown() and WorldMapFrame:GetMapID()
    if not (self.active and mapID) then
        drawer:Hide()
        return
    end

    local results = self:ScoreEntries(mapID)
    local count = math.min(#results, MAX_ICONS)
    for index = 1, math.max(count, #entryButtons) do
        local button = entryButtons[index]
        if index <= count then
            button = button or CreateEntryButton(index)
            entryButtons[index] = button

            local entry = results[index].entry
            local actionType, actionID = GetUsableAction(entry)
            button.entryName = entry.isHearthstone and ("Hearthstone (" .. GetBindLocation() .. ")") or entry.name
            button.actionType, button.actionID = actionType, actionID
            button.icon:SetTexture(GetEntryIcon(entry))
            button:SetAttribute("type", actionType)
            button:SetAttribute("spell", actionType == "spell" and actionID or nil)
            button:SetAttribute("toy", actionType == "toy" and actionID or nil)
            button:SetAttribute("item", actionType == "item" and ("item:" .. actionID) or nil)
            UpdateButtonCooldown(button)
            button:Show()
        elseif button then
            button:Hide()
        end
    end

    if count == 0 then
        drawer:Hide()
        return
    end

    drawer:SetWidth(DRAWER_PAD * 2 + count * ICON_SIZE + (count - 1) * ICON_PAD)
    drawer:ClearAllPoints()
    drawer:SetPoint("TOP", WorldMapFrame.ScrollContainer or WorldMapFrame, "BOTTOM", 0, -6)
    drawer:Show()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Lifecycle
-- ────────────────────────────────────────────────────────────────────────────

function SmartTeleport:OnInitialize()
    CreateDrawer()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "SPELL_UPDATE_COOLDOWN" or event == "BAG_UPDATE_COOLDOWN" then
            for _, button in ipairs(entryButtons) do
                if button:IsShown() then UpdateButtonCooldown(button) end
            end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingRefresh then self:RefreshDrawer() end
            return
        end
        self:RebuildOwnershipCache()
        if drawer:IsShown() then self:RefreshDrawer() end
    end)

    -- Deferred so addon code never runs inside the map's secure open sequence
    -- (secureexecuterange / SetMapID), which would taint the flight-point pins.
    local function DeferredRefresh()
        if self.active then
            C_Timer.After(0, function() self:RefreshDrawer() end)
        end
    end
    hooksecurefunc(WorldMapFrame, "SetMapID", DeferredRefresh)
    WorldMapFrame:HookScript("OnShow", DeferredRefresh)
    WorldMapFrame:HookScript("OnHide", function()
        if self.active then self:HideDrawer() end
    end)
end

function SmartTeleport:OnEnable()
    for _, event in ipairs({ "SPELLS_CHANGED", "BAG_UPDATE_DELAYED", "TOYS_UPDATED",
        "PLAYER_REGEN_ENABLED", "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN" }) do
        self.eventFrame:RegisterEvent(event)
    end
    self:RebuildOwnershipCache()
    self:RefreshDrawer()
end

function SmartTeleport:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self:HideDrawer()
    if pendingRefresh then
        -- Still need the end-of-combat event to hide the drawer.
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    end
end

BOLT:RegisterModule("smartTeleport", SmartTeleport)
