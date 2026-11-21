-- B.O.L.T My Damage Module
-- A small, quiet panel that replaces Blizzard's damage meter window with only what matters to
-- you: your rank in the group and your own spells (pets included), best first.
--
--   #2 of 5                 12.4K dps
--   [icon] Arcane Shot        84.1K   ▬▬▬▬▬▬▬▬
--   [icon] Claw (Wolf)        51.0K   ▬▬▬▬▬
--
-- Right-click switches to the group: the same rows, one per player (class icon and colour)
-- instead of one per spell. Left-click switches between this fight and the overall session.
-- Both only while the panel takes clicks (Edit Mode: "Click-through" off, the default).
--
-- Data comes from Blizzard's own meter (C_DamageMeter), current fight (the last one once combat
-- ends) or overall. The game ranks players and sorts spells itself, and flags your line (isLocalPlayer is
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
local DEFAULT_OPACITY = 80 -- percent; the panel's only fade (100% = fully opaque)
local REFRESH = 0.5 -- seconds between refreshes while the meter updates
-- Class icons from the classic sheet: both clients have it, and Forever has no spec icons.
local CLASS_SHEET = "Interface\\TargetingFrame\\UI-Classes-Circles"
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

local function Opacity()
    return EditMode:Get(EDIT_KEY, "opacity", DEFAULT_OPACITY) / 100
end

local function ClickThrough()
    return EditMode:Get(EDIT_KEY, "clickThrough", false)
end

local function SessionType()
    return Cfg("overall") and Enum.DamageMeterSessionType.Overall or Enum.DamageMeterSessionType.Current
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

local function ClassColor(class)
    if not class then class = select(2, UnitClass("player")) end
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
    row.bar:SetAlpha(1)
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

local function ApplyMouse()
    if panel then panel:EnableMouse(not ClickThrough()) end
end

local function ShowTooltip(self)
    if InCombatLockdown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("My Damage", 1, 1, 1)
    GameTooltip:AddLine(("Left-click: %s"):format(Cfg("overall") and "this fight" or "overall"), nil, nil, nil, true)
    GameTooltip:AddLine(("Right-click: %s"):format(Cfg("group") and "your spells" or "the group"), nil, nil, nil, true)
    GameTooltip:Show()
end

local function OnClick(self, button)
    if button == "LeftButton" then
        BOLT:SetConfig(not Cfg("overall"), "myDamage", "overall")
    elseif button == "RightButton" then
        BOLT:SetConfig(not Cfg("group"), "myDamage", "group")
    else
        return
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    MyDamage:Refresh()
    if GameTooltip:GetOwner() == self then ShowTooltip(self) end
end

local function Build()
    panel = CreateFrame("Frame", "BOLTMyDamage", UIParent)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("LOW")
    panel:SetScript("OnMouseUp", OnClick)
    panel:SetScript("OnEnter", ShowTooltip)
    panel:SetScript("OnLeave", GameTooltip_Hide)
    ApplyMouse()

    header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)

    rankText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rankText:SetPoint("LEFT", 0, 1)
    -- What the panel shows right now ("group", "overall"), quieter than the rank.
    header.mode = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header.mode:SetPoint("LEFT", rankText, "RIGHT", 6, 0)
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
        hideCoords = true,
        onEnter = function() MyDamage:Refresh() end,
        onExit = function() MyDamage:Refresh() end,
        apply = function() Place() ApplyMouse() MyDamage:Refresh() end,
        settings = {
            EditMode:Slider("Lines shown", nil, {
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
            EditMode:Slider("Opacity", nil, {
                min = 10, max = 100, step = 5, default = DEFAULT_OPACITY,
                desc = "How see-through the panel is, in and out of combat. 100% is fully opaque.",
                format = function(value) return ("%d%%"):format(value) end,
                get = function() return EditMode:Get(EDIT_KEY, "opacity", DEFAULT_OPACITY) end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "opacity", value)
                    MyDamage:Refresh()
                end,
            }),
            EditMode:Checkbox("Click-through", nil, {
                desc = "Clicks go through to the world. Off: left-click switches this fight / overall, right-click your spells / the group.",
                default = false,
                get = function() return ClickThrough() end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "clickThrough", value and true or false)
                    ApplyMouse()
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
        SessionType(), Enum.DamageMeterType.DamageDone)
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
        SessionType(), Enum.DamageMeterType.DamageDone, UnitGUID("player"))
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
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.bar:SetStatusBarColor(ClassColor())
    row.name:SetTextColor(0.85, 0.85, 0.85)
    row:Show()
end

-- One player in the group view: spec (or class) icon, name, total and a bar in class colour.
local function FillPlayerRow(row, source, maxAmount)
    local class = source.classFilename
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if source.specIconID and source.specIconID ~= 0 then
        row.icon:SetTexture(source.specIconID)
        row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    elseif coords then
        row.icon:SetTexture(CLASS_SHEET)
        row.icon:SetTexCoord(unpack(coords))
    else
        row.icon:SetTexture(nil)
    end
    if not pcall(row.name.SetText, row.name, source.name) then row.name:SetText("?") end
    SetAmount(row.amount, source.totalAmount)
    pcall(function()
        row.bar:SetMinMaxValues(0, maxAmount)
        row.bar:SetValue(source.totalAmount)
    end)
    local r, g, b = ClassColor(class)
    row.bar:SetStatusBarColor(r, g, b)
    if source.isLocalPlayer then
        row.name:SetTextColor(1, 1, 1)
    else
        row.name:SetTextColor(r * 0.8 + 0.2, g * 0.8 + 0.2, b * 0.8 + 0.2)
    end
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
    header.mode:SetText(Cfg("overall") and "overall" or "")
    if not available then
        rankText:SetText("My Damage")
        dpsText:SetText("")
        hint:SetText("Turn the damage meter on in the game options (Gameplay).")
        hint:Show()
    elseif rank then
        if Cfg("group") then
            rankText:SetText("Group")
        elseif count > 1 then
            rankText:SetFormattedText("#%d of %d", rank, count)
        else
            rankText:SetText("Solo")
        end
        if rank == 1 and count > 1 and not Cfg("group") then
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
    if Cfg("group") then
        local sources = session and session.combatSources
        if Readable(sources) then
            for i = 1, math.min(#sources, RowCount()) do
                local player = sources[i]
                if Readable(player) then
                    shown = shown + 1
                    FillPlayerRow(rows[shown] or CreateRow(shown), player, session.maxAmount)
                end
            end
        end
    elseif source then
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

    local opacity = Opacity()
    panel:SetAlpha(editing and 1 or opacity)
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
