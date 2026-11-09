-- B.O.L.T Campfire Module (WoW: Forever only)
-- While the "Campfire Nearby" buff is on you (it reaches ~100 yards), a slim camp bar fades in
-- beside the minimap (left by default; right, above, under or anywhere, set in Edit Mode):
--   * The bar: the fire, what to do now ("Sit by the fire", "Warming up", "Camp benefits
--     active"), a progress bar for the minute of warming up or the benefits' time left, and Sit.
--   * Click it to open the drawer: the camp benefits you got (read from the Camp Benefits
--     tooltip) and your camp gear, each object with its own Place and Craft buttons.
--   * Ready alert: a sound, a glow and a taskbar flash when Camp Benefits lands.
--
-- Range: the game gives no distance to the fire (Campfire Nearby covers ~100 yards and the
-- Cooking spell-focus check ignores campfires, tested 2026-11-07). What we do know:
--   seated + Welcoming Campfire          = close enough (and we remember that spot),
--   seated + no Welcoming after a moment = too far,
--   standing on a remembered spot        = close enough; auto-sit happens there.
--
-- Crafting: opening a profession is a spellbook cast, so Craft, Place and Open are secure
-- buttons. When the profession is already open, Craft crafts directly; otherwise the click casts
-- the profession spell and the craft fires once its window is ready (click again if it didn't).
--
-- Camp recipes ship with the addon (OBJECTS); open profession windows refine what you know.
-- `/bolt camp` prints what the module sees, for bug reports.

local ADDON_NAME, BOLT = ...

local Campfire = {
    displayName = "Campfire",
}

local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode

local AURA_NEARBY = "Campfire Nearby"
local AURA_WARMING = "Welcoming Campfire"
local AURA_BENEFITS = "Camp Benefits"
local WARM_UP = 60          -- seconds of sitting before Camp Benefits
local TOO_FAR_AFTER = 3     -- seconds seated without Welcoming Campfire = too far
local AUTO_SIT_STILL = 1    -- seconds standing still on a warm spot before auto-sit
local WARM_RADIUS = 2.5     -- yards around a spot where the fire warmed you
local CRAFT_RETRY_HINT = 1.5 -- seconds after the window opened with no craft started
local FALLBACK_ICON = "Interface\\Icons\\Spell_Fire_Fire"
local FADE = 0.35
local WIDTH = 270           -- bar and drawer
local BAR_HEIGHT = 46
local PAD = 12
local GAP = 2
local ROW_HEIGHT = 34
local BENEFIT_HEIGHT = 20
local EDIT_KEY = "campBar"

-- The square minimap's panel art, so the bar looks like part of the minimap.
local BOX = { atlas = "ui-hud-minimap-header-button", corner = 7, midX = 76, midY = 11 }

local GREEN = { 0.45, 1, 0.45 }
local RED = { 1, 0.4, 0.3 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.65, 0.65, 0.65 }
local ORANGE = { 1, 0.55, 0.15 }

---------------------------------------------------------------------------
-- Camp objects (Forever camping guides, 2026-11; recipe/item IDs from wowforever.be and
-- method.gg, Camp Tent confirmed in game). Reagents are a fallback: the live recipe schematic wins.
---------------------------------------------------------------------------

local SKILL_LINE = {
    Alchemy = 171, Blacksmithing = 164, Enchanting = 333, Engineering = 202, Herbalism = 182,
    Leatherworking = 165, Mining = 186, Skinning = 393, Tailoring = 197, Cooking = 185,
    ["First Aid"] = 129, Fishing = 356,
}

local OBJECTS = {
    -- The fire itself
    { "Basic Campfire", "Cooking", 1229737, nil, "Lights a camp with 3 object slots", { { 4470, 1 } } },
    { "Journeyman Campfire", "Cooking", 1283400, nil, "Lights a camp with 5 object slots", { { 11291, 1 } } },
    { "Expert Campfire", "Cooking", 1291341, nil, "Lights a camp with 10 object slots", { { 272941, 1 } } },
    -- Tier 1
    { "Mana Well", "Alchemy", 1230564, 279956, "Mana regeneration", { { 2447, 1 }, { 3371, 1 } } },
    { "Sharpening Wheel", "Blacksmithing", 1230171, 279944, "Strength", { { 2835, 1 }, { 2840, 1 } } },
    { "Enchanted Lute", "Enchanting", 1230643, 279976, "Armor, all stats and resistances", { { 4470, 1 }, { 10940, 1 } } },
    { "First Aid Kit", "First Aid", 1230117, 279968, "Stamina", { { 1251, 3 }, { 159, 1 } } },
    { "Fish Bowl", "Fishing", 1229745, 279967, "+8% all stats", { { 6291, 1 }, { 3371, 1 } } },
    { "Incense Candle", "Herbalism", 1229705, 279962, "Intellect", { { 2447, 1 }, { 765, 1 } } },
    { "Camp Tent", "Leatherworking", 1229432, 279978, "Rested experience", { { 2318, 5 } } },
    { "Lodestone", "Mining", 1230161, 279960, "Melee attack power", { { 2835, 1 }, { 2840, 1 } } },
    { "Camp Chair", "Skinning", 1229517, 279979, "+2% critical strike", { { 2318, 3 }, { 4470, 2 } } },
    { "Faction Banner", "Tailoring", 1263425, 279972, "Spirit, for your faction", { { 2996, 1 }, { 2320, 1 } } },
    { "Reagent Bot", "Engineering", 1230656, 279950, "Reagent vendor, sell items", { { 4359, 1 }, { 4361, 1 } } },
    -- Tier 2
    { "Fermenter", "Alchemy", 1263005, 279970, "Workstation for some reagents" },
    { "Anvil", "Blacksmithing", 1263041, 279988, "Blacksmithing anywhere" },
    { "Cookie's Feast", "Cooking", 1262978, 279957, "Stamina food" },
    { "Arcane Salvager", "Enchanting", 1263056, 279985, "Disenchanting station" },
    { "Repair Bot", "Engineering", 1263034, 279949, "Reagents, selling and repairs" },
    { "Toxin Study", "First Aid", 1262996, 279940, "Healing potions and anti-venom" },
    { "Fishing Rack", "Fishing", 1262990, 279965, "Lures and uncommon fish" },
    { "Greenhouse", "Herbalism", 1262980, 279964, "Grows herbs from seeds" },
    { "Tanning Rack", "Leatherworking", 1263031, 279941, "Workstation for some materials" },
    { "Rock Garden", "Mining", 1262975, 279948, "Slowly grows an ore node" },
    { "Field Guide", "Skinning", 1262985, 279969, "Track Beasts" },
    { "Spinning Wheel", "Tailoring", 1263032, 279943, "Workstation for some materials" },
    -- Tier 3
    { "Alchemy Laboratory", "Alchemy", 1263078, 279990, "Workstation for some recipes" },
    { "Master Forge", "Blacksmithing", 1263073, 279955, "Workstation for some plans" },
    { "Iron Oven", "Cooking", 1263067, 279982, "Workstation for some recipes" },
    { "Arcane Forge", "Enchanting", 1263082, 279987, "Workstation for some formulas" },
    { "Anarchist's Workbench", "Engineering", 1263083, 279989, "Workstation for some schematics" },
    { "Plague Doctor's Laboratory", "First Aid", 1263001, 279951, "Healing potions and poultices" },
    { "Fishing Hut", "Fishing", 1262998, 279966, "Lures and rare fish" },
    { "Seed Hybridizer", "Herbalism", 1263070, 279947, "Multiplies or converts seeds" },
    { "Sewing Machine", "Leatherworking", 1263079, 279945, "Workstation for some patterns" },
    { "Molten Foundry", "Mining", 1263071, 279952, "Workstation for some smelting" },
    { "Trapper's Workbench", "Skinning", 1262982, 279938, "Provides a trap" },
    { "Loom", "Tailoring", 1263080, 279959, "Workstation for some patterns" },
    -- No profession
    { "Scarlet Banner", nil, nil, 278030, "Cosmetic banner" },
}

local function Normalize(name)
    if not name then return nil end
    return (name:lower():gsub("\226\128\153", "'"):gsub("%s+kit$", ""))
end

local BY_NAME, BY_ITEM, BY_RECIPE = {}, {}, {}
for order, row in ipairs(OBJECTS) do
    local object = {
        order = order, name = row[1], profession = row[2], skillLine = row[2] and SKILL_LINE[row[2]],
        recipeID = row[3], itemID = row[4], effect = row[5], reagents = row[6],
    }
    BY_NAME[Normalize(object.name)] = object
    if object.itemID then BY_ITEM[object.itemID] = object end
    if object.recipeID then BY_RECIPE[object.recipeID] = object end
end
BY_NAME["fishing bowl"] = BY_NAME["fish bowl"] -- Blizzard's article calls it that

local function MatchName(name)
    if not name or name:find("^Blueprint") then return nil end
    return BY_NAME[Normalize(name)]
end

function Campfire:IsSupported()
    return BOLT.isForever
end

local bar
local state = {
    seatedAt = nil,      -- GetTime() when the player sat, until they move
    dismissed = false,   -- right-clicked, until Campfire Nearby goes away
    stillSince = nil,    -- GetTime() when the player last stopped moving
    autoSatThisStop = false,
    warmSpots = {},      -- { x, y, instance } where the fire warmed the player, this camp
    placedAt = nil,      -- GetTime() when the player last placed a camp object
    pendingCraft = nil,  -- recipeID waiting for its profession window
    craftTriedAt = nil,  -- GetTime() when we called CraftRecipe after the window opened
    clickAgain = nil,    -- recipeID whose craft didn't start: ask for another click
    openedForCraft = false,
    dirty = true,        -- gear rows need a rebuild (out of combat)
}

---------------------------------------------------------------------------
-- Game state
---------------------------------------------------------------------------

local function FindAura(name)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        return C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then return nil end
        if aura.name == name then return aura end
    end
end

local function IsMoving()
    return (GetUnitSpeed("player") or 0) > 0
end

local function CanSit()
    return not (InCombatLockdown() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or IsMounted()
        or IsSwimming() or IsFlying() or UnitOnTaxi("player") or UnitInVehicle("player"))
end

local function Position()
    local y, x, _, instance = UnitPosition("player")
    if x then return x, y, instance end
end

local function RememberWarmSpot()
    local x, y, instance = Position()
    if not x then return end
    for _, spot in ipairs(state.warmSpots) do
        if spot.instance == instance and (spot.x - x) ^ 2 + (spot.y - y) ^ 2 < 1 then return end
    end
    table.insert(state.warmSpots, { x = x, y = y, instance = instance })
    if #state.warmSpots > 30 then table.remove(state.warmSpots, 1) end
end

local function OnWarmSpot()
    local x, y, instance = Position()
    if not x then return false end
    for _, spot in ipairs(state.warmSpots) do
        if spot.instance == instance and (spot.x - x) ^ 2 + (spot.y - y) ^ 2 <= WARM_RADIUS ^ 2 then
            return true
        end
    end
    return false
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds >= 3600 then
        return ("%d h %02d min"):format(seconds / 3600, (seconds % 3600) / 60)
    elseif seconds >= 60 then
        return ("%d min"):format(math.ceil(seconds / 60))
    end
    return ("0:%02d"):format(seconds)
end

-- The Camp Benefits tooltip: "Gained the following camp benefits:", then "Object: effect" lines.
local function ReadBenefits(aura)
    local list = {}
    if not (aura and C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return list end
    local ok, data = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", aura.auraInstanceID)
    if not ok or not data or not data.lines then return list end
    for i = 2, #data.lines do
        for line in (data.lines[i].leftText or ""):gmatch("[^\n]+") do
            -- Strip colors and the |4singular:plural; grammar escape ("44 |4minute:minutes; remaining").
            line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|4[^:;]*:([^;]*);", "%1")
                :gsub("^%s+", ""):gsub("%s+$", "")
            local name, effect = line:match("^(.-):%s*(.+)$")
            if line:find("remaining") then
                -- the aura's time left, shown in the section header instead
            elseif name and not line:find("^Gained") then
                table.insert(list, { name = name, effect = effect, object = MatchName(name) })
            elseif line ~= "" and not line:find("^Gained") then
                table.insert(list, { effect = line })
            end
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Professions and recipes
---------------------------------------------------------------------------

-- skillLine -> { name, rank, opener (spell ID that opens its window) }
local function PlayerProfessions()
    local list = {}
    for _, index in ipairs({ GetProfessions() }) do
        local name, _, rank, _, numSpells, spellOffset, skillLine = GetProfessionInfo(index)
        if skillLine then
            local opener
            if numSpells and numSpells > 0 and C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
                local info = C_SpellBook.GetSpellBookItemInfo(spellOffset + 1, Enum.SpellBookSpellBank.Player)
                opener = info and (info.spellID or info.actionID)
            end
            list[skillLine] = { name = name, rank = rank, opener = opener }
        end
    end
    return list
end

-- Learned recipes seen in open profession windows: profile.campfire.learned[recipeID] = true.
local function Learned()
    local learned = BOLT:GetConfig("campfire", "learned")
    if type(learned) ~= "table" then
        learned = {}
        BOLT:SetConfig(learned, "campfire", "learned")
    end
    return learned
end

local function KnowsRecipe(object)
    if not object.recipeID then return false end
    if Learned()[object.recipeID] then return true end
    local info = C_TradeSkillUI.GetRecipeInfo and C_TradeSkillUI.GetRecipeInfo(object.recipeID)
    if info and info.learned then return true end
    return IsPlayerSpell and IsPlayerSpell(object.recipeID) or false
end

local schematicCache = {}
local function Reagents(object)
    local cached = schematicCache[object.recipeID]
    if cached then return cached end
    local ok, schematic = pcall(C_TradeSkillUI.GetRecipeSchematic, object.recipeID, false)
    if ok and schematic and schematic.reagentSlotSchematics and #schematic.reagentSlotSchematics > 0 then
        local list = {}
        for _, slot in ipairs(schematic.reagentSlotSchematics) do
            local reagent = slot.reagents and slot.reagents[1]
            if reagent and reagent.itemID and slot.required ~= false and (slot.quantityRequired or 0) > 0 then
                table.insert(list, { reagent.itemID, slot.quantityRequired })
            end
        end
        schematicCache[object.recipeID] = list
        return list
    end
    return object.reagents or {}
end

local function CraftableCount(object)
    local count = math.huge
    for _, reagent in ipairs(Reagents(object)) do
        count = math.min(count, math.floor(C_Item.GetItemCount(reagent[1]) / reagent[2]))
    end
    return count == math.huge and 0 or count
end

local function OpenProfession()
    if not (C_TradeSkillUI.IsTradeSkillReady and C_TradeSkillUI.IsTradeSkillReady()) then return nil end
    local base = C_TradeSkillUI.GetBaseProfessionInfo()
    return base and base.professionID
end

-- An open profession window tells us exactly which camp recipes this character knows.
local function ScanOpenProfession()
    local skillLine = OpenProfession()
    if not skillLine then return end
    local learned = Learned()
    for _, object in pairs(BY_RECIPE) do
        if object.skillLine == skillLine then learned[object.recipeID] = nil end
    end
    local list = (C_TradeSkillUI.GetAllRecipeIDs or C_TradeSkillUI.GetFilteredRecipeIDs)()
    for _, recipeID in ipairs(list or {}) do
        local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
        if info and info.learned then
            local object = BY_RECIPE[recipeID] or MatchName(info.name)
            if object then
                learned[object.recipeID or recipeID] = true
                if not object.recipeID then object.recipeID = recipeID end
            end
        end
    end
    state.dirty = true
end

local function CloseIfWeOpened()
    if not state.openedForCraft then return end
    state.openedForCraft = false
    C_TradeSkillUI.CloseTradeSkill()
end

---------------------------------------------------------------------------
-- Camp gear: what the player carries or can craft
---------------------------------------------------------------------------

local function BagCounts()
    local counts = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local object = BY_ITEM[info.itemID] or MatchName(info.itemName or C_Item.GetItemNameByID(info.itemID))
                if object then
                    object.itemID = object.itemID or info.itemID
                    object.icon = info.iconFileID
                    counts[object] = (counts[object] or 0) + (info.stackCount or 1)
                end
            end
        end
    end
    return counts
end

local function ObjectIcon(object)
    if object.icon then return object.icon end
    if object.itemID then
        local icon = C_Item.GetItemIconByID(object.itemID)
        if icon then object.icon = icon return icon end
    end
    if object.recipeID then
        local info = C_Spell.GetSpellInfo(object.recipeID)
        if info and info.iconID then return info.iconID end
    end
    return FALLBACK_ICON
end

-- Rows: objects in bags, then known recipes; plus a hint per profession with no camp recipe known.
local function GearList()
    local professions = PlayerProfessions()
    local counts = BagCounts()
    local list, hasRecipe = {}, {}
    for _, object in pairs(BY_NAME) do
        local prof = object.skillLine and professions[object.skillLine]
        local known = prof ~= nil and KnowsRecipe(object)
        if known then hasRecipe[object.skillLine] = true end
        if (counts[object] or 0) > 0 or (known and BOLT:GetConfig("campfire", "showCraft", true)) then
            if not list[object] then
                list[object] = { object = object, count = counts[object] or 0, known = known, profession = prof }
            end
        end
    end
    local rows = {}
    for _, row in pairs(list) do table.insert(rows, row) end
    table.sort(rows, function(a, b)
        if (a.count > 0) ~= (b.count > 0) then return a.count > 0 end
        return a.object.order < b.object.order
    end)
    if BOLT:GetConfig("campfire", "showCraft", true) then
        for skillLine, prof in pairs(professions) do
            -- Camp recipes start at skill 20: no hint before that.
            if not hasRecipe[skillLine] and prof.opener and (prof.rank or 0) >= 20 then
                for _, object in pairs(BY_RECIPE) do
                    if object.skillLine == skillLine then
                        table.insert(rows, { hint = true, profession = prof, skillLine = skillLine })
                        break
                    end
                end
            end
        end
    end
    return rows
end


---------------------------------------------------------------------------
-- Camp bar building blocks
---------------------------------------------------------------------------

local function SetColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function FadeTo(alpha, onDone)
    bar.fade:Stop()
    local from = bar:GetAlpha()
    if math.abs(alpha - from) < 0.01 then
        bar:SetAlpha(alpha)
        if onDone then onDone() end
        return
    end
    bar.fade.alpha:SetFromAlpha(from)
    bar.fade.alpha:SetToAlpha(alpha)
    bar.fade.alpha:SetDuration(FADE * math.abs(alpha - from))
    bar.fade.onDone = onDone
    bar.fade:Play()
end

local function Reveal()
    if bar.wanted then return end
    bar.wanted = true
    if not bar:IsShown() then
        bar:SetAlpha(0)
        bar:Show()
    end
    bar.glow.pulse:Play()
    FadeTo(1)
end

local function Conceal(instant)
    if not bar.wanted and not instant then return end
    bar.wanted = false
    local function done()
        bar:Hide()
        bar.glow.pulse:Stop()
    end
    if instant then
        bar.fade:Stop()
        bar:SetAlpha(0)
        done()
    else
        FadeTo(0, done)
    end
end

local function Sit()
    DoEmote("SIT")
    state.seatedAt = GetTime()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Campfire:Update()
end

-- Bronze (Forever) or dark (Midnight) Blizzard panel, the same art as BOLT's square minimap.
local function Panel(frame)
    if NativeArt.CreateBox(frame, BOX, true) then return end
    local backdrop = CreateFrame("Frame", nil, frame, "TooltipBackdropTemplate")
    backdrop:SetAllPoints()
    backdrop:SetFrameLevel(frame:GetFrameLevel())
    if backdrop.NineSlice and backdrop.NineSlice.SetCenterColor then
        backdrop.NineSlice:SetCenterColor(0.06, 0.04, 0.02, 0.92)
    end
end

local function SectionLabel(parent, text)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetText(text)
    label:SetJustifyH("LEFT")
    local extra = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    extra:SetJustifyH("RIGHT")
    SetColor(extra, GREY)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    local section = { label = label, extra = extra, line = line }
    function section:Place(y)
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", PAD, y)
        extra:ClearAllPoints()
        extra:SetPoint("TOPRIGHT", -PAD, y)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", PAD, y - 14)
        line:SetPoint("TOPRIGHT", -PAD, y - 14)
        return y - 20
    end
    function section:SetShown(shown)
        label:SetShown(shown)
        extra:SetShown(shown)
        line:SetShown(shown)
    end
    return section
end

---------------------------------------------------------------------------
-- Drawer rows
---------------------------------------------------------------------------

local function BenefitRow(index)
    local drawer = bar.drawer
    local row = drawer.benefitRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, drawer)
    row:SetSize(WIDTH - PAD * 2, BENEFIT_HEIGHT)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.effect = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.effect:SetPoint("LEFT", row.name, "RIGHT", 6, 0)
    row.effect:SetPoint("RIGHT", 0, 0)
    row.effect:SetJustifyH("RIGHT")
    row.effect:SetWordWrap(false)
    SetColor(row.effect, GREEN)
    drawer.benefitRows[index] = row
    return row
end

-- Craft: when the profession is open, craft right away; otherwise this click casts the
-- profession spell (opening its window) and the craft fires when the window is ready.
local function CraftPreClick(self)
    if InCombatLockdown() then return end
    local data = self:GetParent().data
    local object = data.object
    self:SetAttribute("type", nil)
    state.clickAgain = nil
    if OpenProfession() == object.skillLine then
        C_TradeSkillUI.CraftRecipe(object.recipeID, 1)
    elseif data.profession and data.profession.opener then
        state.pendingCraft = object.recipeID
        state.openedForCraft = true
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", data.profession.opener)
    end
end

local function RowTooltip(self)
    local data = self.data or self:GetParent().data
    if not data then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if data.hint then
        GameTooltip:SetText(data.profession.name, 1, 1, 1)
        GameTooltip:AddLine("BOLT hasn't seen a camp recipe for this profession yet. Click Open once; "
            .. "the camp recipes you know then show here.", nil, nil, nil, true)
        GameTooltip:Show()
        return
    end
    local object = data.object
    GameTooltip:SetText(object.name, 1, 1, 1)
    if object.effect then GameTooltip:AddLine(object.effect, GOLD[1], GOLD[2], GOLD[3], true) end
    if data.known then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(("Craft (%s):"):format(object.profession), 1, 1, 1)
        for _, reagent in ipairs(Reagents(object)) do
            local have = C_Item.GetItemCount(reagent[1])
            local color = have >= reagent[2] and GREEN or RED
            GameTooltip:AddDoubleLine(C_Item.GetItemNameByID(reagent[1]) or ("Item " .. reagent[1]),
                ("%d/%d"):format(have, reagent[2]), 0.85, 0.85, 0.85, color[1], color[2], color[3])
        end
    end
    if data.count > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("One object per character per camp, then a 1 hour cooldown.", GREY[1], GREY[2], GREY[3], true)
    end
    GameTooltip:Show()
end

local function RowButton(row, label, width)
    local button = CreateFrame("Button", nil, row, "SecureActionButtonTemplate,UIPanelButtonTemplate")
    button:SetSize(width, 20)
    button:SetText(label)
    button:RegisterForClicks("AnyUp") -- secure buttons act on release on this client
    button:SetAttribute("useOnKeyDown", false)
    button:SetScript("OnEnter", RowTooltip)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function GearRow(index)
    local drawer = bar.drawer
    local row = drawer.gearRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, drawer)
    row:SetSize(WIDTH - PAD * 2 + 4, ROW_HEIGHT)
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.border = row:CreateTexture(nil, "OVERLAY")
    row.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    row.border:SetPoint("TOPLEFT", row.icon, -10, 10)
    row.border:SetPoint("BOTTOMRIGHT", row.icon, 10, -10)
    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, -1, 1)

    -- Place uses the item in your bags; Craft makes one more.
    row.place = RowButton(row, "Place", 54)
    row.place:SetPoint("RIGHT", -2, 0)
    row.place:SetAttribute("type", "item")
    row.place:SetScript("PreClick", function() state.placedAt = GetTime() end)
    row.craft = RowButton(row, "Craft", 54)
    row.craft:SetScript("PreClick", CraftPreClick)
    row.open = RowButton(row, "Open", 54)
    row.open:SetPoint("RIGHT", -2, 0)
    row.open:SetAttribute("type", "spell")

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)

    drawer.gearRows[index] = row
    return row
