-- B.O.L.T Max Camera Distance Module
-- Sets the camera's max zoom-out (cameraDistanceMaxZoomFactor) to the highest value the client
-- accepts: 4 on Classic-style clients, 2.6 on the modern one. Turning the module off puts the
-- game's default back.
-- DynamicCam sets this CVar itself, so with DynamicCam loaded B.O.L.T leaves it alone.

local ADDON_NAME, BOLT = ...

local CameraZoom = {
    displayName = "Max Camera Distance",
}

local CVAR = "cameraDistanceMaxZoomFactor"

local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
local Set = (C_CVar and C_CVar.SetCVar) or SetCVar

function CameraZoom:IsSupported()
    return Get(CVAR) ~= nil
end

function CameraZoom:OnEnable()
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if loaded and loaded("DynamicCam") then
        BOLT:Print("Max Camera Distance: DynamicCam controls the camera distance (its 'Maximum Camera Distance' setting); B.O.L.T leaves it alone.")
        return
    end
    Set(CVAR, "4")
    if (tonumber(Get(CVAR)) or 0) < 3.9 then Set(CVAR, "2.6") end -- the modern client's cap
end

function CameraZoom:OnDisable()
    local default = C_CVar and C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(CVAR)
    if default then Set(CVAR, default) end
end

BOLT:RegisterModule("cameraZoom", CameraZoom)
