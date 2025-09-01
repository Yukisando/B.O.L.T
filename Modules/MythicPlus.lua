-- ColdSnap Mythic Plus Module
-- Enhancements for Mythic+ dungeons and keystone management

local ADDON_NAME, ColdSnap = ...

-- Create the MythicPlus module
local MythicPlus = {}

-- References to the buttons
local readyCheckButton = nil
local countdownButton = nil

-- Store reference to the keystone frame
local keystoneFrame = nil

function MythicPlus:OnInitialize()
    self.parent:Debug("MythicPlus module initializing...")
end

function MythicPlus:OnEnable()
    self.parent:Debug("MythicPlus module OnEnable called")
    
    if not self.parent:IsModuleEnabled("mythicPlus") then
        self.parent:Debug("MythicPlus module is disabled, skipping OnEnable")
        return
    end
    
    self.parent:Debug("MythicPlus module enabling...")
    
    -- Hook into the keystone frame events
    self:HookKeystoneFrame()
end

function MythicPlus:OnDisable()
    -- Clean up buttons when disabling
    if readyCheckButton then
        readyCheckButton:Hide()
        readyCheckButton = nil
    end
    if countdownButton then
        countdownButton:Hide()
        countdownButton = nil
    end
end

function MythicPlus:HookKeystoneFrame()
    -- We need to hook into the Challenge Mode frame
    -- The keystone socket frame is part of ChallengesKeystoneFrame
    if not ChallengesKeystoneFrame then
        self.parent:Debug("ChallengesKeystoneFrame not found, creating delayed hook")
        -- Create a frame to wait for the UI to load
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("ADDON_LOADED")
        waitFrame:SetScript("OnEvent", function(frame, event, addonName)
            if addonName == "Blizzard_ChallengesUI" or ChallengesKeystoneFrame then
                frame:UnregisterEvent("ADDON_LOADED")
                self:SetupKeystoneHooks()
            end
        end)
        return
    end
    
    self:SetupKeystoneHooks()
end

function MythicPlus:SetupKeystoneHooks()
    if not ChallengesKeystoneFrame then
        self.parent:Debug("ChallengesKeystoneFrame still not available")
        return
    end
    
    keystoneFrame = ChallengesKeystoneFrame
    
    -- Hook the frame show event
    keystoneFrame:HookScript("OnShow", function()
        self.parent:Debug("Keystone frame shown")
        -- Check if we're in combat before proceeding
        if InCombatLockdown() then
            self.parent:Debug("In combat, deferring keystone button creation")
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function(eventFrame)
                eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:UpdateKeystoneFrame()
                eventFrame:SetScript("OnEvent", nil)
            end)
        else
            -- Small delay to ensure the frame is fully loaded
            C_Timer.After(0.1, function()
                if not InCombatLockdown() then
                    self:UpdateKeystoneFrame()
                end
            end)
        end
    end)
    
    keystoneFrame:HookScript("OnHide", function()
        self.parent:Debug("Keystone frame hidden")
        -- Only hide buttons if not in combat
        if not InCombatLockdown() then
            self:HideKeystoneButtons()
        end
    end)
    
    self.parent:Debug("Keystone frame hooks installed")
end

function MythicPlus:UpdateKeystoneFrame()
    self.parent:Debug("MythicPlus UpdateKeystoneFrame called")
    
    if not self.parent:GetConfig("mythicPlus", "enabled") then
        self.parent:Debug("MythicPlus module disabled in config")
        return
    end
    
    -- Don't update UI elements during combat
    if InCombatLockdown() then
        self.parent:Debug("In combat, skipping MythicPlus UI update")
        return
    end
    
    -- Show keystone buttons if enabled
    if self.parent:GetConfig("mythicPlus", "showKeystoneButtons") then
        self.parent:Debug("Showing keystone buttons")
        self:ShowKeystoneButtons()
    else
        self.parent:Debug("Hiding keystone buttons (config disabled)")
        self:HideKeystoneButtons()
    end
end

function MythicPlus:ShowKeystoneButtons()
    -- Create the buttons if they don't exist
    if not readyCheckButton then
        self:CreateReadyCheckButton()
    end
    if not countdownButton then
        self:CreateCountdownButton()
    end
    
    -- Position and show the buttons
    self:PositionKeystoneButtons()
    if readyCheckButton then
        readyCheckButton:Show()
    end
    if countdownButton then
        countdownButton:Show()
    end
    
    self.parent:Debug("Keystone buttons shown and positioned")
end

function MythicPlus:HideKeystoneButtons()
    if readyCheckButton then
        readyCheckButton:Hide()
    end
    if countdownButton then
        countdownButton:Hide()
    end
end

