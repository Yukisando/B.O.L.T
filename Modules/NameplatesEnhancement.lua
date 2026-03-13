local ADDON_NAME, BOLT = ...

local NameplatesEnhancement = {}

local MANA_R, MANA_G, MANA_B = 0.2, 0.4, 1.0
local DEFAULT_MANA_R, DEFAULT_MANA_G, DEFAULT_MANA_B = 0.2, 0.4, 1.0

local isEnabled = false
local instanceOnly = false

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

-- Color enemy nameplate health bars for mana users
local function UpdateNameplatePowerColor(unit)
    if not unit or not ShouldApply() then return end
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
    if not ShouldApply() or not frame then return end
    local unit = frame.unit
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not IsEnemyUnit(unit) then return end

    local powerType = UnitPowerType(unit)
    if powerType == Enum.PowerType.Mana and frame.healthBar then
        frame.healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
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

function NameplatesEnhancement:OnInitialize()
end

function NameplatesEnhancement:OnEnable()
    isEnabled = true
    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
    self:LoadManaColor()

    eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
        if not unit or not unit:match("^nameplate%d+$") then return end

        if event == "NAME_PLATE_UNIT_ADDED" then
            UpdateNameplatePowerColor(unit)
        elseif event == "UNIT_DISPLAYPOWER" or event == "UNIT_POWER_BAR_SHOW" then
            UpdateNameplatePowerColor(unit)
        end
    end)
end

function NameplatesEnhancement:RefreshInstanceOnly()
    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
end

function NameplatesEnhancement:OnDisable()
    isEnabled = false
    eventFrame:SetScript("OnEvent", nil)
end

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
