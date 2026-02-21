-- B.O.L.T Teleport Data
-- All teleport pin locations shipped with the addon.
-- Add entries here so they are version-controlled and included when you push.
--
-- Use "/bolt export-teleports" in-game to dump runtime-added teleports as
-- copy-pasteable Lua you can paste into this table.
--
-- Entry format:
--   { name = "Display Name", mapID = <uiMapID>, x = 0.0-1.0, y = 0.0-1.0,
--     icon = <texture path or fileID>, type = "spell"|"item"|"toy", id = <spellID|itemID> }

local ADDON_NAME, BOLT = ...

BOLT.TeleportData = {
    -- Example (uncomment and modify):
    -- { name = "Portal to Orgrimmar", mapID = 84, x = 0.49, y = 0.87, icon = "Interface\\Icons\\Spell_Arcane_PortalOrgrimmar", type = "spell", id = 11417 },
}
