-- B.O.L.T Campfire Module (WoW: Forever only)
-- While the "Campfire Nearby" buff is on you (it reaches ~100 yards), a camp panel fades in above
-- the action bars:
--   * Header: sit by the fire (click), with an "In range" / "Too far" verdict.
--   * Warm-up bar: the minute of sitting until Welcoming Campfire turns into Camp Benefits.
--   * Camp benefits: one row per camp object, read from the Camp Benefits tooltip.
--   * Your camp gear: one row per camp object you carry or can craft. Left-click places the one in
--     your bags (or crafts it), right-click crafts another.
--
-- Range: the game gives no distance to the fire (Campfire Nearby covers ~100 yards and the
-- Cooking spell-focus check ignores campfires, tested 2026-11-07). What we do know:
--   seated + Welcoming Campfire          = close enough (and we remember that spot),
--   seated + no Welcoming after a moment = too far,
--   standing on a remembered spot        = close enough; auto-sit happens there.
--
-- Crafting: opening a profession is a spellbook cast, so every gear row is a secure button. When
-- the profession is already open, PreClick crafts directly; otherwise the click casts the
-- profession spell and the craft fires once its window is ready (click again if it didn't).
--
-- Camp recipes ship with the addon (OBJECTS); open profession windows refine what you know.
-- `/bolt camp` prints what the module sees, for bug reports.

local ADDON_NAME, BOLT = ...

local Campfire = {
    displayName = "Campfire",
}

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
local WIDTH = 300
local PAD = 12
local ROW_HEIGHT = 34
local BENEFIT_HEIGHT = 20

local GREEN = { 0.45, 1, 0.45 }
local RED = { 1, 0.4, 0.3 }
local GOLD = { 1, 0.82, 0 }
local GREY = { 0.65, 0.65, 0.65 }

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

local prompt
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
-- Panel building blocks
---------------------------------------------------------------------------

local function FadeTo(alpha, onDone)
    prompt.fade:Stop()
    local from = prompt:GetAlpha()
    if math.abs(alpha - from) < 0.01 then
        prompt:SetAlpha(alpha)
        if onDone then onDone() end
        return
    end
    prompt.fade.alpha:SetFromAlpha(from)
    prompt.fade.alpha:SetToAlpha(alpha)
    prompt.fade.alpha:SetDuration(FADE * math.abs(alpha - from))
    prompt.fade.onDone = onDone
    prompt.fade:Play()
end

local function Reveal()
    if prompt.wanted then return end
    prompt.wanted = true
    if not prompt:IsShown() then
        prompt:SetAlpha(0)
        prompt:Show()
    end
    prompt.glow.pulse:Play()
    FadeTo(1)
end

local function Conceal(instant)
    if not prompt.wanted and not instant then return end
    prompt.wanted = false
    local function done()
        prompt:Hide()
        prompt.glow.pulse:Stop()
    end
    if instant then
        prompt.fade:Stop()
        prompt:SetAlpha(0)
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

local function SetColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end

local function CreateSection(label)
    local section = {}
    section.label = prompt:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    section.label:SetText(label)
    section.label:SetJustifyH("LEFT")
    section.extra = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    section.extra:SetJustifyH("RIGHT")
    SetColor(section.extra, GREY)
    section.line = prompt:CreateTexture(nil, "ARTWORK")
    section.line:SetColorTexture(1, 0.82, 0, 0.25)
    section.line:SetHeight(1)
    function section:Place(y)
        self.label:ClearAllPoints()
        self.label:SetPoint("TOPLEFT", PAD, y)
        self.extra:ClearAllPoints()
        self.extra:SetPoint("TOPRIGHT", -PAD, y)
        self.line:ClearAllPoints()
        self.line:SetPoint("TOPLEFT", PAD, y - 14)
        self.line:SetPoint("TOPRIGHT", -PAD, y - 14)
        return y - 20
    end
    function section:SetShown(shown)
        self.label:SetShown(shown)
        self.extra:SetShown(shown)
        self.line:SetShown(shown)
    end
    return section
end

local function BenefitRow(index)
    local row = prompt.benefitRows[index]
    if row then return row end
    row = CreateFrame("Frame", nil, prompt)
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
    prompt.benefitRows[index] = row
    return row
end

---------------------------------------------------------------------------
-- Gear rows (secure: place an item, or open a profession and craft)
---------------------------------------------------------------------------

local function GearPreClick(self, mouseButton)
    if InCombatLockdown() then return end
    local action = mouseButton == "RightButton" and self.rightAction or self.leftAction
    self:SetAttribute("type", nil)
    if action == "place" then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. self.data.object.itemID)
        state.placedAt = GetTime()
    elseif action == "craft" then
        local object = self.data.object
        state.clickAgain = nil
        if OpenProfession() == object.skillLine then
            C_TradeSkillUI.CraftRecipe(object.recipeID, 1)
        elseif self.data.profession and self.data.profession.opener then
            state.pendingCraft = object.recipeID
            state.openedForCraft = true
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", self.data.profession.opener)
        end
    elseif action == "open" then
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", self.data.profession.opener)
    end
