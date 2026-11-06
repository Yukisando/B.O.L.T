-- B.O.L.T Minimap Module
-- A square minimap framed with Blizzard's own art (Forever's bronze c60 art on WoW: Forever):
--   title bar     zone name and clock, always above the map
--   button bar    tracking, calendar, mail, addon list, addon drawer... as one row or column on
--                 the side you pick (above the map pushes the title bar up)
--   in the map    coordinates bottom right, Forever's day/night dial top right, both half faded
--                 until the map is hovered
-- Addon buttons (LibDBIcon and the like) go into one drawer.
--
-- Blizzard re-anchors its minimap pieces on its own (Edit Mode, mail arriving, the landing page
-- changing), so every placed frame keeps a SetPoint hook that puts it back. None of these
-- frames are protected, so placing them also works in combat.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt

local SquareMinimap = {
    displayName = "Minimap",
}

local FOREVER = BOLT.isForever
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BAR = 24          -- bar thickness
local SLOT = 16         -- largest side of a button inside the button bar
local SPACING = 4       -- between buttons, and from a bar's ends
local GAP = 2           -- between the map frame and a bar, or two bars
local ZOOM_RESET = 20   -- seconds before a zoomed-in map zooms back out
local IDLE_ALPHA = 0.5  -- coordinates and day/night dial while the map isn't hovered
local DIEL_SCALE = 0.65 -- Forever's day/night dial, shrunk to sit in the map's corner
local DRAWER_COLUMNS = 6
local DRAWER_CELL = 34

-- Panels are one Blizzard atlas cut in nine (see NativeArt.CreateBox). `out` is how far the
-- map frame reaches outside the map, so the art's border line sits on the map's edge.
local BOX = FOREVER
    and { atlas = "ui-hud-minimap-header-button", corner = 7, midX = 76, midY = 11, out = 3 }
    or { atlas = "ui-hud-minimap-button", corner = 6, midX = 10, midY = 9, out = 4 }
-- Forever draws a bronze frame into each round button's art; this much of it is cropped away
-- so the icons sit plainly in the bar.
local BUTTON_FRAME_INSET = 4

local function Cfg(key)
    return BOLT:GetConfig("minimap", key)
end

local function Cluster(key)
    return MinimapCluster and MinimapCluster[key]
end

local titleBar, buttonBar, border, coords, rest, drawerButton, drawer
local placing = {}       -- [frame] = true while we move it ourselves
local placed = {}        -- [frame] = true for frames we keep in place
local hooked = {}
local hider = CreateFrame("Frame")
hider:Hide()
local layoutQueued = false

---------------------------------------------------------------------------
-- The button bar's contents, in order
---------------------------------------------------------------------------

local function IndicatorShown()
    local indicator = Cluster("IndicatorFrame")
    if not indicator then return false end
    for _, key in ipairs({ "MailFrame", "CraftingOrderFrame" }) do
        if indicator[key] and indicator[key]:IsShown() then return true end
    end
    return false
end

local BUTTONS = {
    { frame = function() return Cluster("Tracking") end },
    { frame = function() return GameTimeFrame end },
    { frame = function() return Cluster("IndicatorFrame") end, shown = IndicatorShown,
        watch = function()
            local indicator = Cluster("IndicatorFrame")
            return indicator and { indicator.MailFrame, indicator.CraftingOrderFrame } or {}
        end },
    { frame = function() return ExpansionLandingPageMinimapButton end },
    { frame = function() return Cluster("InstanceDifficulty") or MiniMapInstanceDifficulty end },
    { frame = function() return AddonCompartmentFrame end },
    { frame = function() return drawerButton end },
}

local function IsShown(item, frame)
    if item.shown then return item.shown() end
    return frame:IsShown()
end

-- A button's real size: Midnight's tracking frame is smaller than the button inside it.
local function Measure(frame)
    local width, height = frame:GetWidth(), frame:GetHeight()
    if frame.Button then
        width = math.max(width, frame.Button:GetWidth())
        height = math.max(height, frame.Button:GetHeight())
    end
    return width, height
end

---------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------

local RequestLayout

-- Move a Blizzard frame without our own SetPoint hook putting it straight back.
local function Place(frame, ...)
    placing[frame] = true
    frame:ClearAllPoints()
    frame:SetPoint(...)
    placing[frame] = nil
    placed[frame] = true
end

