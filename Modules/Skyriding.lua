-- B.O.L.T Skyriding Module
-- Remaps A/D → TURNLEFT/TURNRIGHT (and optionally W/S → PITCH) while the
-- player is actively in dynamic flight (Skyriding).
--
-- Safety guarantees
--   1. ClearOverrideBindings is NOT a protected function – it can be called
--      at any time, including in combat. Clearing stuck bindings is therefore
--      always possible immediately.
--   2. When overrides are active the watchdog runs every FRAME so landing is
--      detected in < 1 game tick (~16 ms). There is no 50 ms stuck window.
--   3. SetOverrideBinding IS protected. Activation is only attempted when
--      InCombatLockdown() == false.
--   4. Every event path that implies dismount / landing calls EagerClear()
--      before any deferred logic – even when in combat.
--   5. /boltreset and /boltnuke are always available as a last-resort escape.

local ADDON_NAME, BOLT = ...

local Skyriding = {}

-- ── state ─────────────────────────────────────────────────────────────────
local overrideFrame = nil   -- Frame that owns our override bindings
local isActive      = false -- true while override bindings are in effect
local leftDown      = false -- GLOBAL_MOUSE_DOWN/UP tracking
local rightDown     = false

-- ── local cache ───────────────────────────────────────────────────────────
local playerClass = UnitClassBase and select(1, UnitClassBase("player"))
                 or select(2, UnitClass("player"))

-- ── helpers ───────────────────────────────────────────────────────────────
local function CanApply()  return not InCombatLockdown() end

local function Debug(s)
    if BOLT:GetConfig("debug") then BOLT:Print(s) end
end

-- Returns true when the player is in Skyriding (dynamic flight) mode.
-- Absence of the "Steady Flight" aura (id 404468) means dynamic flight.
-- issecretvalue guard handles tainted return values from protected code.
local function IsSkyridingMode()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(404468)
    if issecretvalue and issecretvalue(aura) then return true end
    return aura == nil
end

local function IsDruidSkyForm()
    if playerClass ~= "DRUID" then return false end
    local id = GetShapeshiftFormID and GetShapeshiftFormID()
    if id == 27 or id == 29 then return true end
    return IsFlying() and GetShapeshiftForm and GetShapeshiftForm() == 3
end

-- Single source of truth: is the player actively skyriding right now?
local function InSkyridingFlight()
    if not IsFlying()                        then return false end
    if not (IsMounted() or IsDruidSkyForm()) then return false end
    if not IsAdvancedFlyableArea()           then return false end
    if not IsOutdoors()                      then return false end
    if not IsSkyridingMode()                 then return false end
    return true
end

-- Should override bindings be active right now?
local function ShouldBeActive()
    if not BOLT:IsModuleEnabled("skyriding") then return false end
    if not InSkyridingFlight()               then return false end
    if BOLT:GetConfig("skyriding", "requireMouseButton") then
        return leftDown and not rightDown
    end
    return true
end

-- ── override frame management ─────────────────────────────────────────────
local function EnsureFrame()
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "BOLTSkyridingOverrideFrame")
    end
end

-- Clear all override bindings.  Safe to call at ANY time – including combat.
local function DoClear()
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
    end
end

-- Apply override bindings.  Must only be called when CanApply() is true.
local function DoApply()
    EnsureFrame()
    local function bind(cmd, baseBinding)
        local k1, k2, k3, k4 = GetBindingKey(baseBinding)
        if k1 then SetOverrideBinding(overrideFrame, true, k1, cmd) end
        if k2 then SetOverrideBinding(overrideFrame, true, k2, cmd) end
        if k3 then SetOverrideBinding(overrideFrame, true, k3, cmd) end
        if k4 then SetOverrideBinding(overrideFrame, true, k4, cmd) end
    end
    bind("TURNLEFT",  "STRAFELEFT")
    bind("TURNRIGHT", "STRAFERIGHT")
    if BOLT:GetConfig("skyriding", "enablePitchControl") then
        local inv = BOLT:GetConfig("skyriding", "invertPitch")
        bind(inv and "PITCHDOWN" or "PITCHUP",   "MOVEFORWARD")
        bind(inv and "PITCHUP"   or "PITCHDOWN", "MOVEBACKWARD")
    end
end

-- ── activate / deactivate ─────────────────────────────────────────────────
local function Activate()
    -- SetOverrideBinding is a protected API – requires out-of-combat.
    if not CanApply() then return end
    DoApply()
    isActive = true
    Debug("Skyriding overrides ON")
end

-- Immediately clear override bindings.
-- ClearOverrideBindings is NOT protected → always callable.
local function Deactivate()
    DoClear()
    isActive = false
    Debug("Skyriding overrides OFF")
end

-- Unconditional clear: strips bindings whenever "not flying" is detected,
-- even mid-combat.  Called from the per-frame watchdog and event handlers.
local function EagerClear()
    if isActive then
        Deactivate()
    end
end

-- Full recalc: bring isActive in line with ShouldBeActive().
-- Only attempts Activate() when CanApply() is true.
local function Recalc()
    -- Safety net: if we still think we're active but aren't flying, clear NOW.
    if isActive and not IsFlying() then
        Deactivate()
        return
    end
    local should = ShouldBeActive()
    if should and not isActive then
        Activate()
    elseif not should and isActive then
        Deactivate()
    end
end

-- ── watchdog ──────────────────────────────────────────────────────────────
-- When overrides are ACTIVE  → check IsFlying() on EVERY frame (< 1 tick).
-- When overrides are inactive → poll at INACTIVE_INTERVAL to catch mount-up.
-- This gives the fastest possible landing detection with minimal overhead
-- while idle.

