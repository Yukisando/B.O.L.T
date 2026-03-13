-- B.O.L.T Sound Muter Module
-- Mutes specific sound IDs from playing in the game

local ADDON_NAME, BOLT = ...

local SoundMuter = {}

function SoundMuter:OnInitialize() end

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
