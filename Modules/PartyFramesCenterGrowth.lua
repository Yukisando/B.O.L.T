local ADDON_NAME, BOLT = ...

local PartyFramesCenterGrowth = {}

local MAX_PARTY_UNITS = 5
local POLL_INTERVAL = 0.1

local frame
local eventFrame
local isEnabled = false
local hookInstalled = false
local pendingUpdate = false
local lastAppliedX = 0
local lastAppliedY = 0
local lastExpectedPoint
local lastExpectedRelativePoint
local lastExpectedX
local lastExpectedY

local function ApproximatelyEqual(a, b)
    return math.abs((a or 0) - (b or 0)) < 0.5
end

local function RecordExpectedAnchor(point, relativePoint, xOfs, yOfs)
    lastExpectedPoint = point
    lastExpectedRelativePoint = relativePoint
    lastExpectedX = xOfs
    lastExpectedY = yOfs
end

local function WasExternallyReset(point, relativePoint, xOfs, yOfs)
    if not lastExpectedPoint then
        return false
    end

    if point ~= lastExpectedPoint or relativePoint ~= lastExpectedRelativePoint then
        return true
    end

    return not ApproximatelyEqual(xOfs, lastExpectedX) or not ApproximatelyEqual(yOfs, lastExpectedY)
end

local function IsRaidStylePartyEnabled()
    return EditModeManagerFrame
        and EditModeManagerFrame.UseRaidStylePartyFrames
        and EditModeManagerFrame:UseRaidStylePartyFrames()
end

local function GetDisplayedMemberCount(compactPartyFrame)
    local shown = 0
    if compactPartyFrame and compactPartyFrame.memberUnitFrames then
        for _, unitFrame in ipairs(compactPartyFrame.memberUnitFrames) do
            if unitFrame:IsShown() then
                shown = shown + 1
            end
        end
    end

    if shown > 0 then
        return math.min(MAX_PARTY_UNITS, shown)
    end

    if EditModeManagerFrame and EditModeManagerFrame.ArePartyFramesForcedShown and EditModeManagerFrame:ArePartyFramesForcedShown() then
        return MAX_PARTY_UNITS
    end

    if IsInRaid and IsInRaid() then
        return 0
    end

    local members = (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
    if members <= 0 and (not IsInGroup or not IsInGroup()) then
        return 1
    end

    return math.min(MAX_PARTY_UNITS, members + 1)
end

local function ClearOffset(compactPartyFrame)
    if not compactPartyFrame or (lastAppliedX == 0 and lastAppliedY == 0) then
        return true
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingUpdate = true
        return false
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = compactPartyFrame:GetPoint(1)
    if not point then
        return false
    end

    compactPartyFrame:ClearAllPoints()
    xOfs = xOfs - lastAppliedX
    yOfs = yOfs - lastAppliedY
    compactPartyFrame:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs)
    lastAppliedX = 0
    lastAppliedY = 0
    RecordExpectedAnchor(point, relativePoint, xOfs, yOfs)
    return true
end

