-- B.O.L.T Native Art (Brittle and Occasionally Lethal Tweaks)
-- Building blocks for restyling Blizzard's UI with Blizzard's own art, so BOLT's changes look
-- like they shipped with the game. Shared by every UI module.

local ADDON_NAME, BOLT = ...

local NativeArt = {}
BOLT.NativeArt = NativeArt

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CLAMP = "CLAMPTOBLACKADDITIVE"

-- WoW: Forever ships its own look as "<atlas>-c60" variants of the modern atlases.
function NativeArt.ResolveAtlas(name)
    if not (name and C_Texture and C_Texture.GetAtlasInfo) then return nil end
    if BOLT.isForever then
        local forever = name .. "-c60"
        if C_Texture.GetAtlasInfo(forever) then return forever end
    end
    if C_Texture.GetAtlasInfo(name) then return name end
    return nil
end

---------------------------------------------------------------------------
-- Sliced atlas: Blizzard art drawn at any width
---------------------------------------------------------------------------
-- One end cap is kept exactly as Blizzard drew it, the other end is the same cap mirrored,
-- and a one-pixel column of the middle is stretched between them. Height stays native, so
-- borders keep their thickness and nothing blurs.
--
--   spec = { atlas = "...", cap = { x0, x1 }, mid = x, native = "left" | "right" }
--   (pixel columns of the atlas; x1 exclusive)

local Slice = {}
Slice.__index = Slice

function NativeArt.CreateSlice(parent, layer, subLevel)
    local slice = setmetatable({ pieces = {} }, Slice)
    for i = 1, 3 do
        local texture = parent:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or 0)
        if texture.SetSnapToPixelGrid then
            texture:SetSnapToPixelGrid(false)
            texture:SetTexelSnappingBias(0)
        end
        slice.pieces[i] = texture
    end
    return slice
end

-- Returns false (and hides the art) when the atlas doesn't exist on this client.
function Slice:SetSpec(spec)
    local name = NativeArt.ResolveAtlas(spec.atlas)
    local info = name and C_Texture.GetAtlasInfo(name)
    if not info then
        self.ready = false
        self:SetShown(false)
        return false
    end

    local left, right, top, bottom = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    local function U(x) return left + (right - left) * x / info.width end

    self.ready = true
    self.height = info.height
    self.capWidth = spec.cap[2] - spec.cap[1]

    local capFrom, capTo = U(spec.cap[1]), U(spec.cap[2])
    local leftPiece, midPiece, rightPiece = self.pieces[1], self.pieces[2], self.pieces[3]
    for _, texture in ipairs(self.pieces) do
        texture:SetTexture(info.file)
    end
    if spec.native == "right" then
        rightPiece:SetTexCoord(capFrom, capTo, top, bottom)
        leftPiece:SetTexCoord(capTo, capFrom, top, bottom)
    else
        leftPiece:SetTexCoord(capFrom, capTo, top, bottom)
        rightPiece:SetTexCoord(capTo, capFrom, top, bottom)
    end
    -- Sample the middle of the pixel so linear filtering can't pull in its neighbours.
    midPiece:SetTexCoord(U(spec.mid + 0.25), U(spec.mid + 0.75), top, bottom)
    return true
end

-- Lay the art out `width` wide, its top-left at (x, y) from relTo's top-left.
function Slice:Place(relTo, x, y, width)
    self.relTo, self.x, self.y, self.width = relTo, x, y, width
    local leftPiece, midPiece, rightPiece = self.pieces[1], self.pieces[2], self.pieces[3]
    local capWidth, height = self.capWidth, self.height

    leftPiece:ClearAllPoints()
    leftPiece:SetSize(capWidth, height)
    leftPiece:SetPoint("TOPLEFT", relTo, "TOPLEFT", x, y)

    rightPiece:ClearAllPoints()
    rightPiece:SetSize(capWidth, height)
    rightPiece:SetPoint("TOPLEFT", relTo, "TOPLEFT", x + width - capWidth, y)

    midPiece:ClearAllPoints()
    midPiece:SetPoint("TOPLEFT", leftPiece, "TOPRIGHT")
    midPiece:SetPoint("BOTTOMRIGHT", rightPiece, "BOTTOMLEFT")
