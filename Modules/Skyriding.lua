-- B.O.L.T Skyriding Module
-- A/D -> horizontal turn, optional W/S -> pitch (climb/dive)
-- Active only while Skyriding (and optionally only while holding Left Mouse).
--
-- Simple two-state design: overrides are applied/cleared immediately when out
-- of combat. In-combat changes are deferred until PLAYER_REGEN_ENABLED fires.
-- WoW movement commands use held-key polling (not discrete events), so it is
-- safe to call ClearOverrideBindings while a movement key is held -- the engine
-- drops the old command and picks up the base binding on the very next tick.

local ADDON_NAME, BOLT = ...

local Skyriding = {}

local isActive = false  -- are override bindings currently in effect?
local leftDown, rightDown = false, false
local inSkyriding = false
local overrideFrame
local watchdog
local playerClass = UnitClassBase and select(1, UnitClassBase("player")) or select(2, UnitClass("player"))

local function Safe() return not InCombatLockdown() end

-- "Steady Flight" aura (id 404468) means NOT Skyriding
-- Midnight (12.0.0): GetPlayerAuraBySpellID may return secret values from
-- tainted code in combat; use issecretvalue to avoid comparison errors.
local function IsSkyridingSelected()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(404468)
    if issecretvalue and issecretvalue(aura) then
        return true
    end
    return aura == nil
end

local function IsDruidFlightFormActive()
    if playerClass ~= "DRUID" then
        return false
    end

    local formID = GetShapeshiftFormID and GetShapeshiftFormID()
    if formID == 27 or formID == 29 then
        return true
    end

    return IsFlying() and GetShapeshiftForm and GetShapeshiftForm() == 3
end

local function IsSkyridingActiveNow()
    return (IsMounted() or IsDruidFlightFormActive())
       and IsAdvancedFlyableArea()
       and IsOutdoors()
       and IsSkyridingSelected()
       and IsFlying()
end

-- =========================
-- Binding apply / clear
-- =========================
local function ClearOverrides()
    if overrideFrame then ClearOverrideBindings(overrideFrame) end
end

local function ApplyBindings(enablePitch, invertPitch)
    if not overrideFrame then return end
    local function bindTo(cmd, binding)
        local k1, k2, k3, k4 = GetBindingKey(binding)
        if k1 then SetOverrideBinding(overrideFrame, true, k1, cmd) end
        if k2 then SetOverrideBinding(overrideFrame, true, k2, cmd) end
        if k3 then SetOverrideBinding(overrideFrame, true, k3, cmd) end
        if k4 then SetOverrideBinding(overrideFrame, true, k4, cmd) end
    end
    bindTo("TURNLEFT",  "STRAFELEFT")
    bindTo("TURNRIGHT", "STRAFERIGHT")
    if enablePitch then
        bindTo(invertPitch and "PITCHDOWN" or "PITCHUP",   "MOVEFORWARD")
        bindTo(invertPitch and "PITCHUP"   or "PITCHDOWN", "MOVEBACKWARD")
    end
end

-- =========================
-- State helpers
-- =========================
local function ShouldBeActive()
    if BOLT:GetConfig("skyriding", "requireMouseButton") then
        return inSkyriding and leftDown and not rightDown
    end
    return inSkyriding
end

local function Activate()
    if not Safe() then return end
    if not BOLT:IsModuleEnabled("skyriding") then return end
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "BOLTSkyridingOverrideFrame")
    end
    local enablePitch = BOLT:GetConfig("skyriding", "enablePitchControl")
    ApplyBindings(enablePitch, BOLT:GetConfig("skyriding", "invertPitch"))
    isActive = true
    if BOLT:GetConfig("debug") then
        local pitch = enablePitch
            and (BOLT:GetConfig("skyriding", "invertPitch")
                 and " W=dive S=climb" or " W=climb S=dive")
            or ""
        local mouseStr = BOLT:GetConfig("skyriding", "requireMouseButton") and " (hold LMB)" or ""
        BOLT:Print(("Skyriding overrides ON%s%s"):format(mouseStr, pitch))
    end
end

