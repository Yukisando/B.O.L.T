-- ColdSnap Mythic Plus Module
-- Quality of life improvements for Mythic Plus dungeons

local ADDON_NAME, ColdSnap = ...

-- Create the MythicPlus module
local MythicPlus = {}

-- Track if we're in a mythic plus instance
local inMythicPlus = false
-- Track if we recently inserted a key to avoid spam
local recentKeyInsert = false
-- Timer to reset the recent key insert flag
local keyInsertTimer = nil

function MythicPlus:OnInitialize()
    self.parent:Debug("MythicPlus module initializing...")
end

function MythicPlus:OnEnable()
    if not self.parent:IsModuleEnabled("mythicPlus") then
        return
    end
    
    self.parent:Debug("MythicPlus module enabling...")
    
    -- Register for events
    self:RegisterEvents()
end

function MythicPlus:OnDisable()
    self:UnregisterEvents()
end

function MythicPlus:RegisterEvents()
    -- Create event frame if it doesn't exist
    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:SetScript("OnEvent", function(frame, event, ...)
            self:OnEvent(event, ...)
        end)
    end
    
    -- Register for relevant events
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_KEYSTONE_SLOTTED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_START")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self.eventFrame:RegisterEvent("CHALLENGE_MODE_RESET")
    
    self.parent:Debug("MythicPlus events registered")
end

function MythicPlus:UnregisterEvents()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
    end
end

function MythicPlus:OnEvent(event, ...)
    if event == "CHALLENGE_MODE_KEYSTONE_SLOTTED" then
        self:OnKeystoneSlotted()
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:OnPlayerEnteringWorld()
    elseif event == "CHALLENGE_MODE_START" then
        inMythicPlus = true
        self.parent:Debug("Mythic Plus started")
    elseif event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
        inMythicPlus = false
        self.parent:Debug("Mythic Plus ended")
    end
end

function MythicPlus:OnPlayerEnteringWorld()
    -- Check if we're in a mythic plus when entering world
    local _, instanceType = IsInInstance()
    if instanceType == "party" then
        -- Small delay to ensure APIs are available
        C_Timer.After(1, function()
            local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo()
            if level and level > 0 then
                inMythicPlus = true
                self.parent:Debug("Detected active Mythic Plus (level " .. level .. ")")
            else
                inMythicPlus = false
            end
        end)
    else
        inMythicPlus = false
    end
end

function MythicPlus:OnKeystoneSlotted()
    -- Check if auto ready check is enabled
    if not self.parent:GetConfig("mythicPlus", "autoReadyCheck") then
        return
    end
    
    -- Prevent spam by checking if we recently inserted a key
    if recentKeyInsert then
        return
    end
    
    -- Check if we're the group leader
    if not UnitIsGroupLeader("player") then
        self.parent:Debug("Not group leader, skipping auto ready check")
        return
    end
    
    -- Check if we're in a group
    if not (IsInGroup() or IsInRaid()) then
        self.parent:Debug("Not in group, skipping auto ready check")
        return
    end
    
    -- Check if we're in a mythic plus dungeon
    local _, instanceType = IsInInstance()
    if instanceType ~= "party" then
        self.parent:Debug("Not in dungeon, skipping auto ready check")
        return
    end
    
    -- Get keystone info to verify a key was actually slotted
    local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo()
    if not level or level <= 0 then
        self.parent:Debug("No active keystone found")
        return
    end
    
    -- Set flag to prevent spam
    recentKeyInsert = true
    
    -- Reset the flag after 10 seconds
    if keyInsertTimer then
        keyInsertTimer:Cancel()
    end
    keyInsertTimer = C_Timer.NewTimer(10, function()
        recentKeyInsert = false
    end)
    
    -- Small delay to let the key insertion UI settle
    C_Timer.After(0.5, function()
        self:InitiateReadyCheck()
    end)
end

function MythicPlus:InitiateReadyCheck()
    -- Double-check we're still the leader
    if not UnitIsGroupLeader("player") then
        return
    end
    
    -- Check if a ready check is already in progress
    if GetReadyCheckStatus() then
        self.parent:Debug("Ready check already in progress")
        return
    end
    
    -- Get the keystone level for the message
    local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo()
    local keystoneInfo = ""
    if level then
        keystoneInfo = " (Level " .. level .. ")"
    end
    
    -- Initiate the ready check
    DoReadyCheck()
    
    -- Print message to let the user know what happened
    self.parent:Print("Auto ready check initiated for Mythic Plus" .. keystoneInfo)
    
    self.parent:Debug("Ready check initiated for M+ level " .. (level or "unknown"))
end

-- Utility function to check if we're currently in a mythic plus
function MythicPlus:IsInMythicPlus()
    return inMythicPlus
end

-- Utility function to get current mythic plus info
function MythicPlus:GetMythicPlusInfo()
    if not inMythicPlus then
        return nil
    end
    
    local level, affixes, wasEnergized = C_ChallengeMode.GetActiveKeystoneInfo()
    if level and level > 0 then
        return {
            level = level,
            affixes = affixes,
            wasEnergized = wasEnergized
        }
    end
    
    return nil
end

-- Register the module
ColdSnap:RegisterModule("MythicPlus", MythicPlus)
