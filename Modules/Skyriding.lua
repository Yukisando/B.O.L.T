-- ColdSnap Skyriding Module
-- Changes strafe keybinds to horizontal movement while sky riding

local ADDON_NAME, ColdSnap = ...

-- Create the Skyriding module
local Skyriding = {}

-- Storage for original keybinds
local originalBindings = {}
local isInSkyriding = false
local bindingCheckFrame = nil

function Skyriding:OnInitialize()
    self.parent:Debug("Skyriding module initializing...")
end

function Skyriding:OnEnable()
    if not self.parent:IsModuleEnabled("skyriding") then
        self.parent:Debug("Skyriding module is disabled, skipping OnEnable")
        return
    end
    
    self.parent:Debug("Skyriding module enabling...")
    
    -- Create event handling frame
    self:CreateEventFrame()
    
    -- Start monitoring for skyriding state
    self:StartMonitoring()
end

function Skyriding:OnDisable()
    self.parent:Debug("Skyriding module disabling...")
    
    -- Restore original bindings if we're currently in skyriding mode
    if isInSkyriding then
        self:RestoreOriginalBindings()
    end
    
    -- Stop monitoring
    self:StopMonitoring()
    
    -- Clean up event frame
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
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
    
    self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
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
    
    -- Handle state changes
    if currentlyInSkyriding ~= isInSkyriding then
        if currentlyInSkyriding then
            self:EnterSkyridingMode()
        else
            self:ExitSkyridingMode()
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
    if InCombatLockdown() then
        self.parent:Debug("In combat, deferring binding changes")
        return
    end
    
    -- Store original bindings before changing them
    self:StoreOriginalBindings()
    
    -- Apply skyriding bindings
    self:ApplySkyridingBindings()
    
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
    self.parent:Debug("Exiting skyriding mode - restoring original bindings")
    
    -- Don't change bindings if in combat
    if InCombatLockdown() then
        self.parent:Debug("In combat, deferring binding restoration")
        return
    end
    
    -- Restore original bindings
    self:RestoreOriginalBindings()
    
    if self.parent:GetConfig("debug") then
        self.parent:Print("Skyriding mode disabled: All movement keys restored to normal")
    end
end

function Skyriding:StoreOriginalBindings()
    -- Clear previous stored bindings
    originalBindings = {}
    
    -- Get the current bindings for strafe left/right
    local strafeLeftBinding = GetBindingKey("STRAFELEFT")
    local strafeRightBinding = GetBindingKey("STRAFERIGHT")
    
    if strafeLeftBinding then
        originalBindings["STRAFELEFT"] = strafeLeftBinding
        self.parent:Debug("Stored original strafe left binding: " .. strafeLeftBinding)
    end
    
    if strafeRightBinding then
        originalBindings["STRAFERIGHT"] = strafeRightBinding
        self.parent:Debug("Stored original strafe right binding: " .. strafeRightBinding)
    end
    
    -- Store forward/backward bindings for pitch control if enabled
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local forwardBinding = GetBindingKey("MOVEFORWARD")
        local backwardBinding = GetBindingKey("MOVEBACKWARD")
        
        if forwardBinding then
            originalBindings["MOVEFORWARD"] = forwardBinding
            self.parent:Debug("Stored original forward binding: " .. forwardBinding)
        end
        
        if backwardBinding then
            originalBindings["MOVEBACKWARD"] = backwardBinding
            self.parent:Debug("Stored original backward binding: " .. backwardBinding)
        end
        
        -- Store pitch up/down bindings
        local pitchUpBinding = GetBindingKey("PITCHUP")
        local pitchDownBinding = GetBindingKey("PITCHDOWN")
        
        if pitchUpBinding then
            originalBindings["PITCHUP"] = pitchUpBinding
        end
        
        if pitchDownBinding then
            originalBindings["PITCHDOWN"] = pitchDownBinding
        end
    end
    
    -- Also store turn bindings in case user wants to swap those too
    local turnLeftBinding = GetBindingKey("TURNLEFT") 
    local turnRightBinding = GetBindingKey("TURNRIGHT")
    
    if turnLeftBinding then
        originalBindings["TURNLEFT"] = turnLeftBinding
    end
    
    if turnRightBinding then
        originalBindings["TURNRIGHT"] = turnRightBinding
    end
end