end

-- Fits a 54px button: "42m", "35s".
local function ShortTime(seconds)
    seconds = math.max(0, seconds)
    if seconds >= 60 then return ("%dm"):format(math.ceil(seconds / 60)) end
    return ("%ds"):format(math.ceil(seconds))
end

-- "Missing: 2 Light Leather, 1 Coarse Thread"
local function MissingText(object)
    local parts = {}
    for _, reagent in ipairs(Reagents(object)) do
        local short = reagent[2] - C_Item.GetItemCount(reagent[1])
        if short > 0 then
            table.insert(parts, ("%d %s"):format(short, C_Item.GetItemNameByID(reagent[1]) or ("item " .. reagent[1])))
        end
    end
    return #parts > 0 and ("Missing: " .. table.concat(parts, ", ")) or nil
end

-- Out of combat only (secure buttons inside).
local function FillGearRow(row, data)
    row.data = data
    row.icon:SetDesaturated(false)
    row.count:SetText("")
    row.place:Hide()
    row.craft:Hide()
    row.open:Hide()

    if data.hint then
        row.icon:SetTexture(C_Spell.GetSpellTexture(data.profession.opener) or FALLBACK_ICON)
        row.name:SetText(data.profession.name)
        row.detail:SetText("Open it once to list its camp recipes")
        SetColor(row.detail, GREY)
        row.open:SetAttribute("spell", data.profession.opener)
        row.open:Show()
        row.name:SetPoint("RIGHT", row.open, "LEFT", -6, 0)
        row.detail:SetPoint("RIGHT", row.open, "LEFT", -6, 0)
        return
    end

    local object = data.object
    row.icon:SetTexture(ObjectIcon(object))
    row.name:SetText(object.name)
    row.detail:SetText(object.effect or "")
    SetColor(row.detail, GREY)
    local leftmost

    if data.count > 0 then
        row.count:SetText(data.count > 1 and data.count or "")
        row.place:SetAttribute("item", "item:" .. object.itemID)
        local start, duration = C_Container.GetItemCooldown(object.itemID)
        if duration and duration > 2 then
            row.place:SetText(ShortTime(start + duration - GetTime()))
            row.place:Disable()
        else
            row.place:SetText("Place")
            row.place:Enable()
        end
        row.place:Show()
        leftmost = row.place
    end

    if data.known then
        local craftable = CraftableCount(object)
        row.craft:ClearAllPoints()
        if leftmost then
            row.craft:SetPoint("RIGHT", leftmost, "LEFT", -2, 0)
        else
            row.craft:SetPoint("RIGHT", -2, 0)
        end
        if state.clickAgain == object.recipeID then
            row.craft:SetText("Again")
            row.craft:Enable()
        elseif craftable > 0 then
            row.craft:SetText("Craft")
            row.craft:Enable()
        else
            row.craft:SetText("Craft")
            row.craft:Disable()
            if data.count == 0 then row.icon:SetDesaturated(true) end
            local missing = MissingText(object)
            if missing then
                row.detail:SetText(missing)
                SetColor(row.detail, RED)
            end
        end
        if craftable > 1 and data.count == 0 then row.count:SetText(craftable) end
        row.craft:Show()
        leftmost = row.craft
    end

    row.name:SetPoint("RIGHT", leftmost or row, leftmost and "LEFT" or "RIGHT", -6, 0)
    row.detail:SetPoint("RIGHT", leftmost or row, leftmost and "LEFT" or "RIGHT", -6, 0)
