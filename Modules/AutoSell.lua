-- B.O.L.T Auto Sell Module
-- At a merchant, sells every junk (grey) item and every item on your sell list. The sell list is
-- account-wide (BOLTDB.sellList, by item ID): Alt + right-click an item in your bags to add it or
-- take it off again. Listed items carry a coin in the corner of their bag slot, in Blizzard's
-- bags and in Baganator.

local ADDON_NAME, BOLT = ...

local AutoSell = {
    displayName = "Auto Sell",
}

-- The money frame's gold coin exists on every client; the group-loot coin used before didn't
-- show on WoW: Forever (2026-11-12).
local ICON = "Interface\\MoneyFrame\\UI-GoldIcon"
local ICON_SIZE = 14
local SELL_DELAY = 0.1 -- seconds between two sales; the server drops sales sent too fast
local BAGANATOR_WIDGET = "bolt_sell_list"

local function List()
    BOLTDB.sellList = BOLTDB.sellList or {}
    return BOLTDB.sellList
end

local function IsListed(itemID)
    return AutoSell.active and itemID ~= nil and List()[itemID] == true
end

local function LastBag()
    return NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
end

---------------------------------------------------------------------------
-- Bag slot icons
---------------------------------------------------------------------------

local function MarkButton(button)
    if not (button and button.GetBagID and button.GetID) then return end
    local ok, bag = pcall(button.GetBagID, button)
    if not ok or not bag then return end
    local itemID = C_Container.GetContainerItemID(bag, button:GetID())
    local listed = IsListed(itemID)
    if listed and not button.boltSellIcon then
        local icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
        icon:SetTexture(ICON)
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:SetPoint("TOPLEFT", 1, -1)
        button.boltSellIcon = icon
    end
    if button.boltSellIcon then button.boltSellIcon:SetShown(listed) end
end

local function MarkFrame(frame)
    if not (frame and frame.EnumerateValidItems) then return end
    for _, button in frame:EnumerateValidItems() do MarkButton(button) end
end

local hookedFrames = {}
local function HookFrame(frame)
    if not frame or hookedFrames[frame] or not frame.UpdateItems then return end
    hookedFrames[frame] = true
    hooksecurefunc(frame, "UpdateItems", MarkFrame)
end

local function BlizzardFrames()
    local frames = { ContainerFrameCombinedBags }
    local container = ContainerFrameContainer and ContainerFrameContainer.ContainerFrames
    for _, frame in ipairs(container or {}) do table.insert(frames, frame) end
    return frames
end

local function RefreshIcons()
    for _, frame in ipairs(BlizzardFrames()) do
        if frame:IsShown() then MarkFrame(frame) end
    end
    if Baganator and Baganator.API and Baganator.API.RequestItemButtonsRefresh then
        Baganator.API.RequestItemButtonsRefresh()
    end
end

local function RegisterBaganator()
    local api = Baganator and Baganator.API
    if AutoSell.baganator or not (api and api.RegisterCornerWidget) then return end
    AutoSell.baganator = true
    pcall(api.RegisterCornerWidget, "BOLT: sell list", BAGANATOR_WIDGET,
        function(icon, details)
            return IsListed(details and details.itemID)
        end,
        function(itemButton)
            local icon = itemButton:CreateTexture(nil, "OVERLAY")
            icon:SetTexture(ICON)
            icon:SetSize(ICON_SIZE, ICON_SIZE)
            icon.padding = 0
            return icon
        end,
        { corner = "top_left", priority = 1 }, true)
end

---------------------------------------------------------------------------
-- Alt + right-click
---------------------------------------------------------------------------

