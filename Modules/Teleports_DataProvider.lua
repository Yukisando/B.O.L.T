-- B.O.L.T Teleports Data Provider
-- Manages MapCanvas pin lifecycle following 12.0 rules
-- Extends MapCanvasDataProviderMixin with proper refresh cycle

local ADDON_NAME, BOLT = ...

---@class BOLTTeleportDataProviderMixin : MapCanvasDataProviderMixin
BOLTTeleportDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin)

-- Called when data provider is added to map canvas
function BOLTTeleportDataProviderMixin:OnAdded(mapCanvas)
    MapCanvasDataProviderMixin.OnAdded(self, mapCanvas)
    self:RefreshAllData()
end

-- Called when data provider is removed from map canvas
function BOLTTeleportDataProviderMixin:OnRemoved(mapCanvas)
    self:RemoveAllData()
    MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas)
end

-- Called when the map changes (zoom, pan, different map)
function BOLTTeleportDataProviderMixin:OnMapChanged()
    self:RefreshAllData()
end

-- Remove all pins created by this provider
function BOLTTeleportDataProviderMixin:RemoveAllData()
    local map = self:GetMap()
    if map then
        map:RemoveAllPinsByTemplate("BOLTTeleportPinTemplate")
    end
end

-- Refresh all pins - the core refresh cycle
function BOLTTeleportDataProviderMixin:RefreshAllData()
    local map = self:GetMap()
    if not map then return end
    
    -- Always remove existing pins first (required for proper refresh)
    self:RemoveAllData()
    
    -- Get teleports module reference
    local teleportsModule = BOLT.modules and BOLT.modules.teleports
    if not teleportsModule then return end
    
    -- Check if module is enabled
    if not BOLT:IsModuleEnabled("teleports") then return end
    
    -- Get current map ID
    local currentMapID = map:GetMapID()
    if not currentMapID then return end
    
    -- Get teleport list
    local success, list = pcall(function()
        return teleportsModule:GetTeleportList()
    end)
    
    if not success or not list or type(list) ~= "table" then return end
    
    local pinCount = 0
    
    for _, entry in ipairs(list) do
        -- Project entry coordinates to current map
        local x, y, canProject = teleportsModule:ProjectToMap(entry, currentMapID)
        
        if canProject and x and y then
            -- CORRECT: AcquirePin with entry and coordinates as arguments
            -- The pin's OnAcquired(entry, x, y) will receive these
            local pin = map:AcquirePin("BOLTTeleportPinTemplate", entry, x, y)
            if pin then
                pinCount = pinCount + 1
            end
        end
    end
    
    -- Force the map canvas to process the new pins immediately
    -- This is similar to how TomTom/HereBeDragons triggers updates
    if map.TriggerEvent then
        map:TriggerEvent("DataProviderRefreshed", self)
    end
    
    -- Debug output
    if teleportsModule.Debug then
        teleportsModule:Debug(string.format("RefreshAllData: Placed %d pins on map %d from %d total teleports", 
            pinCount, currentMapID, #list))
    end
end

-- Create and return a new data provider instance
function BOLT:CreateTeleportDataProvider()
    local provider = CreateFromMixins(BOLTTeleportDataProviderMixin)
    return provider
end

return BOLTTeleportDataProviderMixin
