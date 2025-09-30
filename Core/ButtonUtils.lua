-- B.O.L.T Button Utilities (Brittle and Occasionally Lethal Tweaks)
-- Simplified button creation using latest WoW API

local ADDON_NAME, BOLT = ...

-- Create the ButtonUtils module
local ButtonUtils = {}

-- Standard button configuration
local BUTTON_CONFIG = {
    size = 25,
}

-- Create a simple square icon button using clean approach
function ButtonUtils:CreateIconButton(name, parent, iconPath, options)
    options = options or {}
    
    -- Create a basic button frame
    local btn = CreateFrame("Button", name, parent)
    btn:SetSize(BUTTON_CONFIG.size, BUTTON_CONFIG.size)
    
    -- Create icon texture with rounded mask
    if iconPath then
        local iconSize = options.iconScale and (BUTTON_CONFIG.size * options.iconScale) or BUTTON_CONFIG.size
        local contentScale = options.contentScale or options.iconScale or 1.0
        local contentSize = iconSize * contentScale
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize, iconSize) -- This affects the hover/pressed area
        icon:SetTexture(iconPath)
        icon:SetPoint("CENTER", btn, "CENTER")
        
        -- Apply content scaling to texture coordinates for visual scaling
        local cropBase = 0.08
        local cropRange = 0.84 -- (0.92 - 0.08)
        local cropAdjust = (1 - contentScale) * 0.5 * cropRange
        local cropMin = cropBase + cropAdjust
        local cropMax = 0.92 - cropAdjust
        icon:SetTexCoord(cropMin, cropMax, cropMin, cropMax)
        
        btn.icon = icon
        btn.iconPath = iconPath
        
        -- Apply rounded mask using a circular mask texture
        local mask = btn:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        btn.mask = mask
    end
    
    -- Create subtle highlight with rounded mask
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetColorTexture(1, 1, 1, 0.2) -- Subtle white overlay
    highlight:SetAllPoints(btn)
    
    -- Apply rounded mask to highlight as well
    if btn.mask then
        highlight:AddMaskTexture(btn.mask)
    end
    
    btn:SetHighlightTexture(highlight)
    
    -- Apply highlight color if specified
    if options.highlightColor then
        highlight:SetColorTexture(unpack(options.highlightColor))
    end
    
    -- Add sound on click
    btn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
    end)
    
    btn:EnableMouse(true)
    
    return btn
end

-- Create a volume button with special styling
function ButtonUtils:CreateVolumeButton(name, parent, options)
    options = options or {}
    
    -- Add yellow highlight for volume functionality indication
    if not options.highlightColor then
        options.highlightColor = {1, 1, 0.5, 0.2}
    end
    
    local btn = self:CreateIconButton(name, parent, "Interface\\Icons\\Spell_Shadow_SoundDamp", options)
    
    -- Add a subtle background if requested
    if options.showBackground then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.6) -- Dark semi-transparent background
        bg:SetAllPoints(btn)
        
        -- Apply rounded mask to background as well
        if btn.mask then
            bg:AddMaskTexture(btn.mask)
        end
        
        btn.background = bg
    end
    
    return btn
end

-- Create a secure action button for toys, spells, etc.
function ButtonUtils:CreateSecureActionButton(name, parent, iconPath, options)
    options = options or {}
    
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(BUTTON_CONFIG.size, BUTTON_CONFIG.size)
    
    -- Create icon texture with rounded mask
    if iconPath then
        local iconSize = options.iconScale and (BUTTON_CONFIG.size * options.iconScale) or BUTTON_CONFIG.size
        local contentScale = options.contentScale or options.iconScale or 1.0
        
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(iconSize, iconSize) -- This affects the hover/pressed area
        icon:SetTexture(iconPath)
        icon:SetPoint("CENTER", btn, "CENTER")
        
        -- Apply content scaling to texture coordinates for visual scaling
        local cropBase = 0.08
        local cropRange = 0.84 -- (0.92 - 0.08)
        local cropAdjust = (1 - contentScale) * 0.5 * cropRange
        local cropMin = cropBase + cropAdjust
        local cropMax = 0.92 - cropAdjust
        icon:SetTexCoord(cropMin, cropMax, cropMin, cropMax)
        
        btn.icon = icon
        btn.iconPath = iconPath
        
        -- Apply rounded mask using a circular mask texture
        local mask = btn:CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        btn.mask = mask
    end
    
    -- Create subtle highlight with rounded mask
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetColorTexture(1, 1, 1, 0.2) -- Subtle white overlay
    highlight:SetAllPoints(btn)
    
    -- Apply rounded mask to highlight as well
    if btn.mask then
        highlight:AddMaskTexture(btn.mask)
    end
    
    btn:SetHighlightTexture(highlight)
    
    -- Apply highlight color if specified
    if options.highlightColor then
        highlight:SetColorTexture(unpack(options.highlightColor))
    end
    
    btn:EnableMouse(true)
    
    return btn
end

-- Update an existing button's icon
function ButtonUtils:UpdateButtonIcon(button, iconPath)
    if not button or not button.icon then
        return
    end
    
    button.icon:SetTexture(iconPath)
    button.iconPath = iconPath
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