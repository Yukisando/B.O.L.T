-- B.O.L.T Teleports Pin Mixin
-- DISPLAY ONLY - No secure logic, no teleport execution
-- Pins show icons, tooltips, and open the teleport popup on click

local ADDON_NAME, BOLT = ...

local DEFAULT_ICON = "Interface\\Icons\\Spell_Arcane_TeleportDalaran"

---@class BOLTTeleportPinMixin : MapCanvasPinMixin
BOLTTeleportPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BOLTTeleportPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
end

-- Called by MapCanvas when pin is acquired via AcquirePin(template, entry, x, y)
function BOLTTeleportPinMixin:OnAcquired(entry, x, y)
    self.entry = entry
    
    -- Create the icon texture if it doesn't exist
    if not self.Icon then
        self.Icon = self:CreateTexture(nil, "ARTWORK")
        self.Icon:SetSize(24, 24)
        self.Icon:SetPoint("CENTER", self, "CENTER", 0, 0)
        self.Icon:SetDrawLayer("ARTWORK", 7)
    end
    
    -- Set up the icon
    if self.Icon and entry then
        local icon = entry.icon or DEFAULT_ICON
        self.Icon:SetTexture(icon)
        self.Icon:Show()
        self.Icon:SetVertexColor(1, 1, 1, 1)
    end
    
    -- Ensure the pin itself is visible and interactive
    self:SetSize(24, 24)
    self:Show()
    self:EnableMouse(true)
    self:SetAlpha(1.0)
    
    -- Set position via MapCanvasPinMixin
    if x and y then
        self:SetPosition(x, y)
    end
end

function BOLTTeleportPinMixin:OnReleased()
    self.entry = nil
    if self.Icon then
        self.Icon:Hide()
    end
end

function BOLTTeleportPinMixin:OnMouseEnter()
    if not self.entry then return end
    
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    
    if self.entry.type == "item" and self.entry.id then
        if GameTooltip.SetItemByID then
            GameTooltip:SetItemByID(self.entry.id)
        else
            GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
            if self.entry.desc then
                GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
            end
        end
    elseif self.entry.type == "spell" and self.entry.id then
        if GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(self.entry.id)
        else
            GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
            if self.entry.desc then
                GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
            end
        end
    elseif self.entry.type == "toy" and self.entry.id then
        GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
        if self.entry.desc then
            GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
        end
    else
        GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
        if self.entry.desc then
            GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
        end
    end
    
    -- Show edit mode hint if enabled
    local cfg = BOLT:GetConfig("teleports") or {}
    if cfg.editMode and self.entry.isUserAdded then
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("Right-click to delete", 0.7, 0.7, 0.7)
    end
    
    GameTooltip:Show()
end

function BOLTTeleportPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- DISPLAY ONLY: Opens the teleport popup - does NOT execute teleport
function BOLTTeleportPinMixin:OnMouseDown(button)
    if not self.entry then return end
    
    if button == "RightButton" then
        -- Right-click to delete (only if edit mode is enabled)
        local cfg = BOLT:GetConfig("teleports") or {}
        if cfg.editMode and self.entry.isUserAdded then
            local teleportsModule = BOLT.modules and BOLT.modules.teleports
            if teleportsModule then
                local combined = teleportsModule:GetTeleportList()
                for i, entry in ipairs(combined) do
                    if entry == self.entry then
                        teleportsModule:DeleteTeleport(i)
                        return
                    end
                end
            end
        end
    elseif button == "LeftButton" then
        -- Left-click opens the teleport popup (secure button handles the actual teleport)
        local teleportsModule = BOLT.modules and BOLT.modules.teleports
        if teleportsModule and teleportsModule.OpenTeleportPopup then
            teleportsModule:OpenTeleportPopup(self.entry)
        end
    end
end

return BOLTTeleportPinMixin
