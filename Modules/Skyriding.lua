-- B.O.L.T Skyriding Module (mouse-hold only)
-- A/D -> horizontal turn, optional W/S -> pitch (climb/dive)
-- Active only while Skyriding AND holding Left Mouse (not both buttons).

local ADDON_NAME, BOLT = ...

local Skyriding = {}

-- =========================
-- Small, explicit state
-- =========================
local leftDown, rightDown = false, false
local inCombat = false
local inSkyriding = false
local active = false -- overrides currently applied
local overrideFrame
local watchdog

-- =========================
-- Helpers
-- =========================
local function Safe() return not InCombatLockdown() end

-- "Steady Flight" aura (id 404468) means NOT Skyriding
local function IsSkyridingSelected()
    return C_UnitAuras.GetPlayerAuraBySpellID(404468) == nil
end

-- Single source of truth
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
        for i=1, select("#", ...) do
            local key = select(i, ...)
            if key then t[#t+1] = key end
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

local function AnyKeyDown(keys)
    for i=1, #keys do if IsKeyDown(keys[i]) then return true end end
    return false
end

-- Gate: run cb once all managed keys are UP (or after timeout)
local deferFrame
local function DeferUntilKeysUp(keys, cb, timeout)
    if not keys or #keys == 0 or not AnyKeyDown(keys) then
        cb() ; return
    end
    if not deferFrame then deferFrame = CreateFrame("Frame") end
    local waiting = {}
    for i=1,#keys do if IsKeyDown(keys[i]) then waiting[keys[i]] = true end end
    local waited, limit = 0, timeout or 1.5
    deferFrame:SetScript("OnUpdate", function(_, dt)
        waited = waited + dt
        local held = false
        for k in pairs(waiting) do
            if IsKeyDown(k) then held = true break end
        end
        if not held or waited >= limit then
            deferFrame:SetScript("OnUpdate", nil)
            cb()
        end
    end)
end

-- =========================
-- Binding apply/clear
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
    -- A/D => turning (strafe -> turn)
    bindTo("TURNLEFT",  "STRAFELEFT")
    bindTo("TURNRIGHT", "STRAFERIGHT")
    -- W/S => pitch (optional)
    if enablePitch then
        bindTo(invertPitch and "PITCHDOWN" or "PITCHUP", "MOVEFORWARD")
        bindTo(invertPitch and "PITCHUP"   or "PITCHDOWN", "MOVEBACKWARD")
    end
end

local function Activate(reason)
    if active or not Safe() then return end
    if not BOLT:GetConfig("skyriding","enabled") then return end
    if not IsSkyridingSelected() then return end
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame","BOLTSkyridingOverrideFrame")
    end
    local enablePitch = BOLT:GetConfig("skyriding","enablePitchControl")
    local keys = GetManagedKeys(enablePitch)
    DeferUntilKeysUp(keys, function()
        if not Safe() then return end
        ApplyBindings(enablePitch, BOLT:GetConfig("skyriding","invertPitch"))
        active = true
        if BOLT:GetConfig("debug") then
            local pitch  = enablePitch and (BOLT:GetConfig("skyriding","invertPitch") and " W=dive S=climb" or " W=climb S=dive") or ""
            BOLT:Print(("Skyriding overrides ON (hold LMB)%s"):format(pitch))
        end
    end, 1.0)
end

local function Deactivate(reason)
    if not active or not Safe() then return end
    local enablePitch = BOLT:GetConfig("skyriding","enablePitchControl")
    local keys = GetManagedKeys(enablePitch)
    DeferUntilKeysUp(keys, function()
        if not Safe() then return end
        ClearOverrides()
        active = false
        if BOLT:GetConfig("debug") then
            BOLT:Print("Skyriding overrides OFF")
        end
    end, 1.0)
end

-- =========================
-- State driver
-- =========================
local function ShouldBeActive()
    -- Only active when: skyriding AND LMB down AND RMB not down
    return inSkyriding and leftDown and not rightDown
end

local function Recalc()
    if not Safe() then return end
    inSkyriding = IsSkyridingActiveNow()
    if ShouldBeActive() and not active then
        Activate("recalc")
    elseif not ShouldBeActive() and active then
        Deactivate("recalc")
    end
end

-- 3s watchdog to fix rare desyncs (e.g., eaten mouse-up)
local function StartWatchdog()
    if watchdog then return end
    watchdog = CreateFrame("Frame")
    local t = 0
    watchdog:SetScript("OnUpdate", function(_, dt)
        t = t + dt
        if t >= 3 then
            t = 0
            if Safe() then
                if ShouldBeActive() and not active then
                    Activate("watchdog")
                elseif not ShouldBeActive() and active then
                    Deactivate("watchdog")
                end
            end
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

    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- combat start
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- combat end

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            inCombat = true
            if active and not inSkyriding and Safe() then Deactivate("combat") end

        elseif event == "PLAYER_REGEN_ENABLED" then
            inCombat = false
            Recalc()

        elseif event == "GLOBAL_MOUSE_DOWN" then
            if InCombatLockdown() then return end
            local btn = ...
            if btn == "LeftButton" then
                leftDown = true
                if inSkyriding and not rightDown then
                    Activate("LMB down")
                end
            elseif btn == "RightButton" then
                rightDown = true
                if active then Deactivate("RMB down") end
            end

        elseif event == "GLOBAL_MOUSE_UP" then
            if InCombatLockdown() then return end
            local btn = ...
            if btn == "LeftButton" then
                leftDown = false
                if active then Deactivate("LMB up") end
            elseif btn == "RightButton" then
                local wasRight = rightDown
                rightDown = false
                if wasRight and leftDown and inSkyriding then
                    Activate("RMB up resume")
                end
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
    if not self.parent:IsModuleEnabled("skyriding") then return end
    inCombat = InCombatLockdown()
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
    if Safe() and active then Deactivate("disable") end
    leftDown, rightDown = false, false
    inSkyriding, active, inCombat = false, false, false
    if deferFrame then deferFrame:SetScript("OnUpdate", nil) end
    if overrideFrame then ClearOverrideBindings(overrideFrame) overrideFrame = nil end
end

-- =========================
-- Public hooks / settings
-- =========================
function Skyriding:OnPitchSettingChanged()
    -- invalidate cache
    managedCache, managedCachePitch = nil, nil
    if not active or not Safe() then return end
    local enablePitch = BOLT:GetConfig("skyriding","enablePitchControl")
    local keys = GetManagedKeys(enablePitch)
    DeferUntilKeysUp(keys, function()
        if not Safe() then return end
        ClearOverrides()
        ApplyBindings(enablePitch, BOLT:GetConfig("skyriding","invertPitch"))
    end, 1.0)
end

function Skyriding:EmergencyReset()
    if InCombatLockdown() then self.parent:Print("B.O.L.T: Can't reset in combat.") return end
    if deferFrame then deferFrame:SetScript("OnUpdate", nil) end
    if overrideFrame then ClearOverrideBindings(overrideFrame) end
    leftDown, rightDown = false, false
    inSkyriding, active = false, false
    self.parent:Print("B.O.L.T: Emergency reset complete.")
end

-- =========================
-- Register
-- =========================
BOLT:RegisterModule("skyriding", Skyriding)

-- Slash reset
SLASH_BOLTRESET1, SLASH_BOLTRESET2 = "/boltreset", "/boltnuke"
SlashCmdList["BOLTRESET"] = function()
    if Skyriding and Skyriding.EmergencyReset then Skyriding:EmergencyReset() end
end
