-- B.O.L.T Game Menu Module
-- Adds quality of life improvements to the game menu

local ADDON_NAME, BOLT = ...

-- Create the GameMenu module
local GameMenu = {}

-- Helper: return the parent frame we should use for menu widgets (container if present)
function GameMenu:GetMenuParent()
    return self.menuContainer or UIParent
end

-- Helper: return the anchor frame to use for positioning (prefer our container, fall back to GameMenuFrame)
function GameMenu:GetMenuAnchor()
    return self.menuContainer or GameMenuFrame
end

-- Reusable raid target texture coordinates (4x4 sprite sheet)
local MARKER_TEXCOORDS = {
    [1] = { 0, 0.25, 0, 0.25 },     -- Star
    [2] = { 0.25, 0.5, 0, 0.25 },   -- Circle
    [3] = { 0.5, 0.75, 0, 0.25 },   -- Diamond
    [4] = { 0.75, 1, 0, 0.25 },     -- Triangle
    [5] = { 0, 0.25, 0.25, 0.5 },   -- Moon
    [6] = { 0.25, 0.5, 0.25, 0.5 }, -- Square
    [7] = { 0.5, 0.75, 0.25, 0.5 }, -- Cross
    [8] = { 0.75, 1, 0.25, 0.5 },   -- Skull
}
local function GetMarkerTexCoords(i)
    return unpack(MARKER_TEXCOORDS[i] or MARKER_TEXCOORDS[1])
end

-- Reference to the Leave Group button
local leaveGroupButton = nil
-- Reference to the Reload UI button
local reloadButton = nil
-- Group tools buttons
local readyCheckButton = nil
local countdownButton = nil
local raidMarkerButton = nil
-- Battle text toggle buttons
local damageNumbersButton = nil
local healingNumbersButton = nil
-- Volume control button
local volumeButton = nil
-- Loot specialization button
local lootSpecButton = nil

-- Battle text console variable names (v2 API)
local DAMAGE_CONSOLE_VARS = {
    "floatingCombatTextCombatDamage_v2",
    "floatingCombatTextCombatLogPeriodicSpells_v2",
    "floatingCombatTextPetMeleeDamage_v2",
    "floatingCombatTextPetSpellDamage_v2",
}
local HEALING_CONSOLE_VARS = {
    "floatingCombatTextCombatHealing_v2",
}
local DEFAULT_LOOT_SPEC_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local GetLootSpec = GetLootSpecialization or (C_SpecializationInfo and C_SpecializationInfo.GetLootSpecialization)
local SetLootSpec = SetLootSpecialization or (C_SpecializationInfo and C_SpecializationInfo.SetLootSpecialization)

-- Generation counter: incremented on each OnShow, checked by deferred callbacks
-- to prevent stale timers from re-showing widgets after the menu has closed.
local showGeneration = 0

-- Utility: perform a protected call and surface a friendly message on error
function GameMenu:SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then
        if self.parent and self.parent.Print then
            self.parent:Print("B.O.L.T: prevented restricted UI action: " .. tostring(res))
        end
        return nil, res
    end
    return res
end

function GameMenu:SafeHideUIPanel(frame)
    if not frame then return end
    -- Do NOT call HideUIPanel(frame) from addon code. HideUIPanel writes to the
    -- UIPanelWindows management table in the non-secure (addon) execution context,
    -- tainting that table entry. The secure ESC-key binding then calls
    -- ShowUIPanel(GameMenuFrame) in combat, reads the tainted entry, and silently
    -- fails -- preventing the game menu from opening in combat with no error.
    -- Calling frame:Hide() directly hides the frame without touching UIPanelWindows,
    -- so the panel management state remains clean for secure callers.
    self:SafeCall(frame.Hide, frame)
end

function GameMenu:SafeShowUIPanel(frame)
    if not frame then return end
    self:SafeCall(ShowUIPanel, frame)
end

function GameMenu:SafeReloadUI()
    self:SafeCall(ReloadUI)
end

function GameMenu:SafeDoReadyCheck()
    self:SafeCall(DoReadyCheck)
end

function GameMenu:SafeDoCountdown(seconds)
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        self:SafeCall(C_PartyInfo.DoCountdown, seconds)
    end
end

function GameMenu:SafeSetRaidTarget(unit, idx)
    if not SetRaidTarget then return end
    self:SafeCall(SetRaidTarget, unit, idx)
end

function GameMenu:EnsureMenuContainer()
    if not self.menuContainer then
        local c = CreateFrame("Frame", "BOLTGameMenuContainer", UIParent)
        c:SetFrameStrata("LOW")
        -- Use a fallback position; actual anchoring to GameMenuFrame is deferred
        -- to avoid calling the protected SetAllPoints during ShowUIPanel's secure path.
        c:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        c:SetSize(100, 100)
        c:Hide()
        self.menuContainer = c
    end

    -- Reparent existing buttons so they follow the container visibility and anchoring
    local _buttons = { leaveGroupButton, reloadButton, readyCheckButton, countdownButton, raidMarkerButton,
        damageNumbersButton, healingNumbersButton, volumeButton, lootSpecButton }
    for _, btn in ipairs(_buttons) do
        if btn and btn:GetParent() ~= self.menuContainer then
            btn:SetParent(self.menuContainer)
        end
    end
end

function GameMenu:OnInitialize()
    -- Module initialization
end

function GameMenu:OnEnable()
    -- Hook into the game menu show event
    self:HookGameMenu()

    -- Ensure our container exists so buttons created while the menu is closed are parented correctly
    self:EnsureMenuContainer()

    -- group-state watcher
    if not self.groupUpdateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("GROUP_ROSTER_UPDATE")
        f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
        f:RegisterEvent("PARTY_LEADER_CHANGED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED")
        f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        f:SetScript("OnEvent", function()
            if GameMenuFrame and GameMenuFrame:IsShown() then
                self:RefreshGroupToolsState()
                self:UpdateLootSpecButtonDisplay()
            end
        end)
        self.groupUpdateFrame = f
    end

    -- Watch for loading completion (and world entry) so we can verify the Game Menu state
    if not self.loadCheckFrame then
        local lf = CreateFrame("Frame")
        lf:RegisterEvent("LOADING_SCREEN_DISABLED")
        lf:RegisterEvent("PLAYER_ENTERING_WORLD")
        lf:SetScript("OnEvent", function()
            -- Defer slightly to avoid race conditions with Blizzard's loading handlers
            C_Timer.After(0.01, function()
                if self and self.EnsureHiddenIfMenuNotShown then
                    self:EnsureHiddenIfMenuNotShown()
                end
            end)
        end)
        self.loadCheckFrame = lf
    end

