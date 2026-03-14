local ADDON_NAME, BOLT = ...

local NameplatesEnhancement = {}

local MANA_R, MANA_G, MANA_B = 0.2, 0.4, 1.0
local DEFAULT_MANA_R, DEFAULT_MANA_G, DEFAULT_MANA_B = 0.2, 0.4, 1.0

local INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B = 0.8, 0.15, 0.15
local DEFAULT_INTERRUPT_WARN_R, DEFAULT_INTERRUPT_WARN_G, DEFAULT_INTERRUPT_WARN_B = 0.8, 0.15, 0.15

local INTERRUPT_SOON_R, INTERRUPT_SOON_G, INTERRUPT_SOON_B = 1.0, 0.55, 0.1

local isEnabled = false
local instanceOnly = false
local interruptWarningEnabled = false
local isApplyingCastBarColor = false
-- Maps nameplate unit token -> true when their active cast is not interruptible.
-- Populated via UNIT_SPELLCAST_NOT_INTERRUPTIBLE / UNIT_SPELLCAST_INTERRUPTIBLE events
-- to avoid reading the secret boolean from UnitCastingInfo (which taints addon code).
local notInterruptibleUnits = {}

-- Resolve interrupt spell
local INTERRUPT_BY_CLASS = {
    DEATHKNIGHT = 47528,
    DEMONHUNTER = 183752,
    DRUID = 106839,
    EVOKER = 351338,
    HUNTER = 147362,
    MAGE = 2139,
    MONK = 116705,
    PALADIN = 96231,
    PRIEST = 15487,
    ROGUE = 1766,
    SHAMAN = 57994,
    WARLOCK = 19647,
    WARRIOR = 6552,
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

-- interrupt ready timestamp
local function GetInterruptReadyTime()
    if not INTERRUPT_SPELL_ID then
        return math.huge
    end

    local cd = C_Spell.GetSpellCooldown(INTERRUPT_SPELL_ID)

    if not cd or cd.startTime == 0 then
        return GetTime()
    end

    return cd.startTime + cd.duration
end

local function UnitIsCastingInterruptible(unit)
    -- Do NOT read or boolean-test notInterruptible from UnitCastingInfo/UnitChannelInfo.
    -- For nameplate units it is a "secret boolean" whose boolean test taints addon code
    -- and causes cascading ADDON_ACTION_BLOCKED errors. Interruptibility is instead
    -- tracked via UNIT_SPELLCAST_NOT_INTERRUPTIBLE / UNIT_SPELLCAST_INTERRUPTIBLE events.
    local name = UnitCastingInfo(unit)
    if name then
        return not notInterruptibleUnits[unit]
    end

    name = UnitChannelInfo(unit)
    if name then
        return not notInterruptibleUnits[unit]
    end

    return false
end

local function GetUnitCastEndTime(unit)
    local _, _, _, _, endTimeMS = UnitCastingInfo(unit)
    if endTimeMS then
        return endTimeMS / 1000
    end

    _, _, _, _, endTimeMS = UnitChannelInfo(unit)
    if endTimeMS then
        return endTimeMS / 1000
    end

    return nil
end

local function GetInterruptState(unit)
    if not UnitIsCastingInterruptible(unit) then
        return "NONE"
    end

    local castEnd = GetUnitCastEndTime(unit)
    if not castEnd then
        return "NONE"
    end

    local readyTime = GetInterruptReadyTime()
    local now = GetTime()

    if readyTime <= now then
        return "READY"
    end

    if readyTime <= castEnd then
        return "SOON"
    end

    return "IMPOSSIBLE"
end

-- Tracks which castBar frames we have already hooked. Using a local Lua table
-- instead of writing a field onto the Blizzard-owned castBar frame avoids
-- tainting that frame from addon context.
local hookedCastBars = {}

-- Hook castbar
local function HookCastBar(nameplate)
    local uf = nameplate.UnitFrame
    if not uf then return end

    local castBar = uf.castBar or uf.CastBar
    if not castBar or hookedCastBars[castBar] then return end

    hookedCastBars[castBar] = true

    castBar:HookScript("OnUpdate", function(self)
        if not interruptWarningEnabled then return end
        if not ShouldApply() then return end

        local unit = self.unit
        if not unit then return end
        if not IsEnemyUnit(unit) then return end

        local state = GetInterruptState(unit)

        if state == "IMPOSSIBLE" then
            self:SetStatusBarColor(INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B)
        elseif state == "SOON" then
            self:SetStatusBarColor(INTERRUPT_SOON_R, INTERRUPT_SOON_G, INTERRUPT_SOON_B)
        end
    end)
end

local function RefreshAllCastBars()
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        local uf = nameplate.UnitFrame
        if uf then
            local castBar = uf.castBar or uf.CastBar
            if castBar then
                castBar:SetStatusBarColor(castBar:GetStatusBarColor())
            end
        end
    end
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

function NameplatesEnhancement:LoadInterruptWarningColor()
    local c = self.parent:GetConfig("nameplatesEnhancement", "interruptWarningColor")

    if c then
        INTERRUPT_WARN_R = c.r or DEFAULT_INTERRUPT_WARN_R
        INTERRUPT_WARN_G = c.g or DEFAULT_INTERRUPT_WARN_G
        INTERRUPT_WARN_B = c.b or DEFAULT_INTERRUPT_WARN_B
    else
        INTERRUPT_WARN_R, INTERRUPT_WARN_G, INTERRUPT_WARN_B =
            DEFAULT_INTERRUPT_WARN_R,
            DEFAULT_INTERRUPT_WARN_G,
            DEFAULT_INTERRUPT_WARN_B
    end
end

function NameplatesEnhancement:RefreshInterruptWarning()
    interruptWarningEnabled = self.parent:GetConfig("nameplatesEnhancement", "interruptWarning") or false

    self:LoadInterruptWarningColor()

    RefreshAllCastBars()
end

function NameplatesEnhancement:OnInitialize()
end

function NameplatesEnhancement:OnEnable()
    isEnabled = true

    instanceOnly = self.parent:GetConfig("nameplatesEnhancement", "instanceOnly") or false
    interruptWarningEnabled = self.parent:GetConfig("nameplatesEnhancement", "interruptWarning") or false

    self:LoadManaColor()
    self:LoadInterruptWarningColor()

    -- Lazy-create the event frame so no addon code runs at module load time.
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    -- Register the core nameplate events (mirrored in OnDisable).
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
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
        if event == "SPELL_UPDATE_COOLDOWN" then
            RefreshAllCastBars()
            return
        end

        if not unit or not unit:match("^nameplate%d+$") then return end

        if event == "NAME_PLATE_UNIT_ADDED" then
            local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
            if nameplate then
                HookCastBar(nameplate)
            end

            UpdateNameplateManaColor(unit)

            return
        end

        if event == "NAME_PLATE_UNIT_REMOVED" then
            notInterruptibleUnits[unit] = nil
            return
        end

        if event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
            notInterruptibleUnits[unit] = true
            return
        end

        if event == "UNIT_SPELLCAST_INTERRUPTIBLE"
                or event == "UNIT_SPELLCAST_STOP"
                or event == "UNIT_SPELLCAST_INTERRUPTED"
                or event == "UNIT_SPELLCAST_FAILED"
                or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            notInterruptibleUnits[unit] = nil
            return
        end

        UpdateNameplateManaColor(unit)
    end)

    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
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
    eventFrame:UnregisterEvent("NAME_PLATE_UNIT_REMOVED")
    eventFrame:UnregisterEvent("UNIT_DISPLAYPOWER")
    eventFrame:UnregisterEvent("UNIT_POWER_BAR_SHOW")
    eventFrame:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_STOP")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_FAILED")
    eventFrame:UnregisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    wipe(notInterruptibleUnits)
    wipe(hookedCastBars)
end

BOLT:RegisterModule("nameplatesEnhancement", NameplatesEnhancement)
