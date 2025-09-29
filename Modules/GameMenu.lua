-- B.O.L.T Game Menu Module
-- Adds quality of life improvements to the game menu

local ADDON_NAME, BOLT = ...

-- Create the GameMenu module
local GameMenu = {}

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

function GameMenu:OnInitialize()
    self.parent:Debug("GameMenu module initializing...")
end

function GameMenu:OnEnable()
    if not self.parent:IsModuleEnabled("gameMenu") then
        return
    end
    
    self.parent:Debug("GameMenu module enabling...")
    
    -- Hook into the game menu show event
    self:HookGameMenu()
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
end

function GameMenu:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Always try to show battle text toggles first (they work in combat)
            if self.parent:GetConfig("gameMenu", "showBattleTextToggles") then
                self:ShowBattleTextToggles()
            end
            
            -- Check if we're in combat or a protected state before proceeding with other buttons
            if InCombatLockdown() then
                -- Defer the update until after combat
                local frame = CreateFrame("Frame")
                frame:RegisterEvent("PLAYER_REGEN_ENABLED")
                frame:SetScript("OnEvent", function(self)
                    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    GameMenu:UpdateGameMenu()
                    self:SetScript("OnEvent", nil)
                end)
            else
                -- Small delay to ensure the menu is fully loaded, but only if not in combat
                C_Timer.After(0.05, function()
                    if not InCombatLockdown() then
                        self:UpdateGameMenu()
                    end
                end)
            end
        end)
        
        GameMenuFrame:HookScript("OnHide", function()
            -- Only hide certain buttons if not in combat (battle text toggles can always be hidden)
            if not InCombatLockdown() then
                self:HideLeaveGroupButton()
                self:HideReloadButton()
                self:HideGroupTools()
            end
            -- Battle text toggles can be hidden even in combat since they don't affect protected functions
            self:HideBattleTextToggles()
        end)
    end
end