function MythicPlus:CreateReadyCheckButton()
    -- Create a button similar to the game menu buttons
    readyCheckButton = CreateFrame("Button", "ColdSnapReadyCheckButton", keystoneFrame)
    
    -- Create textures manually to match other buttons
    local normalTexture = readyCheckButton:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    readyCheckButton:SetNormalTexture(normalTexture)
    
    local pushedTexture = readyCheckButton:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    readyCheckButton:SetPushedTexture(pushedTexture)
    
    local highlightTexture = readyCheckButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    highlightTexture:SetBlendMode("ADD")
    readyCheckButton:SetHighlightTexture(highlightTexture)
    
    -- Set button properties - small square size
    readyCheckButton:SetSize(28, 28)
    
    -- Create the ready check icon
    local iconTexture = readyCheckButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\Icons\\Spell_Shadow_Charm")  -- Ready check icon
    iconTexture:SetSize(20, 20)
    iconTexture:SetPoint("CENTER")
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
    
    -- If that icon doesn't exist, use a fallback
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\Ability_DualWield")
        iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    
    -- Enable mouse interaction
    readyCheckButton:EnableMouse(true)
    readyCheckButton:SetMotionScriptsWhileDisabled(true)
    
    -- Set the click handler
    readyCheckButton:SetScript("OnClick", function()
        self:OnReadyCheckClick()
    end)
    
    -- Add hover effects
    readyCheckButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(readyCheckButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Ready Check", 1, 1, 1)
            GameTooltip:AddLine("Start a ready check for your group", 0.8, 0.8, 0.8, true)
            if not UnitIsGroupLeader("player") then
                GameTooltip:AddLine("You must be group leader to use this", 1, 0.5, 0.5, true)
            end
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    readyCheckButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    
    -- Add click sound
    readyCheckButton:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
    
    self.parent:Debug("Ready check button created")
end

function MythicPlus:CreateCountdownButton()
    -- Create a button similar to the ready check button
    countdownButton = CreateFrame("Button", "ColdSnapCountdownButton", keystoneFrame)
    
    -- Create textures manually to match other buttons
    local normalTexture = countdownButton:CreateTexture(nil, "BACKGROUND")
    normalTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    normalTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    normalTexture:SetAllPoints()
    countdownButton:SetNormalTexture(normalTexture)
    
    local pushedTexture = countdownButton:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Down")
    pushedTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    pushedTexture:SetAllPoints()
    countdownButton:SetPushedTexture(pushedTexture)
    
    local highlightTexture = countdownButton:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
    highlightTexture:SetTexCoord(0, 0.625, 0, 0.6875)
    highlightTexture:SetAllPoints()
    highlightTexture:SetBlendMode("ADD")
    countdownButton:SetHighlightTexture(highlightTexture)
    
    -- Set button properties - small square size
    countdownButton:SetSize(28, 28)
    
    -- Create the countdown icon
    local iconTexture = countdownButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")  -- Timer/countdown icon
    iconTexture:SetSize(20, 20)
    iconTexture:SetPoint("CENTER")
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
    
    -- If that icon doesn't exist, use a fallback
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\Ability_Warrior_WarCry")
        iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    
    -- Enable mouse interaction
    countdownButton:EnableMouse(true)
    countdownButton:SetMotionScriptsWhileDisabled(true)
    
    -- Set the click handler
    countdownButton:SetScript("OnClick", function()
        self:OnCountdownClick()
    end)
    
    -- Add hover effects
    countdownButton:SetScript("OnEnter", function()
        if GameTooltip then
            GameTooltip:SetOwner(countdownButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("Start Countdown", 1, 1, 1)
            GameTooltip:AddLine("Start a 5-second countdown", 0.8, 0.8, 0.8, true)
            if not UnitIsGroupLeader("player") then
                GameTooltip:AddLine("You must be group leader to use this", 1, 0.5, 0.5, true)
            end
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    countdownButton:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    
    -- Add click sound
    countdownButton:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
    
    self.parent:Debug("Countdown button created")
end

function MythicPlus:PositionKeystoneButtons()
    if not readyCheckButton or not countdownButton then
        return
    end
    
    -- Clear any existing anchor points
    readyCheckButton:ClearAllPoints()
    countdownButton:ClearAllPoints()
    
    -- Position at the top left of the keystone frame with some padding
    readyCheckButton:SetPoint("TOPLEFT", keystoneFrame, "TOPLEFT", 12, -12)
    countdownButton:SetPoint("LEFT", readyCheckButton, "RIGHT", 8, 0)
    
    -- Ensure the buttons are clickable and visible
    if readyCheckButton and keystoneFrame then
        readyCheckButton:SetFrameLevel(keystoneFrame:GetFrameLevel() + 2)
        readyCheckButton:EnableMouse(true)
    end
    if countdownButton and keystoneFrame then
        countdownButton:SetFrameLevel(keystoneFrame:GetFrameLevel() + 2)
        countdownButton:EnableMouse(true)
    end
    
    self.parent:Debug("Keystone buttons positioned")
end

function MythicPlus:OnReadyCheckClick()
    -- Check if player is group leader
    if not UnitIsGroupLeader("player") then
        self.parent:Print("You must be the group leader to start a ready check.")
        return
    end
    
    -- Check if we're in a group
    if not self.parent:IsInGroup() then
        self.parent:Print("You must be in a group to start a ready check.")
        return
    end
    
    -- Start the ready check
    DoReadyCheck()
    self.parent:Print("Ready check started!")
end

function MythicPlus:OnCountdownClick()
    -- Check if player is group leader
    if not UnitIsGroupLeader("player") then
        self.parent:Print("You must be the group leader to start a countdown.")
        return
    end
    
    -- Check if we're in a group
    if not self.parent:IsInGroup() then
        self.parent:Print("You must be in a group to start a countdown.")
        return
    end
    
    -- Start a 5-second countdown using the built-in countdown system
    if C_PartyInfo and C_PartyInfo.DoCountdown then
        C_PartyInfo.DoCountdown(5)
        self.parent:Print("5-second countdown started!")
    else
        -- Fallback: manual countdown in chat
        self:DoManualCountdown()
    end
end

function MythicPlus:DoManualCountdown()
    -- Manual countdown implementation as fallback
    self.parent:Print("Starting countdown...")
    self.parent:Print("Pull in 5...")
    
    C_Timer.After(1, function()
        self.parent:Print("4...")
    end)
    
    C_Timer.After(2, function()
        self.parent:Print("3...")
    end)
    
    C_Timer.After(3, function()
        self.parent:Print("2...")
    end)
    
    C_Timer.After(4, function()
        self.parent:Print("1...")
    end)
    
    C_Timer.After(5, function()
        self.parent:Print("GO!")
    end)
end

-- Register the module
ColdSnap:RegisterModule("mythicPlus", MythicPlus)
