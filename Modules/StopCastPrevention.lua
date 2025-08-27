-- ColdSnap Stop Cast Prevention Module
-- Prevents escape key from stopping casts while maintaining all other escape functionality

local ADDON_NAME, ColdSnap = ...

-- Create the StopCastPrevention module
local StopCastPrevention = {}

-- Store original escape function
local originalToggleGameMenu = nil
local isHooked = false

function StopCastPrevention:OnInitialize()
    self.parent:Debug("StopCastPrevention module initializing...")
end

function StopCastPrevention:OnEnable()
    if not self.parent:IsModuleEnabled("stopCastPrevention") then
        return
    end
    
    self.parent:Debug("StopCastPrevention module enabling...")
    self:EnableStopCastPrevention()
end

function StopCastPrevention:OnDisable()
    self:DisableStopCastPrevention()
end

function StopCastPrevention:EnableStopCastPrevention()
    if isHooked then
        return -- Already enabled
    end
    
    -- Store the original function and replace it with our custom handler
    originalToggleGameMenu = ToggleGameMenu
    ToggleGameMenu = function()
        StopCastPrevention:HandleEscape()
    end
    
    isHooked = true
    self.parent:Debug("Stop cast prevention enabled")
end

function StopCastPrevention:DisableStopCastPrevention()
    if not isHooked then
        return
    end
    
    -- Restore the original function
    if originalToggleGameMenu then
        ToggleGameMenu = originalToggleGameMenu
        originalToggleGameMenu = nil
    end
    
    isHooked = false
    self.parent:Debug("Stop cast prevention disabled")
end

function StopCastPrevention:HandleEscape()
    -- Check if player is currently casting or channeling
    local casting = UnitCastingInfo("player")
    local channeling = UnitChannelInfo("player")
    
    -- If casting or channeling, handle escape without stopping the cast
    if casting or channeling then
        self:PerformEscapeWithoutStopCast()
    else
        -- Not casting, perform normal escape behavior
        if originalToggleGameMenu then
            originalToggleGameMenu()
        end
    end
end

function StopCastPrevention:PerformEscapeWithoutStopCast()
    -- Handle escape key functionality without stopping casts
    
    -- First check for static popups and close them
    if StaticPopup_EscapePressed and StaticPopup_EscapePressed() then
        return -- A popup was closed, we're done
    end
    
    -- Close dropdown menus
    if CloseDropDownMenus then
        CloseDropDownMenus()
    end
    
    -- Check for tooltip and close it
    if GameTooltip and GameTooltip:IsShown() then
        GameTooltip:Hide()
        return
    end
    
    -- Close various UI frames in priority order
    local framesToCheck = {
        { frame = GameMenuFrame, closeFunc = function() HideUIPanel(GameMenuFrame) end },
        { frame = SpellBookFrame, closeFunc = function() HideUIPanel(SpellBookFrame) end },
        { frame = CharacterFrame, closeFunc = function() HideUIPanel(CharacterFrame) end },
        { frame = PVPUIFrame, closeFunc = function() HideUIPanel(PVPUIFrame) end },
        { frame = EncounterJournal, closeFunc = function() HideUIPanel(EncounterJournal) end },
        { frame = CollectionsJournal, closeFunc = function() HideUIPanel(CollectionsJournal) end },
        { frame = AchievementFrame, closeFunc = function() HideUIPanel(AchievementFrame) end },
        { frame = QuestLogFrame, closeFunc = function() HideUIPanel(QuestLogFrame) end },
        { frame = FriendsFrame, closeFunc = function() HideUIPanel(FriendsFrame) end },
        { frame = GuildFrame, closeFunc = function() HideUIPanel(GuildFrame) end },
        { frame = LFDParentFrame, closeFunc = function() HideUIPanel(LFDParentFrame) end },
        { frame = HelpFrame, closeFunc = function() HideUIPanel(HelpFrame) end },
        { frame = SettingsPanel, closeFunc = function() HideUIPanel(SettingsPanel) end },
    }
    
    -- Try to close any open frames
    for _, frameInfo in ipairs(framesToCheck) do
        if frameInfo.frame and frameInfo.frame:IsShown() then
            frameInfo.closeFunc()
            return -- Only close one frame at a time
        end
    end
    
    -- If no frames were open, show the game menu
    if not GameMenuFrame:IsShown() then
        ShowUIPanel(GameMenuFrame)
    end
end

-- Register the module
ColdSnap:RegisterModule("StopCastPrevention", StopCastPrevention)
