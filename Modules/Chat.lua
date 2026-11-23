-- B.O.L.T Chat Module
-- Blizzard's own chat window, made quiet: text on the screen and little else until you reach
-- for it.
--
--   * Clean window: the window's border art, the tab backgrounds and the scroll bar go; tabs
--     show only while the mouse is over the chat (a tab with new messages still shows), and a
--     soft dark background fades in on hover, in the minimap's bronze frame that runs around the
--     text and up around each tab.
--   * Text on hover only: the messages themselves show only while the mouse is over the chat
--     or you type (new messages pop up through ChatPopups instead).
--   * Chat buttons (menu, channels, voice, social) hidden. Emotes and languages are still typed.
--   * History: the last lines of each tab come back after a reload or login, a little dimmed.
--   * Copy chat: a tab's right-click menu (and the settings page) opens the tab's text as plain
--     text to select and copy.
-- The chat window can also join a fade group (Auto-hide UI, "Chat window"), and it stays shown
-- while you type. Sounds and popups for new messages are their own modules (ChatNotifier,
-- ChatPopups), grouped with this one on the settings page.
--
-- Everything is done from outside: hooks, masks over Blizzard's textures, and parking frames
-- on a hidden holder. No Blizzard global is written, so chat commands like /cast stay clean.
-- With Chattynator loaded the chat window is left alone; the history and copy still work on
-- Blizzard's frames.

local ADDON_NAME, BOLT = ...
local NativeArt = BOLT.NativeArt

local Chat = {
    displayName = "Chat",
    alwaysOn = true, -- every part is its own setting
}

