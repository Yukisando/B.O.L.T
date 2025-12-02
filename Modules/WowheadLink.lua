-- B.O.L.T Wowhead Link Module
-- Quickly copy Wowhead links for items by pressing Ctrl+C twice on mouseover

local ADDON_NAME, BOLT = ...

local WowheadLink = {}

-- Frame for showing the link
local linkFrame = nil
local currentItemLink = nil
local currentWowheadURL = nil

function WowheadLink:OnInitialize()
    -- Module initialization
end

function WowheadLink:OnEnable()
    if not self.parent:IsModuleEnabled("wowheadLink") then
        return
    end

    -- Set default keybinding if none exists
    local key1, key2 = GetBindingKey("BOLT_SHOW_WOWHEAD_LINK")
    if not key1 and not key2 then
        SetBinding("CTRL-C", "BOLT_SHOW_WOWHEAD_LINK")
        SaveBindings(GetCurrentBindingSet())
    end

    -- Create the link display frame if it doesn't exist
    if not linkFrame then
        self:CreateLinkFrame()
    end
end

function WowheadLink:OnDisable()
    if linkFrame then
        linkFrame:Hide()
    end
end

function WowheadLink:CreateLinkFrame()
    -- Create a frame to display the Wowhead link
    linkFrame = CreateFrame("Frame", "BOLTWowheadLinkFrame", UIParent, "BackdropTemplate")
    linkFrame:SetSize(400, 120)
    linkFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    linkFrame:SetFrameStrata("DIALOG")
    linkFrame:SetFrameLevel(100)

    -- Backdrop styling
    linkFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    linkFrame:SetBackdropColor(0, 0, 0, 0.9)

    -- Title
    local title = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", linkFrame, "TOP", 0, -15)
    title:SetText("Wowhead Link")
    title:SetTextColor(1, 0.82, 0)

    -- Instruction text
    local instruction = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    instruction:SetPoint("TOP", title, "BOTTOM", 0, -8)
    instruction:SetText("Press Ctrl+C to copy")
    instruction:SetTextColor(0.7, 0.7, 0.7)

    -- EditBox to display the link (auto-selected)
    local editBox = CreateFrame("EditBox", "BOLTWowheadLinkEditBox", linkFrame, "InputBoxTemplate")
    editBox:SetSize(370, 25)
    editBox:SetPoint("TOP", instruction, "BOTTOM", 0, -10)
    editBox:SetAutoFocus(true)
    editBox:SetMaxLetters(500)
    editBox:SetScript("OnEscapePressed", function()
        linkFrame:Hide()
    end)
    
    -- Detect Ctrl+C in the editbox to close the window
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown() then
            -- Small delay to allow the copy to happen first
            C_Timer.After(0.05, function()
                linkFrame:Hide()
                BOLT:Print("Wowhead link copied to clipboard!")
            end)
        end
    end)

    -- Store reference to editBox
    linkFrame.editBox = editBox

    -- Close button
    local closeButton = CreateFrame("Button", nil, linkFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", linkFrame, "TOPRIGHT", -5, -5)

    linkFrame:Hide()
end

function WowheadLink:ShowLinkForItem(itemLink)
    if not itemLink or not linkFrame then
        return
    end

    -- Parse the item ID from the item link
    local itemString = string.match(itemLink, "item[%-?%d:]+")
    if not itemString then
        self.parent:Print("Could not parse item link")
        return
    end

    -- Extract just the item ID (first number after "item:")
    local itemID = string.match(itemString, "item:(%d+)")
    if not itemID then
        self.parent:Print("Could not extract item ID")
        return
    end

    -- Get item name for display
    local itemName = GetItemInfo(itemLink)
    if not itemName then
        itemName = "Item " .. itemID
    end

    -- Generate Wowhead URL
    local wowheadURL = "https://www.wowhead.com/item=" .. itemID

    -- Store the current link
    currentItemLink = itemLink
    currentWowheadURL = wowheadURL

    -- Show the frame
    linkFrame:Show()
    linkFrame.editBox:SetText(wowheadURL)
    linkFrame.editBox:HighlightText()
    linkFrame.editBox:SetFocus()
end

-- Global function for keybinding
function BOLT_ShowWowheadLink()
    local BOLT = _G["BOLT"]

    if BOLT and BOLT.modules and BOLT.modules.wowheadLink then
        -- Check if the window is already open - if so, close it
        if linkFrame and linkFrame:IsShown() then
            linkFrame:Hide()
            BOLT:Print("Wowhead link copied to clipboard!")
            return
        end

        -- Get the item link from the tooltip
        local _, itemLink = GameTooltip:GetItem()

        if not itemLink then
            -- Try to get from mouseover unit if it's an item
            if GetMouseFocus() then
                local frame = GetMouseFocus()
                -- Check if it's a container item
                if frame and frame.GetItemLocation then
                    local itemLocation = frame:GetItemLocation()
                    if itemLocation and itemLocation:IsValid() then
                        itemLink = C_Item.GetItemLink(itemLocation)
                    end
                end
                -- Check if it's a bag item
                if not itemLink and frame.GetBagID and frame.GetID then
                    local bag = frame:GetBagID()
                    local slot = frame:GetID()
                    if bag and slot then
                        itemLink = C_Container.GetContainerItemLink(bag, slot)
                    end
                end
            end
        end

        if itemLink then
            BOLT.modules.wowheadLink:ShowLinkForItem(itemLink)
        else
            BOLT:Print("No item found. Hover over an item and try again.")
        end
    end
end

-- Register the module
BOLT:RegisterModule("wowheadLink", WowheadLink)
