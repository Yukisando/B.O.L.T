local ADDON_NAME, BOLT = ...

local BattleRez = {}
BattleRez.alwaysInitialize = true

local MAX_BATTLE_REZ_CHARGES = 5
local BATTLE_REZ_RECHARGE_SECONDS = 600
local GetCombatLogEventInfo = C_CombatLog and C_CombatLog.GetCurrentEventInfo
local COMBAT_RES_SPELL_IDS = {
    [20484] = true,
    [20707] = true,
    [61999] = true,
    [391054] = true,
}

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

local function GetChallengeBlock()
    return ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock or nil
end

local function GetBlockElapsedTime(block)
    if not block or not block.timeLimit or not block.StatusBar or not block.StatusBar.GetValue then
        return nil
    end

    local timeLeft = block.StatusBar:GetValue()
    if type(timeLeft) ~= "number" then
        return nil
    end

    return math.max(0, block.timeLimit - timeLeft)
end

function BattleRez:OnInitialize()
    self.usedCharges = 0
    self.elapsedTime = 0
    self.activeTimerID = nil
    self.recentResurrections = {}
    self.isEnabled = false
    self.hooksInstalled = false

    self:InstallHooks()
end

function BattleRez:InstallHooks()
    if self.hooksInstalled then
        return
    end

    self.hooksInstalled = true

    if type(ScenarioObjectiveTrackerChallengeModeMixin) == "table" then
        hooksecurefunc(ScenarioObjectiveTrackerChallengeModeMixin, "Activate", function(block, timerID, elapsedTime)
            self:HandleTrackerActivated(block, timerID, elapsedTime)
        end)

        hooksecurefunc(ScenarioObjectiveTrackerChallengeModeMixin, "UpdateTime", function(block, elapsedTime)
            self:HandleTrackerTimeUpdated(block, elapsedTime)
        end)

        hooksecurefunc(ScenarioObjectiveTrackerChallengeModeMixin, "UpdateDeathCount", function(block)
            self:HandleTrackerLayoutChanged(block)
        end)
    end

    if type(ScenarioTimerMixin) == "table" then
        hooksecurefunc(ScenarioTimerMixin, "StopTimer", function()
            self:HandleTrackerStopped()
        end)
    end

    local combatLogProcessor = _G["CombatLogProcessor"]
    if type(combatLogProcessor) == "table" and type(combatLogProcessor.ProcessCurrentCombatEvent) == "function" then
        hooksecurefunc(combatLogProcessor, "ProcessCurrentCombatEvent", function()
            self:HandleCombatLogEvent()
        end)
    end
end

function BattleRez:SyncFromActiveTracker(resetUsage)
    local block = GetChallengeBlock()
    if not block or not block.timerID then
        self:HandleTrackerStopped()
        return
    end

    self:HandleTrackerActivated(block, block.timerID, GetBlockElapsedTime(block), resetUsage)
end

function BattleRez:OnEnable()
    self.isEnabled = true
    self:SyncFromActiveTracker(true)
end

function BattleRez:OnDisable()
    self.isEnabled = false

    self.activeTimerID = nil
    self.usedCharges = 0
    self.elapsedTime = 0
    wipe(self.recentResurrections)
    self:HideDisplay()
end

function BattleRez:HandleTrackerActivated(block, timerID, elapsedTime, resetUsage)
    if not block or not timerID then
        return
    end

    if timerID ~= self.activeTimerID or resetUsage then
        self.usedCharges = 0
        wipe(self.recentResurrections)
    end

    self.activeTimerID = timerID
    self.elapsedTime = elapsedTime or GetBlockElapsedTime(block) or 0

    if self.isEnabled then
        self:UpdateDisplay()
    end
end

function BattleRez:HandleTrackerTimeUpdated(block, elapsedTime)
    if not block or block.timerID ~= self.activeTimerID then
        if block and block.timerID then
            self:HandleTrackerActivated(block, block.timerID, elapsedTime)
        end
        return
    end

    self.elapsedTime = elapsedTime or GetBlockElapsedTime(block) or self.elapsedTime or 0
    if self.isEnabled then
        self:UpdateDisplay()
    end
end

function BattleRez:HandleTrackerLayoutChanged(block)
    if self.isEnabled and block and block.timerID then
        self:UpdateDisplay()
    end
end

function BattleRez:HandleTrackerStopped()
    self.activeTimerID = nil
    self.elapsedTime = 0
    self.usedCharges = 0
    wipe(self.recentResurrections)

    if self.isEnabled then
        self:HideDisplay()
    end
end

function BattleRez:HandleCombatLogEvent()
    if not self.isEnabled or not self.activeTimerID or not GetCombatLogEventInfo then
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
    if not self.activeTimerID then
        return 0, 0
    end

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
    frame:SetSize(20, 20)
    frame:EnableMouse(true)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    icon:SetAtlas("RaidFrame-Icon-Rez", true)
    frame.Icon = icon

    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER", icon, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
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
    GameTooltip:AddLine("Tracking is based on Blizzard's Mythic+ tracker timer plus combat-log callback events for successful battle res casts.", 0.7, 0.7, 0.7, true)
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

    if challengeBlock.Level and challengeBlock.Level:IsShown() then
        frame:SetPoint("RIGHT", challengeBlock.Level, "LEFT", -10, 0)
    elseif challengeBlock.DeathCount and challengeBlock.DeathCount:IsShown() then
        frame:SetPoint("RIGHT", challengeBlock.DeathCount, "LEFT", -10, 0)
    elseif challengeBlock.StatusBar then
        frame:SetPoint("TOPRIGHT", challengeBlock.StatusBar, "TOPLEFT", -8, 0)
    else
        frame:SetPoint("TOPRIGHT", challengeBlock, "TOPLEFT", -8, -16)
    end

    return true
end

function BattleRez:UpdateDisplay()
    if not self.activeTimerID then
        self:HideDisplay()
        return
    end

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