-- B.O.L.T Special Gamemode Module (Hidden trolling features)
-- Contains special "gamemodes" to prank friends

local ADDON_NAME, BOLT = ...

-- Create the SpecialGamemode module
local SpecialGamemode = {}

function SpecialGamemode:OnInitialize()
    self.hardcoreModeActive = false
    self.effectsPaused = false
    
    -- Set up simple key polling for F9/F10
    self:SetupKeyPolling()
end

function SpecialGamemode:OnEnable()
    -- Module enabled
end

function SpecialGamemode:SetupKeyPolling()
    -- Simple timer that checks key states every 0.1 seconds
    self.keyPollTimer = C_Timer.NewTicker(0.1, function()
        if IsKeyDown then
            if IsKeyDown("F9") and not self.f9WasPressed and self:IsGamemodeAllowed() and not self.hardcoreModeActive then
                self.f9WasPressed = true
                self:EnterHardcoreMode()
            elseif not IsKeyDown("F9") then
                self.f9WasPressed = false
            end
            
            if IsKeyDown("F10") and not self.f10WasPressed and self.hardcoreModeActive then
                self.f10WasPressed = true
                self:ExitHardcoreMode()
            elseif not IsKeyDown("F10") then
                self.f10WasPressed = false
            end
        end
    end)
end

function SpecialGamemode:IsGamemodeAllowed()
    return self.parent:GetConfig("playground", "allowSpecialGamemode", true)
end

function SpecialGamemode:EnterHardcoreMode()
    if self.hardcoreModeActive then
        return
    end
    
    self.hardcoreModeActive = true
    
    -- Store original camera distance
    self.originalCameraDistance = GetCameraZoom()
    
    -- Show activation message
    self:ShowModeMessage("HARDCORE MODE ACTIVATED", 2.0)
    self.parent:Print("|cFFFF0000HARDCORE MODE ACTIVATED! Press F10 to escape.|r")
    
    -- Start the effect timer (applies effects every 0.2 seconds)
    self:StartEffectTimer()
end

function SpecialGamemode:ExitHardcoreMode()
    if not self.hardcoreModeActive then
        return
    end
    
    self.hardcoreModeActive = false
    
    -- Stop the effect timer
    self:StopEffectTimer()
    
    -- Restore interface and camera
    UIParent:Show()
    if self.originalCameraDistance then
        SetCameraZoom(self.originalCameraDistance)
        self.originalCameraDistance = nil
    end
    
    -- Remove game menu hooks
    self:UnhookGameMenuFrame()
    
    -- Show exit message
    self:ShowModeMessage("Hardcore mode deactivated", 1.5)
    self.parent:Print("|cFF00FF00Hardcore mode deactivated.|r")
end

function SpecialGamemode:StartEffectTimer()
    -- Stop any existing timer
    self:StopEffectTimer()
    
    -- Set up game menu monitoring
    self:HookGameMenuFrame()
    
    -- Start timer that applies effects every 0.2 seconds
    self.effectTimer = C_Timer.NewTicker(0.2, function()
        if self.hardcoreModeActive and not self.effectsPaused then
            self:ApplyHardcoreEffects()
        end
    end)
end

function SpecialGamemode:StopEffectTimer()
    if self.effectTimer then
        self.effectTimer:Cancel()
        self.effectTimer = nil
    end
end

function SpecialGamemode:ApplyHardcoreEffects()
    -- Hide UI if it's showing
    if UIParent:IsShown() then
        UIParent:Hide()
    end
    
    -- Force camera to first person
    CameraZoomIn(50) -- Zoom in as much as possible
end

function SpecialGamemode:PauseEffects()
    self.effectsPaused = true
    -- Show UI when effects are paused
    UIParent:Show()
end

function SpecialGamemode:ResumeEffects()
    self.effectsPaused = false
    -- Effects will be applied on next timer tick
end

function SpecialGamemode:HookGameMenuFrame()
    -- Hook GameMenuFrame to pause/resume effects when menu shows/hides
    if GameMenuFrame and not self.originalGameMenuShow then
        self.originalGameMenuShow = GameMenuFrame.Show
        self.originalGameMenuHide = GameMenuFrame.Hide
        
        GameMenuFrame.Show = function(frame)
            self.originalGameMenuShow(frame)
            -- Pause effects when game menu shows
            if self.hardcoreModeActive then
                self:PauseEffects()
            end
        end
        
        GameMenuFrame.Hide = function(frame)
            self.originalGameMenuHide(frame)
            -- Resume effects when game menu hides
            if self.hardcoreModeActive then
                self:ResumeEffects()
            end
        end
    end
end

function SpecialGamemode:UnhookGameMenuFrame()
    -- Restore original GameMenuFrame functions
    if GameMenuFrame then
        if self.originalGameMenuShow then
            GameMenuFrame.Show = self.originalGameMenuShow
            self.originalGameMenuShow = nil
        end
        if self.originalGameMenuHide then
            GameMenuFrame.Hide = self.originalGameMenuHide
            self.originalGameMenuHide = nil
        end
    end
end

function SpecialGamemode:ShowModeMessage(text, duration)
    -- Create a temporary message frame
    local messageFrame = CreateFrame("Frame", nil, UIParent)
    messageFrame:SetSize(400, 100)
    messageFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    
    local messageText = messageFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    messageText:SetPoint("CENTER")
    messageText:SetText(text)
    messageText:SetTextColor(1, 0, 0, 1) -- Red text
    
    -- Create glow effect
    local glow = messageFrame:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Spellbook\\SpellBook-Parts")
    glow:SetTexCoord(0.49, 0.74, 0.74, 0.95)
    glow:SetPoint("CENTER")
    glow:SetSize(450, 120)
    glow:SetVertexColor(1, 0, 0, 0.5)
    
    -- Fade out animation
    local fadeOut = messageFrame:CreateAnimationGroup()
    local alpha = fadeOut:CreateAnimation("Alpha")
    alpha:SetFromAlpha(1)
    alpha:SetToAlpha(0)
    alpha:SetDuration(duration or 2.0)
    alpha:SetScript("OnFinished", function()
        messageFrame:Hide()
        messageFrame = nil
    end)
    
    fadeOut:Play()
end

-- Public interface for other modules
function SpecialGamemode:IsHardcoreModeActive()
    return self.hardcoreModeActive
end

function SpecialGamemode:ToggleGamemodeAllowed(enabled)
    if not enabled and self.hardcoreModeActive then
        -- If disabling gamemodes while hardcore mode is active, exit it
        self:ExitHardcoreMode()
    end
    
    -- Clean up timers if disabling
    if not enabled then
        if self.keyPollTimer then
            self.keyPollTimer:Cancel()
            self.keyPollTimer = nil
        end
        if self.effectTimer then
            self.effectTimer:Cancel()
            self.effectTimer = nil
        end
    else
        -- Re-setup key polling if enabling
        if not self.keyPollTimer then
            self:SetupKeyPolling()
        end
    end
end

-- Register the module
BOLT:RegisterModule("specialGamemode", SpecialGamemode)