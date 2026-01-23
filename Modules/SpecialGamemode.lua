-- B.O.L.T Special Gamemode Module (Hidden trolling features)
-- Contains special "gamemodes" to prank friends

local ADDON_NAME, BOLT = ...

-- Create the SpecialGamemode module
local SpecialGamemode = {}

function SpecialGamemode:OnInitialize()
    self.hardcoreModeActive = false
    self.effectsPaused = false

    -- Set up simple key polling for F1/F2
    self:SetupKeyPolling()

    -- Set up chat monitoring
    self:SetupChatMonitoring()
end

function SpecialGamemode:OnEnable()
    -- Module enabled
end

function SpecialGamemode:SetupKeyPolling()
    -- Simple timer that checks key states every 0.1 seconds
    self.keyPollTimer = C_Timer.NewTicker(0.1, function()
        if IsKeyDown then
            -- Ctrl+Shift+F1 to activate hardcore mode
            if IsKeyDown("F1") and IsControlKeyDown() and IsShiftKeyDown() and not self.activateWasPressed and not self.hardcoreModeActive then
                self.activateWasPressed = true
                self:EnterHardcoreMode()
            elseif not (IsKeyDown("F1") and IsControlKeyDown() and IsShiftKeyDown()) then
                self.activateWasPressed = false
            end

            -- Ctrl+Shift+F2 to exit hardcore mode
            if IsKeyDown("F2") and IsControlKeyDown() and IsShiftKeyDown() and not self.exitWasPressed and self.hardcoreModeActive then
                self.exitWasPressed = true
                self:ExitHardcoreMode()
            elseif not (IsKeyDown("F2") and IsControlKeyDown() and IsShiftKeyDown()) then
                self.exitWasPressed = false
            end
        end
    end)
end

function SpecialGamemode:SetupChatMonitoring()
    -- Create frame to handle chat events
    if not self.chatFrame then
        self.chatFrame = CreateFrame("Frame")
        -- Register for multiple chat events
        self.chatFrame:RegisterEvent("CHAT_MSG_YELL")
        self.chatFrame:RegisterEvent("CHAT_MSG_PARTY")
        self.chatFrame:RegisterEvent("CHAT_MSG_RAID")
        self.chatFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
        self.chatFrame:SetScript("OnEvent", function(frame, event, message, sender, ...)
            self:OnChatMessage(event, message, sender, ...)
        end)
    end
end

