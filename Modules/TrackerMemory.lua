-- B.O.L.T Tracker Memory Module
-- The objective tracker ("All Objectives") stays collapsed or open the way you left it, across
-- reloads and logins (every character). Blizzard opens it again every time.
-- Only your own clicks on its collapse button are remembered: the game opening it by itself
-- (tracking a new quest, say) doesn't change what comes back next time.
-- Always on, no setting.
--
-- The fold is visual only: the tracker's parts go invisible and a copy of the "expand" button sits
-- on its header. Calling Blizzard's SetCollapsed from addon code tainted the whole tracker, and
-- its next update then failed on secret auras in instances (Blizzard_MawBuffs, 2026-11-16).

local ADDON_NAME, BOLT = ...

local TrackerMemory = {
    displayName = "Objective Tracker Memory",
    alwaysOn = true,
}

local hooked = false
local folded = false
local expandButton, keeper
-- The background's alpha as Blizzard last set it (Edit Mode's opacity for the tracker): folding
-- hides it, unfolding puts back this value, not 1. Putting back 1 gave the tracker a fully dark
-- background after it opened again (2026-11-25).
local backgroundAlpha
local settingBackground = false

local function Tracker()
    local tracker = ObjectiveTrackerFrame
    if tracker and tracker.IsCollapsed and tracker.Header and tracker.Header.MinimizeButton then
        return tracker
    end
end

-- Everything under the header: the modules and the background.
local function SetPartsAlpha(tracker, alpha)
    for _, module in ipairs(tracker.modules or {}) do
        if module:GetAlpha() ~= alpha then module:SetAlpha(alpha) end
    end
    local background = tracker.NineSlice
    if background then
        local want = alpha == 0 and 0 or (backgroundAlpha or 1)
        if math.abs(background:GetAlpha() - want) > 0.001 then
            settingBackground = true
            background:SetAlpha(want)
            settingBackground = false
        end
    end
end

local function Unfold(tracker)
    if not folded then return end
    folded = false
    keeper:Hide()
    expandButton:Hide()
    SetPartsAlpha(tracker, 1)
end

local function Fold(tracker)
    if folded then return end
    folded = true
    expandButton:Show()
    keeper:Show()
    SetPartsAlpha(tracker, 0)
end

local function Setup(tracker)
    if hooked then return end
    hooked = true
    local button = tracker.Header.MinimizeButton

    local background = tracker.NineSlice
    if background then
        backgroundAlpha = background:GetAlpha()
        hooksecurefunc(background, "SetAlpha", function(_, alpha)
            if settingBackground then return end
            backgroundAlpha = alpha
            if folded then
                settingBackground = true
                background:SetAlpha(0)
                settingBackground = false
            end
        end)
    end

    -- Blizzard's own button: a real collapse or expand, remembered as is.
    button:HookScript("OnClick", function()
        BOLTDB.trackerCollapsed = tracker:IsCollapsed() and true or false
    end)

    -- Our "expand" button over it while the tracker is folded.
    expandButton = CreateFrame("Button", nil, tracker.Header)
    expandButton:SetAllPoints(button)
    expandButton:SetFrameLevel(button:GetFrameLevel() + 5)
    expandButton:SetNormalAtlas("ui-questtrackerbutton-expand-all")
    expandButton:SetPushedAtlas("ui-questtrackerbutton-expand-all-pressed")
    expandButton:SetHighlightAtlas("ui-questtrackerbutton-red-highlight", "ADD")
    expandButton:Hide()
    expandButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        BOLTDB.trackerCollapsed = false
        Unfold(tracker)
    end)

    -- Blizzard shows modules and fades their art while it updates: keep them hidden while folded.
    keeper = CreateFrame("Frame", nil, tracker.Header)
    keeper:Hide()
    keeper:SetScript("OnUpdate", function()
        if tracker:IsCollapsed() then Unfold(tracker) else SetPartsAlpha(tracker, 0) end
    end)

    -- The game opening the tracker by itself (a new quest tracked) shows it, like Blizzard does.
    hooksecurefunc(tracker, "ForceExpand", function() Unfold(tracker) end)
end

function TrackerMemory:Apply()
    local tracker = Tracker()
    if not tracker then return end
    Setup(tracker)
    if BOLTDB.trackerCollapsed and not tracker:IsCollapsed() then Fold(tracker) end
end

function TrackerMemory:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(frame, event, name)
        if name ~= "Blizzard_ObjectiveTracker" then return end
        self:Apply()
    end)
    self.eventFrame:RegisterEvent("ADDON_LOADED")
end

function TrackerMemory:OnEnable()
    self:Apply()
end

BOLT:RegisterModule("trackerMemory", TrackerMemory)
