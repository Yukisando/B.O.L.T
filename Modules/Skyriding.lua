-- B.O.L.T Skyriding Module
-- Changes strafe keybinds to horizontal movement while skyriding
-- Overrides are only active while holding the left mouse button

local ADDON_NAME, BOLT = ...

-- Create the Skyriding module
local Skyriding = {}

-- State management
local isInSkyriding = false
local isLeftMouseDown = false
local bindingsCurrentlyActive = false
local bindingCheckFrame = nil
local overrideFrame = nil
local isInCombat = false
local pendingStateChanges = {}

-- =========================
-- Flight style detection
-- =========================

-- Central guard for protected actions
local function SafeToMutateBindings()
    return not InCombatLockdown()
end

-- Check if Skyriding is selected (Steady Flight buff absent = Skyriding)
local function IsSkyridingSelected()
    return C_UnitAuras.GetPlayerAuraBySpellID(404468) == nil
end

-- Check if current zone supports advanced flight (Skyriding physics)
local function IsSkyridingPossibleHere()
    -- advflyable can be true indoors; require outdoors to avoid false positives
    return IsAdvancedFlyableArea() and IsOutdoors()
end

-- Single source of truth for "are we in Skyriding?"
local function IsSkyridingActiveNow()
    local mounted   = IsMounted()
    local advZone   = IsAdvancedFlyableArea()
    local outdoors  = IsOutdoors()
    local steadyOn  = (C_UnitAuras.GetPlayerAuraBySpellID(404468) ~= nil)
    return mounted and advZone and outdoors and not steadyOn
end

-- =========================
-- Helpers for key handling
-- =========================

-- Get ALL keys bound to an action (primary, secondary, etc.)
local function GetAllBindingKeys(action)
    local t = { GetBindingKey(action) }
    return t
end

-- Cache for managed keys to avoid rebuilding every time
local managedKeysCache = {}
local lastPitchSetting = nil

-- Build the list of keys we manage (for gating)
local function CollectManagedKeys(enablePitch)
    -- Return cached result if setting hasn't changed
    if lastPitchSetting == enablePitch and managedKeysCache[enablePitch] then
        return managedKeysCache[enablePitch]
    end
    
    local managed = {}
    local function add(list) for _, k in ipairs(list or {}) do table.insert(managed, k) end end
    add(GetAllBindingKeys("STRAFELEFT"))
    add(GetAllBindingKeys("STRAFERIGHT"))
    if enablePitch then
        add(GetAllBindingKeys("MOVEFORWARD"))
        add(GetAllBindingKeys("MOVEBACKWARD"))
    end
    
    -- Cache the result
    managedKeysCache[enablePitch] = managed
    lastPitchSetting = enablePitch
    
    return managed
end

-- Are ANY of the provided physical keys currently down?
local function AnyKeyDown(keys)
    for _, key in ipairs(keys) do
        if IsKeyDown(key) then return true end
    end
    return false
end

