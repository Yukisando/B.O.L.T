-- B.O.L.T Saved Instances Module
-- Lists current-expansion dungeons and raids and your lockout progress.

local ADDON_NAME, BOLT = ...

local SavedInstances = {
    displayName = "Saved Instances",
}

local function GetLockouts()
    local saved = {}
    for i = 1, GetNumSavedInstances() do
        local name, _, reset, _, locked, _, _, _, _, difficultyName, numEncounters, progress = GetSavedInstanceInfo(i)
        if name and locked and reset > 0 then
            saved[name] = saved[name] or {}
            table.insert(saved[name], {
                difficultyName = difficultyName,
                progress = progress,
                total = numEncounters,
            })
        end
    end
    return saved
end

-- Encounter Journal instances of the newest tier (the current expansion).
local function GetCurrentTierInstances(isRaid)
    local list = {}
    EJ_SelectTier(EJ_GetNumTiers())
    local index = 1
    while true do
        local instanceID, name = EJ_GetInstanceByIndex(index, isRaid)
        if not instanceID then break end
        table.insert(list, name)
        index = index + 1
    end
    return list
end

function SavedInstances:PrintUnsavedInstances()
    local lockouts = GetLockouts()
    local printedAny = false

    BOLT:Print("--- Saved Instances (Current Expansion) ---")
    for _, category in ipairs({ { "Dungeons", false }, { "Raids", true } }) do
        local instances = GetCurrentTierInstances(category[2])
        if #instances > 0 then
            printedAny = true
            print("|cffffcc00" .. category[1] .. ":|r")
            for _, name in ipairs(instances) do
                local entries = lockouts[name]
                if not entries then
                    print("  |cff00ff00" .. name .. " - Not saved|r")
                else
                    for _, entry in ipairs(entries) do
                        local color = entry.progress >= entry.total and "|cff888888" or "|cffff8800"
                        print(("  %s%s (%s): %d/%d|r"):format(color, name, entry.difficultyName,
                            entry.progress, entry.total))
                    end
                end
            end
        end
    end

    if not printedAny then
        print("  No current expansion instances found in the Encounter Journal.")
    end
end

function SavedInstances:OnEnable()
    -- Lockout info is only accurate after the server answers this request.
    RequestRaidInfo()
end

SLASH_BOLTSAVED1 = "/boltsaved"
SlashCmdList.BOLTSAVED = function()
    if BOLT:IsModuleEnabled("savedInstances") then
        RequestRaidInfo()
        SavedInstances:PrintUnsavedInstances()
    else
        BOLT:Print("The Saved Instances module is disabled.")
    end
end

BOLT:RegisterModule("savedInstances", SavedInstances)
