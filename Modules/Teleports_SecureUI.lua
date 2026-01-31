-- B.O.L.T Teleports Secure UI
-- BACKUP/FALLBACK secure button for teleport execution
-- Primary method is now direct-click pins (see Teleports_PinMixin.lua)
-- This module provides a popup fallback and utility functions

local ADDON_NAME, BOLT = ...

local SecureUI = {}

-- Fallback secure button (only used if pin click fails)
local SecureButton = nil
local TeleportPopup = nil

-- Initialize secure UI (called on PLAYER_LOGIN)
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

-- Create fallback secure button
function SecureUI:CreateSecureButton()
    if SecureButton then return SecureButton end
    
    SecureButton = CreateFrame("Button", "BOLTTeleportSecureButton", UIParent, "SecureActionButtonTemplate")
    SecureButton:SetSize(1, 1)
    SecureButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    SecureButton:RegisterForClicks("AnyUp", "AnyDown")
    SecureButton:Hide()
    
    SecureButton:SetScript("PostClick", function()
        if TeleportPopup then
            TeleportPopup:Hide()
        end
    end)
    
    return SecureButton
end

-- Create simple teleport popup (fallback UI)
function SecureUI:CreateTeleportPopup()
    if TeleportPopup then return TeleportPopup end
    
    local popup = CreateFrame("Frame", "BOLTTeleportPopup", UIParent, "BackdropTemplate")
    popup:SetSize(280, 140)
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

    popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    popup.title:SetPoint("TOP", 0, -16)
    popup.title:SetText("Teleport")

    popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    popup.text:SetPoint("TOP", popup.title, "BOTTOM", 0, -10)
    popup.text:SetWidth(250)
    popup.text:SetJustifyH("CENTER")

    local visualBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    visualBtn:SetSize(120, 26)
    visualBtn:SetPoint("BOTTOM", 0, 16)
    visualBtn:SetText("Teleport")
    popup.visualButton = visualBtn
    
    SecureButton:SetParent(popup)
    SecureButton:ClearAllPoints()
    SecureButton:SetAllPoints(visualBtn)
    SecureButton:SetFrameStrata("DIALOG")
    SecureButton:SetFrameLevel(visualBtn:GetFrameLevel() + 10)
    
    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -5, -5)

    tinsert(UISpecialFrames, "BOLTTeleportPopup")
    
    popup:SetScript("OnShow", function(self)
        SecureButton:Show()
        visualBtn:SetEnabled(not InCombatLockdown())
    end)
    
    popup:SetScript("OnHide", function(self)
        SecureButton:Hide()
    end)

    TeleportPopup = popup
    return popup
end

-- Prepare secure attributes for fallback button
function SecureUI:PrepareTeleport(entry)
    if not entry or InCombatLockdown() then return false end
    
    if not SecureButton then
        self:Initialize()
        if not SecureButton then return false end
    end
    
    SecureButton:SetAttribute("type", nil)
    SecureButton:SetAttribute("spell", nil)
    SecureButton:SetAttribute("item", nil)
    SecureButton:SetAttribute("toy", nil)
    SecureButton:SetAttribute("macrotext", nil)
    
    if entry.type == "spell" and entry.id then
        SecureButton:SetAttribute("type", "spell")
        SecureButton:SetAttribute("spell", entry.id)
    elseif entry.type == "item" and entry.id then
        SecureButton:SetAttribute("type", "item")
        SecureButton:SetAttribute("item", "item:" .. entry.id)
    elseif entry.type == "toy" and entry.id then
        SecureButton:SetAttribute("type", "toy")
        SecureButton:SetAttribute("toy", entry.id)
    end
    
    return true
end

-- Show fallback popup (rarely needed now that pins are secure buttons)
function SecureUI:ShowPopup(entry)
    if not entry then return end
    
    if not TeleportPopup then
        self:Initialize()
    end
    if not TeleportPopup then return end
    
    self:PrepareTeleport(entry)
    
    local displayName = entry.name or "Unknown"
    local typeLabel = entry.type and (entry.type:sub(1,1):upper() .. entry.type:sub(2)) or "Unknown"
    TeleportPopup.text:SetText(string.format("|cff00ff00%s|r\n|cff888888(%s)|r", displayName, typeLabel))
    TeleportPopup:Show()
end

function SecureUI:HidePopup()
    if TeleportPopup then TeleportPopup:Hide() end
end

function SecureUI:IsPopupShown()
    return TeleportPopup and TeleportPopup:IsShown()
end

function SecureUI:GetSecureButton()
    return SecureButton
end

BOLT.TeleportSecureUI = SecureUI

return SecureUI
