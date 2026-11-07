-- B.O.L.T Database Management (Brittle and Occasionally Lethal Tweaks)
-- Saved variables layout (BOLTDB, account-wide):
--   moduleStates[module]   = bool   account-wide on/off toggles
--   profiles[playerKey]    = table  per-character options (see BOLT.defaults.profile)
--   admin, transmogPresets, preMuteVolume, sellList   account-wide data owned by modules

local ADDON_NAME, BOLT = ...

-- Keys that older versions stored in profiles and that are now dead.
local LEGACY_PROFILE_KEYS = {
    { "nameplatesEnhancement", "interruptWarning" },
    { "nameplatesEnhancement", "interruptWarningColor" },
    { "skyriding", "toggleMode" },
    { "playground", "allowSpecialGamemode" },
    { "autoHide", "microMenu" },
    -- The minimap's per-button placements became one button bar.
    { "minimap", "zone" }, { "minimap", "clock" }, { "minimap", "difficulty" }, { "minimap", "tracking" },
    { "minimap", "calendar" }, { "minimap", "mail" }, { "minimap", "landingPage" },
    { "minimap", "compartment" }, { "minimap", "drawer" },
    { "campfire", "recipes" }, -- became the built-in recipe table plus campfire.learned
}

function BOLT:GetPlayerKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and CopyTable(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local function CleanProfile(profile, moduleNames)
    -- Module enabled flags moved from profiles to moduleStates.
    for name in pairs(moduleNames) do
        if type(profile[name]) == "table" then
            profile[name].enabled = nil
        end
    end
    for _, path in ipairs(LEGACY_PROFILE_KEYS) do
        local section = profile[path[1]]
        if type(section) == "table" then
            section[path[2]] = nil
        end
    end
end

function BOLT:InitializeDatabase()
    BOLTDB = BOLTDB or {}
    BOLTDB.profiles = BOLTDB.profiles or {}

    local playerKey = self:GetPlayerKey()

    -- Migrate module toggles out of the old per-character profiles.
    if not BOLTDB.moduleStates then
        BOLTDB.moduleStates = {}
        local oldProfile = BOLTDB.profiles[playerKey]
        if oldProfile then
            for name in pairs(self.defaultModuleStates) do
                if type(oldProfile[name]) == "table" and oldProfile[name].enabled ~= nil then
                    BOLTDB.moduleStates[name] = oldProfile[name].enabled
                end
            end
        end
    end
    for name, default in pairs(self.defaultModuleStates) do
        if BOLTDB.moduleStates[name] == nil then
            BOLTDB.moduleStates[name] = default
        end
    end

    for _, profile in pairs(BOLTDB.profiles) do
        CleanProfile(profile, self.defaultModuleStates)
    end

    -- The profile table is the saved table itself, so every write persists.
    local profile = BOLTDB.profiles[playerKey] or {}
    BOLTDB.profiles[playerKey] = profile
    MergeDefaults(profile, self.defaults.profile)

    self.db = { global = BOLTDB, profile = profile }
end

-- GetConfig("section", "key"[, default]) — string keys walk the profile; a trailing
-- non-string argument is the value returned when the setting is missing.
function BOLT:GetConfig(...)
    local count = select("#", ...)
    local default
    if count > 0 and type((select(count, ...))) ~= "string" then
        default = select(count, ...)
        count = count - 1
    end

    local node = self.db and self.db.profile
    for i = 1, count do
        if type(node) ~= "table" then return default end
        node = node[(select(i, ...))]
    end

    if node == nil then return default end
    return node
end

-- SetConfig(value, "section", "key") — creates intermediate tables as needed.
function BOLT:SetConfig(value, ...)
    local count = select("#", ...)
    local node = self.db.profile
    for i = 1, count - 1 do
        local key = select(i, ...)
        if type(node[key]) ~= "table" then
            node[key] = {}
        end
        node = node[key]
    end
    node[(select(count, ...))] = value
end
