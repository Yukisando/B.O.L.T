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
-- own color, like it would read in the chat window. More lines from the same person in a row go
-- into the same popup. Popups are click-through by default (setting). Otherwise hovering keeps a
-- popup up, left-click replies in that chat (whisper back, or opens party chat) and right-click
-- whispers the sender of a group message (a whisper popup just closes).
-- In instances the sender and the text can be secret values: they are only handed to
-- FontString:SetText, never compared or cut, so those popups never merge.
--
-- Info popups share the box: a thin one-line strip (icon, coloured edge, text) for skill ups,
-- your pet learning an ability, level ups, money, reputation, experience and new spells. Each
-- kind is its own setting. Money and experience add up into one strip while it is on screen,
-- skill ups and reputation per skill or faction. They are always click-through.
--
--   |# Bows 138 (+1)                      |

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

local INFO_HEIGHT = 22
local INFO_ICON = 16

local box
local toasts = {} -- shown, newest first
local pool = {}
local infoPool = {}

-- Info popup kinds, in the order the settings list them.
ChatPopups.INFO_TYPES = {
    { key = "skill", label = "Skill ups" },
    { key = "pet", label = "Your pet learns an ability" },
    { key = "level", label = "Level up" },
    { key = "money", label = "Money gained or spent" },
    { key = "rep", label = "Reputation" },
    { key = "xp", label = "Experience" },
    { key = "spell", label = "New spells" },
}

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

function ChatPopups:IsInfoEnabled(key)
    local info = BOLT:GetConfig("chatPopups", "info")
    return type(info) == "table" and info[key] == true
end

