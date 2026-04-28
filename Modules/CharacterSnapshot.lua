-- B.O.L.T Character Snapshot Module
-- Builds a JSON "time capsule" of the current character (account-wide stats,
-- collections, money, time played, achievements, etc.) and shows it in a
-- read-only popup so the player can copy it into a website / spreadsheet.

local ADDON_NAME, BOLT = ...

local CharacterSnapshot = {}
-- This module has no enable toggle and should always initialize so the
-- TIME_PLAYED_MSG listener is wired up before the popup is opened.
CharacterSnapshot.alwaysInitialize = true

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
    self.timePlayedTotal = nil
    self.timePlayedLevel = nil

    local f = CreateFrame("Frame")
    f:RegisterEvent("TIME_PLAYED_MSG")
    f:SetScript("OnEvent", function(_, event, total, level)
        if event == "TIME_PLAYED_MSG" then
            self.timePlayedTotal = total
            self.timePlayedLevel = level
            -- Suppress chat spam from our own requests
            if self._suppressChat and ChatFrame_DisplayTimePlayed then
                self._suppressChat = false
            end
            if self.popup and self.popup:IsShown() then
                self:RefreshSnapshotText()
            end
        end
    end)
    self.eventFrame = f
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
    if not self.popup or not self.popup.editBox then return end
    local snapshot = self:BuildSnapshot()
    local json = ToJSON(snapshot)
    self.popup.editBox:SetText(json)
    self.popup.editBox:HighlightText()

    if self.popup.statusText then
        if not snapshot.timePlayed.totalSeconds then
            self.popup.statusText:SetText("|cFFFFD200Waiting for /played data...|r")
        else
            local hours = math.floor((snapshot.timePlayed.totalSeconds or 0) / 3600)
            self.popup.statusText:SetText(string.format("Snapshot ready - %d categories, total /played: %dh.",
                (snapshot.statistics and (function() local n = 0; for _ in pairs(snapshot.statistics) do n = n + 1 end; return n end)()) or 0,
                hours))
        end
    end
end

function CharacterSnapshot:CreatePopup()
    local popup = CreateFrame("Frame", "BOLTCharacterSnapshotPopup", UIParent, "BackdropTemplate")
    popup:SetSize(560, 420)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    popup:SetFrameStrata("DIALOG")
    popup:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    popup:SetBackdropColor(0, 0, 0, 1)
    popup:EnableMouse(true)
    popup:SetMovable(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:Hide()

    local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", popup, "TOP", 0, -16)
    title:SetText("Character Snapshot (JSON)")

    local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -4)
    hint:SetText("Press Ctrl+C to copy. Ctrl+A re-selects all.")

    local closeBtn = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)

    -- Scrollable read-only EditBox
    local scroll = CreateFrame("ScrollFrame", "BOLTCharacterSnapshotScroll", popup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 16, -60)
    scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -32, 56)

    local editBox = CreateFrame("EditBox", "BOLTCharacterSnapshotEditBox", scroll)
    editBox:SetMultiLine(true)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(500)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function() popup:Hide() end)
    -- Block edits: revert to last known JSON if user types
    editBox:SetScript("OnTextChanged", function(eb, userInput)
        if userInput and popup._currentJson and eb:GetText() ~= popup._currentJson then
            eb:SetText(popup._currentJson)
            eb:HighlightText()
        end
    end)
    scroll:SetScrollChild(editBox)
    popup.editBox = editBox

    -- Override the basic Refresh wrapper so we can keep the JSON cached for the lock above
    local originalRefresh = self.RefreshSnapshotText
    self.RefreshSnapshotText = function(s)
        local snapshot = s:BuildSnapshot()
        local json = ToJSON(snapshot)
        popup._currentJson = json
        editBox:SetText(json)
        editBox:HighlightText()
        if popup.statusText then
            local categoryCount = 0
            if snapshot.statistics then
                for _ in pairs(snapshot.statistics) do categoryCount = categoryCount + 1 end
            end
            if not snapshot.timePlayed.totalSeconds then
                popup.statusText:SetText(string.format("|cFFFFD200Waiting for /played data...|r  (%d stat categories)", categoryCount))
            else
                local hours = math.floor((snapshot.timePlayed.totalSeconds or 0) / 3600)
                popup.statusText:SetText(string.format("Snapshot ready - %d stat categories, total /played: %dh.", categoryCount, hours))
            end
        end
    end

    -- Status line
    local statusText = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 18, 22)
    statusText:SetJustifyH("LEFT")
    popup.statusText = statusText

    -- Refresh button
    local refreshBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    refreshBtn:SetSize(90, 22)
    refreshBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -110, 18)
    refreshBtn:SetText("Refresh")
    refreshBtn:SetScript("OnClick", function()
        RequestTimePlayed()
        self:RefreshSnapshotText()
    end)

    -- Close button (text)
    local closeTextBtn = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    closeTextBtn:SetSize(90, 22)
    closeTextBtn:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -16, 18)
    closeTextBtn:SetText("Close")
    closeTextBtn:SetScript("OnClick", function() popup:Hide() end)

    if UISpecialFrames then
        tinsert(UISpecialFrames, "BOLTCharacterSnapshotPopup")
    end

    self.popup = popup
end

function CharacterSnapshot:ShowExportPopup()
    if not self.popup then
        self:CreatePopup()
    end
    if self.popup:IsShown() then
        self.popup:Hide()
        return
    end
    -- Request /played; the event handler will refresh the JSON when it arrives.
    RequestTimePlayed()
    self:RefreshSnapshotText()
    self.popup:Show()
    self.popup.editBox:SetFocus()
    self.popup.editBox:HighlightText()
end

BOLT:RegisterModule("characterSnapshot", CharacterSnapshot)