function SpecialGamemode:OnChatMessage(event, message, sender, ...)
    -- Convert message to lowercase for case-insensitive matching
    local lowerMessage = string.lower(message or "")

    -- Define chat triggers with their actions
    local chatTriggers = {
        -- Hardcore mode triggers
        {
            trigger = "carrot",
            channels = { "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT" },
            action = function()
                if not self.hardcoreModeActive then
                    print("BOLT: Activating hardcore mode via chat")
                    self:EnterHardcoreMode()
                    if self.parent and self.parent.Print then
                        self.parent:Print("|cFFFF0000Hardcore mode activated by group member!|r")
                    end
                else
                    print("BOLT: Hardcore mode already active")
                end
            end
        },
        {
            trigger = "feta",
            channels = { "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT" },
            action = function()
                if self.hardcoreModeActive then
                    print("BOLT: Deactivating hardcore mode via chat")
                    self:ExitHardcoreMode()
                    if self.parent and self.parent.Print then
                        self.parent:Print("|cFF00FF00Hardcore mode deactivated by group member!|r")
                    end
                else
                    print("BOLT: Hardcore mode not active")
                end
            end
        },
        -- Dismount trigger (completely silent)
        {
            trigger = "oops!",
            channels = { "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_INSTANCE_CHAT" },
            action = function()
                if IsMounted() then
                    Dismount()
                elseif UnitInVehicle("player") then
                    VehicleExit()
                end
            end
        }
    }

    -- Process all chat triggers
    for _, triggerData in ipairs(chatTriggers) do
        -- Check if the current event channel is in the trigger's allowed channels
        local channelAllowed = false
        for _, allowedChannel in ipairs(triggerData.channels) do
            if event == allowedChannel then
                channelAllowed = true
                break
            end
        end

        -- If channel is allowed and trigger word is found, execute the action
        if channelAllowed and string.find(lowerMessage, triggerData.trigger) then
            triggerData.action()
        end
    end
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
    self.parent:Print("|cFFFF0000HARDCORE MODE ACTIVATED!|r")

    -- Send group chat message
    if GetNumGroupMembers() > 0 then
        local chatType = IsInRaid() and "RAID" or "PARTY"
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage("Hardcore mode activated!", chatType)
        else
            -- Fallback: display a local message in the primary chat frame
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000[B.O.L.T]|r Hardcore mode activated!")
            end
        end
    end

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
    local ok = pcall(function() UIParent:Show() end)
    if not ok and self.parent and self.parent.Print then
        self.parent:Print("B.O.L.T: UI show blocked by restrictions.")
    end

    -- Restore original camera zoom
    if self.originalCameraDistance then
        -- Directly restore the original camera distance without resetting first
        if SetCameraZoom then
            pcall(SetCameraZoom, self.originalCameraDistance)
        else
            -- Fallback: Use CameraZoomOut/CameraZoomIn to reach the original distance
            local currentZoom = GetCameraZoom()
            local targetZoom = self.originalCameraDistance

            -- Calculate how much we need to adjust
            if currentZoom < targetZoom then
                -- Need to zoom out to increase distance
                local difference = targetZoom - currentZoom
                pcall(CameraZoomOut, difference)
            elseif currentZoom > targetZoom then
                -- Need to zoom in to decrease distance
                local difference = currentZoom - targetZoom
                pcall(CameraZoomIn, difference)
            end
        end
        self.originalCameraDistance = nil
    end

    -- Remove game menu hooks
    self:UnhookGameMenuFrame()

    -- Send group chat message
    if GetNumGroupMembers() > 0 then
        local chatType = IsInRaid() and "RAID" or "PARTY"
        if C_ChatInfo and C_ChatInfo.SendChatMessage then
            C_ChatInfo.SendChatMessage("Hardcore mode deactivated!", chatType)
        else
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("|cFF00FF00[B.O.L.T]|r Hardcore mode deactivated!")
            end
        end
    end

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
    -- Hide UI if it's showing (guarded)
    pcall(function()
        if UIParent:IsShown() then
            UIParent:Hide()
        end
    end)

    -- Force camera to first person (guarded)
    pcall(CameraZoomIn, 50) -- Zoom in as much as possible
end

function SpecialGamemode:PauseEffects()
    self.effectsPaused = true
    -- Show UI when effects are paused (guarded)
    pcall(function() UIParent:Show() end)
end

function SpecialGamemode:ResumeEffects()
    self.effectsPaused = false
    -- Effects will be applied on next timer tick
end

function SpecialGamemode:HookGameMenuFrame()
    -- Use HookScript instead of replacing Show/Hide to avoid interfering with other addons
    if GameMenuFrame and not self.hookedGameMenu then
        GameMenuFrame:HookScript("OnShow", function()
            if self.hardcoreModeActive then
                self:PauseEffects()
            end
        end)
        GameMenuFrame:HookScript("OnHide", function()
            if self.hardcoreModeActive then
                self:ResumeEffects()
            end
        end)
        self.hookedGameMenu = true
    end
end

function SpecialGamemode:UnhookGameMenuFrame()
    -- We leave the hooks in place (they are harmless when not in hardcore mode)
    self.hookedGameMenu = nil
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
        if messageFrame then
            messageFrame:Hide()
        end
    end)

    fadeOut:Play()
end

-- Public interface for other modules
function SpecialGamemode:IsHardcoreModeActive()
    return self.hardcoreModeActive
end

-- Register the module
BOLT:RegisterModule("specialGamemode", SpecialGamemode)
