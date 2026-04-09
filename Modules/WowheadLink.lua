-- B.O.L.T Wowhead Link Module
-- Quickly copy Wowhead links for items by pressing Ctrl+C twice on mouseover

local ADDON_NAME, BOLT = ...

local WowheadLink = {}


-- Frame for showing the link
local linkFrame = nil
local currentItemLink = nil
local currentWowheadURL = nil

local function EnsureBinding(action, defaultKey)
    local key1, key2 = GetBindingKey(action)
    if key1 or key2 then
        return true
    end

    if SetBinding(defaultKey, action) then
        SaveBindings(GetCurrentBindingSet())
        return true
    end

    return false
end


local function GetHoveredFrame()
    local getMouseFoci = rawget(_G, "GetMouseFoci")
    if type(getMouseFoci) == "function" then
        local ok, focus = pcall(getMouseFoci)
        if ok and focus then
            if type(focus) == "table" then
                return focus[1]
            end
            return focus
        end
    end

    local getMouseFocus = rawget(_G, "GetMouseFocus")
    if type(getMouseFocus) == "function" then
        return getMouseFocus()
    end

    return nil
end

local function GetTooltipHyperlink(tooltip)
    if not tooltip or not tooltip:IsShown() then
        return nil
    end

    local _, itemLink = tooltip:GetItem()
    if itemLink and itemLink ~= "" then
        return itemLink
    end

    if type(tooltip.GetSpell) == "function" then
        local spellResult = { pcall(tooltip.GetSpell, tooltip) }
        if spellResult[1] then
            local spellID = spellResult[#spellResult]
            if type(spellID) == "number" then
                return "spell:" .. tostring(spellID)
            end
        end
    end

    local tooltipUtil = rawget(_G, "TooltipUtil")
    if tooltipUtil and type(tooltipUtil.GetDisplayedHyperlink) == "function" then
        local ok, hyperlink = pcall(tooltipUtil.GetDisplayedHyperlink, tooltip)
        if ok and hyperlink and hyperlink ~= "" then
            return hyperlink
        end
    end

    return nil
end


function WowheadLink:OnInitialize()
    -- Module initialization
end

function WowheadLink:OnEnable()
    -- Set default keybinding if none exists
    if not EnsureBinding("BOLT_SHOW_WOWHEAD_LINK", "CTRL-C") then
        self.parent:Print("Wowhead Link could not bind CTRL-C automatically. Set a keybind manually in Key Bindings.")
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
    if not itemLink then
        return
    end

    if not linkFrame then
        self:CreateLinkFrame()
    end

    -- Try to parse item or spell IDs from the link
    local id, idType

    id = string.match(itemLink, "item:(%d+)")
    if id then
        idType = "item"
    else
        id = string.match(itemLink, "spell:(%d+)")
        if id then
            idType = "spell"
        end
    end



    if not id then
        self.parent:Print("Could not parse link")
        return
    end



    -- Get a display name for the id
    local displayName
    if idType == "item" then
        if C_Item and C_Item.GetItemInfoByID then
            local info = C_Item.GetItemInfoByID(tonumber(id))
            if info and info.name then
                displayName = info.name
            end
        end
        if not displayName then
            displayName = "Item " .. id
        end
    elseif idType == "spell" then
        -- Use the modern C_Spell.GetSpellInfo API (returns a table {name, rank, iconID, ...}).
        -- GetSpellInfo (global) was removed in Midnight (12.0); C_Spell.GetSpellInfo is the replacement.
        local name
        if C_Spell and C_Spell.GetSpellInfo then
            local spellInfo = C_Spell.GetSpellInfo(tonumber(id))
            if spellInfo then name = spellInfo.name end
        end

        if name then
            displayName = name
        else
            displayName = "Spell " .. id
        end
    end

    -- Generate Wowhead URL
    local wowheadURL
    if idType == "item" then
        wowheadURL = "https://www.wowhead.com/item=" .. id
    elseif idType == "spell" then
        wowheadURL = "https://www.wowhead.com/spell=" .. id
    end

    -- Store the current link
    currentItemLink = itemLink
    currentWowheadURL = wowheadURL

    -- Show the frame
    local frame = linkFrame
    if not frame or not frame.editBox then
        return
    end

    frame:Show()
    frame.editBox:SetText(wowheadURL)
    frame.editBox:HighlightText()
    frame.editBox:SetFocus()
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
        local hyperlink = GetTooltipHyperlink(tooltip)
        if hyperlink then
            return hyperlink
        end
    end
    
    return nil
end

-- Try to get item from the focused frame (bags, equipment, etc.)
local function GetItemFromFocusedFrame()
    local frame = GetHoveredFrame()
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

    local frame = GetHoveredFrame()
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

    local frame = GetHoveredFrame()
    
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

    local frame = GetHoveredFrame()
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

    local frame = GetHoveredFrame()
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

    local frame = GetHoveredFrame()
    if not frame then return nil end
    
    local buttonName = frame:GetName()
    if buttonName then
        local tab, slot = string.match(buttonName, "GuildBankColumn(%d+)Button(%d+)")
        if tab and slot then
            tab = tonumber(tab)
            slot = tonumber(slot)
            local trueSlot = (tab - 1) * 14 + slot
            local currentTab = GetCurrentGuildBankTab()
            if currentTab then
                return GetGuildBankItemLink(currentTab, trueSlot)
            end
        end
    end
    
    return nil
end

-- Global function for keybinding
function BOLT_ShowWowheadLink()
    local addon = BOLT or _G[ADDON_NAME] or _G["BOLT"] or _G["Bolt"]

    if addon and addon.modules and addon.modules.wowheadLink then
        local module = addon.modules.wowheadLink

        if not addon:IsModuleEnabled("wowheadLink") then
            addon:Print("Wowhead Link is disabled. Enable it in B.O.L.T settings first.")
            return
        end

        if module.OnInitialize and not module._initialized then
            module:OnInitialize()
            module._initialized = true
        end

        if not linkFrame then
            module:CreateLinkFrame()
        end

        -- Check if the window is already open - if so, close it
        if linkFrame and linkFrame:IsShown() then
            linkFrame:Hide()
            addon:Print("Wowhead link copied to clipboard!")
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
            module:ShowLinkForItem(itemLink)
        else
            addon:Print("No item found. Hover over an item and try again. (debug info below)")

            -- Debugging info: list visible tooltips and mouse focus details to help identify the hovered object
            local tooltipsToCheck = {
                GameTooltip,
                ItemRefTooltip,
                ShoppingTooltip1,
                ShoppingTooltip2,
                ItemRefShoppingTooltip1,
                ItemRefShoppingTooltip2,
            }

            addon:Print("Debug: checking visible tooltips and their data:")
            for _, tt in ipairs(tooltipsToCheck) do
                if tt and tt:IsShown() then
                    local name = tt:GetName() or "<unnamed>"
                    addon:Print(" Tooltip: " .. name)
                    local tooltipLink = GetTooltipHyperlink(tt)
                    if tooltipLink then
                        addon:Print("  hyperlink -> " .. tostring(tooltipLink))
                    end
                end
            end

            -- Also print mouse focus/frame details
            local mf = GetHoveredFrame()
            if mf then
                local mfName = "<unnamed>"
                pcall(function() mfName = mf:GetName() end)
                local mfType = "<unknown>"
                pcall(function() mfType = mf:GetObjectType() end)
                addon:Print("MouseFocus: " .. tostring(mfName) .. " (" .. tostring(mfType) .. ")")
                if mf.itemID then addon:Print("  itemID -> " .. tostring(mf.itemID)) end
                if mf.spellID then addon:Print("  spellID -> " .. tostring(mf.spellID)) end
                if mf.visualInfo and mf.visualInfo.visualID then addon:Print("  visualID -> " .. tostring(mf.visualInfo.visualID)) end
                if mf.GetBagID and mf.GetID then
                    local ok3, bag, slot = pcall(function() return mf:GetBagID(), mf:GetID() end)
                    if ok3 and bag and slot then
                        addon:Print("  bag,slot -> " .. tostring(bag) .. "," .. tostring(slot))
                    end
                end
            end
        end
    end
end

-- Register the module
BOLT:RegisterModule("wowheadLink", WowheadLink)
