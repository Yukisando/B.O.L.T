-- B.O.L.T Auto-hide UI Module
-- Fades parts of Blizzard's UI out until they're needed. A group fades in when you hover it,
-- have a target or are in combat; it stays hidden while mounted or on a flight path unless
-- you're in combat. Everything shows in Edit Mode, and action bars show while you drag a
-- spell or item onto them.
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

local function Cfg(key)
    return BOLT:GetConfig("autoHide", key)
end

local function Named(names)
    local frames = {}
    for _, name in ipairs(names) do
        if _G[name] then
            table.insert(frames, _G[name])
        end
    end
    return frames
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

local GROUPS = {
    {
        -- The bottom row reads as one strip, so it shows as one: hovering the main bar, the
        -- micro menu or the bags reveals all three.
        key = "mainBar",
        showWhileDragging = true,
        frames = function()
            return Named({ "MainActionBar", "MainMenuBar", "MicroMenuContainer", "BagsBar", "MicroButtonAndBagsBar" })
        end,
    },
    {
        key = "actionBars",
        showWhileDragging = true,
        frames = function()
            return Named({ "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
                "MultiBar5", "MultiBar6", "MultiBar7", "StanceBar", "PetActionBar", "MultiCastActionBarFrame" })
        end,
    },
    {
        -- The bar containers animate their own alpha, so we fade their manager. The manager's
        -- own rectangle doesn't cover the bars (Edit Mode places the containers), so hover is
        -- checked on the containers themselves.
        key = "xpBar",
        frames = function()
            return Named({ "StatusTrackingBarManager" })
        end,
        hover = function()
            return Named({ "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" })
        end,
    },
    {
        key = "buffs",
        frames = function()
            return Named({ "BuffFrame" })
        end,
    },
    {
        key = "debuffs",
        frames = function()
            return Named({ "DebuffFrame" })
        end,
    },
    {
        -- Target and focus only exist while you have one, and a target shows the UI anyway.
        key = "unitFrames",
        frames = function()
            return Named({ "PlayerFrame", "PetFrame", "FocusFrame", "PartyFrame", "CompactPartyFrame" })
        end,
    },
    {
        key = "questTracker",
        frames = function()
            return Named({ "ObjectiveTrackerFrame", "QuestWatchFrame", "WatchFrame" })
        end,
    },
    {
        -- The map itself; its buttons are their own group. Hovering a button reveals the map too,
        -- since addon buttons sit on the map and would otherwise stay faded with it.
        key = "minimap",
        frames = function()
            local frames = Named({ "MinimapBackdrop", "Minimap" })
            if MinimapCluster and MinimapCluster.MinimapContainer then
                table.insert(frames, 1, MinimapCluster.MinimapContainer)
            end
            return frames
        end,
        hover = MinimapButtons,
    },
    {
        key = "minimapButtons",
        frames = MinimapButtons,
        -- Hovering the map reveals its buttons.
        hover = function()
            return Named({ "Minimap" })
        end,
    },
}

local state = {} -- [group key] = { group, frames, hover, alpha, holdUntil }

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

local function Rescan()
    for _, entry in pairs(state) do
        local frames = entry.group.frames()
        -- A frame that left the group gets its alpha back.
        local keep = {}
        for _, frame in ipairs(frames) do keep[frame] = true end
        for _, frame in ipairs(entry.frames) do
            if not keep[frame] then frame:SetAlpha(1) end
        end
        entry.frames = frames
        entry.hover = entry.group.hover and entry.group.hover() or nil
    end
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
        Rescan()
    end

    local now = GetTime()
    local inCombat = InCombatLockdown() or UnitAffectingCombat("player")
    local mounted = IsMounted() or UnitOnTaxi("player")
    -- Combat always shows; a target shows unless you're mounted or flying a taxi.
    local wanted = inCombat or (UnitExists("target") and not mounted) or IsEditing()
    local dragging = GetCursorInfo() ~= nil
    local idleAlpha = (Cfg("idleAlpha") or 0) / 100

    for _, entry in pairs(state) do
        local show = wanted
            or (entry.group.showWhileDragging and dragging)
            or Hovered(entry.frames)
            or (entry.hover ~= nil and Hovered(entry.hover))
        if show then
            entry.holdUntil = now + FADE_OUT_DELAY
        end

        local goal = (show or now < entry.holdUntil) and 1 or idleAlpha
        local alpha = entry.alpha
        if alpha < goal then
            alpha = math.min(goal, alpha + elapsed / FADE_IN)
        elseif alpha > goal then
            alpha = math.max(goal, alpha - elapsed / FADE_OUT)
        end
        entry.alpha = alpha
        SetAlpha(entry.frames, alpha)
    end
end

function AutoHide:BuildGroups()
    for _, group in ipairs(GROUPS) do
        local entry = state[group.key]
        if Cfg(group.key) then
            if not entry then
                state[group.key] = {
                    group = group,
                    frames = group.frames(),
                    hover = group.hover and group.hover() or nil,
                    alpha = 1,
                    holdUntil = GetTime() + FADE_OUT_DELAY,
                }
            end
        elseif entry then
            SetAlpha(entry.frames, 1)
            state[group.key] = nil
        end
    end
end

function AutoHide:RestoreAll()
    for key, entry in pairs(state) do
        SetAlpha(entry.frames, 1)
        state[key] = nil
    end
end

function AutoHide:OnInitialize()
    self.driver = CreateFrame("Frame")
end

function AutoHide:OnEnable()
    self:BuildGroups()
    self.driver:SetScript("OnUpdate", OnUpdate)
end

function AutoHide:OnDisable()
    self.driver:SetScript("OnUpdate", nil)
    self:RestoreAll()
end

function AutoHide:OnSettingChanged()
    self:BuildGroups()
end

BOLT:RegisterModule("autoHide", AutoHide)