local BORDERS = { "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
local TAB_ART = { "Left", "Middle", "Right" }
local EDIT_ART = { "Left", "Mid", "Right" }
local LOOSE_BUTTONS = { "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "TextToSpeechButtonFrame" }

-- The bronze frame the minimap and chat popups use (see NativeArt.CreateBox), drawn around the
-- text and the tabs while the chat shows. `out` puts the art's border line just outside the panel.
local BOX = BOLT.isForever
    and { atlas = "ui-hud-minimap-header-button", corner = 7, midX = 76, midY = 11, out = 3 }
    or { atlas = "ui-hud-minimap-button", corner = 6, midX = 10, midY = 9, out = 4 }
local LINE = BOX.out       -- where the art's line sits in each piece, from its outer side
local TAB_PAD_X = 10       -- tab outline, from the tab's text sideways
local TAB_PAD_Y = 5        -- and at least this much above it
local TAB_FILL = 0.6       -- the tab's dark background, darker than the panel so its label reads
local TAB_MIN_ALPHA = 0.9  -- unselected tab labels stay this visible while the chat shows

local HOVER_ALPHA = 0.35   -- the dark background under the text while the mouse is over it
local BG_FADE = 0.25       -- seconds
local HISTORY_LINES = 100  -- per tab
local HISTORY_DIM = 0.6    -- restored lines, color multiplier

local function Cfg(key) return BOLT:GetConfig("chat", key) end

local function IsSecret(value) return BOLT.IsSecret(value) end

function Chat:ChattynatorLoaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("Chattynator") and true or false
    end
    return IsAddOnLoaded and IsAddOnLoaded("Chattynator") and true or false
end

local function ChatFrames()
    local frames = {}
    if CHAT_FRAMES then
        for _, name in ipairs(CHAT_FRAMES) do
            if _G[name] then table.insert(frames, _G[name]) end
        end
    else
        for i = 1, NUM_CHAT_WINDOWS or 10 do
            if _G["ChatFrame" .. i] then table.insert(frames, _G["ChatFrame" .. i]) end
        end
    end
    return frames
end
Chat.ChatFrames = ChatFrames

local function IsCombatLogFrame(frame)
    if IsCombatLog then
        local ok, result = pcall(IsCombatLog, frame)
        if ok then return result end
    end
    return frame == ChatFrame2
end

-- The chat window whose text you're typing into, if any.
function Chat.IsTyping()
    local get = (ChatFrameUtil and ChatFrameUtil.GetActiveWindow) or ChatEdit_GetActiveWindow
    if get then
        local ok, editBox = pcall(get)
        if ok and editBox and editBox:HasFocus() then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- Parking frames out of sight
---------------------------------------------------------------------------

local holder = CreateFrame("Frame")
holder:Hide()
local parked = {} -- [frame] = original parent

local function Park(frame)
    if not frame or parked[frame] then return end
    if frame:IsProtected() and InCombatLockdown() then return end
    parked[frame] = frame:GetParent() or UIParent
    frame:SetParent(holder)
end

local function Unpark(frame)
    local parent = frame and parked[frame]
    if not parent then return end
    if frame:IsProtected() and InCombatLockdown() then return end
    frame:SetParent(parent)
    parked[frame] = nil
end

---------------------------------------------------------------------------
-- Clean window
---------------------------------------------------------------------------

local cleanOn, buttonsHidden = false, false
local styled = {}      -- [chatFrame] = our background texture
local frames = {}      -- [chatFrame] = our bronze frame around text and tabs
local tabHooked = {}
local tabAlpha = {}    -- [tab] = the alpha our fade gives it
local settingTab = false

local function Tab(chatFrame) return _G[chatFrame:GetName() .. "Tab"] end

-- Blizzard shows the tabs only once the mouse has stood still over the chat for a moment. Our
-- fade drives them instead, together with the background, so Blizzard's own alpha changes are
-- put back to ours.
local function OnTabAlpha(tab, alpha)
    if settingTab or not cleanOn then return end
    local mine = tabAlpha[tab]
    if not mine or math.abs(mine - alpha) < 0.001 then return end
    settingTab = true
    tab:SetAlpha(mine)
    settingTab = false
end

local function SetTabAlpha(tab, alpha)
    tabAlpha[tab] = alpha
    settingTab = true
    tab:SetAlpha(alpha)
    settingTab = false
end

-- How visible a tab is while the chat is hovered: the selected one fully, the others barely less,
-- so every label reads in its box.
local function TabShownAlpha(tab)
    if ChatFrameUtil and ChatFrameUtil.GetTabAlphas then
        local ok, over = pcall(ChatFrameUtil.GetTabAlphas, tab)
        if ok and type(over) == "number" then return math.max(over, TAB_MIN_ALPHA) end
    end
    return 1
end

-- The frame goes around the text area, and each tab gets the same frame on top of it, open at
-- the bottom. Where a tab's side meets the panel's top line, a corner piece of the same art
-- curves the line into it, and the top line is left out under the tab, so the outline runs as
-- one smooth piece from the panel up around each tab and back down.
local function TabsOf(chatFrame)
    local tabs = {}
    local docked = chatFrame.isDocked and GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES
    for _, frame in ipairs(docked or { chatFrame }) do
        local tab = Tab(frame)
        if tab and tab:IsShown() then table.insert(tabs, tab) end
    end
    return tabs
end

local function CopyPiece(owner, piece)
    local texture = owner:CreateTexture(nil, "BORDER")
    texture:SetTexture(piece:GetTexture())
    texture:SetTexCoord(piece:GetTexCoord())
    if texture.SetSnapToPixelGrid then
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
    end
    return texture
end

local function TabBox(panel, index)
    local box = panel.tabs[index]
    if box then return box end
    box = CreateFrame("Frame", nil, panel)
    box.pieces = NativeArt.CreateBox(box, BOX, false, "BORDER")
    -- No bottom edge: the tab opens into the panel.
    for i = 6, 8 do box.pieces[i]:Hide() end
    -- The curves from the panel's top line up into the tab's sides: a box's bottom-right corner
    -- (line from the left, turning up) on the left, its bottom-left corner on the right.
    box.curveLeft = CopyPiece(box, panel.pieces[8])
    box.curveRight = CopyPiece(box, panel.pieces[6])
    box.fill = box:CreateTexture(nil, "BACKGROUND")
    box.fill:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    box.fill:SetVertexColor(0, 0, 0, TAB_FILL)
    box.fill:SetPoint("TOPLEFT", BOX.corner / 2, -BOX.corner / 2)
    box.fill:SetPoint("BOTTOMRIGHT", -BOX.corner / 2, LINE)
    panel.tabs[index] = box
    return box
end

local function EdgeSegment(panel, index)
    local segment = panel.edges[index]
    if segment then return segment end
    segment = CopyPiece(panel, panel.pieces[2])
    panel.edges[index] = segment
    return segment
end

local function PlacePanel(chatFrame)
    local panel = frames[chatFrame]
    if not panel then return end
    local area = _G[chatFrame:GetName() .. "Background"] or chatFrame.Background or chatFrame
    local areaLeft, areaTop, areaWidth = area:GetLeft(), area:GetTop(), area:GetWidth()
    local c, out, d = BOX.corner, BOX.out, LINE
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", area, "TOPLEFT", -out, out)
    panel:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", out, -out)

    -- Below, in the area's coordinates: x from its left, y up from its top. `lineY` is the
    -- panel's top line; a tab's `x0`/`x1` are its side lines.
    local lineY = out - d
    local shapes = {}
    if areaLeft and areaTop and areaWidth then
        local tabs = TabsOf(chatFrame)
        table.sort(tabs, function(x, y) return (x:GetLeft() or 0) < (y:GetLeft() or 0) end)
        for _, tab in ipairs(tabs) do
            local text = tab.Text or _G[tab:GetName() .. "Text"]
            local left, right = text and text:GetLeft(), text and text:GetRight()
            local top, bottom = text and text:GetTop(), text and text:GetBottom()
            if left and right and top and bottom then
                table.insert(shapes, {
                    x0 = left - areaLeft - TAB_PAD_X, x1 = right - areaLeft + TAB_PAD_X,
                    top = top - areaTop, bottom = bottom - areaTop,
                })
            end
        end
        -- Room for the curves: away from the panel's own corners, and between neighbours.
        local minX = 2 * c - out - d
        local maxX = areaWidth + out - 2 * c + d
        local gap = 2 * (c - d)
        for i, shape in ipairs(shapes) do
            shape.x0 = math.max(shape.x0, minX)
            shape.x1 = math.min(shape.x1, maxX)
            local prev = shapes[i - 1]
            if prev and shape.x0 - prev.x1 < gap then
                local mid = (prev.x1 + shape.x0) / 2
                prev.x1, shape.x0 = mid - gap / 2, mid + gap / 2
            end
        end
    end

    local openings = {}
    for i, shape in ipairs(shapes) do
        local box = TabBox(panel, i)
        -- As much room above the label as below it, so it sits in the middle of its box.
        local pad = math.max(TAB_PAD_Y, shape.bottom - lineY)
        local boxBottom = lineY - d
        local boxTop = math.max(shape.top + pad, boxBottom + 2 * c)
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", area, "TOPLEFT", shape.x0 - d, boxTop)
        box:SetPoint("BOTTOMRIGHT", area, "TOPLEFT", shape.x1 + d, boxBottom)
        box.curveLeft:ClearAllPoints()
        box.curveLeft:SetPoint("TOPLEFT", area, "TOPLEFT", shape.x0 + d - c, boxBottom + c)
        box.curveLeft:SetPoint("BOTTOMRIGHT", area, "TOPLEFT", shape.x0 + d, boxBottom)
        box.curveRight:ClearAllPoints()
        box.curveRight:SetPoint("TOPLEFT", area, "TOPLEFT", shape.x1 - d, boxBottom + c)
        box.curveRight:SetPoint("BOTTOMRIGHT", area, "TOPLEFT", shape.x1 - d + c, boxBottom)
        box:Show()
        -- The gap this tab leaves in the panel's top line, from the panel's left side.
        table.insert(openings, { shape.x0 + d - c + out, shape.x1 - d + c + out })
    end
    for i = #shapes + 1, #panel.tabs do panel.tabs[i]:Hide() end

    -- The top edge, drawn in pieces between the openings.
    local width = panel:GetWidth() or 0
    local from, count = c, 0
    local function Segment(to)
        if to - from >= 0.5 then
            count = count + 1
            local segment = EdgeSegment(panel, count)
            segment:ClearAllPoints()
            segment:SetPoint("TOPLEFT", panel, "TOPLEFT", from, 0)
            segment:SetPoint("BOTTOMRIGHT", panel, "TOPLEFT", to, -c)
            segment:Show()
        end
    end
    for _, opening in ipairs(openings) do
        Segment(math.min(opening[1], width - c))
        from = math.max(from, opening[2])
    end
    Segment(width - c)
    for i = count + 1, #panel.edges do panel.edges[i]:Hide() end
    panel.pieces[2]:Hide()
end

local function StyleFrame(chatFrame)
    local name = chatFrame:GetName()
    for _, key in ipairs(BORDERS) do NativeArt.Conceal(_G[name .. key]) end
    NativeArt.Conceal(_G[name .. "Background"])

    local bg = styled[chatFrame]
    if not bg then
        local blizzard = _G[name .. "Background"] or chatFrame.Background
        bg = chatFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
        if blizzard then bg:SetAllPoints(blizzard) else bg:SetAllPoints() end
        bg:SetVertexColor(0, 0, 0)
        bg:SetAlpha(0)
        styled[chatFrame] = bg
        -- Below the tabs and text, so they draw over the frame's top edge.
        local border = CreateFrame("Frame", nil, chatFrame)
        border:SetFrameLevel(math.max(0, chatFrame:GetFrameLevel() - 1))
        border.pieces = NativeArt.CreateBox(border, BOX, false, "BORDER")
        if border.pieces then
            border.tabs, border.edges = {}, {}
            border:SetAlpha(0)
            frames[chatFrame] = border
        end
    end
    bg:Show()
    if frames[chatFrame] then frames[chatFrame]:Show() end
    PlacePanel(chatFrame)

    local tab = Tab(chatFrame)
    if tab then
        for _, key in ipairs(TAB_ART) do NativeArt.Conceal(tab[key]) end
        if not tabHooked[tab] then
            tabHooked[tab] = true
            hooksecurefunc(tab, "SetAlpha", OnTabAlpha)
        end
        if not tabAlpha[tab] then SetTabAlpha(tab, 0) end
    end

    local editBox = chatFrame.editBox or _G[name .. "EditBox"]
    if editBox then
        for _, key in ipairs(EDIT_ART) do NativeArt.Conceal(_G[editBox:GetName() .. key]) end
    end

    if chatFrame.ScrollBar then Park(chatFrame.ScrollBar) end
end

local function UnstyleFrame(chatFrame)
    local name = chatFrame:GetName()
    for _, key in ipairs(BORDERS) do NativeArt.Reveal(_G[name .. key]) end
    NativeArt.Reveal(_G[name .. "Background"])
    if styled[chatFrame] then styled[chatFrame]:Hide() end
    if frames[chatFrame] then frames[chatFrame]:Hide() end
    local tab = Tab(chatFrame)
    if tab then
        for _, key in ipairs(TAB_ART) do NativeArt.Reveal(tab[key]) end
        tabAlpha[tab] = nil
        if FCFTab_UpdateAlpha then pcall(FCFTab_UpdateAlpha, chatFrame) end
    end
    local editBox = chatFrame.editBox or _G[name .. "EditBox"]
    if editBox then
        for _, key in ipairs(EDIT_ART) do NativeArt.Reveal(_G[editBox:GetName() .. key]) end
    end
    if chatFrame.ScrollBar then Unpark(chatFrame.ScrollBar) end
end

local function SetButtonsHidden(hide)
    for _, chatFrame in ipairs(ChatFrames()) do
        local buttons = chatFrame.buttonFrame or _G[chatFrame:GetName() .. "ButtonFrame"]
        if buttons then
            if hide then Park(buttons) else Unpark(buttons) end
        end
    end
    for _, name in ipairs(LOOSE_BUTTONS) do
        local frame = _G[name]
        if frame then
            if hide then Park(frame) else Unpark(frame) end
        end
    end
    buttonsHidden = hide
end

-- The mouse is over a chat window, counting the strip above it where the tabs sit.
local function Hovered(chatFrame)
    if chatFrame:IsVisible() and chatFrame:IsMouseOver(28, -2, -2, 2) then return true end
    local tab = Tab(chatFrame)
    return tab and tab:IsVisible() and tab:IsMouseOver() or false
end

local function Step(current, goal, full, elapsed)
    if current == goal then return goal end
    local step = full * elapsed / BG_FADE
    if current < goal then return math.min(goal, current + step) end
    return math.max(goal, current - step)
end

---------------------------------------------------------------------------
-- Text on hover only
---------------------------------------------------------------------------

local hoverOnly = false

local function ResetText(chatFrame)
    if chatFrame.FontStringContainer then chatFrame.FontStringContainer:SetAlpha(1) end
end

-- Background, tabs and text fade in together as soon as the mouse is over the chat (or you type).
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, elapsed)
    local typing = Chat.IsTyping()
    -- Docked windows share one spot: hovering any of them (or a docked tab) shows them all.
    local dockHovered = false
    for chatFrame in pairs(styled) do
        if chatFrame.isDocked and Hovered(chatFrame) then dockHovered = true break end
    end
    if GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.overflowButton and GENERAL_CHAT_DOCK.overflowButton.list
        and GENERAL_CHAT_DOCK.overflowButton.list:IsShown() then
        dockHovered = true
    end

    for chatFrame, bg in pairs(styled) do
        if bg:IsShown() then
            local shown = chatFrame.hasBeenFaded
                or (chatFrame.isDocked and dockHovered) or Hovered(chatFrame)
                or (typing and chatFrame == SELECTED_CHAT_FRAME)
            local before = bg:GetAlpha()
            -- Tabs move, appear and change width: the frame follows while it shows.
            local panel = frames[chatFrame]
            if panel and (shown or before > 0) and chatFrame:IsVisible() then
                panel.timer = (panel.timer or 0) + elapsed
                if before == 0 or panel.timer > 0.2 then
                    panel.timer = 0
                    PlacePanel(chatFrame)
                end
            end
            bg:SetAlpha(Step(before, shown and HOVER_ALPHA or 0, HOVER_ALPHA, elapsed))
            local border = frames[chatFrame]
            if border then border:SetAlpha(bg:GetAlpha() / HOVER_ALPHA) end

            -- Only the text: the window itself stays as it is, so fade groups keep working.
            local container = chatFrame.FontStringContainer
            if container then
                local goal = (not hoverOnly or shown) and 1 or 0
                local alpha = Step(container:GetAlpha(), goal, 1, elapsed)
                if alpha ~= container:GetAlpha() then container:SetAlpha(alpha) end
            end

            local tab = Tab(chatFrame)
            if tab and tabAlpha[tab] then
                local goal = 0
                if shown then
                    goal = TabShownAlpha(tab)
                elseif tab.alerting and not hoverOnly then
                    goal = 1
                end
                local alpha = Step(tabAlpha[tab], goal, 1, elapsed)
                if alpha ~= tabAlpha[tab] or math.abs(tab:GetAlpha() - alpha) > 0.001 then
                    SetTabAlpha(tab, alpha)
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Input box above or below the window
---------------------------------------------------------------------------

local inputMoved = {} -- [editBox] = Blizzard's anchors, to put back

local function SavePoints(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return points
end

-- On top it sits above the tabs, so hovering the chat never puts a tab over what you type.
local function SetInputOnTop(chatFrame, top)
    local editBox = chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"]
    if not editBox then return end
    if top then
        inputMoved[editBox] = inputMoved[editBox] or SavePoints(editBox)
        local tab = Tab(chatFrame)
        local lift = (tab and tab:GetHeight() or 24) + 2
        editBox:ClearAllPoints()
        editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -5, lift)
        editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 5, lift)
    elseif inputMoved[editBox] then
        editBox:ClearAllPoints()
        for _, point in ipairs(inputMoved[editBox]) do editBox:SetPoint(unpack(point)) end
        inputMoved[editBox] = nil
    end
