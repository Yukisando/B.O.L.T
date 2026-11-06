-- B.O.L.T Campfire Module (WoW: Forever only)
-- When the "Campfire Nearby" buff is on you, a small prompt fades in above the action bars,
-- offering to sit by the fire. Click it to sit; right-click to dismiss it until you next come
-- near a fire. It steps aside while you sit, fight, ride, swim or are dead, and comes back when
-- you get up and walk around while still near the fire.

local ADDON_NAME, BOLT = ...

local Campfire = {
    displayName = "Campfire Rest",
}

local BUFF_NAME = "Campfire Nearby"
local FALLBACK_ICON = "Interface\\Icons\\Spell_Fire_Fire"
local FADE = 0.35 -- seconds
local ICON_SIZE = 30

function Campfire:IsSupported()
    return BOLT.isForever
end

local prompt
local state = {
    seated = false,    -- clicked "sit", until the player moves
    dismissed = false, -- right-clicked, until the buff goes away
}

local function FindBuff()
    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName then
        return C_UnitAuras.GetAuraDataBySpellName("player", BUFF_NAME, "HELPFUL")
    end
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then return nil end
        if aura.name == BUFF_NAME then return aura end
    end
end

local function CanSit()
    return not (InCombatLockdown() or UnitAffectingCombat("player") or UnitIsDeadOrGhost("player") or IsMounted()
        or IsSwimming() or IsFlying() or UnitOnTaxi("player") or UnitInVehicle("player"))
end

---------------------------------------------------------------------------
-- The prompt
---------------------------------------------------------------------------

local function FadeTo(alpha, onDone)
    prompt.fade:Stop()
    local from = prompt:GetAlpha()
    if math.abs(alpha - from) < 0.01 then
        prompt:SetAlpha(alpha)
        if onDone then onDone() end
        return
    end
    prompt.fade.alpha:SetFromAlpha(from)
    prompt.fade.alpha:SetToAlpha(alpha)
    prompt.fade.alpha:SetDuration(FADE * math.abs(alpha - from))
    prompt.fade.onDone = onDone
    prompt.fade:Play()
end

local function Reveal()
    if prompt.wanted then return end
    prompt.wanted = true
    if not prompt:IsShown() then
        prompt:SetAlpha(0)
        prompt:Show()
    end
    prompt.glow.pulse:Play()
    FadeTo(1)
end

local function Conceal()
    if not prompt.wanted then return end
    prompt.wanted = false
    FadeTo(0, function()
        prompt:Hide()
        prompt.glow.pulse:Stop()
    end)
end

local function Sit()
    DoEmote("SIT")
    state.seated = true
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    Campfire:Update()
end

local function BuildPrompt()
    prompt = CreateFrame("Button", "BOLTCampfirePrompt", UIParent, "TooltipBackdropTemplate")
    prompt:SetFrameStrata("MEDIUM")
    prompt:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 230)
    prompt:SetHeight(ICON_SIZE + 16)
    prompt:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    prompt:Hide()
    if prompt.NineSlice and prompt.NineSlice.SetCenterColor then
        prompt.NineSlice:SetCenterColor(0, 0, 0, 0.8)
    end

    local icon = prompt:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", 9, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    prompt.icon = icon

    -- A soft warm glow behind the icon that breathes while the prompt is up.
    local glow = prompt:CreateTexture(nil, "BACKGROUND", nil, 1)
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.55, 0.15)
    glow:SetSize(ICON_SIZE * 1.9, ICON_SIZE * 1.9)
    glow:SetPoint("CENTER", icon)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local breathe = pulse:CreateAnimation("Alpha")
    breathe:SetFromAlpha(0.25)
    breathe:SetToAlpha(0.8)
    breathe:SetDuration(1.4)
    breathe:SetSmoothing("IN_OUT")
    glow.pulse = pulse
    prompt.glow = glow

    local title = prompt:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 9, -1)
    title:SetText("Sit by the fire")
    local hint = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 9, 1)
    hint:SetText("Rest a while and warm up")
    hint:SetTextColor(0.85, 0.85, 0.85)
    prompt:SetWidth(ICON_SIZE + 30 + math.max(title:GetStringWidth(), hint:GetStringWidth()))

    local highlight = prompt:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.75, 0.35, 0.25)
    highlight:SetPoint("TOPLEFT", 4, -4)
    highlight:SetPoint("BOTTOMRIGHT", -4, 4)

    local fade = prompt:CreateAnimationGroup()
    fade.alpha = fade:CreateAnimation("Alpha")
    fade:SetToFinalAlpha(true)
    fade:SetScript("OnFinished", function(self)
        if self.onDone then self.onDone() end
    end)
    prompt.fade = fade

    prompt:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            state.dismissed = true
            Campfire:Update()
        else
            Sit()
        end
    end)
    prompt:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Campfire", 1, 1, 1)
        GameTooltip:AddLine("Click to sit down by the fire.", nil, nil, nil, true)
        GameTooltip:AddLine("Right-click to dismiss until the next fire.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    prompt:SetScript("OnLeave", GameTooltip_Hide)
end

function Campfire:Update()
    if not prompt then return end
    local buff = self.active and FindBuff()
    if not buff then
        state.dismissed, state.seated = false, false
        return Conceal()
    end
    prompt.icon:SetTexture(buff.icon or FALLBACK_ICON)
    if state.dismissed or state.seated or not CanSit() then
        return Conceal()
    end
    Reveal()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Campfire:OnInitialize()
    BuildPrompt()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_STARTED_MOVING" then state.seated = false end
        self:Update()
    end)
end

function Campfire:OnEnable()
    local events = self.eventFrame
    events:RegisterUnitEvent("UNIT_AURA", "player")
    for _, event in ipairs({ "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_DEAD", "PLAYER_UNGHOST", "PLAYER_ENTERING_WORLD" }) do
        events:RegisterEvent(event)
    end
    self:Update()
end

function Campfire:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self:Update()
end

BOLT:RegisterModule("campfire", Campfire)
