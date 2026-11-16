-- B.O.L.T Cheetah Warning Module (hunters)
-- Warns when combat starts while Aspect of the Cheetah (or of the Pack) is on you: on Forever and
-- older clients it dazes you on every hit. A quiet gold line and a soft ping, then a silent
-- reminder line every few seconds for as long as the aspect stays up in combat.

local ADDON_NAME, BOLT = ...

local CheetahWarning = {
    displayName = "Cheetah Warning",
}

-- Aspect of the Cheetah, Aspect of the Pack (old ranks and modern IDs).
local ASPECTS = { 5118, 13159, 186257, 186258 }
local REPEAT = 4 -- seconds between reminders while the aspect stays up in combat

function CheetahWarning:IsSupported()
    local _, class = UnitClass("player")
    return class == "HUNTER"
end

local function HasAspect(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
        return ok and aura ~= nil
    end
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, id = UnitBuff("player", i)
        if not id then return false end
        if id == spellID then return true end
    end
    return false
end

-- The aspect that is on, by name, or nil.
local function ActiveAspect()
    for _, id in ipairs(ASPECTS) do
        if HasAspect(id) then
            return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) or GetSpellInfo(id)
        end
    end
end

-- A quiet hint: a gold line where the game prints "Out of range" and the like, with a soft ping
-- the first time only (reminders are silent).
function CheetahWarning:Warn(name, first)
    local text = ("%s is still on"):format(name or "Aspect of the Cheetah")
    if UIErrorsFrame then
        UIErrorsFrame:AddMessage(text, 1, 0.82, 0)
    end
    if first then PlaySound(3175, "SFX") end -- map ping
end

-- combatStarting: called from PLAYER_REGEN_DISABLED, when the combat flag may not be set yet.
function CheetahWarning:Check(combatStarting)
    self.token = (self.token or 0) + 1
    if not self.active then return end
    if not combatStarting and not UnitAffectingCombat("player") then return end
    local name = ActiveAspect()
    if not name then return end
    self:Warn(name, combatStarting)
    local token = self.token
    C_Timer.After(REPEAT, function()
        if self.token == token then self:Check() end
    end)
end

function CheetahWarning:OnInitialize()
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function() self:Check(true) end)
    self.eventFrame = frame
end

function CheetahWarning:OnEnable()
    -- PLAYER_REGEN_DISABLED fires as combat starts; nothing else is needed, since the reminder
    -- timer keeps checking until the aspect drops or combat ends.
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function CheetahWarning:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self.token = (self.token or 0) + 1
end

BOLT:RegisterModule("cheetahWarning", CheetahWarning)
