-- B.O.L.T Nameplates Enhancement Module
-- Recolors enemy nameplate health bars for mana users (healers and casters).

local ADDON_NAME, BOLT = ...

local NameplatesEnhancement = {
    displayName = "Nameplates",
}

local DEFAULT_MANA_COLOR = { r = 0.2, g = 0.4, b = 1.0 }
local manaR, manaG, manaB = DEFAULT_MANA_COLOR.r, DEFAULT_MANA_COLOR.g, DEFAULT_MANA_COLOR.b
local hooked = false

local function ShouldApply()
    if not NameplatesEnhancement.active then return false end
    if BOLT:GetConfig("nameplatesEnhancement", "instanceOnly") then
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
    if not (unit and frame.healthBar and ShouldApply()) then return end
    if not unit:find("^nameplate%d") then return end
    if IsEnemyManaUser(unit) then
        frame.healthBar:SetStatusBarColor(manaR, manaG, manaB)
    end
end

local function ColorUnit(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate then
        ColorFrame(plate.UnitFrame)
    end
end

function NameplatesEnhancement:LoadManaColor()
    local color = BOLT:GetConfig("nameplatesEnhancement", "manaColor") or DEFAULT_MANA_COLOR
    manaR, manaG, manaB = color.r, color.g, color.b
end

function NameplatesEnhancement:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, _, unit)
        if unit and unit:find("^nameplate%d") then
            ColorUnit(unit)
        end
    end)
end

function NameplatesEnhancement:OnEnable()
    self:LoadManaColor()

    -- Blizzard recolors on threat/reaction changes; re-apply after it. hooksecurefunc
    -- can't be removed, so the hook checks ShouldApply and stays inert when disabled.
    if not hooked then
        hooksecurefunc("CompactUnitFrame_UpdateHealthColor", ColorFrame)
        hooked = true
    end

    self.eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    self.eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    self.eventFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")
end

function NameplatesEnhancement:OnDisable()
    self.eventFrame:UnregisterAllEvents()
end

function NameplatesEnhancement:OnSettingChanged()
    self:LoadManaColor()
    -- Only recolor; calling Blizzard's update from addon code would taint the plates.
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        ColorFrame(plate.UnitFrame)
    end
end

NameplatesEnhancement.DEFAULT_MANA_COLOR = DEFAULT_MANA_COLOR

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