local function GetSlot(index)
    buttonBar.slots = buttonBar.slots or {}
    local slot = buttonBar.slots[index]
    if not slot then
        slot = CreateFrame("Frame", nil, buttonBar)
        buttonBar.slots[index] = slot
    end
    return slot
end

-- Lay a bar along one side of the map, or along the far side of `after` (another bar).
local function AnchorBar(bar, side, after)
    local out = BOX.out
    local relTo = after or Minimap
    local edge = after and 0 or out
    bar:ClearAllPoints()
    if side == "TOP" then
        bar:SetPoint("BOTTOMLEFT", relTo, "TOPLEFT", after and 0 or -out, edge + GAP)
        bar:SetPoint("BOTTOMRIGHT", relTo, "TOPRIGHT", after and 0 or out, edge + GAP)
        bar:SetHeight(BAR)
    elseif side == "BOTTOM" then
        bar:SetPoint("TOPLEFT", relTo, "BOTTOMLEFT", -out, -out - GAP)
        bar:SetPoint("TOPRIGHT", relTo, "BOTTOMRIGHT", out, -out - GAP)
        bar:SetHeight(BAR)
    elseif side == "LEFT" then
        bar:SetPoint("TOPRIGHT", relTo, "TOPLEFT", -out - GAP, out)
        bar:SetPoint("BOTTOMRIGHT", relTo, "BOTTOMLEFT", -out - GAP, -out)
        bar:SetWidth(BAR)
    else
        bar:SetPoint("TOPLEFT", relTo, "TOPRIGHT", out + GAP, out)
        bar:SetPoint("BOTTOMLEFT", relTo, "BOTTOMRIGHT", out + GAP, -out)
        bar:SetWidth(BAR)
    end
end

local function LayoutButtons()
    local side = Cfg("buttons") or "BOTTOM"
    local horizontal = side == "TOP" or side == "BOTTOM"
    AnchorBar(buttonBar, side)

    local offset, index = SPACING, 0
    local level = buttonBar:GetFrameLevel() + 2
    for _, item in ipairs(BUTTONS) do
        local frame = item.frame()
        if frame and IsShown(item, frame) then
            index = index + 1
            local width, height = Measure(frame)
            local scale = (width > 0 and height > 0) and math.min(1, SLOT / math.max(width, height)) or 1
            local length = (horizontal and width or height) * scale
            if length <= 0 then length = SLOT end

            local slot = GetSlot(index)
            slot:ClearAllPoints()
            if horizontal then
                slot:SetSize(length, BAR)
                slot:SetPoint("LEFT", buttonBar, "LEFT", offset, 0)
            else
                slot:SetSize(BAR, length)
                slot:SetPoint("TOP", buttonBar, "TOP", 0, -offset)
            end
            offset = offset + length + SPACING

            frame:SetScale(scale)
            if frame:GetFrameLevel() < level then frame:SetFrameLevel(level) end
            if frame.boltCover then frame.boltCover:SetFrameLevel(frame:GetFrameLevel() + 2) end
            Place(frame, "CENTER", slot, "CENTER", 0, 0)
        end
    end
    buttonBar:SetShown(index > 0)
end

local function LayoutTitle()
    local stacked = buttonBar:IsShown() and (Cfg("buttons") or "BOTTOM") == "TOP"
    AnchorBar(titleBar, "TOP", stacked and buttonBar or nil)
    local level = titleBar:GetFrameLevel() + 2

    local clock = TimeManagerClockButton
    if clock then
        clock:SetScale(1)
        if clock:GetFrameLevel() < level then clock:SetFrameLevel(level) end
        Place(clock, "RIGHT", titleBar, "RIGHT", -4, 0)
        local ticker = TimeManagerClockTicker
        if ticker then
            clock:SetWidth(math.max(30, ticker:GetStringWidth() + 8))
        end
    end

    local zone = Cluster("ZoneTextButton")
    if zone then
        if zone:GetFrameLevel() < level then zone:SetFrameLevel(level) end
        placing[zone] = true
        zone:ClearAllPoints()
        zone:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
        if clock and clock:IsShown() then
            zone:SetPoint("RIGHT", clock, "LEFT", -4, 0)
        else
            zone:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)
        end
        zone:SetHeight(BAR - 4)
        placing[zone] = nil
        placed[zone] = true
    end
end

