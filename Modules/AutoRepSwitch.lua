-- B.O.L.T Auto Rep Switch Module
-- Automatically switches the watched reputation to the faction you just gained reputation with

local ADDON_NAME, BOLT = ...

local AutoRepSwitch = {}

function AutoRepSwitch:OnInitialize()
    self.factionReps = {}
    self.ready = false
    self.queue = {}
end

function AutoRepSwitch:BuildFactionSnapshot()
    if not C_Reputation or not C_Reputation.GetNumFactions then return end
    
    local ok, initialNum = pcall(C_Reputation.GetNumFactions)
    if not ok or not initialNum or initialNum == 0 then
        if not self.waitingForNumFactions then
            self.waitingForNumFactions = true
            C_Timer.After(5, function() if self then self.waitingForNumFactions = false end end)
        end
        C_Timer.After(0.5, function() if self and self.BuildFactionSnapshot then self:BuildFactionSnapshot() end end)
        return
    end
    
    -- Expand all collapsed headers
    for i = 1, initialNum do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if factionData and factionData.isHeader and factionData.isCollapsed then
            C_Reputation.ExpandFactionHeader(i)
        end
    end
    
    local num = C_Reputation.GetNumFactions()
    if not num or num == 0 then
        C_Timer.After(0.5, function() if self and self.BuildFactionSnapshot then self:BuildFactionSnapshot() end end)
        return
    end

    self.waitingForNumFactions = false
    self.factionReps = {}
    
    for i = 1, num do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        self.factionReps[i] = factionData and factionData.currentReactionThreshold or 0
    end

    if not self.ready then
        self.ready = true
        self:ProcessQueue()
    end
end

function AutoRepSwitch:ProcessQueue()
    if not self.ready then return end
    local q = self.queue
    self.queue = {}

    for _, task in ipairs(q) do
        if task.type == "chat" and task.message then
            self:HandleFactionChange(task.message)
        elseif task.type == "update" then
            self:HandleUpdateFaction()
        end
    end
end

function AutoRepSwitch:OnEnable()
    if not self.parent:IsModuleEnabled("autoRepSwitch") then return end

    if not self.eventFrame then
        self.eventFrame = CreateFrame("Frame")
        self.eventFrame:RegisterEvent("PLAYER_LOGIN")
        self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.eventFrame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
        self.eventFrame:RegisterEvent("UPDATE_FACTION")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
                C_Timer.After(0.7, function() self:BuildFactionSnapshot() end)
            elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
                local message = ...
                if not self.ready then
                    table.insert(self.queue, {type = "chat", message = message})
                else
                    self:HandleFactionChange(message)
                end
            elseif event == "UPDATE_FACTION" then
                if not self.ready then
                    table.insert(self.queue, {type = "update"})
                    C_Timer.After(0.1, function() if self and not self.ready then self:BuildFactionSnapshot() end end)
                else
                    C_Timer.After(0.05, function()
                        if self and self.HandleUpdateFaction then
                            self:HandleUpdateFaction()
                        end
                    end)
                end
            end
        end)
    end

    C_Timer.After(0.7, function()
        if self and self.BuildFactionSnapshot then
            self:BuildFactionSnapshot()
        end
    end)
end

function AutoRepSwitch:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
    self.factionReps = {}
end

function AutoRepSwitch:SwitchToFaction(index)
    if not index or not C_Reputation then return end
    
    local factionData = C_Reputation.GetFactionDataByIndex(index)
    if not factionData or not factionData.name then return end
    
    local watchedData = C_Reputation.GetWatchedFactionData()
    if watchedData and watchedData.name == factionData.name then return end

    C_Reputation.SetWatchedFactionByIndex(index)
    
    C_Timer.After(0.1, function()
        local newWatched = C_Reputation.GetWatchedFactionData()
        if newWatched and newWatched.name == factionData.name then
            if self.parent and self.parent.Print then
                self.parent:Print(("Now tracking %s"):format(factionData.name))
            end
        end
    end)
end

local function normalizeString(s)
    if not s then return "" end
    -- Replace non-alphanumeric characters with spaces, lowercase, collapse spaces
    local t = s:gsub("[^%w]", " "):lower():gsub("%s+", " "):gsub("^%s",""):gsub("%s$", "")
    return t
end

local function nameTokensMatchMessage(name, message)
    if not name or name == "" then return false end
    local n = normalizeString(name)
    local m = normalizeString(message)
    if n == "" or m == "" then return false end
    -- require that each token in the faction name exists somewhere in the message
    for token in n:gmatch("%S+") do
        if not string.find(m, token, 1, true) then
            return false
        end
    end
    return true
end

function AutoRepSwitch:HandleFactionChange(message)
    if not message or message == "" or not C_Reputation then return end

    local initialNum = C_Reputation.GetNumFactions()
    if not initialNum or initialNum == 0 then return end
    
    -- Expand all collapsed headers
    for i = 1, initialNum do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if factionData and factionData.isHeader and factionData.isCollapsed then
            C_Reputation.ExpandFactionHeader(i)
        end
    end
    
    local num = C_Reputation.GetNumFactions()
    if not num or num == 0 then return end

    -- Scan factions for message match
    for i = 1, num do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if factionData and not factionData.isHeader then
            if nameTokensMatchMessage(factionData.name, message) then
                if self.parent and self.parent.Print then 
                    self.parent:Print(("Detected rep gain for %s"):format(factionData.name)) 
                end
                self:SwitchToFaction(i)
                return
            end
        end
    end
end

function AutoRepSwitch:HandleUpdateFaction()
    if not C_Reputation then return end
    
    local initialNum = C_Reputation.GetNumFactions()
    if not initialNum or initialNum == 0 then return end
    
    -- Expand all collapsed headers
    for i = 1, initialNum do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if factionData and factionData.isHeader and factionData.isCollapsed then
            C_Reputation.ExpandFactionHeader(i)
        end
    end
    
    local num = C_Reputation.GetNumFactions()
    if not num or num == 0 then return end

    for i = 1, num do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        local new = factionData and factionData.currentReactionThreshold or 0
        local old = self.factionReps[i] or 0
        
        if new > old then
            if self.parent and self.parent.Print then
                self.parent:Print(("Detected rep gain for %s"):format(factionData.name or "Unknown"))
            end
            self:SwitchToFaction(i)
        end
        self.factionReps[i] = new
    end
end

-- Register the module
BOLT:RegisterModule("autoRepSwitch", AutoRepSwitch)