end

---------------------------------------------------------------------------
-- The bar
---------------------------------------------------------------------------

local function BarTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Campfire", 1, 1, 1)
    local benefits = ReadBenefits(FindAura(AURA_BENEFITS))
    for _, benefit in ipairs(benefits) do
        GameTooltip:AddDoubleLine(benefit.name or "", benefit.effect or "", 0.85, 0.85, 0.85, GREEN[1], GREEN[2], GREEN[3])
    end
    if #benefits > 0 then GameTooltip:AddLine(" ") end
    GameTooltip:AddLine(BOLT:GetConfig("campfire", "expanded", false) and "Click to fold the camp details away."
        or "Click for camp benefits and your camp gear.", nil, nil, nil, true)
    GameTooltip:AddLine("Right-click to hide the bar until the next fire.", GREY[1], GREY[2], GREY[3], true)
    GameTooltip:AddLine("Move it in Edit Mode.", GREY[1], GREY[2], GREY[3], true)
    GameTooltip:Show()
end

local function BuildDrawer()
    local drawer = CreateFrame("Frame", nil, bar)
    drawer:SetWidth(WIDTH)
    drawer:Hide()
    Panel(drawer)
    drawer.benefitSection = SectionLabel(drawer, "Camp benefits")
    drawer.benefitEmpty = drawer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    drawer.benefitEmpty:SetJustifyH("LEFT")
    drawer.benefitEmpty:SetWidth(WIDTH - PAD * 2)
    SetColor(drawer.benefitEmpty, GREY)
    drawer.benefitRows = {}
    drawer.gearSection = SectionLabel(drawer, "Your camp gear")
    drawer.gearEmpty = drawer:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    drawer.gearEmpty:SetJustifyH("LEFT")
    drawer.gearEmpty:SetWidth(WIDTH - PAD * 2)
    SetColor(drawer.gearEmpty, GREY)
    drawer.gearRows = {}
    bar.drawer = drawer
