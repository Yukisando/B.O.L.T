-- B.O.L.T Campfire Module (WoW: Forever only)
-- A small, quiet panel in the My Damage style that lists what resting at the camp gives you.
-- It shows while the "Campfire Nearby" buff is on you (the fire reaches ~100 yards):
--
--   Camp                52 min  Sit
--   ==================================   one bar: warming up, then the benefits' time left
--   [icon] Fish Bowl         +8% all stats
--   [icon] Camp Chair        +2% critical strike
--
-- What it lists, best source first:
--   * Camp Benefits is on you: its tooltip ("Object: effect" lines), with the time left.
--   * Welcoming Campfire is on you (sitting, the minute of warming up): the countdown.
--   * Otherwise: camp objects the Campfire Nearby tooltip names, if it names any, else a hint.
-- Click-through except a small Sit button (hidden while you warm up). It steps aside in combat.
-- Move it in Edit Mode.
-- `/bolt camp` prints what the module sees, for bug reports.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode
local EDIT_KEY = "camp"

local Campfire = {
    displayName = "Campfire",
}

local AURA_NEARBY = "Campfire Nearby"
local AURA_WARMING = "Welcoming Campfire"
local AURA_BENEFITS = "Camp Benefits"
local WARM_UP = 60 -- seconds of sitting before Camp Benefits

local WHITE = "Interface\\Buttons\\WHITE8X8"
local FALLBACK_ICON = "Interface\\Icons\\Spell_Fire_Fire"
local WIDTH = 220
local ROW_HEIGHT = 16
local HEADER_HEIGHT = 16
local BAR_HEIGHT = 4
local BAR_GAP = 3     -- below the bar, before the first row
local MAX_ROWS = 10
local DEFAULT_OPACITY = 80
local REFRESH = 0.5

local GREEN = { 0.45, 1, 0.45 }
local ORANGE = { 1, 0.55, 0.15 }

---------------------------------------------------------------------------
-- Camp objects: name, item ID (for the icon), short effect. Forever camping guides, 2026-11.
---------------------------------------------------------------------------

local OBJECTS = {
    { "Mana Well", 279956, "Mana regeneration" },
    { "Sharpening Wheel", 279944, "Strength" },
    { "Enchanted Lute", 279976, "Armor, stats, resistances" },
    { "First Aid Kit", 279968, "Stamina" },
    { "Fish Bowl", 279967, "+8% all stats" },
    { "Incense Candle", 279962, "Intellect" },
    { "Camp Tent", 279978, "Rested experience" },
    { "Lodestone", 279960, "Melee attack power" },
    { "Camp Chair", 279979, "+2% critical strike" },
    { "Faction Banner", 279972, "Spirit" },
    { "Reagent Bot", 279950, "Reagent vendor" },
    { "Fermenter", 279970, "Workstation" },
    { "Anvil", 279988, "Blacksmithing" },
    { "Cookie's Feast", 279957, "Stamina food" },
    { "Arcane Salvager", 279985, "Disenchanting" },
    { "Repair Bot", 279949, "Repairs" },
    { "Toxin Study", 279940, "Potions, anti-venom" },
    { "Fishing Rack", 279965, "Lures, fish" },
    { "Greenhouse", 279964, "Grows herbs" },
    { "Tanning Rack", 279941, "Workstation" },
    { "Rock Garden", 279948, "Grows ore" },
    { "Field Guide", 279969, "Track Beasts" },
    { "Spinning Wheel", 279943, "Workstation" },
}

