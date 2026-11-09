-- B.O.L.T Roleplay Module
-- Total RP 3 helpers: an IC/OOC toggle keybind that can also show/hide the TRP
-- toolbar and switch Edit Mode layouts. Also keybinds for everyday emotes (hello, thanks, sit).

local ADDON_NAME, BOLT = ...

local Roleplay = {
    displayName = "Roleplay",
    alwaysOn = true,
}

-- C_EditMode.GetLayouts().layouts lists only custom layouts; the active-layout index
-- also counts the two built-in presets (Modern, Classic) in front of them.
local PRESET_LAYOUT_COUNT = 2

function Roleplay:IsTRP3Loaded()
    return AddOn_TotalRP3 ~= nil and AddOn_TotalRP3.Player ~= nil and AddOn_TotalRP3.Enums ~= nil
end

function Roleplay:GetCustomLayouts()
    local info = C_EditMode.GetLayouts()
    return info and info.layouts or {}
end

function Roleplay:GetLayoutName(index)
    local layout = index and index > 0 and self:GetCustomLayouts()[index]
    return layout and layout.layoutName
end

function Roleplay:ApplyLayout(index)
    if not index or index <= 0 or not self:GetCustomLayouts()[index] then return end
    if InCombatLockdown() then
        BOLT:Print("Edit Mode layout can't change in combat.")
        return
    end
    -- What EditModeManagerFrame:SelectLayout does internally, without calling into
    -- (and tainting) the Edit Mode frame.
    C_EditMode.SetActiveLayout(index + PRESET_LAYOUT_COUNT)
end

function Roleplay:ToggleStatus()
    if not self:IsTRP3Loaded() then
        BOLT:Print("|cffff6b6bTotal RP 3 is not installed or loaded.|r")
        return
    end

    local user = AddOn_TotalRP3.Player.GetCurrentUser()
    local statuses = AddOn_TotalRP3.Enums.ROLEPLAY_STATUS
    -- Unset/unknown counts as OOC, so the first press always goes IC.
    local goingIC = user:GetRoleplayStatus() ~= statuses.IN_CHARACTER
    user:SetRoleplayStatus(goingIC and statuses.IN_CHARACTER or statuses.OUT_OF_CHARACTER)

    if BOLT:GetConfig("roleplay", "toggleTrpToolbar") and TRP3_ToolbarFrame then
        TRP3_ToolbarFrame:SetShown(goingIC)
    end
    self:ApplyLayout(BOLT:GetConfig("roleplay", goingIC and "editModeProfileIndex" or "editModeOOCProfileIndex"))

    BOLT:Print("TRP3 status: " .. (goingIC and "|cff55ff55In Character|r" or "|cffffaaaaOut of Character|r"))
end

function BOLT_ToggleTRP3Status()
    Roleplay:ToggleStatus()
end

-- Everyday emotes on a key, no Total RP 3 needed. DoEmote aims at your target when you have one,
-- like typing /hello.
function BOLT_EmoteHello() DoEmote("HELLO") end
function BOLT_EmoteBye() DoEmote("BYE") end
function BOLT_EmoteThanks() DoEmote("THANK") end
function BOLT_EmoteSit() DoEmote("SIT") end

---------------------------------------------------------------------------
-- Auto-thank: another player buffs you, you /thank them 2 seconds later.
-- Skipped in combat (aura data can be secret there on Midnight, and nobody wants emote spam
-- mid-pull) and at most once a minute per player, so a paladin rebuffing the raid gets one thanks.
---------------------------------------------------------------------------

local THANK_DELAY = 2
local THANK_COOLDOWN = 60
local lastThanked = {} -- caster name -> GetTime()

local function ThankCaster(aura)
    if BOLT.IsSecret(aura) or not aura.isHelpful then return end
    local source = aura.sourceUnit
    if BOLT.IsSecret(source) or type(source) ~= "string" then return end
    if UnitIsUnit(source, "player") or not UnitIsPlayer(source) then return end
    if not UnitIsFriend("player", source) then return end
    local name = GetUnitName(source, true)
    if BOLT.IsSecret(name) or not name or name == UNKNOWNOBJECT then return end

    local now = GetTime()
    if lastThanked[name] and now - lastThanked[name] < THANK_COOLDOWN then return end
    lastThanked[name] = now
    C_Timer.After(THANK_DELAY, function()
        if InCombatLockdown() or not BOLT:GetConfig("roleplay", "autoThankBuffs") then return end
        DoEmote("THANK", name)
    end)
end

local function OnPlayerAura(_, _, unit, updateInfo)
    if unit ~= "player" or InCombatLockdown() then return end
    if not BOLT:GetConfig("roleplay", "autoThankBuffs") then return end
    if BOLT.IsSecret(updateInfo) or type(updateInfo) ~= "table" then return end
    -- A full update (login, zoning) isn't someone buffing you right now.
    if updateInfo.isFullUpdate or not updateInfo.addedAuras then return end
    for _, aura in ipairs(updateInfo.addedAuras) do
        pcall(ThankCaster, aura)
    end
end

function Roleplay:OnInitialize()
    self.auraFrame = CreateFrame("Frame")
    self.auraFrame:SetScript("OnEvent", OnPlayerAura)
end

function Roleplay:OnEnable()
    self.auraFrame:RegisterUnitEvent("UNIT_AURA", "player")
end

function Roleplay:OnDisable()
    self.auraFrame:UnregisterAllEvents()
end

BOLT:RegisterModule("roleplay", Roleplay)