function ChatPopups:SetInfoEnabled(key, enabled)
    local info = BOLT:GetConfig("chatPopups", "info")
    if type(info) ~= "table" then
        info = {}
        BOLT:SetConfig(info, "chatPopups", "info")
    end
    info[key] = enabled or false
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
    if toast.isInfo then
        toast.infoKey, toast.data = nil, nil
        table.insert(infoPool, toast)
    else
        table.insert(pool, toast)
    end
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

    -- Left: answer in that chat. Right: whisper the sender of a group message (a whisper
    -- popup just closes, since left-click already whispers back).
    toast:SetScript("OnClick", function(self, button)
        if self.preview then return end
        if button == "LeftButton" then
            Reply(self)
        elseif self.chatType ~= "WHISPER" and self.chatType ~= "BN_WHISPER"
            and self.sender and not IsSecret(self.sender) then
            ChatCall("ChatFrame_SendTell", "SendTell", self.sender)
        end
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
    if toast.isInfo then
        toast:SetHeight(INFO_HEIGHT)
        return
    end
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
    toast:EnableMouse(not BOLT:GetConfig("chatPopups", "clickThrough"))
    toast:Show()
    table.insert(toasts, 1, toast)
    while #toasts > MaxCount() do Release(toasts[#toasts]) end
    Layout()
end

---------------------------------------------------------------------------
-- Info popups: thin strips, one line each
---------------------------------------------------------------------------

local function CreateInfoToast()
    local toast = CreateFrame("Frame", nil, box)
    toast.isInfo = true
    toast:EnableMouse(false)

    -- Dark on the left, fading out to the right, so it reads as a strip rather than a panel.
    local bg = toast:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    local ok = CreateColor and pcall(bg.SetGradient, bg, "HORIZONTAL",
        CreateColor(0, 0, 0, 0.8), CreateColor(0, 0, 0, 0.15))
    if not ok then bg:SetColorTexture(0, 0, 0, 0.6) end

    toast.edge = toast:CreateTexture(nil, "ARTWORK")
    toast.edge:SetPoint("TOPLEFT")
    toast.edge:SetPoint("BOTTOMLEFT")
    toast.edge:SetWidth(2)
    toast.edge:SetColorTexture(1, 1, 1, 1)

    toast.icon = toast:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(INFO_ICON, INFO_ICON)
    toast.icon:SetPoint("LEFT", 7, 0)
    toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    toast.text = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    toast.text:SetPoint("LEFT", toast.icon, "RIGHT", 6, 0)
    toast.text:SetPoint("RIGHT", -6, 0)
    toast.text:SetJustifyH("LEFT")
    toast.text:SetWordWrap(false)
    return toast
end

local function FindInfo(key)
    if not key then return end
    for _, toast in ipairs(toasts) do
        if toast.infoKey == key then return toast end
    end
end

-- Shows (or updates, when `key` is already on screen) a one-line info popup.
-- `data` stays on the popup so callers can add up amounts while it is shown.
local function PushInfo(key, color, icon, text, data, preview)
    if not box then return end
    local toast = FindInfo(key)
    if not toast then
        toast = table.remove(infoPool) or CreateInfoToast()
        toast.infoKey, toast.preview = key, preview
        toast:Show()
        table.insert(toasts, 1, toast)
        while #toasts > MaxCount() do Release(toasts[#toasts]) end
    end
    toast.data = data
    toast.edge:SetVertexColor(color[1], color[2], color[3])
    toast.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    toast.text:SetText(text)
    toast.expires = GetTime() + Duration()
    toast:SetAlpha(1)
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

local ShowInfoPreview

local function ShowPreview()
    ClearPreview()
    Push("PARTY", BY_EVENT.PARTY, "Jaina", nil, "pull after this drink", true)
    Push("WHISPER", BY_EVENT.WHISPER, "Thrall", nil, "hey, want to run Deadmines?", true)
    ShowInfoPreview()
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
-- Info events
---------------------------------------------------------------------------

local COLORS = {
    skill = { 0.35, 0.65, 1 },
    pet = { 0.45, 0.85, 0.3 },
    level = { 1, 0.82, 0 },
    money = { 1, 0.82, 0 },
    repUp = { 0.3, 0.85, 0.4 },
    repDown = { 0.9, 0.3, 0.25 },
    xp = { 0.65, 0.45, 1 },
    spell = { 1, 0.9, 0.6 },
}
local ICONS = {
    skill = "Interface\\Icons\\INV_Misc_Book_09",
    level = "Interface\\Icons\\Spell_Holy_DivineSpirit",
    money = "Interface\\Icons\\INV_Misc_Coin_01",
    rep = "Interface\\Icons\\INV_Scroll_03",
    xp = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
}
local GREEN, RED, GREY = "|cff40ff40", "|cffff5040", "|cffa0a0a0"

local function Number(value)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return tostring(value)
end

local function Coins(copper)
    if GetMoneyString then return GetMoneyString(copper, true) end
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper)
    end
    return GetCoinTextureString and GetCoinTextureString(copper) or tostring(copper)
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local function SpellIcon(spell)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spell) end
    return GetSpellTexture and GetSpellTexture(spell) or nil
end

-- "Claw (Rank 2)" when the spell has a rank, else just its name.
local function SpellLabel(id)
    local name = SpellName(id)
    if not name then return end
    local rank = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id)
    if type(rank) == "string" and rank ~= "" then return ("%s (%s)"):format(name, rank) end
    return name
end

-- Lua pattern from a Blizzard format string ("Your skill in %s has increased to %d.").
local function PatternFrom(format)
    if type(format) ~= "string" then return end
    local pattern = format:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    pattern = pattern:gsub("[%(%)%.%+%-%*%?%[%]%^%$%%]", "%%%0")
    pattern = pattern:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    return "^" .. pattern .. "$"
end

local SKILL_PATTERN = PatternFrom(SKILL_RANK_UP)
local REP_UP = PatternFrom(FACTION_STANDING_INCREASED)
local REP_DOWN = PatternFrom(FACTION_STANDING_DECREASED)
local PET_LEARN = { PatternFrom(ERR_PET_LEARN_ABILITY_S), PatternFrom(ERR_PET_LEARN_SPELL_S) }

local function Readable(message)
    return type(message) == "string" and not IsSecret(message)
end

