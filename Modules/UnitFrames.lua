-- B.O.L.T Unit Frames Module (saved as "unitFrames")
-- Restyles Blizzard's game UI with Blizzard's own art, so it looks shipped with the game:
--   unit frames  portrait-less: the native box stretches over the portrait and the bars widen
--   cast bars    spell name on the bar, no label strip underneath
--
-- Blizzard's bars are protected and Blizzard re-anchors some of them on its own (every target
-- change, vehicles, party art swaps), sometimes in combat. So each frame is handled in two passes:
--   skin    art, masks, text and icons - plain regions, re-applied after every Blizzard update
--   layout  bar positions and sizes - protected, only out of combat (queued until combat ends)
-- and only anchors Blizzard never touches are used where its updates can happen in combat.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt

local UnitFrames = {
    displayName = "Unit Frames",
}

local FOREVER = BOLT.isForever

---------------------------------------------------------------------------
-- Blizzard frame art geometry (atlas pixels, measured from the game files)
---------------------------------------------------------------------------
-- cap / mid / native   how the box art is stretched (see NativeArt slices)
-- texW, texH           size of the portrait frame atlas Blizzard draws
-- left                 art column where the portrait-less box starts (frames whose portrait is on the left)
-- width                art width (target, whose portrait is on the right)
-- inset                border columns either side of the bars
-- edge                 column of the box's outer border line, counted from its outer side
-- top                  first row of the box's top border
-- name, health, mana   compartment rows (top inclusive, bottom exclusive)
-- healthH, manaH       height of Blizzard's bar fill art (kept native, masked to its compartment)
-- healthPad, manaPad   margin {left, top, right} of that fill art to hide - its transparent edge plus the
--                      darker bevel columns at its ends - so the fill runs flat right up to the borders

local ART
if FOREVER then
    ART = {
        player = { cap = { 182, 198 }, mid = 150, native = "right", texW = 198, texH = 71, left = 4,
            inset = 7, edge = 4, top = 11, name = { 16, 27 }, health = { 32, 45 }, mana = { 49, 56 }, healthH = 20, manaH = 10,
            healthPad = { 3, 4, 3 }, manaPad = { 3, 1, 3 } },
        target = { cap = { 0, 12 }, mid = 60, native = "left", texW = 194, texH = 68, width = 190,
            inset = 5, edge = 3, top = 7, name = { 13, 24 }, health = { 30, 42 }, mana = { 46, 53 }, healthH = 20, manaH = 10,
            healthPad = { 4, 4, 4 }, manaPad = { 8, 1, 7 } },
        small = { cap = { 100, 120 }, mid = 80, native = "right", texW = 120, texH = 49, left = 2,
            inset = 7, edge = 4, top = 3, name = { 8, 15 }, health = { 20, 27 }, mana = { 31, 35 }, healthH = 10, manaH = 7,
            healthPad = { 2, 1, 3 }, manaPad = { 4, 1, 4 } },
    }
else
    ART = {
        player = { cap = { 182, 198 }, mid = 150, native = "right", texW = 198, texH = 71, left = 4,
            inset = 7, edge = 5, top = 12, name = { 12, 23 }, health = { 27, 45 }, mana = { 48, 56 }, healthH = 20, manaH = 10,
            healthPad = { 0, 1, 0 }, manaPad = { 0, 1, 0 } },
        target = { cap = { 0, 12 }, mid = 60, native = "left", texW = 192, texH = 67, width = 188,
            inset = 4, edge = 2, top = 9, name = { 9, 21 }, health = { 24, 42 }, mana = { 45, 53 }, healthH = 20, manaH = 10,
            healthPad = { 0, 1, 3 }, manaPad = { 0, 1, 5 } },
        small = { cap = { 100, 120 }, mid = 80, native = "right", texW = 120, texH = 49, left = 2,
            inset = 7, edge = 5, top = 3, name = { 3, 15 }, health = { 18, 26 }, mana = { 29, 34 }, healthH = 10, manaH = 7,
            healthPad = { 0, 1, 0 }, manaPad = { 2, 1, 0 } },
    }
end

