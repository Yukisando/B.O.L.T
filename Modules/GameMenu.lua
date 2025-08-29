-- ColdSnap Game Menu Module
-- Adds quality of life improvements to the game menu

local ADDON_NAME, ColdSnap = ...

-- Create the GameMenu module
local GameMenu = {}

-- Reference to the Leave Group button
local leaveGroupButton = nil
-- Reference to the Reload UI button
local reloadButton = nil
-- Reference to the Favorite Toy button
local favoriteToyButton = nil

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
    if favoriteToyButton then
        favoriteToyButton:Hide()
        favoriteToyButton = nil
    end
end

function GameMenu:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Check if we're in combat or a protected state before proceeding
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
            -- Only hide buttons if not in combat
            if not InCombatLockdown() then
                self:HideLeaveGroupButton()
                self:HideReloadButton()
                self:HideFavoriteToyButton()
            end
        end)
    end
end

function GameMenu:UpdateGameMenu()
    if not self.parent:GetConfig("gameMenu", "enabled") then
        return
    end
    
    -- Don't update UI elements during combat
    if InCombatLockdown() then
        return
    end
    
    -- Show reload button if enabled
    if self.parent:GetConfig("gameMenu", "showReloadButton") then
        self:ShowReloadButton()
    else
        self:HideReloadButton()
    end
    
    -- Show favorite toy button if enabled
    if self.parent:GetConfig("gameMenu", "showFavoriteToy") then
        self:ShowFavoriteToyButton()
    else
        self:HideFavoriteToyButton()
    end
    
    -- Check if player is in a group for leave group button
    if self.parent:GetConfig("gameMenu", "showLeaveGroup") and self.parent:IsInGroup() then
        self:ShowLeaveGroupButton()
    else
        self:HideLeaveGroupButton()
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

function GameMenu:ShowFavoriteToyButton()
    -- Create the button if it doesn't exist
    if not favoriteToyButton then
        self:CreateFavoriteToyButton()
    end
    
    -- Update the secure button with the current toy
    self:UpdateFavoriteToyButton()
    
    -- Always enable the button so it's clickable - the secure action will handle usability
    local toyId = self.parent:GetConfig("gameMenu", "favoriteToyId")
    if toyId and PlayerHasToy(toyId) then
        favoriteToyButton:Enable()
        favoriteToyButton:SetAlpha(1.0)
        
        -- Update visual state based on usability, but keep button enabled
        if not C_ToyBox.IsToyUsable(toyId) then
            favoriteToyButton:SetAlpha(0.7) -- Slightly dimmed but still clearly clickable
        end
    else
        favoriteToyButton:Enable() -- Still enable so user can click and get feedback
        favoriteToyButton:SetAlpha(0.5)
    end
    
    favoriteToyButton:Show()
    self:PositionFavoriteToyButton()
end

function GameMenu:HideFavoriteToyButton()
    if favoriteToyButton then
        favoriteToyButton:Hide()
    end
end

function GameMenu:CreateLeaveGroupButton()
    -- Create a button similar to the existing game menu buttons
    -- First try the modern template, fallback to creating manually
    local template = "UIPanelButtonTemplate"
    leaveGroupButton = CreateFrame("Button", "ColdSnapLeaveGroupButton", GameMenuFrame, template)
    
    -- If that didn't work, try without template and style manually
    if not leaveGroupButton:GetNormalTexture() then
        leaveGroupButton = CreateFrame("Button", "ColdSnapLeaveGroupButton", GameMenuFrame)
        
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

function GameMenu:CreateReloadButton()
    -- Create a small reload button for the top right
    reloadButton = CreateFrame("Button", "ColdSnapReloadButton", GameMenuFrame)
    
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

