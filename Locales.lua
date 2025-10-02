-- B.O.L.T Localization
-- Keybinding display names

local L = {}

-- English (default)
L["BINDING_HEADER_BOLT"] = "B.O.L.T"
L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Toggle Master Volume"

-- Register localization
if GetLocale() == "enUS" or GetLocale() == "enGB" then
    -- Already set above
elseif GetLocale() == "frFR" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Basculer le volume principal"
elseif GetLocale() == "deDE" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Hauptlautstärke umschalten"
elseif GetLocale() == "esES" or GetLocale() == "esMX" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Alternar volumen maestro"
end

-- Apply localization to global scope
for k, v in pairs(L) do
    _G[k] = v
end
