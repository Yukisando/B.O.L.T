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
-- and right-click menus (yours; Shift for your target's) on its bars.

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
local function OpenMenu(catcher)
    if IsShiftKeyDown() then
        if UnitExists("target") and TargetFrame_OpenMenu then TargetFrame_OpenMenu(catcher) end
        return
    end
    if not UnitPopup_OpenMenu then return end
    local inVehicle = UnitHasVehicleUI and UnitHasVehicleUI("player")
    UnitPopup_OpenMenu(inVehicle and "VEHICLE" or "SELF", {
        fromPlayerFrame = true,
        ownerFrame = catcher,
        unit = inVehicle and "vehicle" or "player",
    })
end

function FrameVisibility:UpdateMenuCatcher()
    local display = Display()
    if not (display and display.HealthBarsContainer) then return end
    local catcher = self.menuCatcher
    if not catcher then
        if not DisplayCfg("rightClickMenus") then return end
        catcher = CreateFrame("Button", "BOLTDisplayMenuCatcher", display)
        catcher:SetPoint("TOPLEFT", display.HealthBarsContainer, "TOPLEFT")
        catcher:SetPoint("BOTTOMRIGHT", display.PowerBar or display.HealthBarsContainer, "BOTTOMRIGHT")
        catcher:SetFrameLevel(display:GetFrameLevel() + 10)
        catcher:RegisterForClicks("RightButtonUp")
        catcher:SetMouseMotionEnabled(false)
        if catcher.SetPassThroughButtons and not InCombatLockdown() then
            catcher:SetPassThroughButtons("LeftButton")
        end
        catcher:SetScript("OnClick", OpenMenu)
        self.menuCatcher = catcher
    end
    catcher:SetShown(DisplayCfg("rightClickMenus") and true or false)
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
    })
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function FrameVisibility:OnSettingChanged(key, path)
    if path and path[2] == "display" then
        RefreshDisplay()
        self:UpdateMenuCatcher()
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
end

BOLT:RegisterModule("frameVisibility", FrameVisibility)