end

function GameMenu:OnDisable()
    -- Clean up buttons when disabling
    if leaveGroupButton then
        leaveGroupButton:Hide()
        leaveGroupButton = nil
    end
    if reloadButton then
        reloadButton:Hide()
        reloadButton = nil
    end
    if readyCheckButton then
        readyCheckButton:Hide()
        readyCheckButton = nil
    end
    if countdownButton then
        countdownButton:Hide()
        countdownButton = nil
    end
    if raidMarkerButton then
        raidMarkerButton:Hide()
        raidMarkerButton = nil
    end
    if damageNumbersButton then
        damageNumbersButton:Hide()
        damageNumbersButton = nil
    end
    if healingNumbersButton then
        healingNumbersButton:Hide()
        healingNumbersButton = nil
    end
    if volumeButton then
        volumeButton:Hide()
        volumeButton = nil
    end
    if lootSpecButton then
        lootSpecButton:Hide()
        lootSpecButton = nil
    end

    -- Clean up group update frame
    if self.groupUpdateFrame then
        self.groupUpdateFrame:UnregisterAllEvents()
        self.groupUpdateFrame:SetScript("OnEvent", nil)
        self.groupUpdateFrame = nil
    end
    -- Clean up CVAR watcher if present
    if self.cvarWatcher then
        self.cvarWatcher:UnregisterAllEvents()
        self.cvarWatcher:SetScript("OnEvent", nil)
        self.cvarWatcher = nil
    end

    -- Clean up our menu container if present
    if self.menuContainer then
        self.menuContainer:Hide()
        self.menuContainer = nil
    end

    -- Clean up loading check frame if present
    if self.loadCheckFrame then
        self.loadCheckFrame:UnregisterAllEvents()
        self.loadCheckFrame:SetScript("OnEvent", nil)
        self.loadCheckFrame = nil
    end

    if self.menuVisibilityWatcher then
        self.menuVisibilityWatcher:SetScript("OnUpdate", nil)
        self.menuVisibilityWatcher = nil
    end
end

-- Ensure all menu widgets are hidden when the Game Menu is not shown (used after loading screens / reloads)
function GameMenu:EnsureHiddenIfMenuNotShown()
    if GameMenuFrame and GameMenuFrame:IsShown() then
        return
    end

    -- Hide the individual widgets (mirrors OnHide behavior)
    self:HideLeaveGroupButton()
    self:HideReloadButton()
    self:HideGroupTools()
    self:HideBattleTextToggles()
    self:HideVolumeButton()
    self:HideLootSpecButton()

    -- Clean up CVAR watcher if present
    if self.cvarWatcher then
        self.cvarWatcher:UnregisterAllEvents()
        self.cvarWatcher:SetScript("OnEvent", nil)
        self.cvarWatcher = nil
    end

    -- Hide our container if present
    if self.menuContainer then
        self.menuContainer:Hide()
    end
end

function GameMenu:HandleMenuShown()
    if self.suppressOnShow then
        C_Timer.After(0.25, function()
            if self then self.suppressOnShow = nil end
        end)
        return
    end

    if self.settingsPanelOpen then
        return
    end

    showGeneration = showGeneration + 1
    local gen = showGeneration

    self:EnsureMenuContainer()

    C_Timer.After(0.01, function()
        if gen ~= showGeneration then return end
        if self.menuContainer and GameMenuFrame and GameMenuFrame:IsShown() then
            self.menuContainer:ClearAllPoints()
            self.menuContainer:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
                GameMenuFrame:GetLeft(), GameMenuFrame:GetBottom())
            self.menuContainer:SetSize(GameMenuFrame:GetWidth(), GameMenuFrame:GetHeight())
            self.menuContainer:Show()
        end
    end)

    C_Timer.After(0.05, function()
        if gen ~= showGeneration then return end
        if GameMenuFrame and GameMenuFrame:IsShown() then
            self:UpdateGameMenu()
        end
    end)

    if not self.cvarWatcher then
        local f = CreateFrame("Frame")
        f:RegisterEvent("CVAR_UPDATE")
        f:SetScript("OnEvent", function(_, _, name)
            if name == "Sound_MasterVolume" or name == "Sound_EnableMusic" or name == "Sound_EnableDialog" then
                self:UpdateVolumeDisplay()
            elseif name == "floatingCombatTextCombatDamage_v2" or name == "floatingCombatTextCombatHealing_v2" then
                self:RefreshBattleTextTogglesState()
            end
        end)
        self.cvarWatcher = f
    end
end

function GameMenu:HandleMenuHidden()
    showGeneration = showGeneration + 1

    self:HideLeaveGroupButton()
    self:HideReloadButton()
    self:HideGroupTools()
    self:HideBattleTextToggles()
    self:HideVolumeButton()
    self:HideLootSpecButton()

    if self.menuContainer then
        self.menuContainer:Hide()
    end

    if self.cvarWatcher then
        self.cvarWatcher:UnregisterEvent("CVAR_UPDATE")
        self.cvarWatcher:SetScript("OnEvent", nil)
        self.cvarWatcher = nil
    end

end

