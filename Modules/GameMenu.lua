-- B.O.L.T Game Menu Module
-- Adds quick-access buttons around the game menu (Escape menu).

local ADDON_NAME, BOLT = ...
local ButtonUtils = BOLT.ButtonUtils

local GameMenu = {
    displayName = "Game Menu",
}

local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local DAMAGE_CVARS = {
    "floatingCombatTextCombatDamage_v2",
    "floatingCombatTextCombatLogPeriodicSpells_v2",
    "floatingCombatTextPetMeleeDamage_v2",
    "floatingCombatTextPetSpellDamage_v2",
}
local HEALING_CVARS = { "floatingCombatTextCombatHealing_v2" }
local DEFAULT_LOOT_SPEC_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local STACK_GAP = 6

local buttons = {}
local container

-- Generation counter: bumped on every show/hide so deferred work for a menu that
-- has since closed does nothing.
local showGeneration = 0

local function Cfg(key)
    return BOLT:GetConfig("gameMenu", key)
end

local function CanCommandGroup()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

local function MarkerTexCoords(index)
    local i = math.max(1, math.min(8, index)) - 1
    local left, top = (i % 4) * 0.25, math.floor(i / 4) * 0.25
    return left, left + 0.25, top, top + 0.25
end

---------------------------------------------------------------------------
-- Volume (also used by the keybinding when the module is disabled)
---------------------------------------------------------------------------

local function GetMasterVolume()
    return tonumber(GetCVar("Sound_MasterVolume")) or 1
end

local function ToggleCVar(cvar)
    local enabled = GetCVar(cvar) ~= "1"
    SetCVar(cvar, enabled and "1" or "0")
    return enabled
end

function GameMenu:ToggleMute()
    BOLTDB = BOLTDB or {}
    local volume = GetMasterVolume()
    if volume == 0 then
        local previous = BOLTDB.preMuteVolume or 0.5
        SetCVar("Sound_MasterVolume", tostring(previous))
        BOLT:Print(("Audio unmuted (%d%%)"):format(math.floor(previous * 100 + 0.5)))
    else
        -- Stored account-wide so unmuting works after a relog or on another character.
        BOLTDB.preMuteVolume = volume
        SetCVar("Sound_MasterVolume", "0")
        BOLT:Print("Audio muted")
    end
    self:UpdateVolumeDisplay()
end

function GameMenu:UpdateVolumeDisplay()
    local button = buttons.volume
    if not button then return end

    local percent = math.floor(GetMasterVolume() * 100 + 0.5)
    if percent == 0 then
        button.text:SetText("M")
        button.text:SetTextColor(1, 0.2, 0.2)
    else
        button.text:SetText(percent)
        button.text:SetTextColor(1, 1, 1)
    end
end

function BOLT_ToggleMasterVolume()
    GameMenu:ToggleMute()
end

---------------------------------------------------------------------------
-- Loot specialization
---------------------------------------------------------------------------

function GameMenu:GetLootSpecOptions()
    local options = {}
    local currentIndex = GetSpecialization()
    local _, currentName, _, currentIcon
    if currentIndex then
        _, currentName, _, currentIcon = GetSpecializationInfo(currentIndex)
    end

    table.insert(options, {
        specID = 0,
        name = currentName and ("Current Specialization (" .. currentName .. ")") or "Current Specialization",
        icon = currentIcon or DEFAULT_LOOT_SPEC_ICON,
    })
    for index = 1, GetNumSpecializations() do
        local specID, name, _, icon = GetSpecializationInfo(index)
        if specID and name then
            table.insert(options, { specID = specID, name = name, icon = icon or DEFAULT_LOOT_SPEC_ICON })
        end
    end
    return options
end

function GameMenu:GetLootSpecInfo(specID)
    for _, option in ipairs(self:GetLootSpecOptions()) do
        if option.specID == specID then
            return option
        end
    end
    return { specID = specID, name = "Loot Specialization", icon = DEFAULT_LOOT_SPEC_ICON }