-- Defer a callback until all the relevant keys are UP (or a 5s safety timeout)
function Skyriding:DeferUntilKeysUp(keys, callback, reason)
    if not keys or #keys == 0 then
        callback()
        return
    end

    if not AnyKeyDown(keys) then
        callback()
        return
    end

    if not self.deferFrame then
        self.deferFrame = CreateFrame("Frame")
    end

    -- Track which keys are currently being waited for
    local waitingKeys = {}
    for _, key in ipairs(keys) do
        if IsKeyDown(key) then
            waitingKeys[key] = true
        end
    end

    local waited = 0
    local reasonText = reason or "action"
    
    self.deferFrame:SetScript("OnUpdate", function(frame, elapsed)
        waited = waited + elapsed
        
        -- Check if any of the originally held keys are still down
        local stillHeld = false
        for key, _ in pairs(waitingKeys) do
            if IsKeyDown(key) then
                stillHeld = true
                break
            end
        end
        
        if not stillHeld then
            frame:SetScript("OnUpdate", nil)
            callback()
        elseif waited >= 5 then
            frame:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

-- Clear managed keys cache (call when pitch control setting changes at runtime)
local function InvalidateManagedKeysCache()
    managedKeysCache = {}
    lastPitchSetting = nil
end

-- =========================
-- Module lifecycle
-- =========================

function Skyriding:OnInitialize()
    -- Module initialization
end

function Skyriding:OnEnable()
    if not self.parent:IsModuleEnabled("skyriding") then
        return
    end

    -- Initialize state
    isInCombat = InCombatLockdown()

    -- Create event handling frame
    self:CreateEventFrame()

    -- Start monitoring for skyriding state
    self:StartMonitoring()
end

function Skyriding:OnDisable()
    -- Clear any pending state changes
    pendingStateChanges = {}

    -- Clear override bindings if we're currently in skyriding mode
    if bindingsCurrentlyActive then
        -- Wait for keys to be released before clearing
        local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
        if AnyKeyDown(keys) then
            self:DeferUntilKeysUp(keys, function()
                if not SafeToMutateBindings() then return end
                self:ClearSkyridingOverrides()
            end, "module disable with held keys")
        else
            self:ClearSkyridingOverrides()
        end
    end

    -- Reset state variables
    isInSkyriding = false
    isLeftMouseDown = false
    bindingsCurrentlyActive = false
    isInCombat = false

    -- Stop monitoring
    self:StopMonitoring()

    -- Clean up event frame
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end

    -- Clean up defer frame
    if self.deferFrame then
        self.deferFrame:SetScript("OnUpdate", nil)
        self.deferFrame = nil
    end

    -- Clean up override frame
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
        overrideFrame = nil
    end
end

-- =========================
-- Events & monitoring
-- =========================

function Skyriding:CreateEventFrame()
    if self.eventFrame then
        return
    end

    self.eventFrame = CreateFrame("Frame")

    -- Register relevant events
    self.eventFrame:RegisterEvent("UNIT_AURA")
    self.eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Combat
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Combat start
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Combat end

    -- Mouse events (event-driven instead of polling)
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            isInCombat = true
            -- Only clear active overrides when combat starts if not currently in skyriding
            -- (allow skyriding controls to work in combat)
            if bindingsCurrentlyActive and not isInSkyriding then
                self:ClearSkyridingOverrides()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            isInCombat = false
            -- No need to restore bindings automatically - they'll be applied when mouse is pressed
        elseif event == "GLOBAL_MOUSE_DOWN" then
            local button = ...
            if button == "LeftButton" then
                -- Don't change state during combat to keep it in sync with binding state
                if not InCombatLockdown() then
                    isLeftMouseDown = true
                    if isInSkyriding and not self.parent:GetConfig("skyriding", "toggleMode") then
                        self:ApplySkyridingOverrides()
                    end
                end
            end
        elseif event == "GLOBAL_MOUSE_UP" then
            local button = ...
            if button == "LeftButton" then
                -- Don't change state during combat to keep it in sync with binding state
                if not InCombatLockdown() then
                    isLeftMouseDown = false
                    -- In toggleMode, mouse release shouldn't clear overrides
                    if self.parent:GetConfig("skyriding", "toggleMode") then return end
                    self:ClearSkyridingOverrides()
                end
            end
        elseif event == "UNIT_AURA" then
            local unit = ...
            if unit == "player" then
                -- Flight style changed (Steady <-> Skyriding toggle)
                self:CheckSkyridingState()
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unitTarget = ...
            if unitTarget == "player" then
                C_Timer.After(0.1, function()
                    if not SafeToMutateBindings() then return end
                    self:CheckSkyridingState()
                end)
            end
        elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" or
               event == "MOUNT_JOURNAL_USABILITY_CHANGED" or
               event == "ZONE_CHANGED" or
               event == "ZONE_CHANGED_NEW_AREA" or
               event == "PLAYER_ENTERING_WORLD" then
            -- Small delay to ensure mount state has updated
            C_Timer.After(0.2, function()
                if not SafeToMutateBindings() then return end
                self:CheckSkyridingState()
            end)
        end
    end)

end

function Skyriding:StartMonitoring()
    if bindingCheckFrame then
        return
    end

    -- Create a lightweight frame for safety verification only (no more state polling)
    bindingCheckFrame = CreateFrame("Frame")
    bindingCheckFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.timeSinceLastStateCheck = (frame.timeSinceLastStateCheck or 0) + elapsed

        -- Verify binding state integrity every 5 seconds as a safety measure
        -- This is just a watchdog - real state changes are event-driven
        if frame.timeSinceLastStateCheck >= 5.0 then
            frame.timeSinceLastStateCheck = 0
            self:VerifyBindingState()
        end
    end)