-- Forever's day/night dial: Blizzard rescales it with Edit Mode, so we keep its scale relative.
local dielBaseScale
local function PlaceDiel()
    local diel = Cluster("DielFrame")
    if not diel then return end
    placing[diel] = true
    diel:SetScale((dielBaseScale or diel:GetScale()) * DIEL_SCALE)
    placing[diel] = nil
    diel:SetFrameLevel(border:GetFrameLevel() + 2)
    if rest then rest:SetFrameLevel(diel:GetFrameLevel() + 3) end
    Place(diel, "TOPRIGHT", Minimap, "TOPRIGHT", -6, -6)
end

local function Layout()
    layoutQueued = false
    if not (SquareMinimap.active and SquareMinimap.ready) then return end
    LayoutButtons()
    LayoutTitle()
    PlaceDiel()
end

function RequestLayout()
    if layoutQueued then return end
    layoutQueued = true
    C_Timer.After(0, Layout)
end

-- Put a frame back whenever Blizzard re-anchors it, and re-pack the bar as buttons come and go.
local function HookFrame(frame)
    if not frame or hooked[frame] then return end
    hooked[frame] = true
    hooksecurefunc(frame, "SetPoint", function(self)
        if placing[self] or not SquareMinimap.active then return end
        if placed[self] then RequestLayout() end
    end)
    frame:HookScript("OnShow", RequestLayout)
    frame:HookScript("OnHide", RequestLayout)
end

local function HookFrames()
    for _, item in ipairs(BUTTONS) do
        HookFrame(item.frame())
        for _, frame in ipairs(item.watch and item.watch() or {}) do
            if frame and not hooked[frame] then
                hooked[frame] = true
                frame:HookScript("OnShow", RequestLayout)
                frame:HookScript("OnHide", RequestLayout)
            end
        end
    end
    HookFrame(Cluster("ZoneTextButton"))
    HookFrame(TimeManagerClockButton)

    local diel = Cluster("DielFrame")
    if diel and not hooked[diel] then
        hooked[diel] = true
        dielBaseScale = diel:GetScale()
        hooksecurefunc(diel, "SetScale", function(self, scale)
            if placing[self] or not SquareMinimap.active then return end
            dielBaseScale = scale
            RequestLayout()
        end)
        hooksecurefunc(diel, "SetPoint", function(self)
            if not placing[self] and SquareMinimap.active then RequestLayout() end
        end)
    end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function CreatePanel(parent, fill)
    local frame = CreateFrame("Frame", nil, parent)
    if not NativeArt.CreateBox(frame, BOX, fill) then
        -- Atlas missing on this client: a plain dark panel.
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(WHITE)
        bg:SetVertexColor(0, 0, 0, fill == false and 0 or 0.6)
        bg:SetAllPoints()
    end
    return frame
end

local function BuildBars()
    for _, key in ipairs({ "titleBar", "buttonBar" }) do
        local bar = CreatePanel(MinimapCluster)
        bar:SetFrameStrata(MinimapCluster:GetFrameStrata())
        bar:SetFrameLevel(Minimap:GetFrameLevel() + 3)
        bar:Hide()
        if key == "titleBar" then titleBar = bar else buttonBar = bar end
    end
    buttonBar:SetScript("OnSizeChanged", RequestLayout)

    border = CreatePanel(Minimap, false)
    border:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -BOX.out, BOX.out)
    border:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", BOX.out, -BOX.out)
    border:SetFrameLevel(Minimap:GetFrameLevel() + 2)
end

-- Coordinates in the map's bottom-right corner, fading with the dial while the map isn't hovered.
local function BuildCoords()
    coords = CreateFrame("Frame", nil, Minimap)
    coords:SetSize(80, 14)
    coords:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", -9, 5)
    coords:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    local text = coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("RIGHT")
    text:SetJustifyH("RIGHT")

    local since = 1
    coords:SetScript("OnUpdate", function(self, elapsed)
        since = since + elapsed
        if since < 0.2 then return end
        since = 0

        local alpha = Minimap:IsMouseOver() and 1 or IDLE_ALPHA
        self:SetAlpha(alpha)
        local diel = Cluster("DielFrame")
        if diel then diel:SetAlpha(alpha) elseif rest then rest:SetAlpha(alpha) end

        -- No position inside instances; the map also hides it from addons in some places.
        local mapID = C_Map.GetBestMapForUnit("player")
        local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
        local x, y
        if position then x, y = position:GetXY() end
        if x and y and not BOLT.IsSecret(x) and not BOLT.IsSecret(y) and (x > 0 or y > 0) then
            text:SetFormattedText("%.1f, %.1f", x * 100, y * 100)
        else
            text:SetText("")
        end
    end)
