-- B.O.L.T Smart Ground Mount Module
-- When in a no-fly zone, summons a random ground-only mount from your favorites
-- instead of letting WoW pick a flying mount that awkwardly walks on the ground.
--
-- Bind BOLT_SMART_MOUNT (under B.O.L.T in Key Bindings) in place of your
-- normal "Summon Random Favorite Mount" key.

local ADDON_NAME, BOLT = ...

local SmartGroundMount = {}

-- Mount type IDs that can fly — exclude these so we never land a flying model
-- on the ground when flying isn't allowed.
--   232 = Standard flying mount
--   247 = Dynamic flying (Dragonriding / Skyriding)
local FLYING_MOUNT_TYPES = {
    [232] = true,
    [247] = true,
}

-- True when the player cannot fly here (indoors always counts as ground-only).
local function IsGroundOnlyArea()
    if not IsOutdoors() then return true end
    if not IsFlyableArea() then return true end
    return false
end

-- Returns a list of favorite, usable, collected mounts that are not flying types.
local function GetFavoriteGroundMounts()
    local mounts = {}
    local mountIDs = C_MountJournal.GetMountIDs()
    for _, mountID in ipairs(mountIDs) do
        local _, _, _, _, isUsable, _, isFavorite, _, _, shouldHideOnChar, isCollected =
            C_MountJournal.GetMountInfoByID(mountID)
        if isFavorite and isUsable and isCollected and not shouldHideOnChar then
            local _, _, _, _, mountTypeID = C_MountJournal.GetMountInfoExtraByID(mountID)
            if not FLYING_MOUNT_TYPES[mountTypeID] then
                table.insert(mounts, mountID)
            end
        end
    end
    return mounts
end

-- Global keybinding handler — always defined so the binding works at load time.
-- If the module is disabled it falls back to the default random-favorite behavior.
function BOLT_SmartGroundMount()
    BOLT:Debug("SmartGroundMount: keybind triggered")

    if InCombatLockdown() then return end

    -- Dismount if already mounted (mirrors default summon-toggle behavior).
    if IsMounted() then
        Dismount()
        return
    end

    local mod = BOLT and BOLT.modules and BOLT.modules["smartGroundMount"]
    if mod and mod.isEnabled and IsGroundOnlyArea() then
        local groundMounts = GetFavoriteGroundMounts()
        BOLT:Debug("SmartGroundMount: " .. #groundMounts .. " ground favorite(s) found")

        if #groundMounts > 0 then
            local pick = groundMounts[math.random(1, #groundMounts)]
            BOLT:Debug("SmartGroundMount: summoning mountID " .. tostring(pick))
            C_MountJournal.SummonByID(pick)
            return
        end

        -- No ground-only favorites — tell the player and fall through.
        BOLT:Print("Smart Ground Mount: no ground-only favorites found, using random favorite.")
    else
        BOLT:Debug("SmartGroundMount: module disabled or flyable area — using default")
    end

    -- Fallback: WoW's built-in random favorite (may pick a flyer, but that's fine here).
    C_MountJournal.SummonByID(0)
end

function SmartGroundMount:OnInitialize()
    self.isEnabled = false
end

function SmartGroundMount:OnEnable()
    self.isEnabled = true
end

function SmartGroundMount:OnDisable()
    self.isEnabled = false
end

BOLT:RegisterModule("smartGroundMount", SmartGroundMount)