end

function Chat:ApplyWindow()
    local allowed = not self:ChattynatorLoaded()
    local clean = allowed and Cfg("clean") and true or false
    local hideButtons = allowed and Cfg("hideButtons") and true or false
    hoverOnly = clean and Cfg("hoverOnly") and true or false

    if clean then
        for _, chatFrame in ipairs(ChatFrames()) do StyleFrame(chatFrame) end
        driver:Show()
    elseif cleanOn then
        for _, chatFrame in ipairs(ChatFrames()) do
            UnstyleFrame(chatFrame)
            ResetText(chatFrame)
        end
        driver:Hide()
    end
    cleanOn = clean

    if hideButtons or buttonsHidden then SetButtonsHidden(hideButtons) end

    local top = allowed and Cfg("inputTop") and true or false
    for _, chatFrame in ipairs(ChatFrames()) do SetInputOnTop(chatFrame, top) end
end

function Chat.IsClean() return cleanOn end

---------------------------------------------------------------------------
-- Battle.net toasts: the game's own Social settings turn the common ones off (no sound either);
-- the toast frame is also kept hidden for any other kind. Turning the option off puts them back.
-- Works with Chattynator too: the toasts aren't part of the chat window.
---------------------------------------------------------------------------

local TOAST_CVARS = { "showToastOnline", "showToastOffline", "showToastBroadcast", "showToastFriendRequest" }
local toastsHidden, toastHooked = false, false