end

local function GearTooltip(self)
    local data = self.data
    GameTooltip:SetOwner(self, "ANCHOR_LEFT") -- the panel sits on the right edge
    if data.hint then
        GameTooltip:SetText(data.profession.name, 1, 1, 1)
        GameTooltip:AddLine("BOLT hasn't seen a camp recipe for this profession yet. Click to open it once; "
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
    GameTooltip:AddLine(" ")
    if self.leftAction == "place" then
        GameTooltip:AddLine("Left-click: place it at this camp", GREY[1], GREY[2], GREY[3])
        if self.rightAction == "craft" then
            GameTooltip:AddLine("Right-click: craft another", GREY[1], GREY[2], GREY[3])
        end
        GameTooltip:AddLine("One object per character per camp, then a 1 hour cooldown.", GREY[1], GREY[2], GREY[3], true)
    elseif self.leftAction == "craft" then
        GameTooltip:AddLine("Click: craft one (opens your " .. object.profession .. " window)", GREY[1], GREY[2], GREY[3], true)
    end
    GameTooltip:Show()
end

local function GearRow(index)
    local row = prompt.gearRows[index]
    if row then return row end
    row = CreateFrame("Button", nil, prompt, "SecureActionButtonTemplate")
    row:SetSize(WIDTH - PAD * 2 + 8, ROW_HEIGHT)
    row:RegisterForClicks("AnyUp") -- mouse clicks act on release on this client
    row:SetScript("PreClick", GearPreClick)
    row:SetScript("OnEnter", GearTooltip)
    row:SetScript("OnLeave", GameTooltip_Hide)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.75, 0.35, 0.3)
    highlight:SetAllPoints()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(28, 28)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.border = row:CreateTexture(nil, "OVERLAY")
    row.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    row.border:SetPoint("TOPLEFT", row.icon, -10, 10)
    row.border:SetPoint("BOTTOMRIGHT", row.icon, 10, -10)
    row.count = row:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, -1, 1)
    row.cooldown = CreateFrame("Cooldown", nil, row, "CooldownFrameTemplate")
    row.cooldown:SetAllPoints(row.icon)
    row.cooldown:SetHideCountdownNumbers(true)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetJustifyH("LEFT")
    row.detail = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.detail:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    SetColor(row.detail, GREY)
    row.action = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.action:SetPoint("RIGHT", -6, 0)
    row.action:SetJustifyH("RIGHT")
    row.detail:SetPoint("RIGHT", row.action, "LEFT", -6, 0)

    prompt.gearRows[index] = row
    return row
end

