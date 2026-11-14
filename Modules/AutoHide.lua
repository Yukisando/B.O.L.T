-- B.O.L.T Auto-hide UI Module
-- Fades parts of Blizzard's UI out until they're needed, through fade groups.
--
-- Elements: the parts of the UI that can fade (main bar, micro menu, bags, each action bar,
-- XP bar, buffs, unit frames, quest tracker, minimap...). Each one joins one fade group, or none
-- (autoHide.members[element] = "g1".."g4" or "none").
-- Fade groups (autoHide.groups.g1..g4): the members of a group fade in and out together, as one.
-- A group's rule lists what brings it back, any one being enough: hovering any of its members,
-- combat, a target (any, attackable or not attackable), being in a group, being in an
-- instance. With "mounted" on, only hover and combat count while mounted or on a flight path.
-- Tick nothing and the group stays faded. Each group has its own opacity while faded.
-- Everything shows in Edit Mode, and a group holding an action bar shows while you drag a spell
-- or item.
--
-- Only alpha changes, which Blizzard allows on protected frames in combat: bars stay
-- clickable and keybinds keep working while hidden.

local ADDON_NAME, BOLT = ...

local AutoHide = {
    displayName = "Auto-hide UI",
}

local FADE_IN = 0.2         -- seconds from hidden to shown
local FADE_OUT = 0.5        -- seconds from shown to hidden
local FADE_OUT_DELAY = 1    -- grace period after the last reason to show
local RESCAN_INTERVAL = 2   -- addons add minimap buttons late; pick them up

---------------------------------------------------------------------------
-- Fade groups and their rules
---------------------------------------------------------------------------

AutoHide.GROUP_IDS = { "g1", "g2", "g3", "g4" }
AutoHide.NONE = "none"

local DEFAULT_RULE = { hover = true, combat = true, target = "ANY", group = false, instance = false,
    mounted = true, alpha = 0 }

-- The on/off conditions of a rule, in the order the settings show them. The target condition
-- (a choice of target kind) and "mounted" sit beside these.
AutoHide.CONDITIONS = {
    { key = "hover", label = "Mouse over", short = "hover" },
    { key = "combat", label = "In combat", short = "combat" },
    { key = "group", label = "In a group", short = "group" },
    { key = "instance", label = "In a dungeon, raid, arena or battleground", short = "instance" },
}

local TARGET_SHORT = { ANY = "target", HOSTILE = "enemy target", FRIENDLY = "friendly target" }

function AutoHide.GroupName(id)
    return "Group " .. (tostring(id):match("%d+") or "?")
end

function AutoHide.Rule(id)
    local rule = BOLT:GetConfig("autoHide", "groups", id)
    if type(rule) ~= "table" then return DEFAULT_RULE end
    return rule
end

function AutoHide.RuleValue(rule, field)
    local value = rule[field]
    if value == nil then return DEFAULT_RULE[field] end
    return value
end

local Rule, RuleValue = AutoHide.Rule, AutoHide.RuleValue

-- "hover, combat, target" for menus and tooltips.
function AutoHide.Summary(id)
    local rule = Rule(id)
    local parts = {}
    for _, condition in ipairs(AutoHide.CONDITIONS) do
        if RuleValue(rule, condition.key) then table.insert(parts, condition.short) end
    end
    local target = TARGET_SHORT[RuleValue(rule, "target")]
    if target then table.insert(parts, target) end
    if #parts == 0 then return "never shows" end
    return table.concat(parts, ", ")
end

---------------------------------------------------------------------------
-- Elements
---------------------------------------------------------------------------

local function Named(names)
    local frames = {}
    for _, name in ipairs(names) do
        if _G[name] then
            table.insert(frames, _G[name])
        end
    end
    return frames
end

local function NamedList(...)
    local names = { ... }
    return function() return Named(names) end
end

