-- B.O.L.T Skyriding Module (mouse-hold only)
-- A/D -> horizontal turn, optional W/S -> pitch (climb/dive)
-- Active only while Skyriding AND holding Left Mouse (not both buttons).
--
-- State machine prevents stuck keys by NEVER changing override bindings
-- while managed keys are physically held. Overrides are only applied/cleared
-- after all managed keys are released.

local ADDON_NAME, BOLT = ...

local Skyriding = {}

-- State machine:
--   "idle"              – no overrides applied
--   "active"            – overrides applied and working
--   "pendingActivate"   – waiting for managed keys to release before applying
--   "pendingDeactivate" – waiting for managed keys to release before clearing
local state = "idle"

local leftDown, rightDown = false, false
local inCombat = false
local inSkyriding = false
local overrideFrame
local transitionPoller -- OnUpdate frame for pending-state polling
local watchdog

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

local function IsSkyridingActiveNow()
    return IsMounted()
       and IsAdvancedFlyableArea()
       and IsOutdoors()
       and IsSkyridingSelected()
       and IsFlying()
end

-- Keys we manage (cached by pitch setting)
local managedCache, managedCachePitch = nil, nil
local function GetManagedKeys(enablePitch)
    if managedCache and managedCachePitch == enablePitch then
        return managedCache
    end
    local t = {}
    local function addAll(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            if key then t[#t + 1] = key end
        end
    end
    addAll(GetBindingKey("STRAFELEFT"))
    addAll(GetBindingKey("STRAFERIGHT"))
    if enablePitch then
        addAll(GetBindingKey("MOVEFORWARD"))
        addAll(GetBindingKey("MOVEBACKWARD"))
    end
    managedCache, managedCachePitch = t, enablePitch
    return t
end

local function AnyManagedKeyDown()
    local enablePitch = BOLT:GetConfig("skyriding", "enablePitchControl")
    local keys = GetManagedKeys(enablePitch)
    for i = 1, #keys do
        if IsKeyDown(keys[i]) then return true end
    end
    return false
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
-- Transition poller
-- Polls every frame; fires callback once ALL managed keys are released.
-- No timeout – overrides stay until keys are physically up.
-- =========================
local function StopTransitionPoller()
    if transitionPoller then
        transitionPoller:SetScript("OnUpdate", nil)
        transitionPoller = nil
    end
end

local function StartTransitionPoller(onKeysReleased)
    StopTransitionPoller()
    transitionPoller = CreateFrame("Frame")
    transitionPoller:SetScript("OnUpdate", function()
        if not Safe() then return end
        if not AnyManagedKeyDown() then
            StopTransitionPoller()
            onKeysReleased()
        end
    end)
end

-- =========================
-- Actual apply / remove helpers (only called when keys are up)
-- =========================
local function DoActivate()
    if not Safe() then return end
    if not BOLT:IsModuleEnabled("skyriding") then return end
    if not IsSkyridingSelected() then return end
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "BOLTSkyridingOverrideFrame")
    end
    local enablePitch = BOLT:GetConfig("skyriding", "enablePitchControl")
    ApplyBindings(enablePitch, BOLT:GetConfig("skyriding", "invertPitch"))
    state = "active"
    if BOLT:GetConfig("debug") then
        local pitch = enablePitch
            and (BOLT:GetConfig("skyriding", "invertPitch")
                 and " W=dive S=climb" or " W=climb S=dive")
            or ""
        BOLT:Print(("Skyriding overrides ON (hold LMB)%s"):format(pitch))
    end
end

local function DoDeactivate()
    if not Safe() then return end
    ClearOverrides()
    state = "idle"
    if BOLT:GetConfig("debug") then
        BOLT:Print("Skyriding overrides OFF")
    end
end

-- =========================
-- Core state transitions
-- =========================
local Recalc -- forward declaration (used in TransitionTo before definition)

local function ShouldBeActive()
    return inSkyriding and leftDown and not rightDown
end

local function TransitionTo(desired)
    if not Safe() then return end

    if desired == "active" then
        if state == "active" then return end
        if state == "pendingDeactivate" then
            -- Cancel pending deactivation – overrides are still in place
            StopTransitionPoller()
            state = "active"
            if BOLT:GetConfig("debug") then
                BOLT:Print("Skyriding: cancelled pending deactivation, staying active")
            end
            return
        end
        if state == "pendingActivate" then return end -- already waiting

        -- From idle: apply overrides only when no managed keys are held
        StopTransitionPoller()
        if AnyManagedKeyDown() then
            state = "pendingActivate"
            StartTransitionPoller(function()
                if ShouldBeActive() then
                    DoActivate()
                else
                    state = "idle"
                end
            end)
        else
            DoActivate()
        end

    elseif desired == "idle" then
        if state == "idle" then return end
        if state == "pendingActivate" then
            -- Cancel pending activation – no overrides were applied yet
            StopTransitionPoller()
            state = "idle"
            return
        end
        if state == "pendingDeactivate" then return end -- already waiting

        -- From active: clear overrides only when no managed keys are held
        StopTransitionPoller()
        if AnyManagedKeyDown() then
            state = "pendingDeactivate"
            StartTransitionPoller(function()
                DoDeactivate()
                -- Re-evaluate in case conditions changed while waiting
                C_Timer.After(0, function() if Safe() then Recalc() end end)
            end)
        else
            DoDeactivate()
        end
    end
end

Recalc = function()
    if not Safe() then return end
    inSkyriding = IsSkyridingActiveNow()
    if ShouldBeActive() then
        TransitionTo("active")
    else
        TransitionTo("idle")
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

    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")

    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true

        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
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
    inCombat = InCombatLockdown()
    self:CreateEventFrame()
    StartWatchdog()
    Recalc()
end

function Skyriding:OnDisable()
    StopWatchdog()
    StopTransitionPoller()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
    if Safe() and (state == "active" or state == "pendingDeactivate") then
        ClearOverrides()
    end
    leftDown, rightDown = false, false
    inSkyriding, inCombat = false, false
    state = "idle"
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
        overrideFrame = nil
    end
end

-- =========================
-- Public hooks / settings
-- =========================
function Skyriding:OnPitchSettingChanged()
    managedCache, managedCachePitch = nil, nil
    if state ~= "active" or not Safe() then return end
    if not AnyManagedKeyDown() then
        ClearOverrides()
        ApplyBindings(
            BOLT:GetConfig("skyriding", "enablePitchControl"),
            BOLT:GetConfig("skyriding", "invertPitch")
        )
    else
        -- Wait for keys to release, then re-apply with new settings
        StartTransitionPoller(function()
            if state ~= "active" or not Safe() then return end
            ClearOverrides()
            ApplyBindings(
                BOLT:GetConfig("skyriding", "enablePitchControl"),
                BOLT:GetConfig("skyriding", "invertPitch")
            )
        end)
    end
end

function Skyriding:EmergencyReset()
    if InCombatLockdown() then
        self.parent:Print("B.O.L.T: Can't reset in combat.")
        return
    end
    StopTransitionPoller()
    if overrideFrame then ClearOverrideBindings(overrideFrame) end
    leftDown, rightDown = false, false
    inSkyriding = false
    state = "idle"
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
