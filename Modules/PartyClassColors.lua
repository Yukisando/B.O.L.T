-- B.O.L.T Party Class Colors Module
-- Party members' names take their class colour (a warrior's name is brown, a mage's light blue),
-- on both Blizzard party frame styles: the classic party frames and the raid-style ones.
-- Runs after Blizzard writes the name (UnitFrame_Update, CompactUnitFrame_UpdateName), which it
-- does again on every name, roster or frame change, so the colour sticks. Turned off, names go
-- back to Blizzard's colour the next time it writes them.

local ADDON_NAME, BOLT = ...

local PartyClassColors = {
    displayName = "Party Class Colors",
}

local DEFAULT_NAME_COLOR = NORMAL_FONT_COLOR -- Blizzard's gold, for frames turned back off

local function ClassColor(unit)
    if not (unit and UnitExists(unit) and UnitIsPlayer(unit)) then return end
    local _, class = UnitClass(unit)
    if not class or BOLT.IsSecret(class) then return end
    local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
    if color then return color.r, color.g, color.b end
end

local function IsPartyUnit(unit)
    return type(unit) == "string" and not BOLT.IsSecret(unit)
        and (unit:match("^party%d$") or (unit == "player" and IsInGroup() and not IsInRaid()))
end

local function Paint(nameText, unit)
    if not (PartyClassColors.active and nameText and IsPartyUnit(unit)) then return end
    local r, g, b = ClassColor(unit)
    if r then nameText:SetTextColor(r, g, b) end
end

local hooked = false

local function Hook()
    if hooked then return end
    hooked = true
    -- Classic party frames (PartyMemberFrame): their name is self.name, their unit self.unit.
    if UnitFrame_Update then
        hooksecurefunc("UnitFrame_Update", function(frame)
            if frame and frame.unit and frame.unit ~= "player" then Paint(frame.name, frame.unit) end
        end)
    end
    -- Raid-style party frames.
    if CompactUnitFrame_UpdateName then
        hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
            if frame and frame.name then Paint(frame.name, frame.displayedUnit or frame.unit) end
        end)
    end
end

-- Repaints what's on screen now (or puts Blizzard's colour back when turned off).
local function RefreshAll()
    if PartyFrame and PartyFrame.PartyMemberFramePool then
        for member in PartyFrame.PartyMemberFramePool:EnumerateActive() do
            local nameText = member.name or member.Name
            if nameText then
                if PartyClassColors.active then
                    Paint(nameText, member.unit)
                else
                    nameText:SetTextColor(DEFAULT_NAME_COLOR:GetRGB())
                end
            end
        end
    end
    if CompactPartyFrame and CompactUnitFrame_UpdateName then
        for i = 1, MEMBERS_PER_RAID_GROUP or 5 do
            local frame = _G["CompactPartyFrameMember" .. i]
            if frame and frame.unit and frame.name then
                if not PartyClassColors.active then frame.name:SetTextColor(1, 1, 1) end
                CompactUnitFrame_UpdateName(frame)
            end
        end
    end
end

function PartyClassColors:OnEnable()
    Hook()
    RefreshAll()
end

function PartyClassColors:OnDisable()
    RefreshAll()
end

BOLT:RegisterModule("partyClassColors", PartyClassColors)