local function SetToastCVars(on)
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    for _, name in ipairs(TOAST_CVARS) do pcall(set, name, on and "1" or "0") end
end

function Chat:ApplyToasts()
    local hide = Cfg("hideBnetToasts") and true or false
    if hide == toastsHidden then return end
    toastsHidden = hide
    SetToastCVars(not hide)
    local toast = BNToastFrame
    if not toast then return end
    if hide and not toastHooked then
        toastHooked = true
        hooksecurefunc(toast, "Show", function(frame)
            if toastsHidden then frame:Hide() end
        end)
    end
    if hide then toast:Hide() end
end

-- Temporary whisper windows and new tabs come later: style them as they open.
local function OnNewWindow()
    if cleanOn or buttonsHidden or Cfg("inputTop") then Chat:ApplyWindow() end
end

---------------------------------------------------------------------------
-- History
---------------------------------------------------------------------------

local restored = {} -- [frame index] = { [message] = { r, g, b } }, lines we put back (undimmed colors)
local historyDone = false

local function CharKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function Keepable(message)
    return type(message) == "string" and not IsSecret(message) and message ~= ""
        and not message:find("|K", 1, true) -- Battle.net names only show in this session
end

function Chat:SaveHistory()
    if not Cfg("history") then return end
    BOLTDB.chatHistory = BOLTDB.chatHistory or {}
    local saved = {}
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and chatFrame.GetNumMessages and not IsCombatLogFrame(chatFrame) then
            local lines = {}
            local ok, count = pcall(chatFrame.GetNumMessages, chatFrame)
            if ok and type(count) == "number" then
                for index = math.max(1, count - HISTORY_LINES + 1), count do
                    local okInfo, message, r, g, b = pcall(chatFrame.GetMessageInfo, chatFrame, index)
                    if okInfo and Keepable(message) then
                        local original = restored[i] and restored[i][message]
                        if original then r, g, b = original[1], original[2], original[3] end
                        if IsSecret(r) or IsSecret(g) or IsSecret(b) then r, g, b = 1, 1, 1 end
                        table.insert(lines, { message, r or 1, g or 1, b or 1 })
                    end
                end
            end
            if #lines > 0 then saved[i] = lines end
        end
    end
    BOLTDB.chatHistory[CharKey()] = saved
