-- B.O.L.T Main File (Brittle and Occasionally Lethal Tweaks)
-- Slash commands. Loaded last so every module is registered.

local ADDON_NAME, BOLT = ...

local MODULE_ALIASES = {
    menu = "gameMenu",
    gamemenu = "gameMenu",
    toy = "playground",
    toys = "playground",
    fun = "playground",
}

local function ResolveModuleName(input)
    if MODULE_ALIASES[input] then
        return MODULE_ALIASES[input]
    end
    for name in pairs(BOLT.defaultModuleStates) do
        if name:lower() == input then
            return name
        end
    end
    return input
end

local function PrintHelp()
    BOLT:Print("B.O.L.T v" .. BOLT.version .. " - Brittle and Occasionally Lethal Tweaks")
    local lines = {
        { "/bolt, /b", "Open settings" },
        { "/bolt status", "Show module status" },
        { "/bolt toggle <module>", "Toggle a module" },
        { "/bolt toggle debug", "Toggle debug mode" },
        { "/bolt debug config", "Show configuration debug info" },
        { "/bolt transmog", "Open Transmog Presets" },
        { "/bolt camp", "Show what the camp bar sees (WoW: Forever)" },
        { "/bolt edge", "Show how far the minimap may go past the screen edge" },
        { "/bolt range", "Show what the nameplate range dot checks on your target" },
        { "/bolt dots", "Show what the nameplate DoT overlay reads on your target (WoW: Forever)" },
        { "/bolt reset", "Clear any stuck Skyriding key overrides" },
        { "/bolt reload", "Reload the UI" },
    }
    for _, line in ipairs(lines) do
        print(("  |cffffffff%s|r - %s"):format(line[1], line[2]))
    end
end

local commands = {}

commands.help = PrintHelp
commands.config = function() BOLT:OpenConfigPanel() end
commands.reload = function() ReloadUI() end

commands.status = function()
    BOLT:Print("Module status:")
    for _, mod in ipairs(BOLT:GetToggleableModules()) do
        local enabled = BOLT:IsModuleEnabled(mod.name)
        print(("  %s: %s"):format(mod.displayName or mod.name,
            enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
    end
end

commands.toggle = function(target)
    if not target then
        BOLT:Print("Usage: /bolt toggle <module>")
        return
    end
    if target == "debug" then
        local enabled = not BOLT:GetConfig("debug")
        BOLT:SetConfig(enabled, "debug")
        BOLT:Print("Debug mode " .. (enabled and "enabled" or "disabled") .. ".")
        return
    end

    local name = ResolveModuleName(target)
    if BOLT.defaultModuleStates[name] == nil then
        BOLT:Print("Unknown module '" .. target .. "'. Type /bolt status for the list.")
        return
    end
    BOLT:SetModuleEnabled(name, not BOLT:IsModuleEnabled(name))
end

commands.reset = function()
    local skyriding = BOLT.modules.skyriding
    if skyriding then
        skyriding:EmergencyReset()
    else
        BOLT:Print("Skyriding is not available on this client.")
    end
end

commands.transmog = function(arg)
    local mod = BOLT.modules.transmogPresets
    if not mod then
        BOLT:Print("Transmog Presets is not available.")
    elseif arg == "debug" then
        mod:PrintDebug()
    else
        mod:ShowUI()
    end
end

commands.camp = function()
    local mod = BOLT.modules.campfire
    if mod then
        mod:PrintDebug()
    else
        BOLT:Print("Campfire is only available on WoW: Forever.")
    end
end

commands.edge = function()
    local mod = BOLT.modules.editModeOptions
    if mod and mod.DescribeMinimapEdge then
        if mod.ApplyMinimapEdge then mod.ApplyMinimapEdge() end
        BOLT:Print("Minimap screen edge: " .. mod:DescribeMinimapEdge())
    end
end

commands.range = function()
    local mod = BOLT.modules.nameplatesEnhancement
    if mod then
        mod:PrintRangeDebug()
    else
        BOLT:Print("Nameplates module is not loaded.")
    end
end

commands.dots = function()
    local mod = BOLT.modules.nameplatesEnhancement
    if mod then
        mod:PrintDotDebug()
    else
        BOLT:Print("Nameplates module is not loaded.")
    end
end

commands.debug = function(arg)
    if arg ~= "config" then
        BOLT:Print("Usage: /bolt debug config")
        return
    end
    BOLT:Print("=== B.O.L.T configuration ===")
    for name, enabled in pairs(BOLTDB.moduleStates) do
        print(("  %s = %s"):format(name, tostring(enabled)))
    end
    print("  Edit Mode layout = " .. tostring(BOLT.layoutName))
    for name, enabled in pairs(BOLT:GetLayout().modules) do
        print(("  %s = %s (this layout)"):format(name, tostring(enabled)))
    end
    print("  debug = " .. tostring(BOLT:GetConfig("debug")))
    print("  player key = " .. BOLT:GetPlayerKey())
    print("  client = " .. (BOLT.isForever and "WoW: Forever" or "Midnight"))
end

SLASH_BOLT1 = "/bolt"
SLASH_BOLT2 = "/b"
SlashCmdList.BOLT = function(msg)
    if not BOLT._started then
        BOLT:Print("Still loading, try again in a moment.")
        return
    end

    local command, arg = msg:lower():match("^%s*(%S*)%s*(%S*)")
    if command == "" then
        BOLT:OpenConfigPanel()
        return
    end

    local handler = commands[command]
    if handler then
        handler(arg ~= "" and arg or nil)
    else
        BOLT:Print("Unknown command. Type /bolt help for the list.")
    end
end
