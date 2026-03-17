local ADDON_NAME, BOLT = ...

local PartyFramesCenterGrowth = {}

local MAX_PARTY_UNITS = 5

local frame
local eventFrame
local pollTicker
local isEnabled = false
local hookInstalled = false
local pendingUpdate = false
local lastAppliedX = 0
local lastAppliedY = 0

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
    compactPartyFrame:SetPoint(point, relativeTo, relativePoint, xOfs - lastAppliedX, yOfs - lastAppliedY)
    lastAppliedX = 0
    lastAppliedY = 0
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

    local baseX = xOfs - lastAppliedX
    local baseY = yOfs - lastAppliedY

    compactPartyFrame:ClearAllPoints()
    compactPartyFrame:SetPoint(point, relativeTo, relativePoint, baseX + desiredX, baseY + desiredY)

    lastAppliedX = desiredX
    lastAppliedY = desiredY
end

function PartyFramesCenterGrowth:ScheduleApply()
    if not frame then
        frame = CompactPartyFrame
    end

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
    end

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
end

function PartyFramesCenterGrowth:OnEnable()
    isEnabled = true

    eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")

    if not pollTicker and C_Timer and C_Timer.NewTicker then
        -- Lightweight polling keeps centering in sync with edit-mode/UI anchor changes
        -- that do not always fire group roster events.
        pollTicker = C_Timer.NewTicker(0.2, function()
            self:ScheduleApply()
        end)
    end

    self:ScheduleApply()
end

function PartyFramesCenterGrowth:OnDisable()
    isEnabled = false

    if pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end

    if eventFrame then
        eventFrame:UnregisterEvent("GROUP_ROSTER_UPDATE")
        eventFrame:UnregisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:UnregisterEvent("PLAYER_FLAGS_CHANGED")
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
