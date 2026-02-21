-- B.O.L.T Teleports Secure UI
-- Contains the ONLY secure button for teleport execution
-- This file owns ALL secure teleport functionality

local ADDON_NAME, BOLT = ...

local SecureUI = {}

-- The ONE and ONLY secure button (created once on login, never recreated)
local SecureButton = nil
local TeleportPopup = nil

-- Initialize secure UI (MUST be called out of combat, typically on PLAYER_LOGIN)
function SecureUI:Initialize()
    if SecureButton then return end  -- Already initialized
    
    if InCombatLockdown() then
        -- Defer initialization until combat ends
        local waitFrame = CreateFrame("Frame")
        waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        waitFrame:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            SecureUI:Initialize()
        end)
        return
    end
    
    self:CreateSecureButton()
    self:CreateTeleportPopup()
end

-- Create the ONE secure button (never call this more than once)
function SecureUI:CreateSecureButton()
    if SecureButton then return SecureButton end
    
    SecureButton = CreateFrame(
        "Button",
        "BOLTTeleportSecureButton",
        UIParent,
        "SecureActionButtonTemplate"
    )
    SecureButton:SetSize(1, 1)
    SecureButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    SecureButton:RegisterForClicks("AnyUp", "AnyDown")
    SecureButton:Hide()
    
    -- Post-click handler to hide popup (runs after secure action)
    SecureButton:SetScript("PostClick", function()
        if TeleportPopup then
            TeleportPopup:Hide()
        end
    end)
    
    return SecureButton
end

-- Create the teleport confirmation popup (normal frame, NOT secure)
function SecureUI:CreateTeleportPopup()
    if TeleportPopup then return TeleportPopup end
    
    local popup = CreateFrame("Frame", "BOLTTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(280, 160)
    popup:SetPoint("CENTER")
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    popup:SetBackdropColor(0, 0, 0, 1)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    -- Title
    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", 0, -16)
    popup.title:SetText("Confirm Teleport")

    -- Teleport name/info text
    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.text:SetPoint("TOP", popup.title, "BOTTOM", 0, -10)
    popup.text:SetWidth(250)
    popup.text:SetJustifyH("CENTER")
    popup.text:SetText("")
    
    -- Combat warning text (hidden by default)
    popup.combatWarning = popup:CreateFontString(nil, "OVERLAY", "GameFontRed")
    popup.combatWarning:SetPoint("TOP", popup.text, "BOTTOM", 0, -5)
    popup.combatWarning:SetWidth(250)
    popup.combatWarning:SetText("Cannot teleport during combat!")
    popup.combatWarning:Hide()

    -- Visual button (the visible UI element)
    local visualBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    visualBtn:SetSize(120, 26)
    visualBtn:SetPoint("BOTTOM", 0, 16)
    visualBtn:SetText("Teleport")
    popup.visualButton = visualBtn
    
    -- Position the secure button ON TOP of the visual button
    -- The secure button is what actually gets clicked
    SecureButton:SetParent(popup)
    SecureButton:ClearAllPoints()
    SecureButton:SetAllPoints(visualBtn)
    SecureButton:SetFrameStrata("DIALOG")
    SecureButton:SetFrameLevel(visualBtn:GetFrameLevel() + 10)
    
    -- Close button
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    -- ESC to close
    tinsert(UISpecialFrames, "BOLTTeleportPopup")
    
    -- Update button state based on combat
    popup:RegisterEvent("PLAYER_REGEN_DISABLED")
    popup:RegisterEvent("PLAYER_REGEN_ENABLED")
    popup:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Entered combat - disable visual feedback
            visualBtn:SetEnabled(false)
            popup.combatWarning:Show()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Left combat - re-enable if popup is shown
            visualBtn:SetEnabled(true)
            popup.combatWarning:Hide()
        end
    end)
    
    popup:SetScript("OnShow", function(self)
        -- Show secure button when popup shows
        SecureButton:Show()
        
        -- Update combat state
        if InCombatLockdown() then
            visualBtn:SetEnabled(false)
            popup.combatWarning:Show()
        else
            visualBtn:SetEnabled(true)
            popup.combatWarning:Hide()
        end
    end)
    
    popup:SetScript("OnHide", function(self)
        -- Hide secure button when popup hides
        SecureButton:Hide()
    end)

    TeleportPopup = popup
    return popup
end

-- Prepare a teleport (sets secure attributes) - MUST be called out of combat
function SecureUI:PrepareTeleport(entry)
    if not entry then return false end
    
    if InCombatLockdown() then
        if BOLT.Print then
            BOLT:Print("Cannot prepare teleport during combat.")
        end
        return false
    end
    
    if not SecureButton then
        self:Initialize()
        if not SecureButton then
            return false
        end
    end
    
    -- Clear all previous attributes
    SecureButton:SetAttribute("type", nil)
    SecureButton:SetAttribute("spell", nil)
    SecureButton:SetAttribute("item", nil)
    SecureButton:SetAttribute("macrotext", nil)
    
    -- Set new attributes based on entry type
    if entry.type == "spell" then
        SecureButton:SetAttribute("type", "spell")
        SecureButton:SetAttribute("spell", entry.id)
        
    elseif entry.type == "item" then
        SecureButton:SetAttribute("type", "macro")
        SecureButton:SetAttribute("macrotext", "/use item:" .. entry.id)
        
    elseif entry.type == "toy" then
        SecureButton:SetAttribute("type", "macro")
        SecureButton:SetAttribute("macrotext", "/use item:" .. entry.id)
    end
    
    return true
end

-- Show the teleport popup for a given entry
function SecureUI:ShowPopup(entry)
    if not entry then return end
    
    -- Initialize if needed
    if not TeleportPopup then
        self:Initialize()
    end
    
    if not TeleportPopup then return end
    
    -- Prepare secure attributes (if not in combat)
    local prepared = self:PrepareTeleport(entry)
    
    -- Update popup text
    local displayName = entry.name or "Unknown"
    local typeLabel = entry.type and (entry.type:sub(1,1):upper() .. entry.type:sub(2)) or "Unknown"
    TeleportPopup.text:SetText(string.format("Teleport to:\n|cff00ff00%s|r\n|cff888888(%s)|r", displayName, typeLabel))
    
    -- Show the popup
    TeleportPopup:Show()
    
    if not prepared and InCombatLockdown() then
        TeleportPopup.combatWarning:Show()
        TeleportPopup.visualButton:SetEnabled(false)
    end
end

-- Hide the teleport popup
function SecureUI:HidePopup()
    if TeleportPopup then
        TeleportPopup:Hide()
    end
end

-- Check if popup is shown
function SecureUI:IsPopupShown()
    return TeleportPopup and TeleportPopup:IsShown()
end

-- Get the secure button (for external reference if needed)
function SecureUI:GetSecureButton()
    return SecureButton
end

-- Register module
BOLT.TeleportSecureUI = SecureUI

return SecureUI
