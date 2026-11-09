-- B.O.L.T Localization
-- Key binding display names (read from globals by the Key Bindings UI).

local strings = {
    BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Toggle Master Volume",
    BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copy Target Mount",
    BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Wowhead Link",
    BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Toggle TRP3 IC/OOC Status",
    ["BINDING_NAME_CLICK BOLTWandShootButton:LeftButton"] = "Shoot Wand",
    BINDING_NAME_BOLT_EMOTE_HELLO = "Emote: Hello",
    BINDING_NAME_BOLT_EMOTE_BYE = "Emote: Goodbye",
    BINDING_NAME_BOLT_EMOTE_THANKS = "Emote: Thanks",
    BINDING_NAME_BOLT_EMOTE_SIT = "Emote: Sit",
}

local translations = {
    frFR = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Basculer le volume principal",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copier la monture de la cible",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Lien Wowhead",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Basculer le statut TRP3 (RP/HRP)",
        ["BINDING_NAME_CLICK BOLTWandShootButton:LeftButton"] = "Tirer avec la baguette",
        BINDING_NAME_BOLT_EMOTE_HELLO = "Emote : Bonjour",
        BINDING_NAME_BOLT_EMOTE_BYE = "Emote : Au revoir",
        BINDING_NAME_BOLT_EMOTE_THANKS = "Emote : Merci",
        BINDING_NAME_BOLT_EMOTE_SIT = "Emote : S'asseoir",
    },
    deDE = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Hauptlautstärke umschalten",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Reittier des Ziels kopieren",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Wowhead-Link",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "TRP3-Status umschalten (IC/OOC)",
        ["BINDING_NAME_CLICK BOLTWandShootButton:LeftButton"] = "Mit Zauberstab schießen",
        BINDING_NAME_BOLT_EMOTE_HELLO = "Emote: Hallo",
        BINDING_NAME_BOLT_EMOTE_BYE = "Emote: Tschüss",
        BINDING_NAME_BOLT_EMOTE_THANKS = "Emote: Danke",
        BINDING_NAME_BOLT_EMOTE_SIT = "Emote: Hinsetzen",
    },
    esES = {
        BINDING_NAME_BOLT_TOGGLE_MASTER_VOLUME = "Alternar volumen maestro",
        BINDING_NAME_BOLT_COPY_TARGET_MOUNT = "Copiar montura del objetivo",
        BINDING_NAME_BOLT_SHOW_WOWHEAD_LINK = "Enlace de Wowhead",
        BINDING_NAME_BOLT_TOGGLE_TRP3_STATUS = "Alternar estado de TRP3 (IC/OOC)",
        ["BINDING_NAME_CLICK BOLTWandShootButton:LeftButton"] = "Disparar varita",
        BINDING_NAME_BOLT_EMOTE_HELLO = "Emote: Hola",
        BINDING_NAME_BOLT_EMOTE_BYE = "Emote: Adiós",
        BINDING_NAME_BOLT_EMOTE_THANKS = "Emote: Gracias",
        BINDING_NAME_BOLT_EMOTE_SIT = "Emote: Sentarse",
    },
}
translations.esMX = translations.esES

local locale = translations[GetLocale()]
for key, value in pairs(strings) do
    _G[key] = locale and locale[key] or value
end
