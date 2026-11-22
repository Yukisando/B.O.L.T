-- B.O.L.T Cooldown Sans
-- Puts ColdSnap's own typeface, Cooldown Sans, on the whole game: every font object (UI text,
-- chat, tooltips, nameplates, unit frames) and the floating damage numbers in the world.
-- The fonts are static instances of the variable font (Medium for text, Bold for damage numbers),
-- since the client can't pick an axis of a variable font. Latin, Greek and Cyrillic only, so
-- the module skips itself on Korean and Chinese clients.

local ADDON_NAME, BOLT = ...

local CooldownFont = {
    displayName = "Cooldown Sans Font",
}

local FONT = "Interface\\AddOns\\BOLT\\Fonts\\Cooldown-Medium.ttf"
local FONT_BOLD = "Interface\\AddOns\\BOLT\\Fonts\\Cooldown-Bold.ttf"
local UNSUPPORTED_LOCALES = { koKR = true, zhCN = true, zhTW = true }

local originals = {}       -- font object or chat frame -> { file, size, flags }
local appliedAtLoad = false -- the world fonts below are only read while the game loads

local function ReplaceFont(object)
    if not (object and object.GetFont) then return end
    local file, size, flags = object:GetFont()
    if not (file and size and size > 0) then return end
    if not originals[object] then
        if file == FONT then return end
        originals[object] = { file, size, flags }
    end
    object:SetFont(FONT, size, flags or "")
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

local function ApplyFonts()
    -- GetFonts lists every named Font object, Blizzard's and addons' alike.
    for _, entry in ipairs(GetFonts and GetFonts() or {}) do
        ReplaceFont(type(entry) == "string" and _G[entry] or entry)
    end
    for _, frame in ipairs(ChatFrames()) do
        ReplaceFont(frame)
    end
end

local function RestoreFonts()
    for object, font in pairs(originals) do
        object:SetFont(font[1], font[2], font[3] or "")
    end
    wipe(originals)
end

-- Damage numbers and the names above characters are drawn by the client from these globals,
-- read while the world loads: set them before that, on ADDON_LOADED, or they wait for a /reload.
-- Only globals the client reads are touched: Lua-read ones such as STANDARD_TEXT_FONT would
-- taint Blizzard code (nameplates get their font from font objects anyway).
local function ApplyWorldFonts()
    DAMAGE_TEXT_FONT = FONT_BOLD
    UNIT_NAME_FONT = FONT
    if UNIT_NAME_FONT_ROMAN then UNIT_NAME_FONT_ROMAN = FONT end
    if UNIT_NAME_FONT_CYRILLIC then UNIT_NAME_FONT_CYRILLIC = FONT end
end

local function WantedAtLoad()
    local states = BOLTDB and BOLTDB.moduleStates
    local state = states and states.cooldownFont
    if state == nil then state = BOLT.defaultModuleStates.cooldownFont end
    return state == true
end

StaticPopupDialogs.BOLT_FONT_RELOAD = {
    text = "B.O.L.T: damage numbers and some text change font after a reload.",
    button1 = RELOADUI or "Reload UI",
    button2 = LATER or "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function OfferReload(enabled)
    if enabled ~= appliedAtLoad then
        StaticPopup_Show("BOLT_FONT_RELOAD")
    end
end

function CooldownFont:IsSupported()
    return not UNSUPPORTED_LOCALES[GetLocale()]
end

function CooldownFont:OnEnable()
    ApplyFonts()
    OfferReload(true)
end

function CooldownFont:OnDisable()
    RestoreFonts()
    OfferReload(false)
end

BOLT:RegisterModule("cooldownFont", CooldownFont)

if not CooldownFont:IsSupported() then return end

-- Saved variables arrive with BOLT's ADDON_LOADED; later addons (load-on-demand Blizzard ones
-- included) may bring new font objects, which get the font as they load.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, addonName)
    if addonName == ADDON_NAME then
        appliedAtLoad = WantedAtLoad()
        if appliedAtLoad then
            ApplyWorldFonts()
            ApplyFonts()
        end
    elseif CooldownFont.active or (appliedAtLoad and not BOLT._started) then
        ApplyFonts()
    end
end)
