-- ColdSnap Skyriding Module
-- Changes strafe keybinds to horizontal movement while sky riding

local ADDON_NAME, ColdSnap = ...

-- Create the Skyriding module
local Skyriding = {}

-- Storage for original keybinds and state management
local originalBindings = {}
local isInSkyriding = false
local bindingCheckFrame = nil
local overrideFrame = nil
local isInCombat = false
local pendingStateChange = nil
local stateChangeDebounce = 0
local lastStateChangeTime = 0

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
    pendingStateChange = nil
    stateChangeDebounce = 0
    lastStateChangeTime = 0
    
    -- Create event handling frame
    self:CreateEventFrame()
    
    -- Start monitoring for skyriding state
    self:StartMonitoring()
end

function Skyriding:OnDisable()
    self.parent:Debug("Skyriding module disabling...")
    
    -- Force release all keys before cleanup
    self:ForceReleaseAllKeys()
    
    -- Clear override bindings if we're currently in skyriding mode
    if isInSkyriding then
        self:ClearOverrideBindings()
    end
    
    -- Reset state variables
    isInSkyriding = false
    isInCombat = false
    pendingStateChange = nil
    stateChangeDebounce = 0
    lastStateChangeTime = 0
    
    -- Stop monitoring
    self:StopMonitoring()
    
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
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Combat start
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Combat end
    
    self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "PLAYER_REGEN_DISABLED" then
            isInCombat = true
            self.parent:Debug("Combat started - blocking binding changes")
        elseif event == "PLAYER_REGEN_ENABLED" then
            isInCombat = false
            self.parent:Debug("Combat ended - checking for pending binding changes")
            -- Process any pending state changes after combat
            if pendingStateChange ~= nil then
                C_Timer.After(0.1, function()
                    if pendingStateChange == true then
                        self:EnterSkyridingMode()
                    else
                        self:ExitSkyridingMode()
                    end
                    pendingStateChange = nil
                end)
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unitTarget, castGUID, spellID = ...
            if unitTarget == "player" then
                -- Check if it's a mount spell
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
                    self.parent:Debug("Detected dragonriding mount (mountTypeID: " .. mountTypeID .. ")")
                end
                
                -- Check for other flying mounts that might support dynamic flight
                if not currentlyInSkyriding and mountTypeID == 248 and canFly then
                    -- Additional check to see if we're in dynamic flight mode
                    -- This could be enhanced in the future with more specific API calls
                    if IsFlying() then
                        currentlyInSkyriding = true
                        self.parent:Debug("Detected flying mount in dynamic flight mode")
                    end
                end
            end
            
            -- Alternative check: Look for dragonriding-specific buffs or abilities
            if not currentlyInSkyriding and canFly and IsFlying() then
                -- Check for dragonriding abilities being available
                local skyridingSpells = {
                    372610, -- Surge Forward
                    361584, -- Skyward Ascent  
                    372611, -- Whirling Surge
                    377236, -- Dragonriding (base ability)
                }
                
                for _, spellID in ipairs(skyridingSpells) do
                    if IsSpellKnown(spellID) then
                        -- If we know dragonriding spells and we're flying, likely in skyriding mode
                        currentlyInSkyriding = true
                        self.parent:Debug("Detected skyriding via spell knowledge (spellID: " .. spellID .. ")")
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
        
        if currentlyInSkyriding then
            if isInCombat then
                pendingStateChange = true
                self.parent:Debug("Skyriding state change pending due to combat")
            else
                self:EnterSkyridingMode()
            end
        else
            if isInCombat then
                pendingStateChange = false
                self.parent:Debug("Skyriding state change pending due to combat")
            else
                self:ExitSkyridingMode()
            end
        end
        isInSkyriding = currentlyInSkyriding
    end
end

function Skyriding:EnterSkyridingMode()
    if not self.parent:GetConfig("skyriding", "enabled") then
        return
    end
    
    self.parent:Debug("Entering skyriding mode - swapping strafe bindings")
    
    -- Don't change bindings if in combat
    if isInCombat then
        self.parent:Debug("In combat, setting pending state change")
        pendingStateChange = true
        return
    end
    
    -- Create override frame first if needed
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "ColdSnapSkyridingOverrideFrame")
        self.parent:Debug("Created override binding frame")
    end
    
    -- Force release all keys before changing bindings to prevent stuck keys
    self:ForceReleaseAllKeys()
    
    -- Small delay to ensure key release is processed
    C_Timer.After(0.05, function()
        -- Store original bindings before changing them
        self:StoreOriginalBindings()
        
        -- Apply skyriding bindings
        self:ApplySkyridingBindings()
    end)
    
    if self.parent:GetConfig("debug") then
        local pitchEnabled = self.parent:GetConfig("skyriding", "enablePitchControl")
        local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")
        
        if pitchEnabled then
            if invertPitch then
                self.parent:Print("Skyriding mode: A/D=horizontal, W=dive, S=climb")
            else
                self.parent:Print("Skyriding mode: A/D=horizontal, W=climb, S=dive")
            end
        else
            self.parent:Print("Skyriding mode: A/D=horizontal movement only")
        end
    end
end

function Skyriding:ExitSkyridingMode()
    self.parent:Debug("Exiting skyriding mode - clearing override bindings")
    
    -- Don't change bindings if in combat
    if isInCombat then
        self.parent:Debug("In combat, setting pending state change")
        pendingStateChange = false
        return
    end
    
    -- Only force release keys if we have an override frame (meaning we were actually in skyriding mode)
    if overrideFrame then
        -- Force release all keys before clearing bindings to prevent stuck keys
        self:ForceReleaseAllKeys()
        
        -- Immediately clear all override bindings to restore normal function
        self:ClearOverrideBindings()
    end
    
    if self.parent:GetConfig("debug") then
        self.parent:Print("Skyriding mode disabled: All movement keys restored to normal")
    end
