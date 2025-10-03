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
local stateChangeDebounce = 0
local lastStateChangeTime = 0
local mouseFrame = nil
local pendingStateChanges = {}
local keysPressedDuringTransition = {}

-- =========================
-- Flight style detection
-- =========================

-- Returns "STEADY", "SKYRIDING", or "UNKNOWN"
local function GetFlightStyle()
    local steady = C_UnitAuras.GetPlayerAuraBySpellID(404468) -- Flight Style: Steady
    if steady then return "STEADY" end
    -- no aura: if you have skyriding unlocked, this means Skyriding is selected
    -- (feature unlock check is optional)
    local unlocked = C_MountJournal.IsDragonridingUnlocked and C_MountJournal.IsDragonridingUnlocked()
    if unlocked then return "SKYRIDING" end
    return "UNKNOWN"
end

-- Optional: is the current zone an "advanced flight (Skyriding) supported" area?
local function IsAdvancedArea()
    return IsAdvancedFlyableArea() and true or false
end

-- =========================
-- Helpers for key handling
-- =========================

-- Get ALL keys bound to an action (primary, secondary, etc.)
local function GetAllBindingKeys(action)
    local keys, i = {}, 1
    while true do
        local key = select(i, GetBindingKey(action))
        if not key then break end
        table.insert(keys, key)
        i = i + 1
    end
    return keys
end

-- Build the list of keys we manage (for gating)
local function CollectManagedKeys(enablePitch)
    local managed = {}
    local function add(list) for _, k in ipairs(list or {}) do table.insert(managed, k) end end
    add(GetAllBindingKeys("STRAFELEFT"))
    add(GetAllBindingKeys("STRAFERIGHT"))
    if enablePitch then
        add(GetAllBindingKeys("MOVEFORWARD"))
        add(GetAllBindingKeys("MOVEBACKWARD"))
    end
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

-- Enhanced function to check if any keys were held during a transition
local function CheckKeysHeldDuringTransition(keys)
    local heldKeys = {}
    for _, key in ipairs(keys) do
        if IsKeyDown(key) then
            table.insert(heldKeys, key)
            keysPressedDuringTransition[key] = true
        end
    end
    return heldKeys
end

-- Function to clear the record of keys held during transition
local function ClearTransitionKeyRecord()
    keysPressedDuringTransition = {}
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
    stateChangeDebounce = 0
    lastStateChangeTime = 0

    -- Create event handling frame
    self:CreateEventFrame()

    -- Start monitoring for skyriding state
    self:StartMonitoring()
    
    -- Start mouse button monitoring
    self:StartMouseMonitoring()
end

function Skyriding:OnDisable()
    -- Clear any pending state changes
    pendingStateChanges = {}
    ClearTransitionKeyRecord()

    -- Clear override bindings if we're currently in skyriding mode
    if bindingsCurrentlyActive then
        -- Wait for keys to be released before clearing
        local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
        if AnyKeyDown(keys) then
            self:DeferUntilKeysUp(keys, function()
                self:ClearOverrideBindings()
            end, "module disable with held keys")
        else
            self:ClearOverrideBindings()
        end
    end

    -- Reset state variables
    isInSkyriding = false
    isLeftMouseDown = false
    bindingsCurrentlyActive = false
    isInCombat = false
    stateChangeDebounce = 0
    lastStateChangeTime = 0

    -- Stop monitoring
    self:StopMonitoring()
    self:StopMouseMonitoring()

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
    self.eventFrame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
    self.eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self.eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    -- Combat
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Combat start
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Combat end

    -- Optional debug events
    self.eventFrame:RegisterEvent("PLAYER_STARTED_TURNING")
    self.eventFrame:RegisterEvent("PLAYER_STOPPED_TURNING")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            isInCombat = true
            -- Clear any active overrides when combat starts
            if bindingsCurrentlyActive then
                self:ClearSkyridingOverrides()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            isInCombat = false
            -- No need to restore bindings automatically - they'll be applied when mouse is pressed
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unitTarget = ...
            if unitTarget == "player" then
                C_Timer.After(0.1, function()
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
                self:CheckSkyridingState()
            end)
        elseif (event == "PLAYER_STARTED_TURNING" or event == "PLAYER_STOPPED_TURNING") and self.parent:GetConfig("debug") then
        end
    end)

