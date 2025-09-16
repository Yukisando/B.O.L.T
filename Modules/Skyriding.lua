-- ColdSnap Skyriding Module
-- Changes strafe keybinds to horizontal movement while skyriding
-- Overrides are only active while holding the left mouse button

local ADDON_NAME, ColdSnap = ...

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
function Skyriding:DeferUntilKeysUp(keys, callback)
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

    local waited = 0
    self.deferFrame:SetScript("OnUpdate", function(frame, elapsed)
        waited = waited + elapsed
        if not AnyKeyDown(keys) then
            frame:SetScript("OnUpdate", nil)
            self.parent:Debug("All managed keys released; proceeding")
            callback()
        elseif waited >= 5 then
            frame:SetScript("OnUpdate", nil)
            self.parent:Debug("Keys still held after 5s; proceeding to avoid deadlock")
            callback()
        end
    end)

    self.parent:Debug("Deferring action until keys are released")
end

-- =========================
-- Module lifecycle
-- =========================

function Skyriding:OnInitialize()
    self.parent:Debug("Skyriding module initializing...")
end

function Skyriding:OnEnable()
    if not self.parent:IsModuleEnabled("skyriding") then
        self.parent:Debug("Skyriding module is disabled, skipping OnEnable")
        return
    end

    self.parent:Debug("Skyriding module enabling...")

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
    self.parent:Debug("Skyriding module disabling...")

    -- Force release all keys before cleanup
    self:ForceReleaseAllKeys()

    -- Clear override bindings if we're currently in skyriding mode
    if bindingsCurrentlyActive then
        self:ClearSkyridingOverrides()
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
            self.parent:Debug("Combat started - clearing active bindings")
            -- Clear any active overrides when combat starts
            if bindingsCurrentlyActive then
                self:ClearSkyridingOverrides()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            isInCombat = false
            self.parent:Debug("Combat ended - mouse controls available again")
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
            self.parent:Debug(event)
        end
    end)

    self.parent:Debug("Skyriding event frame created and events registered")
end

function Skyriding:StartMonitoring()
    if bindingCheckFrame then
        return
    end

    -- Create a frame that periodically checks skyriding state
    bindingCheckFrame = CreateFrame("Frame")
    bindingCheckFrame:SetScript("OnUpdate", function(frame, elapsed)
        frame.timeSinceLastUpdate = (frame.timeSinceLastUpdate or 0) + elapsed

        -- Update debounce timer
        if stateChangeDebounce > 0 then
            stateChangeDebounce = stateChangeDebounce - elapsed
        end

        -- Check every 0.5 seconds (not too frequent to avoid performance issues)
        if frame.timeSinceLastUpdate >= 0.5 then
            frame.timeSinceLastUpdate = 0
            self:CheckSkyridingState()
        end
    end)

    self.parent:Debug("Started skyriding monitoring")
end

function Skyriding:StopMonitoring()
    if bindingCheckFrame then
        bindingCheckFrame:SetScript("OnUpdate", nil)
        bindingCheckFrame = nil
        self.parent:Debug("Stopped skyriding monitoring")
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

    self.parent:Debug("Started mouse button monitoring")
end

function Skyriding:StopMouseMonitoring()
    if mouseFrame then
        mouseFrame:SetScript("OnUpdate", nil)
        mouseFrame = nil
        self.parent:Debug("Stopped mouse button monitoring")
    end
end

function Skyriding:CheckMouseState()
    local currentMouseDown = IsMouseButtonDown("LeftButton")
    
    -- Only process if we're in skyriding mode
    if not isInSkyriding then
        if isLeftMouseDown ~= currentMouseDown then
            isLeftMouseDown = currentMouseDown
        end
        return
    end
    
    -- Check for mouse state changes
    if currentMouseDown ~= isLeftMouseDown then
        isLeftMouseDown = currentMouseDown
        
        if currentMouseDown then
            self.parent:Debug("Left mouse button pressed - applying skyriding overrides")
            self:ApplySkyridingOverrides()
        else
            self.parent:Debug("Left mouse button released - clearing skyriding overrides")
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

    -- Create override frame if needed
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "ColdSnapSkyridingOverrideFrame")
        self.parent:Debug("Created override binding frame")
    end

    -- Wait until relevant keys are UP before applying overrides
    local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
    self:DeferUntilKeysUp(keys, function()
        -- Force release all keys before changing bindings to prevent stuck keys
        self:ForceReleaseAllKeys()

        -- Small delay to ensure key release is processed
        C_Timer.After(0.05, function()
            -- Apply skyriding bindings
            self:ApplySkyridingBindings()
            bindingsCurrentlyActive = true
            
            if self.parent:GetConfig("debug") then
                local pitchEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
                local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")

                if pitchEnabled then
                    if invertPitch then
                        self.parent:Print("Skyriding overrides active: A/D=horizontal, W=dive, S=climb")
                    else
                        self.parent:Print("Skyriding overrides active: A/D=horizontal, W=climb, S=dive")
                    end
                else
                    self.parent:Print("Skyriding overrides active: A/D=horizontal movement only")
                end
            end
        end)
    end)
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

    -- Wait until relevant keys are UP before clearing overrides
    local keys = CollectManagedKeys(self.parent:GetConfig("skyriding", "enablePitchControl"))
    self:DeferUntilKeysUp(keys, function()
        -- Force release all keys before clearing bindings to prevent stuck keys
        self:ForceReleaseAllKeys()

        -- Immediately clear all override bindings to restore normal function
        self:ClearOverrideBindings()
        bindingsCurrentlyActive = false

        if self.parent:GetConfig("debug") then
            self.parent:Print("Skyriding overrides cleared: All movement keys restored to normal")
        end
    end)
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
                    self.parent:Debug("Detected dragonriding mount (mountTypeID: " .. tostring(mountTypeID) .. ")")
                end

                -- Check for other flying mounts that might support dynamic flight
                if not currentlyInSkyriding and mountTypeID == 248 and canFly then
                    if IsFlying() then
                        currentlyInSkyriding = true
                        self.parent:Debug("Detected flying mount in dynamic flight mode")
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
                        self.parent:Debug("Detected skyriding via spell knowledge (spellID: " .. tostring(spellID) .. ")")
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
            self.parent:Debug("State change debounced - too rapid")
            return
        end

        lastStateChangeTime = currentTime
        stateChangeDebounce = 1.0

        -- Update the skyriding state
        isInSkyriding = currentlyInSkyriding
        
        if currentlyInSkyriding then
            self.parent:Debug("Entered skyriding mode - ready for mouse-triggered overrides")
            if self.parent:GetConfig("debug") then
                self.parent:Print("Skyriding mode detected - hold left mouse button to activate overrides")
            end
        else
            self.parent:Debug("Exited skyriding mode - clearing any active overrides")
            -- Clear overrides immediately when exiting skyriding mode
            if bindingsCurrentlyActive then
                self:ClearSkyridingOverrides()
            end
            if self.parent:GetConfig("debug") then
                self.parent:Print("Skyriding mode disabled")
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

    self.parent:Debug("EnterSkyridingMode called - skyriding detection active")
    
    -- If mouse is already down when entering skyriding mode, apply overrides
    if isLeftMouseDown and not bindingsCurrentlyActive then
        self:ApplySkyridingOverrides()
    end
