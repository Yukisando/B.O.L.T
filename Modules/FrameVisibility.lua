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
    local goal = display:IsMouseOver() and 1 or self.goal
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
-- Pet health bar: half the height of the display's other bars, drawn with its own bar art and
-- sitting on top of its health bar. A child of the display, so it shows, hides, fades and scales
-- with it; it only shows while you have a pet out.
---------------------------------------------------------------------------

local PET_COLOR = { 0.45, 0.85, 0.3 } -- a softer green than the player's own health
local DEFAULT_PADDING = 4
local DEFAULT_POWER_HEIGHT = 10 -- the display's power bar height when unreadable
local PET_MIN_HEIGHT = 5
local WHITE = "Interface\\Buttons\\WHITE8X8"

local petBar, petAnchoredTo, petEvents

local function Readable(value, fallback)
    if value and not BOLT.IsSecret(value) and value > 0 then return value end
    return fallback
end

-- Where the pet bar goes: just above the health container, half the power bar's height.
local function PetBarLayout(display)
    local container = display.HealthBarsContainer or display
    local power = display.PowerBar
    local height = power and Readable(power:GetHeight(), DEFAULT_POWER_HEIGHT) or DEFAULT_POWER_HEIGHT
    local padding = display.GetBarPadding and Readable(display:GetBarPadding(), DEFAULT_PADDING) or DEFAULT_PADDING
    return container, padding, math.max(PET_MIN_HEIGHT, math.floor(height / 2 + 0.5))
end

local function AnchorPetBar()
    local display = Display()
    if not display then return false end
    if petBar:GetParent() ~= display then petBar:SetParent(display) end
    local container, padding, height = PetBarLayout(display)
    petBar:ClearAllPoints()
    petBar:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 0, padding)
    petBar:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 0, padding)
    petBar:SetHeight(height)
    if petAnchoredTo ~= container then
        petAnchoredTo = container
        -- Edit Mode changes to the display's size reach the container; follow them.
        container:HookScript("OnSizeChanged", function()
            if petBar:IsShown() and petAnchoredTo == container then AnchorPetBar() end
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
---------------------------------------------------------------------------

local MOODS = {
    [1] = { 0.9, 0.25, 0.2 },   -- unhappy: feed it
    [2] = { 0.95, 0.7, 0.2 },   -- content: feed it soon
    [3] = PET_COLOR,            -- happy
}

local PetHappiness = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness

local function UpdateMoodColor()
    local happiness = DisplayCfg("petHappiness") and PetHappiness and HasPetUI
        and select(2, HasPetUI()) and PetHappiness()
    local color = happiness and MOODS[happiness] or PET_COLOR
    petBar:SetStatusBarColor(color[1], color[2], color[3])
end

-- UnitHealth/UnitHealthMax can be secret values in combat on Midnight; status bars accept them
-- as they are, so they go straight in without being compared.
local function UpdatePetBar()
    if not (DisplayCfg("petHealth") and UnitExists("pet") and AnchorPetBar()) then
        petBar:Hide()
        return
    end
    petBar:SetMinMaxValues(0, UnitHealthMax("pet"))
    petBar:SetValue(UnitHealth("pet"))
    petBar:Show()
    UpdateMoodColor()
end

local function BuildPetBar()
    petBar = CreateFrame("StatusBar", "BOLTPetHealthBar", UIParent)
    petBar:SetMinMaxValues(0, 1)
    petBar:SetValue(1)
    petBar:Hide()

    -- The display's own bar art (PersonalResourceStatusBar template): the background atlas
    -- carries the gold border, drawn a little past the fill on every side.
    local fill = BOLT.NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar")
    local back = BOLT.NativeArt.ResolveAtlas("UI-HUD-CoolDownManager-Bar-BG")
    petBar:SetStatusBarTexture(fill or WHITE)
    petBar:SetStatusBarColor(PET_COLOR[1], PET_COLOR[2], PET_COLOR[3])
    local background = petBar:CreateTexture(nil, "BACKGROUND")
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

    petEvents = CreateFrame("Frame")
    petEvents:SetScript("OnEvent", UpdatePetBar)
end

function FrameVisibility:UpdatePetBar()
    local on = DisplayCfg("petHealth") == true
    if not petBar then
        if not on then return end
        BuildPetBar()
    end
    if on then
        petEvents:RegisterUnitEvent("UNIT_HEALTH", "pet")
        petEvents:RegisterUnitEvent("UNIT_MAXHEALTH", "pet")
        petEvents:RegisterUnitEvent("UNIT_PET", "player")
        petEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        if PetHappiness then
            -- UNIT_HAPPINESS only exists on clients with pet happiness (Blizzard's own indicator
            -- listens to it unfiltered); happiness is also a pet power on some clients, so power
            -- updates cover those.
            pcall(petEvents.RegisterEvent, petEvents, "UNIT_HAPPINESS")
            petEvents:RegisterUnitEvent("UNIT_POWER_UPDATE", "pet")
        end
    else
        petEvents:UnregisterAllEvents()
    end
    UpdatePetBar()
    self:UpdatePetClicker()
end

---------------------------------------------------------------------------
-- Clicking the pet bar works like the Pet Frame: left-click targets your pet, right-click opens
-- its menu (Dismiss, Rename, Abandon...). Hovering it shows the pet's tooltip.
-- Same reasons as the menu catcher above: a secure unit button on UIParent with coordinates
-- copied from where the bar sits, moved only out of combat. RegisterUnitWatch shows and hides it
-- with the pet, which keeps working in combat (the pet dies, you summon another).
---------------------------------------------------------------------------

function FrameVisibility:SyncPetClicker(combatStarting)
    local clicker, display = self.petClicker, Display()
    if not (clicker and display) or InCombatLockdown() then return end
    local container, padding, height = PetBarLayout(display)
    local left, right = Plain(container:GetLeft()), Plain(container:GetRight())
    local top = Plain(container:GetTop())
    local wanted = DisplayCfg("petHealth") and not display.isInEditMode
        and (combatStarting and DisplayShowsInCombat(display) or display:IsVisible())
    if not (wanted and left and right and top) then
        UnregisterUnitWatch(clicker)
        clicker:Hide()
        return
    end
    local ratio = container:GetEffectiveScale() / UIParent:GetEffectiveScale()
    clicker:ClearAllPoints()
    -- One extra pixel around the bar so it isn't fiddly to hit.
    clicker:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, (top + padding - 1) * ratio)
    clicker:SetSize(math.max(1, (right - left) * ratio), (height + 2) * ratio)
    clicker:SetFrameStrata(display:GetFrameStrata())
    clicker:SetFrameLevel(display:GetFrameLevel() + 10)
    RegisterUnitWatch(clicker)
