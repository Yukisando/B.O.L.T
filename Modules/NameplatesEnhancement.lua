-- B.O.L.T Nameplates Module (saved as "nameplatesEnhancement")
-- Small fixes on top of Blizzard's nameplates:
--   mana users     enemy healers and casters get a recolored health bar
--   target         your target's plate is larger and the others fade a little (game settings)
--   interrupt cue  an enemy cast bar lights up when the spell can be interrupted and your
--                  interrupt is off cooldown
--   range hint     a dot above the top left of an enemy's health bar: dark red out of your reach,
--                  yellow in melee range when your reach has a minimum range (hunters)
--   DoT overlay    striped shield over an enemy's health, as wide as the damage your DoTs will
--                  still deal; gold when they will kill it (WoW: Forever, Modules/DotTracking)
--
-- Midnight hides some unit data from addons in combat ("secret" values), including whether a
-- cast can be interrupted. The cue never tests that value in Lua: it hands it to the game with
-- SetAlphaFromBoolean, which accepts secrets.

local ADDON_NAME, BOLT = ...

local Nameplates = {
    displayName = "Nameplates",
}

local DEFAULT_MANA_COLOR = { r = 0.2, g = 0.4, b = 1.0 }
local DEFAULT_INTERRUPT_COLOR = { r = 0.3, g = 1.0, b = 0.45 }
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CUE_REFRESH = 0.2   -- seconds between cooldown and range checks

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
-- Classes whose reference spell has a minimum range: a melee spell tells "too close" apart from
-- "too far", so an enemy in melee gets a dot instead of the dark veil. Ranks listed for Forever.
local MELEE_CHECK = {
    -- Raptor Strike, Wing Clip, Mongoose Bite
    HUNTER = { 2973, 14260, 14261, 14262, 14263, 14264, 14265, 14266, 186270, 2974, 14267, 14268, 1495, 14269, 14270, 14271 },
}
local rangeSpell, meleeSpell, hasMinRange
local rangeChecks, meleeChecks = {}, {}

-- What to hand C_Spell.IsSpellInRange, best first. A rank's spell ID can answer "out of range"
-- when the spellbook holds another version (Forever's ranks, talent overrides), so the spell's
-- name, which the game resolves to the spellbook entry, goes first.
local function RangeChecks(spellID)
    local checks = {}
    if not spellID then return checks end
    local name = C_Spell.GetSpellName(spellID)
    if name then table.insert(checks, name) end
    local override = C_Spell.GetOverrideSpell and C_Spell.GetOverrideSpell(spellID)
    if override and override ~= spellID then table.insert(checks, override) end
    table.insert(checks, spellID)
    return checks
end

-- First real answer (true, false or secret) from the checks; nil when none can tell.
local function SpellInRange(checks, unit)
    for _, spell in ipairs(checks) do
        local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, unit)
        if ok and inRange ~= nil then return inRange, spell end
    end
    return nil
end

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

    meleeSpell = nil
    hasMinRange = MELEE_CHECK[class] ~= nil
    for _, spellID in ipairs(MELEE_CHECK[class] or {}) do
        local ok, known = pcall(Known, spellID)
        if ok and known then
            meleeSpell = spellID
            break
        end
    end
    rangeChecks = RangeChecks(rangeSpell)
    meleeChecks = RangeChecks(meleeSpell)
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
    -- The cast bar's height can be secret (no arithmetic allowed): fall back to a fixed size.
    local height = cue:GetHeight()
    local size = 14
    if height and not BOLT.IsSecret(height) then size = math.max(12, height + 6) end
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
-- A small dot at the top left of an enemy's health bar; the bar itself is never tinted.
--   dark red   your reference spell can't reach it
--   none       in reach
--   yellow     too close for the reference spell but in melee range (hunters' minimum range)
-- The reach check may come back secret in some fights: it then goes to the game as a boolean
-- and only the red dot can show.

local OUT_OF_RANGE_COLOR = { 0.6, 0.05, 0.05 }
local MELEE_COLOR = { 1, 0.85, 0.1 }
local DOT_SIZE = 6
local DOT_RISE = 14 -- pixels above the health bar, clear of the bar's top edge and the name

local function GetDot(bar)
    local dot = bar.boltRangeDot
    if dot then return dot end
    dot = bar:CreateTexture(nil, "OVERLAY", nil, 7)
    dot:SetTexture(WHITE)
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, DOT_RISE)
    local mask = bar:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(dot)
    dot:AddMaskTexture(mask)
    bar.boltRangeDot = dot
    return dot
