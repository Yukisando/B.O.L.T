-- B.O.L.T KeyShare Module
-- Responds to "!keys" in chat by linking the player's current Mythic+ keystone
-- in the same channel the message was received on.

local ADDON_NAME, BOLT = ...

local KeyShare = {}
local KEYSTONE_ITEM_IDS = {
    [138019] = true,
    [151086] = true,
    [158923] = true,
    [180653] = true,
    [187786] = true,
}

-- Chat events we listen on, and the matching SendChatMessage type / channel arg.
-- Format: { event suffix, send type, channelArg }
-- channelArg is a function(args) that returns the channel argument for SendChatMessage.
local RESPOND_CHANNELS = {
    { suffix = "PARTY",        sendType = "PARTY" },
    { suffix = "PARTY_LEADER", sendType = "PARTY" },
    { suffix = "RAID",         sendType = "RAID" },
    { suffix = "RAID_LEADER",  sendType = "RAID" },
    { suffix = "GUILD",        sendType = "GUILD" },
}

-- Build a lookup: suffix → row
local suffixMap = {}
for _, row in ipairs(RESPOND_CHANNELS) do
    suffixMap[row.suffix] = row
end

function KeyShare:OnInitialize() end

function KeyShare:OnEnable()
    self:RegisterEvents()
end

function KeyShare:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
end

function KeyShare:IsKeystoneLink(link)
    if type(link) ~= "string" then
        return false
    end

    if link:find("|Hkeystone:", 1, true) then
        return true
    end

    local itemID = tonumber(link:match("|Hitem:(%d+):"))
    return itemID ~= nil and KEYSTONE_ITEM_IDS[itemID] == true
end

function KeyShare:FindKeystoneLinkInBags()
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local link = C_Container.GetContainerItemLink(bag, slot)
            if self:IsKeystoneLink(link) then
                return link
            end

            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and self:IsKeystoneLink(info.hyperlink) then
                return info.hyperlink
            end
        end
    end

    return nil
end

function KeyShare:BuildOwnedKeystoneLink()
    if not C_MythicPlus then
        return nil
    end

    local challengeMapID = C_MythicPlus.GetOwnedKeystoneChallengeMapID and C_MythicPlus.GetOwnedKeystoneChallengeMapID()
    local level = C_MythicPlus.GetOwnedKeystoneLevel and C_MythicPlus.GetOwnedKeystoneLevel()
    if not challengeMapID or not level or level <= 0 then
        return nil
    end

    local mapName = nil
    if C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        mapName = C_ChallengeMode.GetMapUIInfo(challengeMapID)
    end
    if not mapName or mapName == "" then
        mapName = "Mythic Keystone"
    end

    local affixIDs = { 0, 0, 0, 0 }
    if C_MythicPlus.GetCurrentAffixes then
        local currentAffixes = C_MythicPlus.GetCurrentAffixes()
        if type(currentAffixes) == "table" then
            for index = 1, math.min(#currentAffixes, 4) do
                affixIDs[index] = currentAffixes[index].id or 0
            end
        end
    end

    return string.format(
        "|cffa335ee|Hkeystone:%d:%d:%d:%d:%d:%d:%d|h[Keystone: %s (%d)]|h|r",
        180653,
        challengeMapID,
        level,
        affixIDs[1],
        affixIDs[2],
        affixIDs[3],
        affixIDs[4],
        mapName,
        level
    )
end

function KeyShare:GetCurrentKeystoneLink()
    return self:FindKeystoneLinkInBags() or self:BuildOwnedKeystoneLink()
end

function KeyShare:ShouldRespondToMessage(message, sender)
    if issecretvalue and (issecretvalue(message) or issecretvalue(sender)) then
        return false
    end

    if type(message) ~= "string" then
        return false
    end

    return strtrim(string.lower(message)) == "!keys"
end

function KeyShare:SendChat(text, chatType)
    if not C_ChatInfo or not C_ChatInfo.SendChatMessage then
        return false
    end

    return pcall(C_ChatInfo.SendChatMessage, text, chatType)
end

function KeyShare:RegisterEvents()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end
    local f = self.eventFrame
    f:UnregisterAllEvents()

    for _, row in ipairs(RESPOND_CHANNELS) do
        f:RegisterEvent("CHAT_MSG_" .. row.suffix)
    end

    f:SetScript("OnEvent", function(_, event, ...)
        local message, sender = ...
        if not self:ShouldRespondToMessage(message, sender) then return end

        local suffix = event:match("^CHAT_MSG_(.+)$")
        if not suffix then return end

        local row = suffixMap[suffix]
        if not row then return end

        local link = self:GetCurrentKeystoneLink()
        local text = link or "I don't have a keystone :)"

        -- Throttle responses: no more than once every 5 seconds
        local now = GetTime()
        if self._lastRespond and (now - self._lastRespond) < 5 then return end
        self._lastRespond = now

        self:SendChat(text, row.sendType)
    end)
end

BOLT:RegisterModule("keyShare", KeyShare)
