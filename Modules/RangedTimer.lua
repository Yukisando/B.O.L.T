-- B.O.L.T Ranged Attack Timer Module
-- A bar that fills between automatic shots (Auto Shot, and wand Shoot on WoW: Forever), so casts
-- and moves can be timed between them. It is a child of the Personal Resource Display, drawn with
-- the same bar art, sitting as one more bar under its health/power stack. With the Personal
-- Resource Display turned off (or "Attach" unticked) it floats on its own; move it and set its
-- width in Edit Mode ("Ranged Attack Timer").
--
-- Only repeating shots are timed: they are the player's own spell casts, which addons always see.
-- Melee swings would need the combat log, which the game keeps from addons.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode
local EDIT_KEY = "rangedTimer"

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
local holder -- where the floating bar sits; the frame Edit Mode moves
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

local function Attached()
    return BOLT:GetConfig("rangedTimer", "attach") ~= false and PersonalDisplayOn()
end

local function PlaceHolder()
    if not holder or InCombatLockdown() then return end
    local point, x, y = EditMode:GetPosition(EDIT_KEY)
    holder:ClearAllPoints()
    holder:SetPoint(point, UIParent, point, x, y)
    holder:SetSize(EditMode:Get(EDIT_KEY, "width", FLOAT_WIDTH), DEFAULT_HEIGHT)
end

local function Anchor()
    local prd = PersonalResourceDisplayFrame
    bar:ClearAllPoints()
    if Attached() then
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
        bar:SetAllPoints(holder)
    end
end

---------------------------------------------------------------------------
-- Edit Mode: the floating spot is a frame of its own; a preview shows while editing.
---------------------------------------------------------------------------

local function ShowPreview()
    if not (RangedTimer.active and holder) then return end
    PlaceHolder()
    holder:SetShown(not Attached())
end

local function EndPreview()
    if holder then holder:Hide() end
end

local function BuildHolder()
    holder = CreateFrame("Frame", "BOLTRangedTimerAnchor", UIParent)
    holder:SetSize(FLOAT_WIDTH, DEFAULT_HEIGHT)
    holder:SetClampedToScreen(true)
    holder:Hide()
    local preview = holder:CreateTexture(nil, "ARTWORK")
    preview:SetPoint("TOPLEFT")
    preview:SetPoint("BOTTOMLEFT")
    preview:SetWidth(FLOAT_WIDTH * 0.6)
    local fill = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar")
    if fill then preview:SetAtlas(fill) else preview:SetTexture(WHITE) end
    preview:SetVertexColor(COLOR[1], COLOR[2], COLOR[3])
    holder:SetScript("OnSizeChanged", function(self, width) preview:SetWidth(width * 0.6) end)
    local back = holder:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints()
    back:SetColorTexture(0, 0, 0, 0.6)
    PlaceHolder()

    if not EditMode.available then return end
    local attach = EditMode:Checkbox("Attach under the Personal Resource Display", { "rangedTimer", "attach" }, {
        desc = "While the Personal Resource Display is on, the timer is one more bar under it. Untick to keep it here.",
    })
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "Ranged Attack Timer",
        frame = holder,
        default = { point = "CENTER", x = 0, y = FLOAT_Y },
        onEnter = ShowPreview,
        onExit = EndPreview,
        apply = function()
            PlaceHolder()
            if bar then Anchor() end
        end,
        settings = {
            attach,
            EditMode:Slider("Width", nil, {
                min = 80, max = 400, step = 10, default = FLOAT_WIDTH,
                get = function() return EditMode:Get(EDIT_KEY, "width", FLOAT_WIDTH) end,
                set = function(value)
                    EditMode:Set(EDIT_KEY, "width", value)
                    PlaceHolder()
                end,
            }),
        },
    })
    -- The same choice under the Personal Resource Display's own Edit Mode dialog.
    EditMode:AddSystemSettings("PersonalResourceDisplay", nil, nil, {
        EditMode:Checkbox("Ranged attack timer under it", { "rangedTimer", "attach" }, {
            desc = "B.O.L.T's bar that fills between your auto shots. Off, it floats on its own (select it to move it).",
            hidden = function() return not RangedTimer.active or not PersonalDisplayOn() end,
        }),
    }, true)
end

function RangedTimer:OnSettingChanged()
    if bar then Anchor() end
    if EditMode:IsActive() then ShowPreview() end
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
    BuildHolder()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", OnEvent)
end

function RangedTimer:OnEnable()
    if not bar then Build() end
    HookDisplay()
    PlaceHolder()
    Anchor()
    if EditMode:IsActive() then ShowPreview() end
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
    EndPreview()
end

BOLT:RegisterModule("rangedTimer", RangedTimer)
