-- B.O.L.T Button Utilities (Brittle and Occasionally Lethal Tweaks)
-- Round icon buttons used around the game menu.

local ADDON_NAME, BOLT = ...

local ButtonUtils = {}

local BUTTON_SIZE = 25
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BORDER_COLOR = { 0.3, 0.28, 0.24, 1 }

local function AddCircularMask(texture, btn)
    local mask = btn:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    return mask
end

-- Never parent addon buttons to protected Blizzard frames; anchoring to them is fine.
local function SafeParent(parent)
    if parent and parent.IsProtected and parent:IsProtected() then
        BOLT:Debug("Requested parent is protected, using UIParent instead")
        return UIParent
    end
    return parent or UIParent
end

-- Options:
--   secure          use SecureActionButtonTemplate (toys, spells)
--   iconScale       size multiplier for the icon (default 1)
--   contentScale    zoom of the icon artwork inside the circle (default iconScale)
--   highlightColor  { r, g, b, a } for the hover overlay
--   showBackground  dark disc behind the icon (for text overlays)
function ButtonUtils:CreateIconButton(name, parent, iconPath, options)
    options = options or {}
    local template = options.secure and "SecureActionButtonTemplate" or nil
    local btn = CreateFrame("Button", name, SafeParent(parent), template)
    btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)

    local iconSize = BUTTON_SIZE * (options.iconScale or 1)

    if options.showBackground then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetColorTexture(0.1, 0.1, 0.1, 0.6)
        bg:SetAllPoints(btn)
        AddCircularMask(bg, btn)
        btn.background = bg
    end

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetSize(iconSize + 3, iconSize + 3)
    border:SetPoint("CENTER")
    border:SetColorTexture(unpack(BORDER_COLOR))
    AddCircularMask(border, btn)
    btn.border = border

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("CENTER")
    icon:SetTexture(iconPath)
    -- Crop the default 8% icon border, then zoom further in for contentScale > 1.
    local contentScale = options.contentScale or options.iconScale or 1
    local crop = 0.08 + (1 - contentScale) * 0.42
    icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
    btn.mask = AddCircularMask(icon, btn)
    btn.icon = icon

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(btn)
    highlight:SetColorTexture(unpack(options.highlightColor or { 1, 1, 1, 0.2 }))
    highlight:AddMaskTexture(btn.mask)
    btn:SetHighlightTexture(highlight)

    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetAllPoints(btn)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:Hide()
    btn.cooldown = cooldown

    if not options.secure then
        btn:SetScript("OnClick", function()
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        end)
    end

    return btn
end

-- Attach a simple tooltip; lines is a function returning title, then { text, r, g, b } rows.
function ButtonUtils:SetTooltip(button, anchor, buildLines)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        local title, lines = buildLines(self)
        GameTooltip:SetText(title, 1, 1, 1)
        for _, line in ipairs(lines or {}) do
            GameTooltip:AddLine(line[1], line[2] or 0.8, line[3] or 0.8, line[4] or 0.8, true)
        end
        GameTooltip:Show()
        BOLT.PlayHoverSound()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
end

function ButtonUtils:UpdateButtonIcon(button, iconPath)
    if button and button.icon then
        button.icon:SetTexture(iconPath)
    end
end

function ButtonUtils:ClearButtonCooldown(button)
    if button and button.cooldown then
        button.cooldown:Clear()
        button.cooldown:Hide()
    end
end

function ButtonUtils:SetButtonCooldown(button, startTime, duration, isEnabled, modRate)
    if not (button and button.cooldown) then return end

    -- Ignore the global cooldown and anything that isn't a real cooldown.
    if BOLT.IsSecret(duration) or not startTime or not duration or startTime <= 0
        or duration <= 1.5 or isEnabled == false or isEnabled == 0 then
        self:ClearButtonCooldown(button)
        return
    end

    button.cooldown:Show()
    button.cooldown:SetCooldown(startTime, duration, modRate or 1)
end

local function AnchorToMenu(button, point, relativePoint, offsetX, offsetY)
    if not button then return end
    if InCombatLockdown() and button:IsProtected() then return end

    local container = BOLTGameMenuContainer
    local anchor = (container and container:IsShown()) and container or GameMenuFrame
    button:ClearAllPoints()
    button:SetPoint(point, anchor, relativePoint, offsetX, offsetY)
    button:SetFrameLevel(anchor:GetFrameLevel() + 2)
    button:Show()
end

function ButtonUtils:PositionAboveGameMenuRight(button, offsetX, offsetY)
    AnchorToMenu(button, "BOTTOMRIGHT", "TOPRIGHT", offsetX or -12, offsetY or 8)
end

function ButtonUtils:PositionAboveGameMenuLeft(button, offsetX, offsetY)
    AnchorToMenu(button, "BOTTOMLEFT", "TOPLEFT", offsetX or 12, offsetY or 8)
end

BOLT.ButtonUtils = ButtonUtils
