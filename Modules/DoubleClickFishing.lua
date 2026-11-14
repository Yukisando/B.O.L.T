-- B.O.L.T Double-Click Fishing Module
-- Double right-click on the world to cast Fishing, with a fishing rod equipped.
--
-- Addons can't cast from their own code, so a quick right-click on the world arms the
-- double-click: BUTTON2 is bound to a secure button that casts Fishing, for as long as a second
-- click may follow. The second click casts on its RELEASE, always (useOnKeyDown = false):
-- - a second click at the exact same spot is a system double-click, and WoW doesn't hand its
--   press to the binding at all, only its release;
-- - with "cast on key down" on (ActionButtonUseKeyDown), the secure button ignores releases
--   unless useOnKeyDown is false. Earlier versions missed one or the other, so they only cast
--   when the mouse moved between the clicks, or never (fixed 2026-11-14).
-- A secure snippet clears the binding once it has cast (so it also works if combat starts); a
-- timer clears it if no second click comes.
-- Skipped in combat, while mounted, with a unit under the mouse, with a loot window open, while
-- already fishing (so a double-click on the bobber doesn't recast), or without a rod equipped.

local ADDON_NAME, BOLT = ...

local DoubleClickFishing = {
    displayName = "Double-Click Fishing",
}

local BUTTON_NAME = "BOLTFishingButton"
local MAX_HOLD = 0.3     -- a longer first press is turning the camera, not a click
local MAX_GAP = 0.45     -- seconds after the first click for the second one to start
local SECOND_HOLD = 1.5  -- once the second press started, how long its release may take

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
    self.token = (self.token or 0) + 1
    if self.bound and not InCombatLockdown() then
        ClearOverrideBindings(self.button)
    end
    self.bound = false
    self.secondPress = false
end

-- Clears the binding after `delay` seconds unless something re-armed or cleared it since.
function DoubleClickFishing:ClearAfter(delay)
    local token = self.token
    C_Timer.After(delay, function()
        if self.token == token and self.bound then self:ClearBinding() end
    end)
end

function DoubleClickFishing:OnMouseDown(mouseButton)
    if mouseButton ~= "RightButton" then return end
    if self.bound then
        -- The second click started: give its release time to reach the binding.
        if not self.secondPress then
            self.secondPress = true
            self.token = self.token + 1
            self:ClearAfter(SECOND_HOLD)
        end
        return
    end
    self.pressTime = GetTime()
end

function DoubleClickFishing:OnMouseUp(mouseButton)
    if mouseButton ~= "RightButton" then return end
    if self.bound then return end -- the second click's release; the button handles it
    local pressTime = self.pressTime
    self.pressTime = nil
    if not pressTime or GetTime() - pressTime > MAX_HOLD then return end
    if not self:CanCast() then return end
    local spell = FishingSpellName()
    if not spell then return end

    -- A quick click on the world: arm the second click.
    self.button:SetAttribute("spell", spell)
    SetOverrideBindingClick(self.button, true, "BUTTON2", BUTTON_NAME)
    self.bound = true
    self.secondPress = false
    self.token = (self.token or 0) + 1
    self:ClearAfter(MAX_GAP)
end

function DoubleClickFishing:OnInitialize()
    local button = CreateFrame("Button", BUTTON_NAME, nil, "SecureActionButtonTemplate")
    -- Releases only, whatever "cast on key down" says: see the top of the file.
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("useOnKeyDown", false)
    -- Drop the binding as soon as it has cast, from secure code so it also works in combat.
    SecureHandlerWrapScript(button, "PostClick", button, [[
        self:ClearBindings()
    ]])
    button:HookScript("PostClick", function()
        self.bound = false
        self.secondPress = false
        self.token = (self.token or 0) + 1
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