function GameMenu:HookGameMenu()
    if self.menuVisibilityWatcher or not GameMenuFrame then
        return
    end

    local watcher = CreateFrame("Frame")
    watcher.elapsed = 0
    watcher.lastShown = GameMenuFrame:IsShown()
    watcher:SetScript("OnUpdate", function(frame, elapsed)
        frame.elapsed = frame.elapsed + elapsed
        if frame.elapsed < 0.05 then
            return
        end
        frame.elapsed = 0

        if not GameMenuFrame then
            return
        end

        local isShown = GameMenuFrame:IsShown()
        if isShown == frame.lastShown then
            return
        end

        frame.lastShown = isShown
        if isShown then
            self:HandleMenuShown()
        else
            self:HandleMenuHidden()
        end
    end)
    self.menuVisibilityWatcher = watcher
end

function GameMenu:UpdateGameMenu()
    if not self.parent:IsModuleEnabled("gameMenu") then
        return
    end

    -- Volume button - MUST be created/positioned BEFORE battle text toggles
    -- because battle text toggles position relative to volume button
    if self.parent:GetConfig("gameMenu", "showVolumeButton") then
        if not volumeButton then
            self:CreateVolumeButton()
        end
        if volumeButton then
            volumeButton:Show()
            self:PositionVolumeButton()
            self:UpdateVolumeDisplay()
        end
    else
        if volumeButton then
            volumeButton:Hide()
        end
    end

    -- Battle text toggles
    if self.parent:GetConfig("gameMenu", "showBattleTextToggles") then
        self:ShowBattleTextToggles()
    else
        self:HideBattleTextToggles()
    end

    -- Show reload button if enabled and staged back on
    if self.parent:GetConfig("gameMenu", "showReloadButton") then
        self:ShowReloadButton()
    else
        self:HideReloadButton()
    end

    -- Check if player is in a group for leave group button
    if self.parent:GetConfig("gameMenu", "showLeaveGroup") and self.parent:IsInGroup() then
        self:ShowLeaveGroupButton()
    else
        self:HideLeaveGroupButton()
    end

    if self.parent:GetConfig("gameMenu", "showLootSpecButton") and self:CanShowLootSpecButton() then
        self:ShowLootSpecButton()
    else
        self:HideLootSpecButton()
    end

    -- Group tools (ready check, countdown, raid marker)
    -- Show raid marker whenever group tools are enabled; ready check and countdown
    -- will be shown only when the player is in a group.
    if self.parent:GetConfig("gameMenu", "groupToolsEnabled") then
        self:ShowGroupTools()
    else
        self:HideGroupTools()
    end
end

function GameMenu:ShowLeaveGroupButton()
    -- Create the button if it doesn't exist
    if not leaveGroupButton then
        self:CreateLeaveGroupButton()
    end

    -- Update button text and show it
    local groupType = self.parent:GetGroupTypeString()
    if groupType and leaveGroupButton then
        leaveGroupButton:SetText("Leave " .. groupType)
        leaveGroupButton:Show()
        -- Position the button
        self:PositionLeaveGroupButton()
    end
end

function GameMenu:HideLeaveGroupButton()
    if leaveGroupButton then
        leaveGroupButton:Hide()
    end
end

function GameMenu:ShowReloadButton()
    -- Create the button if it doesn't exist
    if not reloadButton then
        self:CreateReloadButton()
    end

    if reloadButton then reloadButton:Show() end
    self:PositionReloadButton()
end

function GameMenu:HideReloadButton()
    if reloadButton then
        reloadButton:Hide()
    end
end

function GameMenu:ShowGroupTools()
    if not readyCheckButton then
        self:CreateReadyCheckButton()
    end
    if not countdownButton then
        self:CreateCountdownButton()
    end
    if not raidMarkerButton then
        self:CreateRaidMarkerButton()
    end

    -- Show raid marker always when group tools are enabled.
    if raidMarkerButton then raidMarkerButton:Show() end

    -- Only show ready check and countdown when the user is in a group
    if self.parent:IsInGroup() then
        if readyCheckButton then readyCheckButton:Show() end
        if countdownButton then countdownButton:Show() end
    else
        if readyCheckButton then readyCheckButton:Hide() end
        if countdownButton then countdownButton:Hide() end
    end

    self:PositionGroupTools()
    self:RefreshGroupToolsState()
end

function GameMenu:HideGroupTools()
    if readyCheckButton then readyCheckButton:Hide() end
    if countdownButton then countdownButton:Hide() end
    if raidMarkerButton then raidMarkerButton:Hide() end
end

function GameMenu:ShowBattleTextToggles()
    if not damageNumbersButton then
        self:CreateDamageNumbersButton()
    end
    if not healingNumbersButton then
        self:CreateHealingNumbersButton()
    end

    if damageNumbersButton then damageNumbersButton:Show() end
    if healingNumbersButton then healingNumbersButton:Show() end

    self:PositionBattleTextToggles()
    self:RefreshBattleTextTogglesState()
end

function GameMenu:HideBattleTextToggles()
    if damageNumbersButton then damageNumbersButton:Hide() end
    if healingNumbersButton then healingNumbersButton:Hide() end
    -- do NOT hide volumeButton here
end

function GameMenu:HideVolumeButton()
    if volumeButton then
        volumeButton:Hide()
    end
end

function GameMenu:CanShowLootSpecButton()
    return GetNumSpecializations and GetNumSpecializations() > 0
end

function GameMenu:GetLootSpecOptions()
    local options = {}
    local currentSpecName, currentSpecIcon
    local currentSpecIndex = GetSpecialization and GetSpecialization()

    if currentSpecIndex then
        local _, name, _, icon = GetSpecializationInfo(currentSpecIndex)
        currentSpecName = name
        currentSpecIcon = icon
    end

    table.insert(options, {
        specID = 0,
        name = currentSpecName and ("Current Specialization (" .. currentSpecName .. ")") or "Current Specialization",
        icon = currentSpecIcon or DEFAULT_LOOT_SPEC_ICON,
    })

    local numSpecs = GetNumSpecializations and GetNumSpecializations() or 0
    for index = 1, numSpecs do
        local specID, name, _, icon = GetSpecializationInfo(index)
        if specID and name then
            table.insert(options, {
                specID = specID,
                name = name,
                icon = icon or DEFAULT_LOOT_SPEC_ICON,
            })
        end
    end

    return options
end