end

-- Old lines go in above whatever the game already printed this session.
function Chat:RestoreHistory()
    if historyDone then return end
    historyDone = true
    if not Cfg("history") then return end
    local saved = BOLTDB.chatHistory and BOLTDB.chatHistory[CharKey()]
    if type(saved) ~= "table" then return end
    for i, lines in pairs(saved) do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and type(lines) == "table" and not IsCombatLogFrame(chatFrame) then
            restored[i] = {}
            local backFill = chatFrame.BackFillMessage
            local function Put(line)
                local message, r, g, b = line[1], line[2] or 1, line[3] or 1, line[4] or 1
                restored[i][message] = { r, g, b }
                local dr, dg, db = r * HISTORY_DIM, g * HISTORY_DIM, b * HISTORY_DIM
                if backFill then
                    pcall(backFill, chatFrame, message, dr, dg, db)
                else
                    pcall(chatFrame.AddMessage, chatFrame, message, dr, dg, db)
                end
            end
            if backFill then
                for index = #lines, 1, -1 do Put(lines[index]) end -- newest first, each one older
            else
                for index = 1, #lines do Put(lines[index]) end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Copy chat
---------------------------------------------------------------------------

local copyDialog

local function PlainText(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[^:]*:", ""):gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|K.-|k", "?")
    return (text:gsub("||", "|"))
