-- B.O.L.T Playground Module
-- Fun features with limited practical use

local ADDON_NAME, BOLT = ...

-- Create the Playground module
local Playground = {}

-- Reference to the Favorite Toy button
local favoriteToyButton = nil

-- Reference to the speedometer frame
local speedometerFrame = nil

-- Optional HereBeDragons library for precise world position
local HBD = LibStub and LibStub("HereBeDragons-2.0", true)

-- Position-based speed fallback (yards per second)
local lastX, lastY, lastT
local speedYPS = 0

local function GetPlayerSpeedYPS()
    -- 1) Try the simple API first (works for ground/steady flight)
    if GetUnitSpeed then
        local cur = GetUnitSpeed("player")
        if cur and cur > 0 then
            return cur -- already in yards/second
        end
    end

    -- 2) Fallback for Skyriding/edge cases: compute from position deltas
    local t = GetTime()

    -- Prefer HBD for precise world coords; fallback to UnitPosition
    local x, y, instance
    if HBD and HBD.GetPlayerWorldPosition then
        x, y, instance = HBD:GetPlayerWorldPosition()
    else
        local ux, uy = UnitPosition("player")
        x, y, instance = ux, uy, nil
    end
    if not x or not y then return 0 end

    if lastX and lastY and lastT then
        local dt = t - lastT
        if dt > 0 then
            local dx = x - lastX
            local dy = y - lastY
            speedYPS = math.sqrt(dx*dx + dy*dy) / dt
        end
    end

    lastX, lastY, lastT = x, y, t
    return speedYPS
end

function Playground:OnInitialize()
end

function Playground:OnEnable()
    
    if not self.parent:IsModuleEnabled("playground") then
        return
    end
    
    
    -- Hook into the game menu show event
    self:HookGameMenu()

    -- Create the speedometter UI
    self:CreateSpeedometer()
    
    -- Initialize special gamemode functionality
    self:InitializeSpecialGamemode()
    
    -- Register the copy mount slash command
    self:RegisterCopyMountCommand()

    -- Keep favorite toy button in sync with toy system updates
    if not self.toyEventFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("TOYS_UPDATED")
        f:RegisterEvent("PLAYER_LOGIN")
        f:SetScript("OnEvent", function(_, event)
            if event == "TOYS_UPDATED" or event == "PLAYER_LOGIN" then
                -- Defer slightly to avoid race conditions during load
                C_Timer.After(0.05, function()
                    if self and self.UpdateFavoriteToyButton then
                        self:UpdateFavoriteToyButton()
                    end
                end)
            end
        end)
        self.toyEventFrame = f
    end
    -- Initial sync
    self:UpdateFavoriteToyButton()
end

function Playground:OnDisable()
    -- Clean up buttons when disabling
    if favoriteToyButton then
        favoriteToyButton:Hide()
        favoriteToyButton = nil
    end

    -- Hide and remove speedometer when module is disabled
    if speedometerFrame then
        speedometerFrame:Hide()
        speedometerFrame:SetScript("OnUpdate", nil)
        speedometerFrame = nil
    end

    if self.toyEventFrame then
        self.toyEventFrame:UnregisterAllEvents()
        self.toyEventFrame:SetScript("OnEvent", nil)
        self.toyEventFrame = nil
    end
end

function Playground:HookGameMenu()
    -- Hook the GameMenuFrame show event
    if GameMenuFrame then
        GameMenuFrame:HookScript("OnShow", function()
            -- Small delay to ensure the menu is fully loaded
            C_Timer.After(0.05, function()
                self:UpdateGameMenu()
            end)
        end)
        
        GameMenuFrame:HookScript("OnHide", function()
            self:HideFavoriteToyButton()
        end)
    end
end

