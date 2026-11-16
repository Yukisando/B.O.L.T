-- B.O.L.T Tracker Memory Module
-- The objective tracker ("All Objectives") stays collapsed or open the way you left it, across
-- reloads and logins (every character). Blizzard opens it again every time.
-- Only your own clicks on its collapse button are remembered: the game opening it by itself
-- (tracking a new quest, say) doesn't change what comes back next time.
-- Always on, no setting.

local ADDON_NAME, BOLT = ...

local TrackerMemory = {
    displayName = "Objective Tracker Memory",
    alwaysOn = true,
}

local hooked = false

local function Tracker()
    local tracker = ObjectiveTrackerFrame
    if tracker and tracker.SetCollapsed and tracker.IsCollapsed then return tracker end
end

local function Remember(tracker)
    BOLTDB.trackerCollapsed = tracker:IsCollapsed() and true or false
end

local function Hook(tracker)
    if hooked then return end
    local button = tracker.Header and tracker.Header.MinimizeButton
    if not button then return end
    hooked = true
    button:HookScript("OnClick", function() Remember(tracker) end)
end

function TrackerMemory:Apply()
    local tracker = Tracker()
    if not tracker then return end
    Hook(tracker)
    if BOLTDB.trackerCollapsed and not tracker:IsCollapsed() then
        -- The tracker holds quest item buttons, which can't change in combat.
        if InCombatLockdown() then
            self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        tracker:SetCollapsed(true)
    end
end

function TrackerMemory:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(frame, event, name)
        if event == "PLAYER_REGEN_ENABLED" then frame:UnregisterEvent(event) end
        if event == "ADDON_LOADED" and name ~= "Blizzard_ObjectiveTracker" then return end
        self:Apply()
    end)
    self.eventFrame:RegisterEvent("ADDON_LOADED")
end

function TrackerMemory:OnEnable()
    self:Apply()
end

BOLT:RegisterModule("trackerMemory", TrackerMemory)