end

function GameMenu:ApplyLootSpec(specID)
    SetLootSpecialization(specID)
    BOLT:Print("Loot specialization: " .. self:GetLootSpecInfo(specID).name)
end

function GameMenu:CycleLootSpec()
    local options = self:GetLootSpecOptions()
    local active = GetLootSpecialization()
    for index, option in ipairs(options) do
        if option.specID == active then
            self:ApplyLootSpec(options[index % #options + 1].specID)
            return
        end
    end
    self:ApplyLootSpec(0)
end

function GameMenu:UpdateLootSpecButton()
    local button = buttons.lootSpec
    if not button then return end

    local specID = GetLootSpecialization()
    button.icon:SetTexture(self:GetLootSpecInfo(specID).icon)
    if specID == 0 then
        button.border:SetColorTexture(0.3, 0.28, 0.24, 1)
    else
        button.border:SetColorTexture(0.95, 0.76, 0.18, 1)
    end
end

---------------------------------------------------------------------------
-- Button creation
---------------------------------------------------------------------------

local function TooltipLines(...)
    return { ... }
end

local function NeedsLeaderLine()
    if CanCommandGroup() then return nil end
    return { "Requires group leader or assistant", 1, 0.2, 0.2 }
end

function GameMenu:CreateButtons()
    local parent = container

    -- Leave group: a regular button (GameMenuButtonTemplate would inherit the secure
    -- callback mechanism and taint it).
    local leave = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    leave:SetSize(144, 28)
    leave:SetScript("OnClick", function()
        GameMenuFrame:Hide()
        C_Timer.After(0.1, function() BOLT:LeaveGroup() end)
    end)
    ButtonUtils:SetTooltip(leave, "ANCHOR_RIGHT", function()
        local groupType = BOLT:GetGroupTypeString()
        return groupType and ("Leave " .. groupType) or "Leave Group"
    end)
    buttons.leave = leave

    local reload = ButtonUtils:CreateIconButton(nil, parent, "Interface\\Icons\\inv_misc_gear_01", { contentScale = 1.3 })
    reload:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    reload:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            ReloadUI()
        elseif mouseButton == "RightButton" then
            self:OpenSettingsFromMenu()
        else
            local savedInstances = BOLT.modules.savedInstances
            if savedInstances and BOLT:IsModuleEnabled("savedInstances") then
                savedInstances:PrintUnsavedInstances()
            else
                BOLT:Print("Saved Instances module is not enabled.")
            end
        end
    end)
    ButtonUtils:SetTooltip(reload, "ANCHOR_LEFT", function()
        return "Reload UI", TooltipLines(
            { "Left-click: Reload the user interface" },
            { "Right-click: Open B.O.L.T settings" },
            { "Middle-click: Show saved instances" })
    end)
    buttons.reload = reload

    local readyCheck = ButtonUtils:CreateIconButton(nil, parent, "Interface\\RaidFrame\\ReadyCheck-Ready")
    readyCheck:SetScript("OnClick", function() self:OnReadyCheckClick() end)
    ButtonUtils:SetTooltip(readyCheck, "ANCHOR_LEFT", function()
        return "Ready Check", TooltipLines({ "Start a ready check for your group" }, NeedsLeaderLine())
    end)
    buttons.readyCheck = readyCheck

    local countdown = ButtonUtils:CreateIconButton(nil, parent, "Interface\\Icons\\Spell_Holy_BorrowedTime")
    countdown:SetScript("OnClick", function() self:OnCountdownClick() end)
    ButtonUtils:SetTooltip(countdown, "ANCHOR_LEFT", function()
        return "Countdown", TooltipLines({ "Start a 5-second pull timer" }, NeedsLeaderLine())
    end)
    buttons.countdown = countdown

    local marker = ButtonUtils:CreateIconButton(nil, parent, "Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    marker:SetScript("OnClick", function(_, mouseButton) self:OnRaidMarkerClick(mouseButton) end)
    ButtonUtils:SetTooltip(marker, "ANCHOR_LEFT", function()
        local name = MARKER_NAMES[Cfg("raidMarkerIndex")] or "none selected"
        return "Raid Marker", TooltipLines(
            { "Left-click: Mark yourself (" .. name .. ")" },
            { "Right-click: Clear your marker" })
    end)
    buttons.marker = marker

    local lootSpec = ButtonUtils:CreateIconButton(nil, parent, DEFAULT_LOOT_SPEC_ICON)
    lootSpec:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    lootSpec:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            self:ShowLootSpecMenu()
        else
            self:CycleLootSpec()
        end
    end)
    ButtonUtils:SetTooltip(lootSpec, "ANCHOR_LEFT", function()
        local specID = GetLootSpecialization()
        local status = specID == 0
            and { "Following your current specialization", 0.65, 0.82, 1 }
            or { "Loot specialization override active", 1, 0.82, 0.2 }
        return "Loot Specialization", TooltipLines(
            { "Current: " .. self:GetLootSpecInfo(specID).name, 1, 1, 0 },
            { "Left-click: Cycle to the next loot spec" },
            { "Right-click: Choose a loot spec" },
            status)
    end)
    buttons.lootSpec = lootSpec

    local volume = ButtonUtils:CreateIconButton(nil, parent, "Interface\\Icons\\Spell_Shadow_SoundDamp",
        { showBackground = true, highlightColor = { 1, 1, 0.5, 0.2 } })
    volume.text = volume:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    volume.text:SetPoint("CENTER")
    volume:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    volume:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            self:ToggleMute()
        elseif mouseButton == "RightButton" then
            BOLT:Print("Music: " .. (ToggleCVar("Sound_EnableMusic") and "ON" or "OFF"))
        else
            BOLT:Print("Dialog audio: " .. (ToggleCVar("Sound_EnableDialog") and "ON" or "OFF"))
        end
    end)
    volume:EnableMouseWheel(true)
    volume:SetScript("OnMouseWheel", function(_, delta)
        local newVolume = math.max(0, math.min(1, GetMasterVolume() + (delta > 0 and 0.05 or -0.05)))
        SetCVar("Sound_MasterVolume", tostring(newVolume))
        self:UpdateVolumeDisplay()
        BOLT.PlayHoverSound()
    end)
    ButtonUtils:SetTooltip(volume, "ANCHOR_RIGHT", function()
        local percent = math.floor(GetMasterVolume() * 100 + 0.5)
        local dialog = GetCVar("Sound_EnableDialog") ~= "0"
        return "Master Volume", TooltipLines(
            { ("Current: %d%%%s"):format(percent, percent == 0 and " (MUTED)" or ""), 1, 1, 0 },
            { "Dialog: " .. (dialog and "ON" or "OFF"), dialog and 0 or 1, dialog and 1 or 0, 0 },
            { "Left-click: Toggle mute" },
            { "Right-click: Toggle music" },
            { "Middle-click: Toggle dialog audio" },
            { "Mouse wheel: Adjust volume" })
    end)
    buttons.volume = volume

    buttons.damage = self:CreateCombatTextButton(parent, "Spell_Fire_FireBolt02", "Damage", DAMAGE_CVARS)
    buttons.healing = self:CreateCombatTextButton(parent, "Spell_Holy_GreaterHeal", "Healing", HEALING_CVARS)

    for _, button in pairs(buttons) do
        button:Hide()
    end