function GameMenu:GetLootSpecInfo(specID)
    local resolvedSpecID = specID or 0
    for _, option in ipairs(self:GetLootSpecOptions()) do
        if option.specID == resolvedSpecID then
            return option.name, option.icon, resolvedSpecID == 0
        end
    end

    return "Loot Specialization", DEFAULT_LOOT_SPEC_ICON, resolvedSpecID == 0
end

function GameMenu:UpdateLootSpecButtonDisplay()
    if not lootSpecButton then
        return
    end

    local specID = GetLootSpec and GetLootSpec() or 0
    local label, icon, isCurrentSpec = self:GetLootSpecInfo(specID)

    if lootSpecButton.icon then
        lootSpecButton.icon:SetTexture(icon or DEFAULT_LOOT_SPEC_ICON)
    end
    if lootSpecButton.border then
        if isCurrentSpec then
            lootSpecButton.border:SetColorTexture(0.3, 0.28, 0.24, 1.0)
        else
            lootSpecButton.border:SetColorTexture(0.95, 0.76, 0.18, 1.0)
        end
    end

    lootSpecButton.currentLabel = label
    lootSpecButton.currentSpecID = specID
end

function GameMenu:CreateLootSpecButton()
    local mod = self
    lootSpecButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(), DEFAULT_LOOT_SPEC_ICON)
    lootSpecButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    lootSpecButton:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            mod:ShowLootSpecMenu()
        else
            mod:CycleLootSpec()
        end
    end)
    lootSpecButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(lootSpecButton, "ANCHOR_LEFT")
        local specID = GetLootSpec and GetLootSpec() or 0
        local label, _, isCurrentSpec = mod:GetLootSpecInfo(specID)
        GameTooltip:SetText("Loot Specialization", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. label, 1, 1, 0, true)
        GameTooltip:AddLine("Left-click: Cycle to the next loot spec", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click: Choose a loot spec", 0.8, 0.8, 0.8, true)
        if isCurrentSpec then
            GameTooltip:AddLine("Following your current specialization", 0.65, 0.82, 1, true)
        else
            GameTooltip:AddLine("Loot specialization override active", 1, 0.82, 0.2, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    lootSpecButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    self:UpdateLootSpecButtonDisplay()
end

function GameMenu:PositionLootSpecButton()
    if not lootSpecButton then
        return
    end

    lootSpecButton:ClearAllPoints()
    local anchor = self:GetMenuAnchor()
    if anchor and anchor.IsAnchoringSecret and anchor:IsAnchoringSecret() then
        return
    end
    if anchor then
        lootSpecButton:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 12)
        lootSpecButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
    end
end

function GameMenu:ShowLootSpecButton()
    if not self:CanShowLootSpecButton() then
        self:HideLootSpecButton()
        return
    end

    if not lootSpecButton then
        self:CreateLootSpecButton()
    end

    if lootSpecButton then
        lootSpecButton:Show()
        self:UpdateLootSpecButtonDisplay()
        self:PositionLootSpecButton()
    end
end

function GameMenu:HideLootSpecButton()
    if lootSpecButton then
        lootSpecButton:Hide()
    end
end

function GameMenu:ApplyLootSpec(specID)
    if not SetLootSpec then
        self.parent:Print("Loot specialization is not available on this character.")
        return
    end

    local ok, err = pcall(SetLootSpec, specID or 0)
    if not ok then
        self.parent:Print("Could not change loot specialization: " .. tostring(err))
        return
    end

    self:UpdateLootSpecButtonDisplay()
    local label = self:GetLootSpecInfo(specID)
    self.parent:Print("Loot specialization: " .. label)
end

function GameMenu:CycleLootSpec()
    local options = self:GetLootSpecOptions()
    if #options <= 1 then
        self.parent:Print("No loot specialization choices are available yet.")
        return
    end

    local activeSpecID = GetLootSpec and GetLootSpec() or 0
    local activeIndex = 1
    for index, option in ipairs(options) do
        if option.specID == activeSpecID then
            activeIndex = index
            break
        end
    end

    local nextOption = options[(activeIndex % #options) + 1]
    self:ApplyLootSpec(nextOption.specID)
end

function GameMenu:ShowLootSpecMenu()
    if not lootSpecButton then
        return
    end
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        self:CycleLootSpec()
        return
    end

    local mod = self
    MenuUtil.CreateContextMenu(lootSpecButton, function(_, rootDescription)
        rootDescription:CreateTitle("Loot Specialization")
        for _, option in ipairs(mod:GetLootSpecOptions()) do
            local entry = option
            rootDescription:CreateRadio(entry.name,
                function()
                    return (GetLootSpec and GetLootSpec() or 0) == entry.specID
                end,
                function()
                    mod:ApplyLootSpec(entry.specID)
                end
            )
        end
    end)
end

function GameMenu:CreateLeaveGroupButton()
    local mod = self
    -- Parent to our container if available to allow grouped visibility control
    -- NOTE: Do NOT use GameMenuButtonTemplate here. That template uses GameMenuButtonMixin
    -- whose OnClick calls self.callback(self) — a protected function. Setting our own
    -- OnClick script taints that callback slot, causing ADDON_ACTION_FORBIDDEN every time
    -- Blizzard's secure handler fires. UIPanelButtonTemplate is visually equivalent and
    -- does not carry the GameMenuButtonMixin callback mechanism.
    leaveGroupButton = CreateFrame("Button", nil, self:GetMenuParent(), "UIPanelButtonTemplate")
    leaveGroupButton:SetSize(144, 28)
    leaveGroupButton:SetText("Leave Group")
    leaveGroupButton:SetScript("OnClick", function() mod:OnLeaveGroupClick() end)
    leaveGroupButton:SetMotionScriptsWhileDisabled(true)
    leaveGroupButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(leaveGroupButton, "ANCHOR_RIGHT")
        local groupType = mod.parent:GetGroupTypeString()
        GameTooltip:SetText(groupType and ("Leave " .. groupType) or "Leave Group", 1, 1, 1)
        if UnitIsGroupLeader("player") then
            GameTooltip:AddLine("Leadership will be transferred automatically", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    leaveGroupButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:PositionLeaveGroupButton()
    if not leaveGroupButton then
        return
    end

    -- Clear any existing anchor points
    leaveGroupButton:ClearAllPoints()

    -- Position the button below the entire GameMenuFrame (using our container/anchor)
    do
        local anchor = self:GetMenuAnchor()
        if anchor then
            leaveGroupButton:SetPoint("BOTTOM", anchor, "TOP", 0, 10)
            leaveGroupButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
        end
    end

    -- Ensure the button is clickable and visible
    leaveGroupButton:EnableMouse(true)
    leaveGroupButton:Show()
end

function GameMenu:CreateReadyCheckButton()
    local mod = self
    readyCheckButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(),
        "Interface\\RaidFrame\\ReadyCheck-Ready")
    readyCheckButton:SetScript("OnClick", function()
        mod:OnReadyCheckClick()
    end)
    readyCheckButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(readyCheckButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Ready Check", 1, 1, 1)
        GameTooltip:AddLine("Start a ready check for your group", 0.8, 0.8, 0.8, true)
        if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:AddLine("Requires group leader or assistant", 1, 0.2, 0.2, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    readyCheckButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateCountdownButton()
    local mod = self
    countdownButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(),
        "Interface\\Icons\\Spell_Holy_BorrowedTime")
    countdownButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    countdownButton:SetScript("OnClick", function()
        mod:OnCountdownClick()
    end)
    countdownButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(countdownButton, "ANCHOR_LEFT")
        GameTooltip:SetText("Countdown", 1, 1, 1)
        GameTooltip:AddLine("Start a 5-second pull timer", 0.8, 0.8, 0.8, true)
        if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:AddLine("Requires group leader or assistant", 1, 0.2, 0.2, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    countdownButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateRaidMarkerButton()
    local mod = self
    raidMarkerButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(),
        "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
    -- We'll adjust tex coords based on selected marker in RefreshGroupToolsState
    raidMarkerButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    raidMarkerButton:SetScript("OnClick", function(_, button)
        mod:OnRaidMarkerClick(button)
    end)
    raidMarkerButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(raidMarkerButton, "ANCHOR_LEFT")
        local idx = mod.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
        local names = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
        GameTooltip:SetText("Raid Marker", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Set your own marker (" .. (names[idx] or "Unknown") .. ")", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click: Clear your marker", 0.8, 0.8, 0.8, true)
        -- Inform the user when they are in a group but are not leader/assist; solo players can set their own marker
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    raidMarkerButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateDamageNumbersButton()
    local mod = self
    damageNumbersButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(),
        "Interface\\Icons\\Spell_Fire_FireBolt02")
    damageNumbersButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    damageNumbersButton:SetScript("OnClick", function()
        mod:OnDamageNumbersClick()
    end)
    damageNumbersButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(damageNumbersButton, "ANCHOR_RIGHT")
        local enabled = GetCVar("floatingCombatTextCombatDamage_v2") == "1"
        GameTooltip:SetText("Toggle Damage Numbers", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. (enabled and "ON" or "OFF"), enabled and 0.0 or 1.0, enabled and 1.0 or 0.0,
            0.0, true)
        GameTooltip:AddLine("Show/hide damage numbers in scrolling combat text", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    damageNumbersButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateHealingNumbersButton()
    local mod = self
    healingNumbersButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(),
        "Interface\\Icons\\Spell_Holy_GreaterHeal")
    healingNumbersButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    healingNumbersButton:SetScript("OnClick", function()
        mod:OnHealingNumbersClick()
    end)
    healingNumbersButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(healingNumbersButton, "ANCHOR_RIGHT")
        local enabled = GetCVar("floatingCombatTextCombatHealing_v2") == "1"
        GameTooltip:SetText("Toggle Healing Numbers", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. (enabled and "ON" or "OFF"), enabled and 0.0 or 1.0, enabled and 1.0 or 0.0,
            0.0, true)
        GameTooltip:AddLine("Show/hide healing numbers in scrolling combat text", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    healingNumbersButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateVolumeButton()
    local mod = self
    -- Create volume button with background using ButtonUtils
    volumeButton = BOLT.ButtonUtils:CreateVolumeButton(nil, self:GetMenuParent(), {
        showBackground = true
    })

    -- Add volume display text overlay - properly centered
    volumeButton.volumeText = volumeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    volumeButton.volumeText:SetPoint("CENTER", volumeButton, "CENTER", 0, 0)
    volumeButton.volumeText:SetTextColor(1, 1, 1)
    volumeButton.volumeText:SetJustifyH("CENTER")
    volumeButton.volumeText:SetWidth(28) -- Match button width
    volumeButton.volumeText:SetScale(1)  -- Smaller scale to fit nicely

    -- Left click for mute/unmute, right click for music toggle, middle click for dialog toggle
    volumeButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            mod:OnVolumeButtonLeftClick()
        elseif button == "RightButton" then
            mod:OnVolumeButtonRightClick()
        elseif button == "MiddleButton" then
            mod:OnVolumeButtonMiddleClick()
        end
    end)

    -- Enable left, right, and middle-click
    volumeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    volumeButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(volumeButton, "ANCHOR_RIGHT")
        local masterVolume = GetCVar("Sound_MasterVolume") or "1"
        local volumePercent = math.floor(tonumber(masterVolume) * 100)
        local isMuted = volumePercent == 0
        GameTooltip:SetText("Master Volume", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. volumePercent .. "%" .. (isMuted and " (MUTED)" or ""), 1, 1, 0, true)
        local dialogEnabled = GetCVar("Sound_EnableDialog") ~= "0"
        GameTooltip:AddLine("Dialog: " .. (dialogEnabled and "ON" or "OFF"), dialogEnabled and 0.0 or 1.0, dialogEnabled and 1.0 or 0.0, 0.0, true)
        GameTooltip:AddLine("Left-click: Toggle mute", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click: Toggle music", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Middle-click: Toggle dialog audio", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Mouse wheel: Adjust volume", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)

    volumeButton:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)

    -- Mouse wheel support for volume adjustment
    volumeButton:EnableMouseWheel(true)
    volumeButton:SetScript("OnMouseWheel", function(_, delta)
        local vol = tonumber(GetCVar("Sound_MasterVolume")) or 1
        local step = 0.05
        local newVol = math.max(0, math.min(1, vol + (delta > 0 and step or -step)))
        mod:SafeCall(SetCVar, "Sound_MasterVolume", tostring(newVol))
        mod:UpdateVolumeDisplay()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    -- Initialize volume display
    mod:UpdateVolumeDisplay()
end

function GameMenu:PositionVolumeButton()
    if not volumeButton then return end

    volumeButton:ClearAllPoints()
    -- Position volume button to the left of the GameMenuFrame (outside the frame)
    do
        local anchor = self:GetMenuAnchor()
        if anchor then
            volumeButton:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -8, 12)
            local level = (anchor.GetFrameLevel and anchor:GetFrameLevel() or 0)
            volumeButton:SetFrameLevel(level + 2)
        end
    end
end

function GameMenu:PositionGroupTools()
    -- Position group tool buttons dynamically depending on which are visible.
    -- The buttons should anchor to the outside of the GameMenuFrame on the right
    -- and stack upwards if more than one is present. The bottom-most button is
    -- anchored to GameMenuFrame BOTTOMRIGHT.
    if not raidMarkerButton then return end

    -- Clear points for all buttons if they exist
    raidMarkerButton:ClearAllPoints()
    if countdownButton then countdownButton:ClearAllPoints() end
    if readyCheckButton then readyCheckButton:ClearAllPoints() end

    local anchor = self:GetMenuAnchor()
    -- If the anchor's anchoring data is secret, bail out to avoid secret-related errors
    if anchor and anchor.IsAnchoringSecret and anchor:IsAnchoringSecret() then return end
    local level = (anchor and anchor.GetFrameLevel and anchor:GetFrameLevel() or 0)

    -- If only raid marker is visible, anchor it at the bottom
    if raidMarkerButton:IsShown() and
        (not countdownButton or not countdownButton:IsShown()) and
        (not readyCheckButton or not readyCheckButton:IsShown()) then
        if lootSpecButton and lootSpecButton:IsShown() then
            raidMarkerButton:SetPoint("BOTTOMLEFT", lootSpecButton, "TOPLEFT", 0, 6)
            raidMarkerButton:SetFrameLevel((lootSpecButton.GetFrameLevel and lootSpecButton:GetFrameLevel() or level) + 2)
        elseif anchor then
            raidMarkerButton:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 12)
            raidMarkerButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
        end
        return
    end

    -- If countdown exists and is visible but readyCheck may be missing
    if countdownButton and countdownButton:IsShown() and
        (not readyCheckButton or not readyCheckButton:IsShown()) then
        -- countdown is bottom, raid marker above it
        if lootSpecButton and lootSpecButton:IsShown() then
            countdownButton:SetPoint("BOTTOMLEFT", lootSpecButton, "TOPLEFT", 0, 6)
            raidMarkerButton:SetPoint("BOTTOMLEFT", countdownButton, "TOPLEFT", 0, 6)
            countdownButton:SetFrameLevel((lootSpecButton.GetFrameLevel and lootSpecButton:GetFrameLevel() or level) + 2)
            raidMarkerButton:SetFrameLevel((countdownButton.GetFrameLevel and countdownButton:GetFrameLevel() or level) + 2)
        elseif anchor then
            countdownButton:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 12)
            raidMarkerButton:SetPoint("BOTTOMLEFT", countdownButton, "TOPLEFT", 0, 6)
            countdownButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
            raidMarkerButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
        end
        return
    end

    -- Otherwise, if readyCheck is visible (and possibly others), stack: ready -> countdown -> raid
    if readyCheckButton and readyCheckButton:IsShown() then
        if lootSpecButton and lootSpecButton:IsShown() then
            readyCheckButton:SetPoint("BOTTOMLEFT", lootSpecButton, "TOPLEFT", 0, 6)
            readyCheckButton:SetFrameLevel((lootSpecButton.GetFrameLevel and lootSpecButton:GetFrameLevel() or level) + 2)
        elseif anchor then
            readyCheckButton:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 12)
            readyCheckButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
        end
        if countdownButton and countdownButton:IsShown() then
            countdownButton:SetPoint("BOTTOMLEFT", readyCheckButton, "TOPLEFT", 0, 6)
            countdownButton:SetFrameLevel((readyCheckButton.GetFrameLevel and readyCheckButton:GetFrameLevel() or 0) + 2)
        end
        if raidMarkerButton and raidMarkerButton:IsShown() then
            local anchor = (countdownButton and countdownButton:IsShown()) and countdownButton or readyCheckButton
            raidMarkerButton:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 6)
            raidMarkerButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
        end
        return
    end

    -- If none of the above matched, ensure raid marker has a fallback anchor
    if lootSpecButton and lootSpecButton:IsShown() then
        raidMarkerButton:SetPoint("BOTTOMLEFT", lootSpecButton, "TOPLEFT", 0, 6)
        raidMarkerButton:SetFrameLevel((lootSpecButton.GetFrameLevel and lootSpecButton:GetFrameLevel() or level) + 2)
    elseif anchor then
        raidMarkerButton:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 8, 12)
        raidMarkerButton:SetFrameLevel((anchor.GetFrameLevel and anchor:GetFrameLevel() or 0) + 2)
    end
