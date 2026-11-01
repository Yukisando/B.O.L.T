-- B.O.L.T Character Snapshot Module
-- Builds a JSON "time capsule" of the current character (account-wide stats,
-- collections, money, time played, achievements, etc.) and shows it in a
-- read-only popup so the player can copy it into a website / spreadsheet.

local ADDON_NAME, BOLT = ...

local CharacterSnapshot = {
    displayName = "Character Snapshot",
    alwaysOn = true,
}

---------------------------------------------------------------------------
-- JSON encoder (small, table -> pretty-printed JSON string)
---------------------------------------------------------------------------
local function escapeString(s)
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    -- strip control characters that aren't valid in JSON strings
    s = s:gsub("[%z\1-\8\11\12\14-\31]", "")
    return s
end

local encodeValue
local function encodeTable(tbl, indent)
    local nextIndent = indent .. "    "
    local count = 0
    local isArray = true
    for k in pairs(tbl) do
        count = count + 1
        if type(k) ~= "number" then isArray = false end
    end
    if isArray and count > 0 then
        for i = 1, count do
            if tbl[i] == nil then isArray = false break end
        end
    end
    if count == 0 then
        return isArray and "[]" or "{}"
    end

    local parts = {}
    if isArray then
        for i = 1, count do
            parts[#parts + 1] = nextIndent .. encodeValue(tbl[i], nextIndent)
        end
        return "[\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "]"
    else
        local keys = {}
        for k in pairs(tbl) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            parts[#parts + 1] = nextIndent .. '"' .. escapeString(tostring(k)) .. '": ' .. encodeValue(tbl[k], nextIndent)
        end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
    end
end

encodeValue = function(v, indent)
    local t = type(v)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return v and "true" or "false"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then
            return "null"
        end
        return tostring(v)
    elseif t == "string" then
        return '"' .. escapeString(v) .. '"'
    elseif t == "table" then
        return encodeTable(v, indent or "")
    end
    return "null"
end

local function ToJSON(tbl)
    return encodeValue(tbl, "")
end

---------------------------------------------------------------------------
-- Module lifecycle
---------------------------------------------------------------------------
function CharacterSnapshot:OnInitialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TIME_PLAYED_MSG")
    frame:SetScript("OnEvent", function(_, _, total, level)
        self.timePlayedTotal = total
        self.timePlayedLevel = level
        if self.popup and self.popup:IsShown() then
            self:RefreshSnapshotText()
        end
    end)
end

---------------------------------------------------------------------------
-- Data gathering
---------------------------------------------------------------------------
local function CountMounts()
    local total, owned = 0, 0
    if C_MountJournal and C_MountJournal.GetMountIDs then
        local ids = C_MountJournal.GetMountIDs()
        for _, id in ipairs(ids) do
            local info = { C_MountJournal.GetMountInfoByID(id) }
            -- Per Blizzard API: 11th return is isCollected
            total = total + 1
            if info[11] then owned = owned + 1 end
        end
    end
    return owned, total
end

local function CountPets()
    if C_PetJournal and C_PetJournal.GetNumPets then
        local total, owned = C_PetJournal.GetNumPets()
        return owned or 0, total or 0
    end
    return 0, 0
end

local function CountToys()
    local owned = 0
    if C_ToyBox and C_ToyBox.GetNumLearnedDisplayedToys then
        owned = C_ToyBox.GetNumLearnedDisplayedToys() or 0
    end
    return owned
end

local function GetAllStatistics()
    local stats = {}
    if not (GetStatisticsCategoryList and GetCategoryNumAchievements and GetAchievementInfo and GetStatistic) then
        return stats
    end
    local categories = GetStatisticsCategoryList()
    if type(categories) ~= "table" then return stats end
    for _, catID in ipairs(categories) do
        local catName
        if GetCategoryInfo then catName = GetCategoryInfo(catID) end
        catName = catName or ("Category " .. tostring(catID))
        local catBucket = stats[catName] or {}
        local numAch = GetCategoryNumAchievements(catID) or 0
        for i = 1, numAch do
            local id, achName = GetAchievementInfo(catID, i)
            if id and achName then
                local val = GetStatistic(id)
                if val and val ~= "" and val ~= "--" then
                    -- Try to coerce to number when the value is purely numeric
                    local stripped = val:gsub(",", "")
                    local num = tonumber(stripped)
                    catBucket[achName] = num or val
                end
            end
        end
        if next(catBucket) then
            stats[catName] = catBucket
        end
    end
    return stats
end

local function CopperToParts(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local cop = copper % 100
    return gold, silver, cop
end

function CharacterSnapshot:BuildSnapshot()
    local copper = GetMoney() or 0
    local gold, silver, cop = CopperToParts(copper)

    local className, classFile, classID = UnitClass("player")
    local raceName, raceFile, raceID = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local sex = UnitSex("player") -- 1 unknown, 2 male, 3 female
    local sexLabel = (sex == 2 and "male") or (sex == 3 and "female") or "unknown"
    local guild, guildRank = GetGuildInfo("player")

    local mountsOwned, mountsTotal = CountMounts()
    local petsOwned, petsTotal = CountPets()
    local toysOwned = CountToys()

    local achievementPoints = 0
    if GetTotalAchievementPoints then
        achievementPoints = GetTotalAchievementPoints() or 0
    end

    local snapshot = {
        schema = "bolt.character-snapshot.v1",
        capturedAt = time(),
        capturedAtIso = date("!%Y-%m-%dT%H:%M:%SZ"),
        addonVersion = (BOLT and BOLT.version) or "dev",
        character = {
            name = UnitName("player"),
            realm = GetRealmName(),
            normalizedRealm = (GetNormalizedRealmName and GetNormalizedRealmName()) or nil,
            level = UnitLevel("player"),
            class = className,
            classFile = classFile,
            classID = classID,
            race = raceName,
            raceFile = raceFile,
            raceID = raceID,
            faction = faction,
            sex = sexLabel,
            guild = guild,
            guildRank = guildRank,
        },
        money = {
            copper = copper,
            gold = gold,
            silver = silver,
            copperRemainder = cop,
            formatted = string.format("%dg %ds %dc", gold, silver, cop),
        },
        timePlayed = {
            totalSeconds = self.timePlayedTotal,
            levelSeconds = self.timePlayedLevel,
        },
        collections = {
            mountsCollected = mountsOwned,
            mountsTotal = mountsTotal,
            petsCollected = petsOwned,
            petsTotal = petsTotal,
            toysCollected = toysOwned,
        },
        achievements = {
            points = achievementPoints,
        },
        statistics = GetAllStatistics(),
    }

    return snapshot
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
function CharacterSnapshot:RefreshSnapshotText()
    local popup = self.popup
    if not popup then return end

    local snapshot = self:BuildSnapshot()
    popup.json = ToJSON(snapshot)
    popup.editBox:SetText(popup.json)
    popup.editBox:HighlightText()

    local categories = 0
    for _ in pairs(snapshot.statistics) do categories = categories + 1 end
    if snapshot.timePlayed.totalSeconds then
        popup.statusText:SetText(("Snapshot ready - %d stat categories, total /played: %dh."):format(
            categories, math.floor(snapshot.timePlayed.totalSeconds / 3600)))
    else
        popup.statusText:SetText(("|cffffd200Waiting for /played data...|r  (%d stat categories)"):format(categories))
    end
end

function CharacterSnapshot:CreatePopup()
    local popup = BOLT:CreateDialog("BOLTCharacterSnapshotPopup", 560, 420, "Character Snapshot (JSON)")

    local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", popup.title, "BOTTOM", 0, -4)
    hint:SetText("Press Ctrl+C to copy. Ctrl+A re-selects all.")

    local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 16, -60)
    scroll:SetPoint("BOTTOMRIGHT", -32, 56)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(500)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
    -- Read-only: revert anything the user types.
    editBox:SetScript("OnTextChanged", function(box, userInput)
        if userInput and popup.json then
            box:SetText(popup.json)
            box:HighlightText()
        end
    end)
    scroll:SetScrollChild(editBox)
    popup.editBox = editBox

    popup.statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    popup.statusText:SetPoint("BOTTOMLEFT", 18, 22)
    popup.statusText:SetJustifyH("LEFT")

    local closeButton = BOLT:CreateButton(popup, "Close", 90, 22, function() popup:Hide() end)
    closeButton:SetPoint("BOTTOMRIGHT", -16, 18)

    local refreshButton = BOLT:CreateButton(popup, "Refresh", 90, 22, function()
        self:RequestPlayed()
        self:RefreshSnapshotText()
    end)
    refreshButton:SetPoint("RIGHT", closeButton, "LEFT", -6, 0)

    self.popup = popup
end

-- Replacing Blizzard's /played chat printer to hide this message would taint the
-- chat frame's event handler, so the line in chat is left alone.
function CharacterSnapshot:RequestPlayed()
    RequestTimePlayed()
end

function CharacterSnapshot:ShowExportPopup()
    if not self.popup then
        self:CreatePopup()
    end
    if self.popup:IsShown() then
        self.popup:Hide()
        return
    end
    self:RequestPlayed()
    self:RefreshSnapshotText()
    self.popup:Show()
    self.popup.editBox:SetFocus()
end

BOLT:RegisterModule("characterSnapshot", CharacterSnapshot)