end

local function BuildBar()
    bar = CreateFrame("Button", "BOLTCampBar", UIParent)
    bar:SetFrameStrata("MEDIUM")
    bar:SetSize(WIDTH, BAR_HEIGHT)
    bar:SetClampedToScreen(true)
    bar:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bar:Hide()
    Panel(bar)

    local icon = bar:CreateTexture(nil, "ARTWORK")
    icon:SetSize(30, 30)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    bar.icon = icon
    local iconBorder = bar:CreateTexture(nil, "OVERLAY")
    iconBorder:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    iconBorder:SetPoint("TOPLEFT", icon, -11, 11)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, 11, -11)

    -- Soft breathing glow behind the icon; a brighter burst when Camp Benefits lands.
    local glow = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.55, 0.15)
    glow:SetSize(58, 58)
    glow:SetPoint("CENTER", icon)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local breathe = pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(0.2)
    breathe:SetToAlpha(0.7)
    breathe:SetDuration(1.4)
    breathe:SetSmoothing("IN_OUT")
    glow.pulse = pulse
    bar.glow = glow

    local burst = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    burst:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    burst:SetBlendMode("ADD")
    burst:SetVertexColor(0.5, 1, 0.4)
    burst:SetSize(64, 64)
    burst:SetPoint("CENTER", icon)
    burst:SetAlpha(0)
    local flash = burst:CreateAnimationGroup()
    local grow = flash:CreateAnimation("Scale")
    grow:SetScaleFrom(0.6, 0.6)
    grow:SetScaleTo(1.4, 1.4)
    grow:SetDuration(0.6)
    local appear = flash:CreateAnimation("Alpha")
    appear:SetFromAlpha(0)
    appear:SetToAlpha(1)
    appear:SetDuration(0.15)
    local vanish = flash:CreateAnimation("Alpha")
    vanish:SetFromAlpha(1)
    vanish:SetToAlpha(0)
    vanish:SetStartDelay(0.6)
    vanish:SetDuration(0.8)
    flash:SetLooping("NONE")
    bar.burst = flash

    -- Fold arrow (far right) and Sit button.
    local arrow = bar:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -8, 0)
    bar.arrow = arrow

    local sit = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
    sit:SetSize(46, 20)
    sit:SetPoint("RIGHT", arrow, "LEFT", -4, 0)
    sit:SetText("Sit")
    sit:SetScript("OnClick", function() Sit() end)
    sit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Sit by the fire", 1, 1, 1)
        GameTooltip:AddLine("Sit right next to the flames for a minute to get the camp's benefits; "
            .. "sit again after new objects are placed to add theirs.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    sit:SetScript("OnLeave", GameTooltip_Hide)
    bar.sit = sit

    bar.title = bar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    bar.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    bar.title:SetJustifyH("LEFT")
    bar.title:SetWordWrap(false)

    bar.subtitle = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    bar.subtitle:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 0)
    bar.subtitle:SetJustifyH("LEFT")
    bar.subtitle:SetWordWrap(false)
    bar.subtitle:SetTextColor(0.85, 0.85, 0.85)

    -- Warm-up / time-left bar under the title, in the Personal Resource Display's bar art.
    local progress = CreateFrame("StatusBar", nil, bar)
    progress:SetHeight(9)
    progress:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 1)
    local fill = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar")
    local back = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar-BG")
    progress:SetStatusBarTexture(fill or "Interface\\TargetingFrame\\UI-StatusBar")
    progress.bg = progress:CreateTexture(nil, "BACKGROUND")
    if back then
        progress.bg:SetAtlas(back)
        progress.bg:SetPoint("TOPLEFT", -2, 3)
        progress.bg:SetPoint("BOTTOMRIGHT", 6, -7)
    else
        progress.bg:SetAllPoints()
        progress.bg:SetColorTexture(0, 0, 0, 0.7)
    end
    progress.text = progress:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    progress.text:SetPoint("CENTER", 0, 0)
    progress.text:SetScale(0.9)
    progress:Hide()
    bar.progress = progress

    local highlight = bar:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.75, 0.35, 0.15)
    highlight:SetPoint("TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", -4, 4)

    bar:SetScript("OnClick", function(_, button)
        if state.preview then return end
        if button == "RightButton" then
            state.dismissed = true
            Campfire:Update()
        elseif not InCombatLockdown() then
            BOLT:SetConfig(not BOLT:GetConfig("campfire", "expanded", false), "campfire", "expanded")
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Campfire:Layout()
        end
    end)
    bar:SetScript("OnEnter", function(self) if not state.preview then BarTooltip(self) end end)
    bar:SetScript("OnLeave", GameTooltip_Hide)

    BuildDrawer()

    local fade = bar:CreateAnimationGroup()
    fade.alpha = fade:CreateAnimation("Alpha")
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function(self)
        if self.onDone then self.onDone() end
    end)
    bar.fade = fade

    bar.elapsed = 0
    bar:SetScript("OnUpdate", function(_, elapsed)
        bar.elapsed = bar.elapsed + elapsed
        if bar.elapsed < 0.25 then return end
        bar.elapsed = 0
        if not state.preview then Campfire:Tick() end
    end)
