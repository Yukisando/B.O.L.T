-- B.O.L.T Frame Visibility Module (replaced Immersive Mode on 2026-11-09)
-- Options for the Player Frame, the Target Frame and the Personal Resource Display, set from
-- each frame's own Edit Mode dialog (a "B.O.L.T" block under Blizzard's settings) or from the
-- settings page. Players build their own setup; the old Immersive Mode is "hide both frames and
-- turn on the Personal Resource Display".
--
-- Player and Target frames: "Hide" parks the frame on a BOLT holder frame. Show conditions
-- (in combat, with a target: any, attackable or not attackable) drive the holder with a secure state driver, so the
-- frame comes back in combat too. "On mouse hover" keeps the frame in place but invisible
-- (alpha 0) until the mouse is over it or a condition is met. In Edit Mode every frame shows.
--
-- Personal Resource Display: on/off (CVar nameplateShowSelf), and with Edit Mode's "In Combat"
-- visibility: also show with a target (any, attackable or not attackable), an out-of-combat opacity instead of hiding,
-- and right-click menus (yours; Shift for your target's) on its bars. Also a half-height pet
-- health bar on top of its health bar, and the pets' share of your damage after each fight.

local ADDON_NAME, BOLT = ...
local EditMode = BOLT.EditMode

local FrameVisibility = {
    displayName = "Player & Target Frames",
    alwaysOn = true, -- the defaults change nothing; options take effect as soon as they're set
}

local PRD_CVAR = "nameplateShowSelf"
local FADE_IN, FADE_OUT = 0.15, 0.4 -- seconds, hover mode

-- "With a target" settings hold one of these: which targets count. Every target option uses
-- the same choice (any, attackable only, not attackable only).
local TARGET_KINDS = {
    ANY = "[@target,exists]",
    HOSTILE = "[@target,harm,nodead]",
    FRIENDLY = "[@target,exists,noharm]",
}
local TARGET_CHOICES = {
    { text = "Off", value = "OFF" },
    { text = "Any target", value = "ANY" },
    { text = "Attackable targets", value = "HOSTILE" },
    { text = "Not attackable targets", value = "FRIENDLY" },
}
FrameVisibility.TARGET_CHOICES = TARGET_CHOICES

-- Conditions per frame: saved key and label. `combat` is on/off; `target` holds a TARGET_KINDS key.
local UNITS = {
    player = {
        label = "Player Frame",
        frame = function() return PlayerFrame end,
        conditions = {
            { key = "combat", label = "In combat" },
            { key = "target", label = "With a target", kinds = true },
        },
    },
    target = {
        label = "Target Frame",
        frame = function() return TargetFrame end,
        conditions = {
            { key = "combat", label = "In combat" },
            { key = "target", label = "With a target", kinds = true },
        },
    },
}
local ORDER = { "player", "target" }

local function Cfg(unit, key)
    return BOLT:GetConfig("frameVisibility", unit, key)
end

local function Plain(value)
    if BOLT.IsSecret(value) then return nil end
    return value
end

local function HasAttackableTarget()
    if not UnitExists("target") then return false end
    return Plain(UnitCanAttack("player", "target")) == true and not Plain(UnitIsDeadOrGhost("target"))
end

-- Does the current target fit a TARGET_KINDS choice? (Live check, same rules as the macros.)
local function TargetFits(kind)
    if not TARGET_KINDS[kind] or not UnitExists("target") then return false end
    if kind == "HOSTILE" then return HasAttackableTarget() end
    if kind == "FRIENDLY" then return Plain(UnitCanAttack("player", "target")) ~= true end
    return true
end
FrameVisibility.TargetFits = TargetFits

-- The macro condition of a frame's condition, or nil when it's off.
local function ConditionMacro(unit, condition)
    local value = Cfg(unit, condition.key)
    if condition.kinds then return TARGET_KINDS[value] end
    return value and "[combat]" or nil
end

local function ConditionMet(unit, condition)
    local value = Cfg(unit, condition.key)
    if condition.kinds then return TargetFits(value) end
    return value and (InCombatLockdown() or UnitAffectingCombat("player")) or false
end

---------------------------------------------------------------------------
-- Player and Target frames
---------------------------------------------------------------------------

local holders, homes, hovering = {}, {}, {}

local function Holder(unit)
    local holder = holders[unit]
    if holder then return holder end
    holder = CreateFrame("Frame", "BOLT" .. (unit == "player" and "Player" or "Target") .. "FrameHolder",
        UIParent, "SecureHandlerStateTemplate")
    holder:SetAllPoints(UIParent)
    holders[unit] = holder
    return holder
end

-- True when BOLT has this frame in hand (other modules leave its alpha alone then).
function FrameVisibility:Controls(unit)
    return Cfg(unit, "hide") == true
end

local fader = CreateFrame("Frame")
fader:Hide()

function FrameVisibility:ApplyUnit(unit)
    local def = UNITS[unit]
    local frame = def.frame()
    if not frame then return end
    local holder = holders[unit]
    local hide = Cfg(unit, "hide") == true
    hovering[unit] = nil

    if not hide then
        if holder then
            UnregisterStateDriver(holder, "visibility")
            holder:Show()
        end
        if holder and frame:GetParent() == holder then
            frame:SetParent(homes[unit] or UIParent)
            frame:SetAlpha(1)
        end
        return
    end

    holder = Holder(unit)
    if frame:GetParent() ~= holder then
        homes[unit] = frame:GetParent()
        frame:SetParent(holder)
    end

    if EditMode:IsActive() then
        UnregisterStateDriver(holder, "visibility")
        holder:Show()
        frame:SetAlpha(1)
    elseif Cfg(unit, "hover") then
        UnregisterStateDriver(holder, "visibility")
        holder:Show()
        hovering[unit] = { alpha = frame:GetAlpha() }
    else
        local parts = {}
        for _, condition in ipairs(def.conditions) do
            local macro = ConditionMacro(unit, condition)
            if macro then table.insert(parts, macro .. " show") end
        end
        table.insert(parts, "hide")
        RegisterStateDriver(holder, "visibility", table.concat(parts, "; "))
        frame:SetAlpha(1)
    end
end

-- Hover mode: invisible until hovered or a condition is met. Alpha is allowed in combat.
fader:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for unit, entry in pairs(hovering) do
        any = true
        local frame = UNITS[unit].frame()
        local goal = 0
        if frame:IsMouseOver() then
            goal = 1
        else
            for _, condition in ipairs(UNITS[unit].conditions) do
                if ConditionMet(unit, condition) then
                    goal = 1
                    break
                end
            end
        end
        local alpha = entry.alpha
        if alpha < goal then
            alpha = math.min(goal, alpha + elapsed / FADE_IN)
        elseif alpha > goal then
            alpha = math.max(goal, alpha - elapsed / FADE_OUT)
        end
        entry.alpha = alpha
        if frame:GetAlpha() ~= alpha then frame:SetAlpha(alpha) end
    end
    if not any then self:Hide() end
end)

function FrameVisibility:ApplyFrames()
    if InCombatLockdown() then
        self.pending = true
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.pending = false
    for _, unit in ipairs(ORDER) do
        self:ApplyUnit(unit)
    end
    fader:SetShown(next(hovering) ~= nil)
end

---------------------------------------------------------------------------
-- Personal Resource Display
---------------------------------------------------------------------------

local function Display()
    return PersonalResourceDisplayFrame
end

local function DisplayCfg(key)
    return BOLT:GetConfig("frameVisibility", "display", key)
end

function FrameVisibility:DisplayAllowed()
    if not C_CVar.GetCVarInfo(PRD_CVAR) then return false end
    local rules, rule = C_GameRules, Enum.GameRule and Enum.GameRule.PersonalResourceDisplayDisabled
    return not (rules and rules.IsGameRuleActive and rule and rules.IsGameRuleActive(rule))
end

function FrameVisibility:IsDisplayOn()
    return C_CVar.GetCVarBool(PRD_CVAR) == true
end