-- Every bag button (Blizzard's and Baganator's) hands a modified click to the global
-- HandleModifiedItemClick with the slot's item location. Hooking that global catches buttons
-- made before BOLT started, which a hook on the button mixin would miss.
local function OnModifiedItemClick(_, itemLocation)
    if not AutoSell.active or not IsAltKeyDown() or GetMouseButtonClicked() ~= "RightButton" then return end
    if not (itemLocation and itemLocation.IsBagAndSlot and itemLocation:IsBagAndSlot()) then return end
    local bag, slot = itemLocation:GetBagAndSlot()
    if bag < 0 or bag > LastBag() then return end -- bags only, not the bank
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID then return end

    local link = info.hyperlink or ("item:" .. info.itemID)
    local list = List()
    if list[info.itemID] then
        list[info.itemID] = nil
        BOLT:Print(("Removed %s from the sell list."):format(link))
    elseif info.hasNoValue then
        BOLT:Print(("%s can't be sold to merchants."):format(link))
        return
    else
        list[info.itemID] = true
        BOLT:Print(("Added %s to the sell list: it will be sold at the next merchant."):format(link))
    end
    RefreshIcons()
end

---------------------------------------------------------------------------
-- Selling
---------------------------------------------------------------------------

local function ShouldSell(info)
    if not info or info.hasNoValue or info.isLocked or not info.itemID then return false end
    if info.quality == Enum.ItemQuality.Poor then return true end
    return List()[info.itemID] == true
end

local function Queue()
    local queue = {}
    for bag = 0, LastBag() do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if ShouldSell(info) then
                table.insert(queue, { bag = bag, slot = slot, itemID = info.itemID, count = info.stackCount or 1 })
            end
        end
    end
    return queue
end

function AutoSell:Sell()
    local queue = Queue()
    if #queue == 0 then return end
    local run = {}
    self.run = run
    local sold, earned = 0, 0

    local function Step()
        -- Merchant closed, or a newer run started.
        if self.run ~= run or not self.atMerchant then return end
        local entry = table.remove(queue, 1)
        if not entry then
            self.run = nil
            if sold > 0 then
                BOLT:Print(("Sold %d item%s for %s."):format(sold, sold == 1 and "" or "s",
                    GetMoneyString and GetMoneyString(earned, true) or tostring(earned)))
            end
            return
        end
        -- The slot may have changed since the queue was built.
        if C_Container.GetContainerItemID(entry.bag, entry.slot) == entry.itemID then
            local price = select(11, C_Item.GetItemInfo(entry.itemID)) or 0
            C_Container.UseContainerItem(entry.bag, entry.slot)
            sold = sold + 1
            earned = earned + price * entry.count
        end
        C_Timer.After(SELL_DELAY, Step)
    end
    -- Let the merchant window finish opening before the first sale.
    C_Timer.After(SELL_DELAY, Step)
end

function AutoSell:ClearList()
    local count = 0
    for _ in pairs(List()) do count = count + 1 end
    BOLTDB.sellList = {}
    BOLT:Print(("Sell list cleared (%d item%s)."):format(count, count == 1 and "" or "s"))
    RefreshIcons()
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function AutoSell:OnInitialize()
    hooksecurefunc("HandleModifiedItemClick", OnModifiedItemClick)
    for _, frame in ipairs(BlizzardFrames()) do HookFrame(frame) end
    RegisterBaganator()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, name)
        if event == "MERCHANT_SHOW" then
            self.atMerchant = true
            if self.active then self:Sell() end
        elseif event == "MERCHANT_CLOSED" then
            self.atMerchant = false
            self.run = nil
        elseif event == "ADDON_LOADED" and name == "Baganator" then
            RegisterBaganator()
        end
    end)
    self.eventFrame:RegisterEvent("MERCHANT_SHOW")
    self.eventFrame:RegisterEvent("MERCHANT_CLOSED")
    self.eventFrame:RegisterEvent("ADDON_LOADED")
end

function AutoSell:OnEnable()
    RefreshIcons()
end

function AutoSell:OnDisable()
    self.run = nil
    RefreshIcons()
end

BOLT:RegisterModule("autoSell", AutoSell)
