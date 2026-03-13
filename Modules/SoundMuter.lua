-- B.O.L.T Sound Muter Module
-- Mutes specific sound IDs from playing in the game

local ADDON_NAME, BOLT = ...

local SoundMuter = {}
local MAX_RECENT_SOUNDS = 10

function SoundMuter:OnInitialize()
    self.recentSounds = {}
    self:BuildSoundKitCache()
    self:InstallSoundHooks()
end

function SoundMuter:BuildSoundKitCache()
    self.soundKitNames = {}
    if not SOUNDKIT then return end
    for name, id in pairs(SOUNDKIT) do
        self.soundKitNames[id] = name
    end
end

-- Hook PlaySound and PlaySoundFile to capture recently played sounds
function SoundMuter:InstallSoundHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    local module = self

    hooksecurefunc("PlaySound", function(soundKitID)
        if type(soundKitID) ~= "number" or soundKitID <= 0 then return end
        module:RecordRecentSound(soundKitID, "SoundKit")
    end)

    hooksecurefunc("PlaySoundFile", function(soundFile)
        if not soundFile then return end
        local id = tonumber(soundFile)
        if id and id > 0 then
            module:RecordRecentSound(id, "FileID")
        elseif type(soundFile) == "string" then
            module:RecordRecentSound(soundFile, "FilePath")
        end
    end)
end

function SoundMuter:RecordRecentSound(id, sourceType)
    -- Skip duplicate of the most recent entry to reduce spam
    if #self.recentSounds > 0 then
        local last = self.recentSounds[1]
        if last.id == id and last.sourceType == sourceType then return end
    end

    local entry = {
        id = id,
        sourceType = sourceType,
        timestamp = GetTime(),
    }

    if sourceType == "SoundKit" and self.soundKitNames then
        entry.name = self.soundKitNames[id]
    end

    table.insert(self.recentSounds, 1, entry)

    while #self.recentSounds > MAX_RECENT_SOUNDS do
        table.remove(self.recentSounds)
    end
end

function SoundMuter:GetRecentSounds()
    return self.recentSounds or {}
end

function SoundMuter:OnEnable()
    local cfg = self.parent:GetConfig("soundMuter") or {}
    local mutedSounds = cfg.mutedSoundIDs or {}
    for _, soundID in ipairs(mutedSounds) do
        MuteSoundFile(soundID)
    end
end

function SoundMuter:OnDisable()
    local cfg = self.parent:GetConfig("soundMuter") or {}
    local mutedSounds = cfg.mutedSoundIDs or {}
    for _, soundID in ipairs(mutedSounds) do
        UnmuteSoundFile(soundID)
    end
end

function SoundMuter:GetMutedSoundIDs()
    local cfg = self.parent:GetConfig("soundMuter") or {}
    return cfg.mutedSoundIDs or {}
end

function SoundMuter:AddSoundID(soundID)
    local list = self:GetMutedSoundIDs()
    for _, id in ipairs(list) do
        if id == soundID then return false end
    end
    table.insert(list, soundID)
    self.parent:SetConfig(list, "soundMuter", "mutedSoundIDs")
    if self.parent:IsModuleEnabled("soundMuter") then
        MuteSoundFile(soundID)
    end
    return true
end

function SoundMuter:RemoveSoundID(soundID)
    local list = self:GetMutedSoundIDs()
    for i, id in ipairs(list) do
        if id == soundID then
            table.remove(list, i)
            self.parent:SetConfig(list, "soundMuter", "mutedSoundIDs")
            UnmuteSoundFile(soundID)
            return true
        end
    end
    return false
end

BOLT:RegisterModule("soundMuter", SoundMuter)
