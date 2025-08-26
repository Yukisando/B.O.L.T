-- ColdSnap Game Menu Module
-- Adds quality of life improvements to the game menu

local ADDON_NAME, ColdSnap = ...

-- Create the GameMenu module
local GameMenu = {}

-- Reference to the Leave Group button
local leaveGroupButton = nil
-- Reference to the Reload UI button
local reloadButton = nil

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

function GameMenu:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Small delay to ensure the menu is fully loaded
            C_Timer.After(0.05, function()
                self:UpdateGameMenu()
            end)
        end)
        
        GameMenuFrame:HookScript("OnHide", function()
            self:HideLeaveGroupButton()
            self:HideReloadButton()
        end)
    end
end

function GameMenu:UpdateGameMenu()
    if not self.parent:GetConfig("gameMenu", "showLeaveGroup") then
        return
    end
    
    -- Always show the reload button
    self:ShowReloadButton()
    
    -- Check if player is in a group
    if self.parent:IsInGroup() then
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
    
    -- Create the refresh icon using a simple text symbol
    local fontString = reloadButton:CreateFontString(nil, "OVERLAY")
    fontString:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    fontString:SetPoint("CENTER")
    fontString:SetTextColor(1, 0.82, 0, 1) -- Gold color
    fontString:SetText("R") -- Simple "R" for Reload
    
    -- Enable mouse interaction
    reloadButton:EnableMouse(true)
    reloadButton:SetMotionScriptsWhileDisabled(true)
    
    -- Set the click handler
    reloadButton:SetScript("OnClick", function()
        self:OnReloadClick()
    end)
    
    -- Add hover effects
    reloadButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(reloadButton, "ANCHOR_LEFT")
            GameTooltip:SetText("Reload UI", 1, 1, 1)
            GameTooltip:AddLine("Reloads the user interface", 0.8, 0.8, 0.8, true)
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