local function Normalize(name)
    if not name then return nil end
    return (name:lower():gsub("\226\128\153", "'"):gsub("%s+kit$", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local BY_NAME = {}
for _, row in ipairs(OBJECTS) do
    BY_NAME[Normalize(row[1])] = { name = row[1], itemID = row[2], effect = row[3] }
end
BY_NAME["fishing bowl"] = BY_NAME["fish bowl"]

local function ObjectIcon(object)
    if object and object.itemID then
        return C_Item.GetItemIconByID(object.itemID) or FALLBACK_ICON
    end
    return FALLBACK_ICON
end

function Campfire:IsSupported()
    return BOLT.isForever
end

---------------------------------------------------------------------------
-- Reading the auras
---------------------------------------------------------------------------

local function FindAura(name)
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        return C_UnitAuras.GetAuraDataBySpellName("player", name, "HELPFUL")
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then return nil end
        if aura.name == name then return aura end
    end
end

-- Plain tooltip lines of a buff on the player (colors and grammar escapes stripped).
local function TooltipLines(aura)
    local lines = {}
    if not (aura and C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return lines end
    local ok, data = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", aura.auraInstanceID)
    if not ok or not data or not data.lines then return lines end
    for i = 2, #data.lines do
        local text = data.lines[i].leftText
        if text and not BOLT.IsSecret(text) then
            for line in text:gmatch("[^\n]+") do
                line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|4[^:;]*:([^;]*);", "%1")
                    :gsub("^%s+", ""):gsub("%s+$", "")
                if line ~= "" then table.insert(lines, line) end
            end
        end
    end
    return lines
end

-- Camp Benefits: "Gained the following camp benefits:", then "Object: effect" lines.
local function ReadBenefits(aura)
    local list = {}
    for _, line in ipairs(TooltipLines(aura)) do
        local name, effect = line:match("^(.-):%s*(.+)$")
        if line:find("remaining") or line:find("^Gained") then
            -- header and time left: the panel shows its own
        elseif name and (name:find("ID$") or effect:match("^%d+$")) then
            -- "Spell ID: 1229741", added to tooltips by the client or an ID addon
        elseif name then
            local object = BY_NAME[Normalize(name)]
            table.insert(list, { name = name, effect = object and object.effect or effect:gsub("%.$", ""), object = object })
        else
            table.insert(list, { effect = line:gsub("%.$", "") })
        end
    end
    return list
end

-- Camp objects the Campfire Nearby tooltip names, if it names any (any line that is or starts
-- with a known object's name).
local function ReadCampObjects(aura)
    local list, seen = {}, {}
    for _, line in ipairs(TooltipLines(aura)) do
        local name = line:match("^(.-):") or line:gsub("^[-*%s]+", "")
        local object = BY_NAME[Normalize(name)]
        if object and not seen[object] then
            seen[object] = true
            table.insert(list, { name = object.name, effect = object.effect, object = object })
        end
    end
    return list
end

local function TimeLeft(aura)
    if aura and aura.expirationTime and aura.expirationTime > 0 then
        return math.max(0, aura.expirationTime - GetTime())
    end
end

local function FormatTime(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds >= 3600 then
        return ("%dh %02dm"):format(seconds / 3600, (seconds % 3600) / 60)
    elseif seconds >= 60 then
        return ("%d min"):format(math.ceil(seconds / 60))
    end
    return ("0:%02d"):format(seconds)
end

---------------------------------------------------------------------------
-- The panel (built like My Damage)
---------------------------------------------------------------------------

local panel, header, titleText, modeText, timeText, hint, progress, sitButton
local rows = {}

local function PanelWidth() return EditMode:Get(EDIT_KEY, "width", WIDTH) end
local function Opacity() return EditMode:Get(EDIT_KEY, "opacity", DEFAULT_OPACITY) / 100 end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, panel)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -HEADER_HEIGHT - BAR_HEIGHT - BAR_GAP - (index - 1) * ROW_HEIGHT)
    row:SetPoint("RIGHT", panel, "RIGHT")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ROW_HEIGHT - 3, ROW_HEIGHT - 3)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.effect = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.effect:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.effect:SetJustifyH("RIGHT")
    row.effect:SetWordWrap(false)
    row.effect:SetTextColor(GREEN[1], GREEN[2], GREEN[3])

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
    row.name:SetPoint("RIGHT", row.effect, "LEFT", -6, 0)
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
    panel:SetWidth(PanelWidth())
end

local function Build()
    panel = CreateFrame("Frame", "BOLTCampPanel", UIParent)
    panel:SetClampedToScreen(true)
    panel:SetFrameStrata("LOW")
    panel:SetSize(WIDTH, HEADER_HEIGHT + ROW_HEIGHT)
    panel:EnableMouse(false)
    panel:Hide()

    header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEADER_HEIGHT)

    titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", 0, 1)
    titleText:SetText("Camp")
    modeText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    modeText:SetPoint("LEFT", titleText, "RIGHT", 6, 0)
    timeText = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    timeText:SetTextColor(0.85, 0.85, 0.85)

    -- A light text button, the panel's only clickable part.
    sitButton = CreateFrame("Button", nil, header)
    sitButton:SetHeight(HEADER_HEIGHT)
    sitButton:SetPoint("RIGHT", 0, 1)
    sitButton:SetNormalFontObject("GameFontNormalSmall")
    sitButton:SetHighlightFontObject("GameFontHighlightSmall")
    sitButton:SetText("Sit")
    sitButton:SetWidth(sitButton:GetFontString():GetStringWidth() + 8)
    local glow = sitButton:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)
    glow:SetAllPoints()
    sitButton:SetScript("OnClick", function() DoEmote("SIT") end)
    sitButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Sit by the fire", 1, 1, 1)
        GameTooltip:AddLine("Sit close to the flames for a minute to get the camp's benefits; "
            .. "sit again after new objects are placed to add theirs.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    sitButton:SetScript("OnLeave", GameTooltip_Hide)

    -- One bar for the whole camp: the minute of warming up, then the benefits' time left.
    progress = CreateFrame("StatusBar", nil, panel)
    progress:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    progress:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    progress:SetHeight(BAR_HEIGHT)
    progress:SetStatusBarTexture(NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar") or WHITE)
    progress.bg = progress:CreateTexture(nil, "BACKGROUND")
    progress.bg:SetAllPoints()
    progress.bg:SetColorTexture(1, 1, 1, 0.06)

    hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -BAR_GAP)
    hint:SetPoint("RIGHT", panel, "RIGHT")
    hint:SetJustifyH("LEFT")
    hint:Hide()

    panel.elapsed = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        panel.elapsed = panel.elapsed + elapsed
        if panel.elapsed < REFRESH then return end
        panel.elapsed = 0
        Campfire:Refresh()
    end)

    Place()

    if not EditMode.available then return end
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "Camp",
        frame = panel,
        default = { point = "BOTTOMRIGHT", x = -320, y = 345 },
        onEnter = function() Campfire:Refresh() end,
        onExit = function() Campfire:Refresh() end,
        apply = function() Place() Campfire:Refresh() end,
        settings = {
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
                desc = "How see-through the panel is. 100% is fully opaque.",
                format = function(value) return ("%d%%"):format(value) end,
                get = function() return EditMode:Get(EDIT_KEY, "opacity", DEFAULT_OPACITY) end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "opacity", value)
                    Campfire:Refresh()
                end,
            }),
        },
    })
