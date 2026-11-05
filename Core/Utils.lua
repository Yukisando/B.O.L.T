-- B.O.L.T Utility Functions (Brittle and Occasionally Lethal Tweaks)
-- Shared helpers used by several modules.

local ADDON_NAME, BOLT = ...

-- Midnight (12.0+) hands addons "secret" values in restricted contexts (chat in
-- instances, some unit data in combat). Comparing or indexing them errors.
function BOLT.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

function BOLT.PlayHoverSound()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end

---------------------------------------------------------------------------
-- Groups
---------------------------------------------------------------------------

local function InDelve()
    if not BOLT.has.delves then return false end
    return C_PartyInfo.IsDelveInProgress() or C_PartyInfo.IsDelveComplete()
end

function BOLT:IsInGroup()
    return IsInGroup() or IsInRaid() or IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
end

function BOLT:GetGroupTypeString()
    if InDelve() then
        return "Delve"
    end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return IsInRaid(LE_PARTY_CATEGORY_INSTANCE) and "Instance Raid" or "Instance Party"
    end
    if IsInRaid() then
        return "Raid"
    end
    if IsInGroup() then
        return "Party"
    end
    return nil
end

function BOLT:LeaveGroup()
    if InDelve() then
        C_PartyInfo.DelveTeleportOut()
        self:Print("Teleporting out of the delve...")
        return
    end

    local groupType = self:GetGroupTypeString()
    if not groupType then
        self:Print("You are not in a group.")
        return
    end

    -- Leadership passes to another member automatically when the leader leaves.
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        C_PartyInfo.LeaveParty(LE_PARTY_CATEGORY_INSTANCE)
    else
        C_PartyInfo.LeaveParty()
    end
    self:Print("Left " .. groupType .. ".")
end

---------------------------------------------------------------------------
-- Chat
---------------------------------------------------------------------------

-- Send a chat message, respecting Midnight's chat messaging lockdown (active in
-- instanced combat). Returns true when the message was handed to the client.
function BOLT:SendChat(text, chatType, target)
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
        return false
    end
    local ok = pcall(C_ChatInfo.SendChatMessage, text, chatType, nil, target)
    return ok
end

-- Strip realm and compare against the player's own name.
function BOLT:IsPlayerName(sender)
    if type(sender) ~= "string" or BOLT.IsSecret(sender) then return false end
    return Ambiguate(sender, "short") == UnitName("player")
end

---------------------------------------------------------------------------
-- Game menu watcher
---------------------------------------------------------------------------

-- Several modules decorate GameMenuFrame. Hooking its OnShow runs addon code inside
-- ShowUIPanel's secure path and taints the menu, so one shared watcher polls the
-- shown state instead and notifies listeners outside of that path.
local menuListeners = {}
local menuWatcher
local menuShown = false

local function NotifyMenuListeners(shown)
    for _, listener in pairs(menuListeners) do
        local callback = shown and listener.onShow or listener.onHide
        if callback then callback() end
    end
end

function BOLT:WatchGameMenu(key, onShow, onHide)
    menuListeners[key] = { onShow = onShow, onHide = onHide }
    if menuWatcher then
        if not menuWatcher:IsShown() then
            menuShown = GameMenuFrame:IsShown()
            menuWatcher:Show()
        end
        return
    end

    menuWatcher = CreateFrame("Frame")
    menuShown = GameMenuFrame:IsShown()
    local elapsed = 0
    menuWatcher:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.05 then return end
        elapsed = 0

        local shown = GameMenuFrame:IsShown()
        if shown ~= menuShown then
            menuShown = shown
            NotifyMenuListeners(shown)
        end
    end)
end

function BOLT:UnwatchGameMenu(key)
    menuListeners[key] = nil
    if menuWatcher and not next(menuListeners) then
        menuWatcher:Hide()
    end
end

function BOLT:IsGameMenuShown()
    return GameMenuFrame ~= nil and GameMenuFrame:IsShown()
end

---------------------------------------------------------------------------
-- Dialog frames
---------------------------------------------------------------------------

local DIALOG_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

-- Movable, ESC-closable dialog with a title and a close button. Starts hidden.
function BOLT:CreateDialog(globalName, width, height, title)
    local frame = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop(DIALOG_BACKDROP)
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    if title then
        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        frame.title:SetPoint("TOP", 0, -16)
        frame.title:SetText(title)
    end

    frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.closeButton:SetPoint("TOPRIGHT", -4, -4)

    if globalName then
        tinsert(UISpecialFrames, globalName)
    end
    return frame
end

function BOLT:CreateButton(parent, text, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height or 22)
    button:SetText(text)
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

function BOLT:OpenConfigPanel()
    local config = self.modules.config
    if not config then return end
    self:ActivateModule(config)
    config:Open()
end
