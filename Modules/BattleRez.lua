local ADDON_NAME, BOLT = ...

local BattleRez = {}

local MAX_BATTLE_REZ_CHARGES = 5
local BATTLE_REZ_RECHARGE_SECONDS = 600
local GetCombatLogEventInfo = C_CombatLog and C_CombatLog.GetCurrentEventInfo
local COMBAT_RES_SPELL_IDS = {
    [20484] = true,
    [20707] = true,
    [61999] = true,
    [391054] = true,
}

local function FindChallengeTimer()
    if not GetWorldElapsedTimers or not GetWorldElapsedTime or not Enum or not Enum.WorldElapsedTimerTypes then
        return nil, nil
    end

    for index = 1, select("#", GetWorldElapsedTimers()) do
        local timerID = select(index, GetWorldElapsedTimers())
        if timerID then
            local _, elapsedTime, timerType = GetWorldElapsedTime(timerID)
            if timerType == Enum.WorldElapsedTimerTypes.ChallengeMode then
                return timerID, elapsedTime or 0
            end
        end
    end

    return nil, nil
end

local function GetTrackedUnitByGUID(guid)
    if not guid then
        return nil
    end

    if UnitGUID("player") == guid then
        return "player"
    end

    for index = 1, GetNumSubgroupMembers() do
        local unit = "party" .. index
        if UnitGUID(unit) == guid then
            return unit
        end
    end

    return nil
end

function BattleRez:OnInitialize()
    self.usedCharges = 0
    self.elapsedTime = 0
    self.activeTimerID = nil
    self.recentResurrections = {}
    self.updateThrottle = 0
end

function BattleRez:OnEnable()
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
    end

    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("SCENARIO_UPDATE")
    self.eventFrame:RegisterEvent("WORLD_STATE_TIMER_START")
    self.eventFrame:RegisterEvent("WORLD_STATE_TIMER_STOP")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
    self.eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        self:OnEvent(event, ...)
    end)
    self.eventFrame:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    self:RefreshTimerState(true)
end

function BattleRez:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame:SetScript("OnUpdate", nil)
    end

    self.activeTimerID = nil
    self.usedCharges = 0
    self.elapsedTime = 0
    self:HideDisplay()
end

function BattleRez:OnEvent(event, ...)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:HandleCombatLogEvent()
        return
    end

    local resetUsage = event == "CHALLENGE_MODE_START"
    self:RefreshTimerState(resetUsage)
end

function BattleRez:OnUpdate(elapsed)
    self.updateThrottle = self.updateThrottle + elapsed
    if self.updateThrottle < 0.2 then
        return
    end

    self.updateThrottle = 0
    self:RefreshTimerState(false)
end

function BattleRez:RefreshTimerState(resetUsage)
    local timerID, elapsedTime = FindChallengeTimer()
    if timerID ~= self.activeTimerID then
        self.activeTimerID = timerID
        self.usedCharges = 0
        wipe(self.recentResurrections)
    elseif resetUsage then
        self.usedCharges = 0
        wipe(self.recentResurrections)
    end

    self.elapsedTime = elapsedTime or 0

    if not self.activeTimerID then
        self:HideDisplay()
        return
    end

    self:UpdateDisplay()
end

function BattleRez:HandleCombatLogEvent()
    if not self.activeTimerID or not GetCombatLogEventInfo then
        return
    end

    local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, spellID = GetCombatLogEventInfo()
    if subEvent ~= "SPELL_RESURRECT" or not COMBAT_RES_SPELL_IDS[spellID] then
        return
    end

    local sourceUnit = GetTrackedUnitByGUID(sourceGUID)
    if not sourceUnit or not UnitAffectingCombat(sourceUnit) then
        return
    end

    local eventKey = tostring(spellID) .. ":" .. tostring(destGUID)
    local now = GetTime()
    local lastSeen = self.recentResurrections[eventKey]
    if lastSeen and (now - lastSeen) < 2 then
        return
    end

    self.recentResurrections[eventKey] = now
    self.usedCharges = self.usedCharges + 1
    self:UpdateDisplay()
end

function BattleRez:GetAvailableCharges()
    local generatedCharges = math.min(MAX_BATTLE_REZ_CHARGES, 1 + math.floor((self.elapsedTime or 0) / BATTLE_REZ_RECHARGE_SECONDS))
    return math.max(0, generatedCharges - (self.usedCharges or 0)), generatedCharges
