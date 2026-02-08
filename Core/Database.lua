-- B.O.L.T Database Management (Brittle and Occasionally Lethal Tweaks)
-- Handles saved variables and configuration

local ADDON_NAME, BOLT = ...

-- Initialize database
function BOLT:InitializeDatabase()
    -- Initialize global (account-wide) saved variables
    if not BOLTDB then
        BOLTDB = {}
    end

    -- Initialize account-wide module enabled states
    -- Migrate from old per-profile system if needed
    if not BOLTDB.moduleStates then
        BOLTDB.moduleStates = {}
        -- Migrate: pull enabled states from the current character's old profile
        if BOLTDB.profiles then
            local playerKey = UnitName("player") .. " - " .. GetRealmName()
            local oldProfile = BOLTDB.profiles[playerKey]
            if oldProfile then
                local moduleNames = {"gameMenu", "playground", "skyriding", "wowheadLink", "autoRepSwitch", "teleports"}
                for _, name in ipairs(moduleNames) do
                    if oldProfile[name] and oldProfile[name].enabled ~= nil then
                        BOLTDB.moduleStates[name] = oldProfile[name].enabled
                    end
                end
            end
        end
        -- Fill in any missing modules with the default (false)
        for name, default in pairs(self.defaultModuleStates) do
            if BOLTDB.moduleStates[name] == nil then
                BOLTDB.moduleStates[name] = default
            end
        end
    end

    -- Set up database structure
    self.db = {
        global = BOLTDB,
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

    -- Clean legacy "enabled" keys out of profiles (now in moduleStates)
    local moduleNames = {"gameMenu", "playground", "skyriding", "wowheadLink", "autoRepSwitch", "teleports"}
    local cleaned = false
    for pkey, profile in pairs(BOLTDB.profiles) do
        for _, name in ipairs(moduleNames) do
            if profile[name] and profile[name].enabled ~= nil then
                profile[name].enabled = nil
                cleaned = true
            end
        end
        -- Remove deprecated skyriding.toggleMode
        if profile.skyriding and profile.skyriding.toggleMode ~= nil then
            profile.skyriding.toggleMode = nil
            cleaned = true
        end
    end
    if self.db.profile then
        for _, name in ipairs(moduleNames) do
            if self.db.profile[name] and self.db.profile[name].enabled ~= nil then
                self.db.profile[name].enabled = nil
                cleaned = true
            end
        end
        if self.db.profile.skyriding and self.db.profile.skyriding.toggleMode ~= nil then
            self.db.profile.skyriding.toggleMode = nil
            cleaned = true
        end
    end
    if cleaned then
        self:SaveProfile()
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