end

---------------------------------------------------------------------------
-- Placement: beside the minimap (left by default, right, above, under) or free (dragged in
-- Edit Mode). Saved per Edit Mode layout.
---------------------------------------------------------------------------

local function Anchor() return EditMode:Get(EDIT_KEY, "anchor", "LEFT") end
local function Scale() return (EditMode:Get(EDIT_KEY, "scale", 100) or 100) / 100 end

-- The minimap and everything framed around it, in UIParent coordinates (Core/Utils.lua).
local function MinimapBounds()
    return BOLT.MinimapBounds()
end

local function PlaceDrawer()
    local drawer = bar.drawer
    drawer:ClearAllPoints()
    local scale = bar:GetEffectiveScale() / UIParent:GetEffectiveScale()
    local bottom = (bar:GetBottom() or 0) * scale
    local opensDown = bottom > UIParent:GetHeight() / 2
    if opensDown then
        drawer:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -GAP)
    else
        drawer:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, GAP)
    end
    local expanded = drawer:IsShown()
    -- Arrow points where the drawer opens (or closes back to).
    local down = (opensDown and not expanded) or (not opensDown and expanded)
    bar.arrow:SetTexture(down and "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
        or "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
end

function Campfire:Place()
    if not bar or InCombatLockdown() then return end
    local scale = Scale()
    bar:SetScale(scale)
    bar:ClearAllPoints()
    local anchor = Anchor()
    local l, r, t, b
    if anchor ~= "FREE" then l, r, t, b = MinimapBounds() end
    if anchor == "FREE" or not l then
        local point, x, y = EditMode:GetPosition(EDIT_KEY)
        bar:SetPoint(point, UIParent, point, x, y)
    elseif anchor == "RIGHT" then
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (r + GAP * 3) / scale, t / scale)
    elseif anchor == "TOP" then
        bar:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", (l + r) / 2 / scale, (t + GAP * 3) / scale)
    elseif anchor == "BOTTOM" then
        bar:SetPoint("TOP", UIParent, "BOTTOMLEFT", (l + r) / 2 / scale, (b - GAP * 3) / scale)
    else
        bar:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", (l - GAP * 3) / scale, t / scale)
    end
    PlaceDrawer()