end

function Skyriding:ForceReleaseAllKeys()
    -- Force release all movement keys to prevent stuck key states
    -- This simulates releasing keys by sending key up events
    
    -- Create override frame if it doesn't exist
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "ColdSnapSkyridingOverrideFrame")
        self.parent:Debug("Created override binding frame for key release")
    end
    
    local keysToRelease = {
        GetBindingKey("STRAFELEFT"),
        GetBindingKey("STRAFERIGHT"),
        GetBindingKey("MOVEFORWARD"),
        GetBindingKey("MOVEBACKWARD"),
        GetBindingKey("TURNLEFT"),
        GetBindingKey("TURNRIGHT")
    }
    
    for _, key in ipairs(keysToRelease) do
        if key then
            -- Create temporary binding to "CAMERALOOKTOGGLEMOUSE" (a harmless action)
            -- This forces the key state to reset
            SetOverrideBinding(overrideFrame, false, key, "CAMERALOOKTOGGLEMOUSE")
        end
    end
    
    self.parent:Debug("Force released all movement keys")
end

function Skyriding:ClearOverrideBindings()
    if overrideFrame then
        -- Immediately clear all override bindings to restore normal function
        ClearOverrideBindings(overrideFrame)
        self.parent:Debug("Cleared all override bindings immediately")
    end
end

function Skyriding:StoreOriginalBindings()
    -- Create the override frame if it doesn't exist
    if not overrideFrame then
        overrideFrame = CreateFrame("Frame", "ColdSnapSkyridingOverrideFrame")
        self.parent:Debug("Created override binding frame")
    end
    
    -- Clear any existing override bindings first
    ClearOverrideBindings(overrideFrame)
    
    -- Get the current bindings for reference and debugging
    local strafeLeftBinding = GetBindingKey("STRAFELEFT")
    local strafeRightBinding = GetBindingKey("STRAFERIGHT")
    local forwardBinding = GetBindingKey("MOVEFORWARD")
    local backwardBinding = GetBindingKey("MOVEBACKWARD")
    
    if strafeLeftBinding then
        self.parent:Debug("Current strafe left binding: " .. strafeLeftBinding)
    end
    
    if strafeRightBinding then
        self.parent:Debug("Current strafe right binding: " .. strafeRightBinding)
    end
    
    if forwardBinding then
        self.parent:Debug("Current forward binding: " .. forwardBinding)
    end
    
    if backwardBinding then
        self.parent:Debug("Current backward binding: " .. backwardBinding)
    end
end

function Skyriding:ApplySkyridingBindings()
    -- Use override bindings instead of changing actual bindings
    -- Override bindings are temporary and safe - they don't modify user's actual keybinds
    
    if not overrideFrame then
        self.parent:Debug("Override frame not created, cannot apply bindings")
        return
    end
    
    -- Get the current bindings to override
    local strafeLeftKey = GetBindingKey("STRAFELEFT")
    local strafeRightKey = GetBindingKey("STRAFERIGHT")
    
    -- Apply horizontal movement bindings (strafe -> turn)
    if strafeLeftKey then
        -- Override the strafe left key to perform turn left action
        SetOverrideBinding(overrideFrame, false, strafeLeftKey, "TURNLEFT")
        self.parent:Debug("Override: " .. strafeLeftKey .. " -> TURNLEFT")
    end
    
    if strafeRightKey then
        -- Override the strafe right key to perform turn right action
        SetOverrideBinding(overrideFrame, false, strafeRightKey, "TURNRIGHT")
        self.parent:Debug("Override: " .. strafeRightKey .. " -> TURNRIGHT")
    end
    
    -- Apply vertical movement bindings if pitch control is enabled
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local forwardKey = GetBindingKey("MOVEFORWARD")
        local backwardKey = GetBindingKey("MOVEBACKWARD")
        local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")
        
        if forwardKey then
            if invertPitch then
                -- Inverted: Forward key becomes pitch down for diving
                SetOverrideBinding(overrideFrame, false, forwardKey, "PITCHDOWN")
                self.parent:Debug("Override: " .. forwardKey .. " -> PITCHDOWN (inverted)")
            else
                -- Normal: Forward key becomes pitch up for climbing
                SetOverrideBinding(overrideFrame, false, forwardKey, "PITCHUP")
                self.parent:Debug("Override: " .. forwardKey .. " -> PITCHUP")
            end
        end
        
        if backwardKey then
            if invertPitch then
                -- Inverted: Backward key becomes pitch up for climbing
                SetOverrideBinding(overrideFrame, false, backwardKey, "PITCHUP")
                self.parent:Debug("Override: " .. backwardKey .. " -> PITCHUP (inverted)")
            else
                -- Normal: Backward key becomes pitch down for diving
                SetOverrideBinding(overrideFrame, false, backwardKey, "PITCHDOWN")
                self.parent:Debug("Override: " .. backwardKey .. " -> PITCHDOWN")
            end
        end
    end
    
    self.parent:Debug("Applied skyriding override bindings")
end

function Skyriding:EmergencyReset()
    -- Emergency function to reset all bindings and state
    -- Can be called via slash command if something goes wrong
    self.parent:Debug("Emergency reset of skyriding bindings")
    
    -- Force release all keys if we have an override frame
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
    pendingStateChange = nil
    stateChangeDebounce = 0
    
    self.parent:Print("Emergency reset complete - all movement keys restored to normal")
end

-- Register the module
ColdSnap:RegisterModule("skyriding", Skyriding)
