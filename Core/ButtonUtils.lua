-- B.O.L.T Button Utilities (Brittle and Occasionally Lethal Tweaks)
-- Shared button creation and styling functions

local ADDON_NAME, BOLT = ...

-- Create the ButtonUtils module
local ButtonUtils = {}

-- Standard button configuration
local BUTTON_CONFIG = {
    size = 28,
    iconSize = 20,
    borderSize = 32, -- Reduced from 52 to fix oversized border issue
    borderAlpha = 0.3,
    iconCrop = 0.07
}

-- Create a standard square icon button
function ButtonUtils:CreateIconButton(name, parent, iconPath, options)
    options = options or {}
    
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(BUTTON_CONFIG.size, BUTTON_CONFIG.size)
    
    -- Create a subtle rounded background that fits perfectly
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    background:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size for consistency
    background:SetPoint("CENTER")
    background:SetTexCoord(0.2, 0.8, 0.2, 0.8) -- Crop to make it fit better
    background:SetVertexColor(0.8, 0.8, 0.8, 0.3) -- Much lighter and more transparent
    btn:SetNormalTexture(background)
    
    -- Create a clean border
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize)
    border:SetPoint("CENTER")
    border:SetVertexColor(0.8, 0.8, 0.8, BUTTON_CONFIG.borderAlpha)
    btn.border = border
    
    -- Create the pushed texture
    local pushedTexture = btn:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushedTexture:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size
    pushedTexture:SetPoint("CENTER")
    btn:SetPushedTexture(pushedTexture)

    -- Create the highlight texture
    local highlightTexture = btn:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlightTexture:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size
    highlightTexture:SetPoint("CENTER")
    highlightTexture:SetBlendMode("ADD")
     
    -- Apply custom highlight color if specified
    if options.highlightColor then
        highlightTexture:SetVertexColor(unpack(options.highlightColor))
    end
    btn:SetHighlightTexture(highlightTexture)

    -- Create the icon with proper sizing and positioning
    if iconPath then
        local iconTexture = btn:CreateTexture(nil, "ARTWORK")
        iconTexture:SetTexture(iconPath)
        iconTexture:SetSize(BUTTON_CONFIG.iconSize, BUTTON_CONFIG.iconSize)
        iconTexture:SetPoint("CENTER")
        iconTexture:SetTexCoord(BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop, BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop)
        btn.icon = iconTexture
    end

    -- Standard mouse and sound interactions
    btn:EnableMouse(true)
    btn:SetMotionScriptsWhileDisabled(true)
    btn:SetScript("OnMouseDown", function()
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end
    end)
    
    return btn
end

-- Create a volume button with special styling to indicate mouse wheel interaction
function ButtonUtils:CreateVolumeButton(name, parent)
    local btn = self:CreateIconButton(name, parent, "Interface\\Icons\\Spell_Shadow_SoundDamp", {
        highlightColor = {1, 1, 0.5} -- Yellow highlight to indicate scroll functionality
    })
    
    -- Apply special border coloring for volume button
    if btn.border then
        btn.border:SetVertexColor(0.9, 0.9, 0.4, 0.4) -- Yellow tint to indicate special interaction
    end
    
    -- Adjust icon texture coordinates for volume icon
    if btn.icon then
        btn.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    end
    
    return btn
end

-- Create a secure action button (for toys, spells, etc.)
function ButtonUtils:CreateSecureActionButton(name, parent, iconPath)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_CONFIG.size, BUTTON_CONFIG.size)
    
    -- Create a subtle rounded background that fits perfectly
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\UI-EmptySlot")
    background:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size for consistency
    background:SetPoint("CENTER")
    background:SetTexCoord(0.2, 0.8, 0.2, 0.8) -- Crop to make it fit better
    background:SetVertexColor(0.8, 0.8, 0.8, 0.3) -- Much lighter and more transparent
    btn:SetNormalTexture(background)
    
    -- Create a clean border
    local border = btn:CreateTexture(nil, "BORDER")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize)
    border:SetPoint("CENTER")
    border:SetVertexColor(0.8, 0.8, 0.8, BUTTON_CONFIG.borderAlpha)
    btn.border = border
    
    -- Create the pushed texture
    local pushedTexture = btn:CreateTexture(nil, "BACKGROUND")
    pushedTexture:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushedTexture:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size
    pushedTexture:SetPoint("CENTER")
    btn:SetPushedTexture(pushedTexture)

    -- Create the highlight texture
    local highlightTexture = btn:CreateTexture(nil, "HIGHLIGHT")
    highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlightTexture:SetSize(BUTTON_CONFIG.borderSize, BUTTON_CONFIG.borderSize) -- Match border size
    highlightTexture:SetPoint("CENTER")
    highlightTexture:SetBlendMode("ADD")
    btn:SetHighlightTexture(highlightTexture)

    -- Create the icon with proper sizing and positioning
    if iconPath then
        local iconTexture = btn:CreateTexture(nil, "ARTWORK")
        iconTexture:SetTexture(iconPath)
        iconTexture:SetSize(BUTTON_CONFIG.iconSize, BUTTON_CONFIG.iconSize)
        iconTexture:SetPoint("CENTER")
        iconTexture:SetTexCoord(BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop, BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop)
        btn.icon = iconTexture
    end

    -- Standard mouse interactions
    btn:EnableMouse(true)
    btn:SetMotionScriptsWhileDisabled(true)
    
    return btn
end

-- Update an existing button's icon texture
function ButtonUtils:UpdateButtonIcon(button, iconPath, texCoords)
    if not button or not button.icon then
        return
    end
    
    button.icon:SetTexture(iconPath)
    
    if texCoords then
        button.icon:SetTexCoord(unpack(texCoords))
    else
        button.icon:SetTexCoord(BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop, BUTTON_CONFIG.iconCrop, 1 - BUTTON_CONFIG.iconCrop)
    end
end

-- Position a button above the game menu (top-right)
function ButtonUtils:PositionAboveGameMenuRight(button, offsetX, offsetY)
    if not button then
        return
    end
    
    offsetX = offsetX or -12
    offsetY = offsetY or 8
    
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", GameMenuFrame, "TOPRIGHT", offsetX, offsetY)
    button:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    button:EnableMouse(true)
    button:Show()
end

-- Position a button above the game menu (top-left)
function ButtonUtils:PositionAboveGameMenuLeft(button, offsetX, offsetY)
    if not button then
        return
    end
    
    offsetX = offsetX or 12
    offsetY = offsetY or 8
    
    button:ClearAllPoints()
    button:SetPoint("BOTTOMLEFT", GameMenuFrame, "TOPLEFT", offsetX, offsetY)
    button:SetFrameLevel(GameMenuFrame:GetFrameLevel() + 2)
    button:EnableMouse(true)
    button:Show()
end

-- Export the ButtonUtils module
BOLT.ButtonUtils = ButtonUtils