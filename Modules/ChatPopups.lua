-- B.O.L.T Chat Popups Module
-- Whispers and party chat as small, quiet popups in a box you place with Edit Mode, like an
-- instant messenger: hard to miss, gone after a few seconds.
--
--   +--------------------------------------+
--   | Thrall                       Whisper |
--   | ready when you are                   |
--   +--------------------------------------+
--
-- Each popup is the bronze Blizzard panel the camp bar and square minimap use (a dark tooltip
-- panel where that art doesn't exist), the sender in class color and the message in the chat's
-- own color, like it would read in the chat window. More lines from the same person in a row go into the same popup. Hovering keeps a popup up,
-- left-click replies (whisper back, or opens party chat), right-click closes it.
-- In instances the sender and the text can be secret values: they are only handed to
-- FontString:SetText, never compared or cut, so those popups never merge.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode
local EDIT_KEY = "chatPopups"

local ChatPopups = {
    displayName = "Chat Popups",
}

-- Chat event suffix -> label shown in the settings and on the popup.
ChatPopups.CHANNEL_TYPES = {
    { event = "WHISPER", label = "Whisper", tag = "Whisper" },
    { event = "BN_WHISPER", label = "Battle.net Whisper", tag = "Whisper" },
    { event = "PARTY", label = "Party", tag = "Party" },
    { event = "PARTY_LEADER", label = "Party Leader", tag = "Party", chatType = "PARTY_LEADER" },
    { event = "INSTANCE_CHAT", label = "Instance", tag = "Instance" },
    { event = "INSTANCE_CHAT_LEADER", label = "Instance Leader", tag = "Instance" },
    { event = "RAID", label = "Raid", tag = "Raid" },
    { event = "RAID_LEADER", label = "Raid Leader", tag = "Raid" },
    { event = "GUILD", label = "Guild", tag = "Guild" },
}
local BY_EVENT = {}
for _, channel in ipairs(ChatPopups.CHANNEL_TYPES) do BY_EVENT[channel.event] = channel end

-- Where a left-click sends you, per chat type.
local SLASH = {
    PARTY = "/p ", PARTY_LEADER = "/p ",
    INSTANCE_CHAT = "/i ", INSTANCE_CHAT_LEADER = "/i ",
    RAID = "/ra ", RAID_LEADER = "/ra ",
    GUILD = "/g ",
}

local DEFAULT_WIDTH = 280
local DEFAULT_COUNT = 4
local DEFAULT_DURATION = 10
local FADE = 1.2 -- seconds of fade-out at the end
local GAP = 4
local PAD = 9 -- clear of the panel's border
local BOX = { atlas = "ui-hud-minimap-header-button", corner = 7, midX = 76, midY = 11 }
local MAX_LINES = 3 -- lines kept in a merged popup

local box
local toasts = {} -- shown, newest first
local pool = {}

local function IsSecret(value) return BOLT.IsSecret(value) end

local function Width() return EditMode:Get(EDIT_KEY, "width", DEFAULT_WIDTH) end
local function MaxCount() return EditMode:Get(EDIT_KEY, "count", DEFAULT_COUNT) end
local function Duration() return EditMode:Get(EDIT_KEY, "duration", DEFAULT_DURATION) end
local function GrowsUp() return EditMode:Get(EDIT_KEY, "grow", "UP") == "UP" end

function ChatPopups:IsChannelEnabled(eventSuffix)
    return BOLT:GetConfig("chatPopups", "channels")[eventSuffix] == true
end

function ChatPopups:SetChannelEnabled(eventSuffix, enabled)
    BOLT:GetConfig("chatPopups", "channels")[eventSuffix] = enabled or false
end

---------------------------------------------------------------------------
-- Chat helpers (renamed to ChatFrameUtil on newer clients)
---------------------------------------------------------------------------

local function ChatCall(oldName, utilName, ...)
    local util = ChatFrameUtil and ChatFrameUtil[utilName]
    local fn = util or _G[oldName]
    if fn then return pcall(fn, ...) end
end

local function ChatColor(chatType)
    local info = ChatTypeInfo and ChatTypeInfo[chatType]
    if info then return info.r or 1, info.g or 1, info.b or 1 end
    return 1, 0.5, 1
end

local function ClassColor(guid)
    if not guid or IsSecret(guid) or guid == "" or not GetPlayerInfoByGUID then return end
    local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
    if not ok or not class or IsSecret(class) then return end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
end

---------------------------------------------------------------------------
-- Popups
---------------------------------------------------------------------------

local Layout

local function Release(toast)
    for i, shown in ipairs(toasts) do
        if shown == toast then table.remove(toasts, i) break end
    end
    toast:Hide()
    toast.sender, toast.chatType, toast.lines = nil, nil, nil
    table.insert(pool, toast)
    Layout()
end

local function Reply(toast)
    local chatType = toast.chatType
    if chatType == "WHISPER" and toast.sender and not IsSecret(toast.sender) then
        ChatCall("ChatFrame_SendTell", "SendTell", toast.sender)
    elseif chatType == "BN_WHISPER" and toast.sender then
        ChatCall("ChatFrame_SendBNetTell", "SendBNetTell", toast.sender)
    else
        ChatCall("ChatFrame_OpenChat", "OpenChat", SLASH[chatType] or "")
    end
end

local function CreateToast()
    local toast = CreateFrame("Button", nil, box)
    toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    -- Bronze Blizzard panel (Forever), or a dark tooltip panel where that art doesn't exist.
    if not NativeArt.CreateBox(toast, BOX, true) then
        local backdrop = CreateFrame("Frame", nil, toast, "TooltipBackdropTemplate")
        backdrop:SetAllPoints()
        backdrop:SetFrameLevel(toast:GetFrameLevel())
        if backdrop.NineSlice and backdrop.NineSlice.SetCenterColor then
            backdrop.NineSlice:SetCenterColor(0.06, 0.04, 0.02, 0.92)
        end
    end

    -- The soft gold glow Blizzard puts on quest log titles.
    toast.highlight = toast:CreateTexture(nil, "HIGHLIGHT")
    toast.highlight:SetPoint("TOPLEFT", 4, -4)
    toast.highlight:SetPoint("BOTTOMRIGHT", -4, 4)
    toast.highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    toast.highlight:SetBlendMode("ADD")
    toast.highlight:SetAlpha(0.35)

    toast.name = toast:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toast.name:SetPoint("TOPLEFT", PAD, -PAD)
    toast.name:SetJustifyH("LEFT")
    toast.name:SetWordWrap(false)

    toast.tag = toast:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    toast.tag:SetPoint("TOPRIGHT", -PAD, -PAD)
    toast.tag:SetJustifyH("RIGHT")
    toast.name:SetPoint("RIGHT", toast.tag, "LEFT", -6, 0)

    toast.text = toast:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
    toast.text:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -3)
    toast.text:SetPoint("RIGHT", -PAD, 0)
    toast.text:SetJustifyH("LEFT")
    toast.text:SetJustifyV("TOP")
    toast.text:SetWordWrap(true)
    if toast.text.SetMaxLines then toast.text:SetMaxLines(4) end

    toast:SetScript("OnClick", function(self, button)
        if self.preview then return end
        if button == "LeftButton" then Reply(self) end
        Release(self)
    end)
    toast:SetScript("OnEnter", function(self) self.hovered = true self:SetAlpha(1) end)
    toast:SetScript("OnLeave", function(self)
        self.hovered = false
        -- A little extra time to read after moving away.
        self.expires = math.max(self.expires or 0, GetTime() + 2)
    end)
    return toast