-- Skill ups: "Bows 138 (+1)", adding up per skill while the popup is shown.
local function OnSkill(message)
    if not (SKILL_PATTERN and Readable(message)) then return end
    local skill, rank = message:match(SKILL_PATTERN)
    rank = tonumber(rank)
    if not (skill and rank) then return end
    local key = "skill:" .. skill
    local shown = FindInfo(key)
    local gained = (shown and shown.data or 0) + 1
    PushInfo(key, COLORS.skill, SpellIcon(skill) or ICONS.skill,
        ("%s %d %s(+%d)|r"):format(skill, rank, GREEN, gained), gained)
end

-- Reputation: "+25 Stormwind", adding up per faction.
local function OnFaction(message)
    if not Readable(message) then return end
    local faction, amount, sign
    if REP_UP then
        faction, amount = message:match(REP_UP)
        sign = 1
    end
    if not faction and REP_DOWN then
        faction, amount = message:match(REP_DOWN)
        sign = -1
    end
    amount = tonumber(amount)
    if not (faction and amount) then return end
    local key = "rep:" .. faction
    local shown = FindInfo(key)
    local total = (shown and shown.data or 0) + sign * amount
    local up = total >= 0
    PushInfo(key, up and COLORS.repUp or COLORS.repDown, ICONS.rep,
        ("%s%s%s|r %s"):format(up and GREEN or RED, up and "+" or "-", Number(math.abs(total)), faction), total)
end

-- Pet abilities: what's new in the pet's spellbook since we last looked at the same pet.
-- The system message ("Your pet has learned ...") is a backup for clients where the pet
-- spellbook can't be read; a name shown in the last few seconds isn't shown twice.
local petSpells = {} -- [pet GUID] = { [spellID] = true }
local petShown = {}  -- [label] = GetTime()

local function ShowPetLearned(label, icon)
    local now = GetTime()
    if petShown[label] and now - petShown[label] < 10 then return end
    petShown[label] = now
    PushInfo("pet:" .. label, COLORS.pet, icon, ("Your pet learned %s%s|r"):format(GREEN, label))
end

local function ReadPetSpells()
    local set, count = {}, 0
    local bank = Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemInfo and bank then
        for i = 1, C_SpellBook.HasPetSpells() or 0 do
            local info = C_SpellBook.GetSpellBookItemInfo(i, bank)
            local id = info and (info.spellID or info.actionID)
            if id and not IsSecret(id) then
                set[id] = true
                count = count + 1
            end
        end
    elseif HasPetSpells and GetSpellBookItemInfo then
        for i = 1, HasPetSpells() or 0 do
            local _, id = GetSpellBookItemInfo(i, BOOKTYPE_PET or "pet")
            if id then
                set[id] = true
                count = count + 1
            end
        end
    end
    return set, count
end

local petCheckQueued = false

local function CheckPetSpells()
    petCheckQueued = false
    local guid = UnitGUID("pet")
    if not guid or IsSecret(guid) then return end
    local ok, set, count = pcall(ReadPetSpells)
    if not ok or count == 0 then return end -- just summoned: the spellbook fills a moment later
    local known = petSpells[guid]
    petSpells[guid] = set
    if not known or not ChatPopups:IsInfoEnabled("pet") then return end
    for id in pairs(set) do
        if not known[id] then
            local label = SpellLabel(id)
            if label then ShowPetLearned(label, SpellIcon(id)) end
        end
    end
end

local function QueuePetCheck()
    if petCheckQueued then return end
    petCheckQueued = true
    C_Timer.After(0.3, CheckPetSpells)
end

local function OnSystem(message)
    if not Readable(message) then return end
    for _, pattern in ipairs(PET_LEARN) do
        local spell = message:match(pattern)
        if spell then
            ShowPetLearned(spell, SpellIcon(spell))
            return
        end
    end
end

-- Money and experience: differences since the last update, adding up while shown.
local lastMoney, lastXP, lastXPMax, lastLevel

local function SnapshotPlayer()
    lastMoney = GetMoney()
    lastXP, lastXPMax, lastLevel = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
end