local function FillGearRow(row, data)
    row.data = data
    row.cooldown:Clear()
    row.icon:SetDesaturated(false)
    row.count:SetText("")
    if data.hint then
        row.leftAction, row.rightAction = "open", nil
        row.icon:SetTexture(C_Spell.GetSpellTexture(data.profession.opener) or FALLBACK_ICON)
        row.name:SetText(data.profession.name)
        row.detail:SetText("Open it once to list its camp recipes")
        row.action:SetText("Open")
        SetColor(row.action, GOLD)
        return
    end

    local object = data.object
    row.icon:SetTexture(ObjectIcon(object))
    row.name:SetText(object.name)
    row.detail:SetText(object.effect or "")
    local craftable = data.known and CraftableCount(object) or 0

    if data.count > 0 then
        row.leftAction = "place"
        row.rightAction = data.known and "craft" or nil
        row.count:SetText(data.count > 1 and data.count or "")
        local start, duration = C_Container.GetItemCooldown(object.itemID)
        if duration and duration > 2 then
            row.cooldown:SetCooldown(start, duration)
            row.action:SetText(FormatTime(start + duration - GetTime()))
            SetColor(row.action, GREY)
        else
            row.action:SetText("Place")
            SetColor(row.action, GREEN)
        end
    else
        row.leftAction, row.rightAction = "craft", nil
        if state.clickAgain == object.recipeID then
            row.action:SetText("Click again")
            SetColor(row.action, GOLD)
        elseif craftable > 0 then
            row.action:SetText(craftable > 1 and ("Craft (%d)"):format(craftable) or "Craft")
            SetColor(row.action, GOLD)
        else
            row.action:SetText("Need reagents")
            SetColor(row.action, RED)
            row.icon:SetDesaturated(true)
        end
    end
end

---------------------------------------------------------------------------
-- The panel
---------------------------------------------------------------------------

local function BuildPrompt()
    prompt = CreateFrame("Frame", "BOLTCampfirePrompt", UIParent, "TooltipBackdropTemplate")
    prompt:SetFrameStrata("MEDIUM")
    prompt:SetSize(WIDTH, 60)
    prompt:Hide()
    if prompt.NineSlice and prompt.NineSlice.SetCenterColor then
        prompt.NineSlice:SetCenterColor(0.06, 0.04, 0.02, 0.92)
    end

    -- Header: click to sit, right-click to dismiss.
    local header = CreateFrame("Button", nil, prompt)
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -6, -6)
    header:SetHeight(44)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    prompt.header = header

    local icon = header:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("LEFT", 6, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    prompt.icon = icon

    local glow = header:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.55, 0.15)
    glow:SetSize(64, 64)
    glow:SetPoint("CENTER", icon)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local breathe = pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(0.25)
    breathe:SetToAlpha(0.8)
    breathe:SetDuration(1.4)
    breathe:SetSmoothing("IN_OUT")
    glow.pulse = pulse
    prompt.glow = glow

    -- Collapse indicator (top right), range verdict next to it, Sit button below.
    prompt.toggle = header:CreateTexture(nil, "ARTWORK")
    prompt.toggle:SetSize(14, 14)
    prompt.toggle:SetPoint("TOPRIGHT", -5, -5)

    prompt.badge = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    prompt.badge:SetPoint("RIGHT", prompt.toggle, "LEFT", -6, 0)

    local sit = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    sit:SetSize(52, 20)
    sit:SetPoint("BOTTOMRIGHT", -2, 1)
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
    prompt.sit = sit

    prompt.title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    prompt.title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    prompt.title:SetPoint("RIGHT", prompt.badge, "LEFT", -6, 0)
    prompt.title:SetJustifyH("LEFT")
    prompt.title:SetWordWrap(false)
    prompt.hint = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    prompt.hint:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 10, 1)
    prompt.hint:SetPoint("RIGHT", sit, "LEFT", -6, 0)
    prompt.hint:SetJustifyH("LEFT")
    prompt.hint:SetWordWrap(false)
    prompt.hint:SetTextColor(0.85, 0.85, 0.85)

    local highlight = header:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.75, 0.35, 0.2)
    highlight:SetAllPoints()

    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            state.dismissed = true
            Campfire:Update()
        elseif not InCombatLockdown() then
            BOLT:SetConfig(not BOLT:GetConfig("campfire", "collapsed", false), "campfire", "collapsed")
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Campfire:Tick()
        end
    end)
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Campfire", 1, 1, 1)
        GameTooltip:AddLine(BOLT:GetConfig("campfire", "collapsed", false) and "Click to expand."
            or "Click to collapse to this line.", nil, nil, nil, true)
        GameTooltip:AddLine("Right-click to hide this panel until the next fire.", GREY[1], GREY[2], GREY[3], true)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", GameTooltip_Hide)

    -- Warm-up bar.
    local bar = CreateFrame("StatusBar", nil, prompt)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(1, 0.55, 0.15)
    bar:SetHeight(14)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.7)
    bar.border = CreateFrame("Frame", nil, bar, "TooltipBackdropTemplate")
    bar.border:SetPoint("TOPLEFT", -3, 3)
    bar.border:SetPoint("BOTTOMRIGHT", 3, -3)
    if bar.border.NineSlice and bar.border.NineSlice.SetCenterColor then
        bar.border.NineSlice:SetCenterColor(0, 0, 0, 0)
    end
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", 0, 0)
    bar:Hide()
    prompt.bar = bar

    prompt.benefitSection = CreateSection("Camp benefits")
    prompt.benefitEmpty = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    prompt.benefitEmpty:SetJustifyH("LEFT")
    SetColor(prompt.benefitEmpty, GREY)
    prompt.benefitRows = {}

    prompt.gearSection = CreateSection("Your camp gear")
    prompt.gearRows = {}

    local fade = prompt:CreateAnimationGroup()
    fade.alpha = fade:CreateAnimation("Alpha")
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function(self)
        if self.onDone then self.onDone() end
    end)
    prompt.fade = fade

    prompt.elapsed = 0
    prompt:SetScript("OnUpdate", function(_, elapsed)
        prompt.elapsed = prompt.elapsed + elapsed
        if prompt.elapsed < 0.25 then return end
        prompt.elapsed = 0
        Campfire:Tick()
    end)