function GameMenu:CreateFavoriteToyButton()
    -- Create a secure action button like OPie does - but with fallback support
    favoriteToyButton = CreateFrame("Button", "ColdSnapFavoriteToyButton", GameMenuFrame, "SecureActionButtonTemplate")
    
    self.parent:Debug("Creating favorite toy button as SecureActionButtonTemplate")
    
    -- Create textures manually to match game menu buttons
    local normalTexture = favoriteToyButton:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    favoriteToyButton:SetNormalTexture(normalTexture)
    
    local pushedTexture = favoriteToyButton:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    favoriteToyButton:SetPushedTexture(pushedTexture)
    
    local highlightTexture = favoriteToyButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    highlightTexture:SetBlendMode("ADD")
    favoriteToyButton:SetHighlightTexture(highlightTexture)
    
    -- Set button properties - same size as reload button
    favoriteToyButton:SetSize(28, 28)
    
    -- Create the toy icon - using a fun toy icon
    local iconTexture = favoriteToyButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Toy_10") -- Toy Train Set icon
    iconTexture:SetSize(20, 20)
    iconTexture:SetPoint("CENTER")
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
    
    -- If that toy icon doesn't exist, fallback to a different one
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Toy_02") -- Jack-in-the-Box
        if not iconTexture:GetTexture() then
            iconTexture:SetTexture("Interface\\Icons\\INV_Misc_Gift_02") -- Generic gift/toy icon
        end
    end
    
    -- Configure the secure button for macro usage (which can call /usetoy)
    -- This is a more reliable approach than direct toy usage
    favoriteToyButton:SetAttribute("type", "macro")
    favoriteToyButton:RegisterForClicks("LeftButtonUp")
    
    -- Set up the toy to use when button is clicked - we'll update this when needed
    self:UpdateFavoriteToyButton()
    
    -- Add hover effects (non-secure scripts are OK)
    favoriteToyButton:SetScript("OnEnter", function()
        local toyId = self.parent:GetConfig("gameMenu", "favoriteToyId")
        if toyId and PlayerHasToy(toyId) then
            local _, toyName = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                GameTooltip:SetOwner(favoriteToyButton, "ANCHOR_RIGHT")
                GameTooltip:SetText("Use " .. toyName, 1, 1, 1)
                GameTooltip:AddLine("Click to use toy directly", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        else
            GameTooltip:SetOwner(favoriteToyButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("No favorite toy selected", 1, 0.82, 0)
            GameTooltip:AddLine("Configure in Interface > AddOns > ColdSnap", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    favoriteToyButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Enable mouse clicks for secure actions
    favoriteToyButton:EnableMouse(true)
    favoriteToyButton:RegisterForClicks("AnyUp", "AnyDown")
end

function GameMenu:UpdateFavoriteToyButton()
    if not favoriteToyButton then
        return
    end
    
    local toyId = self.parent:GetConfig("gameMenu", "favoriteToyId")
    
    if toyId and PlayerHasToy(toyId) then
        -- Get toy info
        local _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyId)
        
        -- Set up a macro that uses the toy - this works with SecureActionButtonTemplate
        local macroText = "/usetoy " .. (toyName or toyId) .. "\n/run HideUIPanel(GameMenuFrame)"
        favoriteToyButton:SetAttribute("macrotext", macroText)
        
        -- Update the icon to match the actual toy
        if toyIcon then
            local iconTexture = favoriteToyButton:GetRegions()
            -- Find the icon texture (it's the overlay texture we created)
            for i = 1, select("#", favoriteToyButton:GetRegions()) do
                local region = select(i, favoriteToyButton:GetRegions())
                if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "OVERLAY" then
                    region:SetTexture(toyIcon)
                    break
                end
            end
        end
        
        self.parent:Debug("Updated secure toy button with macro for toyId: " .. toyId)
    else
        -- Clear the macro if none selected
        favoriteToyButton:SetAttribute("macrotext", "")
        self.parent:Debug("Cleared macro from secure button - no toy selected")
    end
end

function GameMenu:PositionFavoriteToyButton()
    if not favoriteToyButton then
        self.parent:Debug("PositionFavoriteToyButton called but button doesn't exist")
        return
    end
    
    self.parent:Debug("Positioning favorite toy button")
    
    -- Clear any existing anchor points
    favoriteToyButton:ClearAllPoints()
    
    -- Position at the top left corner of the GameMenuFrame with padding (opposite of reload button)
    favoriteToyButton:SetPoint("TOPLEFT", GameMenuFrame, "TOPLEFT", 12, -12)
    
    -- Ensure the button is clickable and visible
    favoriteToyButton:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    favoriteToyButton:EnableMouse(true)
    favoriteToyButton:Show()
    
    self.parent:Debug("Favorite toy button positioned and shown")
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
            if self.parent.modules.Config and self.parent.modules.Config.settingsCategory then
                Settings.OpenToCategory(self.parent.modules.Config.settingsCategory.ID)
            else
                self.parent:Print("Settings panel not available. Please access ColdSnap settings through Interface > AddOns.")
            end
        elseif InterfaceOptionsFrame_OpenToCategory then
            -- Legacy Interface Options (Classic)
            if self.parent.modules.Config and self.parent.modules.Config.optionsPanel then
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.Config.optionsPanel)
                InterfaceOptionsFrame_OpenToCategory(self.parent.modules.Config.optionsPanel) -- Call twice for proper focus
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

-- Register the module
ColdSnap:RegisterModule("GameMenu", GameMenu)