end

local function SizeToast(toast)
    toast:SetWidth(Width())
    local textHeight = toast.text:GetStringHeight() or 12
    if IsSecret(textHeight) then textHeight = 12 end
    toast:SetHeight(math.floor(PAD * 2 + 14 + 3 + textHeight + 0.5))
end

Layout = function()
    if not box then return end
    box:SetWidth(Width())
    local up = GrowsUp()
    local offset = 0
    for _, toast in ipairs(toasts) do
        SizeToast(toast)
        toast:ClearAllPoints()
        if up then
            toast:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, offset)
        else
            toast:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -offset)
        end
        offset = offset + toast:GetHeight() + GAP
    end
end

-- Puts the message on a popup: the newest one when it's the same person in the same chat,
-- otherwise a new one on top.
local function Push(chatType, channel, sender, guid, message, preview)
    if not box then return end
    local newest = toasts[1]
    local canMerge = not preview and sender and not IsSecret(sender) and not IsSecret(message)
        and type(message) == "string"
    if canMerge and newest and not newest.preview and newest.chatType == chatType
        and newest.sender == sender and newest.lines then
        table.insert(newest.lines, message)
        while #newest.lines > MAX_LINES do table.remove(newest.lines, 1) end
        newest.text:SetText(table.concat(newest.lines, "\n"))
        newest.expires = GetTime() + Duration()
        newest:SetAlpha(1)
        Layout()
        return
    end

    local toast = table.remove(pool) or CreateToast()
    toast.chatType, toast.sender, toast.preview = chatType, sender, preview
    toast.lines = canMerge and { message } or nil
    toast.hovered = false

    toast.text:SetTextColor(ChatColor(chatType))

    -- Name: short (no realm) when it can be read, as given otherwise.
    local shown = sender
    if sender and not IsSecret(sender) and chatType ~= "BN_WHISPER" and Ambiguate then
        local ok, short = pcall(Ambiguate, sender, "short")
        if ok and short then shown = short end
    end
    if not pcall(toast.name.SetText, toast.name, shown or "") then toast.name:SetText("") end
    local r, g, b = ClassColor(guid)
    if r then toast.name:SetTextColor(r, g, b) else toast.name:SetTextColor(ChatColor(chatType)) end

    toast.tag:SetText(channel.tag)
    toast.tag:SetTextColor(ChatColor(chatType))
    toast.tag:SetAlpha(0.7)
    if not pcall(toast.text.SetText, toast.text, message or "") then toast.text:SetText("") end

    toast.expires = GetTime() + Duration()
    toast:SetAlpha(1)
    toast:Show()
    table.insert(toasts, 1, toast)
    while #toasts > MaxCount() do Release(toasts[#toasts]) end
    Layout()
