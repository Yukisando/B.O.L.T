-- B.O.L.T Skyriding Module
-- While skyriding, remaps strafe keys to turn (and optionally forward/back to pitch).
--
-- Override bindings can't be changed by addon code in combat, so the switching is
-- done by a secure handler: a state driver flips "state-flight" on [advflyable,flying]
-- and a restricted snippet sets/clears the bindings, which works in and out of combat.
-- Addon code only refines the decision out of combat through the "gate" attribute
-- (steady flight vs skyriding, mouse-button requirement) and the key list.

local ADDON_NAME, BOLT = ...

local Skyriding = {
    displayName = "Skyriding Controls",
}

local STEADY_FLIGHT_AURA = 404468

local driver
local leftDown, rightDown = false, false
local gateValue
local lastSignature

local APPLY_SNIPPET = [[
    if name ~= "state-flight" and name ~= "gate" and name ~= "enabled" and name ~= "bindingsversion" then
        return
    end
    self:ClearBindings()
    if self:GetAttribute("enabled") and self:GetAttribute("gate") and self:GetAttribute("state-flight") == "on" then
        for i = 1, self:GetAttribute("_count") or 0 do
            self:SetBinding(true, self:GetAttribute("_key" .. i), self:GetAttribute("_cmd" .. i))
        end
    end
]]

function Skyriding:IsSupported()
    -- WoW: Forever has no flying.
    return not BOLT.isForever
end

local function Cfg(key)
    return BOLT:GetConfig("skyriding", key)
end

local function IsSteadyFlight()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(STEADY_FLIGHT_AURA)
    if BOLT.IsSecret(aura) then return false end
    return aura ~= nil
end

local function IsActive()
    return driver ~= nil and driver:GetAttribute("enabled") and driver:GetAttribute("gate")
        and driver:GetAttribute("state-flight") == "on"
end

-- Copy the player's current movement keys into the driver. Only called while the
-- overrides are off, so GetBindingKey still reports the normal bindings.
local function RebuildKeyList()
    if InCombatLockdown() or not driver or IsActive() then return end

    local pairsList = {
        { "TURNLEFT", "STRAFELEFT" },
        { "TURNRIGHT", "STRAFERIGHT" },
    }
    if Cfg("enablePitchControl") then
        local invert = Cfg("invertPitch")
        table.insert(pairsList, { invert and "PITCHDOWN" or "PITCHUP", "MOVEFORWARD" })
        table.insert(pairsList, { invert and "PITCHUP" or "PITCHDOWN", "MOVEBACKWARD" })
    end

    local bindings = {}
    for _, entry in ipairs(pairsList) do
        for _, key in ipairs({ GetBindingKey(entry[2]) }) do
            table.insert(bindings, { key, entry[1] })
        end
    end

    -- Re-applying clears override bindings, which fires UPDATE_BINDINGS again; only
    -- push a list that actually changed so that event can't loop.
    local signature = {}
    for _, binding in ipairs(bindings) do
        table.insert(signature, binding[1] .. "=" .. binding[2])
    end
    signature = table.concat(signature, ",")
    if signature == lastSignature then return end
    lastSignature = signature

    for index, binding in ipairs(bindings) do
        driver:SetAttribute("_key" .. index, binding[1])
        driver:SetAttribute("_cmd" .. index, binding[2])
    end
    driver:SetAttribute("_count", #bindings)
    driver:SetAttribute("bindingsversion", (driver:GetAttribute("bindingsversion") or 0) + 1)
end

local function UpdateGate()
    if InCombatLockdown() or not driver then return end

    local gate = not IsSteadyFlight()
    if gate and Cfg("requireMouseButton") then
        gate = leftDown and not rightDown
    end
    if gate ~= gateValue then
        gateValue = gate
        driver:SetAttribute("gate", gate)
        BOLT:Debug("Skyriding overrides " .. (IsActive() and "ON" or "OFF"))
    end
end

-- Bring the secure driver in line with the module state. Out of combat only.
function Skyriding:Sync()
    if InCombatLockdown() then
        self:ScheduleAfterCombat()
        return
    end

    if not driver then
        driver = CreateFrame("Frame", "BOLTSkyridingDriver", UIParent, "SecureHandlerAttributeTemplate")
        driver:SetAttribute("_onattributechanged", APPLY_SNIPPET)
        RegisterStateDriver(driver, "flight", "[advflyable,flying] on; off")
    end

    if not self.active then
        driver:SetAttribute("enabled", false)
        ClearOverrideBindings(driver)
        return
    end
    RebuildKeyList()
    UpdateGate()
    if not driver:GetAttribute("enabled") then
        driver:SetAttribute("enabled", true)
    end
end

function Skyriding:ScheduleAfterCombat()
    if self.combatWaiter then
        self.combatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local waiter = CreateFrame("Frame")
    waiter:SetScript("OnEvent", function(frame)
        frame:UnregisterAllEvents()
        self:Sync()
    end)
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.combatWaiter = waiter
end

function Skyriding:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" then
            local down = event == "GLOBAL_MOUSE_DOWN"
            if arg1 == "LeftButton" then
                leftDown = down
            elseif arg1 == "RightButton" then
                rightDown = down
            else
                return
            end
        elseif event == "UNIT_AURA" and arg1 ~= "player" then
            return
        elseif event == "UPDATE_BINDINGS" or event == "PLAYER_REGEN_ENABLED" then
            RebuildKeyList()
        end
        UpdateGate()
    end)
end

function Skyriding:OnEnable()
    for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "UNIT_AURA", "UPDATE_BINDINGS",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD" }) do
        self.eventFrame:RegisterEvent(event)
    end
    self:Sync()
end

function Skyriding:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    -- In combat the snippet keeps the overrides tied to flight state until Sync runs.
    self:Sync()
end

-- Turn the overrides off so GetBindingKey sees the real bindings, then rebuild.
local function ResetOverrides()
    driver:SetAttribute("gate", false)
    gateValue = false
end

-- Called by the settings UI when pitch or mouse options change.
function Skyriding:OnSettingChanged()
    if InCombatLockdown() or not driver then return end
    ResetOverrides()
    self:Sync()
end

-- /bolt reset, /boltreset: clear any override bindings this module owns.
function Skyriding:EmergencyReset()
    leftDown, rightDown = false, false
    if not driver then return end
    if InCombatLockdown() then
        BOLT:Print("Skyriding: key overrides will be cleared when combat ends.")
        self:ScheduleAfterCombat()
        return
    end
    ResetOverrides()
    ClearOverrideBindings(driver)
    BOLT:Print("Skyriding key overrides cleared.")
end

SLASH_BOLTRESET1 = "/boltreset"
SLASH_BOLTRESET2 = "/boltnuke"
SlashCmdList.BOLTRESET = function()
    Skyriding:EmergencyReset()
end

BOLT:RegisterModule("skyriding", Skyriding)
