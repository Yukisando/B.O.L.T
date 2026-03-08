-- B.O.L.T Achievement Progress Tracker Module
-- Detects and reports when the player makes progress on any achievement

local ADDON_NAME, BOLT = ...

local AchievementTracker = {}

-- Snapshot: achievementID → { completed = count, quantity = totalQty }
local snapshot = {}
-- Reverse lookup: criteriaID → achievementID
local criteriaLookup = {}
-- Ordered list of incomplete achievement IDs (built once, pruned on completion)
local incompleteAchievements = {}

local snapshotReady = false
local busy = false
local rescanPending = false
local debounceTimer = nil
local activeTicker = nil

local BUDGET_US = 500          -- max microseconds per frame (~0.5ms)
local DEBOUNCE_SECONDS = 0.5
local MAX_MESSAGES_PER_SCAN = 5

local SPINNER_FRAMES = { "|cff00aaff⠋|r", "|cff00aaff⠙|r", "|cff00aaff⠹|r", "|cff00aaff⠸|r", "|cff00aaff⠼|r", "|cff00aaff⠴|r", "|cff00aaff⠦|r", "|cff00aaff⠧|r", "|cff00aaff⠇|r", "|cff00aaff⠏|r" }

-- Spinner UI anchored near the minimap
local spinnerFrame, spinnerText, spinnerTick, spinnerIdx

local function CreateSpinner()
    if spinnerFrame then return end
    spinnerFrame = CreateFrame("Frame", nil, MinimapCluster or UIParent)
    spinnerFrame:SetSize(220, 16)
    spinnerFrame:SetPoint("TOP", MinimapCluster or UIParent, "BOTTOM", 0, -4)
    spinnerFrame:SetFrameStrata("HIGH")
    spinnerText = spinnerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spinnerText:SetPoint("CENTER")
    spinnerFrame:Hide()
end

local function ShowSpinner(label)
    CreateSpinner()
    spinnerIdx = 1
    spinnerFrame:Show()
    spinnerText:SetText(SPINNER_FRAMES[1] .. " " .. label)
    spinnerTick = C_Timer.NewTicker(0.1, function()
        spinnerIdx = (spinnerIdx % #SPINNER_FRAMES) + 1
        if spinnerText then
            spinnerText:SetText(SPINNER_FRAMES[spinnerIdx] .. " " .. label)
        end
    end)
end

local function UpdateSpinnerLabel(label)
    if spinnerText then
        spinnerText:SetText(SPINNER_FRAMES[spinnerIdx or 1] .. " " .. label)
    end
end

local function HideSpinner()
    if spinnerTick then spinnerTick:Cancel(); spinnerTick = nil end
    if spinnerFrame then spinnerFrame:Hide() end
end

---------------------------------------------------------------------------
-- Raid-warning style alert display
---------------------------------------------------------------------------
local alertFrame

local function ShowAlert(text)
    if not alertFrame then
        alertFrame = CreateFrame("Frame", nil, UIParent)
        alertFrame:SetSize(600, 50)
        alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
        alertFrame:SetFrameStrata("HIGH")
        local fs = alertFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 22, "OUTLINE")
        fs:SetPoint("CENTER")
        fs:SetTextColor(0, 0.67, 1)
        alertFrame.text = fs
        alertFrame.anim = alertFrame:CreateAnimationGroup()
        local fadeIn = alertFrame.anim:CreateAnimation("Alpha")
        fadeIn:SetFromAlpha(0)
        fadeIn:SetToAlpha(1)
        fadeIn:SetDuration(0.3)
        fadeIn:SetOrder(1)
        local hold = alertFrame.anim:CreateAnimation("Alpha")
        hold:SetFromAlpha(1)
        hold:SetToAlpha(1)
        hold:SetDuration(2.5)
        hold:SetOrder(2)
        local fadeOut = alertFrame.anim:CreateAnimation("Alpha")
        fadeOut:SetFromAlpha(1)
        fadeOut:SetToAlpha(0)
        fadeOut:SetDuration(0.8)
        fadeOut:SetOrder(3)
        alertFrame.anim:SetScript("OnFinished", function() alertFrame:Hide() end)
    end
    alertFrame.text:SetText(text)
    alertFrame:SetAlpha(0)
    alertFrame:Show()
    alertFrame.anim:Stop()
    alertFrame.anim:Play()
end

---------------------------------------------------------------------------
-- Coroutine scheduler: resumes fn once per frame within a time budget
---------------------------------------------------------------------------
local function CheckBudget(t0)
    if (debugprofilestop() - t0) > BUDGET_US then
        coroutine.yield()
        return debugprofilestop()
    end
    return t0
end

local function RunAsync(fn, onDone)
    if activeTicker then activeTicker:Cancel() end
    local co = coroutine.create(fn)
    activeTicker = C_Timer.NewTicker(0, function()
        if coroutine.status(co) == "dead" then
            activeTicker:Cancel()
            activeTicker = nil
            if onDone then onDone() end
            return
        end
        local ok, err = coroutine.resume(co)
        if not ok then
            activeTicker:Cancel()
            activeTicker = nil
        end
    end)