end

function Skyriding:StopMonitoring()
    if bindingCheckFrame then
        bindingCheckFrame:SetScript("OnUpdate", nil)
        bindingCheckFrame = nil
    end
end

function Skyriding:ApplySkyridingOverrides()
    -- Don't touch bindings in combat
    if not SafeToMutateBindings() then return end
    
    -- Don't apply if not enabled
    if not self.parent:GetConfig("skyriding", "enabled") then
        return
    end
    
    -- Don't apply if already active
    if bindingsCurrentlyActive then
        return
    end
    
    -- Safety check: Only apply if we're in SKYRIDING mode
    if not IsSkyridingSelected() then
        if self.parent:GetConfig("debug") then
            self.parent:Print("Cannot apply overrides - not in Skyriding mode")
        end
        return
    end

    -- Create override frame if needed
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "BOLTSkyridingOverrideFrame")
    end

    -- Wait until relevant keys are UP before applying overrides
    local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
    self:DeferUntilKeysUp(keys, function()
        -- Apply skyriding bindings without forcing key release (keys are already up)
        self:ApplySkyridingBindings()
        bindingsCurrentlyActive = true
        
        if self.parent:GetConfig("debug") then
            local pitchEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
            local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")
            local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")

            local modeText = toggleMode and " (always active)" or " (mouse held)"
            
            if pitchEnabled then
                if invertPitch then
                    self.parent:Print("Skyriding overrides active" .. modeText .. ": A/D=horizontal, W=dive, S=climb")
                else
                    self.parent:Print("Skyriding overrides active" .. modeText .. ": A/D=horizontal, W=climb, S=dive")
                end
            else
                self.parent:Print("Skyriding overrides active" .. modeText .. ": A/D=horizontal movement only")
            end
        end
    end, "mouse press with held keys")
end

function Skyriding:ClearSkyridingOverrides()
    -- Don't touch bindings in combat
    if not SafeToMutateBindings() then return end
    
    -- Don't clear if not currently active
    if not bindingsCurrentlyActive then
        return
    end

    -- Only proceed if we have an override frame
    if not overrideFrame then
        return
    end

    local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
    
    -- Enhanced security: Check conditions based on mode
    if toggleMode then
        -- In always-on mode, only clear when exiting skyriding mode or in combat
        -- Don't clear based on mouse state since it should always be on
        if isInSkyriding and not isInCombat then
            return
        end
    else
        -- In hold mode, check if mouse is still down and we're still in skyriding
        if isLeftMouseDown and isInSkyriding then
            return
        end
    end

    -- Check if any managed keys are currently held
    local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
    if AnyKeyDown(keys) then
        -- Wait until all managed keys are UP before clearing overrides
        self:DeferUntilKeysUp(keys, function()
            if bindingsCurrentlyActive and overrideFrame then
                self:ClearOverrideBindings()
                bindingsCurrentlyActive = false
                if self.parent:GetConfig("debug") then
                    self.parent:Print("Skyriding overrides cleared: All movement keys restored to normal")
                end
            end
        end, toggleMode and "exit skyriding with held keys" or "mouse release with held keys")
    else
        -- No keys held, safe to clear immediately
        self:ClearOverrideBindings()
        bindingsCurrentlyActive = false
        if self.parent:GetConfig("debug") then
            self.parent:Print("Skyriding overrides cleared: All movement keys restored to normal")
        end
    end
end

-- =========================
-- State detection
-- =========================