local function Deactivate()
    if not Safe() then return end
    ClearOverrides()
    isActive = false
    if BOLT:GetConfig("debug") then
        BOLT:Print("Skyriding overrides OFF")
    end
end

local function Recalc()
    if not Safe() then return end
    inSkyriding = IsSkyridingActiveNow()
    local should = ShouldBeActive()
    if should and not isActive then
        Activate()
    elseif not should and isActive then
        Deactivate()
    end
end

-- Watchdog: catches rare desyncs (eaten mouse-up, etc.)
local function StartWatchdog()
    if watchdog then return end
    watchdog = CreateFrame("Frame")
    local t = 0
    watchdog:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t >= 1 then
            t = 0
            if Safe() then Recalc() end
        end
    end)
end

local function StopWatchdog()
    if watchdog then
        watchdog:SetScript("OnUpdate", nil)
        watchdog = nil
    end
end

-- =========================
-- Events
-- =========================
function Skyriding:CreateEventFrame()
    if self.eventFrame then return end
    self.eventFrame = CreateFrame("Frame")

    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_AURA")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")

    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Nothing to do immediately; Safe() will block any transition
            -- until PLAYER_REGEN_ENABLED fires.

        elseif event == "PLAYER_REGEN_ENABLED" then
            Recalc()

        elseif event == "GLOBAL_MOUSE_DOWN" then
            if InCombatLockdown() then return end
            local btn = ...
            if btn == "LeftButton" then
                leftDown = true
                Recalc()
            elseif btn == "RightButton" then
                rightDown = true
                Recalc()
            end

        elseif event == "GLOBAL_MOUSE_UP" then
            if InCombatLockdown() then return end
            local btn = ...
            if btn == "LeftButton" then
                leftDown = false
                Recalc()
            elseif btn == "RightButton" then
                rightDown = false
                Recalc()
            end

        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" and Safe() then Recalc() end

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit = ...
            if unit == "player" then
                C_Timer.After(0.1, function() if Safe() then Recalc() end end)
            end

        elseif event == "UPDATE_SHAPESHIFT_FORM"
            or event == "UPDATE_SHAPESHIFT_FORMS" then
            C_Timer.After(0, function() if Safe() then Recalc() end end)

        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED"
            or event == "MOUNT_JOURNAL_USABILITY_CHANGED"
            or event == "ZONE_CHANGED"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(0.2, function() if Safe() then Recalc() end end)
        end
    end)
end

-- =========================
-- Lifecycle
-- =========================
function Skyriding:OnInitialize() end

function Skyriding:OnEnable()
    if BOLT:GetConfig("debug") then
        BOLT:Print("Skyriding OnEnable")
    end
    self:CreateEventFrame()
    StartWatchdog()
    Recalc()
end

function Skyriding:OnDisable()
    StopWatchdog()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
    if Safe() and isActive then
        ClearOverrides()
    end
    leftDown, rightDown = false, false
    inSkyriding = false
    isActive = false
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
        overrideFrame = nil
    end
end

-- =========================
-- Public hooks / settings
-- =========================
function Skyriding:OnPitchSettingChanged()
    if not isActive or not Safe() then return end
    -- Re-apply immediately with updated settings. WoW polling-based movement
    -- picks up the new binding on the next tick even if W/S is held.
    ClearOverrides()
    ApplyBindings(
        BOLT:GetConfig("skyriding", "enablePitchControl"),
        BOLT:GetConfig("skyriding", "invertPitch")
    )
end

function Skyriding:EmergencyReset()
    if InCombatLockdown() then
        self.parent:Print("B.O.L.T: Can't reset in combat.")
        return
    end
    if overrideFrame then ClearOverrideBindings(overrideFrame) end
    leftDown, rightDown = false, false
    inSkyriding = false
    isActive = false
    self.parent:Print("B.O.L.T: Emergency reset complete.")
end

-- =========================
-- Register
-- =========================
BOLT:RegisterModule("skyriding", Skyriding)

SLASH_BOLTRESET1, SLASH_BOLTRESET2 = "/boltreset", "/boltnuke"
SlashCmdList["BOLTRESET"] = function()
    if Skyriding and Skyriding.EmergencyReset then Skyriding:EmergencyReset() end
end
