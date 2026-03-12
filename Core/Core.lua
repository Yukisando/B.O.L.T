-- B.O.L.T Core Framework (Brittle and Occasionally Lethal Tweaks)
-- Main addon initialization and management
local ADDON_NAME, BOLT = ...

-- Create the main addon object
BOLT = BOLT or {}
BOLT.name = ADDON_NAME
BOLT.version = "dev" -- Will be set from TOC after ADDON_LOADED
BOLT.modules = {}

-- Default configuration
-- Module enabled states live in BOLTDB.moduleStates (account-wide).
-- These profile defaults only cover per-module *options*, not the enabled toggle.
BOLT.defaults = {
    profile = {
        debug = false,
        gameMenu = {
            showLeaveGroup = true,
            showReloadButton = true,
            groupToolsEnabled = true,
            raidMarkerIndex = 1, -- 1=Star, 2=Circle, ... 8=Skull; set 0 to clear
            showBattleTextToggles = true,
            showVolumeButton = true
        },
        playground = {
            showFavoriteToy = true,
            favoriteToyId = nil,
            showSpeedometer = true,
            statsPosition = "TOPRIGHT",
            copyTargetMount = true
        },
        skyriding = {
            enablePitchControl = true,
            invertPitch = true
        },
        wowheadLink = {},
        autoRepSwitch = {},
        smartTeleport = {},
        chatNotifier = {
            channels = {},
            soundID = 8959,
        },
        achievementTracker = {
            trackedCategories = {},  -- empty = track all; otherwise catID → true
        },
        soundMuter = {
            mutedSoundIDs = {},
        },
    }
}

-- Default module enabled states for NEW users (all off)
BOLT.defaultModuleStates = {
    gameMenu = false,
    playground = false,
    skyriding = false,
    wowheadLink = false,
    autoRepSwitch = false,
    smartTeleport = false,
    chatNotifier = false,
    achievementTracker = false,
    savedInstances = false,
    soundMuter = false,
}

-- Initialize the addon
function BOLT:OnInitialize()
    -- Set version from TOC file (synced with git tags)
    self.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

    -- Initialize database
    self:InitializeDatabase()

    -- Initialize modules
    self:InitializeModules()

    self:Print("B.O.L.T v" .. self.version .. " loaded successfully!")
end

-- Initialize all registered modules
function BOLT:InitializeModules()
    for name, module in pairs(self.modules) do
        if module.OnInitialize then
            module:OnInitialize()
        end
    end
end

-- Enable modules based on saved config
function BOLT:EnableModules()
    local enabledModules = {}
    for name, module in pairs(self.modules) do
        if module.OnEnable and self:IsModuleEnabled(name) then
            module:OnEnable()
            table.insert(enabledModules, name)
        end
    end

    -- Print summary of enabled modules on startup
    if self and self.Print then
        self:Print("Enabled modules on startup: " ..
            (next(enabledModules) and table.concat(enabledModules, ", ") or "(none)"))
    end
end

-- Print function with addon prefix
function BOLT:Print(msg)
    print("|cff00aaff[B.O.L.T]|r " .. tostring(msg))
end

-- Debug print function
function BOLT:Debug(msg)
    if self.db and self.db.profile.debug then
        self:Print("|cffff0000[DEBUG]|r " .. tostring(msg))
    end
end

-- Event frame for handling addon events
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        BOLT:OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        BOLT:EnableModules()
    end
end)

-- Make the addon globally available
_G[ADDON_NAME] = BOLT