-- The minimap's surroundings: zone name, tracking, calendar, mail and the like, plus the
-- buttons addons hang on the minimap (or BOLT's square minimap bars). The map itself stays.
local function MinimapButtons()
    local frames, seen = {}, {}
    local function Add(frame)
        if frame and not seen[frame] and frame ~= Minimap then
            seen[frame] = true
            table.insert(frames, frame)
        end
    end

    local cluster = MinimapCluster
    if cluster then
        for _, key in ipairs({ "BorderTop", "ZoneTextButton", "Tracking", "IndicatorFrame", "InstanceDifficulty" }) do
            Add(cluster[key])
        end
    end
    for _, frame in ipairs(Named({ "GameTimeFrame", "TimeManagerClockButton", "AddonCompartmentFrame",
        "ExpansionLandingPageMinimapButton", "MiniMapMailFrame", "MiniMapTracking", "MinimapZoneTextButton" })) do
        Add(frame)
    end
    -- The square minimap's bars and addon drawer button.
    local square = BOLT.modules.minimap
    if square and square.active and square.GetChromeFrames then
        for _, frame in ipairs(square:GetChromeFrames()) do
            Add(frame)
        end
    end
    if Minimap then
        Add(Minimap.ZoomIn)
        Add(Minimap.ZoomOut)
        for _, child in ipairs({ Minimap:GetChildren() }) do
            if child:GetObjectType() == "Button" then
                Add(child)
            end
        end
    end
    return frames
end

-- bar: an action bar (its group shows while you drag a spell or item).
-- hover: extra frames whose hover counts for this element, when its frames don't cover it.
AutoHide.ELEMENTS = {
    { key = "mainBar", label = "Main action bar", bar = true, frames = NamedList("MainActionBar", "MainMenuBar") },
    { key = "microMenu", label = "Micro menu", frames = NamedList("MicroMenuContainer", "MicroButtonAndBagsBar") },
    { key = "bags", label = "Bags", frames = NamedList("BagsBar") },
    { key = "bar2", label = "Action bar 2", bar = true, frames = NamedList("MultiBarBottomLeft") },
    { key = "bar3", label = "Action bar 3", bar = true, frames = NamedList("MultiBarBottomRight") },
    { key = "bar4", label = "Action bar 4 (right)", bar = true, frames = NamedList("MultiBarRight") },
    { key = "bar5", label = "Action bar 5 (right)", bar = true, frames = NamedList("MultiBarLeft") },
    { key = "bar6", label = "Action bar 6", bar = true, frames = NamedList("MultiBar5") },
    { key = "bar7", label = "Action bar 7", bar = true, frames = NamedList("MultiBar6") },
    { key = "bar8", label = "Action bar 8", bar = true, frames = NamedList("MultiBar7") },
    { key = "stanceBar", label = "Stance bar", bar = true, frames = NamedList("StanceBar") },
    { key = "petBar", label = "Pet bar", bar = true, frames = NamedList("PetActionBar", "MultiCastActionBarFrame") },
    {
        -- The bar containers animate their own alpha, so we fade their manager. The manager's
        -- own rectangle doesn't cover the bars (Edit Mode places the containers), so hover is
        -- checked on the containers themselves.
        key = "xpBar", label = "Experience bar",
        frames = NamedList("StatusTrackingBarManager"),
        hover = NamedList("MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer"),
    },
    { key = "buffs", label = "Buffs", frames = NamedList("BuffFrame") },
    { key = "debuffs", label = "Debuffs", frames = NamedList("DebuffFrame") },
    {
        key = "playerFrame", label = "Player frame",
        frames = function()
            -- The Player Frame's own hide/show options (Edit Mode) win over auto-hide.
            local visibility = BOLT.modules.frameVisibility
            if PlayerFrame and not (visibility and visibility:Controls("player")) then
                return { PlayerFrame }
            end
            return {}
        end,
    },
    { key = "petFrame", label = "Pet frame", frames = NamedList("PetFrame") },
    { key = "focusFrame", label = "Focus frame", frames = NamedList("FocusFrame") },
    { key = "partyFrames", label = "Party frames", frames = NamedList("PartyFrame", "CompactPartyFrame") },
    { key = "questTracker", label = "Quest tracker", frames = NamedList("ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame") },
    {
        -- The map itself; its buttons are their own element. Hovering a button counts as
        -- hovering the map, since addon buttons sit on the map.
        key = "minimap", label = "Minimap",
        frames = function()
            local frames = Named({ "MinimapBackdrop", "Minimap" })
            if MinimapCluster and MinimapCluster.MinimapContainer then
                table.insert(frames, 1, MinimapCluster.MinimapContainer)
            end
            return frames
        end,
        hover = MinimapButtons,
    },
    { key = "minimapButtons", label = "Minimap buttons", frames = MinimapButtons, hover = NamedList("Minimap") },
}

local ELEMENT_BY_KEY = {}
for _, element in ipairs(AutoHide.ELEMENTS) do ELEMENT_BY_KEY[element.key] = element end
AutoHide.ELEMENT_BY_KEY = ELEMENT_BY_KEY

-- The fade group an element belongs to, or NONE.
function AutoHide.MemberOf(elementKey)
    local id = BOLT:GetConfig("autoHide", "members", elementKey)
    if type(id) ~= "string" or not BOLT:GetConfig("autoHide", "groups", id) then return AutoHide.NONE end
    return id
end

function AutoHide.HasMembers()
    for _, element in ipairs(AutoHide.ELEMENTS) do
        if AutoHide.MemberOf(element.key) ~= AutoHide.NONE then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Fading
---------------------------------------------------------------------------

-- [group id] = { frames, hover, bar, alpha, holdUntil }
local state = {}
local faded = {} -- [frame] = true for every frame BOLT is fading, to give alpha back

local function Hovered(frames)
    for _, frame in ipairs(frames) do
        if frame:IsVisible() and frame:IsMouseOver() then
            return true
        end
    end
    return false
end

local function SetAlpha(frames, alpha)
    for _, frame in ipairs(frames) do
        if frame:GetAlpha() ~= alpha then
            frame:SetAlpha(alpha)
        end
    end
end

-- Rebuilds every group's frame list from the members. Frames that left every group get their
-- alpha back. Keeps each group's current alpha so nothing flashes.
local function Rebuild()
    local wanted, now = {}, GetTime()
    local seen = {}
    for _, element in ipairs(AutoHide.ELEMENTS) do
        local id = AutoHide.MemberOf(element.key)
        if id ~= AutoHide.NONE then
            local group = wanted[id]
            if not group then
                local old = state[id]
                group = { frames = {}, hover = {}, bar = false,
                    alpha = old and old.alpha or 1, holdUntil = old and old.holdUntil or now + FADE_OUT_DELAY }
                wanted[id] = group
            end
            for _, frame in ipairs(element.frames()) do
                if not seen[frame] then
                    seen[frame] = true
                    table.insert(group.frames, frame)
                end
            end
            if element.hover then
                for _, frame in ipairs(element.hover()) do table.insert(group.hover, frame) end
            end
            group.bar = group.bar or element.bar == true
        end
    end
    for frame in pairs(faded) do
        if not seen[frame] then
            frame:SetAlpha(1)
            faded[frame] = nil
        end
    end
    for frame in pairs(seen) do faded[frame] = true end
    state = wanted
end

local function IsEditing()
    local manager = EditModeManagerFrame
    if not manager then return false end
    if manager.IsEditModeActive then
        return manager:IsEditModeActive()
    end
    return manager:IsShown()
end

local sinceRescan = 0
local function OnUpdate(_, elapsed)
    sinceRescan = sinceRescan + elapsed
    if sinceRescan >= RESCAN_INTERVAL then
        sinceRescan = 0
        Rebuild()
    end

    local now = GetTime()
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local mounted = IsMounted() or UnitOnTaxi("player")
    local editing = IsEditing()
    local dragging = GetCursorInfo() ~= nil
    local inGroup = IsInGroup()
    local inInstance, instanceType = IsInInstance()
    inInstance = inInstance and instanceType ~= "none" and instanceType ~= "neighborhood"
    local visibility = BOLT.modules.frameVisibility
    local targetFits = {} -- [kind] = bool, worked out once per frame
    local function TargetFits(kind)
        if not kind or kind == "OFF" then return false end
        if targetFits[kind] == nil then
            if visibility then
                targetFits[kind] = visibility.TargetFits(kind) and true or false
            else
                targetFits[kind] = UnitExists("target") and true or false
            end
        end
        return targetFits[kind]
    end

    for id, group in pairs(state) do
        local rule = Rule(id)
        local quiet = mounted and RuleValue(rule, "mounted")
        local show = editing
            or (group.bar and dragging)
            or (RuleValue(rule, "combat") and inCombat)
            or (RuleValue(rule, "hover") and (Hovered(group.frames) or Hovered(group.hover)))
            or (not quiet and (
                TargetFits(RuleValue(rule, "target"))
                or (RuleValue(rule, "group") and inGroup)
                or (RuleValue(rule, "instance") and inInstance)))
        if show then
            group.holdUntil = now + FADE_OUT_DELAY
        end

        local goal = (show or now < group.holdUntil) and 1 or (RuleValue(rule, "alpha") or 0) / 100
        local alpha = group.alpha
        if alpha < goal then
            alpha = math.min(goal, alpha + elapsed / FADE_IN)
        elseif alpha > goal then
            alpha = math.max(goal, alpha - elapsed / FADE_OUT)
        end
        group.alpha = alpha
        SetAlpha(group.frames, alpha)
    end
end

function AutoHide:RestoreAll()
    for frame in pairs(faded) do frame:SetAlpha(1) end
    faded = {}
    state = {}
end

function AutoHide:OnInitialize()
    self.driver = CreateFrame("Frame")
end

function AutoHide:OnEnable()
    Rebuild()
    self.driver:SetScript("OnUpdate", OnUpdate)
end

function AutoHide:OnDisable()
    self.driver:SetScript("OnUpdate", nil)
    self:RestoreAll()
end

function AutoHide:OnSettingChanged()
    Rebuild()
end

-- Puts an element in a fade group (or NONE). Turns the module on when something joins a group,
-- and off when nothing is left in any group.
function AutoHide.SetMember(elementKey, id)
    BOLT:SetSetting({ "autoHide", "members", elementKey }, id)
    local hasMembers = AutoHide.HasMembers()
    if hasMembers ~= BOLT:IsModuleEnabled("autoHide") then
        BOLT:SetModuleEnabled("autoHide", hasMembers)
    end
end

BOLT:RegisterModule("autoHide", AutoHide)
