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
            showVolumeButton = true,
            showLootSpecButton = true,
        },
        playground = {
            showFavoriteToy = true,
            closeGameMenuOnCast = false,
            favoriteToyId = nil,
            showSpeedometer = true,
            statsPosition = "TOPRIGHT",
            copyTargetMount = true
        },
        skyriding = {
            enablePitchControl = true,
            invertPitch = true,
            requireMouseButton = true,
        },
        wowheadLink = {},
        autoRepSwitch = {},
        smartTeleport = {},
        chatNotifier = {
            channels = {},
            soundID = 8959,
        },
        achievementTracker = {
            trackedCategories = { [97] = true },  -- 97 = Exploration; empty = track all
        },
        soundMuter = {
            mutedSoundIDs = {},
        },
        nameplatesEnhancement = {
            manaColor = { r = 0.2, g = 0.4, b = 1.0 },
            instanceOnly = false,
        },
        keyShare = {
            rouletteEnabled = true,
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
    nameplatesEnhancement = false,
    partyFramesCenterGrowth = false,
    keyShare = false,
}

-- Initialize the addon
function BOLT:OnInitialize()
    -- Set version from TOC file (synced with git tags)
    self.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

    -- Initialize database
    self:InitializeDatabase()

    -- Register Bolt section in the minimap tracking dropdown
    self:HookMinimapTrackingMenu()

    -- Initialize modules
    self:InitializeModules()

    self:Print("B.O.L.T v" .. self.version .. " loaded successfully!")
end

-- Inject Bolt module toggles into the native minimap tracking dropdown
function BOLT:HookMinimapTrackingMenu()
    if not Menu or not Menu.ModifyMenu then return end

    Menu.ModifyMenu("MENU_MINIMAP_TRACKING", function(owner, rootDescription, contextData)
        rootDescription:CreateDivider()
        rootDescription:CreateTitle("|cff00aaffB.O.L.T|r")

        local modules = {
            { key = "achievementTracker",      label = "Achievement Tracker" },
            { key = "chatNotifier",             label = "Chat Notifier" },
            { key = "autoRepSwitch",            label = "Auto Rep Switch" },
            { key = "smartTeleport",            label = "Smart Teleport" },
            { key = "nameplatesEnhancement",    label = "Nameplates" },
            { key = "skyriding",                label = "Skyriding Controls" },
            { key = "keyShare",                 label = "Key Share" },
            { key = "wowheadLink",              label = "Wowhead Links" },
        }

        for _, mod in ipairs(modules) do
            local key = mod.key
            rootDescription:CreateCheckbox(
                mod.label,
                function() return self:IsModuleEnabled(key) end,
                function()
                    self:SetModuleEnabled(key, not self:IsModuleEnabled(key))
                end
            )
        end
    end)
end

-- Initialize all registered modules
function BOLT:InitializeModules()
    for name, module in pairs(self.modules) do
        local shouldInitialize = module.alwaysInitialize or self:IsModuleEnabled(name)
        if shouldInitialize and module.OnInitialize and not module._initialized then
            module:OnInitialize()
            module._initialized = true
        end
    end
end

-- Enable modules based on saved config
function BOLT:EnableModules()
    local enabledModules = {}
    for name, module in pairs(self.modules) do
        if module.OnEnable and self:IsModuleEnabled(name) then
            if module.OnInitialize and not module._initialized then
                module:OnInitialize()
                module._initialized = true
            end
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

local function BootstrapAddon()
    if BOLT._bootstrapStarted then
        return
    end
    BOLT._bootstrapStarted = true

    local function InitializeAfterLoginOnce()
        if BOLT._initializedAfterLogin then
            return
        end
        BOLT._initializedAfterLogin = true
        -- Initialize and enable modules only after login so addon code does not
        -- run during Blizzard secure UI bootstrap.
        BOLT:OnInitialize()
        BOLT:EnableModules()
    end

    local attempts = 0
    local function TryInitializeAfterStartup()
        if BOLT._initializedAfterLogin then
            return
        end

        attempts = attempts + 1
        if not (IsLoggedIn and IsLoggedIn()) then
            C_Timer.After(0.2, TryInitializeAfterStartup)
            return
        end

        -- Wait for Blizzard's startup/UI construction to settle before any
        -- module initialization to reduce GameMenu callback taint risk.
        if not GameMenuFrame then
            C_Timer.After(0.2, TryInitializeAfterStartup)
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            C_Timer.After(0.2, TryInitializeAfterStartup)
            return
        end

        InitializeAfterLoginOnce()
    end

    C_Timer.After(0.2, TryInitializeAfterStartup)
end

C_Timer.After(0, BootstrapAddon)

-- Make the addon globally available
_G[ADDON_NAME] = BOLT
