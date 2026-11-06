-- B.O.L.T Nameplates Module (saved as "nameplatesEnhancement")
-- Small fixes on top of Blizzard's nameplates:
--   mana users     enemy healers and casters get a recolored health bar
--   target         your target's plate is larger and the others fade a little (game settings)
--   native look    health bars use the same Blizzard fill art as the unit frames
--   interrupt cue  an enemy cast bar lights up when the spell can be interrupted and your
--                  interrupt is off cooldown
--   range hint     enemies out of your reach get a slightly darker health bar
--
-- Midnight hides some unit data from addons in combat ("secret" values), including whether a
-- cast can be interrupted. The cue never tests that value in Lua: it hands it to the game with
-- SetAlphaFromBoolean, which accepts secrets.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt

local Nameplates = {
    displayName = "Nameplates",
}

local DEFAULT_MANA_COLOR = { r = 0.2, g = 0.4, b = 1.0 }
local DEFAULT_INTERRUPT_COLOR = { r = 0.3, g = 1.0, b = 0.45 }
local HEALTH_ART = "ui-hud-unitframe-target-portraiton-bar-health-status"
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CUE_REFRESH = 0.2   -- seconds between cooldown and range checks
local RANGE_SHADE = 0.4   -- darkness over the health bar of an enemy out of range

-- Game settings changed by "target emphasis", restored to the game's defaults when turned off.
local TARGET_CVARS = {
    nameplateSelectedScale = "1.2",
    nameplateNotSelectedAlpha = "0.6",
}

-- Interrupts by class, best first. Ranks are listed for WoW: Forever, where Earth Shock still
-- interrupts and some classes have none.
local INTERRUPTS = {
    WARRIOR = { 6552, 6554, 72, 1671, 1672 },
    ROGUE = { 1766, 1767, 1768, 1769 },
    MAGE = { 2139 },
    SHAMAN = { 57994, 8042, 8044, 8045, 8046, 10412, 10413, 10414 },
    DEATHKNIGHT = { 47528 },
    PALADIN = { 96231, 31935 },
    DRUID = { 106839, 78675 },
    HUNTER = { 147362, 187707 },
    MONK = { 116705 },
    DEMONHUNTER = { 183752 },
    EVOKER = { 351338 },
    PRIEST = { 15487 },
    WARLOCK = { 119910, 19647, 19244, 132409, 89766 },
}

local function Cfg(key)
    return BOLT:GetConfig("nameplatesEnhancement", key)
end

local function IsOn(key)
    return Nameplates.active and Cfg(key)
end

local function IsPlateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d") ~= nil
end

local function ForEachPlate(fn)
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        if plate.UnitFrame then fn(plate.UnitFrame) end
    end
end

---------------------------------------------------------------------------
-- Mana users
---------------------------------------------------------------------------

local manaR, manaG, manaB = DEFAULT_MANA_COLOR.r, DEFAULT_MANA_COLOR.g, DEFAULT_MANA_COLOR.b

local function ManaColorApplies()
    if not IsOn("manaUsers") then return false end
    if Cfg("instanceOnly") then
        local inInstance, instanceType = IsInInstance()
        return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
    end
    return true
end

-- Unit data on nameplates can be secret in Midnight; skip those units.
local function IsEnemyManaUser(unit)
    local reaction = UnitReaction("player", unit)
    local powerType = UnitPowerType(unit)
    if BOLT.IsSecret(reaction) or BOLT.IsSecret(powerType) then return false end
    return reaction ~= nil and reaction <= 4 and powerType == Enum.PowerType.Mana
end

local function ColorFrame(frame)
    local unit = frame and frame.unit
    if not (IsPlateUnit(unit) and frame.healthBar and ManaColorApplies()) then return end
    if IsEnemyManaUser(unit) then
        frame.healthBar:SetStatusBarColor(manaR, manaG, manaB)
    end
end

function Nameplates:LoadColors()
    local color = Cfg("manaColor") or DEFAULT_MANA_COLOR
    manaR, manaG, manaB = color.r, color.g, color.b
end

---------------------------------------------------------------------------
-- Native look
---------------------------------------------------------------------------

local skinned = setmetatable({}, { __mode = "k" })

