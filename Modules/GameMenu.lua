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
-- Volume control button
local volumeButton = nil

function GameMenu:OnInitialize()
    -- Module initialization
end

function GameMenu:OnEnable()
    if not self.parent:IsModuleEnabled("gameMenu") then
        return
    end
    
    -- Hook into the game menu show event
    self:HookGameMenu()
    
    -- group-state watcher
    if not self.groupUpdateFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("GROUP_ROSTER_UPDATE")
        f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
        f:RegisterEvent("PARTY_LEADER_CHANGED")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function()
            if GameMenuFrame and GameMenuFrame:IsShown() then
                self:RefreshGroupToolsState()
            end
        end)
        self.groupUpdateFrame = f
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
    
    -- Clean up group update frame
    if self.groupUpdateFrame then
        self.groupUpdateFrame:UnregisterAllEvents()
        self.groupUpdateFrame:SetScript("OnEvent", nil)
        self.groupUpdateFrame = nil
    end
end

function GameMenu:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Small delay to ensure the menu is fully loaded
            C_Timer.After(0.05, function()
                self:UpdateGameMenu()
            end)
            
            -- Watch CVARs while menu is open
            if not self.cvarWatcher then
                local f = CreateFrame("Frame")
                f:RegisterEvent("CVAR_UPDATE")
                f:SetScript("OnEvent", function(_, _, name)
                    if name == "Sound_MasterVolume" or name == "Sound_EnableMusic" then
                        self:UpdateVolumeDisplay()
                    elseif name == "floatingCombatTextCombatDamage" or name == "floatingCombatTextCombatHealing" then
                        self:RefreshBattleTextTogglesState()
                    end
                end)
                self.cvarWatcher = f
            end
        end)
        
        GameMenuFrame:HookScript("OnHide", function()
            self:HideLeaveGroupButton()
            self:HideReloadButton()
            self:HideGroupTools()
            self:HideBattleTextToggles()
            
            -- Clean up CVAR watcher
            if self.cvarWatcher then
                self.cvarWatcher:UnregisterEvent("CVAR_UPDATE")
                self.cvarWatcher:SetScript("OnEvent", nil)
                self.cvarWatcher = nil
            end
        end)
    end
end

function GameMenu:UpdateGameMenu()
    if not self.parent:GetConfig("gameMenu", "enabled") then
        return
    end
    
    -- Battle text toggles
    if self.parent:GetConfig("gameMenu", "showBattleTextToggles") then
        self:ShowBattleTextToggles()
    else
        self:HideBattleTextToggles()
    end
    
    -- Volume button
    if self.parent:GetConfig("gameMenu", "showVolumeButton") then
        if not volumeButton then
            self:CreateVolumeButton()
        end
        if volumeButton then
            volumeButton:Show()
        end
    else
        if volumeButton then
            volumeButton:Hide()
        end
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
    -- do NOT hide volumeButton here
end

function GameMenu:CreateLeaveGroupButton()
    leaveGroupButton = CreateFrame("Button", nil, GameMenuFrame, "GameMenuButtonTemplate")
    leaveGroupButton:SetSize(144, 28)
    leaveGroupButton:SetText("Leave Group")
    leaveGroupButton:SetScript("OnClick", function() self:OnLeaveGroupClick() end)
    leaveGroupButton:SetMotionScriptsWhileDisabled(true)
    leaveGroupButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(leaveGroupButton, "ANCHOR_RIGHT")
        local groupType = self.parent:GetGroupTypeString()
        GameTooltip:SetText(groupType and ("Leave "..groupType) or "Leave Group", 1, 1, 1)
        if UnitIsGroupLeader("player") then
            GameTooltip:AddLine("Leadership will be transferred automatically", 0.8, 0.8, 0.8, true)
        end
        if InCombatLockdown() then
            GameTooltip:AddLine("|cFFFF6B6BNot available during combat|r", 1, 0.42, 0.42, true)
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
    
    -- Position the button below the entire GameMenuFrame
    leaveGroupButton:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -10)
    
    -- Ensure the button is clickable and visible
    leaveGroupButton:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    leaveGroupButton:EnableMouse(true)
    leaveGroupButton:Show()
