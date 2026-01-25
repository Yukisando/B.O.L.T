-- B.O.L.T Teleports Module
-- Shows teleport sources on the main world map

local ADDON_NAME, BOLT = ...

local Teleports = {}
BOLT:RegisterModule("teleports", Teleports)

local DEFAULT_ICON = "Interface\\Icons\\INV_Misc_Rune_01"

local function SafeCall(fn, ...)
    local ok, res = pcall(fn, ...)
    if not ok then return nil end
    return res
end

function Teleports:OnInitialize()
    -- Nothing heavy on init; data comes from saved profile defaults
    self.pinPool = {}
    self.pinsShown = {}
end

-- Logging helper: always-visible messages via B.O.L.T, and debug prints when debug enabled
function Teleports:Log(msg, force)
    if not msg then return end
    if self.parent and type(self.parent.Print) == "function" then
        self.parent:Print("Teleports: " .. tostring(msg))
    elseif BOLT and BOLT.Print then
        BOLT:Print("Teleports: " .. tostring(msg))
    end
    if force and self.parent and type(self.parent.Debug) == "function" then
        self.parent:Debug(tostring(msg))
    end
end

function Teleports:CreateContainer()
    if self.container then return end
    local parent = nil
    -- Prefer the Map ScrollContainer (modern UI), fall back to WorldMapFrame canvas or the frame itself
    if WorldMapFrame and WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.GetCanvas then
        parent = WorldMapFrame.ScrollContainer:GetCanvas() -- anchor directly to the canvas for correct scaling and zoom behavior
    elseif WorldMapFrame and WorldMapFrame.GetCanvas then
        parent = WorldMapFrame:GetCanvas()
    elseif WorldMapFrame then
        parent = WorldMapFrame
    else
        parent = UIParent
    end

    local c = CreateFrame("Frame", "BOLTTeleportMapOverlay", parent)
    c:SetAllPoints(parent)
    c:SetFrameStrata("MEDIUM")
    c:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
    c:SetScale(1)
    c:Hide()
    self.container = c

    -- Hook parent size changes in case canvas is not initialized immediately
    if parent and type(parent.HookScript) == "function" then
        parent:HookScript("OnSizeChanged", function()
            C_Timer.After(0.01, function()
                if self and self.RefreshPins then
                    self:RefreshPins()
                end
            end)
        end)
    end

    -- Log parent info to help debug rendering issues
    local ok, pname, pw, ph = pcall(function() return parent:GetName(), parent:GetWidth(), parent:GetHeight() end)
    self:Log(
        "Container created on parent=" ..
        tostring(ok and pname or tostring(parent)) .. " size=" .. tostring(pw or "?") .. "x" .. tostring(ph or "?"), true)
end

