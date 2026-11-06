-- B.O.L.T Shoot Wand Key Module (WoW: Forever only)
-- One key that targets the enemy under the mouse (or keeps your current target) and starts wand
-- Shoot, and can send your pet in too.
--
-- Addons can't cast from their own code, so the key clicks a secure macro button
-- (binding "CLICK BOLTWandShootButton:LeftButton"), which works in and out of combat. The macro
-- is rebuilt when the pet option changes, out of combat only.

local ADDON_NAME, BOLT = ...

local WandShoot = {
    displayName = "Shoot Wand Key",
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
    local lines = { "/target [@mouseover,harm,nodead]" }
    if BOLT:GetConfig("wandShoot", "petAttack") then
        table.insert(lines, "/petattack [harm,nodead]")
    end
    -- "!" keeps a second press from stopping the wand.
    table.insert(lines, "/cast [harm,nodead] !" .. ShootName())
    return table.concat(lines, "\n")
end

-- Attribute changes on a secure button are blocked in combat; wait for it to end.
function WandShoot:Apply()
    if InCombatLockdown() then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self.button:SetAttribute("type", self.active and "macro" or nil)
    self.button:SetAttribute("macrotext", self.active and self:MacroText() or nil)
end

function WandShoot:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown", "AnyUp")
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