end

-- The player frame's sleepy Zzz while resting, small and dim inside the day/night dial (or in
-- the map's top-right corner where there's no dial).
local function BuildRest()
    local atlas = NativeArt.ResolveAtlas("ui-hud-unitframe-player-rest-flipbook")
    if not atlas then return end
    local diel = Cluster("DielFrame")
    rest = CreateFrame("Frame", nil, diel or Minimap)
    if diel then
        rest:SetAllPoints(diel)
    else
        rest:SetSize(20, 20)
        rest:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -6, -6)
        rest:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    end

    local zzz = rest:CreateTexture(nil, "OVERLAY")
    zzz:SetAtlas(atlas)
    local size = diel and diel:GetWidth() * 0.6 or 20
    zzz:SetSize(size, size)
    zzz:SetPoint("CENTER", rest, "CENTER", 1, 1)
    zzz:SetAlpha(0.7)

    -- Same flipbook Blizzard plays on the player frame: 42 frames in 6 columns and 7 rows.
    local loop = zzz:CreateAnimationGroup()
    loop:SetLooping("REPEAT")
    local flipbook = loop:CreateAnimation("FlipBook")
    flipbook:SetFlipBookRows(7)
    flipbook:SetFlipBookColumns(6)
    flipbook:SetFlipBookFrames(42)
    flipbook:SetFlipBookFrameWidth(0)
    flipbook:SetFlipBookFrameHeight(0)
    flipbook:SetDuration(1.5)
    rest.loop = loop
    rest:Hide()
end

local function UpdateRest()
    if not rest then return end
    local resting = SquareMinimap.active and IsResting()
    rest:SetShown(resting)
    if resting then rest.loop:Play() else rest.loop:Stop() end
end

---------------------------------------------------------------------------
-- Addon button drawer
---------------------------------------------------------------------------

local collected = {}     -- ordered list of addon buttons in the drawer
local isCollected = {}

local function IsBlizzardChild(child)
    if child == Minimap.ZoomIn or child == Minimap.ZoomOut or child == MinimapBackdrop then
        return true
    end
    for _, item in ipairs(BUTTONS) do
        if child == item.frame() then return true end
    end
    return false
end

-- Map pins (HandyNotes, GatherMate, TomTom...) are named buttons on the minimap too, so only
-- LibDBIcon buttons and buttons that call themselves minimap buttons are taken, never pins.
local function IsAddonButton(child)
    if not child:IsObjectType("Button") or IsBlizzardChild(child) then return false end
    local name = child:GetName()
    if not name then return false end
    local lower = name:lower()
    if lower:find("pin", 1, true) then return false end
    if name:find("^LibDBIcon10_") then return true end
    return (lower:find("minimap", 1, true) or lower:find("button", 1, true)) and child:GetWidth() >= 20
end

local function LayoutDrawer()
    local shown = 0
    for _, button in ipairs(collected) do
        if button:IsShown() then
            local column, row = shown % DRAWER_COLUMNS, math.floor(shown / DRAWER_COLUMNS)
            placing[button] = true
            button:ClearAllPoints()
            button:SetPoint("CENTER", drawer, "TOPLEFT", 8 + DRAWER_CELL * (column + 0.5), -8 - DRAWER_CELL * (row + 0.5))
            placing[button] = nil
            shown = shown + 1
        end
    end
    local columns = math.max(1, math.min(shown, DRAWER_COLUMNS))
    local rows = math.max(1, math.ceil(shown / DRAWER_COLUMNS))
    drawer:SetSize(16 + columns * DRAWER_CELL, 16 + rows * DRAWER_CELL)
    drawerButton.count = shown
    if drawerButton:IsShown() ~= (shown > 0) then
        drawerButton:SetShown(shown > 0)
    end
    if shown == 0 then drawer:Hide() end
end

