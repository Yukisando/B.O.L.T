-- B.O.L.T Chat Notifier Module
-- Plays a sound when a new message appears in monitored chat channels.

local ADDON_NAME, BOLT = ...

local ChatNotifier = {
    displayName = "Chat Notifier",
}

-- Chat event suffix -> label
ChatNotifier.CHANNEL_TYPES = {
    { event = "CHANNEL", label = "Custom Channels" },
    { event = "GUILD", label = "Guild" },
    { event = "OFFICER", label = "Officer" },
    { event = "PARTY", label = "Party" },
    { event = "PARTY_LEADER", label = "Party Leader" },
    { event = "RAID", label = "Raid" },
    { event = "RAID_LEADER", label = "Raid Leader" },
    { event = "RAID_WARNING", label = "Raid Warning" },
    { event = "INSTANCE_CHAT", label = "Instance" },
    { event = "INSTANCE_CHAT_LEADER", label = "Instance Leader" },
    { event = "SAY", label = "Say" },
    { event = "YELL", label = "Yell" },
    { event = "WHISPER", label = "Whisper" },
    { event = "BN_WHISPER", label = "Battle.net Whisper" },
    { event = "EMOTE", label = "Emote" },
}

ChatNotifier.SOUND_OPTIONS = {
    { label = "Raid Warning", soundID = 8959 },
    { label = "Auction Open", soundID = 5274 },
    { label = "Map Ping", soundID = 3175 },
    { label = "Loot Coin", soundID = 120 },
    { label = "GM Chat", soundID = 9637 },
    { label = "Alarm Clock 3", soundID = 7355 },
    { label = "Jeweler Craft", soundID = 3337 },
    { label = "Bell Toll", soundID = 6674 },
    { label = "PVP Warning", soundID = 8332 },
    { label = "Store Purchase", soundID = 39517 },
    { label = "Put Ring Down", soundID = 1210 },
    { label = "Put Ring Wood", soundID = 1217 },
}

local THROTTLE_SECONDS = 1
local lastPlayTime = 0

function ChatNotifier:IsChannelEnabled(eventSuffix)
    return BOLT:GetConfig("chatNotifier", "channels")[eventSuffix] == true
end

function ChatNotifier:SetChannelEnabled(eventSuffix, enabled)
    BOLT:GetConfig("chatNotifier", "channels")[eventSuffix] = enabled or nil
end

function ChatNotifier:GetSoundID()
    return BOLT:GetConfig("chatNotifier", "soundID")
end

function ChatNotifier:SetSoundID(soundID)
    BOLT:SetConfig(soundID, "chatNotifier", "soundID")
end

function ChatNotifier:PlayNotification()
    PlaySound(self:GetSoundID(), "Master")
end

function ChatNotifier:OnChatEvent(event, _, sender)
    if not self:IsChannelEnabled(event:sub(10)) then return end -- strip "CHAT_MSG_"
    -- In instances the sender can be a secret value; notify anyway.
    if BOLT:IsPlayerName(sender) then return end

    local now = GetTime()
    if now - lastPlayTime < THROTTLE_SECONDS then return end
    lastPlayTime = now
    self:PlayNotification()
end

function ChatNotifier:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnChatEvent(event, ...)
    end)
end

function ChatNotifier:OnEnable()
    for _, channel in ipairs(self.CHANNEL_TYPES) do
        self.eventFrame:RegisterEvent("CHAT_MSG_" .. channel.event)
    end
end

function ChatNotifier:OnDisable()
    self.eventFrame:UnregisterAllEvents()
end

BOLT:RegisterModule("chatNotifier", ChatNotifier)
