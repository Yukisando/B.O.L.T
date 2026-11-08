-- B.O.L.T Core Framework (Brittle and Occasionally Lethal Tweaks)
-- Addon object, module registry and startup.
local ADDON_NAME, BOLT = ...

BOLT.name = ADDON_NAME
BOLT.version = "dev" -- replaced from the TOC metadata at startup
BOLT.modules = {}
BOLT.moduleOrder = {}

-- WoW: Forever runs on the modern (Mainline) client with interface 16xxx. Some
-- retail-only functions still exist there as stubs (the delve checks report a
-- delve in progress), so features are gated on the client, not only on the API.
local interfaceVersion = select(4, GetBuildInfo()) or 0
BOLT.isForever = (interfaceVersion >= 16000 and interfaceVersion < 20000)
    or (C_GameRules ~= nil and C_GameRules.GetForeverExperiencePreset ~= nil)

-- Systems a feature needs; checked once at load.
BOLT.has = {
    delves = not BOLT.isForever and C_PartyInfo ~= nil and C_PartyInfo.IsDelveInProgress ~= nil,
    specializations = not BOLT.isForever and GetSpecialization ~= nil and GetLootSpecialization ~= nil,
    toys = C_ToyBox ~= nil and C_ToyBox.GetToyInfo ~= nil and PlayerHasToy ~= nil,
    mountJournal = C_MountJournal ~= nil and C_MountJournal.GetMountFromSpell ~= nil,
    countdown = C_PartyInfo ~= nil and C_PartyInfo.DoCountdown ~= nil,
    transmogOutfits = C_TransmogOutfitInfo ~= nil and C_TransmogOutfitInfo.SetPendingTransmog ~= nil,
}

-- Per-character options. Module enabled states live account-wide in BOLTDB.moduleStates.
BOLT.defaults = {
    profile = {
        debug = false,
        unitFrames = {
            player = true,
            target = true,
            targetOfTarget = true,
            pet = true,
            party = true,
            castBars = true,
        },
        immersive = {
            showWithTarget = true, -- Personal Resource Display also shows with an attackable target
            idleAlpha = 10, -- percent opacity of the Personal Resource Display out of combat; 0 hides it
            rightClickMenus = true, -- right-click it for your menu, Shift + right-click for the target's
        },
        autoHide = {
            mainBar = true,     -- main action bar, micro menu and bags, as one strip
            actionBars = true,  -- the other action bars
            xpBar = true,
            minimapButtons = true,
            buffs = false,
            debuffs = false,
            unitFrames = false,
            questTracker = false,
            minimap = false,
            idleAlpha = 0, -- percent opacity while hidden
        },
        gameMenu = {
            showLeaveGroup = true,
            showReloadButton = true,
            groupToolsEnabled = true,
            raidMarkerIndex = 1, -- 1=Star ... 8=Skull, 0 = none
            showBattleTextToggles = true,
            showVolumeButton = true,
            showLootSpecButton = true,
        },
        playground = {
            showFavoriteToy = true,
            closeGameMenuOnCast = false,
            showSpeedometer = true,
            showFPS = false,
            statsPosition = "TOPRIGHT",
            copyTargetMount = true,
        },
        wandShoot = {
            petAttack = true, -- the Shoot Wand key also sends your pet in
        },
        skyriding = {
            enablePitchControl = true,
            invertPitch = true,
            requireMouseButton = true,
        },
        chatNotifier = {
            channels = {},
            soundID = 8959,
        },
        soundMuter = {
            mutedSoundIDs = {},
        },
        minimap = {
            buttons = "BOTTOM", -- side of the map for the button bar: TOP, BOTTOM, LEFT or RIGHT
            wheelZoom = true,
        },
        nameplatesEnhancement = {
            manaUsers = true,
            manaColor = { r = 0.2, g = 0.4, b = 1.0 },
            instanceOnly = false,
            targetEmphasis = true,
            interruptCue = true,
            rangeHint = true,
            interruptColor = { r = 0.3, g = 1.0, b = 0.45 },
        },
        campfire = {
            autoSit = true,   -- sit again on a spot where the fire warmed you, when it would gain something
            showCraft = true, -- craft rows for the camp recipes you know
            collapsed = false, -- panel folded to its title line
            -- learned = { [recipeID] = true }, camp recipes seen in open profession windows
        },
        keyShare = {
            rouletteEnabled = true,
        },
        roleplay = {
            -- -1 = disabled; otherwise a 1-based index into C_EditMode.GetLayouts().layouts
            editModeProfileIndex = -1,
            editModeOOCProfileIndex = -1,
            toggleTrpToolbar = false,
            autoThankBuffs = true,
        },
    },
}

-- Modules with an on/off toggle; all start disabled for new users.
BOLT.defaultModuleStates = {
    gameMenu = false,
    unitFrames = false,
    immersive = false,
    tooltip = false,
    rangedTimer = false,
    autoHide = false,
    minimap = false,
    playground = false,
    skyriding = false,
    wandShoot = false,
    doubleClickFishing = false,
    wowheadLink = false,
    autoRepSwitch = false,
    autoSell = false,
    campfire = false,
    smartTeleport = false,
    chatNotifier = false,
    achievementTracker = false,
    savedInstances = false,
    soundMuter = false,
    nameplatesEnhancement = false,
    partyFramesCenterGrowth = false,
    keyShare = false,
}