function Skyriding:CheckSkyridingState()
    -- Use single source of truth
    local currentlyInSkyriding = IsSkyridingActiveNow()

    if self.parent:GetConfig("debug") then
        local mounted   = IsMounted()
        local advZone   = IsAdvancedFlyableArea()
        local outdoors  = IsOutdoors()
        local steadyOn  = (C_UnitAuras.GetPlayerAuraBySpellID(404468) ~= nil)
        self.parent:Print(("Skyriding state: mounted=%s adv=%s outdoors=%s steady=%s inSky=%s"):
            format(tostring(mounted), tostring(advZone), tostring(outdoors), tostring(steadyOn), tostring(currentlyInSkyriding)))
    end

    -- Only manage bindings out of combat to avoid protected-action blocks
    if not SafeToMutateBindings() then
        -- Just update the flag; let VerifyBindingState() repair post-combat
        isInSkyriding = currentlyInSkyriding
        return
    end

    -- Handle state changes OR verify current state is applied correctly
    local stateChanged = (currentlyInSkyriding ~= isInSkyriding)
    
    if stateChanged then
        isInSkyriding = currentlyInSkyriding
    end
    
    if currentlyInSkyriding then
        local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
        
        -- Apply overrides if state just changed OR if they should be active but aren't
        local shouldApply = false
        if stateChanged then
            -- State just changed to skyriding
            shouldApply = true
        elseif toggleMode and not bindingsCurrentlyActive then
            -- In toggle mode, bindings should always be active while in skyriding
            shouldApply = true
            if self.parent:GetConfig("debug") then
                self.parent:Print("Toggle mode: Bindings not active, will apply now")
            end
        elseif not toggleMode and isLeftMouseDown and not bindingsCurrentlyActive then
            -- In hold mode, bindings should be active when mouse is down
            shouldApply = true
            if self.parent:GetConfig("debug") then
                self.parent:Print("Hold mode: Mouse down but bindings not active, will apply now")
            end
        end
        
        if shouldApply then
            if toggleMode then
                -- Wait a tiny moment for the skyriding state to stabilize, then apply
                C_Timer.After(0.05, function()
                    if not SafeToMutateBindings() then return end
                    if isInSkyriding and not bindingsCurrentlyActive and IsSkyridingActiveNow() then
                        self:ApplySkyridingOverrides()
                    end
                end)
            else
                -- hold-to-override mode: only apply when LMB already down
                if isLeftMouseDown and not bindingsCurrentlyActive then
                    self:ApplySkyridingOverrides()
                end
            end
            
            if self.parent:GetConfig("debug") and stateChanged then
                if toggleMode then
                    self.parent:Print("Skyriding detected - 3D movement controls always active")
                else
                    self.parent:Print("Skyriding detected - hold left mouse button to activate overrides")
                end
            end
        end
    else
        -- Exiting skyriding mode
        if stateChanged and bindingsCurrentlyActive then
                local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
                
                -- Check if any managed keys are currently held
                if AnyKeyDown(keys) then
                    pendingStateChanges.clearOnLanding = true
                    
                    -- Wait for keys to be released before clearing
                    self:DeferUntilKeysUp(keys, function()
                        if pendingStateChanges.clearOnLanding then
                            pendingStateChanges.clearOnLanding = false
                            self:ClearOverrideBindings()
                            bindingsCurrentlyActive = false
                        end
                    end, "landing with held keys")
                    
                    if self.parent:GetConfig("debug") then
                        self.parent:Print("Skyriding ended - waiting for key release to restore controls")
                    end
                else
                    -- No keys held, safe to clear immediately
                    self:ClearOverrideBindings()
                    bindingsCurrentlyActive = false
                    
                    if self.parent:GetConfig("debug") then
                        self.parent:Print("Skyriding ended")
                    end
                end
                
                -- 5s watchdog just in case the OS truly ate the key-up
                C_Timer.After(5, function()
                    if not SafeToMutateBindings() then return end
                    if pendingStateChanges.clearOnLanding then
                        pendingStateChanges.clearOnLanding = false
                        self:ClearOverrideBindings()
                        bindingsCurrentlyActive = false
                    end
                end)
            end
        end
    end
end

-- =========================
-- Binding management
-- =========================

function Skyriding:EnterSkyridingMode()
    -- Compatibility wrapper for the new mouse-triggered system
    if not self.parent:GetConfig("skyriding", "enabled") then
        return
    end

    
    local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
    
    if toggleMode then
        -- In always-on mode, apply overrides immediately when entering skyriding
        if not bindingsCurrentlyActive then
            self:ApplySkyridingOverrides()
        end
    else
        -- In hold mode, apply overrides if mouse is down
        if isLeftMouseDown and not bindingsCurrentlyActive then
            self:ApplySkyridingOverrides()
        end
    end
