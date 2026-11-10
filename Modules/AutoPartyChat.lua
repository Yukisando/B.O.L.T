-- B.O.L.T Auto Party Chat Module
-- Points the chat box at your group's channel when you join a group, and back to Say when you leave.

local ADDON_NAME, BOLT = ...

local AutoPartyChat = {
    displayName = "Auto Party Chat",
}

-- Channels this module may replace; anything else (guild, whisper, a custom channel)
-- was picked by the player and stays as it is.
local REPLACEABLE = {
    SAY = true,
    PARTY = true,
    RAID = true,
    INSTANCE_CHAT = true,
}

local function GroupChatType()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return "SAY"
end

local function SetEditBoxChatType(editBox, chatType)
    if not REPLACEABLE[editBox:GetAttribute("chatType")] then return end
    editBox:SetAttribute("chatType", chatType)
    -- stickyType is what the box returns to each time it opens.
    editBox:SetAttribute("stickyType", chatType)
    if editBox:IsShown() then
        if editBox.UpdateHeader then
            editBox:UpdateHeader()
        elseif ChatEdit_UpdateHeader then
            ChatEdit_UpdateHeader(editBox)
        end
    end
end

function AutoPartyChat:Update()
    local chatType = GroupChatType()
    if chatType == self.lastChatType then return end
    self.lastChatType = chatType
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            SetEditBoxChatType(editBox, chatType)
        end
    end
end

function AutoPartyChat:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function() self:Update() end)
end

function AutoPartyChat:OnEnable()
    -- Covers logging in or reloading while already in a group.
    self.lastChatType = nil
    self:Update()
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
end

function AutoPartyChat:OnDisable()
    self.eventFrame:UnregisterAllEvents()
end

BOLT:RegisterModule("autoPartyChat", AutoPartyChat)