---------------------------------------------------------------------------
-- Module registry
---------------------------------------------------------------------------

-- Modules may define:
--   displayName       label used in menus and chat
--   alwaysOn          enabled on every login, no user toggle (Config, Admin, ...)
--   IsSupported()     return false to skip the module on this client (e.g. Forever)
--   OnInitialize()    runs once, before the first OnEnable
--   OnEnable() / OnDisable()
function BOLT:RegisterModule(name, module)
    if self.modules[name] then return end
    if module.IsSupported and not module:IsSupported() then return end

    module.name = name
    module.parent = self
    self.modules[name] = module
    table.insert(self.moduleOrder, name)
end

function BOLT:GetModule(name)
    return self.modules[name]
end

function BOLT:IsModuleEnabled(name)
    local mod = self.modules[name]
    if mod and mod.alwaysOn then return true end
    return BOLTDB ~= nil and BOLTDB.moduleStates ~= nil and BOLTDB.moduleStates[name] == true
end

function BOLT:InitializeModule(mod)
    if mod._initialized then return end
    mod._initialized = true
    if mod.OnInitialize then mod:OnInitialize() end
end

function BOLT:ActivateModule(mod)
    self:InitializeModule(mod)
    if mod.active then return end
    mod.active = true
    if mod.OnEnable then mod:OnEnable() end
end

function BOLT:DeactivateModule(mod)
    if not mod.active then return end
    mod.active = false
    if mod.OnDisable then mod:OnDisable() end
end

-- Enable or disable a toggleable module immediately and persist the choice account-wide.
function BOLT:SetModuleEnabled(name, enabled)
    enabled = enabled and true or false
    BOLTDB.moduleStates[name] = enabled

    local mod = self.modules[name]
    if not mod then
        self:Print(("Module '%s' is not available on this client."):format(tostring(name)))
        return
    end

    if enabled then
        self:ActivateModule(mod)
    else
        self:DeactivateModule(mod)
    end
    -- Toggles also come from the tracking menu and slash commands: keep the settings page in step.
    local config = self.modules.config
    if config and config.pages then
        config:RefreshAll()
    end
    self:Print(("%s %s."):format(mod.displayName or name, enabled and "enabled" or "disabled"))
end

-- Toggleable modules in registration order, for menus and status output.
function BOLT:GetToggleableModules()
    local list = {}
    for _, name in ipairs(self.moduleOrder) do
        local mod = self.modules[name]
        if not mod.alwaysOn and self.defaultModuleStates[name] ~= nil then
            table.insert(list, mod)
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------

function BOLT:Print(msg)
    print("|cff00aaff[B.O.L.T]|r " .. tostring(msg))
end

function BOLT:Debug(msg)
    if self.db and self.db.profile.debug then
        self:Print("|cffff0000[DEBUG]|r " .. tostring(msg))
    end
end

---------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------

-- Inject module toggles into the minimap tracking dropdown.
function BOLT:HookMinimapTrackingMenu()
    if not (Menu and Menu.ModifyMenu) then return end

    Menu.ModifyMenu("MENU_MINIMAP_TRACKING", function(_, rootDescription)
        rootDescription:CreateDivider()
        rootDescription:CreateTitle("|cff00aaffB.O.L.T|r")
        for _, mod in ipairs(self:GetToggleableModules()) do
            local name = mod.name
            rootDescription:CreateCheckbox(mod.displayName or name,
                function() return self:IsModuleEnabled(name) end,
                function() self:SetModuleEnabled(name, not self:IsModuleEnabled(name)) end)
        end
    end)
end

function BOLT:OnLogin()
    self.version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"
    if self.version:find("@", 1, true) then
        self.version = "dev"
    end

    self:InitializeDatabase()
    self:HookMinimapTrackingMenu()

    local enabled = {}
    for _, name in ipairs(self.moduleOrder) do
        local mod = self.modules[name]
        if self:IsModuleEnabled(name) then
            self:ActivateModule(mod)
            if not mod.alwaysOn then
                table.insert(enabled, mod.displayName or name)
            end
        end
    end

    self:Print(("v%s loaded. Enabled: %s"):format(self.version,
        #enabled > 0 and table.concat(enabled, ", ") or "(none)"))
end

-- Modules are started from a timer instead of PLAYER_LOGIN/ADDON_LOADED handlers:
-- running addon code while Blizzard builds the secure UI (GameMenuFrame_Setup in
-- particular) taints the game menu button callbacks and causes ADDON_ACTION_FORBIDDEN
-- on Logout/Exit. Waiting until the player is in the world and out of combat avoids it.
local function TryStart()
    if BOLT._started then return end
    if not (IsLoggedIn() and GameMenuFrame) or InCombatLockdown() then
        C_Timer.After(0.2, TryStart)
        return
    end
    BOLT._started = true
    BOLT:OnLogin()
end

C_Timer.After(0, TryStart)

_G[ADDON_NAME] = BOLT
