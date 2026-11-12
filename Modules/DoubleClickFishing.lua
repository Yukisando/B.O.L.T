-- B.O.L.T Double-Click Fishing Module
-- Double right-click on the world to cast Fishing, with a fishing rod equipped.
--
-- Addons can't cast from their own code. The second press of a quick right-click pair binds
-- BUTTON2 to a secure button that casts Fishing, from inside that press's GLOBAL_MOUSE_DOWN, so
-- the same click lands on the binding (the way Better Fishing does it). The button starts
-- mouselook on the press and stops it on the release: without that, a click whose mouse didn't
-- move is a world click and its release never reaches the binding, so double-clicks only worked
-- when the mouse moved between the clicks (2026-11-12). A secure snippet clears the binding once
-- the click has cast; a timer and combat start clear it too.
-- Skipped in combat, while mounted, with a unit under the mouse, with a loot window open, while
-- already fishing (so a double-click on the bobber doesn't recast), or without a rod equipped.

local ADDON_NAME, BOLT = ...

local DoubleClickFishing = {
    displayName = "Double-Click Fishing",
}

local BUTTON_NAME = "BOLTFishingButton"
local MAX_HOLD = 0.3 -- a longer press is turning the camera, not a click
local MAX_GAP = 0.4  -- seconds between the two presses; slower is two single clicks
local MIN_GAP = 0.04 -- faster is one click reported twice

-- Fishing cast spells: modern one first, then the old ranks (Classic-style clients).
local FISHING_IDS = { 131474, 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410 }
local IS_FISHING_ID = {}
for _, id in ipairs(FISHING_IDS) do IS_FISHING_ID[id] = true end

-- Ask both APIs: on Forever an old rank can be missing from one and present in the other.
local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
    return IsSpellKnown ~= nil and IsSpellKnown(id) == true
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

-- A rod is a weapon (fishing pole) in the main hand on Forever and older clients, or a
-- profession tool in its own slot on retail. Slots 20-30 are retail's profession gear.
local ROD_SLOTS = { 16, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30 }
local WEAPON = Enum.ItemClass and Enum.ItemClass.Weapon or 2
local POLE = Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole or 20
local PROFESSION = Enum.ItemClass and Enum.ItemClass.Profession or 19
local FISHING_TOOL = Enum.ItemProfessionSubclass and Enum.ItemProfessionSubclass.Fishing or 9

local function HasRodEquipped()
    local info = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    for _, slot in ipairs(ROD_SLOTS) do
        local id = GetInventoryItemID("player", slot)
        if id then
            local classID, subclassID = select(6, info(id))
            if (classID == WEAPON and subclassID == POLE)
                or (classID == PROFESSION and subclassID == FISHING_TOOL) then
                return true
            end
        end
    end
    return false
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
        and HasRodEquipped()
end

function DoubleClickFishing:ClearBinding()
    if self.bound and not InCombatLockdown() then
        ClearOverrideBindings(self.button)
    end
    self.bound = false
end

function DoubleClickFishing:OnMouseDown(mouseButton)
    if mouseButton ~= "RightButton" then return end
    local now = GetTime()
    local first, released = self.firstPress, self.firstReleased
    self.firstPress, self.firstReleased = now, false
    if self.bound or not first then return end
    local gap = now - first
    -- The first click must have been a click (released quickly), not a camera turn.
    if gap < MIN_GAP or gap > MAX_GAP or not released then return end
    if not self:CanCast() then return end
    local spell = FishingSpellName()
    if not spell then return end

    self.firstPress = nil
    self.button:SetAttribute("spell", spell)
    self.button:SetAttribute("useKeyDowns", GetCVarBool("ActionButtonUseKeyDown"))
    SetOverrideBindingClick(self.button, true, "BUTTON2", BUTTON_NAME)
    self.bound = true
    self.bindToken = (self.bindToken or 0) + 1
    local token = self.bindToken
    C_Timer.After(1, function()
        if token == self.bindToken then self:ClearBinding() end
    end)
end

function DoubleClickFishing:OnMouseUp(mouseButton)
    if mouseButton ~= "RightButton" then return end
    self.firstReleased = self.firstPress ~= nil and GetTime() - self.firstPress <= MAX_HOLD
end

function DoubleClickFishing:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, nil, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown", "AnyUp")
    button:SetAttribute("type", "spell")
    button:SetScript("PostClick", function(_, _, down)
        if down then
            MouselookStart()
        else
            MouselookStop()
        end
    end)
    -- The button casts on the press or the release (ActionButtonUseKeyDown); drop the binding
    -- on that edge, from secure code so it also works if combat started in between.
    SecureHandlerWrapScript(button, "PostClick", button, [[
        if (self:GetAttribute("useKeyDowns") and down) or not down then
            self:ClearBindings()
        end
    ]])
    button:HookScript("PostClick", function(_, _, down)
        if not down or self.button:GetAttribute("useKeyDowns") then self.bound = false end
    end)
    self.button = button

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "GLOBAL_MOUSE_DOWN" then
            self:OnMouseDown(...)
        elseif event == "GLOBAL_MOUSE_UP" then
            self:OnMouseUp(...)
        elseif event == "PLAYER_REGEN_DISABLED" then
            self:ClearBinding()
        end
    end)
    self.eventFrame = frame
end

function DoubleClickFishing:OnEnable()
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    self.eventFrame:RegisterEvent("GLOBAL_MOUSE_UP")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
end

function DoubleClickFishing:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    self:ClearBinding()
end

BOLT:RegisterModule("doubleClickFishing", DoubleClickFishing)
