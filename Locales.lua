-- B.O.L.T Localization
-- Keybinding display names

local L = {}

-- English (default)
L["BINDING_HEADER_BOLT"] = "B.O.L.T"
L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Toggle Master Volume"
L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copy Target Mount"

-- Register localization
if GetLocale() == "enUS" or GetLocale() == "enGB" then
    -- Already set above
elseif GetLocale() == "frFR" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Basculer le volume principal"
    L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copier la monture de la cible"
elseif GetLocale() == "deDE" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Hauptlautstärke umschalten"
    L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Reittier des Ziels kopieren"
elseif GetLocale() == "esES" or GetLocale() == "esMX" then
    L["BINDING_HEADER_BOLT"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Alternar volumen maestro"
    L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copiar montura del objetivo"
end

-- Apply localization to global scope
for k, v in pairs(L) do
    _G[k] = v
end
