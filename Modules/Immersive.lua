-- B.O.L.T Immersive Mode Module
-- Hides the player and target frames and turns on Blizzard's Personal Resource Display (your
-- health and power under your character) instead; enemies are read off their nameplates.
-- Turning it off brings both frames back and turns the Personal Resource Display off.
--
-- The frames are protected, so they are parked on a hidden parent (which also beats the unit
-- watch that shows the target frame) and only out of combat; a switch in combat waits for it.
--
-- With Edit Mode's "In Combat" visibility, the Personal Resource Display can also show while you
-- have a living, attackable target: BOLT shows it after each of Blizzard's own visibility checks
-- and asks for a new check when the target changes or dies. The frame isn't protected.

local ADDON_NAME, BOLT = ...

local Immersive = {
    displayName = "Immersive Mode",
}

local PRD_CVAR = "nameplateShowSelf"

local hider = CreateFrame("Frame")
hider:Hide()
local homes = {} -- [frame] = its Blizzard parent

local function Frames()
    return { PlayerFrame, TargetFrame }
end

local function PersonalDisplayAllowed()
    if not C_CVar.GetCVarInfo(PRD_CVAR) then return false end
    local rules, rule = C_GameRules, Enum.GameRule and Enum.GameRule.PersonalResourceDisplayDisabled
    return not (rules and rules.IsGameRuleActive and rule and rules.IsGameRuleActive(rule))
end

function Immersive:Apply()
    if InCombatLockdown() then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        BOLT:Print("Immersive Mode will switch when combat ends.")
        return
    end
    self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    local on = self.active
    for _, frame in ipairs(Frames()) do
        if on and frame:GetParent() ~= hider then
            homes[frame] = frame:GetParent()
            frame:SetParent(hider)
        elseif not on and frame:GetParent() == hider then
            frame:SetParent(homes[frame] or UIParent)
        end
    end

    if PersonalDisplayAllowed() then
        C_CVar.SetCVar(PRD_CVAR, on and "1" or "0")
    elseif on then
        BOLT:Print("The Personal Resource Display isn't available on this client.")
    end
end

---------------------------------------------------------------------------
-- Personal Resource Display with an attackable target
---------------------------------------------------------------------------

local function Display()
    return PersonalResourceDisplayFrame
end

-- Secret answers (Midnight, in some fights) count as "no".
local function Plain(value)
    if BOLT.IsSecret(value) then return nil end
    return value
end

local function HasAttackableTarget()
    if not UnitExists("target") then return false end
    return Plain(UnitCanAttack("player", "target")) == true
        and not Plain(UnitIsDeadOrGhost("target"))
end

-- Out of combat (and with no attackable target) the display fades to its own idle opacity
-- instead of vanishing; hovering it brings it back to full. 0% keeps Blizzard's hiding.
local FADE_SPEED = 4 -- alpha per second
local fader = CreateFrame("Frame")
fader:Hide()
fader.goal = 1

local function IdleAlpha()
    return (BOLT:GetConfig("immersive", "idleAlpha") or 0) / 100
end

fader:SetScript("OnUpdate", function(self, elapsed)
    local display = Display()
    if not display then return self:Hide() end
    local goal = MouseIsOver(display) and 1 or self.goal
    local alpha = display:GetAlpha()
    if alpha < goal then
        display:SetAlpha(math.min(goal, alpha + FADE_SPEED * elapsed))
    elseif alpha > goal then
        display:SetAlpha(math.max(goal, alpha - FADE_SPEED * elapsed))
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
    if not (Immersive.active and UsesCombatSetting(display)) then
        fader:Hide()
        display:SetAlpha(1)
        return
    end
    local wanted = display:IsShown()
        or (BOLT:GetConfig("immersive", "showWithTarget") and HasAttackableTarget())
    local idle = IdleAlpha()
    if wanted or idle > 0 then
        display:Show()
        fader.goal = wanted and 1 or idle
        fader:Show()
    else
        fader:Hide()
        display:SetAlpha(1)
    end
end

local function RefreshDisplay()
    local display = Display()
    if display and display.UpdateShownState then display:UpdateShownState() end
end

function Immersive:HookDisplay()
    local display = Display()
    if self.displayHooked or not (display and display.UpdateShownState) then return end
    self.displayHooked = true
    hooksecurefunc(display, "UpdateShownState", Settle)

    -- Ask for a new check only when "attackable target" flips, not on every health tick.
    local lastAttackable
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_TARGET_CHANGED")
    events:RegisterUnitEvent("UNIT_HEALTH", "target")
    events:RegisterUnitEvent("UNIT_FLAGS", "target")
    events:SetScript("OnEvent", function()
        local now = HasAttackableTarget()
        if now == lastAttackable then return end
        lastAttackable = now
        RefreshDisplay()
    end)
end

---------------------------------------------------------------------------
-- Right-click menus on the Personal Resource Display
---------------------------------------------------------------------------

-- With the player and target frames gone, their right-click menus move onto the bars under
-- your character: right-click opens your own menu, Shift + right-click your target's. A thin
-- click catcher sits over the health and power bars; left clicks pass through to the world.

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

function Immersive:UpdateMenuCatcher()
    local display = Display()
    if not (display and display.HealthBarsContainer) then return end
    local catcher = self.menuCatcher
    if not catcher then
        catcher = CreateFrame("Button", "BOLTImmersiveMenuCatcher", display)
        catcher:SetPoint("TOPLEFT", display.HealthBarsContainer, "TOPLEFT")
        catcher:SetPoint("BOTTOMRIGHT", display.PowerBar or display.HealthBarsContainer, "BOTTOMRIGHT")
        catcher:SetFrameLevel(display:GetFrameLevel() + 10)
        catcher:RegisterForClicks("RightButtonUp")
        catcher:SetMouseMotionEnabled(false)
        -- Restricted in combat only; modules start and settings change out of combat.
        if catcher.SetPassThroughButtons and not InCombatLockdown() then
            catcher:SetPassThroughButtons("LeftButton")
        end
        catcher:SetScript("OnClick", OpenMenu)
        self.menuCatcher = catcher
    end
    catcher:SetShown(self.active and BOLT:GetConfig("immersive", "rightClickMenus") and true or false)
end

function Immersive:OnSettingChanged()
    RefreshDisplay()
    self:UpdateMenuCatcher()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Immersive:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function() self:Apply() end)
    self:HookDisplay()
end

function Immersive:OnEnable()
    self:Apply()
    RefreshDisplay()
    self:UpdateMenuCatcher()
end

function Immersive:OnDisable()
    self:Apply()
    RefreshDisplay()
    self:UpdateMenuCatcher()
end

BOLT:RegisterModule("immersive", Immersive)
