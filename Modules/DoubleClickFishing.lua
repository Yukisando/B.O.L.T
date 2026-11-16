-- B.O.L.T Double-Click Fishing Module
-- Double right-click on the world to cast Fishing, with a fishing rod equipped.
--
-- Addons can't cast from their own code, so a quick right-click on the world arms the
-- double-click: an invisible secure button that casts Fishing covers the world (BACKGROUND strata,
-- so the UI stays on top of it) for as long as a second click may follow. The second click lands
-- on that button as a real mouse click, which is how action buttons cast, so it works whatever
-- "cast on key down" says. Left clicks pass through it to the world.
--
-- Why not a key binding (2026-11-16): every earlier version bound BUTTON2 to the button for the
-- second click. A second click at the same spot is a system double-click, which WoW never hands to
-- key bindings, so those versions only cast when the mouse moved between the clicks, or never.
--
-- A second press held down is a camera turn: the cover hides and mouselook takes over.
-- Skipped in combat, while mounted, with a unit under the mouse, with a loot window open, while
-- already fishing (so a double-click on the bobber doesn't recast), or without a rod equipped.
-- /bolt fish prints why the last right-click did or didn't arm.

local ADDON_NAME, BOLT = ...

local DoubleClickFishing = {
    displayName = "Double-Click Fishing",
}

local BUTTON_NAME = "BOLTFishingButton"
local MAX_HOLD = 0.3     -- a longer first press is turning the camera, not a click
local MAX_GAP = 0.5      -- seconds after the first click for the second one to start
local TURN_HOLD = 0.25   -- a second press held longer than this is a camera turn

-- Fishing cast spells: modern one first, then the old ranks (Classic-style clients).
local FISHING_IDS = { 131474, 7620, 7731, 7732, 18248, 33095, 51294, 88868, 110410 }
local IS_FISHING_ID = {}
for _, id in ipairs(FISHING_IDS) do IS_FISHING_ID[id] = true end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local function IsKnown(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
    return IsSpellKnown ~= nil and IsSpellKnown(id) == true
end

-- Casting by name picks the best known rank. If no ID reads as known (some clients disagree),
-- the plain "Fishing" name still casts: a rod is equipped, so the player can fish.
local function FishingSpellName()
    for _, id in ipairs(FISHING_IDS) do
        if IsKnown(id) then
            local name = SpellName(id)
            if name then return name end
        end
    end
    for _, id in ipairs(FISHING_IDS) do
        local name = SpellName(id)
        if name then return name end
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

-- nil when the cast may go ahead, else the reason it may not (for /bolt fish).
function DoubleClickFishing:BlockReason()
    if InCombatLockdown() then return "in combat" end
    if IsMounted() then return "mounted" end
    if IsFlying and IsFlying() then return "flying" end
    if UnitExists("mouseover") then return "a unit is under the mouse" end
    if GetNumLootItems() > 0 then return "loot window open" end
    if IsMouseButtonDown("LeftButton") then return "left button held" end
    if not MouseOverWorld() then return "mouse over a UI frame" end
    if IsFishing() then return "already fishing" end
    if not HasRodEquipped() then return "no fishing rod equipped" end
    if not FishingSpellName() then return "no Fishing spell found" end
end

function DoubleClickFishing:Disarm()
    self.token = (self.token or 0) + 1
    self.armed = false
    if self.button and not InCombatLockdown() then
        self.button:Hide()
    end
end

function DoubleClickFishing:Arm()
    local button = self.button
    button:SetAttribute("spell", FishingSpellName())
    button:Show()
    self.armed = true
    self.token = (self.token or 0) + 1
    local token = self.token
    C_Timer.After(MAX_GAP, function()
        -- Still up and no second press started on it: the double-click didn't come.
        if self.token == token and self.armed and not self.pressing then self:Disarm() end
    end)
end

-- First click: a quick right-click on the world. GLOBAL_MOUSE_* fire for world clicks too.
function DoubleClickFishing:OnMouseDown(mouseButton)
    if mouseButton ~= "RightButton" or self.armed then return end
    self.pressTime = GetTime()
end

function DoubleClickFishing:OnMouseUp(mouseButton)
    if mouseButton ~= "RightButton" or self.armed then return end
    local pressTime = self.pressTime
    self.pressTime = nil
    if not pressTime then return end -- e.g. the second click's release, after it cast
    if GetTime() - pressTime > MAX_HOLD then
        self.lastResult = "held too long (camera turn)"
        return
    end
    local reason = self:BlockReason()
    if reason then
        self.lastResult = "not armed: " .. reason
        return
    end
    self.lastResult = "armed, waiting for the second click"
    self:Arm()
end

-- Second press on the cover: a click casts on release; held down, it becomes a camera turn.
function DoubleClickFishing:OnCoverMouseDown(mouseButton)
    if mouseButton ~= "RightButton" then return end
    self.pressing = true
    local token = self.token
    C_Timer.After(TURN_HOLD, function()
        if self.token ~= token or not self.armed then return end
        if IsMouseButtonDown("RightButton") then
            self.pressing = false
            self.lastResult = "second press held: camera turn, no cast"
            self:Disarm()
            MouselookStart()
        end
    end)
end

function DoubleClickFishing:OnInitialize()
    -- Parentless so it also works with the UI hidden (Alt+Z); BACKGROUND keeps every UI frame
    -- above it, so it only ever covers the 3D world.
    local button = CreateFrame("Button", BUTTON_NAME, nil, "SecureActionButtonTemplate")
    button:SetFrameStrata("BACKGROUND")
    button:SetFrameLevel(0)
    button:SetAllPoints(UIParent)
    button:RegisterForClicks("RightButtonUp")
    button:SetAttribute("type", "spell")
    button:SetAttribute("useOnKeyDown", false)
    if button.SetPassThroughButtons then
        pcall(button.SetPassThroughButtons, button, "LeftButton")
    end
    button:Hide()
    -- Hide right after the cast, from secure code so it also works if combat started.
    SecureHandlerWrapScript(button, "PostClick", button, [[
        self:Hide()
    ]])
    button:HookScript("PostClick", function()
        self.pressing = false
        self.armed = false
        self.token = (self.token or 0) + 1
        self.lastResult = "cast Fishing"
    end)
    button:HookScript("OnMouseDown", function(_, mouseButton)
        self:OnCoverMouseDown(mouseButton)
    end)
    button:HookScript("OnMouseUp", function()
        -- A release that didn't make a click (e.g. left button): clean up.
        C_Timer.After(0, function()
            if self.pressing then
                self.pressing = false
                if self.armed then self:Disarm() end
            end
        end)
    end)
    button:HookScript("OnHide", function()
        self.armed = false
        self.pressing = false
    end)
    self.button = button

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "GLOBAL_MOUSE_DOWN" then
            self:OnMouseDown(...)
        elseif event == "GLOBAL_MOUSE_UP" then
            self:OnMouseUp(...)
        elseif event == "PLAYER_REGEN_DISABLED" then
            self:Disarm()
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
    self:Disarm()
end

function DoubleClickFishing:PrintDebug()
    BOLT:Print("Double-Click Fishing")
    print("  Last right-click: " .. (self.lastResult or "none seen yet"))
    print("  Right now: " .. (self:BlockReason() or "ready (would arm)"))
    print("  Spell: " .. tostring(FishingSpellName()) .. ", rod equipped: " .. tostring(HasRodEquipped()))
end

BOLT:RegisterModule("doubleClickFishing", DoubleClickFishing)