-- Glows Blizzard drives (combat, threat, resting), redrawn along the stretched box.
-- inset: columns from each art edge to the glow; dy: rows the glow sits above the art.
local GLOW
if FOREVER then
    GLOW = {
        playerCombat = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-InCombat", cap = { 182, 198 }, mid = 150, native = "right", inset = 0, dy = 0 },
        playerStatus = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Status", cap = { 182, 198 }, mid = 150, native = "right", inset = 0, dy = 0 },
        targetCombat = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-InCombat", cap = { 0, 12 }, mid = 60, native = "left", inset = 0, dy = 0 },
        partyCombat = { atlas = "UI-HUD-UnitFrame-Party-PortraitOn-InCombat", cap = { 94, 114 }, mid = 80, native = "right", inset = 6, dy = 1 },
        partyStatus = { atlas = "UI-HUD-UnitFrame-Party-PortraitOn-Status", cap = { 100, 120 }, mid = 80, native = "right", inset = 2, dy = 1 },
        petCombat = { atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-InCombat", cap = { 100, 120 }, mid = 80, native = "right", inset = -1, dy = 0 },
        petStatus = { atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Status", cap = { 100, 120 }, mid = 80, native = "right", inset = 0, dy = 1 },
    }
else
    GLOW = {
        playerCombat = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-InCombat", cap = { 176, 192 }, mid = 145, native = "right", inset = 4.5, dy = 1 },
        playerStatus = { atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Status", cap = { 180, 196 }, mid = 150, native = "right", inset = 2, dy = 0 },
        targetCombat = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-InCombat", cap = { 0, 12 }, mid = 60, native = "left", inset = 2, dy = 2 },
        partyCombat = { atlas = "UI-HUD-UnitFrame-Party-PortraitOn-InCombat", cap = { 94, 114 }, mid = 80, native = "right", inset = 6, dy = 0 },
        partyStatus = { atlas = "UI-HUD-UnitFrame-Party-PortraitOn-Status", cap = { 100, 120 }, mid = 80, native = "right", inset = 0, dy = 0 },
        petCombat = { atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-InCombat", cap = { 94, 114 }, mid = 80, native = "right", inset = 5, dy = 0 },
        petStatus = { atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Status", cap = { 100, 120 }, mid = 80, native = "right", inset = 0, dy = 1 },
    }
end

local MEDALLION_SIZE = 24  -- Blizzard's level circle, worn on the end of the box
-- Level numbers: Blizzard's smaller number font, slightly see-through, so they sit back.
local LEVEL_FONT = "GameFontHighlightSmall"
local LEVEL_ALPHA = 0.8
local DRAGON_SCALE = 0.84  -- elite/rare dragon scaled from portrait to box height
-- Blizzard hangs the player and target health bars this far above their container (Forever only).
local BAR_ABOVE_CONTAINER = FOREVER and 3 or 0

local skins = {}    -- [frame] = { art = slice }
local pending = {}  -- [frame] = layout function, run when combat ends
local hooked = {}

local function Cfg(key)
    return BOLT:GetConfig("unitFrames", key)
end

local function IsOn(key)
    return UnitFrames.active and UnitFrames.ready and Cfg(key)
end

-- Protected changes wait for the end of combat.
local function RunLayout(frame, layout)
    if InCombatLockdown() then
        pending[frame] = layout
        return
    end
    pending[frame] = nil
    layout(frame)
end

-- Post-hook a Blizzard global function (owner = its name) or a frame method, once.
local function Hook(owner, method, fn)
    if not owner then return end
    local key = tostring(owner) .. (method or "")
    if hooked[key] then return end
    if type(owner) == "string" then
        if not _G[owner] then return end
        hooksecurefunc(owner, fn)
    else
        if not owner[method] then return end
        hooksecurefunc(owner, method, fn)
    end
    hooked[key] = true
end

---------------------------------------------------------------------------
-- Shared pieces
---------------------------------------------------------------------------

local function BuildArt(parent, spec, atlas, relTo, x, y, width)
    local art = NativeArt.CreateSlice(parent, "BACKGROUND", 2)
    if not art:SetSpec({ atlas = atlas, cap = spec.cap, mid = spec.mid, native = spec.native }) then
        return nil
    end
    art:Place(relTo, x, y, width)
    art.spec = spec
    art:SetShown(true)
    return art
end

-- Draw a Blizzard glow along the stretched box, on the same layer Blizzard uses for it.
local function BuildGlow(spec, art, source)
    if not source then return end
    local layer, subLevel = source:GetDrawLayer()
    local glow = NativeArt.CreateSlice(source:GetParent(), layer, subLevel)
    if not glow:SetSpec(spec) then
        NativeArt.Conceal(source) -- better no glow than a portrait-shaped one
        return
    end
    glow:Place(art.relTo, art.x + spec.inset, art.y + spec.dy, art.width - 2 * spec.inset)
    NativeArt.Mirror(source, glow)
end

local function ConcealAll(...)
    for i = 1, select("#", ...) do
        NativeArt.Conceal((select(i, ...)))
    end
end

local function Middle(rows)
    return (rows[1] + rows[2]) / 2
end

-- A compartment's rectangle (what the player sees of a bar).
local function CompartmentRect(art, rows)
    local inset = art.spec.inset
    return { inset, rows[1], art.width - inset, rows[2] }
end

-- The bar itself: the compartment grown by the fill art's transparent margin, at native height.
local function BarRect(art, rows, barHeight, pad)
    local inset = art.spec.inset
    local top = rows[1] - pad[2]
    return { inset - pad[1], top, art.width - inset + pad[3], top + barHeight }
end

local function FitRect(art, region, rect)
    if region then
        art:Fit(region, rect[1], rect[2], rect[3], rect[4])
    end
end

local function SetMasks(art, healthMask, manaMask)
    local spec = art.spec
    NativeArt.SetRectMask(healthMask, art, CompartmentRect(art, spec.health))
    NativeArt.SetRectMask(manaMask, art, CompartmentRect(art, spec.mana))
end

local function PlaceName(art, fontString)
    if not fontString then return end
    local spec = art.spec
    fontString:ClearAllPoints()
    art:Anchor(fontString, "CENTER", art.width / 2, Middle(spec.name))
    fontString:SetWidth(art.width - 2 * spec.inset - (MEDALLION_SIZE + 8))
    fontString:SetJustifyH("CENTER")
end

-- Level: Blizzard's level circle worn on the end of the box, at name height. Clients without
-- the circle art get the number at the end of the name compartment instead.
local hasLevelCircle
local function PlaceLevel(art, circle, text, side)
    if not text then return end
    if hasLevelCircle == nil then
        hasLevelCircle = NativeArt.ResolveAtlas("UI-HUD-UnitFrame-SmallCircle") ~= nil
    end
    local spec = art.spec
    local y = Middle(spec.name)
    text:SetFontObject(LEVEL_FONT)
    text:SetAlpha(LEVEL_ALPHA)
    text:ClearAllPoints()
    if circle and hasLevelCircle then
        local x = side == "left" and spec.edge or (art.width - 1 - spec.edge)
        circle:ClearAllPoints()
        circle:SetSize(MEDALLION_SIZE, MEDALLION_SIZE)
        art:Anchor(circle, "CENTER", x, y)
        circle:Show()
        text:SetPoint("CENTER", circle, "CENTER", 0, -0.5)
    elseif side == "left" then
        art:Anchor(text, "LEFT", spec.inset + 4, y)
    else
        art:Anchor(text, "RIGHT", art.width - spec.inset - 4, y)
    end
end

local function PlaceAt(art, region, point, x, y)
    if not region then return end
    if InCombatLockdown() and region.IsProtected and region:IsProtected() then return end
    region:ClearAllPoints()
    art:Anchor(region, point or "CENTER", x, y)
end

---------------------------------------------------------------------------
-- Player
---------------------------------------------------------------------------

local function LayoutPlayer(frame)
    local skin = skins[frame]
    if not skin then return end
    local art, spec = skin.art, ART.player
    local container = PlayerFrame_GetHealthBarContainer()
    local healthBar = PlayerFrame_GetHealthBar()
    local healthRect = BarRect(art, spec.health, spec.healthH, spec.healthPad)

    -- The container carries Blizzard's health extras (temporary max health loss); the bar
    -- hangs off its top-left exactly as Blizzard hangs it, so Blizzard's re-anchoring agrees.
    container:ClearAllPoints()
    art:Anchor(container, "TOPLEFT", healthRect[1], healthRect[2] + BAR_ABOVE_CONTAINER)
    art:Anchor(container, "BOTTOMRIGHT", healthRect[3], healthRect[4])
    healthBar:ClearAllPoints()
    healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, BAR_ABOVE_CONTAINER)
    healthBar:SetSize(healthRect[3] - healthRect[1], healthRect[4] - healthRect[2])

    FitRect(art, PlayerFrame_GetManaBar(), BarRect(art, spec.mana, spec.manaH, spec.manaPad))
end

local function SkinPlayer()
    local frame = PlayerFrame
    if not (IsOn("player") and frame and frame.PlayerFrameContainer and PlayerFrame_GetHealthBarContainer) then return end
    local container = frame.PlayerFrameContainer
    local main = frame.PlayerFrameContent.PlayerFrameContentMain
    local contextual = frame.PlayerFrameContent.PlayerFrameContentContextual
    local spec = ART.player

    local skin = skins[frame]
    if not skin then
        local width, height = frame:GetSize()
        local x = (width - spec.texW) / 2 + spec.left
        local y = -(height - spec.texH) / 2
        local art = BuildArt(container, spec, "UI-HUD-UnitFrame-Player-PortraitOn", container, x, y, spec.texW - spec.left)
        if not art then return end
        skin = { art = art }
        skins[frame] = skin
        ConcealAll(container.PlayerPortrait, container.FrameTexture, container.AlternatePowerFrameTexture,
            container.VehicleFrameTexture, contextual.PlayerPortraitCornerIcon)
        BuildGlow(GLOW.playerCombat, art, container.FrameFlash)
        BuildGlow(GLOW.playerStatus, art, main.StatusTexture)
    end

    local art = skin.art
    local healthMid, nameMid = Middle(spec.health), Middle(spec.name)
    PlaceName(art, PlayerName)
    PlaceLevel(art, main.LevelBackgroundCircle, PlayerLevelText, "left")
    SetMasks(art, PlayerFrame_GetHealthBarContainer().HealthBarMask, PlayerFrame_GetManaBar().ManaBarMask)

    -- Icons that hung off the portrait move to the left end of the box.
    local medallionX = spec.edge
    PlaceAt(art, contextual.AttackIcon, "CENTER", medallionX, nameMid)
    PlaceAt(art, contextual.ReadyCheck, "CENTER", medallionX, nameMid)
    PlaceAt(art, contextual.PlayerRestLoop, "CENTER", medallionX + 14, spec.top - 6)
    PlaceAt(art, contextual.LeaderIcon, "CENTER", medallionX + 26, spec.top + 1)
    PlaceAt(art, contextual.GuideIcon, "CENTER", medallionX + 26, spec.top + 1)
    PlaceAt(art, contextual.PVPIcon, "CENTER", -10, healthMid)
    PlaceAt(art, main.PvpBackgroundIcon, "CENTER", -10, healthMid)
    PlaceAt(art, contextual.PrestigePortrait, "CENTER", -12, healthMid)
    if main.HitIndicator and main.HitIndicator.HitText then
        PlaceAt(art, main.HitIndicator.HitText, "CENTER", art.width / 2, healthMid)
    end

    RunLayout(frame, LayoutPlayer)
end

-- In combat Blizzard swaps the level number for crossed swords; ours share the medallion.
local function SyncPlayerAttackIcon()
    if not (IsOn("player") and skins[PlayerFrame]) then return end
    local icon = PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.AttackIcon
    PlayerLevelText:SetAlpha(icon:IsShown() and 0 or LEVEL_ALPHA)
end

local function HookPlayer()
    Hook("PlayerFrame_ToPlayerArt", nil, SkinPlayer)
    Hook("PlayerFrame_ToVehicleArt", nil, SkinPlayer)
    Hook("PlayerFrame_UpdateHealthBarVisuals", nil, SkinPlayer)
    Hook("PlayerFrame_UpdateManaBarVisuals", nil, SkinPlayer)
    Hook("PlayerFrame_UpdatePlayerNameTextAnchor", nil, SkinPlayer)
    Hook("PlayerFrame_UpdateStatus", nil, SyncPlayerAttackIcon)
end

---------------------------------------------------------------------------
-- Target and focus
---------------------------------------------------------------------------

local function LayoutTarget(frame)
    local skin = skins[frame]
    if not skin then return end
    local art, spec = skin.art, ART.target
    local main = frame.TargetFrameContent.TargetFrameContentMain
    local container = main.HealthBarsContainer
    local healthBar = container.HealthBar
    local healthRect = BarRect(art, spec.health, spec.healthH, spec.healthPad)

    -- Every target change Blizzard re-sets the container's bottom-right and re-hangs the bar
    -- from its top-left. Our top-left and the bar's width survive that, even in combat.
    container:ClearAllPoints()
    art:Anchor(container, "TOPLEFT", healthRect[1], healthRect[2] + BAR_ABOVE_CONTAINER)
    art:Anchor(container, "BOTTOMRIGHT", healthRect[3], healthRect[4])
    healthBar:ClearAllPoints()
    healthBar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, BAR_ABOVE_CONTAINER)
    healthBar:SetSize(healthRect[3] - healthRect[1], healthRect[4] - healthRect[2])

    FitRect(art, main.ManaBar, BarRect(art, spec.mana, spec.manaH, spec.manaPad))
end

-- Elite and rare dragons wrap the end of the box instead of the portrait.
local function PlaceDragon(art, dragon)
    if not (dragon and dragon:IsShown()) then return end
    local info = dragon:GetAtlas() and C_Texture.GetAtlasInfo(dragon:GetAtlas())
    if not info then return end
    local spec = art.spec
    dragon:SetSize(info.width * DRAGON_SCALE, info.height * DRAGON_SCALE)
    PlaceAt(art, dragon, "CENTER", art.width - 2, (spec.top + spec.mana[2] + 3) / 2)
end

local function SkinTarget(frame)
    if not (IsOn("target") and frame and frame.TargetFrameContainer) then return end
    local container = frame.TargetFrameContainer
    local main = frame.TargetFrameContent.TargetFrameContentMain
    local contextual = frame.TargetFrameContent.TargetFrameContentContextual
    local spec = ART.target

    local skin = skins[frame]
    if not skin then
        local width, height = frame:GetSize()
        local x = (width - spec.texW) / 2
        local y = -(height - spec.texH) / 2
        local art = BuildArt(container, spec, "UI-HUD-UnitFrame-Target-PortraitOn", container, x, y, spec.width)
        if not art then return end
        skin = { art = art }
        skins[frame] = skin
        ConcealAll(container.Portrait, container.FrameTexture)
        BuildGlow(GLOW.targetCombat, art, container.Flash)
    end

    local art = skin.art
    local healthMid, nameMid = Middle(spec.health), Middle(spec.name)
    PlaceName(art, main.Name)
    PlaceLevel(art, main.LevelBackgroundCircle, main.LevelText, "right")
    SetMasks(art, main.HealthBarsContainer.HealthBarMask, main.ManaBar.ManaBarMask)
    -- The reaction-colour strip behind the name goes (concealed, so the threat percentage that
    -- hangs off it keeps its place over the name compartment).
    FitRect(art, main.ReputationColor, CompartmentRect(art, spec.name))
    NativeArt.Conceal(main.ReputationColor)

    local medallionX = art.width - 1 - spec.edge
    PlaceDragon(art, container.BossPortraitFrameTexture)
    PlaceAt(art, contextual.BossIcon, "CENTER", medallionX - 22, nameMid)
    PlaceAt(art, contextual.QuestIcon, "CENTER", medallionX - 22, nameMid)
    PlaceAt(art, contextual.RaidTargetIcon, "CENTER", art.width / 2, spec.top - 8)
    PlaceAt(art, contextual.LeaderIcon, "CENTER", medallionX - 26, spec.top + 1)
    PlaceAt(art, contextual.GuideIcon, "CENTER", medallionX - 26, spec.top + 1)
    PlaceAt(art, contextual.PvpIcon, "CENTER", art.width + 10, healthMid)
    PlaceAt(art, contextual.PvpBackgroundIcon, "CENTER", art.width + 10, healthMid)
    PlaceAt(art, contextual.PrestigePortrait, "CENTER", art.width + 12, healthMid)
    PlaceAt(art, contextual.PetBattleIcon, "CENTER", art.width + 12, healthMid)

    RunLayout(frame, LayoutTarget)
end

local function HookTarget(frame)
    if not frame then return end
    local function Reskin() SkinTarget(frame) end
    Hook(frame, "CheckClassification", Reskin)
    Hook(frame, "UpdateHealthBarVisuals", Reskin)
    Hook(frame, "CheckLevel", Reskin)
end

---------------------------------------------------------------------------
-- Small frames: target of target, pet, party
---------------------------------------------------------------------------

local function LayoutSmall(frame)
    local skin = skins[frame]
    if not skin then return end
    local art, spec = skin.art, ART.small
    local healthRect = BarRect(art, spec.health, spec.healthH, spec.healthPad)
    FitRect(art, skin.healthContainer, healthRect)
    FitRect(art, skin.healthBar, healthRect)
    FitRect(art, skin.manaBar, BarRect(art, spec.mana, spec.manaH, spec.manaPad))
end

-- parts = { atlas, x, y, conceal = {...}, glows = {{spec, source}}, healthContainer, healthBar,
--           manaBar, healthMask, manaMask, name }
local function SkinSmall(frame, parts)
    local spec = ART.small
    local skin = skins[frame]
    if not skin then
        local art = BuildArt(frame, spec, parts.atlas, frame, parts.x + spec.left, parts.y, spec.texW - spec.left)
        if not art then return end
        skin = { art = art, healthContainer = parts.healthContainer, healthBar = parts.healthBar, manaBar = parts.manaBar }
        skins[frame] = skin
        for _, texture in pairs(parts.conceal) do
            NativeArt.Conceal(texture)
        end
        for _, glow in ipairs(parts.glows or {}) do
            BuildGlow(glow[1], art, glow[2])
        end
    end

    local art = skin.art
    PlaceName(art, parts.name)
    SetMasks(art, parts.healthMask, parts.manaMask)
    RunLayout(frame, LayoutSmall)
    return art
end

local function SkinTargetOfTarget(frame)
    if not (IsOn("targetOfTarget") and frame and frame.HealthBar) then return end
    local width, height = frame:GetSize()
    SkinSmall(frame, {
        atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
        x = (width - ART.small.texW) / 2, y = -(height - ART.small.texH) / 2,
        conceal = { frame.Portrait, frame.FrameTexture },
        healthBar = frame.HealthBar, manaBar = frame.ManaBar,
        healthMask = frame.HealthBar.HealthBarMask, manaMask = frame.ManaBar.ManaBarMask,
        name = frame.Name,
    })
end

local function SkinPet()
    local frame = PetFrame
    if not (IsOn("pet") and frame and PetFrameHealthBar) then return end
    local width, height = frame:GetSize()
    local art = SkinSmall(frame, {
        atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
        x = (width - ART.small.texW) / 2, y = -(height - ART.small.texH) / 2,
        conceal = { PetPortrait, PetFrameTexture },
        glows = { { GLOW.petCombat, PetFrameFlash }, { GLOW.petStatus, PetAttackModeTexture } },
        healthBar = PetFrameHealthBar, manaBar = PetFrameManaBar,
        healthMask = PetFrameHealthBarMask, manaMask = PetFrameManaBarMask,
        name = PetName,
    })
    if art and PetHitIndicator then
        PlaceAt(art, PetHitIndicator, "CENTER", art.width / 2, Middle(ART.small.health))
    end
end

local function SkinPartyMember(frame)
    if not (IsOn("party") and frame and frame.HealthBarContainer) then return end
    local overlay = frame.PartyMemberOverlay
    local spec = ART.small
    -- Blizzard draws the party frame art at (1, -2) from the frame's top-left.
    local art = SkinSmall(frame, {
        atlas = "UI-HUD-UnitFrame-Party-PortraitOn", x = 1, y = -2,
        conceal = { frame.Portrait, frame.Texture, frame.VehicleTexture },
        glows = { { GLOW.partyCombat, frame.Flash }, { GLOW.partyStatus, overlay and overlay.Status } },
        healthContainer = frame.HealthBarContainer, healthBar = frame.HealthBarContainer.HealthBar, manaBar = frame.ManaBar,
        healthMask = frame.HealthBarContainer.HealthBarMask, manaMask = frame.ManaBar.ManaBarMask,
        name = frame.Name,
    })
    if not art then return end
    if overlay then
        PlaceAt(art, overlay.LeaderIcon, "CENTER", spec.inset + 6, spec.top + 1)
        PlaceAt(art, overlay.GuideIcon, "CENTER", spec.inset + 6, spec.top + 1)
    end
    PlaceAt(art, frame.ReadyCheck, "CENTER", spec.inset + 8, Middle(spec.health))
end

local function HookPartyMember(frame)
    local function Reskin() SkinPartyMember(frame) end
    Hook(frame, "ToPlayerArt", Reskin)
    Hook(frame, "ToVehicleArt", Reskin)
    Hook(frame, "ToCharacterStyleArt", Reskin)
    Hook(frame, "UpdateNameTextAnchors", Reskin)
end

local function SkinParty()
    if not (PartyFrame and PartyFrame.PartyMemberFramePool) then return end
    for member in PartyFrame.PartyMemberFramePool:EnumerateActive() do
        HookPartyMember(member)
        SkinPartyMember(member)
    end
end

---------------------------------------------------------------------------
-- Cast bars
---------------------------------------------------------------------------
-- The spell name moves onto the bar itself and the label strip under the bar goes. Blizzard
-- re-lays the text out whenever a bar's look changes, so this follows SetLook.

local function SkinCastBar(bar)
    if not (IsOn("castBars") and bar and bar.Text) then return end
    if bar.TextBorder then
        NativeArt.Conceal(bar.TextBorder)
    end
    local text = bar.Text
    text:ClearAllPoints()
    text:SetPoint("LEFT", bar, "LEFT", 4, 0)
    text:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
end

local function CastBars()
    return { PlayerCastingBarFrame, PetCastingBarFrame,
        TargetFrame and TargetFrame.spellbar, FocusFrame and FocusFrame.spellbar }
end

local function SkinCastBars()
    for _, bar in pairs(CastBars()) do
        SkinCastBar(bar)
    end
end

local function HookCastBars()
    for _, bar in pairs(CastBars()) do
        Hook(bar, "SetLook", function() SkinCastBar(bar) end)
    end
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function UnitFrames:ApplyAll()
    SkinPlayer()
    SkinTarget(TargetFrame)
    SkinTarget(FocusFrame)
    SkinTargetOfTarget(TargetFrame and TargetFrame.totFrame)
    SkinTargetOfTarget(FocusFrame and FocusFrame.totFrame)
    SkinPet()
    SkinParty()
    SkinCastBars()
end

function UnitFrames:InstallHooks()
    HookPlayer()
    HookTarget(TargetFrame)
    HookTarget(FocusFrame)
    HookCastBars()
    Hook(PetFrame, "Update", SkinPet)
    if PartyFrame then
        Hook(PartyFrame, "InitializePartyMemberFrames", SkinParty)
        Hook(PartyFrame, "UpdatePartyFrames", SkinParty)
    end
end

function UnitFrames:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            for frame, layout in pairs(pending) do
                pending[frame] = nil
                layout(frame)
            end
        else
            self:ApplyAll()
        end
    end)
end

function UnitFrames:OnEnable()
    -- BetterBlizzFrames restyles the same frames; two addons moving the same bars fight.
    if C_AddOns.IsAddOnLoaded("BetterBlizzFrames") then
        self.ready = false
        BOLT:Print("Unit Frames is paused while BetterBlizzFrames is loaded (both restyle the same frames).")
        return
    end
    if not (C_Texture and C_Texture.GetAtlasInfo) then
        self.ready = false
        return
    end
    self.ready = true
    self:InstallHooks()
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:ApplyAll()
end

function UnitFrames:OnDisable()
    self.eventFrame:UnregisterAllEvents()
    wipe(pending)
    if next(skins) then
        BOLT:Print("Unit Frames disabled. Type /reload to bring back Blizzard's portraits.")
    end
end

function UnitFrames:OnSettingChanged(key)
    if Cfg(key) then
        self:ApplyAll()
    else
        BOLT:Print("Type /reload to bring back Blizzard's portraits on that frame.")
    end
end

BOLT:RegisterModule("unitFrames", UnitFrames)
