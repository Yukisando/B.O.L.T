-- B.O.L.T Skyriding Module
-- While skyriding, remaps strafe keys to turn (and optionally forward/back to pitch).
--
-- Override bindings can't be changed by addon code in combat, so the switching is
-- done by a secure handler: a state driver flips "state-flight" on [advflyable,flying]
-- and a restricted snippet sets/clears the bindings, which works in and out of combat.
-- Addon code only refines the decision out of combat through the "gate" attribute
-- (steady flight vs skyriding, mouse-button requirement) and the key list.
--
-- Stuck keys: WoW sends a key's release to whatever the key is bound to *at release
-- time*. If the bindings switch while A is held (landing mid-turn), the release goes
-- to STRAFELEFT and TURNLEFT never stops. So while a remapped key is held the driver
-- is frozen ("freeze"), and the switch happens once every remapped key is released.
-- Addon code can't set attributes in combat, so a switch there can still strand a
-- key; that is detected and repaired after combat by forcing the binding the key was
-- pressed with ("force") until the player taps that key once.

local ADDON_NAME, BOLT = ...

local Skyriding = {
    displayName = "Skyriding Controls",
}

local STEADY_FLIGHT_AURA = 404468

local driver
local keyWatcher
local leftDown, rightDown = false, false
local gateValue
local lastSignature

local remappedKeys = {} -- base key ("A") -> true
local pressedWith = {}  -- held remapped key -> were overrides applied when it went down
local needsRepair = {}  -- key whose release went to the wrong command -> state it needs

