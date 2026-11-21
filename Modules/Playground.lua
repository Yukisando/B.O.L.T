-- B.O.L.T Playground Module
-- Fun features with limited practical use: favorite toy button and copying your target's mount.
-- (The speed and FPS readouts moved to the minimap, 2026-11-21.)

local ADDON_NAME, BOLT = ...
local ButtonUtils = BOLT.ButtonUtils

local Playground = {
    displayName = "Playground",
}

local DEFAULT_TOY_ICON = "Interface\\Icons\\INV_Misc_Toy_10"

local toyButton

local function Cfg(key)
    return BOLT:GetConfig("playground", key)
end

---------------------------------------------------------------------------
-- Favorite toy
---------------------------------------------------------------------------

function Playground:CreateToyButton()
    toyButton = ButtonUtils:CreateIconButton("BOLTFavoriteToyButton", UIParent, DEFAULT_TOY_ICON, { secure = true })
    toyButton:RegisterForClicks("AnyUp", "AnyDown")
    toyButton:SetAttribute("type", "toy")
    toyButton:Hide()

    -- Runs after the secure toy action, so closing the menu can't block the cast.
    toyButton:HookScript("OnClick", function()
        if Cfg("closeGameMenuOnCast") and BOLT:IsGameMenuShown() then
            GameMenuFrame:Hide()
        end
    end)

    ButtonUtils:SetTooltip(toyButton, "ANCHOR_RIGHT", function()
        local toyID = Cfg("favoriteToyId")
        local name
        if toyID then
            name = select(2, C_ToyBox.GetToyInfo(toyID))
        end
        if name and PlayerHasToy(toyID) then
            return "Use " .. name, { { "Click to use your favorite toy" } }
        end
        return "No favorite toy selected", { { "Choose one in the B.O.L.T settings (Extras)" } }
    end)
end

-- Secure attributes can only change out of combat.
function Playground:UpdateToyButton()
    if not toyButton or not BOLT.has.toys or InCombatLockdown() then return end

    local toyID = Cfg("favoriteToyId")
    local itemID, icon
    if toyID then
        itemID, _, icon = C_ToyBox.GetToyInfo(toyID)
    end
    if itemID and PlayerHasToy(itemID) then
        toyButton:SetAttribute("toy", itemID)
        ButtonUtils:UpdateButtonIcon(toyButton, icon or C_Item.GetItemIconByID(itemID) or DEFAULT_TOY_ICON)
        local usable = not C_ToyBox.IsToyUsable or C_ToyBox.IsToyUsable(itemID)
        toyButton:SetAlpha(usable and 1 or 0.7)
        self:UpdateToyCooldown()
    else
        toyButton:SetAttribute("toy", nil)
        ButtonUtils:UpdateButtonIcon(toyButton, DEFAULT_TOY_ICON)
        toyButton:SetAlpha(0.5)
        ButtonUtils:ClearButtonCooldown(toyButton)
    end
end

function Playground:UpdateToyCooldown()
    local toyID = Cfg("favoriteToyId")
    if not (toyButton and toyID and BOLT.has.toys and PlayerHasToy(toyID)) then return end
    local startTime, duration, enabled = C_Item.GetItemCooldown(toyID)
    ButtonUtils:SetButtonCooldown(toyButton, startTime, duration, enabled)
end

-- Collected toys as { id, name, icon } sorted by name. The only toy enumeration API
-- is the Toy Box's filtered list, so its filters are opened up for the scan and
-- then put back exactly as the player had them.
function Playground:GetCollectedToys()
    local saved = {
        collected = C_ToyBox.GetCollectedShown(),
        uncollected = C_ToyBox.GetUncollectedShown(),
        unusable = C_ToyBox.GetUnusableShown(),
        search = ToyBox and ToyBox.searchBox and ToyBox.searchBox:GetText() or "",
        sources = {},
        expansions = {},
    }
    for i = 1, C_PetJournal.GetNumPetSources() do
        saved.sources[i] = C_ToyBox.IsSourceTypeFilterChecked(i)
    end
    for i = 1, GetNumExpansions() do
        saved.expansions[i] = C_ToyBox.IsExpansionTypeFilterChecked(i)
    end

    C_ToyBox.SetCollectedShown(true)
    C_ToyBox.SetUncollectedShown(false)
    C_ToyBox.SetUnusableShown(true)
    C_ToyBox.SetAllSourceTypeFilters(true)
    C_ToyBox.SetAllExpansionTypeFilters(true)
    C_ToyBox.SetFilterString("")

    local toys = {}
    for index = 1, C_ToyBox.GetNumFilteredToys() do
        local itemID = C_ToyBox.GetToyFromIndex(index)
        local _, name, icon = C_ToyBox.GetToyInfo(itemID)
        if name and PlayerHasToy(itemID) then
            table.insert(toys, { id = itemID, name = name, icon = icon })
        end
    end
    table.sort(toys, function(a, b) return a.name < b.name end)

    C_ToyBox.SetCollectedShown(saved.collected)
    C_ToyBox.SetUncollectedShown(saved.uncollected)
    C_ToyBox.SetUnusableShown(saved.unusable)
    for i, checked in pairs(saved.sources) do
        C_ToyBox.SetSourceTypeFilter(i, checked)
    end
    for i, checked in pairs(saved.expansions) do
        C_ToyBox.SetExpansionTypeFilter(i, checked)
    end
    C_ToyBox.SetFilterString(saved.search)

    return toys