end

function GameMenu:CreateCombatTextButton(parent, icon, label, cvars)
    local button = ButtonUtils:CreateIconButton(nil, parent, "Interface\\Icons\\" .. icon)
    button.cvars = cvars
    button:SetScript("OnClick", function()
        local enabled = GetCVar(cvars[1]) ~= "1"
        if enabled then
            SetCVar("enableFloatingCombatText", "1")
        end
        for _, cvar in ipairs(cvars) do
            SetCVar(cvar, enabled and "1" or "0")
        end
        self:RefreshCombatTextButtons()
        BOLT:Print(label .. " numbers: " .. (enabled and "ON" or "OFF"))
    end)
    ButtonUtils:SetTooltip(button, "ANCHOR_RIGHT", function()
        local enabled = GetCVar(cvars[1]) == "1"
        return "Toggle " .. label .. " Numbers", TooltipLines(
            { "Current: " .. (enabled and "ON" or "OFF"), enabled and 0 or 1, enabled and 1 or 0, 0 },
            { "Show/hide " .. label:lower() .. " numbers in scrolling combat text" })
    end)
    return button
end

function GameMenu:RefreshCombatTextButtons()
    for _, button in ipairs({ buttons.damage, buttons.healing }) do
        button:SetAlpha(GetCVar(button.cvars[1]) == "1" and 1 or 0.6)
    end
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