end

local function OnUpdate()
    local now = GetTime()
    for i = #toasts, 1, -1 do
        local toast = toasts[i]
        if toast.hovered or toast.preview then
            toast:SetAlpha(1)
        else
            local left = (toast.expires or 0) - now
            if left <= 0 then
                Release(toast)
            elseif left < FADE then
                toast:SetAlpha(left / FADE)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Box and Edit Mode
---------------------------------------------------------------------------

local function Place()
    if not box then return end
    local point, x, y = EditMode:GetPosition(EDIT_KEY)
    box:ClearAllPoints()
    box:SetPoint(point, UIParent, point, x, y)
    -- The box is the space the popups can take, so Edit Mode shows where they will go.
    box:SetSize(Width(), MaxCount() * 52)
    Layout()
end

local function ClearPreview()
    for i = #toasts, 1, -1 do
        if toasts[i].preview then Release(toasts[i]) end
    end
end

local function ShowPreview()
    ClearPreview()
    Push("PARTY", BY_EVENT.PARTY, "Jaina", nil, "pull after this drink", true)
    Push("WHISPER", BY_EVENT.WHISPER, "Thrall", nil, "hey, want to run Deadmines?", true)
end

local function Build()
    box = CreateFrame("Frame", "BOLTChatPopups", UIParent)
    box:SetClampedToScreen(true)
    box:SetFrameStrata("MEDIUM")
    box:SetScript("OnUpdate", OnUpdate)
    Place()

    if not EditMode.available then return end
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "Chat Popups",
        frame = box,
        default = { point = "BOTTOMLEFT", x = 40, y = 330 },
        onEnter = ShowPreview,
        onExit = ClearPreview,
        apply = Place,
        settings = {
            EditMode:Dropdown("Grow", nil, {
                { text = "Up", value = "UP" },
                { text = "Down", value = "DOWN" },
            }, {
                default = "UP",
                get = function() return EditMode:Get(EDIT_KEY, "grow", "UP") end,
                set = function(value) EditMode:Set(EDIT_KEY, "grow", value) Layout() end,
            }),
            EditMode:Slider("Shown at once", nil, {
                min = 1, max = 8, step = 1, default = DEFAULT_COUNT,
                get = MaxCount,
                set = function(value) EditMode:Set(EDIT_KEY, "count", value) Place() end,
            }),
            EditMode:Slider("Seconds on screen", nil, {
                min = 3, max = 60, step = 1, default = DEFAULT_DURATION,
                get = Duration,
                set = function(value) EditMode:Set(EDIT_KEY, "duration", value) end,
            }),
            EditMode:Slider("Width", nil, {
                min = 180, max = 460, step = 10, default = DEFAULT_WIDTH,
                get = Width,
                set = function(value) EditMode:Set(EDIT_KEY, "width", value) Place() end,
            }),
        },
    })
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