function FrameVisibility:SetDisplayOn(on)
    if not self:DisplayAllowed() then
        BOLT:Print("The Personal Resource Display isn't available on this client.")
        return
    end
    C_CVar.SetCVar(PRD_CVAR, on and "1" or "0")
    local config = BOLT.modules.config
    if config and config.pages then config:RefreshAll() end
end

-- Out of combat (and with no attackable target) the display fades to its idle opacity instead of
-- vanishing; hovering it brings it back to full. 0% keeps Blizzard's hiding.
local displayFader = CreateFrame("Frame")
displayFader:Hide()
displayFader.goal = 1
displayFader:SetScript("OnUpdate", function(self, elapsed)
    local display = Display()
    if not display then return self:Hide() end
    -- The unit bars' click buttons live on UIParent (see the bar clickers), so they count separately.
    local hovered = display:IsMouseOver()
    for _, clicker in pairs(FrameVisibility.clickers or {}) do
        hovered = hovered or (clicker:IsShown() and clicker:IsMouseOver())
    end
    local goal = hovered and 1 or self.goal
    local alpha = display:GetAlpha()
    if alpha < goal then
        display:SetAlpha(math.min(goal, alpha + elapsed / FADE_IN))
    elseif alpha > goal then
        display:SetAlpha(math.max(goal, alpha - elapsed / FADE_OUT))
    end
end)

local function UsesCombatSetting(display)
    if not (display.GetVisibleSetting and Enum.PersonalResourceDisplayVisibleSetting) then return false end
    if display.isInEditMode then return false end
    if display:GetVisibleSetting() ~= Enum.PersonalResourceDisplayVisibleSetting.InCombat then return false end
    return not (C_GameRules and C_GameRules.IsPersonalResourceDisplayEnabled
        and not C_GameRules.IsPersonalResourceDisplayEnabled())
end

-- Runs after each of Blizzard's own visibility checks.
local function Settle(display)
    local withTarget = DisplayCfg("showWithTarget")
    local idle = (DisplayCfg("idleAlpha") or 0) / 100
    if not ((TARGET_KINDS[withTarget] or idle > 0) and UsesCombatSetting(display)) then
        displayFader:Hide()
        display:SetAlpha(1)
        return
    end
    local wanted = display:IsShown() or TargetFits(withTarget)
    if wanted or idle > 0 then
        display:Show()
        displayFader.goal = wanted and 1 or idle
        displayFader:Show()
    else
        displayFader:Hide()
        display:SetAlpha(1)
    end
end

local function RefreshDisplay()
    local display = Display()
    if display and display.UpdateShownState then display:UpdateShownState() end
end

function FrameVisibility:HookDisplay()
    local display = Display()
    if self.displayHooked or not (display and display.UpdateShownState) then return end
    self.displayHooked = true
    hooksecurefunc(display, "UpdateShownState", Settle)

    -- Ask for a new check only when the target's fit flips, not on every health tick.
    local lastFit
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterUnitEvent("UNIT_HEALTH", "target")
    events:RegisterUnitEvent("UNIT_FLAGS", "target")
    events:SetScript("OnEvent", function()
        local kind = DisplayCfg("showWithTarget")
        if not TARGET_KINDS[kind] then return end
        local now = TargetFits(kind)
        if now == lastFit then return end
        lastFit = now
        RefreshDisplay()
    end)
end

-- Right-click opens your own menu, Shift + right-click your target's. A thin click catcher sits
-- over the health and power bars; left clicks pass through to the world.
-- It is a secure unit button using the "togglemenu" action, so Blizzard's own code opens the
-- menu. Opening it from addon code (UnitPopup_OpenMenu) taints the whole menu, and entries that
-- cast a spell then fail with ADDON_ACTION_FORBIDDEN.
-- A protected frame makes every frame it is parented or anchored to protected too, and then
-- Blizzard's own Show() of the display gets blocked in combat. So the catcher lives on UIParent
-- with plain coordinates copied from the bars, and follows the display only out of combat (and
-- once more as combat starts, which is still allowed).
local function DisplayShowsInCombat(display)
    if display:IsVisible() then return true end
    local setting = Enum.PersonalResourceDisplayVisibleSetting
    return setting and display.GetVisibleSetting and display:GetVisibleSetting() == setting.InCombat
end

-- Runs sync whenever the display may have moved, resized, shown or hidden: out of combat, and
-- once more as combat starts. Shared by the menu catcher and the pet bar's click button.
local function FollowDisplay(display, sync)
    display:HookScript("OnShow", function() sync() end)
    display:HookScript("OnHide", function() sync() end)
    if display.HealthBarsContainer then
        display.HealthBarsContainer:HookScript("OnSizeChanged", function() sync() end)
    end
    hooksecurefunc(display, "UpdateShownState", function() sync() end)
    if EditMode.lib then
        -- Next frame: the display's isInEditMode flag may not be set yet when this fires.
        EditMode.lib:RegisterCallback("enter", function() C_Timer.After(0, function() sync() end) end)
        EditMode.lib:RegisterCallback("exit", function() sync() end)
    end
    local combat = CreateFrame("Frame")
    combat:RegisterEvent("PLAYER_REGEN_DISABLED")
    combat:RegisterEvent("PLAYER_REGEN_ENABLED")
    combat:SetScript("OnEvent", function(_, event) sync(event == "PLAYER_REGEN_DISABLED") end)
end

function FrameVisibility:SyncMenuCatcher(combatStarting)
    local catcher, display = self.menuCatcher, Display()
    if not (catcher and display) or InCombatLockdown() then return end
    local container = display.HealthBarsContainer or display
    local lower = display.PowerBar or container
    local left, top = Plain(container:GetLeft()), Plain(container:GetTop())
    local right, bottom = Plain(lower:GetRight()), Plain(lower:GetBottom())
    local wanted = DisplayCfg("rightClickMenus")
        and (combatStarting and DisplayShowsInCombat(display) or display:IsVisible())
    if not (wanted and left and top and right and bottom) then
        catcher:Hide()
        return
    end
    local ratio = container:GetEffectiveScale() / UIParent:GetEffectiveScale()
    catcher:ClearAllPoints()
    catcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
    catcher:SetSize(math.max(1, (right - left) * ratio), math.max(1, (top - bottom) * ratio))
    catcher:SetFrameStrata(display:GetFrameStrata())
    catcher:SetFrameLevel(display:GetFrameLevel() + 10)
    catcher:Show()
end

function FrameVisibility:UpdateMenuCatcher()
    local display = Display()
    if not (display and display.HealthBarsContainer) then return end
    if InCombatLockdown() then
        self.menuPending = true
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.menuPending = nil
    if not self.menuCatcher then
        if not DisplayCfg("rightClickMenus") then return end
        local catcher = CreateFrame("Button", "BOLTDisplayMenuCatcher", UIParent, "SecureUnitButtonTemplate")
        catcher:Hide()
        catcher:RegisterForClicks("RightButtonUp")
        catcher:SetMouseMotionEnabled(false)
        if catcher.SetPassThroughButtons then catcher:SetPassThroughButtons("LeftButton") end
        catcher:SetAttribute("unit", "player")
        catcher:SetAttribute("toggleForVehicle", true)
        catcher:SetAttribute("shift-unit2", "target")
        catcher:SetAttribute("*type2", "togglemenu")
        self.menuCatcher = catcher

        -- Follow the display out of combat: shown/hidden, Edit Mode resizes and moves.
        FollowDisplay(display, function(combatStarting) self:SyncMenuCatcher(combatStarting) end)
    end
    self:SyncMenuCatcher()
end

---------------------------------------------------------------------------
-- Unit bars: small health bars on the display for your pet (on top of its health bar), your
-- target and your target's target (one row under its power bar: the target on the left two
-- thirds, its target on the right third). Half the height of the power bar, drawn with the
-- display's own bar art. Children of the display, so they show, hide, fade and scale with it;
-- each only shows while its unit exists.
---------------------------------------------------------------------------