function Playground:UpdateGameMenu()
    
    if not self.parent:GetConfig("playground", "enabled") then
        return
    end
    
    -- Show favorite toy button if enabled or if a favorite toy is set
    local showFav = self.parent:GetConfig("playground", "showFavoriteToy")
    local favId = self.parent:GetConfig("playground", "favoriteToyId")
    if showFav or (favId ~= nil) then
        self:ShowFavoriteToyButton()
    else
        self:HideFavoriteToyButton()
    end
end

function Playground:ShowFavoriteToyButton()
    
    -- Create the button if it doesn't exist
    if not favoriteToyButton then
        self:CreateFavoriteToyButton()
    end
    
    -- Update the secure button with the current toy
    self:UpdateFavoriteToyButton()
    
    -- Use alpha to indicate usability (secure buttons should remain enabled)
    local toyId = self.parent:GetConfig("playground", "favoriteToyId")
    if favoriteToyButton then
        if toyId and PlayerHasToy(toyId) then
            favoriteToyButton:SetAlpha(1.0)
            
            -- Update visual state based on usability
            if not C_ToyBox.IsToyUsable(toyId) then
                favoriteToyButton:SetAlpha(0.7) -- Slightly dimmed when not usable
            end
        else
            favoriteToyButton:SetAlpha(0.5) -- More dimmed when toy not owned
        end

        favoriteToyButton:Show()
        self:PositionFavoriteToyButton()
    else
        -- Ensure the button exists and try again
        self:CreateFavoriteToyButton()
        if favoriteToyButton then
            self:UpdateFavoriteToyButton()
            favoriteToyButton:Show()
            self:PositionFavoriteToyButton()
        end
    end
    
end

function Playground:HideFavoriteToyButton()
    if favoriteToyButton then
        -- Defer the hide call to avoid taint issues when called from protected contexts
        C_Timer.After(0, function()
            if favoriteToyButton then
                favoriteToyButton:Hide()
            end
        end)
    end
end

