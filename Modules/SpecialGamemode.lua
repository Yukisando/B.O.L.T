-- B.O.L.T Special Gamemode Module (hidden prank features)
-- "Hardcore mode" blacks out the screen and forces first person; a trigger word in
-- chat can switch it on/off or dismount the player. Configured through /boltadmin.

local ADDON_NAME, BOLT = ...

local SpecialGamemode = {
    displayName = "Special Gamemode",
    alwaysOn = true,
}

SpecialGamemode.CHANNELS = {
    { value = "say", label = "Say", events = { "CHAT_MSG_SAY" } },
    { value = "yell", label = "Yell", events = { "CHAT_MSG_YELL" } },
    { value = "party", label = "Party", events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" } },
    { value = "raid", label = "Raid", events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" } },
    { value = "instance", label = "Instance", events = { "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER" } },
    { value = "whisper", label = "Whisper", events = { "CHAT_MSG_WHISPER" } },
}

SpecialGamemode.DEFAULTS = {
    triggersEnabled = true,
    dismountTrigger = "oops",
    dismountChannels = { yell = true },
    hardcoreActivateTrigger = "carrot",
    hardcoreDeactivateTrigger = "feta",
    hardcoreChannels = { yell = true },
    hardcoreEnableMsg = "Hardcore mode activated!",
    hardcoreDisableMsg = "Hardcore mode deactivated!",
}

local EFFECT_INTERVAL = 0.2

-- Account-wide settings in BOLTDB.admin, filled with defaults.
function SpecialGamemode:GetSettings()
    BOLTDB = BOLTDB or {}
    BOLTDB.admin = BOLTDB.admin or {}
    local settings = BOLTDB.admin
    for key, value in pairs(self.DEFAULTS) do
        if settings[key] == nil then
            settings[key] = type(value) == "table" and CopyTable(value) or value
        end
    end
    return settings
end

local function EventInChannels(event, channels)
    for _, channel in ipairs(SpecialGamemode.CHANNELS) do
        if channels[channel.value] then
            for _, channelEvent in ipairs(channel.events) do
                if channelEvent == event then return true end
            end
        end
    end
    return false
end

local function ContainsTrigger(message, trigger)
    -- Plain find: triggers with pattern characters ("(", "%", "-") match literally.
    return trigger ~= "" and message:find(trigger:lower(), 1, true) ~= nil
end

function SpecialGamemode:OnChatMessage(event, message)
    -- Chat in instances arrives as secret values that can't be inspected.
    if BOLT.IsSecret(message) or type(message) ~= "string" then return end

    local settings = self:GetSettings()
    if not settings.triggersEnabled then return end
    message = message:lower()

    if EventInChannels(event, settings.hardcoreChannels) then
        if ContainsTrigger(message, settings.hardcoreActivateTrigger) and not self.hardcoreActive then
            self:EnterHardcoreMode()
        elseif ContainsTrigger(message, settings.hardcoreDeactivateTrigger) and self.hardcoreActive then
            self:ExitHardcoreMode()
        end
    end

    if EventInChannels(event, settings.dismountChannels) and ContainsTrigger(message, settings.dismountTrigger) then
        if IsMounted() then
            Dismount()
        elseif UnitInVehicle("player") then
            VehicleExit()
        end
    end
end

---------------------------------------------------------------------------
-- Hardcore mode
---------------------------------------------------------------------------

function SpecialGamemode:AnnounceToGroup(text)
    if IsInGroup() then
        BOLT:SendChat(text, IsInRaid() and "RAID" or "PARTY")
    end
end

function SpecialGamemode:EnterHardcoreMode()
    if self.hardcoreActive then return end
    self.hardcoreActive = true
    self.originalZoom = GetCameraZoom()

    self:ShowModeMessage("HARDCORE MODE ACTIVATED", 2)
    BOLT:Print("|cffff0000Hardcore mode activated!|r")
    self:AnnounceToGroup(self:GetSettings().hardcoreEnableMsg)

    -- The effect pauses while the game menu is open so the player can still use it.
    BOLT:WatchGameMenu("specialGamemode",
        function() self.coverFrame:Hide() end,
        function() self:ApplyEffects() end)
    self.effectTicker = C_Timer.NewTicker(EFFECT_INTERVAL, function() self:ApplyEffects() end)
    self:ApplyEffects()
end

function SpecialGamemode:ExitHardcoreMode()
    if not self.hardcoreActive then return end
    self.hardcoreActive = false

    self.effectTicker:Cancel()
    self.effectTicker = nil
    BOLT:UnwatchGameMenu("specialGamemode")
    self.coverFrame:Hide()

    if self.originalZoom then
        local difference = self.originalZoom - GetCameraZoom()
        if difference > 0 then
            CameraZoomOut(difference)
        elseif difference < 0 then
            CameraZoomIn(-difference)
        end
        self.originalZoom = nil
    end

    self:ShowModeMessage("Hardcore mode deactivated", 1.5)
    BOLT:Print("|cff00ff00Hardcore mode deactivated.|r")
    self:AnnounceToGroup(self:GetSettings().hardcoreDisableMsg)
end

function SpecialGamemode:ApplyEffects()
    if not self.hardcoreActive or BOLT:IsGameMenuShown() then return end
    -- A full-screen cover instead of UIParent:Hide(), which is protected.
    self.coverFrame:Show()
    CameraZoomIn(50)
end

function SpecialGamemode:IsHardcoreModeActive()
    return self.hardcoreActive == true
end

function SpecialGamemode:ShowModeMessage(text, duration)
    local frame = self.messageFrame
    frame.text:SetText(text)
    frame.fade:SetDuration(duration)
    frame:Show()
    frame.animation:Stop()
    frame.animation:Play()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function SpecialGamemode:CreateFrames()
    local cover = CreateFrame("Frame", "BOLTHardcoreCover", UIParent)
    cover:SetAllPoints(UIParent)
    cover:SetFrameStrata("FULLSCREEN_DIALOG")
    cover:SetFrameLevel(9999)
    local black = cover:CreateTexture(nil, "BACKGROUND")
    black:SetAllPoints()
    black:SetColorTexture(0, 0, 0, 1)
    cover:Hide()
    self.coverFrame = cover

    local message = CreateFrame("Frame", nil, UIParent)
    message:SetSize(400, 100)
    message:SetPoint("CENTER", 0, 100)
    message:SetFrameStrata("TOOLTIP")
    message.text = message:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    message.text:SetPoint("CENTER")
    message.text:SetTextColor(1, 0, 0, 1)
    local glow = message:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture("Interface\\Spellbook\\SpellBook-Parts")
    glow:SetTexCoord(0.49, 0.74, 0.74, 0.95)
    glow:SetPoint("CENTER")
    glow:SetSize(450, 120)
    glow:SetVertexColor(1, 0, 0, 0.5)
    message.animation = message:CreateAnimationGroup()
    message.fade = message.animation:CreateAnimation("Alpha")
    message.fade:SetFromAlpha(1)
    message.fade:SetToAlpha(0)
    message.animation:SetScript("OnFinished", function() message:Hide() end)
    message:Hide()
    self.messageFrame = message
end

-- Ctrl+Shift+F1 enters hardcore mode, Ctrl+Shift+F2 leaves it. Polled because a
-- keybinding would show up (and could be rebound) in the Key Bindings UI.
function SpecialGamemode:StartHotkeyPolling()
    local wasDown = {}
    C_Timer.NewTicker(0.1, function()
        local modifiers = IsControlKeyDown() and IsShiftKeyDown()
        for key, action in pairs({ F1 = "EnterHardcoreMode", F2 = "ExitHardcoreMode" }) do
            local down = modifiers and IsKeyDown(key)
            if down and not wasDown[key] then
                self[action](self)
            end
            wasDown[key] = down
        end
    end)
end

function SpecialGamemode:OnInitialize()
    self:CreateFrames()
    self:StartHotkeyPolling()

    self.eventFrame = CreateFrame("Frame")
    for _, channel in ipairs(self.CHANNELS) do
        for _, event in ipairs(channel.events) do
            self.eventFrame:RegisterEvent(event)
        end
    end
    self.eventFrame:SetScript("OnEvent", function(_, event, message)
        self:OnChatMessage(event, message)
    end)
end

BOLT:RegisterModule("specialGamemode", SpecialGamemode)
