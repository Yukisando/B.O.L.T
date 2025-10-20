-- B.O.L.T Main File (Brittle and Occasionally Lethal Tweaks)
-- Entry point for the addon

local ADDON_NAME, BOLT = ...

-- Initialize the BOLT object if not already created
BOLT = BOLT or {}
BOLT.modules = BOLT.modules or {}

-- Register a module (called by module files at load time)
function BOLT:RegisterModule(name, module)
    if not self.modules[name] then
        self.modules[name] = module
        module.name = name
        module.parent = self
    end
end

-- The core framework and modules are loaded via the .toc file
-- This file serves as the main entry point and can contain
-- any additional initialization or global commands

-- Slash command handler
SLASH_BOLT1 = "/bolt"
SLASH_BOLT2 = "/b"

SlashCmdList["BOLT"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end
    
    if #args == 0 then
        -- Open the Interface Options to B.O.L.T panel
        BOLT:OpenConfigPanel()
    elseif args[1] == "help" then
        BOLT:Print("B.O.L.T v" .. BOLT.version .. " - Brittle and Occasionally Lethal Tweaks")
        print("  |cffFFFFFF/bolt or /b|r - Open settings in Interface Options")
        print("  |cffFFFFFF/bolt help|r - Show this help")
        print("  |cffFFFFFF/bolt config|r - Open settings in Interface Options")
        print("  |cffFFFFFF/bolt status|r - Show module status")
        print("  |cffFFFFFF/bolt toggle <module>|r - Toggle a module")
        print("  |cffFFFFFF/bolt toggle debug|r - Toggle debug mode")
        print("  |cffFFFFFF/bolt reload|r - Reload the addon")
        print("  |cffFFFFFF/bolt reset|r - Emergency reset of skyriding bindings")
    elseif args[1] == "status" then
        BOLT:Print("Module Status:")
        for name, module in pairs(BOLT.modules) do
            local enabled = BOLT:IsModuleEnabled(name)
            local status = enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
            print("  " .. name .. ": " .. status)
        end
    elseif args[1] == "toggle" and args[2] then
        local moduleName = args[2]
        -- Convert common names
        if moduleName == "menu" or moduleName == "gamemenu" then
            moduleName = "gameMenu"
        elseif moduleName == "toy" or moduleName == "toys" or moduleName == "fun" then
            moduleName = "playground"
        end
        
        -- Special handling for debug toggle
        if moduleName == "debug" then
            local currentValue = BOLT:GetConfig("debug")
            local newValue = not currentValue
            BOLT:SetConfig(newValue, "debug")
            
            local status = newValue and "enabled" or "disabled"
            BOLT:Print("Debug mode " .. status .. ".")
            return
        end
        
        if BOLT.modules[moduleName] then
            local currentValue = BOLT:GetConfig(moduleName, "enabled")
            local newValue = not currentValue
            BOLT:SetConfig(newValue, moduleName, "enabled")
            
            local status = newValue and "enabled" or "disabled"
            BOLT:Print("Module '" .. moduleName .. "' " .. status .. ". Type /reload to apply changes.")
        else
            BOLT:Print("Unknown module: " .. moduleName)
            BOLT:Print("Available modules: " .. table.concat(BOLT:GetTableKeys(BOLT.modules), ", "))
        end
    elseif args[1] == "reload" then
        ReloadUI()
    elseif args[1] == "reset" then
        -- Emergency reset for skyriding bindings
        if BOLT.modules.skyriding and BOLT.modules.skyriding.EmergencyReset then
            BOLT.modules.skyriding:EmergencyReset()
        else
            BOLT:Print("Skyriding module not available for reset.")
        end
    elseif args[1] == "config" then
        -- Open the Interface Options to B.O.L.T panel
        BOLT:OpenConfigPanel()
    else
        BOLT:Print("Unknown command. Type '/bolt help' for available commands.")
    end
end