end

function FrameVisibility:UpdatePetClicker()
    local display = Display()
    if not display then return end
    if InCombatLockdown() then
        self.petClickerPending = true
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.petClickerPending = nil
    if not self.petClicker then
        if not DisplayCfg("petHealth") then return end
        local clicker = CreateFrame("Button", "BOLTPetBarClicker", UIParent, "SecureUnitButtonTemplate")
        clicker:Hide()
        clicker:RegisterForClicks("AnyUp")
        clicker:SetAttribute("unit", "pet")
        clicker:SetAttribute("*type1", "target")
        clicker:SetAttribute("*type2", "togglemenu")
        clicker:SetScript("OnEnter", function(button)
            GameTooltip_SetDefaultAnchor(GameTooltip, button)
            GameTooltip:SetUnit("pet")
            GameTooltip:Show()
        end)
        clicker:SetScript("OnLeave", GameTooltip_Hide)
        self.petClicker = clicker
        FollowDisplay(display, function(combatStarting) self:SyncPetClicker(combatStarting) end)
    end
    self:SyncPetClicker()
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
    if petBar and petAnchoredTo then
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
    if petBar and petAnchoredTo then
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
    self:UpdatePetBar()
    self:UpdatePetDamage()
    self:UpdateAmmoCount()
end

function FrameVisibility:OnSettingChanged(key, path)
    if path and path[2] == "display" then
        RefreshDisplay()
        self:UpdateMenuCatcher()
        self:UpdatePetBar()
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
            if self.petClickerPending then self:UpdatePetClicker() end
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
    self:UpdatePetBar()
    self:UpdatePetDamage()
    self:UpdateAmmoCount()
end

BOLT:RegisterModule("frameVisibility", FrameVisibility)
