local ADDON_NAME, BOLT = ...

local NameplatesEnhancement = {}

local INTERRUPT_SPELLS = {
    ROGUE        = 1766,
    WARRIOR      = 6552,
    MAGE         = 2139,
    SHAMAN       = 57994,
    DEATHKNIGHT  = 47528,
    PALADIN      = 96231,
    MONK         = 116705,
    DEMONHUNTER  = 183752,
    DRUID        = 106839,
    EVOKER       = 351338,
    HUNTER       = 147362,
    PRIEST       = 15487,
    WARLOCK      = 19647,
}

local MANA_R, MANA_G, MANA_B = 0.2, 0.4, 1.0
local DEFAULT_MANA_R, DEFAULT_MANA_G, DEFAULT_MANA_B = 0.2, 0.4, 1.0
local GREY_R, GREY_G, GREY_B = 0.5, 0.5, 0.5
local YELLOW_R, YELLOW_G, YELLOW_B = 1.0, 0.82, 0.0
local CASTBAR_R, CASTBAR_G, CASTBAR_B = 1.0, 0.7, 0.0

local interruptSpellID
local isEnabled = false

local function GetPlayerInterruptSpell()
    if interruptSpellID then return interruptSpellID end
    local _, classToken = UnitClass("player")
    interruptSpellID = classToken and INTERRUPT_SPELLS[classToken]
    return interruptSpellID
end

local function IsEnemyUnit(unit)
    local reaction = UnitReaction("player", unit)
    return reaction and reaction <= 4
end

local function GetHealthBar(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return nil end
    local uf = nameplate.UnitFrame
    if not uf then return nil end
    return uf.healthBar
end

local function GetCastBar(unit)
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate then return nil end
    local uf = nameplate.UnitFrame
    if not uf then return nil end
    return uf.castBar
end

-- Feature 1: Color enemy nameplate health bars for mana users
local function UpdateNameplatePowerColor(unit)
    if not unit or not isEnabled then return end
    if not IsEnemyUnit(unit) then return end
    local healthBar = GetHealthBar(unit)
    if not healthBar then return end

    local powerType = UnitPowerType(unit)
    if powerType == Enum.PowerType.Mana then
        healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
    end
end

-- Post-hook for Blizzard's health color update — re-applies our color after
-- Blizzard sets its default so mana coloring persists through combat/threat changes
local function OnHealthColorUpdated(frame)
    if not isEnabled or not frame then return end
    local unit = frame.unit
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not IsEnemyUnit(unit) then return end

    local powerType = UnitPowerType(unit)
    if powerType == Enum.PowerType.Mana and frame.healthBar then
        frame.healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
    end
end

-- Feature 2: Grey/yellow cast bar when interrupt is on cooldown (enemies only)
local function UpdateCastBarInterruptState(unit)
    if not unit then return end
    if not IsEnemyUnit(unit) then return end
    local castBar = GetCastBar(unit)
    if not castBar then return end

    local spellID = GetPlayerInterruptSpell()
    if not spellID then return end

    local _, _, _, _, endTime, _, _, notInterruptible = UnitCastingInfo(unit)
    if not endTime then
        _, _, _, _, endTime, _, _, notInterruptible = UnitChannelInfo(unit)
    end
    if not endTime then return end
    if notInterruptible then return end

    local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
    if not cooldownInfo then return end

    if cooldownInfo.duration == 0 then
        castBar:SetStatusBarColor(CASTBAR_R, CASTBAR_G, CASTBAR_B)
        return
    end

    -- Interrupt is on cooldown — check if it will be ready before the cast ends
    local cooldownEnd = cooldownInfo.startTime + cooldownInfo.duration
    local castEndSec = endTime / 1000
    if cooldownEnd < castEndSec then
        castBar:SetStatusBarColor(YELLOW_R, YELLOW_G, YELLOW_B)
        return
    end

    castBar:SetStatusBarColor(GREY_R, GREY_G, GREY_B)
end

local function UpdateAllCastBars()
    local plates = C_NamePlate.GetNamePlates()
    if not plates then return end
    for _, plate in ipairs(plates) do
        local unit = plate.namePlateUnitToken
        if unit then
            UpdateCastBarInterruptState(unit)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")
eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")

-- Hook Blizzard's health color function so our color survives combat/threat updates.
-- hooksecurefunc runs after the original without spreading taint, safe in combat.
if CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", OnHealthColorUpdated)
elseif CompactUnitFrameMixin and CompactUnitFrameMixin.UpdateHealthColor then
    hooksecurefunc(CompactUnitFrameMixin, "UpdateHealthColor", OnHealthColorUpdated)
end

-- ========== LIFECYCLE ==========

function NameplatesEnhancement:LoadManaColor()
    local c = self.parent:GetConfig("nameplatesEnhancement", "manaColor")
    if c then
        MANA_R, MANA_G, MANA_B = c.r or DEFAULT_MANA_R, c.g or DEFAULT_MANA_G, c.b or DEFAULT_MANA_B
    else
        MANA_R, MANA_G, MANA_B = DEFAULT_MANA_R, DEFAULT_MANA_G, DEFAULT_MANA_B
    end
end

function NameplatesEnhancement:OnInitialize()
end

function NameplatesEnhancement:OnEnable()
    interruptSpellID = nil
    isEnabled = true
    self:LoadManaColor()

    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if event == "SPELL_UPDATE_COOLDOWN" then
            UpdateAllCastBars()
            return
        end

        if not unit or not unit:match("^nameplate%d+$") then return end

        if event == "NAME_PLATE_UNIT_ADDED" then
            UpdateNameplatePowerColor(unit)
        elseif event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_BAR_SHOW" then
            UpdateNameplatePowerColor(unit)
        elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            UpdateCastBarInterruptState(unit)
        end
    end)
end

function NameplatesEnhancement:OnDisable()
    isEnabled = false
    eventFrame:SetScript("OnEvent", nil)
end

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
