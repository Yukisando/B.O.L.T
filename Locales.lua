-- B.O.L.T Localization
-- Key binding display names (read from globals by the Key Bindings UI).

local strings = {
    BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Toggle Master Volume",
    BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copy Target Mount",
    BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Wowhead Link",
    BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Toggle TRP3 IC/OOC Status",
}

local translations = {
    frFR = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Basculer le volume principal",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copier la monture de la cible",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Lien Wowhead",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Basculer le statut TRP3 (RP/HRP)",
    },
    deDE = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Hauptlautstärke umschalten",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Reittier des Ziels kopieren",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Wowhead-Link",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "TRP3-Status umschalten (IC/OOC)",
    },
    esES = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Alternar volumen maestro",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copiar montura del objetivo",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Enlace de Wowhead",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Alternar estado de TRP3 (IC/OOC)",
    },
}
translations.esMX = translations.esES

local locale = translations[GetLocale()]
for key, value in pairs(strings) do
    _G[key] = locale and locale[key] or value
end