function Skyriding:ApplySkyridingBindings()
    -- The core concept: Map strafe keys to turn keys for horizontal movement in skyriding
    -- Optionally map forward/backward keys to pitch up/down for vertical movement
    -- This gives full 3D movement control while skyriding
    
    local strafeLeftKey = originalBindings["STRAFELEFT"]
    local strafeRightKey = originalBindings["STRAFERIGHT"]
    
    -- Apply horizontal movement bindings (strafe -> turn)
    if strafeLeftKey then
        -- Bind the strafe left key to turn left action for horizontal movement
        SetBinding(strafeLeftKey, "TURNLEFT")
        self.parent:Debug("Bound " .. strafeLeftKey .. " to TURNLEFT for horizontal movement")
    end
    
    if strafeRightKey then
        -- Bind the strafe right key to turn right action for horizontal movement  
        SetBinding(strafeRightKey, "TURNRIGHT")
        self.parent:Debug("Bound " .. strafeRightKey .. " to TURNRIGHT for horizontal movement")
    end
    
    -- Apply vertical movement bindings if pitch control is enabled
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local forwardKey = originalBindings["MOVEFORWARD"]
        local backwardKey = originalBindings["MOVEBACKWARD"]
        local invertPitch = self.parent:GetConfig("skyriding", "invertPitch")
        
        if forwardKey then
            if invertPitch then
                -- Inverted: Forward key becomes pitch down for diving
                SetBinding(forwardKey, "PITCHDOWN")
                self.parent:Debug("Bound " .. forwardKey .. " to PITCHDOWN for diving (inverted)")
            else
                -- Normal: Forward key becomes pitch up for climbing
                SetBinding(forwardKey, "PITCHUP")
                self.parent:Debug("Bound " .. forwardKey .. " to PITCHUP for climbing")
            end
        end
        
        if backwardKey then
            if invertPitch then
                -- Inverted: Backward key becomes pitch up for climbing
                SetBinding(backwardKey, "PITCHUP")
                self.parent:Debug("Bound " .. backwardKey .. " to PITCHUP for climbing (inverted)")
            else
                -- Normal: Backward key becomes pitch down for diving
                SetBinding(backwardKey, "PITCHDOWN")
                self.parent:Debug("Bound " .. backwardKey .. " to PITCHDOWN for diving")
            end
        end
    end
    
    -- Save the new bindings
    SaveBindings(GetCurrentBindingSet())
end

function Skyriding:RestoreOriginalBindings()
    -- Don't restore if we don't have stored bindings
    if not originalBindings or not next(originalBindings) then
        self.parent:Debug("No stored bindings to restore")
        return
    end
    
    -- Restore the original strafe bindings
    local strafeLeftKey = originalBindings["STRAFELEFT"]
    local strafeRightKey = originalBindings["STRAFERIGHT"]
    
    -- Clear all current bindings for these keys first to prevent conflicts
    if strafeLeftKey then
        SetBinding(strafeLeftKey)
        self.parent:Debug("Cleared binding for " .. strafeLeftKey)
    end
    
    if strafeRightKey then
        SetBinding(strafeRightKey)
        self.parent:Debug("Cleared binding for " .. strafeRightKey)
    end
    
    -- If pitch control was enabled, also restore forward/backward bindings
    if self.parent:GetConfig("skyriding", "enablePitchControl") then
        local forwardKey = originalBindings["MOVEFORWARD"]
        local backwardKey = originalBindings["MOVEBACKWARD"]
        
        if forwardKey then
            SetBinding(forwardKey)
            self.parent:Debug("Cleared binding for " .. forwardKey)
        end
        
        if backwardKey then
            SetBinding(backwardKey)
            self.parent:Debug("Cleared binding for " .. backwardKey)
        end
    end
    
    -- Force save bindings to clear state
    SaveBindings(GetCurrentBindingSet())
    
    -- Small delay to ensure key states are properly cleared
    C_Timer.After(0.1, function()
        -- Now restore original bindings
        if strafeLeftKey then
            SetBinding(strafeLeftKey, "STRAFELEFT")
            self.parent:Debug("Restored " .. strafeLeftKey .. " to STRAFELEFT")
        end
        
        if strafeRightKey then
            SetBinding(strafeRightKey, "STRAFERIGHT")
            self.parent:Debug("Restored " .. strafeRightKey .. " to STRAFERIGHT")
        end
        
        -- Restore pitch control bindings if they were enabled
        if self.parent:GetConfig("skyriding", "enablePitchControl") then
            local forwardKey = originalBindings["MOVEFORWARD"]
            local backwardKey = originalBindings["MOVEBACKWARD"]
            
            if forwardKey then
                SetBinding(forwardKey, "MOVEFORWARD")
                self.parent:Debug("Restored " .. forwardKey .. " to MOVEFORWARD")
            end
            
            if backwardKey then
                SetBinding(backwardKey, "MOVEBACKWARD")
                self.parent:Debug("Restored " .. backwardKey .. " to MOVEBACKWARD")
            end
        end
        
        -- Save the restored bindings
        SaveBindings(GetCurrentBindingSet())
        
        -- Clear stored bindings
        originalBindings = {}
        
        self.parent:Debug("Key binding restoration complete")
    end)
end

-- Register the module
ColdSnap:RegisterModule("skyriding", Skyriding)
