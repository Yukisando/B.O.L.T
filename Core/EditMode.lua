-- B.O.L.T Edit Mode bridge (Brittle and Occasionally Lethal Tweaks)
-- BOLT plugs into Blizzard's Edit Mode through LibEditMode (Libs\LibEditMode, loaded in
-- "namespaced" mode so it lives on BOLT.LibEditMode and needs no LibStub).
--
--   * BOLT's own frames (camp bar, ranged timer...) are registered with EditMode:AddFrame: they
--     get the blue Edit Mode selection, drag to move, and a settings dialog. Positions and
--     per-frame choices are saved per Edit Mode layout in BOLTDB.layouts[layout].frames[key],
--     shared by every character (Core/Database.lua).
--   * Blizzard's frames (Player Frame, Minimap, action bars...) get a "B.O.L.T" block under their
--     own Edit Mode dialog with EditMode:AddSystemSettings. Those options are the same saved
--     settings the BOLT settings page edits.

local ADDON_NAME, BOLT = ...

local LEM = BOLT.LibEditMode
local EditMode = {}
BOLT.EditMode = EditMode
EditMode.lib = LEM
EditMode.available = LEM ~= nil and Enum.EditModeSystem ~= nil
EditMode.SettingType = LEM and LEM.SettingType or {}

local HEADER = "|cff00aaffB.O.L.T|r"
local specs = {} -- [key] = frame spec

---------------------------------------------------------------------------
-- Per-layout storage
---------------------------------------------------------------------------

local function Store(key, layoutName)
    local frames = BOLT:GetLayout(layoutName).frames
    frames[key] = frames[key] or {}
    return frames[key]
end

function EditMode:Get(key, field, default, layoutName)
    local value = Store(key, layoutName)[field]
    if value == nil then return default end
    return value
end

function EditMode:Set(key, field, value, layoutName)
    Store(key, layoutName)[field] = value
end

function EditMode:IsActive()
    if LEM then return LEM:IsInEditMode() end
    return false
end

---------------------------------------------------------------------------
-- BOLT frames
---------------------------------------------------------------------------

-- spec = {
--   key       saved-variable key, e.g. "campBar"
--   name      label shown on the Edit Mode selection
--   frame     the frame (parented to UIParent)
--   default   { point = "CENTER", x = 0, y = 0 }
--   settings  LibEditMode setting objects for its dialog (optional)
--   onEnter() / onExit()   show a preview in Edit Mode, hide it afterwards
--   onMoved(layoutName)    the user dragged it (position already saved)
--   apply(layoutName)      layout changed: place the frame again
-- }
function EditMode:AddFrame(spec)
    if not self.available or specs[spec.key] then return end
    specs[spec.key] = spec
    spec.frame.editModeName = spec.name
    LEM:AddFrame(spec.frame, function(_, layoutName, point, x, y)
        local store = Store(spec.key, layoutName)
        store.point, store.x, store.y = point, x, y
        if spec.onMoved then spec.onMoved(layoutName) end
    end, spec.default, spec.name)
    if spec.settings then
        LEM:AddFrameSettings(spec.frame, spec.settings)
    end
    if self:IsActive() and spec.onEnter then
        spec.onEnter()
    end
end

-- Saved position for a frame in the current layout, or its default.
function EditMode:GetPosition(key)
    local spec = specs[key]
    local default = spec and spec.default or { point = "CENTER", x = 0, y = 0 }
    local store = Store(key)
    if store.point then return store.point, store.x or 0, store.y or 0 end
    return default.point, default.x, default.y
end

function EditMode:HasSavedPosition(key)
    return Store(key).point ~= nil
end

function EditMode:ClearPosition(key)
    local store = Store(key)
    store.point, store.x, store.y = nil, nil, nil
end

-- Re-reads every value in the frame's open dialog.
function EditMode:RefreshFrame(key)
    local spec = specs[key]
    if spec and LEM then LEM:RefreshFrameSettings(spec.frame) end
end