function GameMenu:OnReadyCheckClick()
    if not CanCommandGroup() then
        BOLT:Print("You must be the group leader or an assistant to start a ready check.")
        return
    end
    DoReadyCheck()
end

function GameMenu:OnCountdownClick()
    if not CanCommandGroup() then
        BOLT:Print("You must be the group leader or an assistant to start a countdown.")
        return
    end
    C_PartyInfo.DoCountdown(5)
end

function GameMenu:OnRaidMarkerClick(mouseButton)
    local index = Cfg("raidMarkerIndex")
    if mouseButton == "RightButton" or index == 0 then
        SetRaidTarget("player", 0)
        BOLT:Print("Raid marker cleared.")
        return
    end
    SetRaidTarget("player", index)
    BOLT:Print("Raid marker set: " .. MARKER_NAMES[index])
end

function GameMenu:ShowLootSpecMenu()
    MenuUtil.CreateContextMenu(buttons.lootSpec, function(_, root)
        root:CreateTitle("Loot Specialization")
        for _, option in ipairs(self:GetLootSpecOptions()) do
            root:CreateRadio(option.name,
                function() return GetLootSpecialization() == option.specID end,
                function() self:ApplyLootSpec(option.specID) end)
        end
    end)
end

function GameMenu:OpenSettingsFromMenu()
    -- frame:Hide() instead of HideUIPanel: HideUIPanel writes to UIPanelWindows from
    -- addon code, and the tainted entry later stops Escape from opening the menu in combat.
    GameMenuFrame:Hide()
    self:HideAll()
    C_Timer.After(0.1, function() BOLT:OpenConfigPanel() end)
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

-- Stack visible buttons upwards from the menu's bottom corner, on the outside edge.
local function StackFromBottom(list, side)
    local anchor = container
    local point, relativePoint, x = "BOTTOMLEFT", "BOTTOMRIGHT", 8
    if side == "left" then
        point, relativePoint, x = "BOTTOMRIGHT", "BOTTOMLEFT", -8
    end

    local previous
    for _, button in ipairs(list) do
        if button:IsShown() then
            button:ClearAllPoints()
            if previous then
                button:SetPoint("BOTTOM", previous, "TOP", 0, STACK_GAP)
            else
                button:SetPoint(point, anchor, relativePoint, x, 12)
            end
            button:SetFrameLevel(anchor:GetFrameLevel() + 2)
            previous = button
        end
    end
end

