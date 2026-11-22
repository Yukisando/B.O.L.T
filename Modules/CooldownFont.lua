-- B.O.L.T Cooldown Sans
-- Puts ColdSnap's own typeface, Cooldown Sans, on the game, part by part (PARTS): interface
-- text, chat, nameplates, names above characters, damage numbers and the combat text above you.
-- The fonts are static instances of the variable font (Medium for text, Bold for numbers),
-- since the client can't pick an axis of a variable font. Latin, Greek and Cyrillic only, so
-- the module skips itself on Korean and Chinese clients.
-- Only text set in Blizzard's own Latin fonts changes: addons' fonts stay, since some are icon or
-- symbol fonts whose glyphs Cooldown Sans doesn't have (they showed as squares).
-- The choice of parts is account-wide, like the module's on/off: both are needed on ADDON_LOADED,
-- before the character's profile is set up.

local ADDON_NAME, BOLT = ...

local CooldownFont = {
    displayName = "Cooldown Sans Font",
}

local FONT = "Interface\\AddOns\\BOLT\\Fonts\\Cooldown-Medium.ttf"
local FONT_BOLD = "Interface\\AddOns\\BOLT\\Fonts\\Cooldown-Bold.ttf"
-- Bold with every letter's side space cut to 12 units: the client draws damage numbers without
-- kerning, and the text font's spacing left wide gaps between the digits.
local FONT_DAMAGE = "Interface\\AddOns\\BOLT\\Fonts\\Cooldown-Damage.ttf"
local UNSUPPORTED_LOCALES = { koKR = true, zhCN = true, zhTW = true }

-- relog: drawn by the client from a font it loads as you enter the world.
CooldownFont.PARTS = {
    { key = "ui", label = "Interface (menus, tooltips, unit frames, quests, bags)" },
    { key = "chat", label = "Chat and chat bubbles" },
    { key = "nameplates", label = "Nameplates" },
    { key = "names", label = "Names above characters", relog = true },
    { key = "damage", label = "Damage numbers on enemies", relog = true },
    { key = "combatText", label = "Combat text above you (\"Mana Low\", incoming damage)" },
}

local BLIZZARD_FONTS = {
    FRIZQT__ = true, FRIZQT___CYR = true, ARIALN = true, K_PAGETEXT = true,
    MORPHEUS = true, MORPHEUS_CYR = true, SKURRI = true, SKURRI_CYR = true,
}

-- Floating combat text is one fixed-size font that Blizzard scales with SetTextHeight. SetFont
-- at its 64 px left the scaled letters far apart; it gets a 120 px base instead (as ElvUI does).
-- The other world fonts are scaled the same way and stay as they are.
local COMBAT_TEXT_SIZE = 120

local originals = {}   -- font object or chat frame -> { file, size, flags, part }
local moduleOn = false
local loadedWorld = {} -- [part] = on, for the relog parts, as the world loaded

local function IsPartOn(key)
    local parts = BOLTDB and BOLTDB.cooldownFontParts
    return not (parts and parts[key] == false)
end

local function IsBlizzardFont(file)
    local name = type(file) == "string" and file:upper():match("([^\\/]+)%.TTF$")
    return name ~= nil and BLIZZARD_FONTS[name] == true
end

local function PartOfFont(name)
    if type(name) ~= "string" then return "ui" end
    if name:find("NamePlate", 1, true) then return "nameplates" end
    if name:find("^CombatText") then return "combatText" end
    if name:find("World", 1, true) then return nil end
    if name:find("Chat", 1, true) or name:find("Bubble", 1, true) then return "chat" end
    return "ui"
end

local function ReplaceFont(object, part)
    if not (object and object.GetFont) or originals[object] then return end
    local file, size, flags = object:GetFont()
    if not (file and size and size > 0 and IsBlizzardFont(file)) then return end
    local original = { file, size, flags, part }
    originals[object] = original
    if part == "combatText" then
        object:SetFont(FONT_BOLD, COMBAT_TEXT_SIZE, original[3] or "")
    else
        object:SetFont(FONT, original[2], original[3] or "")
    end
end

local function ChatFrames()
    local frames = {}
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame then
            table.insert(frames, frame)
            table.insert(frames, _G["ChatFrame" .. i .. "EditBox"])
        end
    end
    return frames
end

-- Puts back the fonts of parts that are off (all of them with the module off).
local function RestoreFonts()
    for object, font in pairs(originals) do
        if not (moduleOn and IsPartOn(font[4])) then
            object:SetFont(font[1], font[2], font[3] or "")
            originals[object] = nil
        end
    end
end

local function ApplyFonts()
    RestoreFonts()
    if not moduleOn then return end
    -- GetFonts lists every named Font object, Blizzard's and addons' alike.
    for _, entry in ipairs(GetFonts and GetFonts() or {}) do
        local name = type(entry) == "string" and entry or nil
        local part = PartOfFont(name)
        if part and IsPartOn(part) then
            ReplaceFont(name and _G[name] or entry, part)
        end
    end
    if IsPartOn("chat") then
        for _, frame in ipairs(ChatFrames()) do
            ReplaceFont(frame, "chat")
        end
    end
end

