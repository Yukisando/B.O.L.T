-- BOLT DoT tracking: what your DoTs still have to deal on each mob, for the nameplate DoT overlay
-- (Modules/NameplatesEnhancement.lua, which sets ns.refresh and ns.enabled). WoW: Forever only.
-- Loaded first: Languages.lua and the Language_*.lua files add the spell description readers, DotTracking.lua the
-- tracking itself.

local _, BOLT = ...

BOLT.DotTracking = {
    enabled = false,           -- the tracking only runs while the overlay is on
    refresh = function() end,  -- called when the numbers may have moved
}