local function SkinFrame(frame)
    local bar = frame and frame.healthBar
    if not (bar and IsOn("nativeLook")) then return end
    local atlas = NativeArt.ResolveAtlas(HEALTH_ART)
    if not atlas then return end
    local texture = bar:GetStatusBarTexture()
    if texture and texture:GetAtlas() == atlas then return end
    bar:SetStatusBarTexture(atlas)
    skinned[frame] = true
end

---------------------------------------------------------------------------
-- Target emphasis
---------------------------------------------------------------------------

local cvarsPending = false

function Nameplates:ApplyTargetCVars()
    if InCombatLockdown() then
        cvarsPending = true
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    cvarsPending = false
    local on = IsOn("targetEmphasis")
    for name, value in pairs(TARGET_CVARS) do
        if C_CVar.GetCVarInfo(name) then
            local wanted = on and value or C_CVar.GetCVarDefault(name)
            if wanted and C_CVar.GetCVar(name) ~= wanted then
                C_CVar.SetCVar(name, wanted)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Interrupt cue
---------------------------------------------------------------------------

local interruptID, interruptIcon

-- Reach is measured with your interrupt; classes or specs without one use a basic attack.
local RANGE_FALLBACK = {
    PRIEST = { 585 },           -- Smite
    PALADIN = { 20271, 35395 }, -- Judgment, Crusader Strike
    DRUID = { 5176 },           -- Wrath
    HUNTER = { 75 },            -- Auto Shot
    WARLOCK = { 686 },          -- Shadow Bolt
    MAGE = { 133 },             -- Fireball
    SHAMAN = { 403 },           -- Lightning Bolt
    WARRIOR = { 78 },           -- Heroic Strike
    ROGUE = { 1752 },           -- Sinister Strike
    MONK = { 100780 },          -- Tiger Palm
    DEATHKNIGHT = { 49998 },    -- Death Strike
    DEMONHUNTER = { 162794 },   -- Chaos Strike
    EVOKER = { 361469 },        -- Living Flame
}
local rangeSpell

local function Known(spellID)
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if C_SpellBook.IsSpellKnown(spellID) then return true end
        local pet = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
        if pet and C_SpellBook.IsSpellKnown(spellID, pet) then return true end
    elseif IsSpellKnown then
        return IsSpellKnown(spellID) or IsSpellKnown(spellID, true)
    end
    return false
end

function Nameplates:FindInterrupt()
    interruptID, interruptIcon = nil, nil
    local _, class = UnitClass("player")
    -- Higher ranks come last in the list, so keep the last one known.
    for _, spellID in ipairs(INTERRUPTS[class] or {}) do
        local ok, known = pcall(Known, spellID)
        if ok and known then
            if not interruptID or C_Spell.GetSpellName(spellID) == C_Spell.GetSpellName(interruptID) then
                interruptID = spellID
            end
        end
    end
    if interruptID then
        interruptIcon = C_Spell.GetSpellTexture(interruptID)
    end

    rangeSpell = interruptID
    if not rangeSpell then
        for _, spellID in ipairs(RANGE_FALLBACK[class] or {}) do
            local ok, known = pcall(Known, spellID)
            if ok and known then
                rangeSpell = spellID
                break
            end
        end
    end
end

-- Cooldown state is never secret for your own spells (isActive), so this is a plain test.
local function InterruptReady()
    if not interruptID then return false end
    local info = C_Spell.GetSpellCooldown(interruptID)
    if not info then return false end
    if info.isActive ~= nil then
        return not info.isActive or info.isOnGCD == true
    end
    if BOLT.IsSecret(info.duration) then return true end
    return (info.duration or 0) <= 1.5
end

local function CastBarOf(frame)
    return frame.castBar or (frame.CastBarsContainer and frame.CastBarsContainer.castBar)
end