function GameMenu:UpdateGameMenu()
    if not self.parent:GetConfig("gameMenu", "enabled") then
        return
    end
    
    -- Battle text toggles can be shown even during combat (they don't use protected functions)
    if self.parent:GetConfig("gameMenu", "showBattleTextToggles") then
        self:ShowBattleTextToggles()
    else
        self:HideBattleTextToggles()
    end
    
    -- Don't update other UI elements during combat
    if InCombatLockdown() then
        return
    end
    
    -- Show reload button if enabled
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

    -- Group tools (ready check, countdown, raid marker)
    if self.parent:GetConfig("gameMenu", "groupToolsEnabled") and self.parent:IsInGroup() then
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
    if groupType then
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
    
    reloadButton:Show()
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

    readyCheckButton:Show()
    countdownButton:Show()
    raidMarkerButton:Show()

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

    damageNumbersButton:Show()
    healingNumbersButton:Show()

    self:PositionBattleTextToggles()
    self:RefreshBattleTextTogglesState()
end

function GameMenu:HideBattleTextToggles()
    if damageNumbersButton then damageNumbersButton:Hide() end
    if healingNumbersButton then healingNumbersButton:Hide() end
end

function GameMenu:CreateLeaveGroupButton()
    -- Create a button similar to the existing game menu buttons
    -- First try the modern template, fallback to creating manually
    local template = "UIPanelButtonTemplate"
    leaveGroupButton = CreateFrame("Button", "BOLTLeaveGroupButton", GameMenuFrame, template)
    
    -- If that didn't work, try without template and style manually
    if not leaveGroupButton:GetNormalTexture() then
        leaveGroupButton = CreateFrame("Button", "BOLTLeaveGroupButton", GameMenuFrame)
        
        -- Create textures manually to match game menu buttons
        local normalTexture = leaveGroupButton:CreateTexture(nil, "BACKGROUND")
        normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
        normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
        normalTexture:SetAllPoints()
        leaveGroupButton:SetNormalTexture(normalTexture)
        
        local pushedTexture = leaveGroupButton:CreateTexture(nil, "BACKGROUND")
        pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
        pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
        pushedTexture:SetAllPoints()
        leaveGroupButton:SetPushedTexture(pushedTexture)
        
        local highlightTexture = leaveGroupButton:CreateTexture(nil, "HIGHLIGHT")
        highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
        highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
        highlightTexture:SetAllPoints()
        highlightTexture:SetBlendMode("ADD")
        leaveGroupButton:SetHighlightTexture(highlightTexture)
    end
    
    -- Set button properties to match other game menu buttons
    leaveGroupButton:SetSize(144, 28)  -- Increased height to match other buttons
    leaveGroupButton:SetText("Leave Group")
    
    -- Set font to match other buttons
    local fontString = leaveGroupButton:GetFontString() or leaveGroupButton:CreateFontString(nil, "OVERLAY")
    fontString:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    fontString:SetPoint("CENTER")
    fontString:SetTextColor(1, 0.82, 0, 1) -- Gold color like other buttons
    leaveGroupButton:SetFontString(fontString)
    
    -- Enable mouse interaction
    leaveGroupButton:EnableMouse(true)
    leaveGroupButton:SetMotionScriptsWhileDisabled(true)
    
    -- Set the click handler
    leaveGroupButton:SetScript("OnClick", function()
        self:OnLeaveGroupClick()
    end)
    
    -- Add hover sound effect like other buttons
    leaveGroupButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(leaveGroupButton, "ANCHOR_RIGHT")
            local groupType = self.parent:GetGroupTypeString()
            if groupType then
                GameTooltip:SetText("Leave " .. groupType, 1, 1, 1)
                if UnitIsGroupLeader("player") then
                    GameTooltip:AddLine("Leadership will be transferred automatically", 0.8, 0.8, 0.8, true)
                end
            else
                GameTooltip:SetText("Leave Group", 1, 1, 1)
            end
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    leaveGroupButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    
    -- Add click sound
    leaveGroupButton:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
end

function GameMenu:PositionLeaveGroupButton()
    if not leaveGroupButton then
        return
    end
    
    -- Clear any existing anchor points
    leaveGroupButton:ClearAllPoints()
    
    -- Position the button below the entire GameMenuFrame
    leaveGroupButton:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -10)
    
    -- Ensure the button is clickable and visible
    leaveGroupButton:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    leaveGroupButton:EnableMouse(true)
    leaveGroupButton:Show()
end

-- Create small square utility button with icon textures
local function CreateIconButton(name, parent, iconPath)
    local btn = CreateFrame("Button", name, parent)
    local normalTexture = btn:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    btn:SetNormalTexture(normalTexture)

    local pushedTexture = btn:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    btn:SetPushedTexture(pushedTexture)

    local highlightTexture = btn:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    highlightTexture:SetBlendMode("ADD")
    btn:SetHighlightTexture(highlightTexture)

    btn:SetSize(28, 28)

    local iconTexture = btn:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture(iconPath)
    iconTexture:SetSize(20, 20)
    iconTexture:SetPoint("CENTER")
    btn.icon = iconTexture

    btn:EnableMouse(true)
    btn:SetMotionScriptsWhileDisabled(true)
    btn:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
    return btn
end