-- Your own lines. By name or GUID when the game lets us read them; in instances both can be
-- secret, so a line in a chat you just sent to also counts as yours.
local SENT_WINDOW = 2 -- seconds between sending and the echo arriving
local lastSent = {} -- [chat type] = GetTime() of your last message there

local function OnSend(_, chatType)
    if type(chatType) == "string" and not IsSecret(chatType) then
        lastSent[chatType:upper()] = GetTime()
    end
end

local function IsMine(suffix, sender, guid)
    if BOLT:IsPlayerName(sender) then return true end
    if guid and not IsSecret(guid) and guid == UnitGUID("player") then return true end
    if not IsSecret(sender) and not IsSecret(guid) then return false end
    local now = GetTime()
    for chatType, sentAt in pairs(lastSent) do
        -- PARTY covers PARTY_LEADER, INSTANCE_CHAT covers INSTANCE_CHAT_LEADER, and so on.
        if now - sentAt < SENT_WINDOW and suffix:sub(1, #chatType) == chatType then return true end
    end
    return false
end

function ChatPopups:OnChatEvent(event, message, sender, ...)
    local suffix = event:sub(10) -- strip "CHAT_MSG_"
    local channel = BY_EVENT[suffix]
    if not channel or not self:IsChannelEnabled(suffix) then return end
    local guid = select(10, ...) -- arg12
    if IsMine(suffix, sender, guid) then return end
    -- Battle.net whispers: arg13 is the presence ID used to reply; the name arg2 works too.
    Push(suffix, channel, sender, guid, message)
end

function ChatPopups:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnChatEvent(event, ...)
    end)
    -- After-the-fact hooks: they only note the chat type, nothing about the send changes.
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        hooksecurefunc(C_ChatInfo, "SendChatMessage", OnSend)
    end
    if SendChatMessage and SendChatMessage ~= (C_ChatInfo and C_ChatInfo.SendChatMessage) then
        hooksecurefunc("SendChatMessage", OnSend)
    end
end

function ChatPopups:OnEnable()
    if not box then Build() end
    box:Show()
    for _, channel in ipairs(self.CHANNEL_TYPES) do
        self.eventFrame:RegisterEvent("CHAT_MSG_" .. channel.event)
    end
    if EditMode:IsActive() then ShowPreview() end
end

function ChatPopups:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    for i = #toasts, 1, -1 do Release(toasts[i]) end
    if box then box:Hide() end
end

BOLT:RegisterModule("chatPopups", ChatPopups)
