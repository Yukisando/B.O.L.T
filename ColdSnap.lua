-- ColdSnap Main File
-- Entry point for the addon

local ADDON_NAME, ColdSnap = ...

-- The core framework and modules are loaded via the .toc file
-- This file serves as the main entry point and can contain
-- any additional initialization or global commands

-- Slash command handler
SLASH_COLDSNAP1 = "/coldsnap"
SLASH_COLDSNAP2 = "/cs"

SlashCmdList["COLDSNAP"] = function(msg)
    local args = {}
    for word in msg:gmatch("%S+") do
        table.insert(args, word:lower())
    end
    
    if #args == 0 then
        -- Open the Interface Options to ColdSnap panel
        if Settings and Settings.OpenToCategory then
            -- Modern Settings API (Retail)
            if ColdSnap.modules.config and ColdSnap.modules.config.settingsCategory then
                Settings.OpenToCategory(ColdSnap.modules.config.settingsCategory.ID)
            else
                ColdSnap:Print("Settings panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            -- Legacy Interface Options (Classic)
            if ColdSnap.modules.config and ColdSnap.modules.config.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(ColdSnap.modules.config.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(ColdSnap.modules.config.optionsPanel) -- Call twice for proper focus
            else
                ColdSnap:Print("Options panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        else
            ColdSnap:Print("Please access ColdSnap settings through Interface > AddOns.")
        end
    elseif args[1] == "help" then
        ColdSnap:Print("ColdSnap v" .. ColdSnap.version .. " - Quality of Life addon")
        print("  |cffFFFFFF/coldsnap or /cs|r - Open settings in Interface Options")
        print("  |cffFFFFFF/coldsnap help|r - Show this help")
        print("  |cffFFFFFF/coldsnap config|r - Open settings in Interface Options")
        print("  |cffFFFFFF/coldsnap status|r - Show module status")
        print("  |cffFFFFFF/coldsnap toggle <module>|r - Toggle a module")
        print("  |cffFFFFFF/coldsnap toggle debug|r - Toggle debug mode")
        print("  |cffFFFFFF/coldsnap reload|r - Reload the addon")
        print("  |cffFFFFFF/coldsnap reset|r - Emergency reset of skyriding bindings")
    elseif args[1] == "status" then
        ColdSnap:Print("Module Status:")
        for name, module in pairs(ColdSnap.modules) do
            local enabled = ColdSnap:IsModuleEnabled(name)
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
            local currentValue = ColdSnap:GetConfig("debug")
            local newValue = not currentValue
            ColdSnap:SetConfig(newValue, "debug")
            
            local status = newValue and "enabled" or "disabled"
            ColdSnap:Print("Debug mode " .. status .. ".")
            return
        end
        
        if ColdSnap.modules[moduleName] then
            local currentValue = ColdSnap:GetConfig(moduleName, "enabled")
            local newValue = not currentValue
            ColdSnap:SetConfig(newValue, moduleName, "enabled")
            
            local status = newValue and "enabled" or "disabled"
            ColdSnap:Print("Module '" .. moduleName .. "' " .. status .. ". Type /reload to apply changes.")
        else
            ColdSnap:Print("Unknown module: " .. moduleName)
            ColdSnap:Print("Available modules: " .. table.concat(tKeys(ColdSnap.modules), ", "))
        end
    elseif args[1] == "reload" then
        ReloadUI()
    elseif args[1] == "reset" then
        -- Emergency reset for skyriding bindings
        if ColdSnap.modules.skyriding and ColdSnap.modules.skyriding.EmergencyReset then
            ColdSnap.modules.skyriding:EmergencyReset()
        else
            ColdSnap:Print("Skyriding module not available for reset.")
        end
    elseif args[1] == "config" then
        -- Open the Interface Options to ColdSnap panel
        if Settings and Settings.OpenToCategory then
            -- Modern Settings API (Retail)
            if ColdSnap.modules.config and ColdSnap.modules.config.settingsCategory then
                Settings.OpenToCategory(ColdSnap.modules.config.settingsCategory.ID)
            else
                ColdSnap:Print("Settings panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            -- Legacy Interface Options (Classic)
            if ColdSnap.modules.config and ColdSnap.modules.config.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(ColdSnap.modules.config.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(ColdSnap.modules.config.optionsPanel) -- Call twice for proper focus
            else
                ColdSnap:Print("Options panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        else
            ColdSnap:Print("Please access ColdSnap settings through Interface > AddOns.")
        end
    else
        ColdSnap:Print("Unknown command. Type '/coldsnap help' for available commands.")
    end
end

-- Utility function to get table keys
function tKeys(t)
    local keys = {}
    for k in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end