local function AcquirePin(self)
    for _, p in ipairs(self.pinPool) do
        if not p._inUse then
            p._inUse = true
            p:Show()
            return p
        end
    end
    local btn = CreateFrame("Button", nil, self.container, "SecureActionButtonTemplate")
    btn:SetSize(22, 22)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetAllPoints(btn)
    btn.icon:SetTexCoord(0, 1, 0, 1)

    -- subtle border/background to improve visibility against map textures
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.bg:SetSize(22, 22)
    btn.bg:SetColorTexture(0, 0, 0, 0.6)

    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    btn._inUse = true
    table.insert(self.pinPool, btn)

    -- Ensure pin is visible above underlying map layers
    if self.container then
        btn:SetFrameLevel(self.container:GetFrameLevel() + 10)
    end

    -- Log creation to help diagnose whether pins are being spawned
    if self.parent and self.parent.Debug then
        self.parent:Debug("Teleports: created pin (pool size=" .. tostring(#self.pinPool) .. ")")
    end
    -- Also log unconditionally to aid users who don't enable debug
    self:Log("Created pin; pool size=" .. tostring(#self.pinPool))

    btn:SetScript("OnEnter", function(b)
        local entry = b._entry
        if not entry then return end
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        if entry.type == "item" and entry.id then
            if GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(entry.id)
            else
                local name = entry.name or (entry.id and GetItemInfo(entry.id)) or "Unknown"
                GameTooltip:SetText(name)
            end
        elseif entry.type == "spell" and entry.id then
            if GameTooltip.SetSpellByID then
                GameTooltip:SetSpellByID(entry.id)
            else
                GameTooltip:SetText(entry.name or "Spell")
            end
        else
            GameTooltip:SetText(entry.name or "Teleport")
            if entry.desc then GameTooltip:AddLine(entry.desc, 1, 1, 1) end
        end
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(b)
        local entry = b._entry
        if not entry then return end
        -- Try to open item/spell tooltip on click
        if entry.type == "item" and entry.id and ItemRefTooltip then
            if ItemRefTooltip.SetItemByID then ItemRefTooltip:SetItemByID(entry.id) end
            ItemRefTooltip:Show()
        elseif entry.type == "spell" and entry.id and ItemRefTooltip then
            if ItemRefTooltip.SetSpellByID then ItemRefTooltip:SetSpellByID(entry.id) end
            ItemRefTooltip:Show()
        end
    end)

    return btn
end

local function ReleaseAllPins(self)
    local count = 0
    for _, p in ipairs(self.pinPool) do
        if p._inUse then count = count + 1 end
        p._inUse = false
        p:Hide()
    end
    self.pinsShown = {}
    if self.parent and self.parent.Debug then
        self.parent:Debug("Teleports: released " .. tostring(count) .. " pins")
    end
end

local function CheckOwned(entry)
    if not entry then return false end
    if entry.type == "item" and entry.id then
        local count = GetItemCount(entry.id) or 0
        return count > 0
    elseif entry.type == "spell" and entry.id then
        if IsSpellKnown then
            return IsSpellKnown(entry.id)
        else
            -- Best effort: try GetSpellInfo
            local name = entry.spellName or entry.name
            return name and IsSpellKnown(name)
        end
    end
    return true
end

function Teleports:RefreshPins()
    if not self.container then self:CreateContainer() end
    if not self.container then return end

    self:Log("Refreshing pins...", true)
    ReleaseAllPins(self)

    local cfg = self.parent:GetConfig("teleports") or {}
    if not cfg or not cfg.showOnMap then
        self:Log("Skipping refresh: showOnMap disabled", true)
        return
    end

    -- Determine current map ID of the displayed world map
    local currentMapID = nil
    if WorldMapFrame and WorldMapFrame.GetMapID then
        currentMapID = SafeCall(WorldMapFrame.GetMapID, WorldMapFrame)
    end
    if not currentMapID and C_Map and C_Map.GetBestMapForUnit then
        currentMapID = C_Map.GetBestMapForUnit("player")
    end

    local list = cfg.teleportList or {}
    -- If saved list is empty, fall back to defaults so the module works out of the box
    if not next(list) then
        if self.parent and self.parent.defaults and self.parent.defaults.profile and self.parent.defaults.profile.teleports and self.parent.defaults.profile.teleports.teleportList then
            list = self.parent.defaults.profile.teleports.teleportList
            self:Log("No configured teleport entries found; using default list", true)
        else
            self:Log("No teleport entries configured and no defaults available", true)
            return
        end
    end

    -- Log all entries to aid debugging
    for i, entry in ipairs(list) do
        self:Log(
            string.format("Entry %d: %s (mapID=%s x=%s y=%s)", i, tostring(entry.name), tostring(entry.mapID),
                tostring(entry.x), tostring(entry.y)), true)
    end

    -- Determine canvas dimensions with robust fallbacks
    local canvas = self.container
    local w, h = canvas:GetWidth(), canvas:GetHeight()
    if (not w or w == 0) and canvas:GetParent() then w = canvas:GetParent():GetWidth() end
    if (not h or h == 0) and canvas:GetParent() then h = canvas:GetParent():GetHeight() end
    if not w or w == 0 then w = UIParent:GetWidth() or 1024 end
    if not h or h == 0 then h = UIParent:GetHeight() or 768 end

    self:Log(
        "mapID=" ..
        tostring(currentMapID) .. " canvasSize=" .. tostring(w) .. "x" .. tostring(h) .. " entries=" .. tostring(#list),
        true)

    -- If the container is hidden for any reason, show it while placing pins
    local wasHidden = not canvas:IsShown()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    elseif wasHidden and WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    end

    -- If debug mode is enabled, show a short-lived on-screen overlay in center of screen to verify rendering
    local debugOverlayShown = false
    if self.parent and self.parent.GetConfig and self.parent:GetConfig("debug") then
        if not self._debugOverlay then
            local d = CreateFrame("Frame", "BOLTTeleportDebugOverlay", UIParent)
            d:SetSize(120, 60)
            d:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
            d.tex = d:CreateTexture(nil, "OVERLAY")
            d.tex:SetAllPoints(d)
            d.tex:SetTexture("Interface\\Icons\\INV_Misc_FireRing")
            d.tex:SetDesaturated(false)
            d.label = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            d.label:SetPoint("TOP", d, "BOTTOM", 0, -4)
            d.label:SetText("B.O.L.T Teleports: DEBUG")
            self._debugOverlay = d
        end
        self._debugOverlay:Show()
        debugOverlayShown = true
        C_Timer.After(5, function() if self and self._debugOverlay then self._debugOverlay:Hide() end end)
    end

    -- If the canvas has zero size, schedule a few retries (sometimes the map canvas isn't ready instantly)
    self._refreshAttempts = (self._refreshAttempts or 0) + 1
    if (not w or w == 0 or not h or h == 0) and (self._refreshAttempts or 0) < 6 then
        self:Log("Canvas size is zero, scheduling retry " .. tostring(self._refreshAttempts), true)
        C_Timer.After(0.05, function()
            if self and self.RefreshPins then self:RefreshPins() end
        end)
        return
    end

    local placed = 0
    for _, entry in ipairs(list) do
        if self.parent and self.parent.Debug then
            self.parent:Debug(string.format("Checking entry: name='%s' mapID=%s x=%s y=%s", tostring(entry.name),
                tostring(entry.mapID), tostring(entry.x), tostring(entry.y)))
        end

        local debugBypass = false
        if self.parent and self.parent.GetConfig then
            debugBypass = self.parent:GetConfig("debug") or false
        end
        if debugBypass then
            self:Log("Debug bypass active: placing pins regardless of map match", true)
        end

        local showAny = cfg.showOnAnyMap or false
        if showAny then
            self:Log("Config 'showOnAnyMap' is enabled; placing pins regardless of map match", true)
        end

        local mapMatch = debugBypass or showAny or (not entry.mapID) or (currentMapID and entry.mapID == currentMapID)
        local owned = (not cfg.showOnlyOwned) or CheckOwned(entry)
        if self.parent and self.parent.Debug then
            self.parent:Debug("mapMatch=" .. tostring(mapMatch) .. " owned=" .. tostring(owned))
        end

        if entry and mapMatch then
            if owned then
                local p = AcquirePin(self)
                if not p then
                    self:Log("AcquirePin returned nil; aborting placement", true)
                    break
                end
                p._entry = entry
                local icon = entry.icon or DEFAULT_ICON
                p.icon:SetTexture(icon)

                -- Make the "Test Teleport" obvious and larger so it is easy to find
                if entry.name and entry.name:match("Test Teleport") then
                    p:SetSize(30, 30)
                    p.bg:SetSize(30, 30)
                    p.icon:SetTexture("Interface\\Icons\\INV_Misc_FireRing")
                else
                    p:SetSize(20, 20)
                    p.bg:SetSize(20, 20)
                end

                local px, py = nil, nil
                -- If we have a reasonable canvas size, compute pixel coords. Otherwise place in center to ensure visibility.
                if w and h and w > 0 and h > 0 then
                    px = (entry.x or 0.5) * w
                    -- Coordinates are normalized with origin at the bottom-left, so invert Y for TOPLEFT anchoring
                    py = (1 - (entry.y or 0.5)) * h
                else
                    -- fallback: place in center (visible) and mark for retry
                    px = (entry.x or 0.5) * (UIParent:GetWidth() or 1024)
                    py = (1 - (entry.y or 0.5)) * (UIParent:GetHeight() or 768)
                    self:Log(
                        "Using UIParent fallback positioning for pin '" ..
                        tostring(entry.name) .. "' because canvas size was zero", true)
                end

                p:ClearAllPoints()
                p:SetPoint("TOPLEFT", canvas, "TOPLEFT", px - (p:GetWidth() / 2), -py - (p:GetHeight() / 2))
                p:Show()
                placed = placed + 1
                -- Unconditional log to ensure visibility
                self:Log("Placed pin: " .. tostring(entry.name) .. " (px=" .. tostring(px) .. ")", true)
                if self.parent and self.parent.Debug then
                    self.parent:Debug("Placed pin: " ..
                        tostring(entry.name) ..
                        " at " .. tostring(entry.x) .. "," .. tostring(entry.y) .. " (px=" .. tostring(px) .. ")")
                end
            else
                self:Log("Skipping entry (not owned): " .. tostring(entry.name))
            end
        else
            self:Log("Skipping entry (map mismatch): " ..
                tostring(entry.name) .. " mapID=" .. tostring(entry.mapID) .. " currentMapID=" .. tostring(currentMapID))
        end
    end

    -- Ensure container visible while World Map is open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    end

    -- Keep container visible while the World Map is open; otherwise hide it
    if WorldMapFrame and WorldMapFrame:IsShown() then
        canvas:Show()
    else
        canvas:Hide()
    end

    -- Debug print in case nothing placed; helps user discover config issues
    if placed == 0 then
        self:Log(
            "No pins placed after refresh (mapID=" .. tostring(currentMapID) .. ", entries=" .. tostring(#list) .. ")",
            true)
        -- If nothing placed, spawn a temporary on-screen test pin once to verify rendering
        if not self._tempPinShown then
            self:ShowTempPin()
            self._tempPinShown = true
        end
    else
        self:Log("Pins placed: " .. tostring(placed), true)
    end
end

-- Create a temporary on-screen pin (independent of map) for debugging visibility
function Teleports:ShowTempPin()
    if self._tempPin then
        self._tempPin:Show()
        return
    end
    local f = CreateFrame("Frame", "BOLTTeleportTempPin", UIParent)
    f:SetSize(56, 56)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f.tex = f:CreateTexture(nil, "OVERLAY")
    f.tex:SetAllPoints(f)
    f.tex:SetTexture("Interface\\Icons\\INV_Misc_FireRing")
    f.tex:SetVertexColor(1, 0.6, 0)
    f.border = f:CreateTexture(nil, "BORDER")
    f.border:SetAllPoints(f)
    f.border:SetColorTexture(0, 0, 0, 0.7)
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.label:SetPoint("TOP", f, "BOTTOM", 0, -6)
    f.label:SetText("B.O.L.T Teleports: TEST PIN")
    f:Show()
    self._tempPin = f
    C_Timer.After(10, function()
        if f then f:Hide() end
    end)
    self:Log("Spawned temporary test pin on screen", true)
end

function Teleports:UpdateMapDisplay()
    -- Called by settings UI to refresh immediately
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshPins()
    end
end

function Teleports:OnEnable()
    if not self.parent:GetConfig("teleports", "enabled") then
        self:Log("Module disabled in config; not enabling")
        return
    end
    self:CreateContainer()
    self:Log("Module enabled; creating container and attaching events", true)

    -- Event-driven refresh (robust across UI versions)
    if not self.eventFrame then
        local ef = CreateFrame("Frame")
        ef:RegisterEvent("PLAYER_LOGIN")
        ef:RegisterEvent("PLAYER_ENTERING_WORLD")
        -- WORLD_MAP_UPDATE is not a valid event in some clients; remove to avoid spam
        ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        ef:RegisterEvent("BAG_UPDATE")
        ef:RegisterEvent("SPELLS_CHANGED")
        ef:RegisterEvent("TOYS_UPDATED")
        ef:SetScript("OnEvent", function(_, event, ...)
            -- Only refresh map pins when the main map is visible or on login
            if WorldMapFrame and WorldMapFrame:IsShown() then
                if self.container then self.container:Show() end
                self:RefreshPins()
            end
            if event == "PLAYER_LOGIN" then
                self:RefreshPins()
            end
        end)
        self.eventFrame = ef
    end

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            if self.container then self.container:Show() end
            self:RefreshPins()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            if self.container then self.container:Hide() end
            ReleaseAllPins(self)
        end)
    end

    -- Refresh now in case map is already open
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if self.container then self.container:Show() end
        self:RefreshPins()
    end
end

function Teleports:OnDisable()
    if self.container then self.container:Hide() end
    ReleaseAllPins(self)
    if self.eventFrame then
        self.eventFrame:UnregisterAllEvents()
        self.eventFrame:SetScript("OnEvent", nil)
        self.eventFrame = nil
    end
end

-- Small utility to dump internal state for debugging
function Teleports:Dump()
    local t = self
    if not t then return end
    local poolsize = t.pinPool and #t.pinPool or 0
    local cfg = (self.parent and self.parent.GetConfig) and self.parent:GetConfig("teleports") or {}
    self:Log(
        "Dump: enabled=" ..
        tostring((self.parent and self.parent:IsModuleEnabled("teleports"))) ..
        " showOnMap=" .. tostring(cfg.showOnMap) .. " pool=" .. tostring(poolsize), true)
    if self.container then
        self:Log(
            "Container shown=" ..
            tostring(self.container:IsShown()) ..
            " size=" .. tostring(self.container:GetWidth()) .. "x" .. tostring(self.container:GetHeight()), true)
    end
end

-- Clean up when player logs out/reloads
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent", function() Teleports:OnDisable() end)

return Teleports
