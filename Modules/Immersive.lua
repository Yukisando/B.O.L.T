-- B.O.L.T Immersive Mode Module
-- Hides the player and target frames and turns on Blizzard's Personal Resource Display (your
-- health and power under your character) instead; enemies are read off their nameplates.
-- Turning it off brings both frames back and turns the Personal Resource Display off.
--
-- The frames are protected, so they are parked on a hidden parent (which also beats the unit
-- watch that shows the target frame) and only out of combat; a switch in combat waits for it.

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

function Immersive:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function() self:Apply() end)
end

function Immersive:OnEnable()
    self:Apply()
end

function Immersive:OnDisable()
    self:Apply()
end

BOLT:RegisterModule("immersive", Immersive)