end

local function BuildCopyDialog()
    local dialog = BOLT:CreateDialog("BOLTChatCopy", 620, 420, "Copy chat")
    local scroll = CreateFrame("ScrollFrame", nil, dialog, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -44)
    scroll:SetPoint("BOTTOMRIGHT", -40, 22)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(550)
    edit:SetScript("OnEscapePressed", function() dialog:Hide() end)
    scroll:SetScrollChild(edit)
    dialog.scroll, dialog.edit = scroll, edit
    return dialog
end

function Chat:ShowCopy(chatFrame)
    chatFrame = chatFrame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    if not chatFrame or not chatFrame.GetNumMessages then return end
    copyDialog = copyDialog or BuildCopyDialog()
    local lines = {}
    local ok, count = pcall(chatFrame.GetNumMessages, chatFrame)
    if ok and type(count) == "number" then
        for index = 1, count do
            local okInfo, message = pcall(chatFrame.GetMessageInfo, chatFrame, index)
            if okInfo and type(message) == "string" and not IsSecret(message) then
                table.insert(lines, PlainText(message))
            end
        end
    end
    local tab = Tab(chatFrame)
    local title = tab and tab.Text and tab.Text:GetText()
    copyDialog.title:SetText(title and not IsSecret(title) and ("Copy chat: " .. title) or "Copy chat")
    copyDialog.edit:SetText(table.concat(lines, "\n"))
    copyDialog:Show()
    copyDialog.edit:SetFocus()
    copyDialog.edit:HighlightText()
    C_Timer.After(0, function()
        copyDialog.scroll:SetVerticalScroll(copyDialog.scroll:GetVerticalScrollRange())
    end)