local watchdogFrame = nil
local watchdogTimer = 0
local INACTIVE_INTERVAL = 0.5  -- seconds between inactive polls

local function StartWatchdog()
    if watchdogFrame then return end
    watchdogFrame = CreateFrame("Frame", "BOLTSkyridingWatchdog")
    watchdogFrame:SetScript("OnUpdate", function(_, dt)
        if isActive then
            -- Per-frame fast path: clear the instant we stop flying.
            -- ClearOverrideBindings is not protected so this always works.
            if not IsFlying() then
                EagerClear()
            end
        else
            watchdogTimer = watchdogTimer + dt
            if watchdogTimer >= INACTIVE_INTERVAL then
                watchdogTimer = 0
                if CanApply() then Recalc() end
            end
        end
    end)
end

local function StopWatchdog()
    if watchdogFrame then
        watchdogFrame:SetScript("OnUpdate", nil)
        watchdogFrame = nil
    end
    watchdogTimer = 0
end

-- ── event frame ───────────────────────────────────────────────────────────
function Skyriding:CreateEventFrame()
    if self.eventFrame then return end
    self.eventFrame = CreateFrame("Frame", "BOLTSkyridingEvents")

    -- Mount / flight state
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_AURA")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
    self.eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

    -- Mouse button tracking (for requireMouseButton option)
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")

    -- Combat lockdown (blocks Activate; does NOT block Deactivate)
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        -- ── Combat ────────────────────────────────────────────────────────
        if event == "PLAYER_REGEN_DISABLED" then
            -- Cannot Activate while in combat, but CAN Deactivate.
            -- Clear immediately if we are no longer flying.
            if isActive and not IsFlying() then Deactivate() end

        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Out of combat: attempt to activate if conditions are met.
            Recalc()

        -- ── Mouse buttons ──────────────────────────────────────────────────
        elseif event == "GLOBAL_MOUSE_DOWN" then
            local btn = ...
            if btn == "LeftButton" then
                leftDown = true
                Recalc()
            elseif btn == "RightButton" then
                rightDown = true
                if isActive then Recalc() end
            end

        elseif event == "GLOBAL_MOUSE_UP" then
            local btn = ...
            if btn == "LeftButton" then
                leftDown = false
                -- Eagerly clear when requireMouseButton is on – no need to
                -- wait for the watchdog or a full Recalc.
                if isActive and BOLT:GetConfig("skyriding", "requireMouseButton") then
                    Deactivate()
                else
                    Recalc()
                end
            elseif btn == "RightButton" then
                rightDown = false
                Recalc()
            end

        -- ── Dismount / landing hints ───────────────────────────────────────
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
            -- Fire immediately so we never leave bindings on after dismount.
            if not IsFlying() then EagerClear() end
            C_Timer.After(0.1, function() if CanApply() then Recalc() end end)

        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" then
                if not IsFlying() then EagerClear() end
                if CanApply() then Recalc() end
            end

        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit = ...
            if unit == "player" then
                C_Timer.After(0.1, function()
                    if not IsFlying() then EagerClear() end
                    if CanApply() then Recalc() end
                end)
            end

        elseif event == "UPDATE_SHAPESHIFT_FORM"
            or event == "UPDATE_SHAPESHIFT_FORMS" then
            C_Timer.After(0, function()
                if not IsFlying() then EagerClear() end
                if CanApply() then Recalc() end
            end)

        elseif event == "ZONE_CHANGED"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "PLAYER_ENTERING_WORLD"
            or event == "MOUNT_JOURNAL_USABILITY_CHANGED" then
            -- Eagerly clear on zone transitions; landing detection in the
            -- new zone will re-activate if still in dynamic flight.
            if not IsFlying() then EagerClear() end
            C_Timer.After(0.2, function()
                if not IsFlying() then EagerClear() end
                if CanApply() then Recalc() end
            end)
        end
    end)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────
function Skyriding:OnInitialize() end

function Skyriding:OnEnable()
    Debug("Skyriding OnEnable")
    self:CreateEventFrame()
    StartWatchdog()
    if CanApply() then Recalc() end
end

function Skyriding:OnDisable()
    StopWatchdog()

    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end

    -- Always clear bindings on disable.  ClearOverrideBindings is safe to
    -- call in combat, so this works regardless of lockdown state.
    DoClear()
    isActive  = false
    leftDown  = false
    rightDown = false

    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
        overrideFrame = nil
    end
end

-- ── public API ────────────────────────────────────────────────────────────

-- Called by Config when pitch settings change.
function Skyriding:OnPitchSettingChanged()
    if not isActive or not CanApply() then return end
    -- Re-apply with updated settings; WoW picks up new bindings on next tick.
    DoClear()
    DoApply()
end

-- Hard reset – clears everything regardless of state.
function Skyriding:EmergencyReset()
    -- ClearOverrideBindings is not protected – always works.
    DoClear()
    leftDown  = false
    rightDown = false
    isActive  = false
    BOLT:Print("B.O.L.T: Skyriding emergency reset complete.")
end

-- ── slash commands ────────────────────────────────────────────────────────
SLASH_BOLTRESET1 = "/boltreset"
SLASH_BOLTRESET2 = "/boltnuke"
SlashCmdList["BOLTRESET"] = function()
    if Skyriding and Skyriding.EmergencyReset then
        Skyriding:EmergencyReset()
    end
end

-- ── register ─────────────────────────────────────────────────────────────
BOLT:RegisterModule("skyriding", Skyriding)