-- B.O.L.T Double-Click Fishing Module
-- Double right-click on the world to cast Fishing.
--
-- Addons can't cast from their own code. WoW sends a key's release to the binding that took its
-- press, so the binding can't be swapped in the middle of a click. Instead, a short right-click on
-- the world arms the double-click: BUTTON2 is bound to a secure button that casts Fishing, for as
-- long as a second click may follow. The button clears the binding as soon as it fires (a secure
-- snippet, so it also works if combat starts), and a timer clears it if no second click comes.
-- Skipped in combat, while mounted, with a unit under the mouse, with a loot window open, or
-- while already fishing (so a double-click on the bobber doesn't recast).

local ADDON_NAME, BOLT = ...

local DoubleClickFishing = {
    displayName = "Double-Click Fishing",
}

local BUTTON_NAME = "BOLTFishingButton"
local MAX_HOLD = 0.3 -- a longer press is turning the camera, not a click
local MAX_GAP = 0.4  -- slower than this is two single clicks

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
    end
    self.bound = false
end

function DoubleClickFishing:OnMouseDown(mouseButton)
    if mouseButton ~= "RightButton" then return end
    if self.bound then
        -- This press went to the fishing button; tidy up once the binding has fired.
        self.pressTime = nil
        C_Timer.After(0, function() self:ClearBinding() end)
        return
    end
    self.pressTime = GetTime()
end

function DoubleClickFishing:OnMouseUp(mouseButton)
    if mouseButton ~= "RightButton" or not self.pressTime then return end
    local held = GetTime() - self.pressTime
    self.pressTime = nil
    if held > MAX_HOLD or not self:CanCast() then return end

    local spell = FishingSpellName()
    if not spell then return end

    self.button:SetAttribute("spell", spell)
    SetOverrideBindingClick(self.button, true, "BUTTON2", BUTTON_NAME)
    self.bound = true
    self.armToken = (self.armToken or 0) + 1
    local token = self.armToken
    C_Timer.After(MAX_GAP, function()
        if token == self.armToken then
            self:ClearBinding()
        end
    end)
end

function DoubleClickFishing:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, UIParent, "SecureActionButtonTemplate")
    button:RegisterForClicks("AnyDown")
    button:SetAttribute("type", "spell")
    -- Cast on the second press. Blizzard reads "useOnKeyDown"; without it the button follows
    -- ActionButtonUseKeyDown and a player with it off would never cast.
    button:SetAttribute("useOnKeyDown", true)
    -- Drop the one-shot binding as soon as it has cast.
    SecureHandlerWrapScript(button, "PostClick", button, [[
        self:ClearBindings()
    ]])
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
