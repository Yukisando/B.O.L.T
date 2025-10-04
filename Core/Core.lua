-- B.O.L.T Core Framework (Brittle and Occasionally Lethal Tweaks)
-- Main addon initialization and management

local ADDON_NAME, BOLT = ...

-- Create the main addon object
BOLT = BOLT or {}
BOLT.name = ADDON_NAME
BOLT.version = "1.9.0"
BOLT.modules = {}

-- Default configuration
BOLT.defaults = {
    profile = {
        debug = false,
        gameMenu = {
            enabled = true,
            showLeaveGroup = true,
            showReloadButton = true,
            groupToolsEnabled = true,
            raidMarkerIndex = 1, -- 1=Star, 2=Circle, ... 8=Skull; set 0 to clear
            showBattleTextToggles = true,
            showVolumeButton = true,
        },
        playground = {
            enabled = true,
            showFavoriteToy = false,
            favoriteToyId = nil,
            showFPS = true,
            showSpeedometer = true,
            statsPosition = "BOTTOMLEFT", -- Default to bottom left corner
            copyTargetMount = false, -- When enabled, summon random mount copies target's mount if known
        },
        skyriding = {
            enabled = false,
            enablePitchControl = true,
            invertPitch = true,
            toggleMode = false,
        },
    }
}

-- Initialize the addon
function BOLT:OnInitialize()
    -- Initialize database
    self:InitializeDatabase()
    
    -- Initialize modules
    self:InitializeModules()
    
    self:Print("B.O.L.T v" .. self.version .. " loaded successfully!")
end

-- Register a module
function BOLT:RegisterModule(name, module)
    if not self.modules[name] then
        self.modules[name] = module
        module.name = name
        module.parent = self
    end
end

-- Initialize all registered modules
function BOLT:InitializeModules()
    for name, module in pairs(self.modules) do
        if module.OnInitialize then
            module:OnInitialize()
        end
    end
end

-- Enable all modules
function BOLT:EnableModules()
    for name, module in pairs(self.modules) do
        if module.OnEnable then
            module:OnEnable()
        end
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
