-- B.O.L.T Roleplay Module
-- Total RP 3 helpers: an IC/OOC toggle keybind that can also show/hide the TRP
-- toolbar and switch Edit Mode layouts.

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

BOLT:RegisterModule("roleplay", Roleplay)