end

function GameMenu:PositionBattleTextToggles()
    if not (damageNumbersButton and healingNumbersButton) then return end
    damageNumbersButton:ClearAllPoints()
    healingNumbersButton:ClearAllPoints()
    -- Position volume button first if it exists and is enabled
    local anchor = self:GetMenuAnchor()
    -- Avoid positioning when anchor has secret anchor data
    if anchor and anchor.IsAnchoringSecret and anchor:IsAnchoringSecret() then return end
    if volumeButton and self.parent:GetConfig("gameMenu", "showVolumeButton") then
        self:PositionVolumeButton()
        -- Healing button above volume button
        healingNumbersButton:SetPoint("BOTTOMLEFT", volumeButton, "TOPLEFT", 0, 6)
        -- Damage button above healing button
        damageNumbersButton:SetPoint("BOTTOMLEFT", healingNumbersButton, "TOPLEFT", 0, 6)
    else
        -- Default: stack outside on the left edge of the game menu anchor
        if anchor then
            healingNumbersButton:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", -8, 12)
            damageNumbersButton:SetPoint("BOTTOMLEFT", healingNumbersButton, "TOPLEFT", 0, 6)
        end
    end

    -- Set frame levels once at the end
    local level = (anchor and anchor.GetFrameLevel and anchor:GetFrameLevel() or 0)
    damageNumbersButton:SetFrameLevel(level + 2)
    healingNumbersButton:SetFrameLevel(level + 2)