function GameMenu:CreateReadyCheckButton()
    readyCheckButton = CreateIconButton("ColdSnapGMReadyCheck", GameMenuFrame, "Interface\\RaidFrame\\ReadyCheck-Ready")
    readyCheckButton:SetScript("OnClick", function()
        self:OnReadyCheckClick()
    end)
    readyCheckButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(readyCheckButton, "ANCHOR_RIGHT")
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
    countdownButton = CreateIconButton("ColdSnapGMCountdown", GameMenuFrame, "Interface\\Icons\\Spell_Holy_BorrowedTime")
    countdownButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    countdownButton:SetScript("OnClick", function()
        self:OnCountdownClick()
    end)
    countdownButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(countdownButton, "ANCHOR_RIGHT")
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
    raidMarkerButton = CreateIconButton("ColdSnapGMRaidMarker", GameMenuFrame, "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
    -- We'll adjust tex coords based on selected marker in RefreshGroupToolsState
    raidMarkerButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    raidMarkerButton:SetScript("OnClick", function(_, button)
        self:OnRaidMarkerClick(button)
    end)
    raidMarkerButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(raidMarkerButton, "ANCHOR_RIGHT")
        local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
        local names = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"}
        GameTooltip:SetText("Raid Marker", 1, 1, 1)
        GameTooltip:AddLine("Left-click: Set your own marker (" .. (names[idx] or "Unknown") .. ")", 0.8,0.8,0.8,true)
        GameTooltip:AddLine("Right-click: Clear your marker", 0.8,0.8,0.8,true)
        if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
            GameTooltip:AddLine("Requires group leader or assistant", 1, 0.2, 0.2, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    raidMarkerButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateDamageNumbersButton()
    damageNumbersButton = CreateIconButton("ColdSnapGMDamageNumbers", GameMenuFrame, "Interface\\Icons\\Spell_Fire_FireBolt02")
    damageNumbersButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    damageNumbersButton:SetScript("OnClick", function()
        self:OnDamageNumbersClick()
    end)
    damageNumbersButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(damageNumbersButton, "ANCHOR_RIGHT")
        local enabled = GetCVar("floatingCombatTextCombatDamage") == "1"
        GameTooltip:SetText("Toggle Damage Numbers", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. (enabled and "ON" or "OFF"), enabled and 0.0 or 1.0, enabled and 1.0 or 0.0, 0.0, true)
        GameTooltip:AddLine("Show/hide damage numbers in scrolling combat text", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    damageNumbersButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateHealingNumbersButton()
    healingNumbersButton = CreateIconButton("ColdSnapGMHealingNumbers", GameMenuFrame, "Interface\\Icons\\Spell_Holy_GreaterHeal")
    healingNumbersButton.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    healingNumbersButton:SetScript("OnClick", function()
        self:OnHealingNumbersClick()
    end)
    healingNumbersButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(healingNumbersButton, "ANCHOR_RIGHT")
        local enabled = GetCVar("floatingCombatTextCombatHealing") == "1"
        GameTooltip:SetText("Toggle Healing Numbers", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. (enabled and "ON" or "OFF"), enabled and 0.0 or 1.0, enabled and 1.0 or 0.0, 0.0, true)
        GameTooltip:AddLine("Show/hide healing numbers in scrolling combat text", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    healingNumbersButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:PositionGroupTools()
    if not (readyCheckButton and countdownButton and raidMarkerButton) then return end
    readyCheckButton:ClearAllPoints()
    countdownButton:ClearAllPoints()
    raidMarkerButton:ClearAllPoints()
    -- Place on the left side of GameMenuFrame, vertically stacked
    readyCheckButton:SetPoint("TOPRIGHT", GameMenuFrame, "TOPLEFT", -8, -12)
    countdownButton:SetPoint("TOPLEFT", readyCheckButton, "BOTTOMLEFT", 0, -6)
    raidMarkerButton:SetPoint("TOPLEFT", countdownButton, "BOTTOMLEFT", 0, -6)
    local level = GameMenuFrame:GetFrameLevel()
    readyCheckButton:SetFrameLevel(level + 2)
    countdownButton:SetFrameLevel(level + 2)
    raidMarkerButton:SetFrameLevel(level + 2)
end

function GameMenu:PositionBattleTextToggles()
    if not (damageNumbersButton and healingNumbersButton) then return end
    damageNumbersButton:ClearAllPoints()
    healingNumbersButton:ClearAllPoints()
    -- Place on the left side of GameMenuFrame, vertically stacked at bottom (mirroring group tools at top)
    healingNumbersButton:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMLEFT", -8, 12)
    damageNumbersButton:SetPoint("BOTTOMLEFT", healingNumbersButton, "TOPLEFT", 0, 6)
    local level = GameMenuFrame:GetFrameLevel()
    damageNumbersButton:SetFrameLevel(level + 2)
    healingNumbersButton:SetFrameLevel(level + 2)
end

function GameMenu:RefreshBattleTextTogglesState()
    if damageNumbersButton then
        local enabled = GetCVar("floatingCombatTextCombatDamage") == "1"
        damageNumbersButton:SetAlpha(enabled and 1.0 or 0.6)
    end
    if healingNumbersButton then
        local enabled = GetCVar("floatingCombatTextCombatHealing") == "1"
        healingNumbersButton:SetAlpha(enabled and 1.0 or 0.6)
    end
end

function GameMenu:RefreshGroupToolsState()
    -- Enable state: Ready/Countdown require leader or assist; Raid marker requires leader or assist
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
        if canCommand then
            raidMarkerButton:Enable()
            raidMarkerButton:SetAlpha(1)
        else
            raidMarkerButton:Disable()
            raidMarkerButton:SetAlpha(0.4)
        end
        local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
        -- Raid target sheet is 4x4 grid; indices 1..8 left-to-right, top-to-bottom (WoW ordering)
        local function GetMarkerTexCoords(i)
            local map = {
                [1] = {0, 0.25, 0, 0.25},      -- Star
                [2] = {0.25, 0.5, 0, 0.25},    -- Circle
                [3] = {0.5, 0.75, 0, 0.25},    -- Diamond
                [4] = {0.75, 1, 0, 0.25},      -- Triangle
                [5] = {0, 0.25, 0.25, 0.5},    -- Moon
                [6] = {0.25, 0.5, 0.25, 0.5},  -- Square
                [7] = {0.5, 0.75, 0.25, 0.5},  -- Cross
                [8] = {0.75, 1, 0.25, 0.5},    -- Skull
            }
            return unpack(map[i] or map[1])
        end
        raidMarkerButton.icon:SetTexture("Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
        raidMarkerButton.icon:SetTexCoord(GetMarkerTexCoords(idx))
    end
end

-- Event hook to keep enable/disable state current
local function RegisterGroupStateUpdates()
    if GameMenu._groupUpdateFrame then return end
    local f = CreateFrame("Frame")
    f:RegisterEvent("GROUP_ROSTER_UPDATE")
    f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
    f:RegisterEvent("PARTY_LEADER_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        if GameMenuFrame and GameMenuFrame:IsShown() then
            GameMenu:RefreshGroupToolsState()
        end
    end)
    GameMenu._groupUpdateFrame = f
end

RegisterGroupStateUpdates()

function GameMenu:CreateReloadButton()
    -- Create a small reload button for the top right
    reloadButton = CreateFrame("Button", "BOLTReloadButton", GameMenuFrame)
    
    -- Create textures manually to match game menu buttons
    local normalTexture = reloadButton:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    reloadButton:SetNormalTexture(normalTexture)
    
    local pushedTexture = reloadButton:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    reloadButton:SetPushedTexture(pushedTexture)
    
    local highlightTexture = reloadButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    highlightTexture:SetBlendMode("ADD")
    reloadButton:SetHighlightTexture(highlightTexture)
    
    -- Set button properties - smaller size for corner placement
    reloadButton:SetSize(28, 28)
    
    -- Create the refresh icon using the standard WoW refresh texture
    local iconTexture = reloadButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    iconTexture:SetSize(20, 20)
    iconTexture:SetPoint("CENTER")
    
    -- If the refresh texture doesn't exist, fallback to a different one
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\Ability_Rogue_Preparation")
        iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
    end
    
    -- Enable mouse interaction
    reloadButton:EnableMouse(true)
    reloadButton:SetMotionScriptsWhileDisabled(true)
    
    -- Set the click handler for both left and right click
    reloadButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            GameMenu:OnReloadClick()
        elseif button == "RightButton" then
            GameMenu:OnOpenSettings()
        end
    end)
    
    -- Register for right-click
    reloadButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- Add hover effects
    reloadButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(reloadButton, "ANCHOR_LEFT")
            GameTooltip:SetText("Reload UI", 1, 1, 1)
            GameTooltip:AddLine("Left-click: Reload the user interface", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Right-click: Open ColdSnap settings", 0.8, 0.8, 0.8, true)
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
    
    -- Add click sound
    reloadButton:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
end

function GameMenu:PositionReloadButton()
    if not reloadButton then
        return
    end
    
    -- Clear any existing anchor points
    reloadButton:ClearAllPoints()
    
    -- Position at the top right corner of the GameMenuFrame with padding
    reloadButton:SetPoint("TOPRIGHT", GameMenuFrame, "TOPRIGHT", -12, -12)
    
    -- Ensure the button is clickable and visible
    reloadButton:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    reloadButton:EnableMouse(true)
    reloadButton:Show()
end

function GameMenu:OnReloadClick()
    -- Call ReloadUI directly - no need for timer delay
    ReloadUI()
end

function GameMenu:OnOpenSettings()
    -- Hide the game menu first
    HideUIPanel(GameMenuFrame)
    
    -- Small delay to ensure UI is hidden before opening settings
    C_Timer.After(0.1, function()
        -- Use the exact same logic as the /cs slash command
        if Settings and Settings.OpenToCategory then
            -- Modern Settings API (Retail)
            if self.parent.modules.config and self.parent.modules.config.settingsCategory then
                Settings.OpenToCategory(self.parent.modules.config.settingsCategory.ID)
            else
                self.parent:Print("Settings panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            -- Legacy Interface Options (Classic)
            if self.parent.modules.config and self.parent.modules.config.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.config.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.config.optionsPanel) -- Call twice for proper focus
            else
                self.parent:Print("Options panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        else
            self.parent:Print("Please access ColdSnap settings through Interface > AddOns.")
        end
    end)
end

function GameMenu:OnLeaveGroupClick()
    -- Hide the game menu first
    HideUIPanel(GameMenuFrame)
    
    -- Small delay to allow UI to close cleanly
    C_Timer.After(0.1, function()
        self.parent:LeaveGroup()
    end)
end

function GameMenu:OnReadyCheckClick()
    if IsInGroup() and (IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
            self.parent:Debug("Ready check initiated")
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
            self.parent:Debug("Countdown initiated")
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
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
        self.parent:Print("You must be the group leader or an assistant to change raid markers.")
        return
    end
    if button == "RightButton" then
        SetRaidTarget("player", 0)
        self.parent:Print("Raid marker cleared from you.")
        return
    end
    local idx = self.parent:GetConfig("gameMenu", "raidMarkerIndex") or 1
    SetRaidTarget("player", idx)
    local names = {"Star","Circle","Diamond","Triangle","Moon","Square","Cross","Skull"}
    self.parent:Print("Set your raid marker: " .. (names[idx] or idx))
end

function GameMenu:OnDamageNumbersClick()
    local currentValue = GetCVar("floatingCombatTextCombatDamage")
    local newValue = (currentValue == "1") and "0" or "1"
    SetCVar("floatingCombatTextCombatDamage", newValue)
    
    -- Refresh the button state immediately
    self:RefreshBattleTextTogglesState()
    
    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Damage numbers: " .. state)
end

function GameMenu:OnHealingNumbersClick()
    local currentValue = GetCVar("floatingCombatTextCombatHealing")
    local newValue = (currentValue == "1") and "0" or "1"
    SetCVar("floatingCombatTextCombatHealing", newValue)
    
    -- Refresh the button state immediately
    self:RefreshBattleTextTogglesState()
    
    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Healing numbers: " .. state)
end

-- Register the module
BOLT:RegisterModule("gameMenu", GameMenu)
