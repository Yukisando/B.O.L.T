-- ColdSnap Playground Module
-- Fun features with limited practical use

local ADDON_NAME, ColdSnap = ...

-- Create the Playground module
local Playground = {}

-- Reference to the Favorite Toy button
local favoriteToyButton = nil

function Playground:OnInitialize()
    self.parent:Debug("Playground module initializing...")
end

function Playground:OnEnable()
    self.parent:Debug("Playground module OnEnable called")
    
    if not self.parent:IsModuleEnabled("playground") then
        self.parent:Debug("Playground module is disabled, skipping OnEnable")
        return
    end
    
    self.parent:Debug("Playground module enabling...")
    
    -- Hook into the game menu show event
    self:HookGameMenu()
end

function Playground:OnDisable()
    -- Clean up buttons when disabling
    if favoriteToyButton then
        favoriteToyButton:Hide()
        favoriteToyButton = nil
    end
end

function Playground:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Check if we're in combat or a protected state before proceeding
            if InCombatLockdown() then
                -- Defer the update until after combat
                local frame = CreateFrame("Frame")
                frame:RegisterEvent("PLAYER_REGEN_ENABLED")
                frame:SetScript("OnEvent", function(eventFrame)
                    eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
                    self:UpdateGameMenu()
                    eventFrame:SetScript("OnEvent", nil)
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
                self:HideFavoriteToyButton()
            end
        end)
    end
end

function Playground:UpdateGameMenu()
    self.parent:Debug("Playground UpdateGameMenu called")
    
    if not self.parent:GetConfig("playground", "enabled") then
        self.parent:Debug("Playground module disabled in config")
        return
    end
    
    -- Don't update UI elements during combat
    if InCombatLockdown() then
        self.parent:Debug("In combat, skipping Playground UI update")
        return
    end
    
    -- Show favorite toy button if enabled
    if self.parent:GetConfig("playground", "showFavoriteToy") then
        self.parent:Debug("Showing favorite toy button")
        self:ShowFavoriteToyButton()
    else
        self.parent:Debug("Hiding favorite toy button (config disabled)")
        self:HideFavoriteToyButton()
    end
end

function Playground:ShowFavoriteToyButton()
    self.parent:Debug("ShowFavoriteToyButton called")
    
    -- Create the button if it doesn't exist
    if not favoriteToyButton then
        self.parent:Debug("Creating favorite toy button")
        self:CreateFavoriteToyButton()
    end
    
    -- Update the secure button with the current toy
    self:UpdateFavoriteToyButton()
    
    -- Always enable the button so it's clickable - the secure action will handle usability
    local toyId = self.parent:GetConfig("playground", "favoriteToyId")
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
    
    self.parent:Debug("Favorite toy button shown and positioned")
end

function Playground:HideFavoriteToyButton()
    if favoriteToyButton then
        favoriteToyButton:Hide()
    end
end

function Playground:CreateFavoriteToyButton()
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
        local toyId = self.parent:GetConfig("playground", "favoriteToyId")
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

function Playground:UpdateFavoriteToyButton()
    if not favoriteToyButton then
        return
    end
    
    local toyId = self.parent:GetConfig("playground", "favoriteToyId")
    
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

function Playground:PositionFavoriteToyButton()
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

-- Register the module
ColdSnap:RegisterModule("playground", Playground)