end

function GameMenu:RefreshBattleTextTogglesState()
    if damageNumbersButton then
        local enabled = GetCVar("floatingCombatTextCombatDamage_v2") == "1"
        damageNumbersButton:SetAlpha(enabled and 1.0 or 0.6)
    end
    if healingNumbersButton then
        local enabled = GetCVar("floatingCombatTextCombatHealing_v2") == "1"
        healingNumbersButton:SetAlpha(enabled and 1.0 or 0.6)
    end
end

function GameMenu:RefreshGroupToolsState()
    -- Enable state: Ready/Countdown require leader or assist; Raid marker can always be set by anyone
    local canCommand = UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
    if readyCheckButton then
        if canCommand then
            readyCheckButton:Enable()
            readyCheckButton:SetAlpha(1)
        else
            readyCheckButton:Disable()
            readyCheckButton:SetAlpha(0.4)
        end
    end
    if countdownButton then
        if canCommand then
            countdownButton:Enable()
            countdownButton:SetAlpha(1)
        else
            countdownButton:Disable()
            countdownButton:SetAlpha(0.4)
        end
    end

    -- Update raid marker icon tex coords to reflect chosen marker
    if raidMarkerButton and raidMarkerButton.icon then
        raidMarkerButton:Enable(); raidMarkerButton:SetAlpha(1)
        local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
        raidMarkerButton.icon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
        raidMarkerButton.icon:SetTexCoord(GetMarkerTexCoords(idx))
    end

    -- Show or hide ready/countdown buttons based on whether the user is in a group
    if self.parent:IsInGroup() then
        if readyCheckButton then readyCheckButton:Show() end
        if countdownButton then countdownButton:Show() end
    else
        if readyCheckButton then readyCheckButton:Hide() end
        if countdownButton then countdownButton:Hide() end
    end

    -- Ensure positioning updates based on visible buttons
    self:PositionGroupTools()
