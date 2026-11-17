-- B.O.L.T Swing Timer Module (module key "rangedTimer", kept so settings carry over)
-- Bars that fill between automatic attacks, so casts and moves can be timed between them.
-- On the Personal Resource Display they are faint light sweeps: main hand and ranged across its
-- health bar (whichever swung last), the off hand across its power bar. No rows of their own, so
-- the pet and target bars sit around them. With the display turned off (or "Attach" unticked)
-- they are bars that float on their own; move them and set their width in Edit Mode.
--
-- WoW: Forever reports every swing (main hand, off hand, ranged) with its duration through
-- PLAYER_SWING (C_SwingTimer, the same event Blizzard's own swing timer reads). Other clients have
-- no such event and the combat log is closed to addons, so there only repeating shots are timed:
-- they are the player's own spell casts, which addons always see.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt
local EditMode = BOLT.EditMode
local EDIT_KEY = "rangedTimer"

local RangedTimer = {
    displayName = "Swing Timer",
}

local SWING = C_SwingTimer and Enum.PlayerSwingType -- nil where the game doesn't report swings
local REPEAT_SPELLS = {
    [75] = true,    -- Auto Shot
    [5019] = true,  -- Shoot (wands, WoW: Forever)
}
local SHOT_CLASSES = { HUNTER = true }
local NATIVE_CVAR = "showSwingTimer" -- Blizzard's own swing timer (Options > Combat)

local COLOR = { 1, 0.76, 0.18 }  -- amber, apart from health green and power blue
local OVERLAY_COLOR = { 1, 1, 1, 0.22 } -- light enough to read the health and power under it
local DEFAULT_HEIGHT = 10        -- the floating bar's height
local FLOAT_WIDTH = 200
local FLOAT_Y = -170             -- below the character, where the Personal Resource Display sits
local FLOAT_GAP = 3              -- between the floating main and off-hand bars
local SHOT_ECHO = 0.2            -- a cast this soon after a ranged swing is the same shot
local WHITE = "Interface\\Buttons\\WHITE8X8"

local bar     -- main hand and ranged
local offBar  -- off hand
local holder  -- where the floating bars sit; the frame Edit Mode moves
local hooked = false
local shotSpeed = 2      -- last readable shot interval; stats can be hidden in some fights
local repeating = false  -- Auto Shot / Shoot is on
local meleeing = false   -- auto attack is on
local lastRangedSwing = 0

function RangedTimer:IsSupported()
    if SWING then return true end
    local _, class = UnitClass("player")
    return SHOT_CLASSES[class] == true
end

local function Readable(value)
    if value and not BOLT.IsSecret(value) and value > 0 then return value end
end

local function ReadShotSpeed()
    shotSpeed = Readable(UnitRangedDamage("player")) or shotSpeed
    return shotSpeed
end

-- The swing's length from the weapon's speed, for when an event's own duration can't be read.
local function EquippedSpeed(swingType)
    local main, off, ranged = UnitAttackSpeed("player")
    if swingType == SWING.OffHand then return Readable(off) end
    if swingType == SWING.Ranged then return Readable(ranged) or ReadShotSpeed() end
    return Readable(main)
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

-- Overlay: a flat light fill with no border. Floating: the display's own bar art in amber.
local function SetOverlayStyle(timer, overlay)
    if timer.overlay == overlay then return end
    timer.overlay = overlay
    if overlay then
        timer:SetStatusBarTexture(WHITE)
        timer:SetStatusBarColor(unpack(OVERLAY_COLOR))
    else
        timer:SetStatusBarTexture(NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar") or WHITE)
        timer:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    end
    timer.background:SetShown(not overlay)
end

-- Overlays are children of the display (same scale, shown and hidden with it), laid over its
-- health or power bar and drawn above their fill.
local function Overlay(timer, prd, target)
    if timer:GetParent() ~= prd then timer:SetParent(prd) end
    timer:SetAllPoints(target)
    timer:SetFrameLevel(target:GetFrameLevel() + 4)
    SetOverlayStyle(timer, true)
end

local function Float(timer)
    if timer:GetParent() ~= UIParent then timer:SetParent(UIParent) end
    SetOverlayStyle(timer, false)
end

local function Anchor()
    local prd = PersonalResourceDisplayFrame
    local health = prd and (prd.HealthBarsContainer or prd)
    local power = prd and prd.PowerBar
    bar:ClearAllPoints()
    offBar:ClearAllPoints()
    if Attached() and health then
        Overlay(bar, prd, health)
        Overlay(offBar, prd, power or health)
    else
        Float(bar)
        bar:SetAllPoints(holder)
        Float(offBar)
        offBar:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -FLOAT_GAP)
        offBar:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -FLOAT_GAP)
        offBar:SetHeight(DEFAULT_HEIGHT / 2)
    end
end

