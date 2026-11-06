-- B.O.L.T Ranged Attack Timer Module
-- A thin bar that fills between automatic shots (Auto Shot, and wand Shoot on WoW: Forever), so
-- casts and moves can be timed between them. It sits under the Cooldown Manager's main row at its
-- width, or floats below the character when the Cooldown Manager isn't shown.
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

local HEIGHT = 4
local FLOAT_WIDTH = 140
local FLOAT_Y = -170     -- below the character, where the Personal Resource Display sits
local WHITE = "Interface\\Buttons\\WHITE8X8"

local bar
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

local function Anchor()
    bar:ClearAllPoints()
    local viewer = EssentialCooldownViewer
    if viewer and viewer:IsShown() and viewer:GetWidth() > 20 then
        bar:SetPoint("TOPLEFT", viewer, "BOTTOMLEFT", 0, -3)
        bar:SetPoint("TOPRIGHT", viewer, "BOTTOMRIGHT", 0, -3)
    else
        local prd = PersonalResourceDisplayFrame
        if prd and prd:IsShown() then
            bar:SetPoint("TOP", prd, "BOTTOM", 0, -3)
        else
            bar:SetPoint("CENTER", UIParent, "CENTER", 0, FLOAT_Y)
        end
        bar:SetWidth(FLOAT_WIDTH)
    end
    bar:SetHeight(HEIGHT)
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
    bar:SetFrameStrata("MEDIUM")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- Blizzard's own cast bar fill, kept thin and dim so it stays in the background.
    local fill = NativeArt.ResolveAtlas("ui-castingbar-filling-standard")
    if fill then
        bar:SetStatusBarTexture(fill)
    else
        bar:SetStatusBarTexture(WHITE)
        bar:SetStatusBarColor(1, 0.78, 0.3)
    end

    local outline = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    outline:SetTexture(WHITE)
    outline:SetVertexColor(0, 0, 0, 0.8)
    outline:SetPoint("TOPLEFT", -1, 1)
    outline:SetPoint("BOTTOMRIGHT", 1, -1)
    local background = bar:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(WHITE)
    background:SetVertexColor(0.08, 0.07, 0.05, 0.75)
    background:SetAllPoints()

    bar:SetAlpha(0.85)
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
    local events = self.eventFrame
    events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterUnitEvent("UNIT_RANGEDDAMAGE", "player")
    events:RegisterEvent("START_AUTOREPEAT_SPELL")
    events:RegisterEvent("STOP_AUTOREPEAT_SPELL")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    ReadSpeed()
end

function RangedTimer:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    repeating, startTime = false, nil
    if bar then bar:Hide() end
end

BOLT:RegisterModule("rangedTimer", RangedTimer)