end

function GameMenu:CreateReloadButton()
    local mod = self
    -- Parent it to our menu container (or UIParent) but anchor to GameMenuFrame so it doesn't try to modify protected frames
    reloadButton = BOLT.ButtonUtils:CreateIconButton(nil, self:GetMenuParent(), "Interface\\Icons\\inv_misc_gear_01", {
        iconScale = 1,
        contentScale = 1.3
    })

    -- Inherit parent visibility fully
    if reloadButton.SetIgnoreParentAlpha then reloadButton:SetIgnoreParentAlpha(false) end
    if reloadButton.SetIgnoreParentScale then reloadButton:SetIgnoreParentScale(false) end

    -- Set the click handler for both left and right click
    reloadButton:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            mod:OnReloadClick()
        elseif button == "RightButton" then
            mod:OnOpenSettings()
        elseif button == "MiddleButton" then
            local siMod = BOLT.modules.savedInstances
            if siMod and BOLT:IsModuleEnabled("savedInstances") then
                siMod:PrintUnsavedInstances()
            else
                BOLT:Print("Saved Instances module is not enabled.")
            end
        end
    end)

    -- Register for right-click and middle-click
    reloadButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")

    -- Add hover effects
    reloadButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(reloadButton, "ANCHOR_LEFT")
            GameTooltip:SetText("Reload UI", 1, 1, 1)
            GameTooltip:AddLine("Left-click: Reload the user interface", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Right-click: Open B.O.L.T settings", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Middle-click: Show saved instances", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)

    reloadButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function GameMenu:PositionReloadButton()
    BOLT.ButtonUtils:PositionAboveGameMenuRight(reloadButton)
end

function GameMenu:OnReloadClick()
    -- Call ReloadUI in a protected manner
    self:SafeReloadUI()
end

function GameMenu:OnOpenSettings()
    -- Hide the game menu first (guarded)
    self:SafeHideUIPanel(GameMenuFrame)

    -- Immediately hide our own widgets in case GameMenuFrame's OnHide doesn't fire
    -- (observed when opening the Settings panel via right-click on the Reload button)
    self:HideLeaveGroupButton()
    self:HideReloadButton()
    self:HideGroupTools()
    self:HideBattleTextToggles()
    self:HideVolumeButton()
    self:HideLootSpecButton()

    -- Clean up CVAR watcher if present (mirror OnHide cleanup)
    if self.cvarWatcher then
        self.cvarWatcher:UnregisterEvent("CVAR_UPDATE")
        self.cvarWatcher:SetScript("OnEvent", nil)
        self.cvarWatcher = nil
    end

    -- All individual widgets above are already hidden; the container itself has no
    -- visual representation so hiding it is redundant. Calling Hide() on it would
    -- also trigger ADDON_ACTION_BLOCKED if the container was ever anchored to a
    -- forbidden frame, so we intentionally skip the container hide here.

    -- While we open the settings, suppress our OnShow handler to prevent the menu
    -- from briefly reappearing when the Settings frame is shown.
    self.suppressOnShow = true
    -- Safety: clear the suppression after a short delay in case something goes wrong
    C_Timer.After(0.6, function()
        if self then self.suppressOnShow = nil end
    end)

    -- Small delay to ensure UI is hidden before opening settings; delegate to
    -- the central OpenConfigPanel helper which handles Settings vs legacy UI.
    local mod = self
    C_Timer.After(0.1, function()
        if mod.parent and mod.parent.OpenConfigPanel then
            mod.parent:OpenConfigPanel()
        else
            mod.parent:Print("Settings panel not available. Open Interface > AddOns.")
        end
    end)
