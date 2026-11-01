-- B.O.L.T Wowhead Link Module
-- Press the keybind (Ctrl+C by default) while hovering something to get its Wowhead URL.

local ADDON_NAME, BOLT = ...

local WowheadLink = {
    displayName = "Wowhead Links",
}

local BINDING = "BOLT_SHOW_WOWHEAD_LINK"
local DEFAULT_KEY = "CTRL-C"

local linkFrame

local TOOLTIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }

local function WowheadBase()
    return BOLT.isForever and "https://www.wowhead.com/forever/" or "https://www.wowhead.com/"
end

-- Tooltip data type -> function(data) returning wowheadType, id
local DATA_TYPES = {
    [Enum.TooltipDataType.Item] = function(data) return "item", data.id end,
    [Enum.TooltipDataType.Toy] = function(data) return "item", data.id end,
    [Enum.TooltipDataType.Spell] = function(data) return "spell", data.id end,
    [Enum.TooltipDataType.UnitAura] = function(data) return "spell", data.id end,
    [Enum.TooltipDataType.Mount] = function(data)
        local spellID = select(2, C_MountJournal.GetMountInfoByID(data.id))
        return "spell", spellID
    end,
    [Enum.TooltipDataType.Currency] = function(data) return "currency", data.id end,
    [Enum.TooltipDataType.Achievement] = function(data) return "achievement", data.id end,
    [Enum.TooltipDataType.Quest] = function(data) return "quest", data.id end,
    [Enum.TooltipDataType.Unit] = function(data)
        local guid = data.guid
        if not guid or BOLT.IsSecret(guid) then return nil end
        local unitType, _, _, _, _, npcID = strsplit("-", guid)
        if unitType == "Creature" or unitType == "Vehicle" then
            return "npc", tonumber(npcID)
        end
        return nil
    end,
}

local function FromTooltip(tooltip)
    if not (tooltip and tooltip:IsShown() and tooltip.GetPrimaryTooltipData) then return nil end
    local data = tooltip:GetPrimaryTooltipData()
    if not data or BOLT.IsSecret(data.type) then return nil end
    local resolver = DATA_TYPES[data.type]
    if resolver and data.id then
        return resolver(data)
    end
    return nil
end

-- Bag and equipment buttons expose an ItemLocation even when no tooltip is shown.
local function FromMouseFocus()
    local focus = GetMouseFoci()[1]
    if focus and focus.GetItemLocation then
        local location = focus:GetItemLocation()
        if location and location:IsValid() then
            return "item", C_Item.GetItemID(location)
        end
    end
    return nil
end

function WowheadLink:FindHoveredObject()
    for _, name in ipairs(TOOLTIPS) do
        local kind, id = FromTooltip(_G[name])
        if kind and id then return kind, id end
    end
    return FromMouseFocus()
end

function WowheadLink:CreateLinkFrame()
    linkFrame = BOLT:CreateDialog("BOLTWowheadLinkFrame", 400, 120, "Wowhead Link")

    local hint = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", linkFrame.title, "BOTTOM", 0, -8)
    hint:SetText("Press Ctrl+C to copy")
    hint:SetTextColor(0.7, 0.7, 0.7)

    local editBox = CreateFrame("EditBox", nil, linkFrame, "InputBoxTemplate")
    editBox:SetSize(360, 25)
    editBox:SetPoint("TOP", hint, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", function() linkFrame:Hide() end)
    editBox:SetScript("OnKeyDown", function(_, key)
        if key == "C" and IsControlKeyDown() then
            -- Let the copy happen before closing.
            C_Timer.After(0.05, function()
                linkFrame:Hide()
                BOLT:Print("Wowhead link copied.")
            end)
        end
    end)
    -- Keep the URL intact if the user types into it.
    editBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and linkFrame.url then
            self:SetText(linkFrame.url)
            self:HighlightText()
        end
    end)
    linkFrame.editBox = editBox
end

function WowheadLink:ShowLink(kind, id)
    if not linkFrame then
        self:CreateLinkFrame()
    end
    linkFrame.url = ("%s%s=%d"):format(WowheadBase(), kind, id)
    linkFrame:Show()
    linkFrame.editBox:SetText(linkFrame.url)
    linkFrame.editBox:HighlightText()
    linkFrame.editBox:SetFocus()
end

function BOLT_ShowWowheadLink()
    if not BOLT:IsModuleEnabled("wowheadLink") then
        BOLT:Print("Wowhead Links is disabled. Enable it in the B.O.L.T settings first.")
        return
    end
    if linkFrame and linkFrame:IsShown() then
        linkFrame:Hide()
        return
    end

    local kind, id = WowheadLink:FindHoveredObject()
    if kind and id then
        WowheadLink:ShowLink(kind, id)
    else
        BOLT:Print("Nothing to link. Hover over an item, spell, NPC, quest or achievement first.")
    end
end

function WowheadLink:OnEnable()
    -- Give the binding a default key, but never take a key another action uses.
    if not GetBindingKey(BINDING) then
        local current = GetBindingAction(DEFAULT_KEY)
        if (current == nil or current == "") and SetBinding(DEFAULT_KEY, BINDING) then
            SaveBindings(GetCurrentBindingSet())
        else
            BOLT:Print("Wowhead Links: set a key in Key Bindings > AddOns > B.O.L.T.")
        end
    end
end

function WowheadLink:OnDisable()
    if linkFrame then
        linkFrame:Hide()
    end
end

BOLT:RegisterModule("wowheadLink", WowheadLink)
