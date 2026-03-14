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

-- Mana color
local function UpdateNameplateManaColor(unit)
    if not unit or not ShouldApply() then return end
    if not IsEnemyUnit(unit) then return end

    local healthBar = GetHealthBar(unit)
    if not healthBar then return end

    local powerType = UnitPowerType(unit)

    if powerType == Enum.PowerType.Mana then
        healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
    end
end

local function OnHealthColorUpdated(frame)
    if not ShouldApply() or not frame then return end

    local unit = frame.unit
    if not unit or not unit:match("^nameplate%d+$") then return end
    if not IsEnemyUnit(unit) then return end

    if not frame.healthBar then return end

    local powerType = UnitPowerType(unit)

    if powerType == Enum.PowerType.Mana then
        frame.healthBar:SetStatusBarColor(MANA_R, MANA_G, MANA_B)
    end
end

-- eventFrame is created lazily inside OnEnable rather than at module load time.
-- Creating frames, registering events, or calling hooksecurefunc at load time runs
-- during Blizzard's secure UI initialisation phase. Addon code in that phase can
-- taint the execution context used by GameMenuFrame_Setup, causing all
-- GameMenuButton.callback values to be treated as tainted — which triggers
-- ADDON_ACTION_FORBIDDEN for every GameMenu button (Disconnect, Logout, etc.).
local eventFrame

-- LIFECYCLE

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

    -- Lazy-create the event frame so no addon code runs at module load time.
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    -- Register the core nameplate events (mirrored in OnDisable).
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:RegisterEvent("UNIT_POWER_BAR_SHOW")

    -- hooksecurefunc cannot be un-hooked, so only install it once per session.
    -- The hook body re-checks isEnabled / ShouldApply() so it is safely inert
    -- when the module is disabled.
    if not NameplatesEnhancement._healthColorHooked then
        if CompactUnitFrame_UpdateHealthColor then
            hooksecurefunc("CompactUnitFrame_UpdateHealthColor", OnHealthColorUpdated)
        elseif CompactUnitFrameMixin and CompactUnitFrameMixin.UpdateHealthColor then
            hooksecurefunc(CompactUnitFrameMixin, "UpdateHealthColor", OnHealthColorUpdated)
        end
        NameplatesEnhancement._healthColorHooked = true
    end

    eventFrame:SetScript("OnEvent", function(_, event, unit)
        if not unit or not unit:match("^nameplate%d+$") then return end

        if event == "NAME_PLATE_UNIT_ADDED" then
            UpdateNameplateManaColor(unit)
            return
        end

        UpdateNameplateManaColor(unit)
    end)
end

function NameplatesEnhancement:RefreshInstanceOnly()
    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
end

function NameplatesEnhancement:OnDisable()
    isEnabled = false

    if not eventFrame then return end

    eventFrame:SetScript("OnEvent", nil)

    -- Unregister everything registered in OnEnable.
    eventFrame:UnregisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:UnregisterEvent("UNIT_POWER_BAR_SHOW")
end

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