end

function BattleRez:GetNextChargeTime()
    local _, generatedCharges = self:GetAvailableCharges()
    if generatedCharges >= MAX_BATTLE_REZ_CHARGES then
        return nil
    end

    local secondsIntoCycle = (self.elapsedTime or 0) % BATTLE_REZ_RECHARGE_SECONDS
    local secondsRemaining = BATTLE_REZ_RECHARGE_SECONDS - secondsIntoCycle
    if secondsRemaining == BATTLE_REZ_RECHARGE_SECONDS then
        secondsRemaining = 0
    end

    return secondsRemaining
end

function BattleRez:EnsureDisplay()
    if self.displayFrame then
        return self.displayFrame
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(34, 16)
    frame:EnableMouse(true)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", frame, "LEFT", 0, 0)
    icon:SetAtlas("RaidFrame-Icon-Rez", true)
    frame.Icon = icon

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    text:SetJustifyH("LEFT")
    frame.Text = text

    frame:SetScript("OnEnter", function(widget)
        self:ShowTooltip(widget)
    end)
    frame:SetScript("OnLeave", function()
        GameTooltip_Hide()
    end)

    self.displayFrame = frame
    return frame
end

function BattleRez:ShowTooltip(widget)
    if not widget or not widget:IsShown() then
        return
    end

    local availableCharges, generatedCharges = self:GetAvailableCharges()
    local nextChargeTime = self:GetNextChargeTime()

    GameTooltip:SetOwner(widget, "ANCHOR_LEFT")
    GameTooltip:AddLine("Battle Resurrection")
    GameTooltip:AddLine(("Available charges: %d/%d"):format(availableCharges, MAX_BATTLE_REZ_CHARGES), 1, 1, 1)
    GameTooltip:AddLine(("Generated this run: %d"):format(generatedCharges), 0.85, 0.85, 0.85)
    GameTooltip:AddLine(("Tracked res casts: %d"):format(self.usedCharges or 0), 0.85, 0.85, 0.85)
    if nextChargeTime and nextChargeTime > 0 then
        GameTooltip:AddLine(("Next charge in %s"):format(SecondsToClock(nextChargeTime, false)), 0.65, 0.82, 1)
    end
    GameTooltip:AddLine("Tracking is based on the Mythic+ timer and observed combat-res casts in the current run.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

function BattleRez:UpdateAnchor(frame)
    local challengeBlock = ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock
    if not challengeBlock then
        frame:Hide()
        return false
    end

    if frame:GetParent() ~= challengeBlock then
        frame:SetParent(challengeBlock)
    end

    frame:SetFrameStrata(challengeBlock:GetFrameStrata())
    frame:SetFrameLevel(challengeBlock:GetFrameLevel() + 5)
    frame:ClearAllPoints()

    if challengeBlock.DeathCount and challengeBlock.DeathCount:IsShown() then
        frame:SetPoint("LEFT", challengeBlock.DeathCount, "RIGHT", 10, 0)
    elseif challengeBlock.Level and challengeBlock.Level:IsShown() then
        frame:SetPoint("LEFT", challengeBlock.Level, "RIGHT", 10, 0)
    elseif challengeBlock.StatusBar then
        frame:SetPoint("TOPRIGHT", challengeBlock.StatusBar, "TOPLEFT", -8, 0)
    else
        frame:SetPoint("TOPRIGHT", challengeBlock, "TOPRIGHT", -8, -16)
    end

    return true
end

function BattleRez:UpdateDisplay()
    local frame = self:EnsureDisplay()
    if not self:UpdateAnchor(frame) then
        return
    end

    local availableCharges = self:GetAvailableCharges()
    frame.Text:SetText(tostring(availableCharges))

    if availableCharges == 0 then
        frame.Text:SetTextColor(1, 0.2, 0.2)
    else
        frame.Text:SetTextColor(1, 0.82, 0.3)
    end

    frame:Show()
end

function BattleRez:HideDisplay()
    if self.displayFrame then
        self.displayFrame:Hide()
    end

    if GameTooltip and self.displayFrame and GameTooltip:GetOwner() == self.displayFrame then
        GameTooltip_Hide()
    end
end

BOLT:RegisterModule("battleRez", BattleRez)