end

function Skyriding:ExitSkyridingMode()
    -- Compatibility wrapper for the new mouse-triggered system

    -- Clear any active overrides when exiting skyriding mode
    if bindingsCurrentlyActive then
        self:ClearSkyridingOverrides()
    end
end

function Skyriding:ForceReleaseAllKeys()
    -- Don't touch bindings in combat
    if not SafeToMutateBindings() then return end
    
    -- Safer approach: Just clear any existing overrides without creating new problematic ones
    -- The key release will happen naturally when overrides are cleared
    
    if overrideFrame then
        -- Simply clear existing overrides - this is safer than creating temporary mappings
        ClearOverrideBindings(overrideFrame)
    end
end

function Skyriding:ClearOverrideBindings()
    -- Don't touch bindings in combat
    if not SafeToMutateBindings() then return end
    
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
    end
end

function Skyriding:ApplySkyridingBindings()
    -- Don't touch bindings in combat
    if not SafeToMutateBindings() then return end
    
    -- Use override bindings to remap keys to movement commands
    -- The client handles the actual movement API calls

    if not overrideFrame then
        return
    end

    local enablePitch = self.parent:GetConfig("skyriding", "enablePitchControl")
    local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")

    local function bindTo(cmd, bindingName)
        for _, phys in ipairs(GetAllBindingKeys(bindingName)) do
            SetOverrideBindingPriority(overrideFrame, false, phys, cmd)
        end
    end

    -- A/D → turning
    bindTo("TURNLEFT", "STRAFELEFT")
    bindTo("TURNRIGHT", "STRAFERIGHT")

    -- W/S → pitch (optional)
    if enablePitch then
        bindTo(invertPitch and "PITCHDOWN" or "PITCHUP", "MOVEFORWARD")
        bindTo(invertPitch and "PITCHUP" or "PITCHDOWN", "MOVEBACKWARD")
    end
end

function Skyriding:EmergencyReset()
    -- Emergency function to reset all bindings and state
    -- Can be called via slash command if something goes wrong

    -- Clear any pending state changes
    pendingStateChanges = {}

    -- Stop any deferred operations
    if self.deferFrame then
        self.deferFrame:SetScript("OnUpdate", nil)
    end

    -- Immediately clear all override bindings without any force release
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
    end

    -- Reset state
    isInSkyriding = false
    isLeftMouseDown = false
    bindingsCurrentlyActive = false

    self.parent:Print("Emergency reset complete - all movement keys restored to normal")
end

-- Pitch control hot-swap handler
function Skyriding:OnPitchSettingChanged()
    InvalidateManagedKeysCache()
    if bindingsCurrentlyActive and SafeToMutateBindings() then
        local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
        self:DeferUntilKeysUp(keys, function()
            if not SafeToMutateBindings() then return end
            self:ClearOverrideBindings()
            self:ApplySkyridingBindings()
        end, "pitch setting changed")
    end
end

-- Enhanced safety function to verify binding state integrity
function Skyriding:VerifyBindingState()
    -- Skip corrective actions when in combat to avoid spammy attempts
    if not SafeToMutateBindings() then
        return
    end
    
    local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
    local expectedActive = isInSkyriding and (toggleMode or isLeftMouseDown)
    
    if bindingsCurrentlyActive ~= expectedActive then
        
        if expectedActive and not bindingsCurrentlyActive then
            -- Should be active but isn't - try to apply
            self:ApplySkyridingOverrides()
        elseif not expectedActive and bindingsCurrentlyActive then
            -- Shouldn't be active but is - try to clear
            self:ClearSkyridingOverrides()
        end
    end
end

-- Register the module
BOLT:RegisterModule("skyriding", Skyriding)

-- Emergency reset slash command
SLASH_BOLTRESET1 = "/boltreset"
SLASH_BOLTRESET2 = "/boltnuke"
SlashCmdList["BOLTRESET"] = function()
    if InCombatLockdown() then
        print("B.O.L.T: Can't reset in combat.")
        return
    end
    if Skyriding and Skyriding.EmergencyReset then
        Skyriding:EmergencyReset()
    end
end