local PET_COLOR = { 0.45, 0.85, 0.3 } -- a softer green than the player's own health
local DEFAULT_PADDING = 4
local DEFAULT_POWER_HEIGHT = 10 -- the display's power bar height when unreadable
local BAR_MIN_HEIGHT = 5
local ROW_GAP = 8 -- between the target and target-of-target bars: their border art spills past the fill
local TOT_SHARE = 1 / 3
local TOT_TICK = 0.2
local WHITE = "Interface\\Buttons\\WHITE8X8"
local REACTION_COLORS = {
    hostile = { 0.85, 0.25, 0.2 },
    neutral = { 0.9, 0.75, 0.2 },
    friendly = { 0.35, 0.8, 0.3 },
}

local BAR_KEYS = { "pet", "target", "targettarget" }
local CLICKER_NAMES = {
    pet = "BOLTPetBarClicker",
    target = "BOLTTargetBarClicker",
    targettarget = "BOLTTargetOfTargetBarClicker",
}

local bars = {}
local petBar -- bars.pet, kept by name for the pet damage and ammo texts that sit beside it
local barEvents, totTicker, barsAnchoredTo
local UpdateHungerPulse, ShowFeedTooltip -- pet feeding, further down

local function Readable(value, fallback)
    if value and not BOLT.IsSecret(value) and value > 0 then return value end
    return fallback
end

local function BarOn(key)
    if key == "pet" then return DisplayCfg("petHealth") == true end
    if key == "target" then return DisplayCfg("targetBar") == true end
    return DisplayCfg("targetBar") == true and DisplayCfg("targetOfTargetBar") == true
end

-- The target of target gets its third of the row only when there is one and it isn't you;
-- otherwise the target bar takes the whole row.
local function ShowsTargetOfTarget()
    return BarOn("targettarget") and UnitExists("targettarget")
        and Plain(UnitIsUnit("targettarget", "player")) ~= true
end

-- Where a bar goes: the frame it hangs from (above the health bars or under the power bar), its
-- span across that frame's width as fractions, the gap to leave on each side, and its height.
-- fullRow lays the target out as if it had the row to itself (its click button always does).
local function BarLayout(key, display, fullRow)
    local container = display.HealthBarsContainer or display
    local power = display.PowerBar
    local powerHeight = power and Readable(power:GetHeight(), DEFAULT_POWER_HEIGHT) or DEFAULT_POWER_HEIGHT
    local layout = {
        padding = display.GetBarPadding and Readable(display:GetBarPadding(), DEFAULT_PADDING) or DEFAULT_PADDING,
        height = math.max(BAR_MIN_HEIGHT, math.floor(powerHeight / 2 + 0.5)),
        from = 0, to = 1, gapLeft = 0, gapRight = 0,
    }
    if key == "pet" then
        layout.ref, layout.above = container, true
    else
        layout.ref, layout.above = power or container, false
        if key == "targettarget" then
            layout.from, layout.gapLeft = 1 - TOT_SHARE, ROW_GAP / 2
        elseif not fullRow and ShowsTargetOfTarget() then
            layout.to, layout.gapRight = 1 - TOT_SHARE, ROW_GAP / 2
        end
    end
    return layout
end

local function AnchorBar(key, display)
    local bar, layout = bars[key], BarLayout(key, display)
    local width = Readable(layout.ref:GetWidth())
    if not width then return false end
    if bar:GetParent() ~= display then bar:SetParent(display) end
    local y = layout.above and layout.padding or -layout.padding
    local edge = layout.above and "TOP" or "BOTTOM"
    local side = layout.above and "BOTTOM" or "TOP"
    bar:ClearAllPoints()
    bar:SetPoint(side .. "LEFT", layout.ref, edge .. "LEFT", width * layout.from + layout.gapLeft, y)
    bar:SetPoint(side .. "RIGHT", layout.ref, edge .. "RIGHT", -width * (1 - layout.to) - layout.gapRight, y)
    bar:SetHeight(layout.height)
    return true
end

local function AnchorBars()
    local display = Display()
    if not display then return false end
    for _, key in ipairs(BAR_KEYS) do
        if bars[key] then bars[key].anchored = AnchorBar(key, display) end
    end
    local container = display.HealthBarsContainer or display
    if barsAnchoredTo ~= container then
        barsAnchoredTo = container
        -- Edit Mode changes to the display's size reach the container; follow them.
        container:HookScript("OnSizeChanged", function()
            if barsAnchoredTo == container then AnchorBars() end
        end)
    end
    return true
end

---------------------------------------------------------------------------
-- Pet happiness: the pet health bar's colour follows the pet's mood: the usual green when happy,
-- amber when content, red when it's unhappy and needs feeding.
-- Only hunter pets have a mood, and only on clients that have pet happiness; elsewhere the bar
-- keeps its green. WoW: Forever reads it with C_PetInfo.GetPetHappiness (no global
-- GetPetHappiness there, which kept the mood hidden until 2026-11-16); older clients have the global.
-- Target bars take the reaction colour, or the class colour for players.
---------------------------------------------------------------------------

local MOODS = {
    [1] = { 0.9, 0.25, 0.2 },   -- unhappy: feed it
    [2] = { 0.95, 0.7, 0.2 },   -- content: feed it soon
    [3] = PET_COLOR,            -- happy
}

local PetHappiness = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness

local function BarColor(key)
    local color
    if key == "pet" then
        local happiness = DisplayCfg("petHappiness") and PetHappiness and HasPetUI
            and select(2, HasPetUI()) and PetHappiness()
        color = happiness and MOODS[happiness] or PET_COLOR
    else
        if UnitIsPlayer(key) then
            local class = Plain(select(2, UnitClass(key)))
            local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if classColor then return classColor.r, classColor.g, classColor.b end
        end
        local reaction = Plain(UnitReaction(key, "player"))
        color = not reaction and REACTION_COLORS.neutral
            or reaction <= 3 and REACTION_COLORS.hostile
            or reaction == 4 and REACTION_COLORS.neutral
            or REACTION_COLORS.friendly
    end
    return color[1], color[2], color[3]
end

---------------------------------------------------------------------------
-- Hover text, like the display's own health bar: percentage on the left, health on the right,
-- only while the pointer is over the bar. In the same font as the display's text.
-- In combat health can be secret: UnitHealthPercent (with a 0-100 curve) and AbbreviateLargeNumbers
-- take secret values and so does SetText, but plain Lua maths on them errors, hence the pcall.
---------------------------------------------------------------------------

local function DisplayTextFont()
    local display = Display()
    local container = display and display.HealthBarsContainer
    local bar = container and (container.healthBar or container.HealthBar)
    local text = bar and (bar.LeftText or bar.RightText or bar.TextString)
    return text and text.GetFontObject and text:GetFontObject() or TextStatusBarText
end

local function HealthTexts(unit)
    local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
    local percent
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        percent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    elseif not (BOLT.IsSecret(health) or BOLT.IsSecret(maxHealth)) and maxHealth > 0 then
        percent = health / maxHealth * 100
    end
    local left = percent and string.format("%.0f%%", percent) or ""
    local right = AbbreviateLargeNumbers and AbbreviateLargeNumbers(health) or tostring(health)
    return left, right
end

local function UpdateBarText(bar)
    local ok, left, right = false, nil, nil
    if bar.hovered and bar:IsShown() then ok, left, right = pcall(HealthTexts, bar.unit) end
    if not ok then
        bar.leftText:Hide()
        bar.rightText:Hide()
        return
    end
    local font = DisplayTextFont()
    for _, text in ipairs({ bar.leftText, bar.rightText }) do
        if font then text:SetFontObject(font) end
    end
    bar.leftText:SetText(left)
    bar.rightText:SetText(right)
    bar.leftText:Show()
    bar.rightText:Show()
end

local function SetBarHovered(key, hovered)
    local bar = bars[key]
    if not bar then return end
    bar.hovered = hovered
    UpdateBarText(bar)
end

