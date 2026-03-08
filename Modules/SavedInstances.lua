-- B.O.L.T Saved Instances Module
-- Lists current expansion dungeons and raids the player hasn't completed this lockout period

local ADDON_NAME, BOLT = ...

local SavedInstances = {}

function SavedInstances:OnInitialize() end

function SavedInstances:OnEnable()
    self:RegisterSlashCommand()
end

function SavedInstances:OnDisable() end

function SavedInstances:RegisterSlashCommand()
    SLASH_BOLTSAVED1 = "/boltsaved"
    SlashCmdList["BOLTSAVED"] = function()
        self:PrintUnsavedInstances()
    end
end

function SavedInstances:GetSavedInstancesByName()
    local saved = {}
    local numSaved = GetNumSavedInstances()
    for i = 1, numSaved do
        local name, _, reset, difficulty, locked, _, _, isRaid, _, difficultyName, numEncounters, encounterProgress = GetSavedInstanceInfo(i)
        if locked and reset > 0 and name then
            if not saved[name] then
                saved[name] = {}
            end
            saved[name][difficulty] = {
                difficultyName = difficultyName,
                encounterProgress = encounterProgress,
                numEncounters = numEncounters,
                isRaid = isRaid,
            }
        end
    end
    return saved
end

function SavedInstances:GetCurrentExpansionInstances()
    local instances = { dungeons = {}, raids = {} }

    local tierIdx = EJ_GetNumTiers and EJ_GetNumTiers() or 0
    if tierIdx > 0 and EJ_SelectTier then
        EJ_SelectTier(tierIdx)

        local dIdx = 1
        while EJ_GetInstanceByIndex(dIdx, false) do
            local instID, instName = EJ_GetInstanceByIndex(dIdx, false)
            if instID and instName then
                table.insert(instances.dungeons, { id = instID, name = instName })
            end
            dIdx = dIdx + 1
        end

        local rIdx = 1
        while EJ_GetInstanceByIndex(rIdx, true) do
            local instID, instName = EJ_GetInstanceByIndex(rIdx, true)
            if instID and instName then
                table.insert(instances.raids, { id = instID, name = instName })
            end
            rIdx = rIdx + 1
        end
    end

    return instances
end

-- Build a structured list of instance status for both chat and tooltip use
function SavedInstances:BuildInstanceList()
    local saved = self:GetSavedInstancesByName()
    local expInstances = self:GetCurrentExpansionInstances()
    local results = { dungeons = {}, raids = {} }

    local function Categorize(list, output)
        for _, inst in ipairs(list) do
            local savedData = saved[inst.name]
            if savedData then
                for _, info in pairs(savedData) do
                    table.insert(output, {
                        name = inst.name,
                        difficultyName = info.difficultyName,
                        progress = info.encounterProgress,
                        total = info.numEncounters,
                        completed = info.encounterProgress >= info.numEncounters,
                    })
                end
            else
                table.insert(output, {
                    name = inst.name,
                    difficultyName = nil,
                    progress = 0,
                    total = 0,
                    completed = false,
                    notSaved = true,
                })
            end
        end
    end

    Categorize(expInstances.dungeons, results.dungeons)
    Categorize(expInstances.raids, results.raids)
    return results
end

function SavedInstances:PrintUnsavedInstances()
    local results = self:BuildInstanceList()
    BOLT:Print("--- Saved Instances (Current Expansion) ---")

    local function PrintCategory(label, list)
        if #list == 0 then return end
        BOLT:Print("|cffffcc00" .. label .. ":|r")
        for _, entry in ipairs(list) do
            if entry.notSaved then
                BOLT:Print("  |cff00ff00" .. entry.name .. " - Not saved|r")
            else
                local progress = entry.progress .. "/" .. entry.total
                local color = entry.completed and "|cff888888" or "|cffff8800"
                BOLT:Print("  " .. color .. entry.name .. " (" .. entry.difficultyName .. "): " .. progress .. "|r")
            end
        end
    end

    PrintCategory("Dungeons", results.dungeons)
    PrintCategory("Raids", results.raids)

    if #results.dungeons == 0 and #results.raids == 0 then
        BOLT:Print("  No current expansion instances found in the Encounter Journal.")
    end
end

BOLT:RegisterModule("savedInstances", SavedInstances)