end

-- Anchor a region to a spot in the art, in art pixels from its top-left (y grows downward).
-- Anchors go to relTo (a Blizzard region) rather than our textures, so Blizzard's protected
-- frames never depend on BOLT regions.
function Slice:Anchor(region, point, artX, artY)
    region:SetPoint(point, self.relTo, "TOPLEFT", self.x + artX, self.y - artY)
end

-- Fit a region over a rectangle of the art: x0/y0 inclusive, x1/y1 exclusive.
function Slice:Fit(region, x0, y0, x1, y1)
    region:ClearAllPoints()
    self:Anchor(region, "TOPLEFT", x0, y0)
    self:Anchor(region, "BOTTOMRIGHT", x1, y1)
end

function Slice:SetShown(shown)
    for _, texture in ipairs(self.pieces) do
        texture:SetShown(shown and self.ready ~= false)
    end
end

function Slice:SetVertexColor(r, g, b, a)
    for _, texture in ipairs(self.pieces) do
        texture:SetVertexColor(r, g, b, a)
    end
end

function Slice:SetAlpha(alpha)
    for _, texture in ipairs(self.pieces) do
        texture:SetAlpha(alpha)
    end
end

function Slice:SetBlendMode(mode)
    for _, texture in ipairs(self.pieces) do
        texture:SetBlendMode(mode)
    end
end

---------------------------------------------------------------------------
-- Concealing Blizzard art
---------------------------------------------------------------------------
-- A mask that covers nothing makes a texture fully transparent. Blizzard keeps calling Show,
-- SetAtlas and SetAlpha on it as usual, so its logic (and anything mirrored from it) runs
-- untouched, but nothing is drawn.

local concealed = setmetatable({}, { __mode = "k" })

function NativeArt.Conceal(texture)
    if not texture or concealed[texture] or not texture.AddMaskTexture then return end
    local mask = texture:GetParent():CreateMaskTexture()
    mask:SetTexture(WHITE, CLAMP, CLAMP)
    mask:SetSize(1, 1)
    mask:SetPoint("TOPLEFT", texture:GetParent(), "TOPLEFT", -4096, 4096)
    texture:AddMaskTexture(mask)
    concealed[texture] = mask
end

function NativeArt.Reveal(texture)
    local mask = texture and concealed[texture]
    if mask then
        texture:RemoveMaskTexture(mask)
        concealed[texture] = nil
    end
end

-- Turn a Blizzard bar mask into a plain rectangle over `rect` = { x0, y0, x1, y1 } of `slice`.
function NativeArt.SetRectMask(mask, slice, rect)
    if not mask then return end
    mask:SetTexture(WHITE, CLAMP, CLAMP)
    slice:Fit(mask, rect[1], rect[2], rect[3], rect[4])
end

---------------------------------------------------------------------------
-- Mirroring Blizzard glows
---------------------------------------------------------------------------
-- Blizzard keeps driving its own glow texture (combat, threat, resting): we conceal it and
-- copy its visibility, colour and alpha onto our art drawn in its place.

local mirrored = setmetatable({}, { __mode = "k" })

function NativeArt.Mirror(source, slice)
    if not source or mirrored[source] then return end
    mirrored[source] = slice
    NativeArt.Conceal(source)
    slice:SetBlendMode(source:GetBlendMode())

    local function Sync()
        local target = mirrored[source]
        if not target then return end
        target:SetShown(source:IsShown())
        target:SetVertexColor(source:GetVertexColor())
        target:SetAlpha(source:GetAlpha())
    end
    for _, method in ipairs({ "Show", "Hide", "SetShown", "SetVertexColor", "SetAlpha" }) do
        hooksecurefunc(source, method, Sync)
    end
    Sync()
end