function Playground:CreateFavoriteToyButton()
    -- Create a secure action button using ButtonUtils
    favoriteToyButton = BOLT.ButtonUtils:CreateSecureActionButton("BOLTFavoriteToyButton", UIParent, "Interface\\Icons\\INV_Misc_Toy_10")
    
    
    -- If that toy icon doesn't exist, fallback to a different one
    if not favoriteToyButton.icon:GetTexture() then
        BOLT.ButtonUtils:UpdateButtonIcon(favoriteToyButton, "Interface\\Icons\\INV_Misc_Toy_02") -- Jack-in-the-Box
        if not favoriteToyButton.icon:GetTexture() then
            BOLT.ButtonUtils:UpdateButtonIcon(favoriteToyButton, "Interface\\Icons\\INV_Misc_Gift_02") -- Generic gift/toy icon
        end
    end
    
    -- Configure the secure button for macro usage (which can call toy APIs)
    favoriteToyButton:SetAttribute("type", "macro")
    favoriteToyButton:RegisterForClicks("AnyUp")
    -- Start with an empty macro to avoid accidental calls
    favoriteToyButton:SetAttribute("macrotext", "")
    
    -- Delay the initial update to ensure game data is loaded
    C_Timer.After(0.1, function()
        self:UpdateFavoriteToyButton()
    end)
    
    -- Add hover effects (non-secure scripts are OK)
    favoriteToyButton:SetScript("OnEnter", function()
        local toyId = self.parent:GetConfig("playground", "favoriteToyId")
        if toyId and PlayerHasToy(toyId) then
            local _, toyName = C_ToyBox.GetToyInfo(toyId)
            if toyName then
                GameTooltip:SetOwner(favoriteToyButton, "ANCHOR_RIGHT")
                GameTooltip:SetText("Use " .. toyName, 1, 1, 1)
                GameTooltip:AddLine("Click to use toy (Out of combat only)", 0.8, 0.8, 0.8)
                GameTooltip:Show()
            end
        else
            GameTooltip:SetOwner(favoriteToyButton, "ANCHOR_RIGHT")
            GameTooltip:SetText("No favorite toy selected", 1, 0.82, 0)
            GameTooltip:AddLine("Configure in Interface > AddOns > B.O.L.T", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end
        -- Play hover sound
        if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        end
    end)
    
    favoriteToyButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Enable mouse clicks for secure actions
    favoriteToyButton:EnableMouse(true)
    favoriteToyButton:RegisterForClicks("AnyUp", "AnyDown")
end

function Playground:UpdateFavoriteToyButton()
    if not favoriteToyButton then
        return
    end
    local toyId = self.parent:GetConfig("playground", "favoriteToyId")

    -- Avoid changing secure attributes while in combat to prevent taint
    if InCombatLockdown() then
        C_Timer.After(1.0, function()
            if self and self.UpdateFavoriteToyButton then pcall(function() self:UpdateFavoriteToyButton() end) end
        end)
        return
    end

    if toyId then
        -- C_ToyBox.GetToyInfo returns: itemID, toyName, icon, isFavorite, hasFanfare, itemQuality
        local itemID, toyName, toyIcon = C_ToyBox.GetToyInfo(toyId)
        
        -- Check ownership using PlayerHasToy with itemID
        if itemID and toyName and PlayerHasToy(itemID) then
            -- Icon fallback from item cache if needed
            if not toyIcon and GetItemInfo then
                toyIcon = select(10, GetItemInfo(itemID))
            end
            
            -- Prefer using the toy ID when constructing the macro to avoid name-escaping problems
            local macroText
            if C_ToyBox and C_ToyBox.UseToyByID then
                macroText = "/run C_ToyBox.UseToyByID(" .. tostring(toyId) .. ")\n/run HideUIPanel(GameMenuFrame)"
            else
                macroText = "/usetoy " .. toyName .. "\n/run HideUIPanel(GameMenuFrame)"
            end
            favoriteToyButton:SetAttribute("macrotext", macroText)
            BOLT.ButtonUtils:UpdateButtonIcon(favoriteToyButton, toyIcon or "Interface\\Icons\\INV_Misc_Toy_10")
            -- Update alpha based on usability when API available
            if C_ToyBox and C_ToyBox.IsToyUsable then
                favoriteToyButton:SetAlpha(C_ToyBox.IsToyUsable(toyId) and 1.0 or 0.7)
            else
                favoriteToyButton:SetAlpha(1.0)
            end
            return
        end
    end

    -- Fallback: clear macro and reset icon
    favoriteToyButton:SetAttribute("macrotext", "")
    BOLT.ButtonUtils:UpdateButtonIcon(favoriteToyButton, "Interface\\Icons\\INV_Misc_Toy_10")
    favoriteToyButton:SetAlpha(0.5)
end

function Playground:PositionFavoriteToyButton()
    BOLT.ButtonUtils:PositionAboveGameMenuLeft(favoriteToyButton)
end

-- Create a very basic speedometter (speed label) anchored at top-left of the screen.
-- This is intentionally lightweight: it shows a numeric speed and updates frequently.
function Playground:CreateSpeedometer()
    if speedometerFrame then
        return
    end
    local f = CreateFrame("Frame", "BOLTSpeedometer", UIParent)
    f:SetSize(200, 22) -- Wider to accommodate both FPS and speed
    
    f:SetFrameStrata("BACKGROUND")

    -- No background texture - removed for cleaner look

    local txt = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetText("Loading...")

    f.text = txt
    f._updateTimer = 0
    f._fadeTimer = 0
    
    -- Set position and text alignment based on configuration
    self:SetStatsPosition(f)

    -- Store reference to parent module for config access
    local parentModule = self.parent

    -- Update every ~0.1s using a robust speed getter
    f:SetScript("OnUpdate", function(self, elapsed)
        self._updateTimer = self._updateTimer + elapsed
        
        -- Update speed display every 0.1s
        local speed = 0
        if self._updateTimer >= 0.1 then
            self._updateTimer = 0

            -- Get speed in yards/second using a helper that falls back to position deltas
            speed = GetPlayerSpeedYPS() or 0

            -- Use a standard run speed reference (about 7 y/s for a baseline run speed)
            local runSpeedRef = 7.0
            local percent = 0
            if runSpeedRef > 0 then
                percent = (speed / runSpeedRef) * 100
            end

            -- Determine a simple movement state label
            local state = ""
            if UnitOnTaxi("player") then
                state = " (Taxi)"
            elseif IsFlying() then
                state = " (Flying)"
            elseif IsSwimming() then
                state = " (Swimming)"
            elseif IsMounted() then
                state = " (Mounted)"
            end

            -- Get FPS counter - try multiple WoW API methods
            local fps = 0
            -- Try different possible FPS functions
            if GetFramerate then
                fps = GetFramerate()
            elseif C_System and C_System.GetFrameRate then
                fps = C_System.GetFrameRate()
            end
            
            -- If still no FPS, calculate approximate from elapsed time
            if not fps or fps <= 0 then
                -- Use a running average for smoother FPS calculation
                if not self._fpsHistory then
                    self._fpsHistory = {}
                end
                
                local currentFPS = elapsed > 0 and (1 / elapsed) or 60
                table.insert(self._fpsHistory, currentFPS)
                
                -- Keep only last 10 samples
                if #self._fpsHistory > 10 then
                    table.remove(self._fpsHistory, 1)
                end
                
                -- Calculate average
                local sum = 0
                for i = 1, #self._fpsHistory do
                    sum = sum + self._fpsHistory[i]
                end
                fps = sum / #self._fpsHistory
            end
            
            -- Build display string based on enabled features
            local showFPS = parentModule and parentModule:GetConfig("playground", "showFPS")
            local showSpeed = parentModule and parentModule:GetConfig("playground", "showSpeedometer")
            
            local displayParts = {}
            
            -- Add FPS first if enabled
            if showFPS and fps and fps > 0 then
                table.insert(displayParts, string.format("%.0f FPS", fps))
            end
            
            -- Add speed percentage and state if enabled  
            if showSpeed then
                table.insert(displayParts, string.format("%.0f%%%s", percent, state))
            end
            
            -- Create final display
            local display = ""
            if #displayParts > 0 then
                display = table.concat(displayParts, " | ")
            else
                -- Show something if both are enabled but data is missing
                if showFPS then
                    display = "FPS"
                elseif showSpeed then
                    display = "0%"
                end
            end
            
            -- Always update text if we have a display
            if display and display ~= "" then
                self.text:SetText(display)
            end
        else
            -- Get current speed for fade logic even when not updating display
            speed = GetPlayerSpeedYPS() or 0
        end
        
        -- Handle fade out when not moving (update every frame for smooth fading)
        if speed > 0.01 then
            -- Player is moving, reset fade timer and make visible
            self._fadeTimer = 0
            self:SetAlpha(1.0)
        else
            -- Player is not moving, start fade timer
            self._fadeTimer = self._fadeTimer + elapsed
            if self._fadeTimer > 2.0 then
                -- Start fading after 2 seconds of no movement
                local fadeTime = self._fadeTimer - 2.0
                local alpha = math.max(0.1, 1.0 - (fadeTime / 3.0)) -- Fade over 3 seconds to minimum 10% alpha
                self:SetAlpha(alpha)
            end
        end
    end)

    -- Initially show the frame - visibility will be controlled by toggle functions
    f:Show()

    speedometerFrame = f
    
    -- Set initial visibility based on config
    self:UpdateSpeedometerVisibility()
end

function Playground:UpdateSpeedometerVisibility()
    if not speedometerFrame then
        return
    end
    
    -- Check if either FPS or speedometer should be shown
    local showFPS = self.parent:GetConfig("playground", "showFPS")
    local showSpeed = self.parent:GetConfig("playground", "showSpeedometer") 
    
    if showFPS or showSpeed then
        speedometerFrame:Show()
    else
        speedometerFrame:Hide()
    end
end

function Playground:ToggleSpeedometer(enabled)
    if not speedometerFrame then
        -- Create the frame so it exists
        self:CreateSpeedometer()
    end
    
    self:UpdateSpeedometerVisibility()
end

function Playground:ToggleFPS(enabled)
    if not speedometerFrame then
        -- Create the frame so it exists
        self:CreateSpeedometer()
    end
    
    self:UpdateSpeedometerVisibility()
end

-- Set the position of the stats frame based on configuration
function Playground:SetStatsPosition(frame)
    if not frame then
        return
    end
    
    frame:ClearAllPoints()
    
    local position = self.parent:GetConfig("playground", "statsPosition") or "BOTTOMLEFT"
    local offset = 8 -- Offset from screen edge
    
    if position == "TOPLEFT" then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", offset, -offset)
        -- Left align text and position it on the left side of the frame
        if frame.text then
            frame.text:ClearAllPoints()
            frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
            frame.text:SetJustifyH("LEFT")
        end
    elseif position == "TOPRIGHT" then
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -offset, -offset)
        -- Right align text and position it on the right side of the frame
        if frame.text then
            frame.text:ClearAllPoints()
            frame.text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            frame.text:SetJustifyH("RIGHT")
        end
    elseif position == "BOTTOMRIGHT" then
        frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -offset, offset)
        -- Right align text and position it on the right side of the frame
        if frame.text then
            frame.text:ClearAllPoints()
            frame.text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
            frame.text:SetJustifyH("RIGHT")
        end
    else -- Default to BOTTOMLEFT
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", offset, offset)
        -- Left align text and position it on the left side of the frame
        if frame.text then
            frame.text:ClearAllPoints()
            frame.text:SetPoint("LEFT", frame, "LEFT", 0, 0)
            frame.text:SetJustifyH("LEFT")
        end
    end
