-- B.O.L.T Utility Functions (Brittle and Occasionally Lethal Tweaks)
-- Common helper functions used throughout the addon

local ADDON_NAME, BOLT = ...

-- Add trim function to string metatable
if not string.trim then
    function string.trim(s)
        return s:match("^%s*(.-)%s*$")
    end
end

-- Check if player is in any kind of group
function BOLT:IsInGroup()
    -- First check if we're actually in a real group (party or raid)
    local inRealGroup = IsInGroup() or IsInRaid()
    
    -- Check for delves (only if we're also in a real group)
    if inRealGroup and C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress() then
        return true
    end
    
    -- Check for instance groups (LFG/LFR)
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return true
    end
    
    -- Check for scenarios (only if we're in a real group, not solo scenarios)
    if inRealGroup and C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
        -- Additional check to make sure we're not in a solo quest scenario
        local scenarioInfo = C_Scenario.GetInfo()
        if scenarioInfo and scenarioInfo.isComplete == false then
            return true
        end
    end
    
    -- Standard group check
    return inRealGroup
end

-- Check if player can leave group (not leader in certain situations)
function BOLT:CanLeaveGroup()
    if not self:IsInGroup() then
        return false
    end
    
    -- Always allow leaving if not the leader
    if not UnitIsGroupLeader("player") then
        return true
    end
    
    -- If leader, check if there are other members
    local numMembers = GetNumGroupMembers()
    return numMembers > 1
end

-- Get group type string for display
function BOLT:GetGroupTypeString()
    -- Check for delves first (only if in a real group)
    if (IsInGroup() or IsInRaid()) and C_PartyInfo and C_PartyInfo.IsDelveInProgress and C_PartyInfo.IsDelveInProgress() then
        return "Delve"
    end
    
    -- Check for scenarios (only if in a real group)
    if (IsInGroup() or IsInRaid()) and C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
        local scenarioInfo = C_Scenario.GetInfo()
        if scenarioInfo and scenarioInfo.isComplete == false then
            return "Scenario"
        end
    end
    
    -- Check for instance groups
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
            return "Instance Raid"
        else
            return "Instance Party"
        end
    end
    
    -- Standard group checks
    if IsInRaid() then
        return "Raid"
    elseif IsInGroup() then
        return "Party"
    else
        return nil
    end
end

-- Safe leave group function
function BOLT:LeaveGroup()
    -- Don't allow leaving group during combat
    if InCombatLockdown() then
        self:Print("Cannot leave group during combat.")
        return
    end
    
    -- Check if we're in a delve first using the proper delve detection
    if C_PartyInfo and (C_PartyInfo.IsDelveInProgress() or C_PartyInfo.IsDelveComplete()) then
        self:Print("Leaving delve...")
        -- Use the proper delve teleport out function
        if C_PartyInfo.DelveTeleportOut then
            C_PartyInfo.DelveTeleportOut()
            self:Print("Teleported out of delve.")
        else
            -- Fallback if the function doesn't exist
            if C_PartyInfo and C_PartyInfo.LeaveParty then
                C_PartyInfo.LeaveParty()
            else
                LeaveParty()
            end
            self:Print("Left delve group.")
        end
        return
    end
    
    -- Check if we're in LFG content
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        self:Print("Leaving instance group...")
        C_PartyInfo.LeaveParty(LE_PARTY_CATEGORY_INSTANCE)
        return
    end
    
    -- Check if we're in a scenario (only if we're actually in a group)
    if (IsInGroup() or IsInRaid()) and C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario() then
        -- Make sure it's not a solo quest scenario
        local scenarioInfo = C_Scenario.GetInfo()
        if scenarioInfo and scenarioInfo.isComplete == false then
            self:Print("Leaving scenario...")
            if C_PartyInfo and C_PartyInfo.LeaveParty then
                C_PartyInfo.LeaveParty()
            else
                LeaveParty()
            end
            return
        end
    end
    
    -- Check if we're in any special content that requires leaving the instance
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario") then
        self:Print("Leaving instance and group...")
        -- Use the more comprehensive leave function
        if C_PartyInfo and C_PartyInfo.LeaveParty then
            C_PartyInfo.LeaveParty()
        else
            LeaveParty()
        end
        return
    end
    
    -- Standard group leaving logic
    if not self:IsInGroup() then
        self:Print("You are not in a group.")
        return
    end
    
    local groupType = self:GetGroupTypeString()
    
    if UnitIsGroupLeader("player") then
        local numMembers = GetNumGroupMembers()
        if numMembers > 1 then
            -- Transfer leadership before leaving if possible
            for i = 1, numMembers do
                local unit = IsInRaid() and "raid" .. i or "party" .. i
                if UnitExists(unit) and not UnitIsUnit(unit, "player") then
                    PromoteToLeader(unit)
                    break
                end
            end
            -- Small delay to allow leadership transfer
            C_Timer.After(0.5, function()
                if C_PartyInfo and C_PartyInfo.LeaveParty then
                    C_PartyInfo.LeaveParty()
                else
                    LeaveParty()
                end
                BOLT:Print("Left " .. (groupType or "group") .. ".")
            end)
        else
            -- Solo in group, just leave
            if C_PartyInfo and C_PartyInfo.LeaveParty then
                C_PartyInfo.LeaveParty()
            else
                LeaveParty()
            end
            self:Print("Left " .. (groupType or "group") .. ".")
        end
    else
        -- Not leader, just leave
        if C_PartyInfo and C_PartyInfo.LeaveParty then
            C_PartyInfo.LeaveParty()
        else
            LeaveParty()
        end
        self:Print("Left " .. (groupType or "group") .. ".")
    end
end

-- Color text with class colors
function BOLT:ColorText(text, color)
    if type(color) == "string" then
        return "|c" .. color .. text .. "|r"
    elseif type(color) == "table" and color.r and color.g and color.b then
        local hex = string.format("%02x%02x%02x", 
            math.floor(color.r * 255), 
            math.floor(color.g * 255), 
            math.floor(color.b * 255))
        return "|cff" .. hex .. text .. "|r"
    else
        return text
    end
end

-- Check if a module is enabled
function BOLT:IsModuleEnabled(moduleName)
    local config = self:GetConfig(moduleName, "enabled")
    return config ~= false -- Default to true if not set
end
