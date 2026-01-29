-- B.O.L.T Localization
-- Keybinding display names

local L = {}

-- English (default)
L["BINDING_HEADER_B_O_L_T"] = "B.O.L.T"
L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Toggle Master Volume"
L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copy Target Mount"
L["BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK"] = "Wowhead link"
L["BINDING_NAME_BOLT_ADD_TELEPORT"] = "Add Teleport Location"


-- Register localization
if GetLocale() == "enUS" or GetLocale() == "enGB" then
    -- Already set above
elseif GetLocale() == "frFR" then
    L["BINDING_HEADER_B_O_L_T"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Basculer le volume principal"
    L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copier la monture de la cible"
    L["BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK"] = "Wowhead link"
    L["BINDING_NAME_BOLT_ADD_TELEPORT"] = "Ajouter un lieu de téléportation"
elseif GetLocale() == "deDE" then
    L["BINDING_HEADER_B_O_L_T"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Hauptlautstärke umschalten"
    L["BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK"] = "Wowhead link"
    L["BINDING_NAME_BOLT_ADD_TELEPORT"] = "Teleport-Ort hinzufügen"
elseif GetLocale() == "esES" or GetLocale() == "esMX" then
    L["BINDING_HEADER_B_O_L_T"] = "B.O.L.T"
    L["BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME"] = "Alternar volumen maestro"
    L["BINDING_NAME_BOLT_COPY_TARGET_MOUNT"] = "Copiar montura del objetivo"
    L["BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK"] = "Wowhead link"
    L["BINDING_NAME_BOLT_ADD_TELEPORT"] = "Añadir ubicación de teletransporte"
end

-- Apply localization to global scope
for k, v in pairs(L) do
    _G[k] = v
end
