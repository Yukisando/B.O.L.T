-- B.O.L.T Sound Muter Module
-- Mutes specific sound IDs from playing in the game

local ADDON_NAME, BOLT = ...

local SoundMuter = {}
local MAX_RECENT_SOUNDS = 10

function SoundMuter:OnInitialize()
    self.recentSounds = {}
    self.mutedLookup = {}

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

function SoundMuter:RebuildLookup()
    wipe(self.mutedLookup)

    local list = self:GetMutedSoundIDs()
    for _, id in ipairs(list) do
        self.mutedLookup[id] = true
    end
end

function SoundMuter:IsMuted(id)
    return self.mutedLookup[id] == true
end

function SoundMuter:InstallSoundHooks()
    if self.hooksInstalled then return end
    self.hooksInstalled = true

    local module = self

    local OriginalPlaySound = PlaySound
    local OriginalPlaySoundFile = PlaySoundFile

    PlaySound = function(soundKitID, ...)
        if type(soundKitID) == "number" then
            module:RecordRecentSound(soundKitID, "SoundKit")

            if module:IsMuted(soundKitID) then
                return
            end
        end

        return OriginalPlaySound(soundKitID, ...)
    end

    PlaySoundFile = function(soundFile, ...)
        if not soundFile then
            return OriginalPlaySoundFile(soundFile, ...)
        end

        local id = tonumber(soundFile)

        if id then
            module:RecordRecentSound(id, "FileID")

            if module:IsMuted(id) then
                return
            end
        else
            module:RecordRecentSound(soundFile, "FilePath")
        end

        return OriginalPlaySoundFile(soundFile, ...)
    end

    if C_Sound and C_Sound.PlaySoundKitID then
        local OriginalPlaySoundKitID = C_Sound.PlaySoundKitID
        C_Sound.PlaySoundKitID = function(soundKitID, ...)
            if type(soundKitID) == "number" then
                module:RecordRecentSound(soundKitID, "SoundKit")

                if module:IsMuted(soundKitID) then
                    return
                end
            end

            return OriginalPlaySoundKitID(soundKitID, ...)
        end
    end

    if C_Sound and C_Sound.PlayVocalErrorSoundID then
        local OriginalPlayVocalErrorSoundID = C_Sound.PlayVocalErrorSoundID
        C_Sound.PlayVocalErrorSoundID = function(vocalErrorSoundID, ...)
            if type(vocalErrorSoundID) == "number" then
                module:RecordRecentSound(vocalErrorSoundID, "VocalError")

                if module:IsMuted(vocalErrorSoundID) then
                    return
                end
            end

            return OriginalPlayVocalErrorSoundID(vocalErrorSoundID, ...)
        end
    end
end

function SoundMuter:RecordRecentSound(id, sourceType)
    if #self.recentSounds > 0 then
        local last = self.recentSounds[1]
        if last.id == id and last.sourceType == sourceType then
            return
        end
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
    self:RebuildLookup()
end

function SoundMuter:OnDisable()
    wipe(self.mutedLookup)
end

function SoundMuter:GetMutedSoundIDs()
    local cfg = self.parent:GetConfig("soundMuter") or {}
    return cfg.mutedSoundIDs or {}
end

function SoundMuter:AddSoundID(soundID)
    local list = self:GetMutedSoundIDs()

    for _, id in ipairs(list) do
        if id == soundID then
            return false
        end
    end

    table.insert(list, soundID)
    self.parent:SetConfig(list, "soundMuter", "mutedSoundIDs")

    self:RebuildLookup()

    return true
end

function SoundMuter:RemoveSoundID(soundID)
    local list = self:GetMutedSoundIDs()

    for i, id in ipairs(list) do
        if id == soundID then
            table.remove(list, i)
            self.parent:SetConfig(list, "soundMuter", "mutedSoundIDs")

            self:RebuildLookup()
            return true
        end
    end

    return false
end

BOLT:RegisterModule("soundMuter", SoundMuter)
