-- B.O.L.T Ranged Attack Timer Module
-- A bar that fills between automatic shots (Auto Shot, and wand Shoot on WoW: Forever), so casts
-- and moves can be timed between them. It is a child of the Personal Resource Display, drawn with
-- the same bar art, sitting as one more bar under its health/power stack. With the Personal
-- Resource Display turned off it floats below the character instead.
--
-- Only repeating shots are timed: they are the player's own spell casts, which addons always see.
-- Melee swings would need the combat log, which the game keeps from addons.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt

local RangedTimer = {
    displayName = "Ranged Attack Timer",
}

local REPEAT_SPELLS = {
    [75] = true,    -- Auto Shot
    [5019] = true,  -- Shoot (wands, WoW: Forever)
}
local CLASSES = BOLT.isForever
    and { HUNTER = true, PRIEST = true, MAGE = true, WARLOCK = true }
    or { HUNTER = true }

local COLOR = { 1, 0.76, 0.18 }  -- amber, apart from health green and power blue
local DEFAULT_HEIGHT = 10        -- Personal Resource Display's power bar height when unreadable
local DEFAULT_PADDING = 4
local FLOAT_WIDTH = 200
local FLOAT_Y = -170             -- below the character, where the Personal Resource Display sits
local WHITE = "Interface\\Buttons\\WHITE8X8"

local bar
local hooked = false
local speed = 2          -- last readable shot interval; stats can be hidden in some fights
local startTime, duration
local repeating = false

function RangedTimer:IsSupported()
    local _, class = UnitClass("player")
    return CLASSES[class] == true
end

local function ReadSpeed()
    local value = UnitRangedDamage("player")
    if value and not BOLT.IsSecret(value) and value > 0 then
        speed = value
    end
    return speed
end

local function Readable(value, fallback)
    if value and not BOLT.IsSecret(value) and value > 0 then return value end
    return fallback
end

-- The display can be out of combat-hidden right now (first shot of a pull lands before it shows),
-- so "turned on" is asked of the setting, not of IsShown.
local function PersonalDisplayOn()
    local prd = PersonalResourceDisplayFrame
    if not prd then return false end
    if prd:IsShown() then return true end
    local rules = C_GameRules
    if rules and rules.IsPersonalResourceDisplayEnabled then
        return rules.IsPersonalResourceDisplayEnabled() == true
    end
    return C_CVar.GetCVarBool("nameplateShowSelf") == true
end

local function Anchor()
    local prd = PersonalResourceDisplayFrame
    bar:ClearAllPoints()
    if PersonalDisplayOn() then
        -- A child of the display: same scale, shown and hidden with it, and its bottom edge
        -- follows every bar Blizzard adds or hides above.
        if bar:GetParent() ~= prd then bar:SetParent(prd) end
        local padding = prd.GetBarPadding and Readable(prd:GetBarPadding(), DEFAULT_PADDING)
            or DEFAULT_PADDING
        local power = prd.PowerBar
        bar:SetPoint("TOPLEFT", prd, "BOTTOMLEFT", 0, -padding)
        bar:SetPoint("TOPRIGHT", prd, "BOTTOMRIGHT", 0, -padding)
        bar:SetHeight(power and Readable(power:GetHeight(), DEFAULT_HEIGHT) or DEFAULT_HEIGHT)
    else
        if bar:GetParent() ~= UIParent then bar:SetParent(UIParent) end
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, FLOAT_Y)
        bar:SetSize(FLOAT_WIDTH, DEFAULT_HEIGHT)
    end
end

-- Edit Mode changes to the display's bar height or spacing move the timer with it.
local function HookDisplay()
    local prd = PersonalResourceDisplayFrame
    if hooked or not prd then return end
    hooked = true
    for _, method in ipairs({ "SetPowerBarHeight", "SetBarPadding", "SetBarWidth", "UpdateFrameHeight" }) do
        if prd[method] then
            hooksecurefunc(prd, method, function()
                if bar then Anchor() end
            end)
        end
    end
end

local function OnUpdate(self)
    if not startTime then return end
    local progress = (GetTime() - startTime) / duration
    if progress >= 1 then
        self:SetValue(1)
        if not repeating then
            startTime = nil
            self:Hide()
        end
        return
    end
    self:SetValue(progress)
end

local function Build()
    bar = CreateFrame("StatusBar", "BOLTRangedAttackTimer", UIParent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- The Personal Resource Display's own bar art (PersonalResourceStatusBar template).
    local fill = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar")
    local back = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar-BG")
    if fill then
        bar:SetStatusBarTexture(fill)
    else
        bar:SetStatusBarTexture(WHITE)
    end
    bar:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])

    local background = bar:CreateTexture(nil, "BACKGROUND")
    if back then
        background:SetAtlas(back)
        background:SetPoint("TOPLEFT", -2, 3)
        background:SetPoint("BOTTOMRIGHT", 6, -7)
    else
        background:SetTexture(WHITE)
        background:SetVertexColor(0, 0, 0, 0.7)
        background:SetPoint("TOPLEFT", -1, 1)
        background:SetPoint("BOTTOMRIGHT", 1, -1)
    end

    bar:SetScript("OnUpdate", OnUpdate)
    bar:Hide()
end

local function OnEvent(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if BOLT.IsSecret(spellID) or not REPEAT_SPELLS[spellID] then return end
        startTime, duration = GetTime(), ReadSpeed()
        Anchor()
        bar:SetValue(0)
        bar:Show()
    elseif event == "START_AUTOREPEAT_SPELL" then
        repeating = true
        ReadSpeed()
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        repeating = false
    elseif event == "CVAR_UPDATE" then
        if bar:IsShown() then Anchor() end
    else
        ReadSpeed()
    end
end

function RangedTimer:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", OnEvent)
end

function RangedTimer:OnEnable()
    if not bar then Build() end
    HookDisplay()
    Anchor()
    local events = self.eventFrame
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_RANGEDDAMAGE", "player")
    events:RegisterEvent("START_AUTOREPEAT_SPELL")
    events:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("CVAR_UPDATE")
    ReadSpeed()
end

function RangedTimer:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    repeating, startTime = false, nil
    if bar then bar:Hide() end
end

BOLT:RegisterModule("rangedTimer", RangedTimer)