end

function Skyriding:StartMonitoring()
    if bindingCheckFrame then
        return
    end

    -- Create a frame that periodically checks skyriding state
    bindingCheckFrame = CreateFrame("Frame")
    bindingCheckFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.timeSinceLastUpdate = (frame.timeSinceLastUpdate or 0) + elapsed
        frame.timeSinceLastStateCheck = (frame.timeSinceLastStateCheck or 0) + elapsed

        -- Update debounce timer
        if stateChangeDebounce > 0 then
            stateChangeDebounce = stateChangeDebounce - elapsed
        end

        -- Check every 0.5 seconds (not too frequent to avoid performance issues)
        if frame.timeSinceLastUpdate >= 0.5 then
            frame.timeSinceLastUpdate = 0
            self:CheckSkyridingState()
        end

        -- Verify binding state integrity every 2 seconds as a safety measure
        if frame.timeSinceLastStateCheck >= 2.0 then
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

function Skyriding:StartMouseMonitoring()
    if mouseFrame then
        return
    end

    -- Create a frame to monitor mouse button state
    mouseFrame = CreateFrame("Frame")
    mouseFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.timeSinceLastUpdate = (frame.timeSinceLastUpdate or 0) + elapsed
        
        -- Check mouse state every 0.1 seconds for responsiveness
        if frame.timeSinceLastUpdate >= 0.1 then
            frame.timeSinceLastUpdate = 0
            self:CheckMouseState()
        end
    end)

end

function Skyriding:StopMouseMonitoring()
    if mouseFrame then
        mouseFrame:SetScript("OnUpdate", nil)
        mouseFrame = nil
    end
end

function Skyriding:CheckMouseState()
    local currentMouseDown = IsMouseButtonDown("LeftButton")
    local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
    
    -- Only process if we're in skyriding mode
    if not isInSkyriding then
        if isLeftMouseDown ~= currentMouseDown then
            isLeftMouseDown = currentMouseDown
        end
        return
    end
    
    -- Update mouse state tracking
    if isLeftMouseDown ~= currentMouseDown then
        isLeftMouseDown = currentMouseDown
    end
    
    if toggleMode then
        -- Toggle mode: Always-on mode - 3D movement is always active while skyriding
        if not bindingsCurrentlyActive then
            self:ApplySkyridingOverrides()
        end
    else
        -- Hold mode: Require left mouse button to be held for 3D movement
        if currentMouseDown ~= isLeftMouseDown then
            if currentMouseDown then
                self:ApplySkyridingOverrides()
            else
                -- Enhanced safety: Check if there are keys held and if we have pending state changes
                local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
                local heldKeys = CheckKeysHeldDuringTransition(keys)
                
                if #heldKeys > 0 then
                end
                
                self:ClearSkyridingOverrides()
            end
        end
    end
    
    -- Safety check: Ensure binding state matches expected state
    local shouldBeActive = isInSkyriding and not isInCombat and (toggleMode or currentMouseDown)
    if bindingsCurrentlyActive ~= shouldBeActive then
        if shouldBeActive and not bindingsCurrentlyActive then
            self:ApplySkyridingOverrides()
        elseif not shouldBeActive and bindingsCurrentlyActive then
            self:ClearSkyridingOverrides()
        end
    end
end

