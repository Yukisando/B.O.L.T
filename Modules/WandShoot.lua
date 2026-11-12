-- B.O.L.T Wand & Pet Attack Key Module (WoW: Forever only)
-- One key that targets the enemy under the mouse (or keeps your current target), sends your pet
-- in and starts wand Shoot. Pet attack is always part of it since 2026-11-12 (it was an option).
--
-- Addons can't cast from their own code, so the key clicks a secure macro button
-- (binding "CLICK BOLTWandShootButton:LeftButton"), which works in and out of combat. The macro
-- is set out of combat only.

local ADDON_NAME, BOLT = ...

local WandShoot = {
    displayName = "Wand & Pet Attack Key",
}

local SHOOT_SPELL_ID = 5019 -- wand Shoot
local BUTTON_NAME = "BOLTWandShootButton"
WandShoot.BINDING = "CLICK " .. BUTTON_NAME .. ":LeftButton"

function WandShoot:IsSupported()
    return BOLT.isForever
end

local function ShootName()
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(SHOOT_SPELL_ID)
    return name or "Shoot"
end

function WandShoot:MacroText()
    -- "!" keeps a second press from stopping the wand. Shoot goes before /petattack: with the pet
    -- line first, only the pet attacked and the wand never started (2026-11-12).
    return table.concat({
        "/target [@mouseover,harm,nodead]",
        "/cast [harm,nodead] !" .. ShootName(),
        "/petattack [harm,nodead]",
    }, "\n")
end

-- Attribute changes on a secure button are blocked in combat; wait for it to end.
function WandShoot:Apply()
    if InCombatLockdown() then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    -- Run the macro once per key press (on the press or the release, per ActionButtonUseKeyDown).
    -- Running it on both would recast Shoot, which can stop the wand.
    local onDown = GetCVarBool("ActionButtonUseKeyDown")
    self.button:RegisterForClicks(onDown and "AnyDown" or "AnyUp")
    self.button:SetAttribute("useOnKeyDown", onDown)
    self.button:SetAttribute("type", self.active and "macro" or nil)
    self.button:SetAttribute("macrotext", self.active and self:MacroText() or nil)
end

function WandShoot:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    self.button = button
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function() self:Apply() end)
end

function WandShoot:OnSettingChanged()
    self:Apply()
end

function WandShoot:OnEnable()
    self:Apply()
end

function WandShoot:OnDisable()
    self:Apply()
end

BOLT:RegisterModule("wandShoot", WandShoot)
