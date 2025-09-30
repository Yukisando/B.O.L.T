-- B.O.L.T Database Management (Brittle and Occasionally Lethal Tweaks)
-- Handles saved variables and configuration

local ADDON_NAME, BOLT = ...

-- Initialize database
function BOLT:InitializeDatabase()
    -- Initialize global saved variables
    if not BOLTDB then
        BOLTDB = {}
    end
    
    -- Initialize character-specific saved variables
    if not BOLTCharDB then
        BOLTCharDB = {}
    end
    
    -- Set up database structure
    self.db = {
        global = BOLTDB,
        char = BOLTCharDB,
        profile = {}
    }
    
    -- Merge defaults with saved settings
    self:MergeDefaults(self.db.profile, self.defaults.profile)
    
    -- Store profile settings in global DB if they don't exist
    if not BOLTDB.profiles then
        BOLTDB.profiles = {}
    end
    
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    if not BOLTDB.profiles[playerKey] then
        BOLTDB.profiles[playerKey] = CopyTable(self.db.profile)
    else
        self.db.profile = BOLTDB.profiles[playerKey]
        self:MergeDefaults(self.db.profile, self.defaults.profile)
    end
end

-- Merge default values into existing table
function BOLT:MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                self:MergeDefaults(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            self:MergeDefaults(target[key], value)
        end
    end
end

-- Save current profile
function BOLT:SaveProfile()
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    BOLTDB.profiles[playerKey] = CopyTable(self.db.profile)
end

-- Get a configuration value
function BOLT:GetConfig(...)
    local args = {...}
    local defaultValue = nil
    
    -- Check if the last argument is a default value (non-string or last arg when length > expected keys)
    local numArgs = select("#", ...)
    if numArgs > 0 then
        local lastArg = args[numArgs]
        -- If last argument looks like a default value (boolean, number, or nil)
        if type(lastArg) == "boolean" or type(lastArg) == "number" or lastArg == nil then
            defaultValue = lastArg
            numArgs = numArgs - 1
        end
    end
    
    local current = self.db.profile
    for i = 1, numArgs do
        local key = args[i]
        if current[key] == nil then
            return defaultValue
        end
        current = current[key]
    end
    return current ~= nil and current or defaultValue
end

-- Set a configuration value
function BOLT:SetConfig(value, ...)
    local keys = {...}
    local current = self.db.profile
    
    for i = 1, #keys - 1 do
        local key = keys[i]
        if current[key] == nil then
            current[key] = {}
        end
        current = current[key]
    end
    
    current[keys[#keys]] = value
    self:SaveProfile()
end