-- UnitHealth/UnitHealthMax can be secret values in combat on Midnight; status bars accept them
-- as they are, so they go straight in without being compared.
local function UpdateBar(key)
    local bar = bars[key]
    if not bar then return end
    local shown = BarOn(key) and UnitExists(key) and bar.anchored
    if key == "targettarget" then shown = shown and ShowsTargetOfTarget() end
    if not shown then
        bar:Hide()
    else
        bar:SetMinMaxValues(0, UnitHealthMax(key))
        bar:SetValue(UnitIsDeadOrGhost(key) and 0 or UnitHealth(key))
        bar:SetStatusBarColor(BarColor(key))
        bar:Show()
    end
    if key == "pet" then UpdateHungerPulse(bar) end
    UpdateBarText(bar)
end

-- "targettarget" fires no unit events of its own (Blizzard's frame polls it too), so a light
-- ticker refreshes it while you have a target.
local splitShown

local function UpdateTargetBars()
    local split = ShowsTargetOfTarget() and true or false
    if split ~= splitShown then
        splitShown = split
        local display = Display()
        if display and bars.target then bars.target.anchored = AnchorBar("target", display) end
        -- Out of combat the target-of-target click button can be pointed at the target straight
        -- away; in combat its secure click wrapper does that (see the bar clickers).
        local clicker = FrameVisibility.clickers and FrameVisibility.clickers.targettarget
        if clicker and not InCombatLockdown() then
            clicker:SetAttribute("unit", split and "targettarget" or "target")
        end
    end
    UpdateBar("target")
    UpdateBar("targettarget")
    if totTicker then totTicker:SetShown(BarOn("targettarget") and UnitExists("target") or false) end
end

local function UpdateBars()
    UpdateBar("pet")
    UpdateTargetBars()
end

local function BuildBar(key)
    local bar = CreateFrame("StatusBar", nil, UIParent)
    bar.unit = key
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:Hide()

    -- The display's own bar art (PersonalResourceStatusBar template): the background atlas
    -- carries the gold border, drawn a little past the fill on every side.
    local fill = BOLT.NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar")
    local back = BOLT.NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar-BG")
    bar:SetStatusBarTexture(fill or WHITE)
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

    -- On an overlay frame so the text sits above the border art.
    local textLayer = CreateFrame("Frame", nil, bar)
    textLayer:SetAllPoints()
    textLayer:SetFrameLevel(bar:GetFrameLevel() + 2)
    bar.leftText = textLayer:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.leftText:SetPoint("LEFT", bar, "LEFT", 2, 0)
    bar.leftText:Hide()
    bar.rightText = textLayer:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    bar.rightText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    bar.rightText:Hide()

    -- Hungry reminder: a soft glow breathing over the fill (see Pet feeding).
    local pulse = textLayer:CreateTexture(nil, "ARTWORK")
    pulse:SetTexture(WHITE)
    pulse:SetBlendMode("ADD")
    pulse:SetAllPoints(bar)
    pulse:Hide()
    local breathe = pulse:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local fade = breathe:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(0.4)
    fade:SetDuration(0.9)
    fade:SetSmoothing("IN_OUT")
    pulse.anim = breathe
    bar.pulse = pulse
    return bar
end

local function OnBarEvent(_, event, unit)
    if unit == "pet" or event == "UNIT_PET" or event == "UNIT_HAPPINESS" then
        UpdateBar("pet")
    elseif unit == "target" or event == "PLAYER_TARGET_CHANGED" then
        UpdateTargetBars()
    else
        UpdateBars()
    end
end

function FrameVisibility:UpdateUnitBars()
    local any = false
    for _, key in ipairs(BAR_KEYS) do
        if BarOn(key) then
            any = true
            if not bars[key] then bars[key] = BuildBar(key) end
        end
    end
    petBar = bars.pet
    if any and not barEvents then
        barEvents = CreateFrame("Frame")
        barEvents:SetScript("OnEvent", OnBarEvent)
        totTicker = CreateFrame("Frame")
        totTicker:Hide()
        local since = 0
        totTicker:SetScript("OnUpdate", function(_, elapsed)
            since = since + elapsed
            if since < TOT_TICK then return end
            since = 0
            UpdateTargetBars()
        end)
    end
    if barEvents then
        barEvents:UnregisterAllEvents()
        if any then barEvents:RegisterEvent("PLAYER_ENTERING_WORLD") end
        if BarOn("pet") then
            barEvents:RegisterUnitEvent("UNIT_HEALTH", "pet", "target")
            barEvents:RegisterUnitEvent("UNIT_MAXHEALTH", "pet", "target")
            barEvents:RegisterUnitEvent("UNIT_PET", "player")
            if PetHappiness then
                -- UNIT_HAPPINESS only exists on clients with pet happiness (Blizzard's own indicator
                -- listens to it unfiltered); happiness is also a pet power on some clients, so power
                -- updates cover those.
                pcall(barEvents.RegisterEvent, barEvents, "UNIT_HAPPINESS")
                barEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
            end
        end
        if BarOn("target") then
            barEvents:RegisterUnitEvent("UNIT_HEALTH", "pet", "target")
            barEvents:RegisterUnitEvent("UNIT_MAXHEALTH", "pet", "target")
            barEvents:RegisterEvent("PLAYER_TARGET_CHANGED")
            barEvents:RegisterUnitEvent("UNIT_FACTION", "target")
            barEvents:RegisterUnitEvent("UNIT_TARGET", "target")
        end
    end
    AnchorBars()
    UpdateBars()
    self:UpdateBarClickers()
end

---------------------------------------------------------------------------
-- Clicking a unit bar works like a unit frame: left-click selects the unit, right-click opens its
-- menu (the pet's Dismiss, Rename...). Hovering shows its text and fades the display in.
-- Same reasons as the menu catcher above: secure unit buttons on UIParent with coordinates
-- copied from where the bars sit, moved only out of combat. RegisterUnitWatch shows and hides
-- each with its unit, which keeps working in combat (the pet dies, you change target).
---------------------------------------------------------------------------

function FrameVisibility:SyncBarClickers(combatStarting)
    local display = Display()
    if not (self.clickers and display) or InCombatLockdown() then return end
    local shows = not display.isInEditMode
        and (combatStarting and DisplayShowsInCombat(display) or display:IsVisible())
    local ratio = (display.HealthBarsContainer or display):GetEffectiveScale() / UIParent:GetEffectiveScale()
    for key, clicker in pairs(self.clickers) do
        local layout = BarLayout(key, display, true)
        local left, right = Plain(layout.ref:GetLeft()), Plain(layout.ref:GetRight())
        local edge = Plain(layout.above and layout.ref:GetTop() or layout.ref:GetBottom())
        if shows and BarOn(key) and left and right and edge then
            local width = right - left
            local x1 = left + width * layout.from + layout.gapLeft
            local x2 = right - width * (1 - layout.to) - layout.gapRight
            local bottom = layout.above and edge + layout.padding or edge - layout.padding - layout.height
            clicker:ClearAllPoints()
            -- One extra pixel around the bar so it isn't fiddly to hit.
            clicker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x1 * ratio, (bottom - 1) * ratio)
            clicker:SetSize(math.max(1, (x2 - x1) * ratio), (layout.height + 2) * ratio)
            clicker:SetFrameStrata(display:GetFrameStrata())
            -- The target of target's button sits over the right third of the target's.
            clicker:SetFrameLevel(display:GetFrameLevel() + (key == "targettarget" and 11 or 10))
            RegisterUnitWatch(clicker)
        else
            UnregisterUnitWatch(clicker)
            clicker:Hide()
        end
    end
end

-- When the target bar has the whole row, the target of target's button (which can't be resized
-- in combat) stands in for the target: hover shows the target's numbers, and before each click a
-- secure snippet points it at the target. UnitIsUnit is looked up rather than assumed, as the
-- secure environment only offers some unit functions; without it the click falls back to the
-- unit set out of combat.
local TOT_CLICK_SNIPPET = [[
    local me = UnitIsUnit and UnitIsUnit("targettarget", "player")
    self:SetAttribute("unit", me and "target" or "targettarget")
]]
local clickWrapper

local function HoverKey(key)
    if key == "targettarget" and not ShowsTargetOfTarget() then return "target" end
    return key
end

