-- B.O.L.T Configuration UI
-- Settings pages are built from the declarative PAGES table below. Each section
-- belongs to a module; sections for modules missing on this client (e.g. WoW:
-- Forever) are skipped, and a disabled module's options collapse.

local ADDON_NAME, BOLT = ...

local Config = {
    displayName = "Settings",
    alwaysOn = true,
}

local ROW_HEIGHT = 30
local OPTION_X = 50
local SECTION_HEADER = 54

---------------------------------------------------------------------------
-- Setting helpers
---------------------------------------------------------------------------

local function GetSetting(path)
    return BOLT:GetConfig(unpack(path))
end

-- Writes a setting and lets the owning module react (module name = first path key). Shared with
-- the Edit Mode dialogs (BOLT:SetSetting), so both always show the same value.
local function SetSetting(path, value)
    BOLT:SetSetting(path, value)
end

local function Module(name)
    return BOLT.modules[name]
end

---------------------------------------------------------------------------
-- Page definitions
---------------------------------------------------------------------------

local MARKER_NAMES = { "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
local STATS_POSITIONS = {
    { value = "TOPLEFT", label = "Top Left" },
    { value = "TOPRIGHT", label = "Top Right" },
    { value = "BOTTOMLEFT", label = "Bottom Left" },
    { value = "BOTTOMRIGHT", label = "Bottom Right" },
}

local function LayoutOptions(settingKey)
    return function()
        local options = { { value = -1, label = "Disabled" } }
        local roleplay = Module("roleplay")
        for index, layout in ipairs(roleplay:GetCustomLayouts()) do
            table.insert(options, { value = index, label = layout.layoutName or ("Layout " .. index) })
        end
        return options
    end
end

-- A multi-select dropdown over a section's on/off settings: entries = { { key, label }, ... }.
local function ToggleList(section, label, allText, entries)
    return {
        type = "multiselect", label = label, width = 300, emptyText = allText,
        isSelected = function(key) return GetSetting({ section, key }) and true or false end,
        toggle = function(key, selected) SetSetting({ section, key }, selected) end,
        options = function()
            local list = {}
            for _, entry in ipairs(entries) do
                table.insert(list, { value = entry[1], label = entry[2] })
            end
            return list
        end,
    }
end

local BUTTON_SIDES = {
    { value = "TOP", label = "Top, under the title" },
    { value = "BOTTOM", label = "Bottom" },
    { value = "LEFT", label = "Left column" },
    { value = "RIGHT", label = "Right column" },
}

-- Opens Blizzard's Edit Mode from the settings page.
local function OpenEditMode()
    if InCombatLockdown() then
        BOLT:Print("Edit Mode can't open in combat.")
        return
    end
    -- :Hide() rather than HideUIPanel, as in GameMenu:OpenSettingsFromMenu (taint).
    if SettingsPanel and SettingsPanel:IsShown() then SettingsPanel:Hide() end
    if GameMenuFrame and GameMenuFrame:IsShown() then GameMenuFrame:Hide() end
    C_Timer.After(0.1, function()
        if EditModeManagerFrame and not InCombatLockdown() then ShowUIPanel(EditModeManagerFrame) end
    end)
end

local PAGES = {
    {
        -- Everything that changes how the game's UI looks.
        title = "Interface",
        sections = {
            {
                module = "unitFrames",
                title = "Unit Frames & Cast Bars",
                description = "Restyles the game UI with Blizzard's own art. Unit frames lose their round portrait: the frame stretches over its space and the bars widen. Cast bars show the spell name on the bar. Turning something off takes a /reload.",
                editMode = "select the Player, Target, Focus, Pet or Party frame or the Cast Bar and tick its Flat style option.",
                options = {
                    ToggleList("unitFrames", "Restyle:", "Everything", {
                        { "player", "Player" },
                        { "target", "Target and focus" },
                        { "targetOfTarget", "Target of target" },
                        { "pet", "Pet" },
                        { "party", "Party" },
                        { "castBars", "Cast bars" },
                    }),
                },
            },
            {
                module = "minimap",
                description = "A square minimap framed with Blizzard's own art. The zone name and clock sit in a title bar above it, and the minimap buttons (tracking, calendar, mail, expansion summary, instance difficulty, addon list and a drawer for addon buttons) in one bar. Coordinates sit inside the map. Turning it off takes a /reload.",
                editMode = "select the Minimap to pick where its buttons go and turn wheel zoom on or off.",
                options = {
                    { type = "dropdown", label = "Minimap buttons:", width = 170, path = { "minimap", "buttons" },
                        options = function() return BUTTON_SIDES end },
                    { type = "checkbox", label = "Zoom with the mouse wheel (hides the +/- buttons, zooms back out after 20 seconds)", path = { "minimap", "wheelZoom" } },
                },
            },
            {
                module = "frameVisibility",
                description = "Hide the Player and Target frames and pick when they come back. Pair a hidden Player Frame with Blizzard's Personal Resource Display (your health and power under your character), which B.O.L.T can also fade out of combat, make right-clickable and top with your pet's health.",
                editMode = "select the Player Frame, the Target Frame or the Personal Resource Display.",
            },
            {
                module = "tooltip",
                description = "Tooltips get a see-through black background instead of Blizzard's dark blue, and unit tooltips lose the health bar underneath.",
            },
            {
                module = "rangedTimer",
                description = (BOLT.isForever and "A bar that fills between your Auto Shots and wand shots" or "A bar that fills between your Auto Shots")
                    .. ", so you can fit casts and moves between them. It sits under the Personal Resource Display in the same style, or floats on its own when that display is off.",
                editMode = "select Ranged Attack Timer to attach it or let it float, move it and set its width.",
                options = {
                    { type = "checkbox", label = "Attach it under the Personal Resource Display when that display is on", path = { "rangedTimer", "attach" } },
                },
            },
            {
                module = "nameplatesEnhancement",
                description = "Small fixes on top of Blizzard's nameplates.",
                options = {
                    { type = "checkbox", label = "Color enemy mana users (healers and casters)", path = { "nameplatesEnhancement", "manaUsers" } },
                    { type = "color", label = "Color:", path = { "nameplatesEnhancement", "manaColor" }, indent = 24,
                        default = { r = 0.2, g = 0.4, b = 1.0 }, requires = { "nameplatesEnhancement", "manaUsers" } },
                    { type = "checkbox", label = "Only in instances (dungeons, raids, scenarios)", path = { "nameplatesEnhancement", "instanceOnly" },
                        indent = 24, requires = { "nameplatesEnhancement", "manaUsers" } },
                    { type = "checkbox", label = "Larger nameplate for your target, the others slightly faded", path = { "nameplatesEnhancement", "targetEmphasis" } },
                    { type = "checkbox", label = "Outline enemy casts you can interrupt right now (interruptible, and your interrupt is ready)", path = { "nameplatesEnhancement", "interruptCue" } },
                    { type = "color", label = "Color:", path = { "nameplatesEnhancement", "interruptColor" }, indent = 24,
                        default = { r = 0.3, g = 1.0, b = 0.45 }, requires = { "nameplatesEnhancement", "interruptCue" } },
                    { type = "checkbox", label = "Range dot on enemy nameplates: dark red when out of your reach (measured with your interrupt or a basic attack), yellow when too close to shoot (hunters), none when in reach", path = { "nameplatesEnhancement", "rangeHint" } },
                },
            },
            {
                module = "autoHide",
                description = "Hides parts of the UI until you need them. They fade in when you hover them, have a target or are in combat, and stay hidden while mounted or on a flight path unless you're in combat. Everything shows in Edit Mode; action bars also show while you drag a spell or item.",
                editMode = "select an action bar, the bags, micro menu, experience bar, buffs, debuffs, quest tracker, minimap, or the pet, focus or party frames, and tick Fade out until needed.",
                options = {
                    ToggleList("autoHide", "Hide:", "Everything", {
                        { "mainBar", "Main bar, micro menu and bags" },
                        { "actionBars", "Other action bars" },
                        { "xpBar", "Experience bar" },
                        { "buffs", "Buffs" },
                        { "debuffs", "Debuffs" },
                        { "unitFrames", "Unit frames" },
                        { "questTracker", "Quest tracker" },
                        { "minimap", "Minimap" },
                        { "minimapButtons", "Minimap buttons" },
                    }),
                    { type = "slider", label = "Opacity while hidden:", path = { "autoHide", "idleAlpha" },
                        min = 0, max = 100, step = 5, format = function(value) return ("%d%%"):format(value) end },
                },
            },
            {
                module = "partyFramesCenterGrowth",
                description = "Keeps raid-style party frames centered as members join or leave. Requires Raid-Style Party Frames in Edit Mode.",
            },
        },
    },
    {
        title = "Quality of Life",
        sections = {
            {
                module = "gameMenu",
                options = {
                    { type = "checkbox", label = "Show Leave Group button", path = { "gameMenu", "showLeaveGroup" } },
                    { type = "checkbox", label = "Show Reload UI button", path = { "gameMenu", "showReloadButton" } },
                    { type = "checkbox", label = BOLT.has.countdown and "Show group tools (ready check, countdown, raid marker)" or "Show group tools (ready check, raid marker)", path = { "gameMenu", "groupToolsEnabled" } },
                    { type = "markers", label = "Raid marker:", path = { "gameMenu", "raidMarkerIndex" }, requires = { "gameMenu", "groupToolsEnabled" } },
                    { type = "checkbox", label = "Show damage/healing number toggles", path = { "gameMenu", "showBattleTextToggles" } },
                    { type = "checkbox", label = "Show volume button", path = { "gameMenu", "showVolumeButton" } },
                    { type = "checkbox", label = "Show loot specialization button", path = { "gameMenu", "showLootSpecButton" },
                        available = function() return BOLT.has.specializations end },
                },
            },
            {
                module = "autoSell",
                description = "Sells every junk (grey) item and everything on your sell list when you open a merchant. Alt + right-click an item in your bags to add it to the sell list or take it off; listed items show a coin on their bag slot. The list is shared by all your characters.",
                options = {
                    { type = "button", label = "Clear Sell List", width = 140,
                        onClick = function() Module("autoSell"):ClearList() end },
                },
            },
            {
                module = "campfire",
                description = "When the Campfire Nearby buff is on you, a slim camp bar fades in beside the minimap: what to do now, a bar counting down the minute to Camp Benefits (then their time left), and a Sit button. Click the bar to open the camp benefits you got and your camp gear, each object with its own Place and Craft buttons. Right-click it to hide it until the next fire. It steps aside in combat, while mounted or swimming.",
                editMode = "select the Camp Bar to place it beside the minimap or anywhere, size it, and set auto-sit, the ready alert and the recipes list.",
                options = {
                    { type = "checkbox", label = "Sit down on your own when you stop where the fire warmed you (if you have no camp benefits yet, or just placed an object)", path = { "campfire", "autoSit" } },
                    { type = "checkbox", label = "Ready alert: a sound, a glow and a taskbar flash when Camp Benefits lands", path = { "campfire", "readyAlert" } },
                    { type = "checkbox", label = "Show the camp recipes you can craft", path = { "campfire", "showCraft" } },
                },
            },
            {
                module = "autoRepSwitch",
                description = "Switches the watched reputation bar to the faction you just gained reputation with.",
            },
            {
                module = "smartTeleport",
                description = "Shows teleports you own that fit the zone you're viewing, below the World Map.",
            },
            {
                module = "savedInstances",
                description = "Lists current-expansion dungeons and raids and your lockouts. /boltsaved or middle-click the game menu gear.",
            },
        },
    },
    {
        title = "Gameplay",
        sections = {
            {
                module = "wandShoot",
                description = "One key for your wand and your pet: it targets the enemy under the mouse (or keeps your current target), sends your pet to attack it and starts your wand's Shoot. Without a pet out it just shoots. Pressing it again doesn't stop the wand. Works in combat.",
                options = {
                    { type = "keybind", label = "Wand + pet attack:", binding = "CLICK BOLTWandShootButton:LeftButton" },
                },
            },
            {
                module = "doubleClickFishing",
                description = "Double right-click on the world to cast Fishing while a fishing rod is equipped. It stays out of the way in combat, while mounted, with a character under the mouse, with loot open, and while your line is already in the water.",
            },
            {
                module = "skyriding",
                description = "While skyriding, strafe keys turn instead (and forward/back can pitch). Use /bolt reset if keys ever feel stuck.",
                options = {
                    { type = "checkbox", label = "Pitch control (forward/back keys)", path = { "skyriding", "enablePitchControl" } },
                    { type = "checkbox", label = "Invert pitch", path = { "skyriding", "invertPitch" }, requires = { "skyriding", "enablePitchControl" } },
                    { type = "checkbox", label = "Only while holding the left mouse button", path = { "skyriding", "requireMouseButton" } },
                },
            },
        },
    },
    {
        title = "Social",
        sections = {
            {
                module = "chatNotifier",
                description = "Plays a sound when a new message arrives in the channels you pick.",
                options = {
                    { type = "dropdown", label = "Sound:", width = 170,
                        get = function() return Module("chatNotifier"):GetSoundID() end,
                        set = function(value)
                            Module("chatNotifier"):SetSoundID(value)
                            Module("chatNotifier"):PlayNotification()
                        end,
                        options = function()
                            local list = {}
                            for _, sound in ipairs(Module("chatNotifier").SOUND_OPTIONS) do
                                table.insert(list, { value = sound.soundID, label = sound.label })
                            end
                            return list
                        end },
                    { type = "button", label = "Preview", width = 70, sameRow = true,
                        onClick = function() Module("chatNotifier"):PlayNotification() end },
                    { type = "multiselect", label = "Channels:", width = 300,
                        isSelected = function(value) return Module("chatNotifier"):IsChannelEnabled(value) end,
                        toggle = function(value, selected) Module("chatNotifier"):SetChannelEnabled(value, selected) end,
                        options = function()
                            local list = {}
                            for _, channel in ipairs(Module("chatNotifier").CHANNEL_TYPES) do
                                table.insert(list, { value = channel.event, label = channel.label })
                            end
                            return list
                        end },
                },
            },
            {
                module = "autoPartyChat",
                description = "When you join a group, the chat box switches to Party (Raid in a raid, Instance in a dungeon finder group), and back to Say when you leave. It switches even from a whisper or a channel, since that is often how you asked for the invite. Leaving only puts Say back if the box was still on the group.",
            },
            {
                module = "wowheadLink",
                description = "Hover an item, spell, NPC, quest or achievement and press the keybind (Ctrl+C by default) to get its Wowhead link.",
            },
            {
                module = "keyShare",
                description = "When someone types \"!keys\" in party, raid or guild chat, links your Mythic+ keystone there.",
                options = {
                    { type = "checkbox", label = "Roulette: pick a random key from everyone's answers and announce it", path = { "keyShare", "rouletteEnabled" } },
                },
            },
        },
    },
    {
        title = "Tracking",
        sections = {
            {
                module = "achievementTracker",
                description = "Announces progress whenever something you do advances an achievement (e.g. /love a critter, finishing a quest).",
                options = {
                    { type = "multiselect", label = "Categories:", width = 300,
                        emptyText = "All categories",
                        isSelected = function(value) return Module("achievementTracker"):IsCategoryTracked(value) end,
                        toggle = function(value, selected) Module("achievementTracker"):SetCategoryTracked(value, selected) end,
                        options = function()
                            local list = {}
                            for _, category in ipairs(Module("achievementTracker"):GetTopLevelCategories()) do
                                table.insert(list, { value = category.id, label = category.name })
                            end
                            return list
                        end },
                    { type = "button", label = "Rescan", width = 80, sameRow = true,
                        onClick = function() Module("achievementTracker"):BuildSnapshot() end },
                },
            },
        },
    },
    {
        title = "Extras",
        sections = {
            {
                module = "playground",
                options = {
                    { type = "checkbox", label = "Favorite toy button", path = { "playground", "showFavoriteToy" },
                        available = function() return BOLT.has.toys end },
                    { type = "toy", sameRow = true, requires = { "playground", "showFavoriteToy" },
                        available = function() return BOLT.has.toys end },
                    { type = "checkbox", label = "Close the game menu when using the toy", path = { "playground", "closeGameMenuOnCast" }, requires = { "playground", "showFavoriteToy" },
                        available = function() return BOLT.has.toys end },
                    { type = "checkbox", label = "Speedometer", path = { "playground", "showSpeedometer" } },
                    { type = "checkbox", label = "FPS counter", path = { "playground", "showFPS" } },
                    { type = "dropdown", label = "Position:", width = 130, path = { "playground", "statsPosition" },
                        options = function() return STATS_POSITIONS end },
                    { type = "checkbox", label = "Copy target's mount (/cm or keybind)", path = { "playground", "copyTargetMount" },
                        available = function() return BOLT.has.mountJournal end },
                },
            },
            {
                module = "soundMuter",
                description = "Mute individual game sounds by their numeric sound file ID.",
                options = {
                    { type = "button", label = "Manage Sounds", width = 150,
                        onClick = function() Module("soundMuter"):ShowManagementPopup() end },
                },
            },
            {
                module = "characterSnapshot",
                description = "Export a JSON time capsule of this character (level, money, /played, collections, achievement points and the Statistics tab).",
                options = {
                    { type = "button", label = "Export Snapshot (JSON)", width = 180,
                        onClick = function() Module("characterSnapshot"):ShowExportPopup() end },
                },
            },
            {
                module = "admin",
                options = {
                    { type = "button", label = "Admin Settings", width = 140,
                        onClick = function() Module("admin"):ShowPasswordPopup() end },
                },
            },
        },
    },
    {
        title = "Roleplay",
        sections = {
            {
                module = "roleplay",
                title = "Total RP 3",
                description = "Requires Total RP 3. A keybind toggles your IC/OOC status and can apply the extras below.",
                options = {
                    { type = "keybind", label = "Toggle IC/OOC:", binding = "BOLT_TOGGLE_TRP3_STATUS" },
                    { type = "checkbox", label = "Show the TRP toolbar when In Character, hide it when Out of Character", path = { "roleplay", "toggleTrpToolbar" } },
                    { type = "dropdown", label = "Edit Mode layout when IC:", width = 160, path = { "roleplay", "editModeProfileIndex" },
                        options = LayoutOptions("editModeProfileIndex") },
                    { type = "dropdown", label = "Edit Mode layout when OOC:", width = 160, path = { "roleplay", "editModeOOCProfileIndex" },
                        options = LayoutOptions("editModeOOCProfileIndex") },
                },
            },
            {
                module = "roleplay",
                title = "Everyday emotes",
                description = "One key per emote, aimed at your target if you have one. Total RP 3 not needed.",
                options = {
                    { type = "keybind", label = "Hello:", binding = "BOLT_EMOTE_HELLO" },
                    { type = "keybind", label = "Goodbye:", binding = "BOLT_EMOTE_BYE" },
                    { type = "keybind", label = "Thanks:", binding = "BOLT_EMOTE_THANKS" },
                    { type = "checkbox", label = "Thank players who buff you (2 seconds later, out of combat, once a minute per player)", path = { "roleplay", "autoThankBuffs" } },
                    { type = "keybind", label = "Sit:", binding = "BOLT_EMOTE_SIT" },
                },
            },
            {
                module = "transmogPresets",
                description = "Save transmog looks account-wide and stage them on any character at a Transmogrifier (/bolt transmog).",
                options = {
                    { type = "button", label = "Manage Presets", width = 160,
                        onClick = function() Module("transmogPresets"):ShowUI() end },
                },
            },
        },
    },
}

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local Widgets = {}

local function AddLabel(parent, text, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetText(text)
    return label
end

local function SetWidgetEnabled(widget, enabled)
    if widget.SetEnabled then widget:SetEnabled(enabled) end
    widget:SetAlpha(enabled and 1 or 0.5)
end

function Widgets.checkbox(parent, option)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(26, 26)
    check.Text:SetFontObject("GameFontHighlight")
    check.Text:SetText(option.label)
    -- option.get/option.set bind it to something other than a saved setting (a CVar...).
    check:SetScript("OnClick", function(self)
        if option.set then
            option.set(self:GetChecked())
        else
            SetSetting(option.path, self:GetChecked())
        end
        Config:RefreshAll()
    end)
    check.Refresh = function(self)
        local value
        if option.get then value = option.get() else value = GetSetting(option.path) end
        self:SetChecked(value and true or false)
    end
    check.anchorRight = check.Text
    return check
end

-- A button that opens a menu; the shared shape for dropdowns and multi-selects.
local function MenuButton(parent, option, buildMenu, getText)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(1, 22)
    local label = AddLabel(holder, option.label)
    label:SetPoint("LEFT")
    -- A fixed label width lines a run of dropdowns up in a column.
    if option.labelWidth then
        label:SetWidth(option.labelWidth)
        label:SetJustifyH("LEFT")
    end

    local button = CreateFrame("DropdownButton", nil, holder, "WowStyle1DropdownTemplate")
    button:SetWidth(option.width or 160)
    button:SetPoint("LEFT", label, "RIGHT", 8, 0)
    button:SetupMenu(buildMenu)
    button:OverrideText(getText())
    holder:SetWidth((option.labelWidth or label:GetStringWidth()) + 8 + button:GetWidth())

    holder.SetEnabled = function(_, enabled) button:SetEnabled(enabled) end
    holder.Refresh = function() button:GenerateMenu() button:OverrideText(getText()) end
    holder.anchorRight = button
    return holder
end

-- Blizzard's own settings slider (with steppers and a value label on the right).
function Widgets.slider(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(1, 22)
    local label = AddLabel(holder, option.label)
    label:SetPoint("LEFT")

    local step = option.step or 1
    local slider = CreateFrame("Frame", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetWidth(option.width or 200)
    slider:SetPoint("LEFT", label, "RIGHT", 12, 0)
    local rightLabel = MinimalSliderWithSteppersMixin.Label.Right
    slider:Init(GetSetting(option.path) or option.min, option.min, option.max, (option.max - option.min) / step, {
        [rightLabel] = CreateMinimalSliderFormatter(rightLabel, option.format),
    })
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        value = math.floor(value / step + 0.5) * step
        if value ~= GetSetting(option.path) then
            SetSetting(option.path, value)
        end
    end, holder)
    holder:SetWidth(label:GetStringWidth() + 12 + slider:GetWidth() + 40)

    holder.SetEnabled = function(_, enabled) slider:SetEnabled(enabled) end
    holder.Refresh = function() slider:SetValue(GetSetting(option.path) or option.min) end
    holder.anchorRight = slider
    return holder
end

function Widgets.dropdown(parent, option)
    local get = option.get or function() return GetSetting(option.path) end
    local set = option.set or function(value) SetSetting(option.path, value) end
    local function Text()
        local current = get()
        for _, entry in ipairs(option.options()) do
            if entry.value == current then return entry.label end
        end
        return "—"
    end
    local holder
    holder = MenuButton(parent, option, function(_, root)
        for _, entry in ipairs(option.options()) do
            root:CreateRadio(entry.label,
                function() return get() == entry.value end,
                function()
                    set(entry.value)
                    holder.Refresh()
                end)
        end
    end, Text)
    return holder
end

function Widgets.multiselect(parent, option)
    local function Text()
        local selected, all = {}, true
        for _, entry in ipairs(option.options()) do
            if option.isSelected(entry.value) then
                table.insert(selected, entry.label)
            else
                all = false
            end
        end
        if all and option.emptyText then return option.emptyText end
        if #selected == 0 then return "None" end
        if #selected > 3 then
            return ("%s, %s + %d more"):format(selected[1], selected[2], #selected - 2)
        end
        return table.concat(selected, ", ")
    end
    local holder
    holder = MenuButton(parent, option, function(_, root)
        for _, entry in ipairs(option.options()) do
            root:CreateCheckbox(entry.label,
                function() return option.isSelected(entry.value) end,
                function()
                    option.toggle(entry.value, not option.isSelected(entry.value))
                    holder.Refresh()
                end)
        end
    end, Text)
    return holder
end

-- A small heading inside a section, above a group of options.
function Widgets.header(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(300, 22)
    local label = AddLabel(holder, option.label, "GameFontNormal")
    label:SetPoint("BOTTOMLEFT", 0, 2)
    return holder
end

function Widgets.button(parent, option)
    local button = BOLT:CreateButton(parent, option.label, option.width or 120, 22, option.onClick)
    button.anchorRight = button
    return button
end

function Widgets.color(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(200, 22)
    local label = AddLabel(holder, option.label)
    label:SetPoint("LEFT")

    local swatch = CreateFrame("Button", nil, holder, "BackdropTemplate")
    swatch:SetSize(20, 20)
    swatch:SetPoint("LEFT", label, "RIGHT", 8, 0)
    swatch:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8, insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local function Apply(r, g, b)
        SetSetting(option.path, { r = r, g = g, b = b })
        swatch:SetBackdropColor(r, g, b, 1)
    end

    swatch:SetScript("OnClick", function()
        local color = GetSetting(option.path)
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b,
            previousValues = { r = color.r, g = color.g, b = color.b },
            swatchFunc = function() Apply(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(previous) Apply(previous.r, previous.g, previous.b) end,
        })
    end)

    local reset = BOLT:CreateButton(holder, "Reset", 55, 20, function()
        Apply(option.default.r, option.default.g, option.default.b)
    end)
    reset:SetPoint("LEFT", swatch, "RIGHT", 6, 0)

    holder.SetEnabled = function(_, enabled)
        swatch:SetEnabled(enabled)
        reset:SetEnabled(enabled)
    end
    holder.Refresh = function()
        local color = GetSetting(option.path)
        swatch:SetBackdropColor(color.r, color.g, color.b, 1)
    end
    return holder
end

local function MarkerTexCoords(index)
    local i = index - 1
    local left, top = (i % 4) * 0.25, math.floor(i / 4) * 0.25
    return left, left + 0.25, top, top + 0.25
end

function Widgets.markers(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(320, 22)
    local label = AddLabel(holder, option.label)
    label:SetPoint("LEFT")

    local buttons = {}
    local previous = label
    for index = 1, 8 do
        local button = CreateFrame("Button", nil, holder)
        button:SetSize(22, 22)
        button:SetPoint("LEFT", previous, "RIGHT", index == 1 and 8 or 4, 0)
        button:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
        button:GetNormalTexture():SetTexCoord(MarkerTexCoords(index))
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        button:SetScript("OnClick", function()
            SetSetting(option.path, index)
            holder.Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(MARKER_NAMES[index])
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", GameTooltip_Hide)
        buttons[index] = button
        previous = button
    end

    holder.SetEnabled = function(_, enabled)
        for _, button in ipairs(buttons) do button:SetEnabled(enabled) end
    end
    holder.Refresh = function()
        local selected = GetSetting(option.path)
        for index, button in ipairs(buttons) do
            button:SetAlpha(index == selected and 1 or 0.4)
        end
    end
    return holder
end

function Widgets.keybind(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(260, 22)
    local label = AddLabel(holder, option.label)
    label:SetPoint("LEFT")

    local button = BOLT:CreateButton(holder, "", 130, 22)
    button:SetPoint("LEFT", label, "RIGHT", 8, 0)
    button:EnableKeyboard(false)

    local function Finish()
        button:EnableKeyboard(false)
        button:SetScript("OnKeyDown", nil)
        holder.Refresh()
    end

    button:SetScript("OnClick", function()
        button:SetText("Press a key...")
        button:EnableKeyboard(true)
        button:SetPropagateKeyboardInput(false)
        button:SetScript("OnKeyDown", function(_, key)
            if key == "ESCAPE" then Finish() return end
            if key:find("SHIFT$") or key:find("CTRL$") or key:find("ALT$") then return end
            local combo = (IsControlKeyDown() and "CTRL-" or "") .. (IsAltKeyDown() and "ALT-" or "")
                .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
            for _, oldKey in ipairs({ GetBindingKey(option.binding) }) do
                SetBinding(oldKey, nil)
            end
            if SetBinding(combo, option.binding) then
                SaveBindings(GetCurrentBindingSet())
            else
                BOLT:Print("Couldn't bind " .. combo .. ".")
            end
            Finish()
        end)
    end)

    holder.Refresh = function()
        button:SetText(GetBindingKey(option.binding) or "Unbound")
    end
    return holder
end

-- Favorite toy picker: current toy + a button opening a searchable list.
function Widgets.toy(parent, option)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(330, 22)

    local choose = BOLT:CreateButton(holder, "Choose Toy", 110, 22, function() Config:ShowToyPicker() end)
    choose:SetPoint("LEFT")
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", choose, "RIGHT", 10, 0)
    local name = AddLabel(holder, "", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 6, 0)

    holder.SetEnabled = function(_, enabled) choose:SetEnabled(enabled) end
    holder.Refresh = function()
        local toyID = BOLT:GetConfig("playground", "favoriteToyId")
        local _, toyName, toyIcon
        if toyID then
            _, toyName, toyIcon = C_ToyBox.GetToyInfo(toyID)
        end
        icon:SetTexture(toyIcon or "Interface\\Icons\\INV_Misc_QuestionMark")
        name:SetText(toyName or "None selected")
    end
    return holder
end

---------------------------------------------------------------------------
-- Toy picker
---------------------------------------------------------------------------

local TOY_ROW = 28

function Config:CreateToyPicker()
    local picker = BOLT:CreateDialog("BOLTToySelectionPopup", 420, 440, "Choose Favorite Toy")

    local search = CreateFrame("EditBox", nil, picker, "SearchBoxTemplate")
    search:SetSize(250, 22)
    search:SetPoint("TOPLEFT", 24, -48)
    search:HookScript("OnTextChanged", function() self:FilterToyPicker() end)
    picker.search = search

    local clear = BOLT:CreateButton(picker, "No Toy", 90, 22, function()
        Module("playground"):SetFavoriteToy(nil)
        picker:Hide()
        self:RefreshAll()
    end)
    clear:SetPoint("LEFT", search, "RIGHT", 12, 0)

    local scroll = CreateFrame("ScrollFrame", nil, picker, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -80)
    scroll:SetPoint("BOTTOMRIGHT", -36, 20)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(360, 1)
    scroll:SetScrollChild(content)
    picker.content = content
    picker.rows = {}

    self.toyPicker = picker
end

function Config:FilterToyPicker()
    local picker = self.toyPicker
    local query = picker.search:GetText():lower()
    local shown = 0
    for _, toy in ipairs(picker.toys) do
        if query == "" or toy.name:lower():find(query, 1, true) then
            shown = shown + 1
            local row = picker.rows[shown]
            if not row then
                row = CreateFrame("Button", nil, picker.content)
                row:SetSize(360, TOY_ROW)
                row:SetPoint("TOPLEFT", 0, -(shown - 1) * TOY_ROW)
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(22, 22)
                row.icon:SetPoint("LEFT", 4, 0)
                row.text = AddLabel(row, "", "GameFontHighlight")
                row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
                row:SetScript("OnClick", function(self)
                    Module("playground"):SetFavoriteToy(self.toyID)
                    picker:Hide()
                    Config:RefreshAll()
                end)
                picker.rows[shown] = row
            end
            row.toyID = toy.id
            row.icon:SetTexture(toy.icon)
            row.text:SetText(toy.name)
            row:Show()
        end
    end
    for index = shown + 1, #picker.rows do
        picker.rows[index]:Hide()
    end
    picker.content:SetHeight(math.max(1, shown * TOY_ROW))
end

function Config:ShowToyPicker()
    if not self.toyPicker then
        self:CreateToyPicker()
    end
    self.toyPicker.toys = Module("playground"):GetCollectedToys()
    self.toyPicker.search:SetText("")
    self:FilterToyPicker()
    self.toyPicker:Show()
end

---------------------------------------------------------------------------
-- Page building
---------------------------------------------------------------------------

local function IsOptionEnabled(option)
    return not option.requires or GetSetting(option.requires) and true or false
end

function Config:BuildSection(page, spec)
    local mod = Module(spec.module)
    local section = CreateFrame("Frame", nil, page.content)
    section.spec = spec
    section.mod = mod

    local title = AddLabel(section, spec.title or mod.displayName, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, 0)

    local y = -28
    if not mod.alwaysOn then
        local toggle = CreateFrame("CheckButton", nil, section, "UICheckButtonTemplate")
        toggle:SetSize(26, 26)
        toggle:SetPoint("TOPLEFT", 26, y)
        toggle.Text:SetFontObject("GameFontHighlight")
        toggle.Text:SetText("Enable")
        toggle:SetScript("OnClick", function(self)
            if self:GetChecked() and Module("editModeOptions") then
                Module("editModeOptions"):EnsureSomethingOn(spec.module)
            end
            BOLT:SetModuleEnabled(spec.module, self:GetChecked())
            Config:RefreshAll()
        end)
        section.toggle = toggle
        y = y - ROW_HEIGHT
    end
    section.headerHeight = -y

    local body = CreateFrame("Frame", nil, section)
    body:SetPoint("TOPLEFT", 0, y)
    body:SetPoint("RIGHT")
    section.body = body
    section.widgets = {}

    -- Sections whose options live in Edit Mode: only the switch above and a button here.
    local options = spec.options or {}
    local text = spec.description
    if spec.editMode and BOLT.EditMode and BOLT.EditMode.available then
        options = { { type = "button", label = "Open Edit Mode", width = 150, onClick = OpenEditMode } }
        text = (text and text .. "\n\n" or "") .. "|cffffd100Options in Edit Mode:|r " .. spec.editMode
    end
    if BOLT:IsLayoutModule(spec.module) then
        text = (text and text .. "\n" or "") .. "|cff888888Saved with your current Edit Mode layout, for all your characters.|r"
    end

    local by = 0
    if text then
        local description = AddLabel(body, text)
        description:SetPoint("TOPLEFT", 30, by)
        description:SetWidth(540)
        description:SetJustifyH("LEFT")
        by = by - math.max(ROW_HEIGHT - 6, description:GetStringHeight() + 10)
    end

    local previous
    for _, option in ipairs(options) do
        -- `available` hides options for systems this client lacks (e.g. on WoW: Forever).
        if not option.available or option.available() then
            local widget = Widgets[option.type](body, option)
            widget.option = option
            if option.sameRow and previous then
                widget:SetPoint("LEFT", previous.anchorRight or previous, "RIGHT", 12, 0)
            else
                widget:SetPoint("TOPLEFT", OPTION_X + (option.indent or 0) - (option.type == "checkbox" and 4 or 0), by)
                by = by - ROW_HEIGHT
            end
            table.insert(section.widgets, widget)
            previous = widget
        end
    end

    section.bodyHeight = -by
    body:SetHeight(math.max(1, section.bodyHeight))
    table.insert(page.sections, section)
end

function Config:LayoutPage(page)
    local y = -56
    for _, section in ipairs(page.sections) do
        local expanded = BOLT:IsModuleEnabled(section.spec.module)
        section.body:SetShown(expanded)
        local height = section.headerHeight + (expanded and section.bodyHeight or 0)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", 0, y)
        section:SetPoint("RIGHT")
        section:SetHeight(height)
        y = y - height - 12
    end
    page.content:SetHeight(-y + 20)
end

function Config:BuildPage(definition)
    local panel = CreateFrame("Frame")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)

    local heading = AddLabel(content, definition.title, "GameFontNormalHuge")
    heading:SetPoint("TOPLEFT", 16, -16)

    local page = { panel = panel, content = content, sections = {}, title = definition.title }
    for _, spec in ipairs(definition.sections) do
        if Module(spec.module) then
            self:BuildSection(page, spec)
        end
    end
    panel:SetScript("OnShow", function() self:RefreshAll() end)
    return page
end

function Config:BuildMainPanel()
    local panel = CreateFrame("Frame")
    local heading = AddLabel(panel, "B.O.L.T", "GameFontNormalHuge")
    heading:SetPoint("TOPLEFT", 16, -16)

    local version = AddLabel(panel, "Brittle and Occasionally Lethal Tweaks - v" .. BOLT.version, "GameFontHighlight")
    version:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)

    local help = AddLabel(panel, "Pick a category on the left to configure each module. Type /bolt help for chat commands."
        .. "\n\nEdit Mode: B.O.L.T's frames (camp bar, ranged timer) move like Blizzard's, and selecting a Blizzard frame shows a B.O.L.T block with what B.O.L.T can do to it. Options for those live only there; these pages turn the modules on and off."
        .. (BOLT.isForever and "\n\nRunning on WoW: Forever - modules for modern-only systems are hidden." or ""))
    help:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -16)
    help:SetWidth(560)
    help:SetJustifyH("LEFT")

    local reload = BOLT:CreateButton(panel, "Reload UI", 120, 25, ReloadUI)
    reload:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -16)
    return panel
end

---------------------------------------------------------------------------
-- Refresh
---------------------------------------------------------------------------

function Config:RefreshAll()
    for _, page in ipairs(self.pages or {}) do
        for _, section in ipairs(page.sections) do
            if section.toggle then
                section.toggle:SetChecked(BOLT:IsModuleEnabled(section.spec.module))
            end
            for _, widget in ipairs(section.widgets) do
                if widget.Refresh then widget:Refresh() end
                SetWidgetEnabled(widget, IsOptionEnabled(widget.option))
            end
        end
        self:LayoutPage(page)
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Config:OnEnable()
    if self.category then return end

    local main = Settings.RegisterCanvasLayoutCategory(self:BuildMainPanel(), "B.O.L.T")
    self.pages = {}
    for _, definition in ipairs(PAGES) do
        local page = self:BuildPage(definition)
        if #page.sections > 0 then
            Settings.RegisterCanvasLayoutSubcategory(main, page.panel, definition.title)
            table.insert(self.pages, page)
        end
    end
    Settings.RegisterAddOnCategory(main)
    self.category = main
    self:RefreshAll()
end

function Config:Open()
    Settings.OpenToCategory(self.category:GetID())
end

BOLT:RegisterModule("config", Config)