end

-- true / false, or nil when it can't be told (no melee check, or the answer is secret).
local function InMelee(unit)
    if meleeSpell then
        local inMelee = SpellInRange(meleeChecks, unit)
        if inMelee ~= nil and not BOLT.IsSecret(inMelee) then return inMelee end
    end
    if CheckInteractDistance then
        local ok, near = pcall(CheckInteractDistance, unit, 3) -- about 10 yards
        if ok and near ~= nil and not BOLT.IsSecret(near) then return near end
    end
    return nil
end

local function UpdateRange(frame)
    local bar = frame.healthBar
    if not bar then return end
    -- The dark veil earlier versions put over the bar.
    if bar.boltRangeShade then bar.boltRangeShade:Hide() end
    local dot = bar.boltRangeDot
    local function Off() if dot then dot:Hide() end end

    local unit = frame.unit
    if not (IsOn("rangeHint") and rangeSpell and IsPlateUnit(unit)) then return Off() end
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if not ok or BOLT.IsSecret(canAttack) or not canAttack then return Off() end
    local inRange = SpellInRange(rangeChecks, unit)
    if inRange == nil then return Off() end

    dot = GetDot(bar)
    if BOLT.IsSecret(inRange) then
        dot:SetVertexColor(unpack(OUT_OF_RANGE_COLOR))
        dot:SetAlphaFromBoolean(inRange, 0, 1)
        dot:Show()
        return
    end
    if inRange then return Off() end

    local tooClose = hasMinRange and InMelee(unit)
    dot:SetVertexColor(unpack(tooClose and MELEE_COLOR or OUT_OF_RANGE_COLOR))
    dot:SetAlpha(1)
    dot:Show()
end

---------------------------------------------------------------------------
-- DoT overlay (WoW: Forever)
---------------------------------------------------------------------------
-- A reverse shield over an enemy's health bar: it starts at the right end of the health left and runs back over
-- it, as wide as the damage your DoTs will still deal. It turns the "kill" color when it covers all the health
-- left: those DoTs alone will finish the mob.
--
-- The tracking is in Modules/DotTracking: the combat log is closed to addons, so it reads each DoT from the
-- spell description at cast time, matches UNIT_COMBAT hits to it by school and timing, and learns your real tick
-- sizes from the damage meter after each fight. Your pet's DoTs count too (its casts are reported the same way).
--
-- Enemy health is secret on Forever, so Lua never compares it with the damage. Status bars accept secret
-- values and do it instead:
--   shield  a reverse-filling bar as wide as the health bar, its right end pinned to the end of the health fill,
--           max = max health, value = DoT damage. Its fill spans the damage on the health's scale; the part past
--           the bar's left edge is clipped.
--   kill    a very long bar, max = current health, value = DoT damage, ending at the bar's left edge. The
--           kill-colored layer rides the end of its fill and is clipped to the health left, so it only slides
--           in when the fill is (all but) full, i.e. damage >= health.

local DOTS_SUPPORTED = BOLT.isForever and BOLT.DotTracking ~= nil
local DEFAULT_DOT_COLOR = { r = 0.85, g = 0.55, b = 1.0 }
local DEFAULT_DOT_KILL_COLOR = { r = 1.0, g = 0.82, b = 0.0 }
local SHIELD_STRIPES = "Interface\\RaidFrame\\Shield-Overlay" -- Blizzard's absorb shield stripes
local KILL_BAR_LENGTH = 100000 -- the kill color shows from damage >= 99.9% of health on a 100px bar

local function DotTracking()
    return DOTS_SUPPORTED and BOLT.DotTracking or nil
end

-- What your DoTs on the unit's mob still have to deal (0 when none, or when it can't be told).
local function PendingDotDamage(unit)
    local tracking = DotTracking()
    if not (tracking and tracking.dotBreakdownForUnit) then return 0 end
    local ok, _, total = pcall(tracking.dotBreakdownForUnit, unit)
    if not ok or type(total) ~= "number" then return 0 end
    return total
end