end

-- Right middle of the screen, mirroring the party frames on the left: same distance from the
-- screen edge, top aligned with theirs. Without visible party frames, a fixed spot.
local PARTY_FRAMES = { "CompactPartyFrame", "PartyFrame", "CompactRaidFrameContainer" }
local function PlacePanel()
    if InCombatLockdown() then return end
    local ratio = 1 / UIParent:GetEffectiveScale()
    local inset, top = 300, UIParent:GetHeight() / 2 + 140
    for _, name in ipairs(PARTY_FRAMES) do
        local frame = _G[name]
        if frame and frame:IsVisible() and frame:GetLeft() and frame:GetTop() then
            local scale = frame:GetEffectiveScale() * ratio
            inset, top = frame:GetLeft() * scale, frame:GetTop() * scale
            break
        end
    end
    inset = math.min(math.max(inset, 20), UIParent:GetWidth() / 3)
    prompt:ClearAllPoints()
    prompt:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", -inset, top)
end

-- Rebuilds the rows. Secure rows inside: out of combat only.
function Campfire:Layout()
    if InCombatLockdown() then return end
    local collapsed = BOLT:GetConfig("campfire", "collapsed", false)
    prompt.layoutCollapsed, prompt.layoutBar = collapsed, prompt.wantBar
    prompt.toggle:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    prompt.bar:SetShown(prompt.wantBar and not collapsed)
    local y = -56

    if collapsed then
        prompt.benefitSection:SetShown(false)
        prompt.benefitEmpty:Hide()
        for _, row in ipairs(prompt.benefitRows) do row:Hide() end
        prompt.gearSection:SetShown(false)
        for _, row in ipairs(prompt.gearRows) do row:Hide() end
        prompt:SetHeight(-y + 2)
        return
    end

    if prompt.bar:IsShown() then
        prompt.bar:ClearAllPoints()
        prompt.bar:SetPoint("TOPLEFT", PAD + 2, y)
        prompt.bar:SetPoint("TOPRIGHT", -PAD - 2, y)
        y = y - 24
    end

    -- Camp benefits
    local benefits = prompt.benefits or {}
    local showBenefits = #benefits > 0 or prompt.bar:IsShown()
    prompt.benefitSection:SetShown(showBenefits)
    prompt.benefitEmpty:Hide()
    for i, row in ipairs(prompt.benefitRows) do
        if i > #benefits then row:Hide() end
    end
    if showBenefits then
        y = prompt.benefitSection:Place(y)
        if #benefits == 0 then
            prompt.benefitEmpty:ClearAllPoints()
            prompt.benefitEmpty:SetPoint("TOPLEFT", PAD, y - 2)
            prompt.benefitEmpty:SetText("Revealed when the bar fills.")
            prompt.benefitEmpty:Show()
            y = y - 20
        end
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
        y = y - 6
    end

    -- Camp gear
    local gear = prompt.gear or {}
    prompt.gearSection:SetShown(#gear > 0)
    for i, row in ipairs(prompt.gearRows) do
        if i > #gear then row:Hide() end
    end
    if #gear > 0 then
        y = prompt.gearSection:Place(y)
        for i, data in ipairs(gear) do
            local row = GearRow(i)
            FillGearRow(row, data)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", PAD - 4, y)
            row:Show()
            y = y - ROW_HEIGHT - 2
        end
    end

    prompt:SetHeight(-y + 8)
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

-- Header, bar and range verdict; runs four times a second while the panel is up.
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

    local title, hint, color
    local bar = prompt.bar
    local showBar = false
    if seated and warming then
        local duration = warming.duration and warming.duration > 0 and warming.duration or WARM_UP
        local left = warming.expirationTime and warming.expirationTime > 0 and warming.expirationTime - now
            or duration - (now - state.seatedAt)
        bar:SetMinMaxValues(0, duration)
        bar:SetValue(duration - left)
        bar.text:SetText(("Camp benefits in %s"):format(FormatTime(left)))
        showBar = true
        title, color = "Warming up", GOLD
        hint = BOLT:GetConfig("campfire", "collapsed", false) and ("Camp benefits in %s"):format(FormatTime(left))
            or "Stay seated until the bar fills"
    elseif range == "far" then
        title, hint, color = "Too far from the fire", "Stand up, step closer to the flames and sit again", RED
    elseif seated then
        title, hint, color = "Sitting down...", "Checking the fire's warmth", GOLD
    elseif benefits then
        local left = benefits.expirationTime and benefits.expirationTime > 0 and benefits.expirationTime - now
        title, color = "Camp benefits active", GREEN
        hint = (left and (FormatTime(left) .. " left. ") or "") .. "Sit again to add new objects"
    else
        title, hint, color = "Sit by the fire", range == "in" and "You're close enough: click to sit"
            or "Sit right next to the flames", GOLD
    end

    prompt.title:SetText(title)
    SetColor(prompt.title, color)
    prompt.hint:SetText(hint)
    prompt.sit:SetShown(not seated and not warming)
    local benefitsLeft = benefits and benefits.expirationTime and benefits.expirationTime > 0
        and benefits.expirationTime - now
    prompt.benefitSection.extra:SetText(benefitsLeft and (FormatTime(benefitsLeft) .. " left") or "")
    if range == "in" then
        prompt.badge:SetText("In range")
        SetColor(prompt.badge, GREEN)
    elseif range == "far" then
        prompt.badge:SetText("Too far")
        SetColor(prompt.badge, RED)
    else
        prompt.badge:SetText("")
    end

    -- Benefits change rarely: compare a signature before relayouting.
    local list = ReadBenefits(benefits)
    local signature = {}
    for _, benefit in ipairs(list) do table.insert(signature, (benefit.name or "") .. benefit.effect) end
    signature = table.concat(signature, "|")
    prompt.wantBar = showBar
    local collapsed = BOLT:GetConfig("campfire", "collapsed", false)
    if (signature ~= prompt.benefitSignature or showBar ~= prompt.layoutBar or collapsed ~= prompt.layoutCollapsed
        or state.dirty) and not InCombatLockdown() then
        prompt.benefitSignature = signature
        prompt.benefits = list
        if state.dirty then
            state.dirty = false
            prompt.gear = GearList()
        end
        self:Layout()
    end
end

function Campfire:Update()
    if not prompt then return end
    if InCombatLockdown() then return end

    local nearby = self.active and FindAura(AURA_NEARBY)
    if not nearby then
        state.dismissed, state.seatedAt, state.placedAt = false, nil, nil
        wipe(state.warmSpots)
        return Conceal()
    end
    prompt.icon:SetTexture(nearby.icon or FALLBACK_ICON)
    if state.dismissed or not CanSit() then
        return Conceal()
    end
    PlacePanel()
    self:Tick()
    Reveal()
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
-- Lifecycle
---------------------------------------------------------------------------

function Campfire:OnInitialize()
    BuildPrompt()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Fires just before combat lockdown: last chance to hide the secure rows.
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
    self:Update()
end

function Campfire:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    state.pendingCraft, state.openedForCraft = nil, false
    self:Update()
end

BOLT:RegisterModule("campfire", Campfire)
