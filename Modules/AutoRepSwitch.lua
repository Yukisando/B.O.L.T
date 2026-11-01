-- B.O.L.T Auto Rep Switch Module
-- Watches the faction you most recently gained reputation with.

local ADDON_NAME, BOLT = ...

local AutoRepSwitch = {
    displayName = "Auto Rep Switch",
}

-- Midnight's FACTION_STANDING_CHANGED (factionID, updatedStanding) replaces parsing
-- CHAT_MSG_COMBAT_FACTION_CHANGE, whose text is a secret value inside instances.
function AutoRepSwitch:OnFactionStandingChanged(factionID)
    local watched = C_Reputation.GetWatchedFactionData()
    if watched and watched.factionID == factionID then return end

    local faction = C_Reputation.GetFactionDataByID(factionID)
    if not faction or faction.isHeader and not faction.isHeaderWithRep then return end

    C_Reputation.SetWatchedFactionByID(factionID)
    BOLT:Print("Now tracking " .. faction.name)
end

function AutoRepSwitch:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, _, factionID)
        if factionID and not BOLT.IsSecret(factionID) then
            self:OnFactionStandingChanged(factionID)
        end
    end)
end

function AutoRepSwitch:OnEnable()
    self.eventFrame:RegisterEvent("FACTION_STANDING_CHANGED")
end

function AutoRepSwitch:OnDisable()
    self.eventFrame:UnregisterAllEvents()
end

BOLT:RegisterModule("autoRepSwitch", AutoRepSwitch)
