-- ColdSnap Mythic Plus Module
-- Adds quality of life improvements for Mythic Plus dungeons

local ADDON_NAME, ColdSnap = ...

-- Create the MythicPlus module
local MythicPlus = {}

-- References to the buttons
local readyCheckButton = nil
local countdownButton = nil

function MythicPlus:OnInitialize()
    self.parent:Debug("MythicPlus module initializing...")
end

function MythicPlus:OnEnable()
    if not self.parent:IsModuleEnabled("mythicPlus") then
        return
    end
    
    self.parent:Debug("MythicPlus module enabling...")
    
    -- Ensure the Blizzard_ChallengesUI addon is loaded
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") or IsAddOnLoaded and IsAddOnLoaded("Blizzard_ChallengesUI")
    if not isLoaded then
        self.parent:Debug("MythicPlus: Loading Blizzard_ChallengesUI addon")
        if C_AddOns and C_AddOns.LoadAddOn then
            C_AddOns.LoadAddOn("Blizzard_ChallengesUI")
        elseif LoadAddOn then
            LoadAddOn("Blizzard_ChallengesUI")
        end
    end
    
    -- Hook into the keystone window
    self:HookKeystoneWindow()
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

function MythicPlus:HookKeystoneWindow()
    -- Hook the ChallengesKeystoneFrame show event (try multiple possible frame names)
    local keystoneFrame = ChallengesKeystoneFrame or _G["ChallengesKeystoneFrame"]
    
    if not keystoneFrame then
        -- If the frame isn't loaded yet, hook into the addon loaded event
        local loadFrame = CreateFrame("Frame")
        loadFrame:RegisterEvent("ADDON_LOADED")
        loadFrame:SetScript("OnEvent", function(frame, event, addonName)
            if addonName == "Blizzard_ChallengesUI" then
                keystoneFrame = ChallengesKeystoneFrame or _G["ChallengesKeystoneFrame"]
                if keystoneFrame then
                    self:HookKeystoneWindowEvents(keystoneFrame)
                    loadFrame:UnregisterEvent("ADDON_LOADED")
                    self.parent:Debug("MythicPlus: Successfully hooked keystone frame after Blizzard_ChallengesUI load")
                end
            end
        end)
        self.parent:Debug("MythicPlus: Keystone frame not found, waiting for Blizzard_ChallengesUI to load")
        return
    end
    
    self:HookKeystoneWindowEvents(keystoneFrame)
    self.parent:Debug("MythicPlus: Successfully hooked keystone frame immediately")
end

function MythicPlus:HookKeystoneWindowEvents(keystoneFrame)
    keystoneFrame:HookScript("OnShow", function()
        -- Check if we're in combat before proceeding
        if InCombatLockdown() then
            -- Defer the update until after combat
            local frame = CreateFrame("Frame")
            frame:RegisterEvent("PLAYER_REGEN_ENABLED")
            frame:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                MythicPlus:UpdateKeystoneWindow()
                self:SetScript("OnEvent", nil)
            end)
        else
            -- Small delay to ensure the window is fully loaded
            C_Timer.After(0.05, function()
                if not InCombatLockdown() then
                    self:UpdateKeystoneWindow()
                end
            end)
        end
    end)
    
    keystoneFrame:HookScript("OnHide", function()
        -- Only hide buttons if not in combat
        if not InCombatLockdown() then
            self:HideButtons()
        end
    end)
    
    -- Store reference to the keystone frame for later use
    self.keystoneFrame = keystoneFrame
end

function MythicPlus:UpdateKeystoneWindow()
    if not self.parent:GetConfig("mythicPlus", "enabled") then
        return
    end
    
    -- Don't update UI elements during combat
    if InCombatLockdown() then
        return
    end
    
    -- Show buttons if enabled
    if self.parent:GetConfig("mythicPlus", "showReadyCheckButton") then
        self:ShowButtons()
    else
        self:HideButtons()
    end
end

function MythicPlus:ShowButtons()
    -- Create the buttons if they don't exist
    if not readyCheckButton then
        self:CreateReadyCheckButton()
    end
    if not countdownButton then
        self:CreateCountdownButton()
    end
    
    readyCheckButton:Show()
    countdownButton:Show()
    
    -- Position the buttons
    self:PositionButtons()
end

