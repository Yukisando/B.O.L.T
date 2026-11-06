-- B.O.L.T Tooltip Module
-- Gives tooltips a see-through black background in place of Blizzard's dark blue, and hides the
-- health bar under unit tooltips. Blizzard resets the background each time a tooltip is styled,
-- so the colour is re-applied after every reset; turning the module off lets the next reset win.

local ADDON_NAME, BOLT = ...

local Tooltip = {
    displayName = "Tooltips",
}

local BACKGROUND = { 0, 0, 0, 0.8 }
local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "EmbeddedItemTooltip" }

local function Paint(tooltip)
    if not Tooltip.active or not tooltip then return end
    local slice = tooltip.NineSlice
    if slice and slice.SetCenterColor then
        slice:SetCenterColor(unpack(BACKGROUND))
    elseif tooltip.SetBackdropColor then
        tooltip:SetBackdropColor(unpack(BACKGROUND))
    end
end

local function HideHealthBar(bar)
    if Tooltip.active then bar:Hide() end
end

function Tooltip:OnInitialize()
    if SharedTooltip_SetBackdropStyle then
        hooksecurefunc("SharedTooltip_SetBackdropStyle", Paint)
    end
    for _, name in ipairs(TOOLTIPS) do
        local tooltip = _G[name]
        if tooltip then tooltip:HookScript("OnShow", Paint) end
    end
    if GameTooltipStatusBar then
        GameTooltipStatusBar:HookScript("OnShow", HideHealthBar)
    end
end

function Tooltip:OnEnable()
    for _, name in ipairs(TOOLTIPS) do Paint(_G[name]) end
    if GameTooltipStatusBar then GameTooltipStatusBar:Hide() end
end

BOLT:RegisterModule("tooltip", Tooltip)
