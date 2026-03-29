-- B.O.L.T KeyShare Module
-- Responds to "!keys" in chat by linking the player's current Mythic+ keystone
-- in the same channel the message was received on.

local ADDON_NAME, BOLT = ...

local KeyShare = {}

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

function KeyShare:GetCurrentKeystoneLink()
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID then
                    -- GetItemInfoInstant is synchronous and available in Midnight (12.0+)
                    -- returns: itemID, name, quality, isBound, lore, itemType, itemSubType, maxStack, equipSlot, texture, vendorPrice, classID, subclassID
                    local classID, subclassID = select(12, C_Item.GetItemInfoInstant(info.itemID))
                    -- classID 0 = Consumable, subclassID 6 = Keystone
                    if classID == 0 and subclassID == 6 then
                        return info.hyperlink
                    end
                end
            end
        end
    end
    return nil
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

    f:SetScript("OnEvent", function(_, event, msg, sender)
        -- Only react to exactly "!keys" (case-insensitive, trimmed)
        if not msg or msg:lower():match("^%s*!keys%s*$") == nil then return end

        -- Don't respond to our own messages
        local playerName = UnitName("player")
        if sender and playerName and sender:find(playerName, 1, true) then return end

        local suffix = event:match("^CHAT_MSG_(.+)$")
        if not suffix then return end

        local row = suffixMap[suffix]
        if not row then return end

        local link = self:GetCurrentKeystoneLink()
        local text = link or "I don't have a keystone."

        -- Throttle responses: no more than once every 5 seconds
        local now = GetTime()
        if self._lastRespond and (now - self._lastRespond) < 5 then return end
        self._lastRespond = now

        SendChatMessage(text, row.sendType)
    end)
end

BOLT:RegisterModule("keyShare", KeyShare)