function Skyriding:ApplySkyridingOverrides()
    -- Don't apply if in combat or if not enabled
    if isInCombat or not self.parent:GetConfig("skyriding", "enabled") then
        return
    end
    
    -- Don't apply if already active
    if bindingsCurrentlyActive then
        return
    end
    
    -- Safety check: Only apply if we're in SKYRIDING mode
    local flightStyle = GetFlightStyle()
    if flightStyle ~= "SKYRIDING" then
        if self.parent:GetConfig("debug") then
            self.parent:Print("Cannot apply overrides - flight style is " .. flightStyle)
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
    -- Don't clear if in combat
    if isInCombat then
        return
    end
    
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

    -- Get the managed keys and check if any are currently held
    local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
    local heldKeys = {}
    for _, key in ipairs(keys) do
        if IsKeyDown(key) then
            table.insert(heldKeys, key)
        end
    end

    -- If keys are held, defer clearing until they're all released
    if #heldKeys > 0 then
        local reason = toggleMode and "exit skyriding with held keys" or "mouse release with held keys"
        
        -- Wait until all managed keys are UP before clearing overrides
        self:DeferUntilKeysUp(keys, function()
            -- Double-check that we should still clear (state might have changed)
            if bindingsCurrentlyActive and overrideFrame then
                -- Simply clear override bindings - keys are already up
                self:ClearOverrideBindings()
                bindingsCurrentlyActive = false

                if self.parent:GetConfig("debug") then
                    self.parent:Print("Skyriding overrides cleared: All movement keys restored to normal")
                end
            end
        end, reason)
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
    local isMounted = IsMounted()
    local currentlyInSkyriding = false

    if isMounted then
        -- Check if we can fly (basic requirement for skyriding)
        local canFly = IsFlyableArea()

        if canFly then
            -- First check: Make sure we're in SKYRIDING mode, not STEADY flight
            local flightStyle = GetFlightStyle()
            if flightStyle ~= "SKYRIDING" then
                -- Not in skyriding mode (either STEADY or UNKNOWN), don't activate
                currentlyInSkyriding = false
                if isInSkyriding and self.parent:GetConfig("debug") then
                    self.parent:Print("Flight style is " .. flightStyle .. " - 3D movement disabled")
                end
                -- Early exit to prevent any activation
                if currentlyInSkyriding ~= isInSkyriding then
                    local currentTime = GetTime()
                    if (currentTime - lastStateChangeTime) < 1.0 and stateChangeDebounce > 0 then
                        return
                    end
                    lastStateChangeTime = currentTime
                    stateChangeDebounce = 1.0
                    isInSkyriding = currentlyInSkyriding
                    if bindingsCurrentlyActive then
                        self:ClearSkyridingOverrides()
                    end
                    ClearTransitionKeyRecord()
                end
                return
            end
            -- Get current mount info - use a safer approach
            local mountID = nil
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local shapeShiftFormID = GetShapeshiftFormID and GetShapeshiftFormID()
                if shapeShiftFormID and shapeShiftFormID > 0 then
                    mountID = C_MountJournal.GetMountFromSpell(shapeShiftFormID)
                end
            end

            if mountID then
                local creatureDisplayID, description, source, isSelfMount, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)

                -- Check if it's a dragonriding mount (mountTypeID 402 = Dragonriding)
                if mountTypeID == 402 then
                    currentlyInSkyriding = true
                end

                -- Check for other flying mounts that might support dynamic flight
                if not currentlyInSkyriding and mountTypeID == 248 and canFly then
                    if IsFlying() then
                        currentlyInSkyriding = true
                    end
                end
            end

            -- Alternative check: Look for dragonriding-specific buffs or abilities
            if not currentlyInSkyriding and canFly and IsFlying() then
                local skyridingSpells = {
                    372610, -- Surge Forward
                    361584, -- Skyward Ascent
                    372611, -- Whirling Surge
                    377236, -- Dragonriding (base ability)
                }

                for _, spellID in ipairs(skyridingSpells) do
                    if IsSpellKnown(spellID) then
                        currentlyInSkyriding = true
                        break
                    end
                end
            end
        end
    end

    -- Handle state changes with debouncing to prevent rapid toggling
    if currentlyInSkyriding ~= isInSkyriding then
        local currentTime = GetTime()

        -- Debounce rapid state changes (prevent toggle spam within 1 second)
        if (currentTime - lastStateChangeTime) < 1.0 and stateChangeDebounce > 0 then
            return
        end

        lastStateChangeTime = currentTime
        stateChangeDebounce = 1.0

        -- Update the skyriding state
        isInSkyriding = currentlyInSkyriding
        
        if currentlyInSkyriding then
            ClearTransitionKeyRecord() -- Clear any previous transition key records
            
            -- In always-on mode, activate overrides immediately
            local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
            if toggleMode then
                -- Wait a brief moment for the skyriding state to stabilize, then apply
                C_Timer.After(0.1, function()
                    if isInSkyriding and not bindingsCurrentlyActive then
                        -- Double-check we're still in SKYRIDING mode before applying
                        local flightStyle = GetFlightStyle()
                        if flightStyle == "SKYRIDING" then
                            self:ApplySkyridingOverrides()
                        end
                    end
                end)
            end
            
            if self.parent:GetConfig("debug") then
                local flightStyle = GetFlightStyle()
                if toggleMode then
                    self.parent:Print("Skyriding mode detected (" .. flightStyle .. ") - 3D movement controls always active")
                else
                    self.parent:Print("Skyriding mode detected (" .. flightStyle .. ") - hold left mouse button to activate overrides")
                end
            end
        else
            
            -- Check if any managed keys are currently held during this transition
            local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
            local heldKeys = CheckKeysHeldDuringTransition(keys)
            
            if #heldKeys > 0 then
                -- Store this as a pending state change
                pendingStateChanges.clearOnLanding = true
                
                -- Set up a monitoring system to clear overrides once keys are released
                if bindingsCurrentlyActive then
                    self:DeferUntilKeysUp(keys, function()
                        if pendingStateChanges.clearOnLanding then
                            -- Simply clear the overrides - keys are already up
                            self:ClearOverrideBindings()
                            bindingsCurrentlyActive = false
                            pendingStateChanges.clearOnLanding = false
                            ClearTransitionKeyRecord()
                        end
                    end, "landing with held keys")
                end
            else
                -- No keys held, safe to clear immediately
                if bindingsCurrentlyActive then
                    self:ClearSkyridingOverrides()
                end
                ClearTransitionKeyRecord()
            end
            
            if self.parent:GetConfig("debug") then
                if #heldKeys > 0 then
                    self.parent:Print("Skyriding mode disabled - waiting for key release to restore controls")
                else
                    self.parent:Print("Skyriding mode disabled")
                end
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
    -- Safer approach: Just clear any existing overrides without creating new problematic ones
    -- The key release will happen naturally when overrides are cleared
    
    if overrideFrame then
        -- Simply clear existing overrides - this is safer than creating temporary mappings
        ClearOverrideBindings(overrideFrame)
    end
