local ADDON_NAME, BOLT = ...

local NameplatesEnhancement = {}

local MANA_R, MANA_G, MANA_B = 0.2, 0.4, 1.0
local DEFAULT_MANA_R, DEFAULT_MANA_G, DEFAULT_MANA_B = 0.2, 0.4, 1.0

local INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B = 0.8, 0.15, 0.15
local DEFAULT_INTERRUPT_WARN_R, DEFAULT_INTERRUPT_WARN_G, DEFAULT_INTERRUPT_WARN_B = 0.8, 0.15, 0.15

local isEnabled = false
local instanceOnly = false
local interruptWarningEnabled = false

-- Resolve the player's interrupt spell once at load time
local INTERRUPT_BY_CLASS = {
    DEATHKNIGHT = 47528,  -- Mind Freeze
    DEMONHUNTER = 183752, -- Disrupt
    DRUID       = 106839, -- Skull Bash
    EVOKER      = 351338, -- Quell
    HUNTER      = 147362, -- Counter Shot
    MAGE        = 2139,   -- Counterspell
    MONK        = 116705, -- Spear Hand Strike
    PALADIN     = 96231,  -- Rebuke
    PRIEST      = 15487,  -- Silence
    ROGUE       = 1766,   -- Kick
    SHAMAN      = 57994,  -- Wind Shear
    WARLOCK     = 19647,  -- Spell Lock
    WARRIOR     = 6552,   -- Pummel
}
local _, playerClass = UnitClass("player")
local INTERRUPT_SPELL_ID = INTERRUPT_BY_CLASS[playerClass]

local function IsInInstanceContent()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
end

local function ShouldApply()
    if not isEnabled then return false end
    if instanceOnly and not IsInInstanceContent() then return false end
    return true
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

local function IsInterruptReady()
    if not INTERRUPT_SPELL_ID then return false end
    local cooldown = C_Spell.GetSpellCooldown(INTERRUPT_SPELL_ID)
    if not cooldown then return false end
    if cooldown.startTime == 0 then return true end
    return (cooldown.startTime + cooldown.duration - GetTime()) <= 0
end

local function UnitIsCastingInterruptible(unit)
    local name, _, _, _, _, _, _, notInterruptible = UnitCastingInfo(unit)
    if name then return not notInterruptible end
    name, _, _, _, _, _, _, notInterruptible = UnitChannelInfo(unit)
    if name then return not notInterruptible end
    return false
end

-- Returns true when the unit is casting something interruptible but our kick is on CD
local function ShouldShowInterruptWarning(unit)
    if not interruptWarningEnabled then return false end
    if not UnitIsCastingInterruptible(unit) then return false end
    return not IsInterruptReady()
end

-- Apply the correct health bar color for a nameplate unit
local function ApplyNameplateColor(unit, healthBar)
    if ShouldShowInterruptWarning(unit) then
        healthBar:SetStatusBarColor(INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B)
        return
    end
    local powerType = UnitPowerType(unit)
    if powerType == Enum.PowerType.Mana then
        healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
    end
end

local function UpdateNameplateColor(unit)
    if not unit or not ShouldApply() then return end
    if not IsEnemyUnit(unit) then return end
    local healthBar = GetHealthBar(unit)
    if not healthBar then return end
    ApplyNameplateColor(unit, healthBar)
end

-- Post-hook for Blizzard's health color update — re-applies our color after
-- Blizzard sets its default so mana coloring persists through combat/threat changes
local function OnHealthColorUpdated(frame)
    if not ShouldApply() or not frame then return end
    local unit = frame.unit
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not IsEnemyUnit(unit) then return end
    if not frame.healthBar then return end
    ApplyNameplateColor(unit, frame.healthBar)
end

-- Refresh all visible nameplates (used when interrupt cooldown state changes)
local function RefreshAllNameplates()
    if not ShouldApply() then return end
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = nameplate.UnitFrame
        if uf and uf.unit then
            UpdateNameplateColor(uf.unit)
        end
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
eventFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")

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

function NameplatesEnhancement:LoadInterruptWarningColor()
    local c = self.parent:GetConfig("nameplatesEnhancement", "interruptWarningColor")
    if c then
        INTERRUPT_WARN_R = c.r or DEFAULT_INTERRUPT_WARN_R
        INTERRUPT_WARN_G = c.g or DEFAULT_INTERRUPT_WARN_G
        INTERRUPT_WARN_B = c.b or DEFAULT_INTERRUPT_WARN_B
    else
        INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B = DEFAULT_INTERRUPT_WARN_R, DEFAULT_INTERRUPT_WARN_G, DEFAULT_INTERRUPT_WARN_B
    end
end

function NameplatesEnhancement:RefreshInterruptWarning()
    interruptWarningEnabled = self.parent:GetConfig("nameplatesEnhancement", "interruptWarning") or false
    self:LoadInterruptWarningColor()
    RefreshAllNameplates()
end

function NameplatesEnhancement:OnInitialize()
end

function NameplatesEnhancement:OnEnable()
    isEnabled = true
    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
    interruptWarningEnabled = self.parent:GetConfig("nameplatesEnhancement", "interruptWarning") or false
    self:LoadManaColor()
    self:LoadInterruptWarningColor()

    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if event == "SPELL_UPDATE_COOLDOWN" then
            RefreshAllNameplates()
            return
        end

        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START"
            or event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP"
            or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if unit and unit:match("^nameplate%d+$") then
                UpdateNameplateColor(unit)
            end
            return
        end

        if not unit or not unit:match("^nameplate%d+$") then return end
        UpdateNameplateColor(unit)
    end)

    eventFrame:RegisterEvent("UNIT_SPELLCAST_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

function NameplatesEnhancement:RefreshInstanceOnly()
    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
end

function NameplatesEnhancement:OnDisable()
    isEnabled = false
    eventFrame:SetScript("OnEvent", nil)
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_START")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
end

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