local function BuildClicker(key)
    local clicker = CreateFrame("Button", CLICKER_NAMES[key], UIParent, "SecureUnitButtonTemplate")
    clicker:Hide()
    clicker:RegisterForClicks("AnyUp")
    clicker:SetAttribute("unit", HoverKey(key))
    clicker:SetAttribute("*type1", "target")
    clicker:SetAttribute("*type2", "togglemenu")
    local hoveredKey
    clicker:SetScript("OnEnter", function()
        hoveredKey = HoverKey(key)
        SetBarHovered(hoveredKey, true)
        if key == "pet" then ShowFeedTooltip(clicker) end
    end)
    local function leave()
        if hoveredKey then SetBarHovered(hoveredKey, false) end
        hoveredKey = nil
        if key == "pet" and GameTooltip:IsOwned(clicker) then GameTooltip:Hide() end
    end
    clicker:SetScript("OnLeave", leave)
    clicker:SetScript("OnHide", leave)
    if key == "targettarget" and SecureHandlerWrapScript then
        clickWrapper = clickWrapper or CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
        SecureHandlerWrapScript(clicker, "OnClick", clickWrapper, TOT_CLICK_SNIPPET)
    end
    return clicker
end

function FrameVisibility:UpdateBarClickers()
    local display = Display()
    if not display then return end
    if InCombatLockdown() then
        self.clickersPending = true
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.clickersPending = nil
    for _, key in ipairs(BAR_KEYS) do
        if BarOn(key) then
            if not self.clickers then
                self.clickers = {}
                FollowDisplay(display, function(combatStarting) self:SyncBarClickers(combatStarting) end)
            end
            self.clickers[key] = self.clickers[key] or BuildClicker(key)
        end
    end
    self:SyncBarClickers()
    self:UpdatePetFeeding()
end

---------------------------------------------------------------------------
-- Pet feeding (hunter pets with a mood). Out of combat, while the pet is content or unhappy,
-- left-clicking the pet bar feeds it; Shift + left-click feeds it whatever its mood. The bar
-- breathes softly while the pet is hungry, out of combat, and not already eating.
-- The food: the cheapest (vendor price) item in your bags that the pet eats, asked of the game
-- with C_PetInfo.CanPetEatItem (WoW: Forever), skipping food more than 30 levels below the pet,
-- which it refuses. The click is a "/cast Feed Pet" + "/use item:<id>" macro on the pet bar's
-- secure button, so no bag opens. Its attributes can only change out of combat: a secure state
-- driver puts left-click back to "target the pet" when combat starts, and the macro comes back
-- once it ends. Feed Pet can't be cast in combat anyway.
---------------------------------------------------------------------------

local FEED_PET = 6991         -- Feed Pet
local FEED_PET_EFFECT = 1539  -- the "eating" aura on the pet
local FOOD_LEVEL_RANGE = 30
local CanPetEatItem = C_PetInfo and C_PetInfo.CanPetEatItem
local ItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local feedEvents, feedDriver
local feedFood -- { itemID, name, count } or nil

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID))
end

local function FeedingOn()
    return DisplayCfg("petHealth") and DisplayCfg("petFeed") and CanPetEatItem and PetHappiness
        and IsPlayerSpell and IsPlayerSpell(FEED_PET) and true or false
end

local function PetMood()
    if not (HasPetUI and select(2, HasPetUI()) and UnitExists("pet")) then return nil end
    return Plain(PetHappiness())
end

local function PetIsEating()
    local name = SpellName(FEED_PET_EFFECT)
    if not (name and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return false end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, "pet", name, "HELPFUL")
    return ok and aura ~= nil and not BOLT.IsSecret(aura)
end