local function OnMoney()
    local money = GetMoney()
    local delta = lastMoney and money - lastMoney or 0
    lastMoney = money
    if delta == 0 or not ChatPopups:IsInfoEnabled("money") then return end
    local shown = FindInfo("money")
    local total = (shown and shown.data or 0) + delta
    local text
    if total >= 0 then
        text = GREEN .. "+|r " .. Coins(total)
    else
        text = RED .. "-|r " .. Coins(-total)
    end
    PushInfo("money", COLORS.money, ICONS.money, text, total)
end

local function OnXP()
    local xp, max, level = UnitXP("player"), UnitXPMax("player"), UnitLevel("player")
    if IsSecret(xp) or IsSecret(max) then return end
    local delta
    if lastLevel and lastXP and level > lastLevel then
        delta = (lastXPMax or 0) - lastXP + xp -- crossed into a new level
    else
        delta = xp - (lastXP or xp)
    end
    lastXP, lastXPMax, lastLevel = xp, max, level
    if delta <= 0 or not ChatPopups:IsInfoEnabled("xp") then return end
    local shown = FindInfo("xp")
    local total = (shown and shown.data or 0) + delta
    local percent = max > 0 and math.floor(xp / max * 100) or 0
    PushInfo("xp", COLORS.xp, ICONS.xp,
        ("+%s XP %s(%d%% of level %d)|r"):format(Number(total), GREY, percent, level), total)
end

local function OnLevelUp(level)
    if not ChatPopups:IsInfoEnabled("level") then return end
    PushInfo("level", COLORS.level, ICONS.level, ("|cffffd100Level %s reached!|r"):format(tostring(level)))
end

local function OnSpellLearned(spellID)
    if not spellID or IsSecret(spellID) or not ChatPopups:IsInfoEnabled("spell") then return end
    local label = SpellLabel(spellID)
    if not label then return end
    PushInfo("spell:" .. spellID, COLORS.spell, SpellIcon(spellID), "New spell: |cffffffff" .. label .. "|r")
end

function ChatPopups:OnInfoEvent(event, ...)
    if event == "PLAYER_MONEY" then
        OnMoney()
    elseif event == "PLAYER_XP_UPDATE" then
        OnXP()
    elseif event == "PLAYER_LEVEL_UP" then
        OnLevelUp(...)
    elseif event == "CHAT_MSG_SKILL" then
        if self:IsInfoEnabled("skill") then OnSkill(...) end
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        if self:IsInfoEnabled("rep") then OnFaction(...) end
    elseif event == "CHAT_MSG_SYSTEM" then
        if self:IsInfoEnabled("pet") then OnSystem(...) end
    elseif event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
        OnSpellLearned(...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        SnapshotPlayer()
        QueuePetCheck()
    else -- the pet or its spellbook may have changed
        QueuePetCheck()
    end
end

local INFO_EVENTS = {
    "PLAYER_MONEY", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD",
    "CHAT_MSG_SKILL", "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_SYSTEM",
    "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE",
    "PET_BAR_UPDATE", "SPELLS_CHANGED", "UNIT_PET",
}

ShowInfoPreview = function()
    PushInfo("preview:skill", COLORS.skill, ICONS.skill, "Bows 138 " .. GREEN .. "(+1)|r", nil, true)
    PushInfo("preview:money", COLORS.money, ICONS.money, GREEN .. "+|r " .. Coins(12410), nil, true)
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
    self.infoFrame = CreateFrame("Frame")
    self.infoFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnInfoEvent(event, ...)
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
    for _, event in ipairs(INFO_EVENTS) do
        -- Not every event exists on every client (the learned-spell one was renamed in 11.0).
        pcall(self.infoFrame.RegisterEvent, self.infoFrame, event)
    end
    SnapshotPlayer()
    QueuePetCheck()
    if EditMode:IsActive() then ShowPreview() end
end

function ChatPopups:OnSettingChanged()
    local through = BOLT:GetConfig("chatPopups", "clickThrough")
    for _, toast in ipairs(toasts) do
        toast:EnableMouse(not through)
        if through then toast.hovered = false end
    end
end

function ChatPopups:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self.infoFrame:UnregisterAllEvents()
    for i = #toasts, 1, -1 do Release(toasts[i]) end
    if box then box:Hide() end
end

BOLT:RegisterModule("chatPopups", ChatPopups)