end

---------------------------------------------------------------------------
-- Drawer layout (rebuilds secure rows: out of combat only)
---------------------------------------------------------------------------

function Campfire:Layout()
    if InCombatLockdown() or not bar then return end
    local drawer = bar.drawer
    local expanded = BOLT:GetConfig("campfire", "expanded", false) and not state.preview
    bar.layoutExpanded = expanded
    if not expanded then
        drawer:Hide()
        PlaceDrawer()
        return
    end

    local y = -10
    -- Camp benefits
    local benefits = bar.benefits or {}
    for i, row in ipairs(drawer.benefitRows) do
        if i > #benefits then row:Hide() end
    end
    y = drawer.benefitSection:Place(y)
    if #benefits == 0 then
        drawer.benefitEmpty:ClearAllPoints()
        drawer.benefitEmpty:SetPoint("TOPLEFT", PAD, y - 2)
        drawer.benefitEmpty:SetText(FindAura(AURA_WARMING) and "Revealed when the bar fills."
            or "Sit by the fire for a minute to gain the camp's benefits.")
        drawer.benefitEmpty:Show()
        y = y - drawer.benefitEmpty:GetStringHeight() - 8
    else
        drawer.benefitEmpty:Hide()
        for i, benefit in ipairs(benefits) do
            local row = BenefitRow(i)
            row.icon:SetTexture(benefit.object and ObjectIcon(benefit.object) or FALLBACK_ICON)
            row.name:SetText(benefit.name or "")
            row.effect:SetText(benefit.effect or "")
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD, y)
            row:Show()
            y = y - BENEFIT_HEIGHT
        end
    end
    y = y - 8

    -- Camp gear
    local gear = bar.gear or {}
    for i, row in ipairs(drawer.gearRows) do
        if i > #gear then row:Hide() end
    end
    y = drawer.gearSection:Place(y)
    if #gear == 0 then
        drawer.gearEmpty:ClearAllPoints()
        drawer.gearEmpty:SetPoint("TOPLEFT", PAD, y - 2)
        drawer.gearEmpty:SetText("No camp objects in your bags, and no camp recipes known yet.")
        drawer.gearEmpty:Show()
        y = y - drawer.gearEmpty:GetStringHeight() - 8
    else
        drawer.gearEmpty:Hide()
        for i, data in ipairs(gear) do
            local row = GearRow(i)
            FillGearRow(row, data)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD - 4, y)
            row:Show()
            y = y - ROW_HEIGHT - 2
        end
    end

    drawer:SetHeight(-y + 8)
    drawer:Show()
    PlaceDrawer()
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

