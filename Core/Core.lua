-- ColdSnap Core Framework
-- Main addon initialization and management

local ADDON_NAME, ColdSnap = ...

-- Create the main addon object
ColdSnap = ColdSnap or {}
ColdSnap.name = ADDON_NAME
ColdSnap.version = "1.1.0"
ColdSnap.modules = {}

-- Default configuration
ColdSnap.defaults = {
    profile = {
        debug = false,
        gameMenu = {
            enabled = true,
            showLeaveGroup = true,
            showReloadButton = true,
            autoConfirmExit = false,
        },
        playground = {
            enabled = true,
            showFavoriteToy = true,
            favoriteToyId = nil,
        }
    }
}

-- Initialize the addon
function ColdSnap:OnInitialize()
    -- Initialize database
    self:InitializeDatabase()
    
    -- Initialize modules
    self:InitializeModules()
    
    self:Print("ColdSnap v" .. self.version .. " loaded successfully!")
end

-- Register a module
function ColdSnap:RegisterModule(name, module)
    if not self.modules[name] then
        self.modules[name] = module
        module.name = name
        module.parent = self
    end
end

-- Initialize all registered modules
function ColdSnap:InitializeModules()
    for name, module in pairs(self.modules) do
        if module.OnInitialize then
            module:OnInitialize()
        end
    end
end

-- Enable all modules
function ColdSnap:EnableModules()
    for name, module in pairs(self.modules) do
        if module.OnEnable then
            module:OnEnable()
        end
    end
end

-- Print function with addon prefix
function ColdSnap:Print(msg)
    print("|cff00aaff[ColdSnap]|r " .. tostring(msg))
end

-- Debug print function
function ColdSnap:Debug(msg)
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
        ColdSnap:OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        ColdSnap:EnableModules()
    end
end)

-- Make the addon globally available
_G[ADDON_NAME] = ColdSnap