local function ApplyCenterOffset(compactPartyFrame)
    if not compactPartyFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingUpdate = true
        return
    end

    if not isEnabled or not IsRaidStylePartyEnabled() then
        ClearOffset(compactPartyFrame)
        return
    end

    local memberCount = GetDisplayedMemberCount(compactPartyFrame)
    if memberCount <= 0 then
        ClearOffset(compactPartyFrame)
        return
    end

    local isHorizontal = EditModeManagerFrame
        and EditModeManagerFrame.ShouldRaidFrameUseHorizontalRaidGroups
        and EditModeManagerFrame:ShouldRaidFrameUseHorizontalRaidGroups(compactPartyFrame.groupType)

    local firstFrame = compactPartyFrame.memberUnitFrames and compactPartyFrame.memberUnitFrames[1]
    if not firstFrame then
        return
    end

    local unitWidth = firstFrame:GetWidth() or 0
    local unitHeight = firstFrame:GetHeight() or 0
    if unitWidth <= 0 or unitHeight <= 0 then
        return
    end

    local missing = MAX_PARTY_UNITS - memberCount
    local desiredX = 0
    local desiredY = 0

    if missing > 0 then
        if isHorizontal then
            desiredX = (missing * unitWidth) / 2
        else
            desiredY = -(missing * unitHeight) / 2
        end
    end

    local point, relativeTo, relativePoint, xOfs, yOfs = compactPartyFrame:GetPoint(1)
    if not point then
        return
    end

    if WasExternallyReset(point, relativePoint, xOfs, yOfs) then
        lastAppliedX = 0
        lastAppliedY = 0
    end

    local baseX = xOfs - lastAppliedX
    local baseY = yOfs - lastAppliedY
    local finalX = baseX + desiredX
    local finalY = baseY + desiredY

    compactPartyFrame:ClearAllPoints()
    compactPartyFrame:SetPoint(point, relativeTo, relativePoint, finalX, finalY)

    lastAppliedX = desiredX
    lastAppliedY = desiredY
    RecordExpectedAnchor(point, relativePoint, finalX, finalY)
end

function PartyFramesCenterGrowth:ScheduleApply()
    frame = CompactPartyFrame or frame

    if not frame then
        return
    end

    C_Timer.After(0, function()
        ApplyCenterOffset(frame)
    end)
end

function PartyFramesCenterGrowth:OnInitialize()
    if not eventFrame then
        eventFrame = CreateFrame("Frame")
    end

    if not hookInstalled then
        if CompactPartyFrameMixin and CompactPartyFrameMixin.UpdateLayout then
            hooksecurefunc(CompactPartyFrameMixin, "UpdateLayout", function(compactPartyFrame)
                frame = compactPartyFrame or frame or CompactPartyFrame
                ApplyCenterOffset(frame)
            end)
            hookInstalled = true
        end

        if PartyFrame and PartyFrame.UpdatePaddingAndLayout then
            hooksecurefunc(PartyFrame, "UpdatePaddingAndLayout", function()
                self:ScheduleApply()
            end)
        end

        if UpdateRaidAndPartyFrames then
            hooksecurefunc("UpdateRaidAndPartyFrames", function()
                self:ScheduleApply()
            end)
        end
    end

    if EventRegistry and not self._editModeExitHandle then
        self._editModeExitHandle = function()
            if isEnabled then
                self:ScheduleApply()
            end
        end
        EventRegistry:RegisterCallback("EditMode.Exit", self._editModeExitHandle)
        EventRegistry:RegisterCallback("EditMode.SavedLayouts", self._editModeExitHandle)
    end

    eventFrame._pollElapsed = 0
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if pendingUpdate then
                pendingUpdate = false
                if isEnabled then
                    self:ScheduleApply()
                else
                    ClearOffset(frame or CompactPartyFrame)
                    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                end
            end
            return
        end

        self:ScheduleApply()
    end)
    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        if not isEnabled then
            return
        end

        eventFrame._pollElapsed = (eventFrame._pollElapsed or 0) + elapsed
        if eventFrame._pollElapsed >= POLL_INTERVAL then
            eventFrame._pollElapsed = 0
            self:ScheduleApply()
        end
    end)
end

function PartyFramesCenterGrowth:OnEnable()
    isEnabled = true

    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
    eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    eventFrame:RegisterEvent("UI_SCALE_CHANGED")

    self:ScheduleApply()
end

function PartyFramesCenterGrowth:OnDisable()
    isEnabled = false

    if eventFrame then
        eventFrame._pollElapsed = 0
        eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:UnregisterEvent("PLAYER_FLAGS_CHANGED")
        eventFrame:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        eventFrame:UnregisterEvent("UI_SCALE_CHANGED")
    end

    local didClear = ClearOffset(frame or CompactPartyFrame)
    if eventFrame then
        if didClear then
            pendingUpdate = false
            eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        else
            eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    end
end

BOLT:RegisterModule("partyFramesCenterGrowth", PartyFramesCenterGrowth)
