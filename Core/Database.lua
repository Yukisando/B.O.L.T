-- B.O.L.T Database Management (Brittle and Occasionally Lethal Tweaks)
-- Saved variables layout (BOLTDB, account-wide):
--   moduleStates[module]   = bool   account-wide on/off toggles (modules not in LAYOUT_MODULES)
--   layouts[layoutName]    = table  UI setup per Edit Mode layout, shared by every character:
--                                   modules (on/off of LAYOUT_MODULES), settings (LAYOUT_SECTIONS),
--                                   frames (BOLT frames' positions and dialog choices, EditMode.lua)
--   profiles[playerKey]    = table  per-character options (see BOLT.defaults.profile)
--   admin, transmogPresets, preMuteVolume, sellList   account-wide data owned by modules

local ADDON_NAME, BOLT = ...

-- Keys that older versions stored in profiles and that are now dead.
local LEGACY_PROFILE_KEYS = {
    { "nameplatesEnhancement", "interruptWarning" },
    { "nameplatesEnhancement", "interruptWarningColor" },
    { "skyriding", "toggleMode" },
    { "playground", "allowSpecialGamemode" },
    { "autoHide", "microMenu" },
    -- The minimap's per-button placements became one button bar.
    { "minimap", "zone" }, { "minimap", "clock" }, { "minimap", "difficulty" }, { "minimap", "tracking" },
    { "minimap", "calendar" }, { "minimap", "mail" }, { "minimap", "landingPage" },
    { "minimap", "compartment" }, { "minimap", "drawer" },
    { "campfire", "recipes" }, -- became the built-in recipe table plus campfire.learned
    { "campfire", "collapsed" },
    { "screenEdges", "minimap" }, -- became minimapEdge, defaulting to MAP (2026-11-09) -- the camp panel became a bar with a drawer (campfire.expanded)
}

-- Immersive Mode (one toggle) became per-frame options in Edit Mode (2026-11-09). Players who
-- had it on get the same result: both frames hidden, the Personal Resource Display keeps its
-- extras. The display's CVar was already on from Immersive, so it stays as it is.
local function MigrateImmersive(profile, wasOn)
    local old = profile.immersive
    profile.immersive = nil
    if not wasOn then return end
    local frames = profile.frameVisibility or {}
    profile.frameVisibility = frames
    frames.player = frames.player or {}
    frames.target = frames.target or {}
    frames.player.hide, frames.target.hide = true, true
    frames.display = frames.display or {}
    local display = frames.display
    old = type(old) == "table" and old or {}
    display.showWithTarget = old.showWithTarget ~= false
    display.idleAlpha = old.idleAlpha or 10
    display.rightClickMenus = old.rightClickMenus ~= false
end

-- Target conditions were on/off (2026-11-09) and became a choice of target kind: any,
-- attackable, not attackable. The Target Frame's "hostile" became target = "HOSTILE".
local function MigrateTargetKinds(profile)
    local frames = profile.frameVisibility
    if type(frames) ~= "table" then return end
    local function Kind(value, onKind)
        if value == true then return onKind end
        if value == false then return "OFF" end
        return value
    end
    if type(frames.player) == "table" then
        frames.player.target = Kind(frames.player.target, "ANY")
    end
    if type(frames.target) == "table" then
        if frames.target.hostile ~= nil and frames.target.target == nil then
            frames.target.target = Kind(frames.target.hostile, "HOSTILE")
        end
        frames.target.hostile = nil
    end
    if type(frames.display) == "table" then
        frames.display.showWithTarget = Kind(frames.display.showWithTarget, "HOSTILE")
    end
end

-- Auto-hide had one on/off and one rule per fixed part (mainBar, actionBars, unitFrames...),
-- until 2026-11-14; before that, one opacity and target choice shared by all. It became fade
-- groups: elements (each bar, each frame) join one of four groups, each group with its own rule.
-- Parts with the same rule land in the same group (up to four groups).
local OLD_AUTOHIDE_PARTS = {
    { "mainBar", { "mainBar", "microMenu", "bags" } },
    { "actionBars", { "bar2", "bar3", "bar4", "bar5", "bar6", "bar7", "bar8", "stanceBar", "petBar" } },
    { "xpBar", { "xpBar" } },
    { "buffs", { "buffs" } },
    { "debuffs", { "debuffs" } },
    { "unitFrames", { "playerFrame", "petFrame", "focusFrame", "partyFrames" } },
    { "questTracker", { "questTracker" } },
    { "minimap", { "minimap" } },
    { "minimapButtons", { "minimapButtons" } },
}
local RULE_FIELDS = { "hover", "combat", "target", "group", "instance", "mounted", "alpha" }

local function MigrateAutoHideGroups(settings)
    local autoHide = type(settings) == "table" and settings.autoHide
    if type(autoHide) ~= "table" then return end
    local old = false
    for _, part in ipairs(OLD_AUTOHIDE_PARTS) do
        if type(autoHide[part[1]]) == "boolean" then old = true end
    end
    if not old then return end

    local defaults = BOLT.defaults.profile.autoHide
    local base = CopyTable(defaults.groups.g1)
    if autoHide.idleAlpha ~= nil then base.alpha = autoHide.idleAlpha end
    if autoHide.showWithTarget ~= nil then base.target = autoHide.showWithTarget end
    local oldRules = type(autoHide.rules) == "table" and autoHide.rules or {}

    local groups, members, bySignature, count = {}, {}, {}, 0
    for _, part in ipairs(OLD_AUTOHIDE_PARTS) do
        local key, elements = part[1], part[2]
        local id = "none"
        if autoHide[key] == true then
            local rule = CopyTable(base)
            if type(oldRules[key]) == "table" then
                for _, field in ipairs(RULE_FIELDS) do
                    if oldRules[key][field] ~= nil then rule[field] = oldRules[key][field] end
                end
            end
            local signature = {}
            for _, field in ipairs(RULE_FIELDS) do table.insert(signature, tostring(rule[field])) end
            signature = table.concat(signature, "|")
            id = bySignature[signature]
            if not id then
                if count < 4 then
                    count = count + 1
                    id = "g" .. count
                    groups[id] = rule
                    bySignature[signature] = id
                else
                    id = "g4"
                end
            end
        end
        for _, element in ipairs(elements) do members[element] = id end
        autoHide[key] = nil
    end
    for id, rule in pairs(defaults.groups) do
        if not groups[id] then groups[id] = CopyTable(rule) end
    end
    autoHide.groups, autoHide.members = groups, members
    autoHide.rules, autoHide.idleAlpha, autoHide.showWithTarget = nil, nil, nil
end

-- UI modules: switched on and off per Edit Mode layout.
BOLT.LAYOUT_MODULES = {
    unitFrames = true,
    minimap = true,
    autoHide = true,
    tooltip = true,
    nameplatesEnhancement = true,
    partyFramesCenterGrowth = true,
    rangedTimer = true,
    campfire = true,
}

-- Settings sections saved per Edit Mode layout instead of per character.
local LAYOUT_SECTIONS = {
    unitFrames = true,
    frameVisibility = true,
    autoHide = true,
    minimap = true,
    screenEdges = true,
    nameplatesEnhancement = true,
    rangedTimer = true,
    campfire = true,
}
-- Keys inside those sections that are character data, not UI.
local CHARACTER_KEYS = {
    campfire = { learned = true },
}

local function IsLayoutPath(section, key)
    if not LAYOUT_SECTIONS[section] then return false end
    local exceptions = CHARACTER_KEYS[section]
    return not (exceptions and key ~= nil and exceptions[key])
end

function BOLT:GetPlayerKey()
    return UnitName("player") .. " - " .. GetRealmName()
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and CopyTable(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

-- Defaults split in two: per-character keys for profiles, layout keys for layouts.
local function SplitDefaults(defaults)
    local character, layout = {}, {}
    for section, value in pairs(defaults) do
        if LAYOUT_SECTIONS[section] and type(value) == "table" then
            layout[section] = value
            local exceptions = CHARACTER_KEYS[section]
            if exceptions then
                character[section] = {}
                for key in pairs(exceptions) do
                    character[section][key] = value[key]
                end
            end
        else
            character[section] = value
        end
    end
    return character, layout
end

-- A fresh layout: install defaults, or a character's old per-character setup on first run.
local function NewLayout(profile, moduleStates, layoutDefaults)
    local layout = { modules = {}, settings = {}, frames = {} }
    for name in pairs(BOLT.LAYOUT_MODULES) do
        local state = moduleStates and moduleStates[name]
        if state == nil then state = BOLT.defaultModuleStates[name] end
        layout.modules[name] = state and true or false
    end
    if profile then
        for section in pairs(LAYOUT_SECTIONS) do
            if type(profile[section]) == "table" then
                layout.settings[section] = CopyTable(profile[section])
                for key in pairs(CHARACTER_KEYS[section] or {}) do
                    layout.settings[section][key] = nil
                end
            end
        end
    end
    MergeDefaults(layout.settings, layoutDefaults)
    return layout
end

local function CleanProfile(profile, moduleNames)
    -- Module enabled flags moved from profiles to moduleStates.
    for name in pairs(moduleNames) do
        if type(profile[name]) == "table" then
            profile[name].enabled = nil
        end
    end
    for _, path in ipairs(LEGACY_PROFILE_KEYS) do
        local section = profile[path[1]]
        if type(section) == "table" then
            section[path[2]] = nil
        end
    end
end

function BOLT:InitializeDatabase()
    BOLTDB = BOLTDB or {}
    BOLTDB.profiles = BOLTDB.profiles or {}

    local playerKey = self:GetPlayerKey()

    -- Migrate module toggles out of the old per-character profiles.
    if not BOLTDB.moduleStates then
        BOLTDB.moduleStates = {}
        local oldProfile = BOLTDB.profiles[playerKey]
        if oldProfile then
            for name in pairs(self.defaultModuleStates) do
                if type(oldProfile[name]) == "table" and oldProfile[name].enabled ~= nil then
                    BOLTDB.moduleStates[name] = oldProfile[name].enabled
                end
            end
        end
    end
    for name, default in pairs(self.defaultModuleStates) do
        if BOLTDB.moduleStates[name] == nil and not self.LAYOUT_MODULES[name] then
            BOLTDB.moduleStates[name] = default
        end
    end

    local immersiveOn = BOLTDB.moduleStates.immersive
    BOLTDB.moduleStates.immersive = nil
    for _, profile in pairs(BOLTDB.profiles) do
        if profile.immersive ~= nil or immersiveOn then
            MigrateImmersive(profile, immersiveOn == true)
        end
        MigrateTargetKinds(profile)
        CleanProfile(profile, self.defaultModuleStates)
    end

    -- The profile table is the saved table itself, so every write persists.
    local profile = BOLTDB.profiles[playerKey] or {}
    BOLTDB.profiles[playerKey] = profile
    local characterDefaults, layoutDefaults = SplitDefaults(self.defaults.profile)
    self.layoutDefaults = layoutDefaults

    -- UI settings moved from each character to each Edit Mode layout (2026-11-10). The first
    -- character to log in after that seeds the layouts with its setup.
    if not BOLTDB.layouts then
        BOLTDB.layouts = {}
        local old = profile.editMode
        for layoutName, frames in pairs(type(old) == "table" and old or {}) do
            local layout = NewLayout(profile, BOLTDB.moduleStates, layoutDefaults)
            layout.frames = frames
            BOLTDB.layouts[layoutName] = layout
        end
        if not next(BOLTDB.layouts) then
            local layout = NewLayout(profile, BOLTDB.moduleStates, layoutDefaults)
            layout.placeholder = true
            BOLTDB.layouts["?"] = layout
        end
    end
    for _, other in pairs(BOLTDB.profiles) do
        other.editMode = nil
        for section in pairs(LAYOUT_SECTIONS) do
            if type(other[section]) == "table" then
                local kept = {}
                for key in pairs(CHARACTER_KEYS[section] or {}) do
                    kept[key] = other[section][key]
                end
                other[section] = next(kept) and kept or nil
            end
        end
    end
    for name in pairs(self.LAYOUT_MODULES) do
        BOLTDB.moduleStates[name] = nil
    end
    for _, layout in pairs(BOLTDB.layouts) do
        layout.modules = layout.modules or {}
        layout.settings = layout.settings or {}
        layout.frames = layout.frames or {}
        MigrateAutoHideGroups(layout.settings)
        MergeDefaults(layout.settings, layoutDefaults)
        for name in pairs(self.LAYOUT_MODULES) do
            if layout.modules[name] == nil then
                layout.modules[name] = self.defaultModuleStates[name] and true or false
            end
        end
    end

    -- The pet health bar shipped off by default (v8-11) and the merge above wrote that "off"
    -- into every layout. It defaults to on now: flip the stored off once, the day after it
    -- shipped, before anyone could really have chosen it.
    if not BOLTDB.petHealthDefaultOn then
        for _, layout in pairs(BOLTDB.layouts) do
            local display = type(layout.settings.frameVisibility) == "table" and layout.settings.frameVisibility.display
            if type(display) == "table" and display.petHealth == false then
                display.petHealth = true
            end
        end
        BOLTDB.petHealthDefaultOn = true
    end

    MergeDefaults(profile, characterDefaults)

    self.db = { global = BOLTDB, profile = profile }

    -- Until Blizzard reports the active layout (shortly after login), use the one this
    -- character was last on.
    self.layoutName = profile.lastLayout
    if not (self.layoutName and BOLTDB.layouts[self.layoutName]) then
        self.layoutName = next(BOLTDB.layouts)
    end
    if not self.layoutName then
        local layout = NewLayout(nil, nil, layoutDefaults)
        layout.placeholder = true
        BOLTDB.layouts["?"] = layout
        self.layoutName = "?"
    end
end

-- Blizzard deleted or renamed a layout.
function BOLT:DeleteLayout(layoutName)
    if layoutName ~= self.layoutName then
        BOLTDB.layouts[layoutName] = nil
    end
end

function BOLT:RenameLayout(oldName, newName)
    local layouts = BOLTDB.layouts
    if not layouts[oldName] or layouts[newName] then return end
    layouts[newName], layouts[oldName] = layouts[oldName], nil
    if self.layoutName == oldName then
        self.layoutName = newName
        self.db.profile.lastLayout = newName
    end
end

---------------------------------------------------------------------------
-- Edit Mode layouts
---------------------------------------------------------------------------

-- The layout's saved setup. A layout BOLT hasn't seen yet starts as a copy of the current one
-- (or of copySource, the layout Blizzard copied it from).
function BOLT:GetLayout(layoutName, copySource)
    layoutName = layoutName or self.layoutName
    local layouts = BOLTDB.layouts
    local layout = layouts[layoutName]
    if layout then return layout end

    local source = (copySource and layouts[copySource]) or layouts[self.layoutName]
    if source and source.placeholder then
        -- Set up before Blizzard named the layout: that setup was this layout all along.
        for name, other in pairs(layouts) do
            if other == source then layouts[name] = nil end
        end
        source.placeholder = nil
        layout = source
    elseif source then
        layout = CopyTable(source)
    else
        layout = NewLayout(nil, nil, self.layoutDefaults)
    end
    layouts[layoutName] = layout
    return layout
end

function BOLT:IsLayoutModule(name)
    return self.LAYOUT_MODULES[name] == true
end

-- Blizzard switched Edit Mode layout: every UI module follows the new layout's setup.
function BOLT:SwitchLayout(layoutName)
    if not layoutName or not self.db then return end
    local previous = self.layoutName
    self:GetLayout(layoutName)
    self.layoutName = layoutName
    self.db.profile.lastLayout = layoutName
    if layoutName == previous then return end

    if InCombatLockdown() then
        self.pendingLayoutApply = true
        return
    end
    self:ApplyLayout()
end

function BOLT:ApplyLayout()
    self.pendingLayoutApply = nil
    for _, name in ipairs(self.moduleOrder) do
        local mod = self.modules[name]
        local layoutModule = self:IsLayoutModule(name)
        local wanted = self:IsModuleEnabled(name)
        if layoutModule and wanted ~= (mod.active == true) then
            if wanted then
                self:ActivateModule(mod)
            else
                self:DeactivateModule(mod)
            end
        elseif (layoutModule or LAYOUT_SECTIONS[name]) and mod.active then
            if mod.OnLayoutChanged then
                mod:OnLayoutChanged()
            elseif mod.OnSettingChanged then
                mod:OnSettingChanged(nil, { name })
            end
        end
    end
    local config = self.modules.config
    if config and config.pages then
        config:RefreshAll()
    end
end

-- GetConfig("section", "key"[, default]) — string keys walk the profile; a trailing
-- non-string argument is the value returned when the setting is missing.
function BOLT:GetConfig(...)
    local count = select("#", ...)
    local default
    if count > 0 and type((select(count, ...))) ~= "string" then
        default = select(count, ...)
        count = count - 1
    end

    local node = self.db and self.db.profile
    if node and count > 0 and IsLayoutPath((select(1, ...)), count > 1 and (select(2, ...)) or nil) then
        node = self:GetLayout().settings
    end
    for i = 1, count do
        if type(node) ~= "table" then return default end
        node = node[(select(i, ...))]
    end

    if node == nil then return default end
    return node
end

-- SetConfig(value, "section", "key") — creates intermediate tables as needed.
function BOLT:SetConfig(value, ...)
    local count = select("#", ...)
    local node = self.db.profile
    if IsLayoutPath((select(1, ...)), count > 1 and (select(2, ...)) or nil) then
        node = self:GetLayout().settings
    end
    for i = 1, count - 1 do
        local key = select(i, ...)
        if type(node[key]) ~= "table" then
            node[key] = {}
        end
        node = node[key]
    end
    node[(select(count, ...))] = value
end