---------------------------------------------------------------------------
-- Blizzard's own swing timer: turned off while this one is on, so the two don't both show.
-- Not turned back on when this one is switched off; that stays the player's choice in Options.
---------------------------------------------------------------------------

local function TurnOffNativeTimer()
    if not SWING or not C_CVar.GetCVarInfo(NATIVE_CVAR) then return end
    if not C_CVar.GetCVarBool(NATIVE_CVAR) then return end
    if InCombatLockdown() then
        RangedTimer.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    C_CVar.SetCVar(NATIVE_CVAR, "0")
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
    local attach = EditMode:Checkbox("Overlay on the Personal Resource Display", { "rangedTimer", "attach" }, {
        desc = "While the Personal Resource Display is on, the timer is a faint sweep across its health bar (the off hand across its power bar). Untick to keep it here as a bar of its own.",
    })
    EditMode:AddFrame({
        key = EDIT_KEY,
        name = "Swing Timer",
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
        EditMode:Checkbox("Swing timer on its bars", { "rangedTimer", "attach" }, {
            desc = "B.O.L.T's timer between your auto attacks, as a faint sweep across the health bar (the off hand across the power bar). Off, it floats on its own as a bar (select it to move it).",
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

---------------------------------------------------------------------------
-- Timing: each bar fills over its swing and then stays full while that attack is still on
-- (auto attack for melee, Auto Shot / Shoot for ranged), else it goes away.
---------------------------------------------------------------------------

local function OnUpdate(self)
    if not self.startTime then return end
    local progress = (GetTime() - self.startTime) / self.duration
    if progress >= 1 then
        self:SetValue(1)
        if not (self.ranged and repeating or not self.ranged and meleeing) then
            self.startTime = nil
            self:Hide()
        end
        return
    end
    self:SetValue(progress)
end

local function StartSwing(timer, length, ranged)
    if not length then return end
    timer.startTime, timer.duration, timer.ranged = GetTime(), length, ranged
    Anchor()
    timer:SetValue(0)
    timer:Show()
end

local function BuildTimer(name)
    local timer = CreateFrame("StatusBar", name, UIParent)
    timer:SetMinMaxValues(0, 1)
    timer:SetValue(0)

    -- The Personal Resource Display's own bar art (PersonalResourceStatusBar template).
    local back = NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar-BG")
    timer:SetStatusBarTexture(NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar") or WHITE)
    timer:SetStatusBarColor(COLOR[1], COLOR[2], COLOR[3])
    local background = timer:CreateTexture(nil, "BACKGROUND")
    timer.background = background
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

    timer:SetScript("OnUpdate", OnUpdate)
    timer:Hide()
    return timer
end

local function Build()
    bar = BuildTimer("BOLTRangedAttackTimer")
    offBar = BuildTimer("BOLTOffHandSwingTimer")
end

-- swingDuration isn't marked secret in the API, but it is read defensively all the same.
local function OnSwing(swingDuration, swingType)
    local length = Readable(swingDuration) or EquippedSpeed(swingType)
    if swingType == SWING.OffHand then
        StartSwing(offBar, length, false)
    elseif swingType == SWING.Ranged then
        lastRangedSwing = GetTime()
        StartSwing(bar, length, true)
    else
        StartSwing(bar, length, false)
    end
end

local function OnEvent(_, event, ...)
    if event == "PLAYER_SWING" then
        OnSwing(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- On Forever a shot also arrives as PLAYER_SWING; this only covers what that missed.
        local _, _, spellID = ...
        if BOLT.IsSecret(spellID) or not REPEAT_SPELLS[spellID] then return end
        if GetTime() - lastRangedSwing < SHOT_ECHO then return end
        StartSwing(bar, ReadShotSpeed(), true)
    elseif event == "START_AUTOREPEAT_SPELL" then
        repeating = true
        ReadShotSpeed()
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        repeating = false
    elseif event == "PLAYER_ENTER_COMBAT" then
        meleeing = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        meleeing = false
    elseif event == "PLAYER_REGEN_ENABLED" then
        RangedTimer.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        TurnOffNativeTimer()
    elseif event == "CVAR_UPDATE" then
        if bar:IsShown() or offBar:IsShown() then Anchor() end
    else
        ReadShotSpeed()
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
    events:RegisterEvent("CVAR_UPDATE")
    if SWING then
        events:RegisterEvent("PLAYER_SWING")
        events:RegisterEvent("PLAYER_ENTER_COMBAT")
        events:RegisterEvent("PLAYER_LEAVE_COMBAT")
    end
    ReadShotSpeed()
    TurnOffNativeTimer()
end

function RangedTimer:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    repeating, meleeing = false, false
    for _, timer in ipairs({ bar, offBar }) do
        if timer then
            timer.startTime = nil
            timer:Hide()
        end
    end
    EndPreview()
end

BOLT:RegisterModule("rangedTimer", RangedTimer)
