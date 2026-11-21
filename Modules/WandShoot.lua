-- B.O.L.T Wand & Pet Attack Key Module (WoW: Forever only)
-- One key that targets the enemy under the mouse (or keeps your current target), sends your pet
-- in and starts wand Shoot (Auto Shot for hunters). Pet attack is always part of it since 2026-11-12 (it was an option).
-- It also puts the pet in Assist mode (setting, on by default), so it keeps helping you after.
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

local AUTO_SHOT_SPELL_ID = 75 -- hunters: Auto Shot (they can't use wands)

local function SpellName(spellID, fallback)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    return name or fallback
end

-- Hunters start Auto Shot with their bow or gun; everyone else their wand's Shoot (2026-11-21).
local function ShootName()
    if select(2, UnitClass("player")) == "HUNTER" and IsPlayerSpell and IsPlayerSpell(AUTO_SHOT_SPELL_ID) then
        return SpellName(AUTO_SHOT_SPELL_ID, "Auto Shot")
    end
    return SpellName(SHOOT_SPELL_ID, "Shoot")
end

-- Assist mode (the pet attacks what you attack) only exists where the client has it.
function WandShoot:CanAssist()
    return C_PetInfo ~= nil and C_PetInfo.PetAssistMode ~= nil
end

function WandShoot:MacroText()
    -- "!" keeps a second press from stopping the wand. Shoot goes before /petattack: with the pet
    -- line first, only the pet attacked and the wand never started (2026-11-12).
    local lines = {
        "/target [@mouseover,harm,nodead]",
        "/cast [harm,nodead] !" .. ShootName(),
    }
    if BOLT:GetConfig("wandShoot", "petAssist") and self:CanAssist() then
        table.insert(lines, "/petassist [@pet,exists]")
    end
    table.insert(lines, "/petattack [harm,nodead]")
    return table.concat(lines, "\n")
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
    -- The spellbook (Auto Shot or not) may not be known yet at login.
    self.eventFrame:RegisterEvent("SPELLS_CHANGED")
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
