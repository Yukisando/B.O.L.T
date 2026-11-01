-- B.O.L.T Key Share Module
-- Answers "!keys" in party, raid or guild chat with your Mythic+ keystone link,
-- and optionally picks a random key from everyone's answers ("roulette").

local ADDON_NAME, BOLT = ...

local KeyShare = {
    displayName = "Key Share",
}

local KEYSTONE_ITEM_ID = 180653
local RESPONSE_THROTTLE = 5
local ROULETTE_WINDOW = 2

-- Chat event suffix -> channel to answer in
local RESPOND_CHANNELS = {
    PARTY = "PARTY",
    PARTY_LEADER = "PARTY",
    RAID = "RAID",
    RAID_LEADER = "RAID",
    GUILD = "GUILD",
}

local lastResponse = 0
local roulette -- { keys = {}, channel = "PARTY" } while collecting

function KeyShare:IsSupported()
    -- WoW: Forever has no Mythic+.
    return not BOLT.isForever
end

local function ExtractKeystoneLink(message)
    return message:match("(|c%x+|Hkeystone:[^|]+|h%[[^%]]+%]|h|r)")
        or message:match("(|Hkeystone:[^|]+|h%[[^%]]+%]|h)")
end

local function FindKeystoneInBags()
    for bag = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if link and (link:find("|Hkeystone:", 1, true) or C_Container.GetContainerItemID(bag, slot) == KEYSTONE_ITEM_ID) then
                return link
            end
        end
    end
    return nil
end

-- Fallback when the bag link isn't cached yet: rebuild the link from keystone info.
local function BuildKeystoneLink()
    local mapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel()
    if not mapID or not level or level <= 0 then return nil end

    local mapName = C_ChallengeMode.GetMapUIInfo(mapID) or "Mythic Keystone"
    local affixes = { 0, 0, 0, 0 }
    for index, affix in ipairs(C_MythicPlus.GetCurrentAffixes() or {}) do
        if index > 4 then break end
        affixes[index] = affix.id or 0
    end
    return ("|cffa335ee|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[Keystone: %s (%d)]|h|r"):format(
        KEYSTONE_ITEM_ID, mapID, level, affixes[1], affixes[2], affixes[3], affixes[4], mapName, level)
end

function KeyShare:GetKeystoneLink()
    return FindKeystoneInBags() or BuildKeystoneLink()
end

function KeyShare:StartRoulette(channel)
    if roulette or not BOLT:GetConfig("keyShare", "rouletteEnabled") then return end
    roulette = { keys = {}, channel = channel }
    C_Timer.After(ROULETTE_WINDOW, function()
        local current = roulette
        roulette = nil
        if current and #current.keys > 0 then
            BOLT:SendChat("Roulette picks: " .. current.keys[math.random(#current.keys)], current.channel)
        end
    end)
end

function KeyShare:OnChatMessage(event, message)
    if BOLT.IsSecret(message) or type(message) ~= "string" then return end

    if roulette then
        local link = ExtractKeystoneLink(message)
        if link then
            table.insert(roulette.keys, link)
        end
    end

    if strtrim(message):lower() ~= "!keys" then return end
    local channel = RESPOND_CHANNELS[event:sub(10)] -- strip "CHAT_MSG_"
    if not channel then return end

    local now = GetTime()
    if now - lastResponse < RESPONSE_THROTTLE then return end
    lastResponse = now

    -- Open the roulette window first so our own answer's echo is collected too.
    self:StartRoulette(channel)
    BOLT:SendChat(self:GetKeystoneLink() or "I don't have a keystone :)", channel)
end

function KeyShare:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, message)
        self:OnChatMessage(event, message)
    end)
end

function KeyShare:OnEnable()
    for suffix in pairs(RESPOND_CHANNELS) do
        self.eventFrame:RegisterEvent("CHAT_MSG_" .. suffix)
    end
end

function KeyShare:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    roulette = nil
end

BOLT:RegisterModule("keyShare", KeyShare)
