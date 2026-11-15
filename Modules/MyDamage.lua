-- B.O.L.T My Damage Module
-- A small, quiet panel that replaces Blizzard's damage meter window with only what matters to
-- you: your rank in the group and your own spells (pets included), best first.
--
--   #2 of 5                 12.4K dps
--   [icon] Arcane Shot        84.1K   ▬▬▬▬▬▬▬▬
--   [icon] Claw (Wolf)        51.0K   ▬▬▬▬▬
--
-- Data comes from Blizzard's own meter (C_DamageMeter), current fight (the last one once combat
-- ends). The game ranks players and sorts spells itself, and flags your line (isLocalPlayer is
-- never secret), so the rank needs no maths. In combat the amounts are secret: they are only
-- handed to things that accept secrets (FontString text, StatusBar values), never compared.
-- Anything that can't be read in combat fills in when combat ends.
-- Blizzard's meter window is hidden (setting), not switched off: switching it off in the game
-- options stops the data too.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode
local EDIT_KEY = "myDamage"

local MyDamage = {
    displayName = "My Damage",
}

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIDTH = 220
local ROW_HEIGHT = 16
local HEADER_HEIGHT = 16
local DEFAULT_ROWS = 6
local REFRESH = 0.5 -- seconds between refreshes while the meter updates
local FADED_ALPHA = 0.55 -- out of combat
local GOLD = { 1, 0.82, 0 }

local panel, header, rankText, dpsText, hint
local rows = {}
local pending = false

local function IsSecret(value) return BOLT.IsSecret(value) end

function MyDamage:IsSupported()
    return C_DamageMeter ~= nil and C_DamageMeter.GetCombatSessionFromType ~= nil
        and Enum.DamageMeterType ~= nil and Enum.DamageMeterSessionType ~= nil
end

local function Cfg(key)
    return BOLT:GetConfig("myDamage", key)
end

local function RowCount()
    return EditMode:Get(EDIT_KEY, "rows", DEFAULT_ROWS)
end

local function PanelWidth()
    return EditMode:Get(EDIT_KEY, "width", WIDTH)
end

-- Readable tables only: in combat the game can hand out tables addons may not index.
local function Readable(value)
    if IsSecret(value) or type(value) ~= "table" then return false end
    if type(canaccesstable) ~= "function" then return true end
    local ok, allowed = pcall(canaccesstable, value)
    return ok and allowed == true
end

-- Text for an amount: abbreviated when the game lets us, raw when it's secret and the
-- abbreviation refuses it.
local function SetAmount(fontString, value)
    if value == nil then fontString:SetText("") return end
    local ok = pcall(function() fontString:SetText(AbbreviateLargeNumbers(value)) end)
    if not ok then pcall(fontString.SetText, fontString, value) end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function ClassColor()
    local _, class = UnitClass("player")
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
    return 0.6, 0.6, 0.6
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -HEADER_HEIGHT - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", panel, "RIGHT")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 3, ROW_HEIGHT - 3)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- A thin bar along the bottom of the row, in the Personal Resource Display's fill.
    row.bar = CreateFrame("StatusBar", nil, row)
    row.bar:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 4, 0)
    row.bar:SetPoint("RIGHT", row, "RIGHT")
    row.bar:SetHeight(3)
    row.bar:SetStatusBarTexture(NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar") or WHITE)
    row.bar:SetStatusBarColor(ClassColor())
    row.bar:SetAlpha(0.7)
    row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
    row.bar.bg:SetAllPoints()
    row.bar.bg:SetColorTexture(1, 1, 1, 0.06)

    row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.amount:SetPoint("BOTTOMRIGHT", row.bar, "TOPRIGHT", 0, 1)
    row.amount:SetJustifyH("RIGHT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("BOTTOMLEFT", row.bar, "TOPLEFT", 0, 1)
    row.name:SetPoint("RIGHT", row.amount, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetTextColor(0.85, 0.85, 0.85)

    row:Hide()
    rows[index] = row
    return row
end

local function Place()
    if not panel or InCombatLockdown() then return end
    local point, x, y = EditMode:GetPosition(EDIT_KEY)
    panel:ClearAllPoints()
    panel:SetPoint(point, UIParent, point, x, y)
    panel:SetSize(PanelWidth(), HEADER_HEIGHT + RowCount() * ROW_HEIGHT)
end

local function Build()
    panel = CreateFrame("Frame", "BOLTMyDamage", UIParent)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("LOW")

    header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)

    rankText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("LEFT", 0, 1)
    dpsText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dpsText:SetPoint("RIGHT", 0, 1)
    dpsText:SetTextColor(0.85, 0.85, 0.85)

    hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetPoint("RIGHT", panel, "RIGHT")
    hint:SetJustifyH("LEFT")
    hint:Hide()

    Place()

    if not EditMode.available then return end
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "My Damage",
        frame = panel,
        default = { point = "BOTTOMRIGHT", x = -320, y = 220 },
        onEnter = function() MyDamage:Refresh() end,
        onExit = function() MyDamage:Refresh() end,
        apply = function() Place() MyDamage:Refresh() end,
        settings = {
            EditMode:Slider("Spells shown", nil, {
                min = 3, max = 12, step = 1, default = DEFAULT_ROWS,
                get = function() return RowCount() end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "rows", value)
                    Place()
                    MyDamage:Refresh()
                end,
            }),
            EditMode:Slider("Width", nil, {
                min = 140, max = 360, step = 10, default = WIDTH,
                get = function() return PanelWidth() end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "width", value)
                    Place()
                end,
            }),
        },
    })
end

