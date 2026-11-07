-- B.O.L.T Double-Click Fishing Module
-- Double right-click on the world to cast Fishing.
--
-- Addons can't cast from their own code. On the second right press, BUTTON2 is bound for that one
-- click to a secure button that casts Fishing; the button clears the binding as soon as it fires
-- (a secure snippet, so it also works if combat starts), and a short timer clears it if the click
-- never lands. Skipped in combat, while mounted, with a unit under the mouse, with a loot window
-- open, or while already fishing (so a double-click on the bobber doesn't recast).

local ADDON_NAME, BOLT = ...

local DoubleClickFishing = {
    displayName = "Double-Click Fishing",
}

local BUTTON_NAME = "BOLTFishingButton"
local MIN_GAP = 0.05 -- faster than this is a bounce, not a second click
local MAX_GAP = 0.4  -- slower than this is two single clicks

-- Fishing cast spells: modern one first, then the old ranks (Classic-style clients).
local FISHING_IDS = { 131474, 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410 }
local IS_FISHING_ID = {}
for _, id in ipairs(FISHING_IDS) do IS_FISHING_ID[id] = true end

local function IsKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id)
    end
    return IsPlayerSpell and IsPlayerSpell(id)
end

-- The known Fishing spell's name; casting by name picks the best rank. nil if the player can't fish.
local function FishingSpellName()
    for _, id in ipairs(FISHING_IDS) do
        if IsKnown(id) then
            return C_Spell.GetSpellName(id)
        end
    end
end

local function IsFishing()
    local spellID = select(8, UnitChannelInfo("player"))
    return spellID and IS_FISHING_ID[spellID] or false
end

local function MouseOverWorld()
    local focus
    if GetMouseFoci then
        focus = GetMouseFoci()[1]
    elseif GetMouseFocus then
        focus = GetMouseFocus()
    end
    return focus == nil or focus == WorldFrame
end

function DoubleClickFishing:CanCast()
    return not InCombatLockdown()
        and not IsMounted()
        and not (IsFlying and IsFlying())
        and not UnitExists("mouseover")
        and GetNumLootItems() == 0
        and not IsMouseButtonDown("LeftButton")
        and MouseOverWorld()
        and not IsFishing()
end

function DoubleClickFishing:ClearBinding()
    if self.bound and not InCombatLockdown() then
        ClearOverrideBindings(self.button)
        self.bound = false
    end
end

function DoubleClickFishing:OnMouseDown(mouseButton)
    if mouseButton ~= "RightButton" or InCombatLockdown() then return end

    local now = GetTime()
    local gap = now - (self.lastClick or 0)
    self.lastClick = now
    if gap < MIN_GAP or gap > MAX_GAP or not self:CanCast() then return end

    local spell = FishingSpellName()
    if not spell then return end

    self.lastClick = nil -- a third click starts a new pair
    self.button:SetAttribute("spell", spell)
    self.button:SetAttribute("useKeyDown", GetCVarBool("ActionButtonUseKeyDown"))
    SetOverrideBindingClick(self.button, true, "BUTTON2", BUTTON_NAME)
    self.bound = true
    C_Timer.After(0.5, function() self:ClearBinding() end)
end

function DoubleClickFishing:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "spell")
    -- Drop the one-shot binding on the press that actually casts (down or up, per the CVar).
    SecureHandlerWrapScript(button, "PostClick", button, [[
        if down == self:GetAttribute("useKeyDown") then
            self:ClearBindings()
        end
    ]])
    self.button = button

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "GLOBAL_MOUSE_DOWN" then
            self:OnMouseDown(...)
        elseif event == "PLAYER_REGEN_DISABLED" then
            self:ClearBinding()
        end
    end)
    self.eventFrame = frame
end

function DoubleClickFishing:OnEnable()
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function DoubleClickFishing:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self:ClearBinding()
end

BOLT:RegisterModule("doubleClickFishing", DoubleClickFishing)