-- Restricted snippets can't read attributes starting with "_", so the key list uses
-- plain names; the snippet ignores changes to anything but the names it watches.
local APPLY_SNIPPET = [[
    if name ~= "state-flight" and name ~= "gate" and name ~= "enabled" and name ~= "bindingsversion"
        and name ~= "freeze" and name ~= "force" then
        return
    end

    local want
    local force = self:GetAttribute("force")
    if force then
        want = force == "on"
    elseif self:GetAttribute("freeze") then
        return
    else
        want = self:GetAttribute("gate") and self:GetAttribute("state-flight") == "on"
    end
    want = want and self:GetAttribute("enabled") and true or false

    self:ClearBindings()
    if want then
        for i = 1, self:GetAttribute("count") or 0 do
            self:SetBinding(true, self:GetAttribute("key" .. i), self:GetAttribute("cmd" .. i))
        end
    end
    self:SetAttribute("applied", want)
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

local function IsApplied()
    return driver ~= nil and driver:GetAttribute("applied") == true
end

-- Attributes only change out of combat and only when the value differs, since every
-- change re-runs the snippet.
local function SetDriverAttribute(name, value)
    if InCombatLockdown() or not driver then return false end
    if driver:GetAttribute(name) ~= value then
        driver:SetAttribute(name, value)
    end
    return true
end

-- Copy the player's current movement keys into the driver. Only called while the
-- overrides are off, so GetBindingKey still reports the normal bindings.
local function RebuildKeyList()
    if InCombatLockdown() or not driver or IsApplied() then return end

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

    wipe(remappedKeys)
    for index, binding in ipairs(bindings) do
        driver:SetAttribute("key" .. index, binding[1])
        driver:SetAttribute("cmd" .. index, binding[2])
        -- Key events report the key without modifiers ("SHIFT-A" arrives as "A").
        remappedKeys[binding[1]:match("[^%-]+$") or binding[1]] = true
    end
    driver:SetAttribute("count", #bindings)
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
        SetDriverAttribute("gate", gate)
        BOLT:Debug("Skyriding overrides " .. (IsApplied() and "ON" or "OFF"))
    end
end

---------------------------------------------------------------------------
-- Held-key tracking
---------------------------------------------------------------------------

-- Out of combat: apply a pending repair, or freeze while remapped keys are held.
local function UpdateKeyGuards()
    if InCombatLockdown() or not driver then return end

    local repairKey, repairState = next(needsRepair)
    if repairKey then
        SetDriverAttribute("force", repairState and "on" or "off")
        SetDriverAttribute("freeze", false)
    else
        SetDriverAttribute("force", nil)
        SetDriverAttribute("freeze", next(pressedWith) ~= nil)
    end
end

local function OnKeyDown(_, key)
    if not remappedKeys[key] or pressedWith[key] ~= nil then return end -- ignore key repeat
    pressedWith[key] = IsApplied()
    UpdateKeyGuards()
end

local function OnKeyUp(_, key)
    if not remappedKeys[key] then return end
    local applied = IsApplied()

    if needsRepair[key] ~= nil then
        -- This tap went through the forced binding, which released the stuck command.
        if needsRepair[key] == applied then
            needsRepair[key] = nil
            BOLT:Debug("Skyriding: released stuck key " .. key)
        end
    elseif pressedWith[key] ~= nil and pressedWith[key] ~= applied then
        -- Bindings switched while the key was held (only possible in combat).
        needsRepair[key] = pressedWith[key]
        BOLT:Print(("Skyriding: %s may be stuck from switching in combat; it will be fixed by tapping %s once combat ends.")
            :format(pressedWith[key] and "turning" or "strafing", key))
    end

    pressedWith[key] = nil
    -- This handler runs before the binding sees the release; unfreezing right away
    -- would switch the binding first and strand the key all over again.
    C_Timer.After(0, UpdateKeyGuards)
end

local function CreateKeyWatcher()
    -- No parent, so it keeps listening while the UI is hidden (Alt+Z).
    keyWatcher = CreateFrame("Frame")
    keyWatcher:EnableKeyboard(true)
    keyWatcher:SetPropagateKeyboardInput(true)
    keyWatcher:SetScript("OnKeyDown", OnKeyDown)
    keyWatcher:SetScript("OnKeyUp", OnKeyUp)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

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
        CreateKeyWatcher()
    end

    keyWatcher:SetShown(self.active)
    if not self.active then
        wipe(pressedWith)
        wipe(needsRepair)
        SetDriverAttribute("force", nil)
        SetDriverAttribute("freeze", false)
        SetDriverAttribute("enabled", false)
        return
    end
    RebuildKeyList()
    UpdateGate()
    UpdateKeyGuards()
    SetDriverAttribute("enabled", true)
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
        if event == "PLAYER_REGEN_DISABLED" then
            -- Last chance before lockdown: a freeze can't be lifted in combat, so drop
            -- it and let the flight state drive the bindings (repaired afterwards).
            SetDriverAttribute("freeze", false)
            return
        elseif event == "GLOBAL_MOUSE_DOWN" or event == "GLOBAL_MOUSE_UP" then
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
        elseif event == "UPDATE_BINDINGS" then
            RebuildKeyList()
        elseif event == "PLAYER_REGEN_ENABLED" then
            RebuildKeyList()
            UpdateKeyGuards()
        end
        UpdateGate()
    end)
end

function Skyriding:OnEnable()
    for _, event in ipairs({ "GLOBAL_MOUSE_DOWN", "GLOBAL_MOUSE_UP", "UNIT_AURA", "UPDATE_BINDINGS",
        "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD" }) do
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
    wipe(pressedWith)
    wipe(needsRepair)
    SetDriverAttribute("force", nil)
    SetDriverAttribute("freeze", false)
    SetDriverAttribute("gate", false)
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
    driver:SetAttribute("applied", false)
    BOLT:Print("Skyriding key overrides cleared.")
end

SLASH_BOLTRESET1 = "/boltreset"
SLASH_BOLTRESET2 = "/boltnuke"
SlashCmdList.BOLTRESET = function()
    Skyriding:EmergencyReset()
end

BOLT:RegisterModule("skyriding", Skyriding)