local function CollectButtons()
    if not drawer then return end
    local added = false
    for _, parent in ipairs({ Minimap, MinimapBackdrop }) do
        for _, child in ipairs({ parent:GetChildren() }) do
            if not isCollected[child] and IsAddonButton(child) then
                isCollected[child] = true
                table.insert(collected, child)
                child:SetParent(drawer)
                child:SetScript("OnDragStart", nil)
                child:SetScript("OnDragStop", nil)
                hooksecurefunc(child, "SetPoint", function(self)
                    if not placing[self] and SquareMinimap.active then C_Timer.After(0, LayoutDrawer) end
                end)
                child:HookScript("OnShow", function() C_Timer.After(0, LayoutDrawer) end)
                child:HookScript("OnHide", function() C_Timer.After(0, LayoutDrawer) end)
                added = true
            end
        end
    end
    if added then
        table.sort(collected, function(a, b) return a:GetName() < b:GetName() end)
    end
    LayoutDrawer()
end

-- Open toward the middle of the screen so the drawer never runs off its edge.
local function OpenDrawer()
    CollectButtons()
    local x, y = drawerButton:GetCenter()
    local width, height = UIParent:GetSize()
    local vertical = (y or 0) > height / 2 and "TOP" or "BOTTOM"
    local horizontal = (x or 0) > width / 2 and "RIGHT" or "LEFT"
    drawer:ClearAllPoints()
    drawer:SetPoint(vertical .. horizontal, drawerButton,
        (vertical == "TOP" and "BOTTOM" or "TOP") .. horizontal, 0, vertical == "TOP" and -4 or 4)
    drawer:Show()
end