end

-- Read all criteria for an achievement, updating criteriaLookup as a side-effect
local function ReadCriteria(achID)
    local n = GetAchievementNumCriteria(achID)
    local done, qty = 0, 0
    for ci = 1, n do
        local _, _, completed, quantity, _, _, _, _, _, criteriaID = GetAchievementCriteriaInfo(achID, ci)
        if completed then done = done + 1 end
        qty = qty + (quantity or 0)
        if criteriaID and criteriaID > 0 then
            criteriaLookup[criteriaID] = achID
        end
    end
    return done, qty, n
end

-- Returns sorted list of { id, name } for top-level achievement categories
function AchievementTracker:GetTopLevelCategories()
    local cats = GetCategoryList()
    local top = {}
    for _, catID in ipairs(cats) do
        local name, parentID = GetCategoryInfo(catID)
        if parentID == -1 and name and name ~= "" then
            top[#top + 1] = { id = catID, name = name }
        end
    end
    table.sort(top, function(a, b) return a.name < b.name end)
    return top
end

function AchievementTracker:GetTrackedCategorySet()
    local saved = self.parent:GetConfig("achievementTracker", "trackedCategories")
    if not saved or not next(saved) then return nil end  -- nil = track all
    if saved["__none"] then return {} end  -- explicit "none selected"
    return saved
end

function AchievementTracker:SetCategoryTracked(catID, enabled)
    local saved = self.parent:GetConfig("achievementTracker", "trackedCategories") or {}
    saved["__none"] = nil  -- clear sentinel when manually toggling
    saved[catID] = enabled or nil
    self.parent:SetConfig(saved, "achievementTracker", "trackedCategories")
end

function AchievementTracker:IsCategoryTracked(catID)
    local saved = self.parent:GetConfig("achievementTracker", "trackedCategories")
    if not saved or not next(saved) then return true end  -- empty = all tracked
    if saved["__none"] then return false end  -- explicit none
    return saved[catID] == true
end

-- Build a set of all category IDs (including children) for the tracked top-level categories
function AchievementTracker:BuildTrackedCategoryIDs()
    local filter = self:GetTrackedCategorySet()
    if not filter then return nil end  -- nil = no filter, track everything

    local allCats = GetCategoryList()
    -- Map each category to its top-level ancestor
    local parentMap = {}
    for _, catID in ipairs(allCats) do
        local _, parentID = GetCategoryInfo(catID)
        parentMap[catID] = parentID
    end

    local function GetRoot(catID)
        local seen = {}
        while parentMap[catID] and parentMap[catID] ~= -1 do
            if seen[catID] then break end
            seen[catID] = true
            catID = parentMap[catID]
        end
        return catID
    end

    local allowed = {}
    for _, catID in ipairs(allCats) do
        local root = GetRoot(catID)
        if filter[root] then
            allowed[catID] = true
        end
    end
    return allowed
end

function AchievementTracker:OnInitialize()
    self:HookMinimapTrackingMenu()
end

function AchievementTracker:OnEnable()
    self:RegisterEvents()
    C_Timer.After(3, function()
        self:BuildSnapshot()
    end)
end

function AchievementTracker:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
    if debounceTimer then debounceTimer:Cancel(); debounceTimer = nil end
    if activeTicker then activeTicker:Cancel(); activeTicker = nil end
    HideSpinner()
    snapshotReady = false
    busy = false
    rescanPending = false
end

function AchievementTracker:RegisterEvents()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end

    self.eventFrame:RegisterEvent("CRITERIA_UPDATE")
    self.eventFrame:RegisterEvent("CRITERIA_COMPLETE")
    self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")
    self.eventFrame:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE")
    self.eventFrame:RegisterEvent("QUEST_TURNED_IN")
    self.eventFrame:RegisterEvent("LOOT_OPENED")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "ACHIEVEMENT_EARNED" then
            self:OnAchievementEarned(...)
        elseif event == "CRITERIA_COMPLETE" then
            self:OnCriteriaComplete(...)
        else
            self:OnCriteriaUpdate()
        end
    end)
end

function AchievementTracker:GetAchievementLink(achievementID)
    return GetAchievementLink(achievementID) or ("Achievement #" .. achievementID)
end

function AchievementTracker:OnAchievementEarned(achievementID, alreadyEarned)
    if alreadyEarned then return end
    local link = self:GetAchievementLink(achievementID)
    ShowAlert("Achievement completed: " .. link .. "!")
    self.parent:Print("Achievement completed: " .. link .. "!")
    snapshot[achievementID] = nil
end

function AchievementTracker:OnCriteriaComplete(criteriaID)
    if not snapshotReady then return end
    local achievementID = criteriaLookup[criteriaID]
    if not achievementID then return end

    local _, _, _, completed = GetAchievementInfo(achievementID)
    if completed then return end

    local link = self:GetAchievementLink(achievementID)
    ShowAlert("Criteria completed for " .. link)
    self.parent:Print("Criteria completed for " .. link)
