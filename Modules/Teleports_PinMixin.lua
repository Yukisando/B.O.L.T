-- B.O.L.T Teleports Pin Mixin
-- SECURE PINS - Direct click to teleport (like OPie's radial menu)
-- Pins ARE secure buttons that can cast spells/use items directly

local ADDON_NAME, BOLT = ...

local DEFAULT_ICON = "Interface\\Icons\\Spell_Arcane_TeleportDalaran"

---@class BOLTTeleportPinMixin : MapCanvasPinMixin
BOLTTeleportPinMixin = CreateFromMixins(MapCanvasPinMixin)

function BOLTTeleportPinMixin:OnLoad()
    self:SetScalingLimits(1, 1.0, 1.2)
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    
    -- Register for clicks (secure action handling)
    self:RegisterForClicks("AnyUp", "AnyDown")
end

-- Configure secure attributes for the entry (like OPie does)
function BOLTTeleportPinMixin:SetupSecureAction(entry)
    if InCombatLockdown() then return end
    if not entry then return end
    
    -- Clear previous attributes
    self:SetAttribute("type", nil)
    self:SetAttribute("spell", nil)
    self:SetAttribute("item", nil)
    self:SetAttribute("toy", nil)
    self:SetAttribute("macrotext", nil)
    
    -- Set action based on entry type
    if entry.type == "spell" and entry.id then
        self:SetAttribute("type", "spell")
        self:SetAttribute("spell", entry.id)
    elseif entry.type == "item" and entry.id then
        self:SetAttribute("type", "item")
        self:SetAttribute("item", "item:" .. entry.id)
    elseif entry.type == "toy" and entry.id then
        -- Toys use the toy attribute or item
        self:SetAttribute("type", "toy")
        self:SetAttribute("toy", entry.id)
    end
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
    
    -- Set up secure action attributes (direct click to teleport)
    self:SetupSecureAction(entry)
    
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
    
    -- Clear secure attributes when released (if not in combat)
    if not InCombatLockdown() then
        self:SetAttribute("type", nil)
        self:SetAttribute("spell", nil)
        self:SetAttribute("item", nil)
        self:SetAttribute("toy", nil)
        self:SetAttribute("macrotext", nil)
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
        -- Try to show toy tooltip
        if C_ToyBox and C_ToyBox.GetToyInfo then
            local itemID, toyName = C_ToyBox.GetToyInfo(self.entry.id)
            if itemID then
                GameTooltip:SetToyByItemID(itemID)
            else
                GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
            end
        else
            GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
        end
    else
        GameTooltip:AddLine(self.entry.name or "Teleport", 1, 1, 1, true)
        if self.entry.desc then
            GameTooltip:AddLine(self.entry.desc, 0.8, 0.8, 0.8, true)
        end
    end
    
    -- Show click hint
    GameTooltip:AddLine(" ", 1, 1, 1)
    GameTooltip:AddLine("|cff00ff00Left-click|r to teleport", 0.7, 0.7, 0.7)
    
    -- Show edit mode hint if enabled
    local cfg = BOLT:GetConfig("teleports") or {}
    if cfg.editMode and self.entry.isUserAdded then
        GameTooltip:AddLine("|cffff6600Right-click|r to delete", 0.7, 0.7, 0.7)
    end
    
    -- Show combat warning if in combat
    if InCombatLockdown() then
        GameTooltip:AddLine("|cffff0000Cannot teleport in combat|r", 1, 0.3, 0.3)
    end
    
    GameTooltip:Show()
end

function BOLTTeleportPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

-- Handle clicks - left click triggers secure action, right click for edit mode
function BOLTTeleportPinMixin:OnClick(button, down)
    if not self.entry then return end
    
    -- Right-click to delete (only if edit mode is enabled and not in combat)
    if button == "RightButton" and not down then
        local cfg = BOLT:GetConfig("teleports") or {}
        if cfg.editMode and self.entry.isUserAdded and not InCombatLockdown() then
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
    end
    -- Left-click is handled automatically by secure action template
end

return BOLTTeleportPinMixin