local function FindFood()
    local petLevel = Plain(UnitLevel("pet")) or 0
    local best, bestPrice, counts = nil, nil, {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local itemID = info and info.itemID
            if itemID and counts[itemID] == nil then
                counts[itemID] = false
                local ok, eats = pcall(CanPetEatItem, itemID)
                local name, _, _, itemLevel, _, _, _, _, _, _, price = ItemInfo(itemID)
                if ok and eats and name and (itemLevel or 0) >= petLevel - FOOD_LEVEL_RANGE then
                    counts[itemID] = 0
                    price = price or 0
                    if not bestPrice or price < bestPrice then best, bestPrice = itemID, price end
                end
            end
            if itemID and counts[itemID] then counts[itemID] = counts[itemID] + (info.stackCount or 1) end
        end
    end
    if not best then return nil end
    return { itemID = best, name = (ItemInfo(best)), count = counts[best] }
end

function UpdateHungerPulse(bar, combatStarting)
    local pulse = bar and bar.pulse
    if not pulse then return end
    local mood = not combatStarting and FeedingOn() and bar:IsShown() and not InCombatLockdown() and PetMood()
    if mood and mood < 3 and not PetIsEating() then
        pulse:SetVertexColor(unpack(MOODS[mood]))
        pulse:Show()
        if not pulse.anim:IsPlaying() then pulse.anim:Play() end
    else
        pulse.anim:Stop()
        pulse:Hide()
    end
end

function ShowFeedTooltip(owner)
    local mood = FeedingOn() and not InCombatLockdown() and PetMood()
    if not mood then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if feedFood then
        GameTooltip:SetText((mood < 3 and "Click" or "Shift-click") .. " to feed your pet", 1, 0.82, 0)
        GameTooltip:AddLine(string.format("%s (%d)", feedFood.name, feedFood.count), 1, 1, 1)
    else
        GameTooltip:SetText("No food your pet eats in your bags", 1, 0.82, 0)
    end
    GameTooltip:Show()
end

-- Runs in the secure environment when combat starts and ends.
local FEED_COMBAT_SNIPPET = [[
    local clicker = self:GetFrameRef("clicker")
    if not clicker then return end
    if newstate == "in" then
        clicker:SetAttribute("type1", nil)
        clicker:SetAttribute("shift-type1", nil)
    else
        clicker:SetAttribute("type1", self:GetAttribute("feed-type1"))
        clicker:SetAttribute("shift-type1", self:GetAttribute("feed-shift-type1"))
    end
]]

local function ApplyFeedAttributes(clicker)
    local mood = FeedingOn() and PetMood()
    feedFood = mood and FindFood() or nil
    local spell = SpellName(FEED_PET)
    local macro = feedFood and spell and string.format("/cast %s\n/use item:%d", spell, feedFood.itemID)
    -- "type1" (no modifier) wins over the bar's "*type1" target; nil falls back to it.
    local plainType = macro and mood < 3 and not PetIsEating() and "macro" or nil
    local shiftType = macro and "macro" or nil
    clicker:SetAttribute("*macrotext1", macro)
    clicker:SetAttribute("type1", plainType)
    clicker:SetAttribute("shift-type1", shiftType)
    if feedDriver then
        feedDriver:SetAttribute("feed-type1", plainType)
        feedDriver:SetAttribute("feed-shift-type1", shiftType)
    end
end

-- PLAYER_REGEN_DISABLED fires just before lockdown starts, while the state driver is switching the
-- click back to targeting: only the pulse changes then.
function FrameVisibility:RefreshPetFeeding(event)
    local combatStarting = event == "PLAYER_REGEN_DISABLED"
    UpdateHungerPulse(bars.pet, combatStarting)
    local clicker = self.clickers and self.clickers.pet
    if clicker and not combatStarting and not InCombatLockdown() then ApplyFeedAttributes(clicker) end
end

function FrameVisibility:UpdatePetFeeding()
    local clicker = self.clickers and self.clickers.pet
    if not (clicker and CanPetEatItem and PetHappiness) or InCombatLockdown() then return end
    if not feedEvents then
        feedEvents = CreateFrame("Frame")
        feedEvents:SetScript("OnEvent", function(_, event) self:RefreshPetFeeding(event) end)
    end
    feedEvents:UnregisterAllEvents()
    if FeedingOn() then
        if not feedDriver and RegisterStateDriver then
            feedDriver = CreateFrame("Frame", nil, UIParent, "SecureHandlerStateTemplate")
            SecureHandlerSetFrameRef(feedDriver, "clicker", clicker)
            feedDriver:SetAttribute("_onstate-combat", FEED_COMBAT_SNIPPET)
            RegisterStateDriver(feedDriver, "combat", "[combat] in; out")
        end
        for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED" }) do
            feedEvents:RegisterEvent(event)
        end
        pcall(feedEvents.RegisterEvent, feedEvents, "UNIT_HAPPINESS")
        feedEvents:RegisterUnitEvent("UNIT_PET", "player")
        feedEvents:RegisterUnitEvent("UNIT_AURA", "pet")
        feedEvents:RegisterUnitEvent("UNIT_LEVEL", "pet")
        feedEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
    end
    self:RefreshPetFeeding()
end

---------------------------------------------------------------------------
-- Totem nodes: the hunter's hawk (and any other totem-slot summon) as small round nodes centred
-- above the pet bar, or above the health bar without one: the spell's icon in the game's own
-- totem ring, with a radial sweep counting down its time. Hover one for its tooltip.
-- WoW: Forever keeps totem slots secret from addons (GetTotemInfo is SecretWhenTotemSlotSecret, and
-- it is, even out of combat), so "is there a totem" can't be asked in Lua. Instead:
--   * PLAYER_TOTEM_UPDATE says which slot changed (that slot number is plain), so its node joins
--     the row; it leaves when its sweep ends (OnCooldownDone) or the slot reads as empty.
--   * The sweep runs from GetTotemDuration's duration object, which cooldowns take secret.
--   * The node's look is gated by SetAlphaFromBoolean on the secret "have totem" and "zero
--     duration" values, so the game itself hides it when the slot is empty, even if the row
--     still holds its place for a moment.
-- Where totem data is plain (other clients), it is read directly.
---------------------------------------------------------------------------

local NODE_SIZE = 26     -- the ring; the native totem button's ring is 30
local NODE_ICON = 19     -- the icon inside it (native 22)
local NODE_SPACING = 24  -- centre to centre; the rings overlap a touch, like the native frame
local NODE_GAP = 5       -- above the bar under them

local totemNodes, totemHolder, totemEvents
local LayoutTotems

local function TotemSlots()
    return (GetNumTotemSlots and GetNumTotemSlots()) or MAX_TOTEMS or 4
end

local function BuildTotemNode(slot)
    local node = CreateFrame("Frame", nil, totemHolder)
    node:SetSize(NODE_SIZE, NODE_SIZE)
    node.slot = slot
    node:Hide()
    -- Two nested gates: drawn only when there is a totem and its time isn't zero.
    node.haveGate = CreateFrame("Frame", nil, node)
    node.haveGate:SetAllPoints()
    node.timeGate = CreateFrame("Frame", nil, node.haveGate)
    node.timeGate:SetAllPoints()
    local look = node.timeGate

    node.icon = look:CreateTexture(nil, "BACKGROUND")
    node.icon:SetSize(NODE_ICON, NODE_ICON)
    node.icon:SetPoint("CENTER")
    local mask = look:CreateMaskTexture()
    mask:SetAtlas("CircleMask")
    mask:SetAllPoints(node.icon)
    node.icon:AddMaskTexture(mask)

    -- The radial countdown, drawn through the same circle so it stays round (as TotemButtonMixin).
    node.cooldown = CreateFrame("Cooldown", nil, look, "CooldownFrameTemplate")
    node.cooldown:SetAllPoints(node.icon)
    node.cooldown:SetReverse(true)
    node.cooldown:SetHideCountdownNumbers(true)
    node.cooldown:SetDrawEdge(false)
    local swipe = C_Texture.GetAtlasInfo("CircleMask")
    if swipe then
        node.cooldown:SetSwipeTexture(swipe.file or swipe.filename)
        node.cooldown:SetTexCoordRange({ x = swipe.leftTexCoord, y = swipe.topTexCoord },
            { x = swipe.rightTexCoord, y = swipe.bottomTexCoord })
    end
    node.cooldown:SetSwipeColor(0, 0, 0, 0.65)
    node.cooldown:SetScript("OnCooldownDone", function()
        node.active = false
        LayoutTotems()
    end)

    local ringLayer = CreateFrame("Frame", nil, look)
    ringLayer:SetAllPoints()
    ringLayer:SetFrameLevel(node.cooldown:GetFrameLevel() + 1)
    local ring = ringLayer:CreateTexture(nil, "OVERLAY")
    ring:SetAtlas(BOLT.NativeArt.ResolveAtlas("UI-HUD-UnitFrame-TotemFrame") or "UI-HUD-UnitFrame-TotemFrame")
    ring:SetSize(NODE_SIZE, NODE_SIZE)
    ring:SetPoint("CENTER", 1, -1) -- the native ring sits a hair off centre in its button

    node:EnableMouse(true)
    if node.SetMouseClickEnabled then node:SetMouseClickEnabled(false) end
    node:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetTotem(self.slot)
    end)
    node:SetScript("OnLeave", GameTooltip_Hide)
    return node
end