local function ReadyAlert()
    if not BOLT:GetConfig("campfire", "readyAlert", true) then return end
    PlaySound(SOUNDKIT.READY_CHECK or 8960)
    bar.burst:Stop()
    bar.burst:Play()
    if FlashClientIcon then FlashClientIcon() end
end

local function ShowProgress(value, max, text, color)
    local progress = bar.progress
    progress:SetMinMaxValues(0, max)
    progress:SetValue(value)
    progress:SetStatusBarColor(color[1], color[2], color[3])
    progress.text:SetText(text)
    progress:SetPoint("RIGHT", bar.sit:IsShown() and bar.sit or bar.arrow, "LEFT", -8, 0)
    progress:Show()
    bar.subtitle:Hide()
end

local function ShowSubtitle(text)
    bar.progress:Hide()
    bar.subtitle:SetText(text)
    bar.subtitle:SetPoint("RIGHT", bar.sit:IsShown() and bar.sit or bar.arrow, "LEFT", -6, 0)
    bar.subtitle:Show()
end

-- Status line, progress and range verdict; runs four times a second while the bar is up.
function Campfire:Tick()
    local now = GetTime()
    if IsMoving() then
        state.stillSince, state.autoSatThisStop = nil, false
    elseif not state.stillSince then
        state.stillSince = now
    end

    local warming = FindAura(AURA_WARMING)
    local benefits = FindAura(AURA_BENEFITS)
    if warming and not state.seatedAt then state.seatedAt = now end -- sat on their own (/sit)
    local seated = state.seatedAt ~= nil

    -- Camp Benefits just landed (or refreshed with new objects) while sitting by this fire.
    local benefitsUntil = benefits and benefits.expirationTime or nil
    if benefitsUntil and benefitsUntil ~= state.benefitsUntil and state.wasWarming then
        ReadyAlert()
        state.wasWarming = false
    end
    state.benefitsUntil = benefitsUntil
    if warming and seated then state.wasWarming = true end

    local range -- "in", "far" or nil (unknown)
    if seated and warming then
        range = "in"
        RememberWarmSpot()
    elseif seated and now - state.seatedAt >= TOO_FAR_AFTER then
        range = "far"
    elseif not seated and OnWarmSpot() then
        range = "in"
    end

    -- Auto-sit on a spot where the fire warmed you, when sitting would gain something:
    -- no Camp Benefits yet, or you just placed an object.
    local wantsBenefits = not benefits or (state.placedAt and (not benefits.expirationTime
        or benefits.expirationTime - benefits.duration < state.placedAt))
    if BOLT:GetConfig("campfire", "autoSit", true) and range == "in" and not seated and not warming
        and wantsBenefits and not state.autoSatThisStop and state.stillSince
        and now - state.stillSince >= AUTO_SIT_STILL and CanSit() then
        state.autoSatThisStop = true
        Sit()
        return
    end

    -- Craft that never started after its window opened: ask for another click.
    if state.craftTriedAt and now - state.craftTriedAt > CRAFT_RETRY_HINT then
        state.clickAgain, state.craftTriedAt = state.pendingCraftShown, nil
        state.dirty = true
    end

    bar.sit:SetShown(not seated and not warming)
    if seated and warming then
        local duration = warming.duration and warming.duration > 0 and warming.duration or WARM_UP
        local left = warming.expirationTime and warming.expirationTime > 0 and warming.expirationTime - now
            or duration - (now - state.seatedAt)
        bar.title:SetText("Warming up")
        SetColor(bar.title, GOLD)
        ShowProgress(duration - left, duration, ("Camp benefits in %s"):format(FormatTime(left)), ORANGE)
    elseif range == "far" then
        bar.title:SetText("Too far from the fire")
        SetColor(bar.title, RED)
        ShowSubtitle("Stand up, step closer and sit again")
    elseif seated then
        bar.title:SetText("Sitting down...")
        SetColor(bar.title, GOLD)
        ShowSubtitle("Checking the fire's warmth")
    elseif benefits then
        local left = benefits.expirationTime and benefits.expirationTime > 0 and benefits.expirationTime - now
        bar.title:SetText("Camp benefits active")
        SetColor(bar.title, GREEN)
        if left and benefits.duration and benefits.duration > 0 then
            ShowProgress(left, benefits.duration, ("%s left"):format(FormatTime(left)), GREEN)
        else
            ShowSubtitle("Sit again to add new objects")
        end
    else
        bar.title:SetText("Sit by the fire")
        SetColor(bar.title, GOLD)
        ShowSubtitle(range == "in" and "You're close enough" or "Right next to the flames")
    end
    bar.title:SetPoint("RIGHT", bar.sit:IsShown() and bar.sit or bar.arrow, "LEFT", -6, 0)
    local benefitsLeft = benefits and benefits.expirationTime and benefits.expirationTime > 0
        and benefits.expirationTime - now
    bar.drawer.benefitSection.extra:SetText(benefitsLeft and (FormatTime(benefitsLeft) .. " left") or "")

    -- Benefits change rarely: compare a signature before relayouting.
    local list = ReadBenefits(benefits)
    local signature = {}
    for _, benefit in ipairs(list) do table.insert(signature, (benefit.name or "") .. benefit.effect) end
    signature = table.concat(signature, "|")
    local expanded = BOLT:GetConfig("campfire", "expanded", false)
    if (signature ~= bar.benefitSignature or expanded ~= bar.layoutExpanded or state.dirty)
        and not InCombatLockdown() then
        bar.benefitSignature = signature
        bar.benefits = list
        if state.dirty then
            state.dirty = false
            bar.gear = GearList()
        end
        self:Layout()
    end
end

function Campfire:Update()
    if not bar or state.preview then return end
    if InCombatLockdown() then return end

    local nearby = self.active and FindAura(AURA_NEARBY)
    if not nearby then
        state.dismissed, state.seatedAt, state.placedAt, state.wasWarming = false, nil, nil, false
        wipe(state.warmSpots)
        return Conceal()
    end
    bar.icon:SetTexture(nearby.icon or FALLBACK_ICON)
    if state.dismissed or not CanSit() then
        return Conceal()
    end
    self:Place()
    self:Tick()
    Reveal()
end

---------------------------------------------------------------------------
-- Edit Mode: preview, position and options
---------------------------------------------------------------------------

