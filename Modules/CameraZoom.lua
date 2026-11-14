-- B.O.L.T Max Camera Distance Module
-- Sets the camera's max zoom-out (cameraDistanceMaxZoomFactor) to the highest value the client
-- accepts, once per login or /reload, and leaves it alone after that.
--
-- Why the delay: the CVar is stored on Blizzard's servers (GetCVarInfo reports it as an
-- account-wide server CVar on WoW: Forever), and the server's copy lands while the world loads,
-- overwriting anything set earlier. So the value is set a few seconds after BOLT starts.
-- Why several values: the cap isn't documented for WoW: Forever. Classic takes 4.0, the modern
-- client 2.6, and an out-of-range value can be refused. The highest value that reads back as
-- set is kept.
-- Turning the module off puts the CVar back to the game's default.

local ADDON_NAME, BOLT = ...

local CameraZoom = {
    displayName = "Max Camera Distance",
}

local CVAR = "cameraDistanceMaxZoomFactor"
local CANDIDATES = { "4", "3.4", "2.6", "2" }
local DELAY = 3 -- seconds after BOLT starts, once the server's copy has landed

local Get = (C_CVar and C_CVar.GetCVar) or GetCVar
local Set = (C_CVar and C_CVar.SetCVar) or SetCVar

local function Current()
    return tonumber(Get(CVAR)) or 0
end

function CameraZoom:IsSupported()
    return Get(CVAR) ~= nil
end

function CameraZoom:Apply()
    if not self.active then return end
    for _, value in ipairs(CANDIDATES) do
        Set(CVAR, value)
        if math.abs(Current() - tonumber(value)) < 0.01 then return end
    end
    BOLT:Print(("Max Camera Distance: the game refused every value; the camera distance stays at %s."):format(tostring(Get(CVAR))))
end

-- BOLT starts its modules once the player is logged in (Core.lua TryStart), so this runs once
-- per login or /reload (or when the module is turned on). The delay lets the server's copy land.
function CameraZoom:OnEnable()
    C_Timer.After(DELAY, function() CameraZoom:Apply() end)
end

function CameraZoom:OnDisable()
    local default = C_CVar and C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(CVAR)
    if default then Set(CVAR, default) end
end

BOLT:RegisterModule("cameraZoom", CameraZoom)