end

local function FillRow(index, entry)
    local row = rows[index] or CreateRow(index)
    row.icon:SetTexture(ObjectIcon(entry.object))
    row.name:SetText(entry.name or "")
    row.effect:SetText(entry.effect or "")
    row:Show()
end

function Campfire:Refresh()
    if not panel then return end
    local editing = EditMode:IsActive()
    local nearby = self.active and FindAura(AURA_NEARBY)
    if not self.active or (not editing and (not nearby or InCombatLockdown())) then
        panel:Hide()
        return
    end

    local benefits = FindAura(AURA_BENEFITS)
    local warming = FindAura(AURA_WARMING)
    local list, value, max, color = {}, 1, 1, GREEN
    hint:Hide()
    modeText:SetText("")
    timeText:SetText("")

    if warming then
        -- Sitting by the fire: the minute of warming up, then the benefits are revealed.
        local duration = warming.duration and warming.duration > 0 and warming.duration or WARM_UP
        local left = TimeLeft(warming) or duration
        modeText:SetText("warming up")
        timeText:SetText(FormatTime(left))
        list = benefits and ReadBenefits(benefits) or ReadCampObjects(nearby)
        value, max, color = duration - left, duration, ORANGE
        if #list == 0 then
            hint:SetText("Benefits in " .. FormatTime(left))
            hint:Show()
        end
    elseif benefits then
        local left = TimeLeft(benefits)
        list = ReadBenefits(benefits)
        if left then
            timeText:SetText(FormatTime(left))
            max = benefits.duration and benefits.duration > 0 and benefits.duration or left
            value = left
        end
    else
        list = ReadCampObjects(nearby)
        modeText:SetText(#list > 0 and "rest to gain" or "")
        if #list == 0 then
            hint:SetText(editing and not nearby and "Camp benefits show here" or "Sit by the fire for a minute")
            hint:Show()
        end
    end

    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do FillRow(i, list[i]) end
    for i = shown + 1, #rows do rows[i]:Hide() end

    progress:SetMinMaxValues(0, max)
    progress:SetValue(value)
    progress:SetStatusBarColor(color[1], color[2], color[3])
    progress:SetAlpha((warming or benefits) and 1 or 0.4)

    -- Sitting starts the warm-up, so the button goes while it runs.
    sitButton:SetShown(not warming)
    timeText:ClearAllPoints()
    if sitButton:IsShown() then
        timeText:SetPoint("RIGHT", sitButton, "LEFT", -4, 0)
    else
        timeText:SetPoint("RIGHT", header, "RIGHT", 0, 1)
    end

    panel:SetHeight(HEADER_HEIGHT + BAR_HEIGHT + BAR_GAP + math.max(shown, 1) * ROW_HEIGHT)
    panel:SetAlpha(editing and 1 or Opacity())
    panel:Show()
end

---------------------------------------------------------------------------
-- Debug: /bolt camp
---------------------------------------------------------------------------

function Campfire:PrintDebug()
    BOLT:Print("=== Campfire ===")
    for _, name in ipairs({ AURA_NEARBY, AURA_WARMING, AURA_BENEFITS }) do
        local aura = FindAura(name)
        if aura then
            print(("  %s: spell %s, duration %s, %ds left"):format(name, tostring(aura.spellId),
                tostring(aura.duration), TimeLeft(aura) or 0))
            for _, line in ipairs(TooltipLines(aura)) do print("    | " .. line) end
        else
            print(("  %s: no"):format(name))
        end
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Campfire:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then Place() end
        self:Refresh()
    end)
end

function Campfire:OnEnable()
    if not panel then Build() end
    local events = self.eventFrame
    events:RegisterUnitEvent("UNIT_AURA", "player")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:Refresh()
end

function Campfire:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    if panel then panel:Hide() end
end

function Campfire:OnSettingChanged()
    self:Refresh()
end

BOLT:RegisterModule("campfire", Campfire)