local ANCHORS = {
    { text = "Left of the minimap", value = "LEFT" },
    { text = "Right of the minimap", value = "RIGHT" },
    { text = "Above the minimap", value = "TOP" },
    { text = "Under the minimap", value = "BOTTOM" },
    { text = "Free (where you drag it)", value = "FREE" },
}

local function ShowPreview()
    if not (Campfire.active and bar) then return end
    state.preview = true
    bar.drawer:Hide()
    bar.icon:SetTexture(FALLBACK_ICON)
    bar.title:SetText("Campfire")
    SetColor(bar.title, GOLD)
    bar.sit:Hide()
    ShowProgress(40, WARM_UP, "Camp bar", ORANGE)
    Campfire:Place()
    bar.fade:Stop()
    bar.wanted = true
    bar:SetAlpha(1)
    bar:Show()
end

local function EndPreview()
    if not state.preview then return end
    state.preview = false
    Conceal(true)
    state.dirty = true
    Campfire:Update()
end

function Campfire:RegisterEditMode()
    if self.editModeRegistered or not EditMode.available then return end
    self.editModeRegistered = true
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "Camp Bar",
        frame = bar,
        default = { point = "TOPRIGHT", x = -250, y = -40 },
        onEnter = ShowPreview,
        onExit = EndPreview,
        onMoved = function(layoutName)
            EditMode:Set(EDIT_KEY, "anchor", "FREE", layoutName)
            EditMode:RefreshFrame(EDIT_KEY)
        end,
        apply = function() Campfire:Place() end,
        settings = {
            EditMode:Dropdown("Position", nil, ANCHORS, {
                default = "LEFT",
                desc = "Beside the minimap (it follows the minimap), or free where you drag it.",
                get = function() return Anchor() end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "anchor", value)
                    Campfire:Place()
                end,
            }),
            EditMode:Slider("Size", nil, {
                min = 50, max = 150, step = 5, default = 100, format = EditMode.Percent,
                get = function() return EditMode:Get(EDIT_KEY, "scale", 100) end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "scale", value)
                    Campfire:Place()
                end,
            }),
            EditMode:Checkbox("Sit down on its own", { "campfire", "autoSit" }, {
                desc = "Sit again when you stop where the fire warmed you, if you have no camp benefits yet or just placed an object.",
            }),
            EditMode:Checkbox("Ready alert", { "campfire", "readyAlert" }, {
                desc = "A sound, a glow and a taskbar flash when Camp Benefits lands.",
            }),
            EditMode:Checkbox("Show camp recipes you can craft", { "campfire", "showCraft" }),
        },
    })
end

---------------------------------------------------------------------------
-- Debug: /bolt camp
---------------------------------------------------------------------------

function Campfire:PrintDebug()
    BOLT:Print("=== Campfire ===")
    for _, name in ipairs({ AURA_NEARBY, AURA_WARMING, AURA_BENEFITS }) do
        local aura = FindAura(name)
        if aura then
            local left = aura.expirationTime and aura.expirationTime > 0 and (aura.expirationTime - GetTime()) or 0
            print(("  %s: spell %s, duration %s, %ds left"):format(name, tostring(aura.spellId),
                tostring(aura.duration), left))
        else
            print(("  %s: no"):format(name))
        end
    end
    for _, benefit in ipairs(ReadBenefits(FindAura(AURA_BENEFITS))) do
        print(("    %s -> %s%s"):format(benefit.name or "?", benefit.effect,
            benefit.object and "" or " (unknown object)"))
    end
    local x, y, instance = Position()
    print(("  position = %s, warm spots = %d, on a warm spot = %s"):format(
        x and ("%.1f, %.1f (%d)"):format(x, y, instance) or "unavailable", #state.warmSpots, tostring(OnWarmSpot())))
    print(("  moving = %s, can sit = %s, seated = %s"):format(tostring(IsMoving()), tostring(CanSit()),
        tostring(state.seatedAt ~= nil)))
    print("  Professions:")
    for skillLine, prof in pairs(PlayerProfessions()) do
        local opener = prof.opener and C_Spell.GetSpellName(prof.opener)
        print(("    %s (%d, rank %s), opens with %s (%s)"):format(prof.name, skillLine, tostring(prof.rank),
            tostring(opener), tostring(prof.opener)))
    end
    print("  Camp gear rows:")
    for _, data in ipairs(GearList()) do
        if data.hint then
            print(("    hint: open %s"):format(data.profession.name))
        else
            local object = data.object
            local info = object.recipeID and C_TradeSkillUI.GetRecipeInfo(object.recipeID)
            print(("    %s: in bags %d, known %s (seen %s, recipeInfo %s, IsPlayerSpell %s), can craft %d"):format(
                object.name, data.count, tostring(data.known), tostring(Learned()[object.recipeID] == true),
                tostring(info and info.learned), tostring(object.recipeID and IsPlayerSpell(object.recipeID)),
                data.known and CraftableCount(object) or 0))
        end
    end
end

---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Campfire:OnInitialize()
    BuildBar()
    self:RegisterEditMode()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Fires just before combat lockdown: last chance to hide the secure buttons.
            Conceal(true)
            return
        elseif event == "PLAYER_STARTED_MOVING" then
            state.seatedAt = nil
        elseif event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_SHOW" then
            ScanOpenProfession()
            local pending = state.pendingCraft
            local object = pending and BY_RECIPE[pending]
            if object and OpenProfession() == object.skillLine then
                state.pendingCraft = nil
                state.pendingCraftShown = pending
                state.craftTriedAt = GetTime()
                C_TradeSkillUI.CraftRecipe(pending, 1)
            end
        elseif event == "UNIT_SPELLCAST_START" then
            if BY_RECIPE[spellID] then
                state.craftTriedAt, state.clickAgain = nil, nil
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if BY_RECIPE[spellID] then
                state.craftTriedAt, state.clickAgain = nil, nil
                CloseIfWeOpened()
            end
            state.dirty = true
        elseif event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE_COOLDOWN" or event == "SKILL_LINES_CHANGED"
            or event == "LEARNED_SPELL_IN_SKILL_LINE" then
            state.dirty = true
        end
        self:Update()
    end)
end

function Campfire:OnSettingChanged()
    state.dirty = true
    if state.preview then return end
    self:Update()
end

function Campfire:OnEnable()
    local events = self.eventFrame
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    for _, event in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD",
        "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "BAG_UPDATE_DELAYED", "BAG_UPDATE_COOLDOWN",
        "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE" }) do
        events:RegisterEvent(event)
    end
    state.dirty = true
    if EditMode:IsActive() then
        ShowPreview()
    else
        self:Update()
    end
end

function Campfire:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    state.pendingCraft, state.openedForCraft = nil, false
    state.preview = false
    Conceal(true)
end

BOLT:RegisterModule("campfire", Campfire)