---------------------------------------------------------------------------
-- Reading the meter
---------------------------------------------------------------------------

local function Session()
    local ok, session = pcall(C_DamageMeter.GetCombatSessionFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone)
    if ok and Readable(session) then return session end
end

-- Your place in the list (the game sorts it), how many are in it, and your line.
local function MyRank(session)
    local sources = session.combatSources
    if not Readable(sources) then return end
    local count = #sources
    for i = 1, count do
        local source = sources[i]
        if Readable(source) and source.isLocalPlayer then
            return i, count, source
        end
    end
    return nil, count
end

local function MySpells()
    local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone, UnitGUID("player"))
    if ok and Readable(source) and Readable(source.combatSpells) then return source end
end

local function SpellLabel(spell)
    local name = C_Spell.GetSpellName(spell.spellID)
    local creature = spell.creatureName
    if creature ~= nil and not IsSecret(creature) and creature ~= "" then
        return ("%s (%s)"):format(name or "?", creature)
    end
    return name
end

local function FillRow(row, spell, maxAmount)
    pcall(function() row.icon:SetTexture(C_Spell.GetSpellTexture(spell.spellID)) end)
    if not pcall(function() row.name:SetText(SpellLabel(spell)) end) then
        pcall(function() row.name:SetText(C_Spell.GetSpellName(spell.spellID)) end)
    end
    SetAmount(row.amount, spell.totalAmount)
    pcall(function()
        row.bar:SetMinMaxValues(0, maxAmount)
        row.bar:SetValue(spell.totalAmount)
    end)
    row:Show()
end

function MyDamage:Refresh()
    pending = false
    if not panel then return end
    local editing = EditMode:IsActive()
    if not self.active then panel:Hide() return end

    local available = true
    if C_DamageMeter.IsDamageMeterAvailable then
        local ok, isAvailable = pcall(C_DamageMeter.IsDamageMeterAvailable)
        available = not ok or isAvailable ~= false
    end

    local session = available and Session()
    local rank, count, mine
    if session then rank, count, mine = MyRank(session) end
    local source = mine and MySpells()

    hint:Hide()
    if not available then
        rankText:SetText("My Damage")
        dpsText:SetText("")
        hint:SetText("Turn the damage meter on in the game options (Gameplay).")
        hint:Show()
    elseif rank then
        if count > 1 then
            rankText:SetFormattedText("#%d of %d", rank, count)
        else
            rankText:SetText("Solo")
        end
        if rank == 1 and count > 1 then
            rankText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            rankText:SetTextColor(0.85, 0.85, 0.85)
        end
        local ok = pcall(function() dpsText:SetText(AbbreviateLargeNumbers(mine.amountPerSecond) .. " dps") end)
        if not ok then SetAmount(dpsText, mine.amountPerSecond) end
    elseif editing then
        rankText:SetText("My Damage")
        dpsText:SetText("")
    else
        panel:Hide()
        return
    end

    local shown = 0
    if source then
        local spells, maxAmount = source.combatSpells, source.maxAmount
        local limit = math.min(#spells, RowCount())
        for i = 1, limit do
            local spell = spells[i]
            if Readable(spell) then
                shown = shown + 1
                FillRow(rows[shown] or CreateRow(shown), spell, maxAmount)
            end
        end
    end
    for i = shown + 1, #rows do rows[i]:Hide() end

    panel:SetAlpha((InCombatLockdown() or editing) and 1 or FADED_ALPHA)
    panel:Show()
end

local function QueueRefresh()
    if pending then return end
    pending = true
    C_Timer.After(REFRESH, function() MyDamage:Refresh() end)
end

---------------------------------------------------------------------------
-- Blizzard's meter window: hidden while this panel is on (setting).
---------------------------------------------------------------------------

local nativeHooked = false

local function HideNative()
    local meter = DamageMeter
    if not meter then return end
    if not (MyDamage.active and Cfg("hideBlizzard")) then return end
    -- A protected frame can't be hidden in combat: make it invisible until combat ends.
    if InCombatLockdown() and meter:IsProtected() then
        meter:SetAlpha(0)
        return
    end
    if meter:IsShown() then meter:Hide() end
end

local function RestoreNative()
    local meter = DamageMeter
    if not meter then return end
    meter:SetAlpha(1)
    if meter.UpdateShownState and not InCombatLockdown() then
        pcall(meter.UpdateShownState, meter)
    end
end

local function HookNative()
    local meter = DamageMeter
    if nativeHooked or not meter then return end
    nativeHooked = true
    hooksecurefunc(meter, "Show", HideNative)
    if meter.SetShown then hooksecurefunc(meter, "SetShown", HideNative) end
end

local function UpdateNative()
    HookNative()
    if MyDamage.active and Cfg("hideBlizzard") then HideNative() else RestoreNative() end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function MyDamage:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "ADDON_LOADED" then
            if DamageMeter then UpdateNative() end
            return
        end
        if event == "PLAYER_REGEN_ENABLED" then
            UpdateNative()
            Place()
        end
        QueueRefresh()
    end)
end

function MyDamage:OnEnable()
    if not panel then Build() end
    local events = self.eventFrame
    events:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    events:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    events:RegisterEvent("DAMAGE_METER_RESET")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("GROUP_ROSTER_UPDATE")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:RegisterEvent("ADDON_LOADED") -- Blizzard_DamageMeter can load after BOLT
    UpdateNative()
    self:Refresh()
end

function MyDamage:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    if panel then panel:Hide() end
    RestoreNative()
end

function MyDamage:OnSettingChanged()
    UpdateNative()
    self:Refresh()
end

BOLT:RegisterModule("myDamage", MyDamage)