-- Two textures painting one region: a faint tint and Blizzard's shield stripes over it.
local function AddShieldTextures(parent, region, level)
    local tint = parent:CreateTexture(nil, "ARTWORK", nil, level)
    tint:SetTexture(WHITE)
    tint:SetAllPoints(region)
    local stripes = parent:CreateTexture(nil, "ARTWORK", nil, level + 1)
    stripes:SetTexture(SHIELD_STRIPES, "REPEAT", "REPEAT")
    stripes:SetHorizTile(true)
    stripes:SetVertTile(true)
    stripes:SetAllPoints(region)
    return { tint = tint, stripes = stripes }
end

local function PaintShield(textures, color)
    textures.tint:SetVertexColor(color.r, color.g, color.b, 0.25)
    textures.stripes:SetVertexColor(color.r, color.g, color.b, 0.75)
end

local function NewStatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0) -- only its fill's position is used
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    return bar
end

local function GetDotOverlay(healthBar)
    local overlay = healthBar.boltDotOverlay
    if overlay then return overlay end
    local fill = healthBar:GetStatusBarTexture()

    -- Everything is clipped to the health bar.
    overlay = CreateFrame("Frame", nil, healthBar)
    overlay:SetAllPoints(healthBar)
    overlay:SetClipsChildren(true)
    overlay:SetFrameLevel(healthBar:GetFrameLevel() + 1)

    local shield = NewStatusBar(overlay)
    shield:SetReverseFill(true)
    shield:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    shield:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    overlay.shield = shield
    local shieldFill = shield:GetStatusBarTexture()
    overlay.normal = AddShieldTextures(shield, shieldFill, 0)

    -- The kill layer: clipped to the health left (all the shield covers once it's lethal), carried by the long
    -- bar's fill end. It's as wide as the whole bar, so at full fill it covers the window whatever the health.
    local killWindow = CreateFrame("Frame", nil, shield)
    killWindow:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    killWindow:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    killWindow:SetClipsChildren(true)
    killWindow:SetFrameLevel(shield:GetFrameLevel() + 1)
    local killBar = NewStatusBar(killWindow)
    killBar:SetPoint("TOPRIGHT", killWindow, "TOPLEFT")
    killBar:SetPoint("BOTTOMRIGHT", killWindow, "BOTTOMLEFT")
    killBar:SetWidth(KILL_BAR_LENGTH)
    overlay.killBar = killBar
    local killRegion = killBar:CreateTexture(nil, "BACKGROUND")
    killRegion:SetPoint("TOPLEFT", killBar:GetStatusBarTexture(), "TOPRIGHT")
    killRegion:SetPoint("BOTTOMLEFT", killBar:GetStatusBarTexture(), "BOTTOMRIGHT")
    killRegion:SetAlpha(0)
    overlay.killRegion = killRegion
    overlay.kill = AddShieldTextures(killBar, killRegion, 0)

    overlay:Hide()
    healthBar.boltDotOverlay = overlay
    return overlay
end

local function UpdateDots(frame)
    local healthBar = frame.healthBar
    if not healthBar then return end
    local overlay = healthBar.boltDotOverlay
    local function Off() if overlay then overlay:Hide() end end

    local unit = frame.unit
    if not (DOTS_SUPPORTED and IsOn("dotOverlay") and IsPlateUnit(unit)) then return Off() end
    local pending = PendingDotDamage(unit)
    if pending <= 0 then return Off() end
    local width = healthBar:GetWidth()
    if BOLT.IsSecret(width) or not width or width <= 0 then return Off() end

    overlay = GetDotOverlay(healthBar)
    PaintShield(overlay.normal, Cfg("dotColor") or DEFAULT_DOT_COLOR)
    PaintShield(overlay.kill, Cfg("dotKillColor") or DEFAULT_DOT_KILL_COLOR)
    overlay.shield:SetWidth(width)
    overlay.killRegion:SetWidth(width)
    -- Health and max health may be secret: only widgets get them.
    local okMax = pcall(overlay.shield.SetMinMaxValues, overlay.shield, 0, UnitHealthMax(unit))
    local okHealth = pcall(overlay.killBar.SetMinMaxValues, overlay.killBar, 0, UnitHealth(unit))
    if not (okMax and okHealth) then return Off() end
    overlay.shield:SetValue(pending)
    overlay.killBar:SetValue(pending)
    overlay:Show()
end

-- The tracking runs only while the overlay is on, and redraws the plates when its numbers move.
local function SetDotTracking(on)
    local tracking = DotTracking()
    if not tracking then return end
    tracking.enabled = on and true or false
    tracking.refresh = on and function() ForEachPlate(UpdateDots) end or function() end
    -- "Count a DoT only once its first tick lands" (the tracking's waitFirstTick: always / off).
    if tracking.db then tracking.db.waitFirstTick = Cfg("dotWaitFirstTick") and "always" or "off" end
end

-- /bolt dots: what the tracking holds for your target.
function Nameplates:PrintDotDebug()
    local tracking = DotTracking()
    if not tracking then
        BOLT:Print("The DoT overlay only runs on WoW: Forever.")
        return
    end
    if not tracking.enabled then
        BOLT:Print("The DoT overlay is off (/bolt, Nameplates).")
        return
    end
    if not UnitExists("target") then
        BOLT:Print("Target an enemy you've put DoTs on.")
        return
    end
    local ok, list, total = pcall(tracking.dotBreakdownForUnit, "target")
    if not ok then
        BOLT:Print("Couldn't read the tracking: " .. tostring(list))
        return
    end
    local now = GetTime()
    for _, dot in ipairs(list) do
        BOLT:Print(("  %s%s: %d damage left, %.1fs left%s"):format(tostring(dot.name), dot.fromPet and " (pet)" or "",
            math.floor(dot.damage + 0.5), (dot.expiresAt or now) - now, dot.provisional and " (still casting)" or ""))
    end
    BOLT:Print(("Your DoTs on the target still have to deal %d damage (%d DoT(s) counted)."):format(
        math.floor((total or 0) + 0.5), #list))
end

local function UpdatePlate(frame)
    UpdateCue(frame)
    UpdateRange(frame)
    UpdateDots(frame)
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

local colorHooked = false

local function SetUpFrame(frame)
    if not frame then return end
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
    end
    if Cfg("interruptCue") or Cfg("rangeHint") then
        events:SetScript("OnUpdate", OnUpdate)
    end
    -- The DoT overlay is redrawn by its tracking (10 times a second and on casts and hits), not from here.
    SetDotTracking(Cfg("dotOverlay"))
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
    SetDotTracking(false)
    self:ApplyTargetCVars()
    UpdateAllCues()
end

function Nameplates:OnLayoutChanged()
    self:ApplyTargetCVars()
    self:RegisterEvents()
    self:OnSettingChanged()
end

function Nameplates:OnSettingChanged(key)
    self:LoadColors()
    if key == "targetEmphasis" then
        self:ApplyTargetCVars()
    elseif key == "interruptCue" or key == "rangeHint" or key == "dotOverlay" or key == "dotWaitFirstTick" then
        self:RegisterEvents()
    end
    -- Only recolor; calling Blizzard's update from addon code would taint the plates.
    ForEachPlate(function(frame)
        ColorFrame(frame)
        UpdatePlate(frame)
    end)
end

-- /bolt range: what the range hint measures with, and what each check says about your target.
function Nameplates:PrintRangeDebug()
    self:FindInterrupt()
    local function Show(value)
        if BOLT.IsSecret(value) then return "secret" end
        return tostring(value)
    end
    BOLT:Print(("Range spell: %s (%s), interrupt: %s, melee spell: %s"):format(
        tostring(rangeSpell), tostring(rangeSpell and C_Spell.GetSpellName(rangeSpell)),
        tostring(interruptID), tostring(meleeSpell)))
    if not UnitExists("target") then
        BOLT:Print("Target an enemy to test the checks.")
        return
    end
    for _, spell in ipairs(rangeChecks) do
        local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, "target")
        BOLT:Print(("  %s -> %s"):format(tostring(spell), ok and Show(inRange) or "error"))
    end
    BOLT:Print("  result -> " .. Show(SpellInRange(rangeChecks, "target")))
end

Nameplates.DEFAULT_MANA_COLOR = DEFAULT_MANA_COLOR
Nameplates.DEFAULT_INTERRUPT_COLOR = DEFAULT_INTERRUPT_COLOR
Nameplates.DEFAULT_DOT_COLOR = DEFAULT_DOT_COLOR
Nameplates.DEFAULT_DOT_KILL_COLOR = DEFAULT_DOT_KILL_COLOR
Nameplates.DOTS_SUPPORTED = DOTS_SUPPORTED

BOLT:RegisterModule("nameplatesEnhancement", Nameplates)