end

function Playground:SetFavoriteToy(itemID)
    BOLT:SetConfig(itemID, "playground", "favoriteToyId")
    self:UpdateToyButton()
end

function Playground:OnMenuShown()
    if not (Cfg("showFavoriteToy") and BOLT.has.toys) then return end
    -- Deferred past the game menu module so its container is positioned first.
    C_Timer.After(0.05, function()
        if InCombatLockdown() or not BOLT:IsGameMenuShown() then return end
        self:UpdateToyButton()
        ButtonUtils:PositionAboveGameMenuLeft(toyButton)
    end)
end

function Playground:OnMenuHidden()
    if toyButton and not InCombatLockdown() then
        toyButton:Hide()
    end
end

---------------------------------------------------------------------------
-- Copy target mount
---------------------------------------------------------------------------

-- Midnight: aura data is secret in combat, so mount detection only runs out of combat.
function Playground:GetTargetMount()
    if not BOLT.has.mountJournal or not UnitExists("target") or InCombatLockdown() then return nil end

    for index = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("target", index, "HELPFUL")
        if not aura then break end
        if not BOLT.IsSecret(aura.spellId) then
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if mountID then
                return aura.spellId, mountID
            end
        end
    end
    return nil
end

function Playground:TryCopyTargetMount()
    if InCombatLockdown() then
        BOLT:Print("Cannot copy a mount while in combat.")
        return
    end
    if not UnitExists("target") then
        BOLT:Print("No target selected.")
        return
    end

    local spellID, mountID = self:GetTargetMount()
    if not mountID then
        BOLT:Print("Target is not on a mount.")
        return
    end

    local mountName = C_Spell.GetSpellName(spellID) or "that mount"
    local isCollected = select(11, C_MountJournal.GetMountInfoByID(mountID))
    if not isCollected then
        BOLT:Print("You don't have " .. mountName .. ".")
        return
    end

    C_MountJournal.SummonByID(mountID)
    BOLT:Print("Summoning " .. mountName .. " (copying target).")
end

local function CopyMountCommand()
    if not BOLT:IsModuleEnabled("playground") then
        BOLT:Print("The Playground module is disabled.")
    elseif not Cfg("copyTargetMount") then
        BOLT:Print("Copy Target Mount is turned off in the B.O.L.T settings (Extras).")
    else
        Playground:TryCopyTargetMount()
    end
end

function BOLT_CopyTargetMount()
    CopyMountCommand()
end

SLASH_BOLTCOPYMOUNT1 = "/copymount"
SLASH_BOLTCOPYMOUNT2 = "/cm"
SlashCmdList.BOLTCOPYMOUNT = CopyMountCommand

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Playground:OnInitialize()
    self:CreateToyButton()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" and not BOLT:IsGameMenuShown() then
            -- The secure button couldn't be hidden if the menu closed during combat.
            self:OnMenuHidden()
        end
        if event == "TOYS_UPDATED" or event == "PLAYER_REGEN_ENABLED" then
            self:UpdateToyButton()
        else
            self:UpdateToyCooldown()
        end
    end)
end

function Playground:OnEnable()
    for _, event in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" }) do
        self.eventFrame:RegisterEvent(event)
    end
    if BOLT.has.toys then
        self.eventFrame:RegisterEvent("TOYS_UPDATED")
    end
    BOLT:WatchGameMenu("playground",
        function() self:OnMenuShown() end,
        function() self:OnMenuHidden() end)

    self:UpdateToyButton()
end

function Playground:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    BOLT:UnwatchGameMenu("playground")
    self:OnMenuHidden()
end

function Playground:OnSettingChanged()
    self:UpdateToyButton()
    if BOLT:IsGameMenuShown() then
        self:OnMenuShown()
    end
end

BOLT:RegisterModule("playground", Playground)