end

-- Update the position of existing stats frame
function Playground:UpdateStatsPosition()
    if speedometerFrame then
        self:SetStatsPosition(speedometerFrame)
    end
end

-- Special Gamemode Integration
function Playground:InitializeSpecialGamemode()
    -- Enable special gamemode if the option is enabled
    local gamemodeAllowed = self.parent:GetConfig("playground", "allowSpecialGamemode", true)
    self:ToggleSpecialGamemode(gamemodeAllowed)
end

function Playground:ToggleSpecialGamemode(enabled)
    -- Get reference to the special gamemode module
    local specialGamemode = self.parent.modules and self.parent.modules.specialGamemode
    
    if specialGamemode and specialGamemode.ToggleGamemodeAllowed then
        specialGamemode:ToggleGamemodeAllowed(enabled)
    end
    
    -- Store the setting
    self.parent:SetConfig(enabled, "playground", "allowSpecialGamemode")
end

-- Mount Copy Feature
-- Gets the mount spell ID that the target unit is currently using
function Playground:GetTargetMountSpellID()
    if not UnitExists("target") then
        return nil
    end
    
    -- Use UnitAura to check all buffs on the target
    local i = 1
    while true do
        local auraData = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex("target", i, "HELPFUL")
        if auraData and auraData.spellId then
            if C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mountID = C_MountJournal.GetMountFromSpell(auraData.spellId)
                if mountID then return auraData.spellId, mountID end
            end
        else
            -- Fallback to older UnitAura signature where the 10th return is the spellId in many clients
            local name, _, _, _, _, _, _, _, _, spellId = UnitAura("target", i, "HELPFUL")
            if not name then break end
            if spellId and C_MountJournal and C_MountJournal.GetMountFromSpell then
                local mountID = C_MountJournal.GetMountFromSpell(spellId)
                if mountID then return spellId, mountID end
            end
        end
        
        i = i + 1
        if i > 40 then break end -- Safety limit
    end
    
    return nil