function MythicPlus:HideButtons()
    if readyCheckButton then
        readyCheckButton:Hide()
    end
    if countdownButton then
        countdownButton:Hide()
    end
end

function MythicPlus:CreateReadyCheckButton()
    -- Use stored keystone frame reference or fallback to global
    local parent = self.keystoneFrame or ChallengesKeystoneFrame or UIParent
    if parent == UIParent then
        self.parent:Debug("MythicPlus: Warning - using UIParent as parent for buttons")
    end
    
    -- Create a button with the same style as GameMenu buttons
    readyCheckButton = CreateFrame("Button", "ColdSnapReadyCheckButton", parent)
    
    -- Create textures manually to match game menu buttons
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
    
    -- Set button properties to match other game menu buttons but smaller for icons
    readyCheckButton:SetSize(32, 32)
    
    -- Create the ready check icon
    local iconTexture = readyCheckButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("CENTER")
    
    -- If the ready check texture doesn't exist, fallback to a different one
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\Ability_Warrior_RallyingCry")
        iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
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
end

function MythicPlus:CreateCountdownButton()
    -- Use stored keystone frame reference or fallback to global
    local parent = self.keystoneFrame or ChallengesKeystoneFrame or UIParent
    
    -- Create a button with the same style as GameMenu buttons
    countdownButton = CreateFrame("Button", "ColdSnapCountdownButton", parent)
    
    -- Create textures manually to match game menu buttons
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
    
    -- Set button properties to match other game menu buttons but smaller for icons
    countdownButton:SetSize(32, 32)
    
    -- Create the countdown icon
    local iconTexture = countdownButton:CreateTexture(nil, "OVERLAY")
    iconTexture:SetTexture("Interface\\Icons\\Spell_Holy_BorrowedTime")
    iconTexture:SetSize(24, 24)
    iconTexture:SetPoint("CENTER")
    iconTexture:SetTexCoord(0.1, 0.9, 0.1, 0.9) -- Crop the icon a bit
    
    -- If that texture doesn't exist, fallback to a different one
    if not iconTexture:GetTexture() then
        iconTexture:SetTexture("Interface\\Icons\\Ability_Warrior_Shout")
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
            GameTooltip:SetText("Countdown Timer", 1, 1, 1)
            GameTooltip:AddLine("Start a 5-second countdown for your group", 0.8, 0.8, 0.8, true)
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
end

function MythicPlus:PositionButtons()
    if not readyCheckButton or not countdownButton then
        return
    end
    
    -- Use stored keystone frame reference or fallback to global
    local parent = self.keystoneFrame or ChallengesKeystoneFrame or UIParent
    
    -- Clear any existing anchor points
    readyCheckButton:ClearAllPoints()
    countdownButton:ClearAllPoints()
    
    -- Position the buttons centered at the top of the keystone window with padding
    -- Calculate center position for both buttons together (64px total width + 5px gap = 69px total)
    local totalWidth = 69 -- 32 + 5 + 32
    local startX = -(totalWidth / 2) + 16 -- Center offset plus half button width
    
    readyCheckButton:SetPoint("TOP", parent, "TOP", startX, -20)
    countdownButton:SetPoint("LEFT", readyCheckButton, "RIGHT", 5, 0)
    
    -- Ensure the buttons are clickable and visible
    readyCheckButton:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 2)
    countdownButton:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 2)
    readyCheckButton:EnableMouse(true)
    countdownButton:EnableMouse(true)
end

function MythicPlus:OnReadyCheckClick()
    -- Initiate a ready check
    if IsInGroup() and (IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            DoReadyCheck()
            self.parent:Debug("Ready check initiated")
        else
            self.parent:Print("You must be the group leader or have assist to start a ready check.")
        end
    else
        self.parent:Print("You must be in a group to start a ready check.")
    end
end

function MythicPlus:OnCountdownClick()
    -- Start a 5-second countdown
    if IsInGroup() and (IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_HOME)) then
        if UnitIsGroupLeader("player") or UnitIsGroupAssistant("player") then
            C_PartyInfo.DoCountdown(5)
            self.parent:Debug("Countdown initiated")
        else
            self.parent:Print("You must be the group leader or have assist to start a countdown.")
        end
    else
        self.parent:Print("You must be in a group to start a countdown.")
    end
end

-- Register the module
ColdSnap:RegisterModule("mythicPlus", MythicPlus)