-- Centred on the row: one node in the middle, two either side of it, and so on.
LayoutTotems = function()
    local display = Display()
    if not (display and totemHolder) then return end
    if totemHolder:GetParent() ~= display then totemHolder:SetParent(display) end
    local container = display.HealthBarsContainer or display
    local base = petBar and petBar:IsShown() and petBar or container
    totemHolder:ClearAllPoints()
    totemHolder:SetPoint("BOTTOM", base, "TOP", 0, NODE_GAP)
    totemHolder:SetSize(NODE_SIZE, NODE_SIZE)
    local on = DisplayCfg("totems") == true
    local shown = {}
    for slot = 1, #totemNodes do
        local node = totemNodes[slot]
        node:SetShown(on and node.active == true)
        if node:IsShown() then table.insert(shown, node) end
    end
    for index, node in ipairs(shown) do
        node:ClearAllPoints()
        node:SetPoint("CENTER", totemHolder, "CENTER", (index - (#shown + 1) / 2) * NODE_SPACING, 0)
    end
end

-- Fills a node from its slot. Returns whether the slot holds a totem when that can be read,
-- or nil when the game keeps it secret.
local function ReadSlot(node)
    local have, _, startTime, duration, icon = GetTotemInfo(node.slot)
    node.icon:SetTexture(icon)
    local durationObject = GetTotemDuration and GetTotemDuration(node.slot)
    if durationObject and node.cooldown.SetCooldownFromDurationObject then
        node.cooldown:SetCooldownFromDurationObject(durationObject)
    elseif not (BOLT.IsSecret(startTime) or BOLT.IsSecret(duration)) then
        node.cooldown:SetCooldown(startTime, duration)
    end

    if not (BOLT.IsSecret(have) or BOLT.IsSecret(duration)) then
        node.haveGate:SetAlpha(1)
        node.timeGate:SetAlpha(1)
        -- A totem with no time on it is gone (Blizzard's buttons hide on duration 0 too).
        return have and (duration or 0) > 0 or false
    end
    node.haveGate:SetAlphaFromBoolean(have, 1, 0)
    local zeroKnown, isZero = false, nil
    if durationObject then zeroKnown, isZero = pcall(durationObject.IsZero, durationObject) end
    if zeroKnown then
        node.timeGate:SetAlphaFromBoolean(isZero, 0, 1)
        -- A plain zero (no secret in the duration) means the slot is empty.
        if not durationObject:HasSecretValues() and isZero == true then return false end
    else
        node.timeGate:SetAlpha(1)
    end
    return nil
end

local function OnTotemEvent(_, event, slot)
    if not totemNodes then return end
    if event == "PLAYER_TOTEM_UPDATE" then
        local node = not BOLT.IsSecret(slot) and totemNodes[slot]
        if node then
            local known = ReadSlot(node)
            -- A change on a secret slot is taken as a summon; its sweep ending takes it off again.
            if known == nil then node.active = true else node.active = known end
        end
    else
        for _, node in ipairs(totemNodes) do
            local known = ReadSlot(node)
            if known ~= nil then node.active = known end
        end
    end
    LayoutTotems()
end

function FrameVisibility:UpdateTotems()
    local on = DisplayCfg("totems") == true
    if not totemNodes then
        if not on then return end
        totemHolder = CreateFrame("Frame", nil, UIParent)
        totemHolder:SetFrameLevel(10)
        totemNodes = {}
        for slot = 1, TotemSlots() do totemNodes[slot] = BuildTotemNode(slot) end
        totemEvents = CreateFrame("Frame")
        totemEvents:SetScript("OnEvent", OnTotemEvent)
    end
    -- The row moves up or down as the pet bar comes and goes.
    if petBar and not petBar.totemHooked then
        petBar.totemHooked = true
        petBar:HookScript("OnShow", LayoutTotems)
        petBar:HookScript("OnHide", LayoutTotems)
    end
    if on then
        totemEvents:RegisterEvent("PLAYER_TOTEM_UPDATE")
        totemEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
    else
        totemEvents:UnregisterAllEvents()
    end
    OnTotemEvent(nil, "REFRESH")
end

---------------------------------------------------------------------------
-- Pet damage share: when combat ends, "38%" fades in to the right of the pet health bar for a few
-- seconds: how much of your damage (yours + your pets') the pets dealt in that fight.
-- The combat log is closed to addons on both clients, so this reads Blizzard's damage meter
-- (C_DamageMeter). It folds pet damage into the owner's line, but each pet spell carries the
-- pet's name in creatureName (Blizzard's meter shows them as "Claw (Wolf)"). In combat the
-- numbers are secret, so they're only read once combat is over.
---------------------------------------------------------------------------

local PET_DAMAGE_HOLD = 4      -- seconds fully shown
local PET_DAMAGE_READ_DELAY = 0.3 -- lets the meter close the fight's session first

local petDamageText, petDamageAnim, petDamageEvents

local function PetDamageAvailable()
    return C_DamageMeter and C_DamageMeter.GetCombatSessionSourceFromType
        and Enum.DamageMeterSessionType and Enum.DamageMeterType and true or false
end

local function ReadPetShare()
    local ok, source = pcall(C_DamageMeter.GetCombatSessionSourceFromType,
        Enum.DamageMeterSessionType.Current, Enum.DamageMeterType.DamageDone, UnitGUID("player"))
    if not (ok and source and source.combatSpells) then return end
    local total = source.totalAmount
    if BOLT.IsSecret(total) or not total or total <= 0 then return end
    local pet = 0
    for _, spell in ipairs(source.combatSpells) do
        local creature, amount = spell.creatureName, spell.totalAmount
        if BOLT.IsSecret(creature) or BOLT.IsSecret(amount) then return end
        if creature and creature ~= "" and amount then pet = pet + amount end
    end
    if pet <= 0 then return end
    return math.min(100, math.floor(pet / total * 100 + 0.5))
end

local function BuildPetDamageText()
    -- On UIParent, not the display: the display usually hides the moment combat ends.
    petDamageText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    petDamageText:SetTextColor(PET_COLOR[1], PET_COLOR[2], PET_COLOR[3])
    local font, size = petDamageText:GetFont()
    if font then petDamageText:SetFont(font, size, "OUTLINE") end
    petDamageText:Hide()
    petDamageAnim = petDamageText:CreateAnimationGroup()
    local fadeIn = petDamageAnim:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.2)
    fadeIn:SetOrder(1)
    local fadeOut = petDamageAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.6)
    fadeOut:SetStartDelay(PET_DAMAGE_HOLD)
    fadeOut:SetOrder(2)
    petDamageAnim:SetScript("OnFinished", function() petDamageText:Hide() end)
end

local function AnchorPetDamageText()
    local display = Display()
    if not display then return false end
    petDamageText:ClearAllPoints()
    -- Next to the pet bar when it has been placed (it keeps its spot while hidden), else where
    -- it would sit: just above the display's health bars. +10 clears the bar art's border.
    if petBar and petBar.anchored then
        petDamageText:SetPoint("LEFT", petBar, "RIGHT", 10, 0)
    else
        petDamageText:SetPoint("BOTTOMLEFT", display.HealthBarsContainer or display, "TOPRIGHT", 10, 2)
    end
    petDamageText:SetScale(display:GetEffectiveScale() / UIParent:GetEffectiveScale())
    return true
end

local function ShowPetShare()
    if not (DisplayCfg("petDamage") and FrameVisibility:IsDisplayOn()) then return end
    local share = ReadPetShare()
    if not share then return end
    if not petDamageText then BuildPetDamageText() end
    if not AnchorPetDamageText() then return end
    petDamageText:SetFormattedText("%d%%", share)
    petDamageAnim:Stop()
    petDamageText:SetAlpha(1)
    petDamageText:Show()
    petDamageAnim:Play()
end

function FrameVisibility:UpdatePetDamage()
    local on = DisplayCfg("petDamage") == true and PetDamageAvailable()
    if not petDamageEvents then
        if not on then return end
        petDamageEvents = CreateFrame("Frame")
        petDamageEvents:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" then
                C_Timer.After(PET_DAMAGE_READ_DELAY, ShowPetShare)
            elseif petDamageText then -- a new fight started: drop the last one's number
                petDamageAnim:Stop()
                petDamageText:Hide()
            end
        end)
    end
    if on then
        petDamageEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        petDamageEvents:RegisterEvent("PLAYER_REGEN_DISABLED")
    else
        petDamageEvents:UnregisterAllEvents()
        if petDamageText then petDamageAnim:Stop() petDamageText:Hide() end
    end
end

---------------------------------------------------------------------------
-- Ammo count: each time a shot uses up ammo, your arrows or bullets left show in white to the
-- left of the pet health bar (opposite the pet damage share), then fade after a moment.
-- The count is read on inventory and bag updates; it only shows when it went down.
---------------------------------------------------------------------------

local AMMO_SLOT = INVSLOT_AMMO or 0
local AMMO_HOLD = 1.5 -- seconds fully shown after the last shot

local ammoText, ammoAnim, ammoEvents, lastAmmo

local function AmmoCount()
    if not GetInventoryItemTexture("player", AMMO_SLOT) then return nil end
    local count = GetInventoryItemCount("player", AMMO_SLOT)
    if BOLT.IsSecret(count) then return nil end
    return count
end

local function BuildAmmoText()
    ammoText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ammoText:SetTextColor(1, 1, 1)
    local font, size = ammoText:GetFont()
    if font then ammoText:SetFont(font, size, "OUTLINE") end
    ammoText:Hide()
    ammoAnim = ammoText:CreateAnimationGroup()
    local fadeOut = ammoAnim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.4)
    fadeOut:SetStartDelay(AMMO_HOLD)
    ammoAnim:SetScript("OnFinished", function() ammoText:Hide() end)
end

local function AnchorAmmoText()
    local display = Display()
    if not display then return false end
    ammoText:ClearAllPoints()
    if petBar and petBar.anchored then
        ammoText:SetPoint("RIGHT", petBar, "LEFT", -10, 0)
    else
        ammoText:SetPoint("BOTTOMRIGHT", display.HealthBarsContainer or display, "TOPLEFT", -10, 2)
    end
    ammoText:SetScale(display:GetEffectiveScale() / UIParent:GetEffectiveScale())
    return true
end

local function ShowAmmo(count)
    if not FrameVisibility:IsDisplayOn() then return end
    if not ammoText then BuildAmmoText() end
    if not AnchorAmmoText() then return end
    ammoText:SetText(count)
    -- White, orange under 300, red under 150.
    if count < 150 then
        ammoText:SetTextColor(1, 0.25, 0.2)
    elseif count < 300 then
        ammoText:SetTextColor(1, 0.6, 0.1)
    else
        ammoText:SetTextColor(1, 1, 1)
    end
    -- Back to full on every shot; the fade only starts once you stop shooting.
    ammoAnim:Stop()
    ammoText:SetAlpha(1)
    ammoText:Show()
    ammoAnim:Play()
end

local function CheckAmmo()
    local count = AmmoCount()
    if count and lastAmmo and count < lastAmmo then ShowAmmo(count) end
    lastAmmo = count