local function GetCue(castBar)
    local cue = castBar.boltCue
    if cue then return cue end

    cue = CreateFrame("Frame", nil, castBar)
    cue:SetAllPoints(castBar)
    cue:SetFrameLevel(castBar:GetFrameLevel() + 5)
    -- A 2px outline just outside the bar: { first point, second point, x, y } per edge.
    cue.edges = {}
    for _, edgeSpec in ipairs({
        { "TOPLEFT", "TOPRIGHT", -2, 2, 2, 2 },
        { "BOTTOMLEFT", "BOTTOMRIGHT", -2, -2, 2, -2 },
        { "TOPLEFT", "BOTTOMLEFT", -2, 2, -2, -2 },
        { "TOPRIGHT", "BOTTOMRIGHT", 2, 2, 2, -2 },
    }) do
        local edge = cue:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetTexture(WHITE)
        edge:SetPoint(edgeSpec[1], cue, edgeSpec[1], edgeSpec[3], edgeSpec[4])
        edge:SetPoint(edgeSpec[2], cue, edgeSpec[2], edgeSpec[5], edgeSpec[6])
        if edgeSpec[4] == edgeSpec[6] then edge:SetHeight(2) else edge:SetWidth(2) end
        table.insert(cue.edges, edge)
    end
    cue.icon = cue:CreateTexture(nil, "OVERLAY", nil, 7)
    cue.icon:SetPoint("LEFT", cue, "RIGHT", 4, 0)
    cue.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cue.regions = { cue.icon, unpack(cue.edges) }
    cue:Hide()
    castBar.boltCue = cue
    return cue
end

local function PaintCue(cue)
    local color = Cfg("interruptColor") or DEFAULT_INTERRUPT_COLOR
    for _, edge in ipairs(cue.edges) do
        edge:SetVertexColor(color.r, color.g, color.b, 1)
    end
    local size = math.max(12, cue:GetHeight() + 6)
    cue.icon:SetSize(size, size)
    cue.icon:SetTexture(interruptIcon)
end

-- Returns notInterruptible (possibly secret) and whether the unit is casting at all.
local function ReadCast(unit)
    local cast = { UnitCastingInfo(unit) }
    if #cast > 0 then return cast[8], true end
    local channel = { UnitChannelInfo(unit) }
    if #channel > 0 then return channel[7], true end
    return nil, false
end

-- Unit tokens can be off limits to addons (in arenas, for example).
local function CastState(unit)
    local ok, notInterruptible, casting = pcall(ReadCast, unit)
    if not ok then return nil, false end
    return notInterruptible, casting
end

local function UpdateCue(frame)
    local castBar = CastBarOf(frame)
    if not castBar then return end
    local unit = frame.unit
    local cue = castBar.boltCue
    local function Off() if cue then cue:Hide() end end

    if not (IsOn("interruptCue") and interruptID and IsPlateUnit(unit)) then return Off() end
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if not ok or BOLT.IsSecret(canAttack) or not canAttack then return Off() end
    local notInterruptible, casting = CastState(unit)
    if not casting or not InterruptReady() then return Off() end

    cue = GetCue(castBar)
    PaintCue(cue)
    local secret = BOLT.IsSecret(notInterruptible)
    for _, region in ipairs(cue.regions) do
        if secret then
            region:SetAlphaFromBoolean(notInterruptible, 0, 1)
        else
            region:SetAlpha(notInterruptible and 0 or 1)
        end
    end
    cue:Show()
end

---------------------------------------------------------------------------
-- Range hint
---------------------------------------------------------------------------
-- A dark veil over the health bar of an enemy your reference spell can't reach. The check may
-- come back secret in some fights, so like the cue it goes to the game as a boolean.

local function UpdateRange(frame)
    local bar = frame.healthBar
    if not bar then return end
    local shade = bar.boltRangeShade
    local function Off() if shade then shade:Hide() end end

    local unit = frame.unit
    if not (IsOn("rangeHint") and rangeSpell and IsPlateUnit(unit)) then return Off() end
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if not ok or BOLT.IsSecret(canAttack) or not canAttack then return Off() end
    local checked, inRange = pcall(C_Spell.IsSpellInRange, rangeSpell, unit)
    if not checked or inRange == nil then return Off() end

    if not shade then
        shade = bar:CreateTexture(nil, "ARTWORK", nil, 7)
        shade:SetTexture(WHITE)
        shade:SetVertexColor(0, 0, 0, 1)
        shade:SetAllPoints(bar)
        bar.boltRangeShade = shade
    end
    if BOLT.IsSecret(inRange) then
        shade:SetAlphaFromBoolean(inRange, 0, RANGE_SHADE)
    else
        shade:SetAlpha(inRange and 0 or RANGE_SHADE)
    end
    shade:Show()
end

local function UpdatePlate(frame)
    UpdateCue(frame)
    UpdateRange(frame)
end

