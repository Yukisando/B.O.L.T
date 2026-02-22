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
local scanInProgress = false
local debounceTimer = nil

-- Time-budget: max ms of work per frame to stay imperceptible
local BUDGET_MS = 2
local DEBOUNCE_SECONDS = 1.0
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
    if debounceTimer then
        debounceTimer:Cancel()
        debounceTimer = nil
    end
    HideSpinner()
    snapshotReady = false
    scanInProgress = false
end

function AchievementTracker:RegisterEvents()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end

    self.eventFrame:RegisterEvent("CRITERIA_UPDATE")
    self.eventFrame:RegisterEvent("CRITERIA_COMPLETE")
    self.eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")

    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CRITERIA_UPDATE" then
            self:OnCriteriaUpdate()
        elseif event == "CRITERIA_COMPLETE" then
            self:OnCriteriaComplete(...)
        elseif event == "ACHIEVEMENT_EARNED" then
            self:OnAchievementEarned(...)
        end
    end)
end

function AchievementTracker:GetAchievementLink(achievementID)
    return GetAchievementLink(achievementID) or ("Achievement #" .. achievementID)
end

function AchievementTracker:OnAchievementEarned(achievementID, alreadyEarned)
    if alreadyEarned then return end
    local link = self:GetAchievementLink(achievementID)
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
    self.parent:Print("Criteria completed for " .. link)
end

function AchievementTracker:OnCriteriaUpdate()
    if not snapshotReady or scanInProgress then return end
    if debounceTimer then
        debounceTimer:Cancel()
    end
    debounceTimer = C_Timer.NewTimer(DEBOUNCE_SECONDS, function()
        debounceTimer = nil
        self:ScanForChanges()
    end)
end

-- Build snapshot of criteria state for all incomplete, non-guild, non-statistic achievements
function AchievementTracker:BuildSnapshot()
    if scanInProgress then return end
    scanInProgress = true
    snapshotReady = false

    incompleteAchievements = {}
    snapshot = {}
    criteriaLookup = {}

    ShowSpinner("Indexing achievements...")

    -- Phase 1: enumerate categories with a time budget per frame
    local categories = GetCategoryList()
    local catIndex = 1
    local allAchievements = {}
    local totalCategories = #categories

    local catTicker
    catTicker = C_Timer.NewTicker(0, function()
        local startTime = debugprofilestop()

        while catIndex <= totalCategories do
            local catID = categories[catIndex]
            local numAch = GetCategoryNumAchievements(catID, false)
            for i = 1, numAch do
                local id, _, _, completed, _, _, _, _, _, _, _, isGuild, _, _, isStatistic = GetAchievementInfo(catID, i)
                if id and not completed and not isGuild and not isStatistic then
                    allAchievements[id] = true
                end
            end
            catIndex = catIndex + 1

            if (debugprofilestop() - startTime) > (BUDGET_MS * 1000) then
                break
            end
        end

        local pct = math.floor((catIndex / totalCategories) * 50)
        UpdateSpinnerLabel("Indexing achievements... " .. pct .. "%")

        if catIndex > totalCategories then
            catTicker:Cancel()
            local achList = {}
            for id in pairs(allAchievements) do
                table.insert(achList, id)
            end
            self:BuildSnapshotPhase2(achList)
        end
    end)
end

-- Phase 2: iterate achievement list with a time budget to record criteria state
function AchievementTracker:BuildSnapshotPhase2(achList)
    local index = 1
    local total = #achList
    local ticker

    UpdateSpinnerLabel("Scanning criteria... 50%")

    ticker = C_Timer.NewTicker(0, function()
        local startTime = debugprofilestop()

        while index <= total do
            local achID = achList[index]
            local numCriteria = GetAchievementNumCriteria(achID)
            if numCriteria > 0 then
                local completedCount = 0
                local totalQuantity = 0

                for ci = 1, numCriteria do
                    local _, _, completed, quantity, _, _, _, _, _, criteriaID = GetAchievementCriteriaInfo(achID, ci)
                    if completed then completedCount = completedCount + 1 end
                    totalQuantity = totalQuantity + (quantity or 0)
                    if criteriaID and criteriaID > 0 then
                        criteriaLookup[criteriaID] = achID
                    end
                end

                snapshot[achID] = {
                    completed = completedCount,
                    quantity = totalQuantity,
                }
            end

            index = index + 1

            if (debugprofilestop() - startTime) > (BUDGET_MS * 1000) then
                break
            end
        end

        local pct = 50 + math.floor((index / total) * 50)
        UpdateSpinnerLabel("Scanning criteria... " .. math.min(pct, 100) .. "%")

        if index > total then
            ticker:Cancel()
            for achID in pairs(snapshot) do
                table.insert(incompleteAchievements, achID)
            end
            snapshotReady = true
            scanInProgress = false
            HideSpinner()
            self.parent:Debug("Achievement Tracker: ready (" .. #incompleteAchievements .. " tracked)")
        end
    end)
end

-- Compare current criteria state against snapshot and report changes
function AchievementTracker:ScanForChanges()
    if not snapshotReady or scanInProgress then return end
    scanInProgress = true

    local index = 1
    local changedAchievements = {}
    local completedAchievements = {}
    local ticker

    ticker = C_Timer.NewTicker(0, function()
        local startTime = debugprofilestop()

        while index <= #incompleteAchievements do
            local achID = incompleteAchievements[index]
            local old = snapshot[achID]
            if old then
                local _, _, _, nowCompleted = GetAchievementInfo(achID)
                if nowCompleted then
                    table.insert(completedAchievements, achID)
                    snapshot[achID] = nil
                else
                    local numCriteria = GetAchievementNumCriteria(achID)
                    local completedCount = 0
                    local totalQuantity = 0

                    for ci = 1, numCriteria do
                        local _, _, completed, quantity, _, _, _, _, _, criteriaID = GetAchievementCriteriaInfo(achID, ci)
                        if completed then completedCount = completedCount + 1 end
                        totalQuantity = totalQuantity + (quantity or 0)
                        -- Update any new criteria IDs discovered
                        if criteriaID and criteriaID > 0 then
                            criteriaLookup[criteriaID] = achID
                        end
                    end

                    if completedCount > old.completed or totalQuantity > old.quantity then
                        table.insert(changedAchievements, achID)
                        snapshot[achID] = {
                            completed = completedCount,
                            quantity = totalQuantity,
                        }
                    end
                end
            end

            index = index + 1

            if (debugprofilestop() - startTime) > (BUDGET_MS * 1000) then
                break
            end
        end

        if index > #incompleteAchievements then
            ticker:Cancel()

            -- Prune completed achievements from the tracking list
            if #completedAchievements > 0 then
                local completedSet = {}
                for _, id in ipairs(completedAchievements) do completedSet[id] = true end
                local pruned = {}
                for _, id in ipairs(incompleteAchievements) do
                    if not completedSet[id] then
                        table.insert(pruned, id)
                    end
                end
                incompleteAchievements = pruned
            end

            scanInProgress = false

            -- Report progress (capped to avoid chat spam)
            local count = #changedAchievements
            if count > 0 then
                local shown = math.min(count, MAX_MESSAGES_PER_SCAN)
                for i = 1, shown do
                    local link = self:GetAchievementLink(changedAchievements[i])
                    self.parent:Print("Progress on " .. link)
                end
                if count > shown then
                    self.parent:Print("...and " .. (count - shown) .. " more achievement(s) progressed.")
                end
            end
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
