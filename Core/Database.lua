-- ColdSnap Database Management
-- Handles saved variables and configuration

local ADDON_NAME, ColdSnap = ...

-- Initialize database
function ColdSnap:InitializeDatabase()
    -- Initialize global saved variables
    if not ColdSnapDB then
        ColdSnapDB = {}
    end
    
    -- Initialize character-specific saved variables
    if not ColdSnapCharDB then
        ColdSnapCharDB = {}
    end
    
    -- Set up database structure
    self.db = {
        global = ColdSnapDB,
        char = ColdSnapCharDB,
        profile = {}
    }
    
    -- Merge defaults with saved settings
    self:MergeDefaults(self.db.profile, self.defaults.profile)
    
    -- Store profile settings in global DB if they don't exist
    if not ColdSnapDB.profiles then
        ColdSnapDB.profiles = {}
    end
    
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    if not ColdSnapDB.profiles[playerKey] then
        ColdSnapDB.profiles[playerKey] = CopyTable(self.db.profile)
    else
        self.db.profile = ColdSnapDB.profiles[playerKey]
        self:MergeDefaults(self.db.profile, self.defaults.profile)
    end
end

-- Merge default values into existing table
function ColdSnap:MergeDefaults(target, defaults)
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
function ColdSnap:SaveProfile()
    local playerKey = UnitName("player") .. " - " .. GetRealmName()
    ColdSnapDB.profiles[playerKey] = CopyTable(self.db.profile)
end

-- Get a configuration value
function ColdSnap:GetConfig(...)
    local current = self.db.profile
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if current[key] == nil then
            return nil
        end
        current = current[key]
    end
    return current
end

-- Set a configuration value
function ColdSnap:SetConfig(value, ...)
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