end

function AchievementTracker:OnCriteriaUpdate()
    if not snapshotReady then return end
    if busy then
        rescanPending = true
        return
    end
    if debounceTimer then debounceTimer:Cancel() end
    debounceTimer = C_Timer.NewTimer(DEBOUNCE_SECONDS, function()
        debounceTimer = nil
        self:ScanForChanges()
    end)
end

-- Build snapshot of criteria state for all incomplete achievements
function AchievementTracker:BuildSnapshot()
    if busy then return end
    busy = true
    snapshotReady = false
    snapshot = {}
    criteriaLookup = {}
    incompleteAchievements = {}

    ShowSpinner("Indexing achievements...")

    RunAsync(function()
        local categories = GetCategoryList()
        local allowedCats = self:BuildTrackedCategoryIDs()
        local found = {}
        local t0 = debugprofilestop()

        -- Phase 1: collect incomplete achievement IDs from filtered categories
        for ci = 1, #categories do
            local catID = categories[ci]
            if not allowedCats or allowedCats[catID] then
                local numAch = GetCategoryNumAchievements(catID, false)
                for i = 1, numAch do
                    local id, _, _, completed, _, _, _, _, _, _, _, isGuild, _, _, isStatistic =
                        GetAchievementInfo(catID, i)
                    if id and not completed and not isGuild and not isStatistic then
                        found[#found + 1] = id
                    end
                    t0 = CheckBudget(t0)
                end
            end
        end

        UpdateSpinnerLabel("Scanning criteria...")

        -- Phase 2: snapshot criteria state for each achievement
        for i = 1, #found do
            local done, qty, n = ReadCriteria(found[i])
            if n > 0 then
                snapshot[found[i]] = { completed = done, quantity = qty }
            end
            t0 = CheckBudget(t0)
        end

        -- Phase 3: build ordered tracking list
        for achID in pairs(snapshot) do
            incompleteAchievements[#incompleteAchievements + 1] = achID
        end
    end, function()
        snapshotReady = true
        busy = false
        HideSpinner()
        self.parent:Debug("Achievement Tracker: ready (" .. #incompleteAchievements .. " tracked)")
    end)
end

-- Compare current criteria state against snapshot and report changes
function AchievementTracker:ScanForChanges()
    if not snapshotReady or busy then return end
    busy = true

    local changed = {}
    local completed = {}

    RunAsync(function()
        local t0 = debugprofilestop()

        for i = 1, #incompleteAchievements do
            local achID = incompleteAchievements[i]
            local old = snapshot[achID]
            if old then
                local _, _, _, nowCompleted = GetAchievementInfo(achID)
                if nowCompleted then
                    completed[#completed + 1] = achID
                    snapshot[achID] = nil
                else
                    local done, qty = ReadCriteria(achID)
                    if done > old.completed or qty > old.quantity then
                        changed[#changed + 1] = achID
                        snapshot[achID] = { completed = done, quantity = qty }
                    end
                end
            end
            t0 = CheckBudget(t0)
        end

        -- Prune completed achievements from the tracking list
        if #completed > 0 then
            local set = {}
            for _, id in ipairs(completed) do set[id] = true end
            local pruned = {}
            for _, id in ipairs(incompleteAchievements) do
                if not set[id] then pruned[#pruned + 1] = id end
            end
            incompleteAchievements = pruned
        end
    end, function()
        busy = false

        -- Report progress with alert + chat
        local count = #changed
        if count > 0 then
            local shown = math.min(count, MAX_MESSAGES_PER_SCAN)
            for i = 1, shown do
                local msg = "Progress on " .. self:GetAchievementLink(changed[i])
                ShowAlert(msg)
                self.parent:Print(msg)
            end
            if count > shown then
                self.parent:Print("...and " .. (count - shown) .. " more achievement(s) progressed.")
            end
        end

        -- If events fired while we were scanning, trigger another scan
        if rescanPending then
            rescanPending = false
            self:OnCriteriaUpdate()
        end
    end)
end

-- Inject toggles into the native minimap tracking dropdown menu
function AchievementTracker:HookMinimapTrackingMenu()
    if not Menu or not Menu.ModifyMenu then return end

    local bolt = self.parent
    Menu.ModifyMenu("MENU_MINIMAP_TRACKING", function(owner, rootDescription, contextData)
        rootDescription:CreateDivider()
        rootDescription:CreateTitle("|cff00aaffB.O.L.T|r")

        local modules = {
            { key = "achievementTracker", label = "Achievement Progress" },
            { key = "chatNotifier",       label = "Chat Notifier" },
            { key = "autoRepSwitch",      label = "Auto Rep Switch" },
        }

        for _, mod in ipairs(modules) do
            local key = mod.key
            rootDescription:CreateCheckbox(
                mod.label,
                function() return bolt:IsModuleEnabled(key) end,
                function()
                    bolt:SetModuleEnabled(key, not bolt:IsModuleEnabled(key))
                end
            )
        end
    end)
end

BOLT:RegisterModule("achievementTracker", AchievementTracker)