end

function Skyriding:ClearOverrideBindings()
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
    end
end

function Skyriding:ApplySkyridingBindings()
    -- Use override bindings instead of changing actual bindings
    -- Override bindings are temporary and safe - they don't modify user's actual keybinds

    if not overrideFrame then
        return
    end

    -- Get the current bindings to override and apply
    for _, key in ipairs(GetAllBindingKeys("STRAFELEFT")) do
        SetOverrideBinding(overrideFrame, false, key, "TURNLEFT")
    end

    for _, key in ipairs(GetAllBindingKeys("STRAFERIGHT")) do
        SetOverrideBinding(overrideFrame, false, key, "TURNRIGHT")
    end

    -- Apply vertical movement bindings if pitch control is enabled
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")

        for _, key in ipairs(GetAllBindingKeys("MOVEFORWARD")) do
            SetOverrideBinding(overrideFrame, false, key, invertPitch and "PITCHDOWN" or "PITCHUP")
        end

        for _, key in ipairs(GetAllBindingKeys("MOVEBACKWARD")) do
            SetOverrideBinding(overrideFrame, false, key, invertPitch and "PITCHUP" or "PITCHDOWN")
        end
    end

end

function Skyriding:EmergencyReset()
    -- Emergency function to reset all bindings and state
    -- Can be called via slash command if something goes wrong

    -- Clear any pending state changes
    pendingStateChanges = {}
    ClearTransitionKeyRecord()

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
    stateChangeDebounce = 0

    self.parent:Print("Emergency reset complete - all movement keys restored to normal")
end

-- Enhanced safety function to verify binding state integrity
function Skyriding:VerifyBindingState()
    local toggleMode = self.parent:GetConfig("skyriding", "toggleMode")
    local expectedActive = isInSkyriding and not isInCombat and (toggleMode or isLeftMouseDown)
    
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