end

function FrameVisibility:UpdateAmmoCount()
    local on = DisplayCfg("ammoCount") == true
    if not ammoEvents then
        if not on then return end
        ammoEvents = CreateFrame("Frame")
        ammoEvents:SetScript("OnEvent", CheckAmmo)
    end
    if on then
        ammoEvents:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        ammoEvents:RegisterEvent("BAG_UPDATE")
        ammoEvents:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        lastAmmo = AmmoCount()
    else
        ammoEvents:UnregisterAllEvents()
        if ammoText then ammoAnim:Stop() ammoText:Hide() end
    end
end

---------------------------------------------------------------------------
-- Edit Mode: a B.O.L.T block under the Player, Target and Personal Resource Display dialogs
---------------------------------------------------------------------------

local function NotHidden(unit)
    return function() return not Cfg(unit, "hide") end
end

function FrameVisibility:RegisterEditMode()
    if self.editModeRegistered or not EditMode.available then return end
    self.editModeRegistered = true

    for _, unit in ipairs(ORDER) do
        local def = UNITS[unit]
        local settings = {
            EditMode:Checkbox("Hide this frame", { "frameVisibility", unit, "hide" }, {
                desc = "Hides the " .. def.label .. " outside Edit Mode. Pick below when it comes back.",
            }),
        }
        -- The "comes back" choices only show once the frame is hidden.
        for _, condition in ipairs(def.conditions) do
            local path = { "frameVisibility", unit, condition.key }
            if condition.kinds then
                table.insert(settings, EditMode:Dropdown("  Show it with a target", path, TARGET_CHOICES, {
                    desc = "Which targets bring the frame back.",
                    hidden = NotHidden(unit),
                }))
            else
                table.insert(settings, EditMode:Checkbox("  Show it " .. condition.label:lower(), path,
                    { hidden = NotHidden(unit) }))
            end
        end
        table.insert(settings, EditMode:Checkbox("  Show it on mouse hover", { "frameVisibility", unit, "hover" }, {
            desc = "Keeps the frame where it is but invisible until you hover it (it stays clickable).",
            hidden = NotHidden(unit),
        }))
        EditMode:AddSystemSettings("UnitFrame", "EditModeUnitFrameSystemIndices",
            unit == "player" and "Player" or "Target", settings)
    end

    if not self:DisplayAllowed() then return end
    local displayOff = function() return not FrameVisibility:IsDisplayOn() end
    EditMode:AddSystemSettings("PersonalResourceDisplay", nil, nil, {
        EditMode:Checkbox("Show it in game", nil, {
            desc = "Blizzard's Personal Resource Display option: your health and power under your character. Off, it only shows here in Edit Mode. Pairs well with a hidden Player Frame.",
            default = false,
            keepOnReset = true,
            get = function() return FrameVisibility:IsDisplayOn() end,
            set = function(value) FrameVisibility:SetDisplayOn(value) end,
        }),
        EditMode:Dropdown("Also show it with a target", { "frameVisibility", "display", "showWithTarget" }, TARGET_CHOICES, {
            desc = "When Visibility above is In Combat: it also shows while you have this kind of target.",
            hidden = displayOff,
        }),
        EditMode:Slider("Opacity out of combat", { "frameVisibility", "display", "idleAlpha" }, {
            min = 0, max = 100, step = 5, format = EditMode.Percent,
            desc = "When Visibility above is In Combat: fade to this instead of hiding. Hovering shows it in full. 0% hides it.",
            hidden = displayOff,
        }),
        EditMode:Checkbox("Right-click it for menus", { "frameVisibility", "display", "rightClickMenus" }, {
            desc = "Right-click the display for your menu, Shift + right-click for your target's.",
            hidden = displayOff,
        }),
        EditMode:Checkbox("Pet health bar", { "frameVisibility", "display", "petHealth" }, {
            desc = "A half-height bar on top of your health bar with your pet's health, in the same style. Shows while you have a pet out. Click it like the Pet Frame: left-click targets your pet, right-click opens its menu.",
            hidden = displayOff,
        }),
        EditMode:Checkbox("  Color by pet happiness", { "frameVisibility", "display", "petHappiness" }, {
            desc = "The pet health bar takes your pet's mood as its colour: green when happy, amber when content, red when it's unhappy and needs feeding.",
            hidden = function() return displayOff() or not DisplayCfg("petHealth") or not PetHappiness end,
        }),
        EditMode:Checkbox("  Click to feed, pulse when hungry", { "frameVisibility", "display", "petFeed" }, {
            desc = "Hunters: while your pet is content or unhappy, the pet bar breathes softly and left-clicking it feeds your pet the cheapest food it eats from your bags, without opening them. Shift + left-click feeds it any time. Out of combat only; in combat left-click targets your pet as usual.",
            hidden = function() return displayOff() or not DisplayCfg("petHealth") or not (PetHappiness and C_PetInfo and C_PetInfo.CanPetEatItem) end,
        }),
        EditMode:Checkbox("Totem timers", { "frameVisibility", "display", "totems" }, {
            desc = "Your hawk and other totem summons as small round nodes centred above the pet bar: the spell's icon in the game's totem ring, with a sweep counting down its time. Hover one for its tooltip.",
            hidden = displayOff,
        }),
        EditMode:Checkbox("Target health bar", { "frameVisibility", "display", "targetBar" }, {
            desc = "Your target's health under your power bar, in the same style as the pet bar: red when hostile, yellow neutral, green friendly, class colour for players. Click it like a unit frame and hover it for its numbers.",
            hidden = displayOff,
        }),
        EditMode:Checkbox("  Target of target", { "frameVisibility", "display", "targetOfTargetBar" }, {
            desc = "Your target's target on the same row, in the last third: see who the mob is hitting or how the tank is doing. Click it to select them.",
            hidden = function() return displayOff() or not DisplayCfg("targetBar") end,
        }),
        EditMode:Checkbox("Pet damage after combat", { "frameVisibility", "display", "petDamage" }, {
            desc = "When a fight ends, a percentage fades in next to the pet health bar for a few seconds: the share of your damage your pets dealt (yours + theirs = 100%). Read from Blizzard's damage meter.",
            hidden = function() return displayOff() or not PetDamageAvailable() end,
        }),
        EditMode:Checkbox("Ammo count after each shot", { "frameVisibility", "display", "ammoCount" }, {
            desc = "Each shot that uses an arrow or bullet briefly shows how many you have left, in white to the left of the pet health bar.",
            hidden = function() return displayOff() or not BOLT.isForever end,
        }),
    })
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function FrameVisibility:OnLayoutChanged()
    self:ApplyFrames()
    RefreshDisplay()
    self:UpdateMenuCatcher()
    self:UpdateUnitBars()
    self:UpdateTotems()
    self:UpdatePetDamage()
    self:UpdateAmmoCount()
end

function FrameVisibility:OnSettingChanged(key, path)
    if path and path[2] == "display" then
        RefreshDisplay()
        self:UpdateMenuCatcher()
        self:UpdateUnitBars()
        self:UpdateTotems()
        self:UpdatePetDamage()
        self:UpdateAmmoCount()
    else
        self:ApplyFrames()
    end
end

function FrameVisibility:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
            if self.pending then self:ApplyFrames() end
            if self.menuPending then self:UpdateMenuCatcher() end
            if self.clickersPending then self:UpdateBarClickers() end
        end
    end)
    self:HookDisplay()
    self:RegisterEditMode()
    if EditMode.lib then
        EditMode.lib:RegisterCallback("enter", function() self:ApplyFrames() end)
        EditMode.lib:RegisterCallback("exit", function() self:ApplyFrames() end)
    end
end

function FrameVisibility:OnEnable()
    self:ApplyFrames()
    RefreshDisplay()
    self:UpdateMenuCatcher()
    self:UpdateUnitBars()
    self:UpdateTotems()
    self:UpdatePetDamage()
    self:UpdateAmmoCount()
end

BOLT:RegisterModule("frameVisibility", FrameVisibility)