if LEM then
    LEM:RegisterCallback("enter", function()
        for _, spec in pairs(specs) do
            if spec.onEnter then spec.onEnter() end
        end
    end)
    LEM:RegisterCallback("exit", function()
        for _, spec in pairs(specs) do
            if spec.onExit then spec.onExit() end
        end
    end)
    LEM:RegisterCallback("layout", function(layoutName)
        if not BOLT.db then return end
        BOLT:SwitchLayout(layoutName)
        for _, spec in pairs(specs) do
            if spec.apply then spec.apply(layoutName) end
        end
    end)

    LEM:RegisterCallback("create", function(layoutName, _, copySource)
        if BOLT.db then BOLT:GetLayout(layoutName, copySource) end
    end)
    LEM:RegisterCallback("rename", function(oldName, newName)
        if BOLT.db then BOLT:RenameLayout(oldName, newName) end
    end)
    LEM:RegisterCallback("delete", function(layoutName)
        if BOLT.db then BOLT:DeleteLayout(layoutName) end
    end)

    -- A layout switch during combat waits for it to end (modules may touch secure frames).
    local regen = CreateFrame("Frame")
    regen:RegisterEvent("PLAYER_REGEN_ENABLED")
    regen:SetScript("OnEvent", function()
        if BOLT.pendingLayoutApply then BOLT:ApplyLayout() end
    end)
end

---------------------------------------------------------------------------
-- Options on Blizzard's own Edit Mode systems
---------------------------------------------------------------------------

-- systemName = key of Enum.EditModeSystem ("UnitFrame"); indexEnum/indexName pick a sub-system
-- ("EditModeUnitFrameSystemIndices", "Player"). A "B.O.L.T" divider heads the block.
-- Returns false when this client has no such system. noHeader: add to a block already headed.
function EditMode:AddSystemSettings(systemName, indexEnum, indexName, settings, noHeader)
    if not self.available or #settings == 0 then return false end
    local system = Enum.EditModeSystem[systemName]
    if system == nil then return false end
    local sub
    if indexEnum then
        sub = Enum[indexEnum] and Enum[indexEnum][indexName]
        if sub == nil then return false end
    end
    local list = noHeader and {} or { self:Header() }
    for _, setting in ipairs(settings) do table.insert(list, setting) end
    LEM:AddSystemSettings(system, list, sub)
    return true
end

---------------------------------------------------------------------------
-- Setting builders bound to BOLT's saved settings
---------------------------------------------------------------------------

local function DefaultAt(path)
    local node = BOLT.defaults.profile
    for _, key in ipairs(path) do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

function EditMode:Header(text)
    return { kind = self.SettingType.Divider, name = text or HEADER }
end

-- opts: desc, disabled(), hidden(), get(), set(value) (to bind to something other than `path`),
-- keepOnReset (the dialog's "Reset to default" leaves it alone: module on/off, CVars)
function EditMode:Checkbox(name, path, opts)
    opts = opts or {}
    local default = opts.default
    if default == nil and path then default = DefaultAt(path) and true or false end
    return {
        kind = self.SettingType.Checkbox,
        name = name,
        desc = opts.desc,
        default = default or false,
        disabled = opts.disabled,
        hidden = opts.hidden,
        get = opts.get or function() return BOLT:GetConfig(unpack(path)) and true or false end,
        set = function(_, value, fromReset)
            -- Clicks pass fromReset = false; "Reset to default" passes nothing.
            if opts.keepOnReset and fromReset ~= false then return end
            if opts.set then
                opts.set(value)
            else
                BOLT:SetSetting(path, value and true or false)
            end
        end,
    }
end

-- opts: min, max, step, format(value) -> string, desc, disabled(), hidden(), get(), set(value)
function EditMode:Slider(name, path, opts)
    opts = opts or {}
    local default = opts.default
    if default == nil and path then default = DefaultAt(path) end
    return {
        kind = self.SettingType.Slider,
        name = name,
        desc = opts.desc,
        default = default or opts.min or 0,
        minValue = opts.min or 0,
        maxValue = opts.max or 100,
        valueStep = opts.step or 1,
        formatter = opts.format,
        disabled = opts.disabled,
        hidden = opts.hidden,
        get = opts.get or function() return BOLT:GetConfig(unpack(path)) end,
        set = opts.set and function(_, value) opts.set(value) end
            or function(_, value) BOLT:SetSetting(path, value) end,
    }
end

-- values = { { text = "Left", value = "LEFT" }, ... }
function EditMode:Dropdown(name, path, values, opts)
    opts = opts or {}
    local default = opts.default
    if default == nil and path then default = DefaultAt(path) end
    return {
        kind = self.SettingType.Dropdown,
        name = name,
        desc = opts.desc,
        default = default,
        values = values,
        disabled = opts.disabled,
        hidden = opts.hidden,
        get = opts.get or function() return BOLT:GetConfig(unpack(path)) end,
        set = opts.set and function(_, value) opts.set(value) end
            or function(_, value) BOLT:SetSetting(path, value) end,
    }
end

-- Percent formatter shared by opacity and size sliders.
function EditMode.Percent(value)
    return ("%d%%"):format(value)
end
