-- B.O.L.T Chill Music Module (Indoor Music Only)
-- Simple: Mutes music when outdoors, unmutes when indoors

local ADDON_NAME, BOLT = ...

local ChillMusic = {}

-- State tracking
ChillMusic.isIndoors = false
ChillMusic.previousVolume = nil

function ChillMusic:OnInitialize()
    self.parent = BOLT
    
    -- Create event frame
    self.eventFrame = CreateFrame("Frame")
end

function ChillMusic:OnEnable()
    if not self.parent:IsModuleEnabled("chillMusic") then
        return
    end

    -- Register events
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    
    local module = self
    self.eventFrame:SetScript("OnEvent", function(_, event, ...)
        C_Timer.After(0.5, function()
            module:CheckEnvironment()
        end)
    end)

    -- Initial check
    self:CheckEnvironment()
end

function ChillMusic:OnDisable()
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
    end
    
    -- Restore music volume if we muted it
    if self.previousVolume then
        SetCVar("Sound_MusicVolume", self.previousVolume)
        self.previousVolume = nil
    end
end

function ChillMusic:CheckEnvironment()
    local wasIndoors = self.isIndoors
    self.isIndoors = IsIndoors()
    
    -- Only act on changes
    if wasIndoors ~= self.isIndoors then
        if self.isIndoors then
            -- Indoors: Restore music volume
            if self.previousVolume then
                SetCVar("Sound_MusicVolume", self.previousVolume)
                self.previousVolume = nil
            end
        else
            -- Outdoors: Mute music
            if not self.previousVolume then
                self.previousVolume = GetCVar("Sound_MusicVolume")
            end
            SetCVar("Sound_MusicVolume", "0")
        end
    end
end

-- Register the module
BOLT:RegisterModule("chillMusic", ChillMusic)
