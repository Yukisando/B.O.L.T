-- B.O.L.T Auto Party Chat Module
-- Points the chat box at your group's channel when you join a group, and back to Say when you leave.
--
-- Joining a group switches the box whatever it was on: you often whisper someone or post in a
-- channel to get that invite, and the box would otherwise stay on that whisper or channel.
-- Leaving only puts Say back if the box was still on a group channel.

local ADDON_NAME, BOLT = ...

local AutoPartyChat = {
    displayName = "Auto Party Chat",
}

local GROUP_TYPES = {
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

-- Should a box on `current` follow the group change from `old` to `new`?
local function ShouldSwitch(current, old, new)
    if old == "SAY" and new ~= "SAY" then
        return true -- just joined
    end
    -- Leaving, party <-> raid, or a login/reload: only a box that was on Say or a group channel.
    return current == nil or current == "SAY" or GROUP_TYPES[current] == true
end

local function UpdateHeader(editBox)
    if editBox.UpdateHeader then
        editBox:UpdateHeader()
    elseif ChatEdit_UpdateHeader then
        ChatEdit_UpdateHeader(editBox)
    end
end

local function SwitchEditBox(editBox, old, new)
    -- stickyType is what the box goes back to each time it opens.
    local current = editBox:GetAttribute("stickyType") or editBox:GetAttribute("chatType")
    if current == new or not ShouldSwitch(current, old, new) then return end
    editBox:SetAttribute("stickyType", new)
    local text = editBox:GetText()
    if editBox:IsShown() and text and text ~= "" then
        -- Mid-message: leave what's being typed where it was going; the next one goes to the group.
        return
    end
    editBox:SetAttribute("chatType", new)
    if editBox:IsShown() then
        UpdateHeader(editBox)
    end
end

function AutoPartyChat:Update()
    self.pending = false
    local new = GroupChatType()
    local old = self.lastChatType
    if new == old then return end
    self.lastChatType = new
    for i = 1, NUM_CHAT_WINDOWS do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox then
            SwitchEditBox(editBox, old, new)
        end
    end
end

-- Group events come in bursts, and IsInGroup can lag the first one: check on the next frame.
function AutoPartyChat:QueueUpdate()
    if self.pending then return end
    self.pending = true
    C_Timer.After(0, function()
        if self.active then
            self:Update()
        else
            self.pending = false
        end
    end)
end

function AutoPartyChat:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function() self:QueueUpdate() end)
end

function AutoPartyChat:OnEnable()
    -- Covers logging in or reloading while already in a group.
    self.lastChatType = nil
    self:QueueUpdate()
    self.eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventFrame:RegisterEvent("GROUP_JOINED")
    self.eventFrame:RegisterEvent("GROUP_LEFT")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function AutoPartyChat:OnDisable()
    self.eventFrame:UnregisterAllEvents()
end

BOLT:RegisterModule("autoPartyChat", AutoPartyChat)
