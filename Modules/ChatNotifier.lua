-- B.O.L.T Chat Notifier Module
-- Plays a notification sound when a new message appears in monitored chat channels

local ADDON_NAME, BOLT = ...

local ChatNotifier = {}

-- Channel event mapping: chat event suffix -> display name
local CHANNEL_TYPES = {
    { event = "CHANNEL",           label = "Custom Channels" },
    { event = "GUILD",             label = "Guild" },
    { event = "OFFICER",           label = "Officer" },
    { event = "PARTY",             label = "Party" },
    { event = "PARTY_LEADER",      label = "Party Leader" },
    { event = "RAID",              label = "Raid" },
    { event = "RAID_LEADER",       label = "Raid Leader" },
    { event = "RAID_WARNING",      label = "Raid Warning" },
    { event = "INSTANCE_CHAT",     label = "Instance" },
    { event = "INSTANCE_CHAT_LEADER", label = "Instance Leader" },
    { event = "SAY",               label = "Say" },
    { event = "YELL",              label = "Yell" },
    { event = "WHISPER",           label = "Whisper" },
    { event = "BN_WHISPER",        label = "Battle.net Whisper" },
    { event = "EMOTE",             label = "Emote" },
}

-- Available sound options
local SOUND_OPTIONS = {
    { label = "Raid Warning",    soundID = 8959 },
    { label = "Auction Open",    soundID = 5274 },
    { label = "Map Ping",        soundID = 3175 },
    { label = "Loot Coin",       soundID = 120 },
    { label = "GM Chat",         soundID = 9637 },
    { label = "Alarm Clock 3",   soundID = 7355 },
    { label = "Jeweler Craft",   soundID = 3337 },
    { label = "Bell Toll",       soundID = 6674 },
    { label = "PVP Warning",     soundID = 8332 },
    { label = "Store Purchase",  soundID = 39517 },
    { label = "Put ring down",  soundID = 1210 },
    { label = "Put ring wood",  soundID = 1217 },
}

local THROTTLE_SECONDS = 1
local lastPlayTime = 0

function ChatNotifier:OnInitialize() end

function ChatNotifier:OnEnable()
    self:RegisterChatEvents()
end

function ChatNotifier:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
end

function ChatNotifier:GetMonitoredChannels()
    local cfg = self.parent:GetConfig("chatNotifier") or {}
    return cfg.channels or {}
end

function ChatNotifier:SetChannelEnabled(eventSuffix, enabled)
    local cfg = self.parent:GetConfig("chatNotifier") or {}
    local channels = cfg.channels or {}
    channels[eventSuffix] = enabled or nil
    self.parent:SetConfig(channels, "chatNotifier", "channels")
end

function ChatNotifier:IsChannelEnabled(eventSuffix)
    local channels = self:GetMonitoredChannels()
    return channels[eventSuffix] == true
end

function ChatNotifier:GetSoundID()
    local cfg = self.parent:GetConfig("chatNotifier") or {}
    return cfg.soundID or SOUND_OPTIONS[1].soundID
end

function ChatNotifier:SetSoundID(soundID)
    self.parent:SetConfig(soundID, "chatNotifier", "soundID")
end

function ChatNotifier:RegisterChatEvents()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end

    local f = self.eventFrame or CreateFrame("Frame")
    self.eventFrame = f

    for _, ch in ipairs(CHANNEL_TYPES) do
        f:RegisterEvent("CHAT_MSG_" .. ch.event)
    end

    f:SetScript("OnEvent", function(_, event, msg, sender, ...)
        local suffix = event:match("^CHAT_MSG_(.+)$")
        if not suffix then return end
        if not self:IsChannelEnabled(suffix) then return end

        -- Don't notify for own messages
        local playerName = UnitName("player")
        if sender and sender:find(playerName) then return end

        -- Throttle so rapid messages don't spam sounds
        local now = GetTime()
        if (now - lastPlayTime) < THROTTLE_SECONDS then return end
        lastPlayTime = now

        PlaySound(self:GetSoundID(), "Master")
    end)
end

-- Expose constants for Config UI
ChatNotifier.CHANNEL_TYPES = CHANNEL_TYPES
ChatNotifier.SOUND_OPTIONS = SOUND_OPTIONS

BOLT:RegisterModule("chatNotifier", ChatNotifier)