local function UpdateAllCues()
    ForEachPlate(UpdatePlate)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    "UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP",
}

local hookedFrames = setmetatable({}, { __mode = "k" })
local colorHooked = false

local function SetUpFrame(frame)
    if not frame then return end
    if not hookedFrames[frame] and frame.ApplyFrameOptions then
        hookedFrames[frame] = true
        -- Blizzard re-applies its bar art when the nameplate style changes.
        hooksecurefunc(frame, "ApplyFrameOptions", function(self) SkinFrame(self) end)
    end
    SkinFrame(frame)
    ColorFrame(frame)
    UpdatePlate(frame)
end

local function OnEvent(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate then SetUpFrame(plate.UnitFrame) end
    elseif event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_BAR_SHOW" then
        local plate = IsPlateUnit(unit) and C_NamePlate.GetNamePlateForUnit(unit)
        if plate then ColorFrame(plate.UnitFrame) end
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        UpdateAllCues()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_TALENT_UPDATE" or event == "UNIT_PET" then
        Nameplates:FindInterrupt()
        UpdateAllCues()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Nameplates.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if cvarsPending then Nameplates:ApplyTargetCVars() end
    elseif IsPlateUnit(unit) then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame then UpdateCue(plate.UnitFrame) end
    end
end

-- Cooldowns run out and enemies walk in and out of reach without events: re-check regularly.
local sinceRefresh = 0
local function OnUpdate(_, elapsed)
    sinceRefresh = sinceRefresh + elapsed
    if sinceRefresh < CUE_REFRESH then return end
    sinceRefresh = 0
    UpdateAllCues()
end

function Nameplates:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", OnEvent)
end

function Nameplates:RegisterEvents()
    local events = self.eventFrame
    events:UnregisterAllEvents()
    events:SetScript("OnUpdate", nil)
    events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    events:RegisterEvent("UNIT_DISPLAYPOWER")
    events:RegisterEvent("UNIT_POWER_BAR_SHOW")
    if cvarsPending then events:RegisterEvent("PLAYER_REGEN_ENABLED") end
    if Cfg("interruptCue") then
        for _, event in ipairs(CAST_EVENTS) do
            pcall(events.RegisterEvent, events, event) -- empower events don't exist on Forever
        end
        pcall(events.RegisterEvent, events, "SPELL_UPDATE_COOLDOWN")
    end
    if Cfg("interruptCue") or Cfg("rangeHint") then
        for _, event in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE" }) do
            pcall(events.RegisterEvent, events, event)
        end
        events:RegisterUnitEvent("UNIT_PET", "player")
        events:SetScript("OnUpdate", OnUpdate)
    end
end

function Nameplates:OnEnable()
    self:LoadColors()
    self:FindInterrupt()

    -- Blizzard recolors on threat/reaction changes; re-apply after it. hooksecurefunc
    -- can't be removed, so the hook checks the settings and stays inert when disabled.
    if not colorHooked then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ColorFrame)
        colorHooked = true
    end

    self:RegisterEvents()
    self:ApplyTargetCVars()
    ForEachPlate(SetUpFrame)
end

function Nameplates:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self.eventFrame:SetScript("OnUpdate", nil)
    self:ApplyTargetCVars()
    UpdateAllCues()
    if next(skinned) then
        BOLT:Print("Nameplates disabled. Type /reload to bring back Blizzard's bar art.")
    end
end

function Nameplates:OnSettingChanged(key)
    self:LoadColors()
    if key == "targetEmphasis" then
        self:ApplyTargetCVars()
    elseif key == "interruptCue" or key == "rangeHint" then
        self:RegisterEvents()
    elseif key == "nativeLook" and not Cfg("nativeLook") and next(skinned) then
        BOLT:Print("Type /reload to bring back Blizzard's nameplate bar art.")
    end
    -- Only recolor; calling Blizzard's update from addon code would taint the plates.
    ForEachPlate(function(frame)
        SkinFrame(frame)
        ColorFrame(frame)
        UpdatePlate(frame)
    end)
end

Nameplates.DEFAULT_MANA_COLOR = DEFAULT_MANA_COLOR
Nameplates.DEFAULT_INTERRUPT_COLOR = DEFAULT_INTERRUPT_COLOR

BOLT:RegisterModule("nameplatesEnhancement", Nameplates)
