-- B.O.L.T Edit Mode options on Blizzard's frames
-- Select a Blizzard frame in Edit Mode and a "B.O.L.T" block under its own settings lists what
-- BOLT can do to that frame. Each checkbox says what happens to *this* frame ("Fade out until
-- needed", "Flat style"), and turns its module on or off as needed: checked means it's happening.
-- The settings page only holds the module on/off switches and an "Open Edit Mode" button.
-- The Player, Target and Personal Resource Display blocks start in FrameVisibility; BOLT's own
-- frames (camp bar, ranged timer) have their own Edit Mode dialogs in their modules.

local ADDON_NAME, BOLT = ...
local EditMode = BOLT.EditMode

local EditModeOptions = {
    displayName = "Edit Mode options",
    alwaysOn = true,
}

local function Active(name)
    return BOLT:IsModuleEnabled(name) and BOLT.modules[name] ~= nil
end

local function Off(name)
    return function() return not Active(name) end
end

-- The per-frame settings of a module that does several frames at once.
local GROUP_KEYS = {
    unitFrames = { "player", "target", "targetOfTarget", "pet", "party", "castBars" },
}

local function On(module, key)
    return Active(module) and BOLT:GetConfig(module, key) and true or false
end

-- Turns one frame's part of a module on or off. Turning the module on from one frame only does
-- that frame (the others start off); turning the last frame off turns the module off.
local function SetFramePart(module, key, value)
    if value then
        if not Active(module) then
            for _, other in ipairs(GROUP_KEYS[module]) do
                BOLT:SetConfig(other == key, module, other)
            end
            BOLT:SetModuleEnabled(module, true)
        else
            BOLT:SetSetting({ module, key }, true)
        end
    else
        BOLT:SetSetting({ module, key }, false)
        for _, other in ipairs(GROUP_KEYS[module]) do
            if BOLT:GetConfig(module, other) then return end
        end
        BOLT:SetModuleEnabled(module, false)
    end
end

local function FramePart(module, key, label, desc)
    return EditMode:Checkbox(label, nil, {
        desc = desc,
        default = false,
        keepOnReset = true,
        get = function() return On(module, key) end,
        set = function(value) SetFramePart(module, key, value) end,
    })
end

-- A single-purpose module: the checkbox is the module itself.
local function ModuleToggle(name, label, desc)
    if not BOLT.modules[name] then return nil end
    return EditMode:Checkbox(label, nil, {
        desc = desc,
        default = false,
        keepOnReset = true,
        get = function() return BOLT:IsModuleEnabled(name) end,
        set = function(value) BOLT:SetModuleEnabled(name, value) end,
    })
end

local function List(...)
    local list = {}
    for i = 1, select("#", ...) do
        local setting = select(i, ...)
        if setting then table.insert(list, setting) end
    end
    return list
end

---------------------------------------------------------------------------
-- Auto-hide UI
---------------------------------------------------------------------------

-- Each frame picks a fade group ("Fades with"), and under it edits that group's conditions.
-- The conditions belong to the group: every frame in the group follows them, so they're bound
-- to whichever group the frame is in at the moment, not to the frame.
local SHARED = " This is a setting of the whole group: every frame in it follows it."

local function GroupChoices()
    local autoHide = BOLT.modules.autoHide
    local values = { { text = "Never (always shown)", value = autoHide.NONE } }
    for _, id in ipairs(autoHide.GROUP_IDS) do
        table.insert(values, { text = autoHide.GroupName(id), value = id })
    end
    return values
end

-- "Fades with" for one element, then (unless conditions = false) its group's rule.
local function Fade(elementKey, label, conditions)
    local autoHide = BOLT.modules.autoHide
    if not autoHide then return {} end
    local element = autoHide.ELEMENT_BY_KEY[elementKey]
    local function Group() return autoHide.MemberOf(elementKey) end
    local function Faded() return Active("autoHide") and Group() ~= autoHide.NONE end
    local notFaded = function() return not Faded() end
    local function Get(field)
        return function() return autoHide.RuleValue(autoHide.Rule(Group()), field) end
    end
    local function Set(field)
        return function(value)
            local id = Group()
            if id ~= autoHide.NONE then BOLT:SetSetting({ "autoHide", "groups", id, field }, value) end
        end
    end

    local settings = {
        EditMode:Dropdown(label or "Fades with", nil, GroupChoices(), {
            desc = ("Puts the %s in a fade group: the frames of a group fade in and out together, by the group's conditions. Hovering any of them shows the whole group. Groups are also on the B.O.L.T settings page (Auto-hide UI)."):format(element.label:lower()),
            default = autoHide.NONE, keepOnReset = true,
            get = function() return Active("autoHide") and Group() or autoHide.NONE end,
            set = function(value) autoHide.SetMember(elementKey, value) end,
        }),
    }
    if conditions == false then return settings end

    for _, condition in ipairs(autoHide.CONDITIONS) do
        table.insert(settings, EditMode:Checkbox("  Shows: " .. condition.label:lower(), nil, {
            desc = "The group comes back while this is true." .. SHARED,
            default = false, keepOnReset = true, hidden = notFaded,
            get = Get(condition.key), set = Set(condition.key),
        }))
    end
    local visibility = BOLT.modules.frameVisibility
    if visibility then
        table.insert(settings, EditMode:Dropdown("  Shows with a target", nil, visibility.TARGET_CHOICES, {
            desc = "Which targets bring the group back." .. SHARED,
            default = "OFF", keepOnReset = true, hidden = notFaded,
            get = Get("target"), set = Set("target"),
        }))
    end
    table.insert(settings, EditMode:Checkbox("  Not while mounted", nil, {
        desc = "While mounted or on a flight path, only hover and combat bring the group back." .. SHARED,
        default = false, keepOnReset = true, hidden = notFaded,
        get = Get("mounted"), set = Set("mounted"),
    }))
    table.insert(settings, EditMode:Slider("  Opacity while faded", nil, {
        min = 0, max = 100, step = 5, format = EditMode.Percent,
        desc = "How visible the group stays while faded out." .. SHARED,
        keepOnReset = true, hidden = notFaded,
        get = Get("alpha"), set = Set("alpha"),
    }))
    return settings
end

-- Edit Mode's action bar index names, to BOLT's element keys.
local BARS = {
    { "MainBar", "mainBar" }, { "Bar2", "bar2" }, { "Bar3", "bar3" }, { "RightBar1", "bar4" },
    { "RightBar2", "bar5" }, { "ExtraBar1", "bar6" }, { "ExtraBar2", "bar7" }, { "ExtraBar3", "bar8" },
    { "StanceBar", "stanceBar" }, { "PetActionBar", "petBar" },
}

local function RegisterAutoHide()
    local indices = "EditModeActionBarSystemIndices"
    for _, bar in ipairs(BARS) do
        EditMode:AddSystemSettings("ActionBar", indices, bar[1], Fade(bar[2]))
    end
    EditMode:AddSystemSettings("MicroMenu", nil, nil, Fade("microMenu"))
    EditMode:AddSystemSettings("Bags", nil, nil, Fade("bags"))
    EditMode:AddSystemSettings("StatusTrackingBar", nil, nil, Fade("xpBar"))
    EditMode:AddSystemSettings("AuraFrame", "EditModeAuraFrameSystemIndices", "BuffFrame", Fade("buffs"))
    EditMode:AddSystemSettings("AuraFrame", "EditModeAuraFrameSystemIndices", "DebuffFrame", Fade("debuffs"))
    EditMode:AddSystemSettings("ObjectiveTracker", nil, nil, Fade("questTracker"))
end

---------------------------------------------------------------------------
-- Minimap
---------------------------------------------------------------------------

local BUTTON_SIDES = {
    { text = "Bottom", value = "BOTTOM" },
    { text = "Top, under the title", value = "TOP" },
    { text = "Left column", value = "LEFT" },
    { text = "Right column", value = "RIGHT" },
}

-- Screen edge: Blizzard keeps the whole minimap cluster (its selection box, with a lot of empty
-- space around the square minimap) on screen. "MAP" keeps only what you see on screen, so the map
-- can sit snug against the edge; "FREE" lets it go anywhere, even off screen (Edit Mode's "Reset
-- To Default Position" brings it back).
local EDGE_CHOICES = {
    { text = "Keep the whole frame on screen", value = "BLIZZARD" },
    { text = "Keep only the visible map on screen", value = "MAP" },
    { text = "Free, it can leave the screen", value = "FREE" },
}

local applyingEdge = false

local function ApplyMinimapEdge()
    local cluster = MinimapCluster
    if not cluster or applyingEdge then return end
    applyingEdge = true
    local mode = BOLT:GetConfig("screenEdges", "minimapEdge") or "MAP"
    cluster:SetClampedToScreen(mode ~= "FREE")
    if mode == "MAP" and cluster:GetLeft() then
        local l, r, t, b = BOLT.MinimapBounds(cluster)
        if l then
            cluster:SetClampRectInsets(l - cluster:GetLeft(), r - cluster:GetRight(),
                t - cluster:GetTop(), b - cluster:GetBottom())
        end
    elseif cluster.UpdateClampOffsets then
        cluster:UpdateClampOffsets() -- Blizzard's own insets back
    end
    applyingEdge = false
end
EditModeOptions.ApplyMinimapEdge = ApplyMinimapEdge

-- Blizzard resets the insets when it lays the cluster out; the map's chrome can change size.
local function HookMinimapEdge()
    local cluster = MinimapCluster
    if not cluster then return end
    if cluster.UpdateClampOffsets then
        hooksecurefunc(cluster, "UpdateClampOffsets", ApplyMinimapEdge)
    end
    cluster:HookScript("OnSizeChanged", ApplyMinimapEdge)
    if Minimap then Minimap:HookScript("OnSizeChanged", ApplyMinimapEdge) end
    local later = function() C_Timer.After(0, ApplyMinimapEdge) end
    EditMode.lib:RegisterCallback("enter", later)
    EditMode.lib:RegisterCallback("exit", later)
    EditMode.lib:RegisterCallback("layout", later)
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function() C_Timer.After(1, ApplyMinimapEdge) end)
end

-- What the clamp is doing right now, for /bolt edge.
function EditModeOptions:DescribeMinimapEdge()
    local cluster = MinimapCluster
    if not cluster then return "no MinimapCluster on this client" end
    local l, r, t, b = cluster:GetClampRectInsets()
    return ("mode %s, clamped to screen: %s, clamp insets L %.0f R %.0f T %.0f B %.0f, size %.0f x %.0f"):format(
        tostring(BOLT:GetConfig("screenEdges", "minimapEdge") or "MAP"), tostring(cluster:IsClampedToScreen()),
        l or 0, r or 0, t or 0, b or 0, cluster:GetWidth() or 0, cluster:GetHeight() or 0)
end

local function RegisterMinimap()
    -- First in the block so it's easy to find.
    local settings = {
        EditMode:Dropdown("Screen edge", { "screenEdges", "minimapEdge" }, EDGE_CHOICES, {
            desc = "How far you can drag the minimap. Only the visible map (the default) lets the empty space around it go past the screen edge, so the map sits snug in the corner. Free lets it leave the screen entirely.",
            set = function(value)
                BOLT:SetConfig(value, "screenEdges", "minimapEdge")
                ApplyMinimapEdge()
            end,
        }),
    }
    if BOLT.modules.minimap then
        table.insert(settings, ModuleToggle("minimap", "Square minimap",
            "A square minimap in Blizzard's own art, with the zone name and clock in a title bar and the buttons in one bar. Turning it off takes a /reload."))
        table.insert(settings, EditMode:Dropdown("Its buttons", { "minimap", "buttons" }, BUTTON_SIDES, {
            hidden = Off("minimap"),
            set = function(value)
                BOLT:SetSetting({ "minimap", "buttons" }, value)
                C_Timer.After(0, ApplyMinimapEdge)
            end,
        }))
        table.insert(settings, EditMode:Checkbox("Zoom with the mouse wheel", { "minimap", "wheelZoom" }, {
            desc = "Hides the +/- buttons; zooms back out after 20 seconds.",
            hidden = Off("minimap"),
        }))
    end
    if BOLT.modules.autoHide then
        for _, setting in ipairs(Fade("minimapButtons", "Its buttons fade with", false)) do
            table.insert(settings, setting)
        end
        for _, setting in ipairs(Fade("minimap", "The map fades with")) do
            table.insert(settings, setting)
        end
    end
    EditMode:AddSystemSettings("Minimap", nil, nil, settings)
    HookMinimapEdge()
end

---------------------------------------------------------------------------
-- Unit frames and cast bars: flat style; party frames
---------------------------------------------------------------------------

local FLAT_DESC = "Blizzard's own art without the round portrait: the frame stretches over the portrait's space and the bars widen. Turning it off takes a /reload."

local function Flat(key, label)
    if not BOLT.modules.unitFrames then return nil end
    return FramePart("unitFrames", key, label or "Flat style (no round portrait)", FLAT_DESC)
end

local function RegisterUnitFrames()
    local indices = "EditModeUnitFrameSystemIndices"
    -- Player and Target already have a B.O.L.T block (FrameVisibility): no second header.
    EditMode:AddSystemSettings("UnitFrame", indices, "Player", List(Flat("player")), true)
    EditMode:AddSystemSettings("UnitFrame", indices, "Target", List(
        Flat("target", "Flat style for target and focus"),
        Flat("targetOfTarget", "Flat style for target of target")
    ), true)
    EditMode:AddSystemSettings("UnitFrame", indices, "Focus", List(
        Flat("target", "Flat style for target and focus"),
        unpack(Fade("focusFrame"))
    ))
    EditMode:AddSystemSettings("UnitFrame", indices, "Pet", List(
        Flat("pet"),
        unpack(Fade("petFrame"))
    ))
    EditMode:AddSystemSettings("UnitFrame", indices, "Party", List(
        Flat("party"),
        ModuleToggle("partyFramesCenterGrowth", "Keep raid-style party frames centered",
            "They stay centered as members join or leave. Needs Raid-Style Party Frames above."),
        unpack(Fade("partyFrames"))
    ))
    if BOLT.modules.unitFrames then
        EditMode:AddSystemSettings("CastBar", nil, nil, {
            FramePart("unitFrames", "castBars", "Spell name on the bar",
                "Blizzard's own art with the spell name inside the bar instead of a label strip underneath. Turning it off takes a /reload."),
        })
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function EditModeOptions:OnInitialize()
    if not EditMode.available then return end
    RegisterAutoHide()
    RegisterMinimap()
    RegisterUnitFrames()
end

-- Turning a multi-frame module on from the settings page with nothing picked would do nothing:
-- start from the defaults then.
function EditModeOptions:EnsureSomethingOn(module)
    local autoHide = BOLT.modules.autoHide
    if module == "autoHide" and autoHide then
        if autoHide.HasMembers() then return end
        local defaults = BOLT.defaults.profile.autoHide.members
        for key, id in pairs(defaults) do BOLT:SetConfig(id, "autoHide", "members", key) end
        return
    end
    local keys = GROUP_KEYS[module]
    if not keys then return end
    for _, key in ipairs(keys) do
        if BOLT:GetConfig(module, key) then return end
    end
    local defaults = BOLT.defaults.profile[module]
    for _, key in ipairs(keys) do
        BOLT:SetConfig(defaults[key] and true or false, module, key)
    end
end

BOLT:RegisterModule("editModeOptions", EditModeOptions)