function GameMenu:Refresh()
    if not (container and container:IsShown()) then return end

    local inGroup = BOLT:IsInGroup()
    local groupTools = Cfg("groupToolsEnabled")
    local showCombatText = Cfg("showBattleTextToggles") and GetCVar(DAMAGE_CVARS[1]) ~= nil

    buttons.leave:SetShown(Cfg("showLeaveGroup") and inGroup)
    buttons.volume:SetShown(Cfg("showVolumeButton"))
    buttons.damage:SetShown(showCombatText)
    buttons.healing:SetShown(showCombatText)
    buttons.lootSpec:SetShown(Cfg("showLootSpecButton") and GetNumSpecializations() > 0)
    buttons.marker:SetShown(groupTools)
    buttons.readyCheck:SetShown(groupTools and inGroup)
    buttons.countdown:SetShown(groupTools and inGroup)

    local groupType = BOLT:GetGroupTypeString()
    buttons.leave:SetText(groupType and ("Leave " .. groupType) or "Leave Group")
    buttons.leave:ClearAllPoints()
    buttons.leave:SetPoint("BOTTOM", container, "TOP", 0, 10)
    ButtonUtils:PositionAboveGameMenuRight(buttons.reload)
    buttons.reload:SetShown(Cfg("showReloadButton"))

    local canCommand = CanCommandGroup()
    for _, button in ipairs({ buttons.readyCheck, buttons.countdown }) do
        button:SetEnabled(canCommand)
        button:SetAlpha(canCommand and 1 or 0.4)
    end

    local markerIndex = Cfg("raidMarkerIndex")
    buttons.marker.icon:SetTexCoord(MarkerTexCoords(markerIndex > 0 and markerIndex or 1))
    buttons.marker:SetAlpha(markerIndex > 0 and 1 or 0.5)

    self:UpdateVolumeDisplay()
    self:UpdateLootSpecButton()
    if showCombatText then
        self:RefreshCombatTextButtons()
    end

    StackFromBottom({ buttons.lootSpec, buttons.readyCheck, buttons.countdown, buttons.marker }, "right")
    StackFromBottom({ buttons.volume, buttons.healing, buttons.damage }, "left")
end

function GameMenu:HideAll()
    showGeneration = showGeneration + 1
    if container then
        container:Hide()
    end
end

function GameMenu:OnMenuShown()
    showGeneration = showGeneration + 1
    local generation = showGeneration

    -- Deferred: positioning work must not run inside ShowUIPanel's secure call chain.
    C_Timer.After(0, function()
        if generation ~= showGeneration or not BOLT:IsGameMenuShown() then return end

        -- The container mirrors the menu's rectangle so our widgets can anchor to it
        -- without anchoring anything to the protected GameMenuFrame itself.
        container:ClearAllPoints()
        container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", GameMenuFrame:GetLeft(), GameMenuFrame:GetBottom())
        container:SetSize(GameMenuFrame:GetWidth(), GameMenuFrame:GetHeight())
        container:Show()
        self:Refresh()
    end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function GameMenu:OnInitialize()
    container = CreateFrame("Frame", "BOLTGameMenuContainer", UIParent)
    container:SetFrameStrata("DIALOG")
    container:Hide()
    self:CreateButtons()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, name)
        if event == "CVAR_UPDATE" and not (name and (name:find("^Sound_") or name:find("^floatingCombatText"))) then
            return
        end
        self:Refresh()
    end)
end

function GameMenu:OnEnable()
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED", "PLAYER_ROLES_ASSIGNED",
        "PLAYER_LOOT_SPEC_UPDATED", "PLAYER_SPECIALIZATION_CHANGED", "CVAR_UPDATE" }) do
        self.eventFrame:RegisterEvent(event)
    end
    BOLT:WatchGameMenu("gameMenu",
        function() self:OnMenuShown() end,
        function() self:HideAll() end)
    if BOLT:IsGameMenuShown() then
        self:OnMenuShown()
    end
end

function GameMenu:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    BOLT:UnwatchGameMenu("gameMenu")
    self:HideAll()
end

-- Settings changed while the menu is open.
function GameMenu:OnSettingChanged()
    self:Refresh()
end

BOLT:RegisterModule("gameMenu", GameMenu)
