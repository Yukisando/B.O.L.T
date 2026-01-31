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
    local itemName
    if C_Item and C_Item.GetItemInfoByID then
        local info = C_Item.GetItemInfoByID(tonumber(itemID))
        if info and info.name then
            itemName = info.name
        end
    end
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

-- Helper function to extract item ID from various sources
local function GetItemIDFromTooltipData(tooltipData)
    if not tooltipData then return nil end
    
    -- Check for item ID directly in tooltip data
    if tooltipData.id and tooltipData.type then
        if tooltipData.type == Enum.TooltipDataType.Item then
            return tooltipData.id
        end
        if tooltipData.type == Enum.TooltipDataType.Toy then
            return tooltipData.id
        end
    end
    
    -- Check hyperlink in tooltip data
    if tooltipData.hyperlink then
        local itemID = string.match(tooltipData.hyperlink, "item:(%d+)")
        if itemID then return tonumber(itemID) end
    end
    
    return nil
end

-- Try to get item from various tooltip frames
local function GetItemFromTooltips()
    local tooltipsToCheck = {
        GameTooltip,
        ItemRefTooltip,
        ShoppingTooltip1,
        ShoppingTooltip2,
        ItemRefShoppingTooltip1,
        ItemRefShoppingTooltip2,
    }
    
    for _, tooltip in ipairs(tooltipsToCheck) do
        if tooltip and tooltip:IsShown() then
            -- Try the standard GetItem method
            local _, itemLink = tooltip:GetItem()
            if itemLink then
                return itemLink
            end
            
            -- Try the modern tooltip data API
            if tooltip.GetTooltipData then
                local tooltipData = tooltip:GetTooltipData()
                local itemID = GetItemIDFromTooltipData(tooltipData)
                if itemID then
                    local _, link = C_Item.GetItemInfo(itemID)
                    if link then return link end
                    -- Fallback: create a basic item link
                    return "item:" .. itemID
                end
            end
        end
    end
    
    return nil
end

-- Try to get item from the focused frame (bags, equipment, etc.)
local function GetItemFromFocusedFrame()
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    if not frame then return nil end
    
    -- Check if it's a container item via ItemLocation
    if frame.GetItemLocation then
        local itemLocation = frame:GetItemLocation()
        if itemLocation and itemLocation:IsValid() then
            return C_Item.GetItemLink(itemLocation)
        end
    end
    
    -- Check if it's a bag item
    if frame.GetBagID and frame.GetID then
        local bag = frame:GetBagID()
        local slot = frame:GetID()
        if bag and slot then
            return C_Container.GetContainerItemLink(bag, slot)
        end
    end
    
    return nil
end

-- Try to get item from ToyBox
local function GetItemFromToyBox()
    if not ToyBox or not ToyBox:IsShown() then return nil end
    
    -- Check if we have a toy button hovered
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    if frame and frame.itemID then
        local _, link = C_Item.GetItemInfo(frame.itemID)
        if link then return link end
        return "item:" .. frame.itemID
    end
    
    -- Try to get from the toy's spellID
    if frame and frame.spellID then
        local itemID = C_ToyBox and C_ToyBox.GetToyInfo and select(1, C_ToyBox.GetToyInfo(frame.spellID))
        if itemID then
            local _, link = C_Item.GetItemInfo(itemID)
            if link then return link end
            return "item:" .. itemID
        end
    end
    
    return nil
end

-- Try to get item from vendor frame
local function GetItemFromMerchant()
    if not MerchantFrame or not MerchantFrame:IsShown() then return nil end
    
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    
    -- Check for merchant item buttons
    if frame then
        -- Try to get the merchant index from the button
        local buttonName = frame:GetName()
        if buttonName then
            local index = string.match(buttonName, "MerchantItem(%d+)ItemButton")
            if index then
                index = tonumber(index)
                local link = GetMerchantItemLink(index)
                if link then return link end
            end
        end
        
        -- Check for buyback items
        local buybackIndex = buttonName and string.match(buttonName, "MerchantBuyBackItemItemButton")
        if buybackIndex then
            local link = GetBuybackItemLink(1)
            if link then return link end
        end
    end
    
    return nil
end

-- Try to get item from quest reward frame
local function GetItemFromQuestReward()
    if not QuestInfoFrame or not QuestInfoFrame:IsShown() then return nil end
    
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    if not frame then return nil end
    
    local buttonName = frame:GetName()
    if not buttonName then return nil end
    
    -- Quest reward choices
    local rewardIndex = string.match(buttonName, "QuestInfoRewardsFrameQuestInfoItem(%d+)")
    if rewardIndex then
        rewardIndex = tonumber(rewardIndex)
        if QuestInfoFrame.questLog then
            return GetQuestLogItemLink("choice", rewardIndex)
        else
            return GetQuestItemLink("choice", rewardIndex)
        end
    end
    
    return nil
end

-- Try to get item from collections/appearances
local function GetItemFromCollections()
    if not WardrobeCollectionFrame or not WardrobeCollectionFrame:IsShown() then return nil end
    
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    if frame and frame.visualInfo and frame.visualInfo.visualID then
        local sources = C_TransmogCollection.GetAppearanceSources(frame.visualInfo.visualID)
        if sources and sources[1] and sources[1].itemID then
            local _, link = C_Item.GetItemInfo(sources[1].itemID)
            if link then return link end
            return "item:" .. sources[1].itemID
        end
    end
    
    return nil
end

-- Try to get item from auction house
local function GetItemFromAuctionHouse()
    if not AuctionHouseFrame or not AuctionHouseFrame:IsShown() then return nil end
    
    -- The AH uses the tooltip data system, so GetItemFromTooltips should handle it
    return nil
end

-- Try to get item from guild bank
local function GetItemFromGuildBank()
    if not GuildBankFrame or not GuildBankFrame:IsShown() then return nil end
    
    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if not getMouseFocus then return nil end
    
    local frame = getMouseFocus()
    if not frame then return nil end
    
    local buttonName = frame:GetName()
    if buttonName then
        local tab, slot = string.match(buttonName, "GuildBankColumn(%d+)Button(%d+)")
        if tab and slot then
            tab = tonumber(tab)
            slot = tonumber(slot)
            local trueSlot = (tab - 1) * 14 + slot
            local currentTab = GetCurrentGuildBankTab()
            return GetGuildBankItemLink(currentTab, trueSlot)
        end
    end
    
    return nil
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

        local itemLink = nil
        
        -- Try multiple sources in order of likelihood
        itemLink = GetItemFromTooltips()
        
        if not itemLink then
            itemLink = GetItemFromFocusedFrame()
        end
        
        if not itemLink then
            itemLink = GetItemFromToyBox()
        end
        
        if not itemLink then
            itemLink = GetItemFromMerchant()
        end
        
        if not itemLink then
            itemLink = GetItemFromQuestReward()
        end
        
        if not itemLink then
            itemLink = GetItemFromCollections()
        end
        
        if not itemLink then
            itemLink = GetItemFromGuildBank()
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