-- Damage numbers and the names above characters are drawn by the client from these globals,
-- read as the world loads: a change shows after logging out to the character list and back in,
-- never after a /reload. They are set as early as possible, when this file loads (the saved
-- choice isn't known yet, so the default "on" goes first), then from the saved choice on
-- ADDON_LOADED and again on PLAYER_LOGIN in case another addon set them in between.
-- Only globals the client reads are touched: Lua-read ones such as STANDARD_TEXT_FONT would
-- taint Blizzard code (nameplates get their font from font objects anyway).
local WORLD_FONTS = {
    { key = "DAMAGE_TEXT_FONT", part = "damage", font = FONT_DAMAGE },
    { key = "UNIT_NAME_FONT", part = "names", font = FONT },
    { key = "UNIT_NAME_FONT_ROMAN", part = "names", font = FONT },
    { key = "UNIT_NAME_FONT_CYRILLIC", part = "names", font = FONT },
}
local blizzardWorldFonts = {}

local function SetWorldFonts()
    for _, world in ipairs(WORLD_FONTS) do
        local key = world.key
        if _G[key] ~= nil then
            if blizzardWorldFonts[key] == nil then blizzardWorldFonts[key] = _G[key] end
            local on = moduleOn and IsPartOn(world.part)
            _G[key] = on and world.font or blizzardWorldFonts[key]
        end
    end
end

local function WantedAtLoad()
    local states = BOLTDB and BOLTDB.moduleStates
    local state = states and states.cooldownFont
    if state == nil then state = BOLT.defaultModuleStates.cooldownFont end
    return state == true
end

StaticPopupDialogs.BOLT_FONT_RELOG = {
    text = "B.O.L.T: names above characters and damage numbers change font after you log out to the character list and log back in.",
    button1 = OKAY or "Okay",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

StaticPopupDialogs.BOLT_FONT_RELOAD = {
    text = "B.O.L.T: some text keeps Cooldown Sans until you reload the UI.",
    button1 = RELOADUI or "Reload UI",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- After a change: the relog parts differ from what the world loaded with, or a part went off
-- (frames that copied the font when they were made only let go of it on a reload).
local function Refresh(turnedOff)
    SetWorldFonts()
    ApplyFonts()
    for _, part in ipairs(CooldownFont.PARTS) do
        if part.relog and (moduleOn and IsPartOn(part.key)) ~= loadedWorld[part.key] then
            StaticPopup_Show("BOLT_FONT_RELOG")
            return
        end
    end
    if turnedOff then StaticPopup_Show("BOLT_FONT_RELOAD") end
end

function CooldownFont:IsPartEnabled(key)
    return IsPartOn(key)
end

function CooldownFont:SetPartEnabled(key, enabled)
    BOLTDB.cooldownFontParts = BOLTDB.cooldownFontParts or {}
    BOLTDB.cooldownFontParts[key] = enabled and true or false
    if self.active then Refresh(not enabled) end
end

-- /bolt font: what the client was told to use for the damage numbers and names.
function CooldownFont:PrintDebug()
    local function Known(path)
        local asset = C_UIFileAsset
        if not asset then return "?" end
        local loose = asset.IsLooseFile and asset.IsLooseFile(path)
        local known = asset.IsKnownFile and asset.IsKnownFile(path)
        return ("loose=%s known=%s"):format(tostring(loose), tostring(known))
    end
    BOLT:Print("Cooldown Sans: on = " .. tostring(moduleOn))
    for _, part in ipairs(self.PARTS) do
        local loaded = part.relog and (", as the world loaded: " .. tostring(loadedWorld[part.key] == true)) or ""
        print(("  %s: %s%s"):format(part.key, tostring(IsPartOn(part.key)), loaded))
    end
    print("  DAMAGE_TEXT_FONT = " .. tostring(DAMAGE_TEXT_FONT))
    print("  UNIT_NAME_FONT = " .. tostring(UNIT_NAME_FONT))
    print("  Damage file: " .. Known(FONT_DAMAGE) .. ", Medium file: " .. Known(FONT))
end

function CooldownFont:IsSupported()
    return not UNSUPPORTED_LOCALES[GetLocale()]
end

function CooldownFont:OnEnable()
    moduleOn = true
    Refresh(false)
end

function CooldownFont:OnDisable()
    moduleOn = false
    Refresh(true)
end

BOLT:RegisterModule("cooldownFont", CooldownFont)

if not CooldownFont:IsSupported() then return end

moduleOn = BOLT.defaultModuleStates.cooldownFont == true
SetWorldFonts()

-- Saved variables arrive with BOLT's ADDON_LOADED; later addons (load-on-demand Blizzard ones
-- included) may bring new font objects, which get the font as they load.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(_, event, addonName)
    if event == "PLAYER_LOGIN" then
        SetWorldFonts()
        for _, part in ipairs(CooldownFont.PARTS) do
            if part.relog then loadedWorld[part.key] = moduleOn and IsPartOn(part.key) end
        end
    elseif addonName == ADDON_NAME then
        moduleOn = WantedAtLoad()
        SetWorldFonts()
        ApplyFonts()
    elseif moduleOn then
        ApplyFonts()
    end
end)