end

function GameMenu:CreateReadyCheckButton()
    readyCheckButton = BOLT.ButtonUtils:CreateIconButton(nil, GameMenuFrame, "Interface\\RaidFrame\\ReadyCheck-Ready")
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
        if InCombatLockdown() then
            GameTooltip:AddLine("|cFFFF6B6BNot available during combat|r", 1, 0.42, 0.42, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    readyCheckButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateCountdownButton()
    countdownButton = BOLT.ButtonUtils:CreateIconButton(nil, GameMenuFrame, "Interface\\Icons\\Spell_Holy_BorrowedTime")
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
        if InCombatLockdown() then
            GameTooltip:AddLine("|cFFFF6B6BNot available during combat|r", 1, 0.42, 0.42, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    countdownButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateRaidMarkerButton()
    raidMarkerButton = BOLT.ButtonUtils:CreateIconButton(nil, GameMenuFrame, "Interface\\TARGETINGFRAME\\UI-RaidTargetingIcons")
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
        if InCombatLockdown() then
            GameTooltip:AddLine("|cFFFF6B6BNot available during combat|r", 1, 0.42, 0.42, true)
        end
        GameTooltip:Show()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    raidMarkerButton:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function GameMenu:CreateDamageNumbersButton()
    damageNumbersButton = BOLT.ButtonUtils:CreateIconButton(nil, GameMenuFrame, "Interface\\Icons\\Spell_Fire_FireBolt02")
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
    healingNumbersButton = BOLT.ButtonUtils:CreateIconButton(nil, GameMenuFrame, "Interface\\Icons\\Spell_Holy_GreaterHeal")
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

function GameMenu:CreateVolumeButton()
    -- Create volume button with background using ButtonUtils
    volumeButton = BOLT.ButtonUtils:CreateVolumeButton(nil, GameMenuFrame, {
        showBackground = true
    })
    
    -- Add volume display text overlay - properly centered
    volumeButton.volumeText = volumeButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    volumeButton.volumeText:SetPoint("CENTER", volumeButton, "CENTER", 0, 0)
    volumeButton.volumeText:SetTextColor(1, 1, 1)
    volumeButton.volumeText:SetJustifyH("CENTER")
    volumeButton.volumeText:SetWidth(28) -- Match button width
    volumeButton.volumeText:SetScale(1) -- Smaller scale to fit nicely
    
    -- Left click for mute/unmute, right click for music toggle
    volumeButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            GameMenu:OnVolumeButtonLeftClick()
        elseif button == "RightButton" then
            GameMenu:OnVolumeButtonRightClick()
        end
    end)
    
    -- Enable both left and right-click
    volumeButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    volumeButton:SetScript("OnEnter", function()
        GameTooltip:SetOwner(volumeButton, "ANCHOR_RIGHT")
        local masterVolume = GetCVar("Sound_MasterVolume") or "1"
        local volumePercent = math.floor(tonumber(masterVolume) * 100)
        local isMuted = volumePercent == 0
        GameTooltip:SetText("Master Volume", 1, 1, 1)
        GameTooltip:AddLine("Current: " .. volumePercent .. "%" .. (isMuted and " (MUTED)" or ""), 1, 1, 0, true)
        GameTooltip:AddLine("Display: " .. (isMuted and "M" or tostring(volumePercent)), 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine("Left-click: Toggle mute", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("Right-click: Toggle music", 0.8, 0.8, 0.8, true)
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
        SetCVar("Sound_MasterVolume", tostring(newVol))
        GameMenu:UpdateVolumeDisplay()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    -- Initialize volume display
    self:UpdateVolumeDisplay()
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
    
    -- Position volume button if it exists and is enabled
    if volumeButton and self.parent:GetConfig("gameMenu", "showVolumeButton") then
        volumeButton:ClearAllPoints()
        -- Volume button at the bottom
        volumeButton:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMLEFT", -8, 12)
        -- Healing button above volume button
        healingNumbersButton:SetPoint("BOTTOMLEFT", volumeButton, "TOPLEFT", 0, 6)
        -- Damage button above healing button
        damageNumbersButton:SetPoint("BOTTOMLEFT", healingNumbersButton, "TOPLEFT", 0, 6)
    else
        -- Original positioning if no volume button or volume button disabled
        healingNumbersButton:SetPoint("BOTTOMRIGHT", GameMenuFrame, "BOTTOMLEFT", -8, 12)
        damageNumbersButton:SetPoint("BOTTOMLEFT", healingNumbersButton, "TOPLEFT", 0, 6)
    end
    
    -- Set frame levels once at the end
    local level = GameMenuFrame:GetFrameLevel()
    damageNumbersButton:SetFrameLevel(level + 2)
    healingNumbersButton:SetFrameLevel(level + 2)
    if volumeButton then
        volumeButton:SetFrameLevel(level + 2)
    end
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

function GameMenu:CreateReloadButton()
    -- Create a reload button with a gear/engineering icon
    reloadButton = BOLT.ButtonUtils:CreateIconButton(nil, UIParent, "Interface\\Icons\\inv_misc_gear_01", {
        iconScale = 1,
        contentScale = 1.3
    })
    
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
            GameTooltip:AddLine("Right-click: Open B.O.L.T settings", 0.8, 0.8, 0.8, true)
            if InCombatLockdown() then
                GameTooltip:AddLine("|cFFFF6B6BNot available during combat|r", 1, 0.42, 0.42, true)
            end
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
            local cat = self.parent.modules.config and self.parent.modules.config.settingsCategory
            if cat and cat.GetID then
                Settings.OpenToCategory(cat:GetID())
            else
                self.parent:Print("Settings panel not available. Open Interface > AddOns.")
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            -- Legacy Interface Options (Classic)
            if self.parent.modules.config and self.parent.modules.config.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.config.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.config.optionsPanel) -- Call twice for proper focus
            else
                self.parent:Print("Options panel not available. Please access B.O.L.T settings through Interface > AddOns.")
            end
        else
            self.parent:Print("Please access B.O.L.T settings through Interface > AddOns.")
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

function GameMenu:OnVolumeButtonLeftClick()
    -- Toggle mute/unmute
    local currentVolume = tonumber(GetCVar("Sound_MasterVolume")) or 1
    
    if currentVolume == 0 then
        -- Unmute: restore previous volume or set to 50% if no previous volume stored
        local previousVolume = self.previousVolume or 0.5
        SetCVar("Sound_MasterVolume", tostring(previousVolume))
        self.parent:Print("Audio unmuted (" .. math.floor(previousVolume * 100) .. "%)")
    else
        -- Mute: store current volume and set to 0
        self.previousVolume = currentVolume
        SetCVar("Sound_MasterVolume", "0")
        self.parent:Print("Audio muted")
    end
    
    -- Update the volume display
    self:UpdateVolumeDisplay()
end

function GameMenu:OnVolumeButtonRightClick()
    -- Toggle music on/off
    local currentMusic = GetCVar("Sound_EnableMusic")
    local newValue = (currentMusic == "1") and "0" or "1"
    SetCVar("Sound_EnableMusic", newValue)
    
    local state = (newValue == "1") and "ON" or "OFF"
    self.parent:Print("Music: " .. state)
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
            -- Unmute: restore to 50%
            SetCVar("Sound_MasterVolume", "0.5")
            print("|cff00aaff[B.O.L.T]|r Audio unmuted (50%)")
        else
            -- Mute
            SetCVar("Sound_MasterVolume", "0")
            print("|cff00aaff[B.O.L.T]|r Audio muted")
        end
    end
end

-- Register the module
BOLT:RegisterModule("gameMenu", GameMenu)