local function BuildDrawer()
    drawer = CreatePanel(UIParent)
    drawer:SetFrameStrata("MEDIUM")
    drawer:SetClampedToScreen(true)
    drawer:EnableMouse(true)
    drawer:Hide()
    -- Close once the mouse has been away from both the drawer and its button for a moment.
    drawer:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() or drawerButton:IsMouseOver() then
            self.away = 0
        else
            self.away = (self.away or 0) + elapsed
            if self.away > 1.5 then self:Hide() end
        end
    end)
    drawer:SetScript("OnHide", function(self) self.away = 0 end)

    -- Blizzard's "more" dots; how many buttons are inside shows in the tooltip.
    drawerButton = CreateFrame("Button", "BOLTMinimapDrawerButton", MinimapCluster)
    drawerButton:SetSize(SLOT, SLOT)
    drawerButton.count = 0
    local dots = drawerButton:CreateTexture(nil, "ARTWORK")
    local dotsAtlas = NativeArt.ResolveAtlas("perks-threedots")
    if dotsAtlas then
        dots:SetAtlas(dotsAtlas)
        dots:SetSize(15, 5)
    else
        dots:SetTexture(WHITE)
        dots:SetSize(10, 2)
    end
    dots:SetPoint("CENTER")
    local glow = drawerButton:CreateTexture(nil, "HIGHLIGHT")
    glow:SetAllPoints(dots)
    if dotsAtlas then glow:SetAtlas(dotsAtlas) else glow:SetTexture(WHITE) end
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.6)

    drawerButton:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if drawer:IsShown() then drawer:Hide() else OpenDrawer() end
    end)
    drawerButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(("Addon buttons (%d)"):format(self.count), 1, 1, 1)
        GameTooltip:AddLine("Click to show the buttons addons put on the minimap.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    drawerButton:SetScript("OnLeave", GameTooltip_Hide)
    drawerButton:Hide()
end

---------------------------------------------------------------------------
-- The map itself
---------------------------------------------------------------------------

local function ApplyMask()
    if not SquareMinimap.active then return end
    placing[Minimap] = true
    Minimap:SetMaskTexture(WHITE)
    placing[Minimap] = nil
    -- Quest, task and dig-site areas are drawn as rings that assume a round map.
    for _, method in ipairs({ "SetArchBlobRingScalar", "SetArchBlobRingAlpha", "SetQuestBlobRingScalar",
        "SetQuestBlobRingAlpha", "SetTaskBlobRingScalar", "SetTaskBlobRingAlpha" }) do
        if Minimap[method] then Minimap[method](Minimap, 0) end
    end
    -- Some zones draw a separate texture-based minimap with its own round mask.
    local hybrid = HybridMinimap
    if hybrid and hybrid.CircleMask and hybrid.MapCanvas then
        hybrid.MapCanvas:SetUseMaskTexture(false)
        hybrid.CircleMask:SetTexture(WHITE)
        hybrid.MapCanvas:SetUseMaskTexture(true)
    end
end

local function OnMouseWheel(_, delta)
    local zoom = Minimap:GetZoom() + (delta > 0 and 1 or -1)
    Minimap:SetZoom(math.max(0, math.min(Minimap:GetZoomLevels() - 1, zoom)))
end

function SquareMinimap:ApplyZoom()
    local zoomButtons = { Minimap.ZoomIn, Minimap.ZoomOut, Minimap.ZoomHitArea }
    if Cfg("wheelZoom") then
        if self.blizzardWheel == nil then
            self.blizzardWheel = Minimap:GetScript("OnMouseWheel") or false
        end
        Minimap:EnableMouseWheel(true)
        Minimap:SetScript("OnMouseWheel", OnMouseWheel)
        for _, frame in pairs(zoomButtons) do frame:SetParent(hider) end
    else
        if self.blizzardWheel ~= nil then
            Minimap:SetScript("OnMouseWheel", self.blizzardWheel or nil)
            self.blizzardWheel = nil
        end
        for _, frame in pairs(zoomButtons) do frame:SetParent(Minimap) end
    end
end

local zoomTimer
local function OnZoomChanged(_, zoom)
    if zoomTimer then
        zoomTimer:Cancel()
        zoomTimer = nil
    end
    if SquareMinimap.active and Cfg("wheelZoom") and (zoom or 0) > 0 then
        zoomTimer = C_Timer.NewTimer(ZOOM_RESET, function()
            zoomTimer = nil
            Minimap:SetZoom(0)
        end)
    end
end

-- Crop the frame Forever draws into a button's own art, and keep it cropped when the art changes.
-- The crop works from the coordinates the texture is drawn with: the atlas name Blizzard set is
-- the retail one, whose coordinates point into a different sheet than the c60 art Forever shows.
local function CropFrame(texture)
    if not texture or hooked[texture] then return end
    hooked[texture] = true
    -- Blizzard re-sets the same atlas on every hover and press, which may leave our coordinates
    -- in place: the crop is worked out once per atlas and re-applied, never cropped again.
    local cropped
    local function Crop()
        local atlas = texture:GetAtlas()
        if not (cropped and cropped.atlas == atlas) then
            local width, height = texture:GetSize()
            if not width or width <= 0 or height <= 0 then return end
            local left, top, _, bottom, right = texture:GetTexCoord()
            local du = (right - left) * BUTTON_FRAME_INSET / width
            local dv = (bottom - top) * BUTTON_FRAME_INSET / height
            cropped = { atlas = atlas, left + du, right - du, top + dv, bottom - dv }
        end
        texture:SetTexCoord(cropped[1], cropped[2], cropped[3], cropped[4])
    end
    hooksecurefunc(texture, "SetAtlas", Crop)
    Crop()
end

-- Blizzard art that belongs to the round map or frames each button.
local function ConcealRoundArt()
    NativeArt.Conceal(MinimapCompassTexture)
    NativeArt.Conceal(MinimapCompassTextureUnderlay)
    local borderTop = Cluster("BorderTop")
    if borderTop then borderTop:SetParent(hider) end
    -- Blizzard's own coordinates; ours sit in the map's corner.
    local container = Cluster("MinimapContainer")
    if container and container.PlayerCoords then container.PlayerCoords:SetParent(hider) end

    -- On Forever the zone name sits on its own header art; our title bar replaces it.
    local zone = Cluster("ZoneTextButton")
    if zone then
        NativeArt.Conceal(zone.StateTexture)
        NativeArt.Conceal(zone.AddTexture)
        if MinimapZoneText then
            MinimapZoneText:ClearAllPoints()
            MinimapZoneText:SetPoint("LEFT", zone, "LEFT", 0, 0)
            MinimapZoneText:SetPoint("RIGHT", zone, "RIGHT", 0, 0)
            MinimapZoneText:SetJustifyH("LEFT")
        end
    end
    -- The clock's round plate; the time reads straight off the title bar.
    local clock = TimeManagerClockButton
    if clock then
        for _, region in ipairs({ clock:GetRegions() }) do
            if region:IsObjectType("Texture") and region ~= TimeManagerAlarmFiredTexture then
                NativeArt.Conceal(region)
            end
        end
    end

    -- The button bar is the frame now: no plate or frame around each button.
    local tracking = Cluster("Tracking")
    if tracking then
        NativeArt.Conceal(tracking.Background)
        if FOREVER and tracking.Button then
            CropFrame(tracking.Button.StateTexture)
            CropFrame(tracking.Button.AddTexture)
        end
    end
    if FOREVER and GameTimeFrame then
        CropFrame(GameTimeFrame.StateTexture)
        CropFrame(GameTimeFrame.AddTexture)
    end

    -- Blizzard's addon list shows a bare number: it becomes Blizzard's small settings cog. The
    -- cog lives on its own layer above the button, out of reach of Blizzard's state updates.
    local compartment = AddonCompartmentFrame
    local cog = NativeArt.ResolveAtlas("questlog-icon-setting")
    if compartment and cog and not compartment.boltCover then
        for _, region in ipairs({ compartment:GetRegions() }) do
            if region:IsObjectType("Texture") then NativeArt.Conceal(region) end
        end
        local text = compartment.Text or compartment:GetFontString()
        if text then
            text:SetAlpha(0)
            hooksecurefunc(text, "SetAlpha", function(self, alpha)
                if alpha and alpha > 0 then self:SetAlpha(0) end
            end)
        end
        compartment:SetSize(SLOT, SLOT) -- Forever's is 23px for its frame art, gone now

        local cover = CreateFrame("Frame", nil, compartment)
        cover:SetAllPoints()
        cover:SetFrameLevel(compartment:GetFrameLevel() + 2)
        local icon = cover:CreateTexture(nil, "OVERLAY")
        icon:SetAtlas(cog, true)
        icon:SetPoint("CENTER")
        compartment:HookScript("OnEnter", function() icon:SetVertexColor(1, 0.82, 0) end)
        compartment:HookScript("OnLeave", function() icon:SetVertexColor(1, 1, 1) end)
        compartment.boltCover = cover
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function SquareMinimap:GetChromeFrames()
    local frames = {}
    if titleBar then table.insert(frames, titleBar) end
    if buttonBar then table.insert(frames, buttonBar) end
    if drawerButton then table.insert(frames, drawerButton) end
    return frames
end

function SquareMinimap:Build()
    if self.built then return end
    self.built = true
    BuildBars()
    BuildCoords()
    BuildRest()
    BuildDrawer()

    hooksecurefunc(Minimap, "SetMaskTexture", function()
        if not placing[Minimap] then ApplyMask() end
    end)
    hooksecurefunc(Minimap, "SetZoom", OnZoomChanged)
    if MinimapCluster.SetHeaderUnderneath then
        hooksecurefunc(MinimapCluster, "SetHeaderUnderneath", RequestLayout)
    end
    if MinimapCluster.UpdateMinimapConfig then
        hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
            ApplyMask()
            RequestLayout()
        end)
    end