end

function GameMenu:OnLeaveGroupClick()
    -- Hide the game menu first (guarded)
    self:SafeHideUIPanel(GameMenuFrame)

    -- Small delay to allow UI to close cleanly
    C_Timer.After(0.1, function()
        self.parent:LeaveGroup()
    end)
end

function GameMenu:OnReadyCheckClick()
    if IsInGroup() and (IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
        else
            self.parent:Print("You must be the group leader or an assistant to start a ready check.")
        end
    else
        self.parent:Print("You must be in a group to start a ready check.")
    end
end

function GameMenu:OnCountdownClick()
    if IsInGroup() and (IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            if C_PartyInfo and C_PartyInfo.DoCountdown then
                C_PartyInfo.DoCountdown(5)
            end
        else
            self.parent:Print("You must be the group leader or an assistant to start a countdown.")
        end
    else
        self.parent:Print("You must be in a group to start a countdown.")
    end
end

function GameMenu:OnRaidMarkerClick(button)
    if not SetRaidTarget then
        self.parent:Print("Raid markers not available.")
        return
    end
    if button == "RightButton" then
        SetRaidTarget("player", 0)
        self.parent:Print("Raid marker cleared from you.")
        return
    end
    local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
    SetRaidTarget("player", idx)
    local names = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
    self.parent:Print("Set your raid marker: " .. (names[idx] or idx))
end

function GameMenu:OnDamageNumbersClick()
    local currentValue = GetCVar("floatingCombatTextCombatDamage_v2")
    local newValue = (currentValue == "1") and "0" or "1"

    if newValue == "1" then
        SetCVar("enableFloatingCombatText", "1")
    end

    for _, cvar in ipairs(DAMAGE_CONSOLE_VARS) do
        ConsoleExec(cvar .. " " .. newValue)
    end

    self:RefreshBattleTextTogglesState()

    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Damage numbers: " .. state)
end

function GameMenu:OnHealingNumbersClick()
    local currentValue = GetCVar("floatingCombatTextCombatHealing_v2")
    local newValue = (currentValue == "1") and "0" or "1"
    for _, cvar in ipairs(HEALING_CONSOLE_VARS) do
        ConsoleExec(cvar .. " " .. newValue)
    end

    self:RefreshBattleTextTogglesState()

    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Healing numbers: " .. state)
end

function GameMenu:OnVolumeButtonLeftClick()
    -- Toggle mute/unmute
    local currentVolume = tonumber(GetCVar("Sound_MasterVolume")) or 1

    if currentVolume == 0 then
        -- Unmute: restore previous volume from global (account-wide) DB, fall back to 50%
        local previousVolume = BOLTDB and BOLTDB.preMuteVolume or 0.5
        self:SafeCall(SetCVar, "Sound_MasterVolume", tostring(previousVolume))
        self.parent:Print("Audio unmuted (" .. math.floor(previousVolume * 100) .. "%)")
    else
        -- Mute: persist current volume globally so it survives reloads/relogs/character switches
        if BOLTDB then BOLTDB.preMuteVolume = currentVolume end
        self:SafeCall(SetCVar, "Sound_MasterVolume", "0")
        self.parent:Print("Audio muted")
    end

    -- Update the volume display
    self:UpdateVolumeDisplay()
end

function GameMenu:OnVolumeButtonRightClick()
    -- Toggle music on/off
    local currentMusic = GetCVar("Sound_EnableMusic")
    local newValue = (currentMusic == "1") and "0" or "1"
    self:SafeCall(SetCVar, "Sound_EnableMusic", newValue)

    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Music: " .. state)
end

function GameMenu:OnVolumeButtonMiddleClick()
    -- Toggle dialog audio on/off
    local currentDialog = GetCVar("Sound_EnableDialog")
    local newValue = (currentDialog == "1") and "0" or "1"
    self:SafeCall(SetCVar, "Sound_EnableDialog", newValue)

    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Dialog audio: " .. state)
end

function GameMenu:UpdateVolumeDisplay()
    if volumeButton and volumeButton.volumeText then
        local masterVolume = GetCVar("Sound_MasterVolume") or "1"
        local volumePercent = math.floor(tonumber(masterVolume) * 100)
        local displayText
        if volumePercent == 0 then
            displayText = "M"
            volumeButton.volumeText:SetTextColor(1, 0.2, 0.2) -- Red for muted
        else
            displayText = tostring(volumePercent)
            volumeButton.volumeText:SetTextColor(1, 1, 1) -- White for normal
        end
        volumeButton.volumeText:SetText(displayText)
    end
end

-- Global function for keybinding to toggle master volume
function BOLT_ToggleMasterVolume()
    -- Access the global BOLT addon
    local BOLT = _G["BOLT"]

    -- Get the GameMenu module
    if BOLT and BOLT.modules and BOLT.modules.gameMenu then
        BOLT.modules.gameMenu:OnVolumeButtonLeftClick()
    else
        -- Fallback if module isn't available
        local currentVolume = tonumber(GetCVar("Sound_MasterVolume")) or 1

        if currentVolume == 0 then
            -- Unmute: restore from global DB if available, else 50%
            local prev = BOLTDB and BOLTDB.preMuteVolume or 0.5
            pcall(SetCVar, "Sound_MasterVolume", tostring(prev))
            print("|cff00aaff[B.O.L.T]|r Audio unmuted (" .. math.floor(prev * 100) .. "%)")
        else
            -- Mute: persist current volume globally
            if BOLTDB then BOLTDB.preMuteVolume = currentVolume end
            pcall(SetCVar, "Sound_MasterVolume", "0")
            print("|cff00aaff[B.O.L.T]|r Audio muted")
        end
    end
end

-- Register the module
BOLT:RegisterModule("gameMenu", GameMenu)