end

local function AddTabMenuEntry()
    if not (Menu and Menu.ModifyMenu) then return end
    Menu.ModifyMenu("MENU_FCF_TAB", function(owner, rootDescription)
        if not Cfg("copyMenu") then return end
        local chatFrame = owner and owner.GetID and _G["ChatFrame" .. owner:GetID()]
        rootDescription:CreateDivider()
        rootDescription:CreateButton("Copy chat", function() Chat:ShowCopy(chatFrame) end)
    end)
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

function Chat:OnInitialize()
    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGOUT" then
            self:SaveHistory()
        elseif event == "PLAYER_REGEN_ENABLED" then
            self:ApplyWindow() -- anything combat kept us from moving
        else
            self:ApplyWindow()
        end
    end)
    self.eventFrame:RegisterEvent("PLAYER_LOGOUT")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    if FCF_OpenTemporaryWindow then hooksecurefunc("FCF_OpenTemporaryWindow", OnNewWindow) end
    if FCF_OpenNewWindow then hooksecurefunc("FCF_OpenNewWindow", OnNewWindow) end
    AddTabMenuEntry()
    SLASH_BOLTCOPYCHAT1 = "/copychat"
    SlashCmdList.BOLTCOPYCHAT = function() Chat:ShowCopy() end
end

function Chat:OnEnable()
    self:RestoreHistory()
    self:ApplyWindow()
    self:ApplyToasts()
end

function Chat:OnSettingChanged()
    self:ApplyWindow()
    self:ApplyToasts()
end

BOLT:RegisterModule("chat", Chat)