end

function SquareMinimap:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event, addon)
        if event == "ADDON_LOADED" then
            if addon == "Blizzard_HybridMinimap" then ApplyMask() end
            if addon == "Blizzard_TimeManager" then
                ConcealRoundArt()
                HookFrames()
                RequestLayout()
            end
        elseif event == "PLAYER_UPDATE_RESTING" then
            UpdateRest()
        elseif event == "PLAYER_ENTERING_WORLD" then
            UpdateRest()
            ApplyMask()
            CollectButtons()
            RequestLayout()
        end
    end)
end

function SquareMinimap:OnEnable()
    if not (Minimap and MinimapCluster and C_Texture and C_Texture.GetAtlasInfo) then return end
    for _, addon in ipairs({ "SexyMap", "BasicMinimap", "ElvUI" }) do
        if C_AddOns.IsAddOnLoaded(addon) then
            BOLT:Print(("Minimap is paused while %s is loaded (both restyle the minimap)."):format(addon))
            return
        end
    end
    self.ready = true
    self:Build()

    -- LibDBIcon and other button libraries read this to lay buttons out on a square.
    GetMinimapShape = function() return "SQUARE" end

    border:Show()
    coords:Show()
    titleBar:Show()
    ConcealRoundArt()
    ApplyMask()
    self:ApplyZoom()
    HookFrames()
    CollectButtons()
    Layout()

    self.eventFrame:RegisterEvent("ADDON_LOADED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_UPDATE_RESTING")
    UpdateRest()
    -- Addons create their buttons at different times after login.
    self.ticker = C_Timer.NewTicker(5, CollectButtons, 12)
end

function SquareMinimap:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    UpdateRest()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.ready then
        BOLT:Print("Minimap disabled. Type /reload to bring back the round minimap.")
    end
end

function SquareMinimap:OnSettingChanged(key)
    if not self.ready then return end
    if key == "wheelZoom" then
        self:ApplyZoom()
    else
        Layout()
    end
end

BOLT:RegisterModule("minimap", SquareMinimap)