end

function Skyriding:ExitSkyridingMode()
    -- Compatibility wrapper for the new mouse-triggered system
    self.parent:Debug("ExitSkyridingMode called - clearing any active overrides")

    -- Clear any active overrides when exiting skyriding mode
    if bindingsCurrentlyActive then
        self:ClearSkyridingOverrides()
    end
end

function Skyriding:ForceReleaseAllKeys()
    -- Force release all movement keys to prevent stuck key states
    -- This uses harmless override remaps to flush held state (safe out of combat)

    -- Create override frame if it doesn't exist
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "ColdSnapSkyridingOverrideFrame")
        self.parent:Debug("Created override binding frame for key release")
    end

    local keys = {}
    local function add(list) for _, k in ipairs(list or {}) do table.insert(keys, k) end end
    add(GetAllBindingKeys("STRAFELEFT"))
    add(GetAllBindingKeys("STRAFERIGHT"))
    add(GetAllBindingKeys("MOVEFORWARD"))
    add(GetAllBindingKeys("MOVEBACKWARD"))
    add(GetAllBindingKeys("TURNLEFT"))
    add(GetAllBindingKeys("TURNRIGHT"))

    for _, key in ipairs(keys) do
        SetOverrideBinding(overrideFrame, false, key, "CAMERALOOKTOGGLEMOUSE")
    end

    self.parent:Debug("Force released all movement keys")
end

function Skyriding:ClearOverrideBindings()
    if overrideFrame then
        ClearOverrideBindings(overrideFrame)
        self.parent:Debug("Cleared all override bindings immediately")
    end
end

function Skyriding:ApplySkyridingBindings()
    -- Use override bindings instead of changing actual bindings
    -- Override bindings are temporary and safe - they don't modify user's actual keybinds

    if not overrideFrame then
        self.parent:Debug("Override frame not created, cannot apply bindings")
        return
    end

    -- Get the current bindings to override and apply
    for _, key in ipairs(GetAllBindingKeys("STRAFELEFT")) do
        SetOverrideBinding(overrideFrame, false, key, "TURNLEFT")
        self.parent:Debug("Override: " .. key .. " -> TURNLEFT")
    end

    for _, key in ipairs(GetAllBindingKeys("STRAFERIGHT")) do
        SetOverrideBinding(overrideFrame, false, key, "TURNRIGHT")
        self.parent:Debug("Override: " .. key .. " -> TURNRIGHT")
    end

    -- Apply vertical movement bindings if pitch control is enabled
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")

        for _, key in ipairs(GetAllBindingKeys("MOVEFORWARD")) do
            SetOverrideBinding(overrideFrame, false, key, invertPitch and "PITCHDOWN" or "PITCHUP")
            self.parent:Debug("Override: " .. key .. " -> " .. (invertPitch and "PITCHDOWN" or "PITCHUP"))
        end

        for _, key in ipairs(GetAllBindingKeys("MOVEBACKWARD")) do
            SetOverrideBinding(overrideFrame, false, key, invertPitch and "PITCHUP" or "PITCHDOWN")
            self.parent:Debug("Override: " .. key .. " -> " .. (invertPitch and "PITCHUP" or "PITCHDOWN"))
        end
    end

    self.parent:Debug("Applied skyriding override bindings")
end

function Skyriding:EmergencyReset()
    -- Emergency function to reset all bindings and state
    -- Can be called via slash command if something goes wrong
    self.parent:Debug("Emergency reset of skyriding bindings")

    if overrideFrame then
        self:ForceReleaseAllKeys()
        C_Timer.After(0.1, function()
            if overrideFrame then
                ClearOverrideBindings(overrideFrame)
            end
        end)
    end

    -- Reset state
    isInSkyriding = false
    isLeftMouseDown = false
    bindingsCurrentlyActive = false
    stateChangeDebounce = 0

    self.parent:Print("Emergency reset complete - all movement keys restored to normal")
end

-- Register the module
ColdSnap:RegisterModule("skyriding", Skyriding)