end

-- Checks if the player knows a specific mount
function Playground:PlayerKnowsMount(mountID)
    if not mountID or not C_MountJournal then
        return false
    end
    
    -- Query mount info; the returned tuple varies across clients, but isCollected is typically the last boolean
    local info = {C_MountJournal.GetMountInfoByID(mountID)}
    local isCollected = info[11] or info[10] or false
    return isCollected == true
end

-- Gets the spell name for a mount
function Playground:GetMountSpellName(spellID)
    if not spellID then
        return nil
    end
    
    -- Use modern API if available, fallback to old API
    -- Use modern C_Spell API (introduced 11.0.0)
    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        return spellInfo and spellInfo.name
    elseif C_Spell and C_Spell.GetSpellName then
        -- Fallback for older API
        return C_Spell.GetSpellName(spellID)
    end
    
    return nil
end

-- Tries to copy the target's mount, prints messages about the attempt
function Playground:TryCopyTargetMount()
    -- Check if feature is enabled
    if not self.parent:GetConfig("playground", "copyTargetMount") then
        return false
    end
    
    -- Can't mount in combat
    if InCombatLockdown() then
        self.parent:Print("Cannot copy mount while in combat!")
        return false
    end
    
    -- Check for target
    if not UnitExists("target") then
        self.parent:Print("No target selected!")
        return false
    end
    
    -- Get target's mount
    local spellID, mountID = self:GetTargetMountSpellID()
    
    if not spellID or not mountID then
        -- Target doesn't have a mount or we couldn't detect it
        self.parent:Print("Target is not on a mount!")
        return false
    end
    
    -- Check if player knows this mount
    if not self:PlayerKnowsMount(mountID) then
        -- Player doesn't have this mount
        local mountName = self:GetMountSpellName(spellID) or "Unknown Mount"
        self.parent:Print("You don't have " .. mountName .. "!")
        return false
    end
    
    -- Get the mount name for the message
    local mountName = self:GetMountSpellName(spellID) or "Unknown Mount"
    
    -- If player is already mounted, dismount first (use available API)
    if IsMounted() then
        if C_MountJournal and C_MountJournal.Dismiss then
            C_MountJournal.Dismiss()
        elseif Dismount then
            Dismount()
        end
    end

    -- Summon the mount using the mount ID if supported
    if C_MountJournal and C_MountJournal.SummonByID then
        C_MountJournal.SummonByID(mountID)
        self.parent:Print("Summoning " .. mountName .. " (copying target)")
        return true
    else
        -- No modern API available to summon by ID on this client
        self.parent:Print("Cannot summon mount on this client (missing API).")
        return false
    end
end

-- Create a slash command for manual mount copying
function Playground:RegisterCopyMountCommand()
    SLASH_BOLTCOPYMOUNT1 = "/copymount"
    SLASH_BOLTCOPYMOUNT2 = "/cm"
    
    SlashCmdList["BOLTCOPYMOUNT"] = function(msg)
        if not self.parent:IsModuleEnabled("playground") then
            self.parent:Print("Playground module is not enabled!")
            return
        end
        
        if not self.parent:GetConfig("playground", "copyTargetMount") then
            self.parent:Print("Copy Target Mount feature is not enabled! Enable it in Interface > AddOns > B.O.L.T")
            return
        end
        
        self:TryCopyTargetMount()
    end
end

-- Register the module
BOLT:RegisterModule("playground", Playground)

-- Global function for keybinding
function BOLT_CopyTargetMount()
    if not BOLT or not BOLT.modules or not BOLT.modules.playground then
        return
    end
    
    local playground = BOLT.modules.playground
    
    -- Check if module is enabled
    if not playground.parent:IsModuleEnabled("playground") then
        return
    end
    
    -- Check if feature is enabled
    if not playground.parent:GetConfig("playground", "copyTargetMount") then
        return
    end
    
    -- Try to copy the target's mount
    playground:TryCopyTargetMount()
end
