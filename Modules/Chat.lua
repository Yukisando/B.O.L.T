-- B.O.L.T Chat Module
-- Blizzard's own chat window, made quiet: text on the screen and little else until you reach
-- for it.
--
--   * Clean window: the window's border art, all of the tabs' own art and the scroll bar go; tabs
--     show only while the mouse is over the chat (a tab with new messages still shows), and a
--     soft dark background fades in on hover inside the minimap's bronze frame, with room around
--     the text on every side (the combat log's filter bar goes inside it too). Each tab is a small
--     outline of the same art standing on that frame, with no background of its own. The
--     scroll-to-bottom arrows sit inside the frame's corner.
--   * Text size (down to 8, below the tab menu's 12) and room between lines, for every window.
--   * Text on hover only: the messages themselves show only while the mouse is over the chat
--     or you type (new messages pop up through ChatPopups instead).
--   * Chat buttons (menu, channels, voice, social) hidden. Emotes and languages are still typed.
--   * Input box on top: above the tab boxes instead of under the window.
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
local EDIT_ART = { "Left", "Mid", "Right" }
local LOOSE_BUTTONS = { "QuickJoinToastButton", "ChatFrameToggleVoiceDeafenButton",
    "ChatFrameToggleVoiceMuteButton", "TextToSpeechButtonFrame" }

-- The bronze frame the minimap and chat popups use (see NativeArt.CreateBox). `out` is how far
-- the art's line sits inside each piece's outer edge.
local BOX = BOLT.isForever
    and { atlas = "ui-hud-minimap-header-button", corner = 7, midX = 76, midY = 11, out = 3 }
    or { atlas = "ui-hud-minimap-button", corner = 6, midX = 10, midY = 9, out = 4 }
local LINE = BOX.out

-- Room between the chat's text and the frame's line.
local PAD_X = 8
local PAD_TOP = 6
local PAD_BOTTOM = 5
local MIN_PAD_TOP = 2      -- the top room shrinks down to this when the tab labels sit low

-- Tabs: room around each label inside its box.
local TAB_PAD_X = 12
local TAB_GAP = 6          -- at least this much between two tab boxes (their facing sides shrink)
local TAB_PAD_Y_MIN = 6    -- above the label: as much as below it, within these bounds
local TAB_PAD_Y_MAX = 10
local TAB_MIN_BELOW = 4    -- a label stays at least this far above the frame's top line
local TAB_MIN_ALPHA = 0.9  -- unselected tab labels stay this visible while the chat shows

local HOVER_ALPHA = 0.6    -- the dark background under the text while the mouse is over it
local MIN_TEXT_SIZE, MAX_TEXT_SIZE = 8, 24 -- the text size slider (the tab menu stops at 12)
local BG_FADE = 0.25       -- seconds
local HISTORY_LINES = 100  -- per tab
local HISTORY_DIM = 0.85   -- restored lines, color multiplier

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
-- From the bottom up:
--   * the panel: our own frame, a whole strata under the chat and its tabs, holding the dark
--     background and the bronze frame. It goes around the text with room on every side, and
--     around the combat log's filter bar when that window shows it.
--   * the tab boxes: outlines drawn as textures on each tab itself, anchored to its label, so
--     the label always draws over them and they follow the tab wherever Blizzard moves it. A box
--     stands on the panel's top line, the label centered in it.
--   * the input box, when it's on top: just above the highest tab box. Its art is hidden, so it
--     takes clicks only while you type in it; idle, it would be an invisible wall over the tabs.
-- Positions come from the screen, and are measured again while the chat shows: tabs move,
-- appear, get renamed, and the combat log's filter bar pushes them up.

local cleanOn, buttonsHidden = false, false
local styled = {}      -- [chatFrame] = true while we style it
local panels = {}      -- [chatFrame] = our panel
local fade = {}        -- [chatFrame] = 0..1, how far the panel has faded in
local tabHooked = {}
local tabAlpha = {}    -- [tab] = the alpha our fade gives it
local settingTab = false
local ours = setmetatable({}, { __mode = "k" }) -- textures we put on Blizzard's frames

local function Tab(chatFrame) return _G[chatFrame:GetName() .. "Tab"] end
local function TabText(tab) return tab.Text or _G[tab:GetName() .. "Text"] end
local function EditBoxOf(chatFrame) return chatFrame.editBox or _G[chatFrame:GetName() .. "EditBox"] end

local function SavePoints(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return points
end

local function RestorePoints(region, points)
    region:ClearAllPoints()
    for _, point in ipairs(points) do region:SetPoint(unpack(point)) end
end

-- Blizzard shows the tabs only once the mouse has stood still over the chat for a moment. Our
-- fade drives them instead, together with the panel, so Blizzard's own alpha changes are put
-- back to ours.
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

-- How visible a tab is while the chat is hovered: the selected one fully, the others barely less.
local function TabShownAlpha(tab)
    if ChatFrameUtil and ChatFrameUtil.GetTabAlphas then
        local ok, over = pcall(ChatFrameUtil.GetTabAlphas, tab)
        if ok and type(over) == "number" then return math.max(over, TAB_MIN_ALPHA) end
    end
    return 1
end

-- The tabs shown with a chat window: all the docked ones for a docked window.
local function TabsOf(chatFrame)
    local tabs = {}
    local docked = chatFrame.isDocked and GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES
    for _, frame in ipairs(docked or { chatFrame }) do
        local tab = Tab(frame)
        if tab and tab:IsShown() then table.insert(tabs, tab) end
    end
    return tabs
end

-- Every texture of a tab is Blizzard's tab art (background, selected and hover pieces): all of
-- it goes, so only the label shows, in our box. The new-message glow and the whisper icon stay.
local tabArt = {} -- [tab] = the textures we hid

local function ConcealTabArt(tab)
    if tabArt[tab] then return end
    local keep = { [tab.glow or false] = true, [tab.conversationIcon or false] = true }
    local glow = tab:GetName() and _G[tab:GetName() .. "Glow"]
    if glow then keep[glow] = true end
    local list = {}
    for _, region in ipairs({ tab:GetRegions() }) do
        if region:IsObjectType("Texture") and not keep[region] and not ours[region] then
            NativeArt.Conceal(region)
            table.insert(list, region)
        end
    end
    tabArt[tab] = list
end

local function RevealTabArt(tab)
    for _, texture in ipairs(tabArt[tab] or {}) do NativeArt.Reveal(texture) end
    tabArt[tab] = nil
end

---------------------------------------------------------------------------
-- Tab boxes
---------------------------------------------------------------------------

local tabBoxes = {} -- [tab] = { rect, pieces }

local function TabBox(tab)
    local box = tabBoxes[tab]
    if box then return box end
    box = {}
    -- An invisible rectangle the art is anchored to; Layout sizes it around the label.
    box.rect = tab:CreateTexture(nil, "BACKGROUND", nil, -8)
    box.rect:SetColorTexture(0, 0, 0, 0)
    box.pieces = NativeArt.CreateBox(tab, BOX, false, "BORDER", 0, box.rect) or {}
    local c = BOX.corner
    if #box.pieces == 8 then
        -- Open at the bottom: no bottom edge, and the sides run all the way down to the panel's
        -- top line. Pieces without a center: TL, T, TR, L, R, BL, B, BR.
        box.pieces[4]:SetPoint("BOTTOMRIGHT", box.rect, "BOTTOMLEFT", c, 0)
        box.pieces[5]:SetPoint("BOTTOMRIGHT", box.rect, "BOTTOMRIGHT", 0, 0)
        for i = 6, 8 do box.pieces[i]:Hide() end
    end
    ours[box.rect] = true
    for _, piece in ipairs(box.pieces) do ours[piece] = true end
    tabBoxes[tab] = box
    return box
end

local function ShowTabBox(tab, show)
    local box = tabBoxes[tab]
    if not box then return end
    box.rect:SetShown(show)
    for i, piece in ipairs(box.pieces) do piece:SetShown(show and (#box.pieces ~= 8 or i < 6)) end
end

-- Where the label's text is drawn, left and right, in the tab's coordinates.
local function TextSpan(tab)
    local text = TabText(tab)
    if not text then return nil end
    local sw = text:GetStringWidth() or 0
    local justify = text:GetJustifyH()
    if justify == "LEFT" then
        local left = text:GetLeft()
        return left, left and left + sw
    elseif justify == "RIGHT" then
        local right = text:GetRight()
        return right and right - sw, right
    end
    local cx = text:GetCenter()
    return cx and cx - sw / 2, cx and cx + sw / 2
end

-- `below`: from the bottom of the label's text to the panel's top line. `left`/`right`: from the
-- text to the box's sides. Returns the box's top, up from the label's text bottom.
local function SizeTabBox(tab, below, left, right)
    local text = TabText(tab)
    if not text then return end
    local box = TabBox(tab)
    local sw, sh = text:GetStringWidth() or 0, text:GetStringHeight() or 12
    local above = math.max(TAB_PAD_Y_MIN, math.min(TAB_PAD_Y_MAX, below))
    left, right = left or TAB_PAD_X + LINE, right or TAB_PAD_X + LINE
    local width = sw + left + right
    local height = sh + above + LINE + below
    -- The box's middle, from the middle of the text as it's drawn.
    local dx, dy = (right - left) / 2, (above + LINE - below) / 2
    local justify = text:GetJustifyH()
    box.rect:ClearAllPoints()
    box.rect:SetSize(width, math.max(height, 2 * BOX.corner))
    if justify == "LEFT" then
        box.rect:SetPoint("CENTER", text, "LEFT", sw / 2 + dx, dy)
    elseif justify == "RIGHT" then
        box.rect:SetPoint("CENTER", text, "RIGHT", -sw / 2 + dx, dy)
    else
        box.rect:SetPoint("CENTER", text, "CENTER", dx, dy)
    end
    ShowTabBox(tab, true)
    return sh + above + LINE
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------

local STRATA = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
local STRATA_NAMES = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN",
    "FULLSCREEN_DIALOG", "TOOLTIP" }

-- A whole strata below the chat, its text and its tabs (frame levels alone weren't enough: the
-- text ended up under the panel). Already in BACKGROUND, it goes just under them there.
local function PutUnder(panel, chatFrame, tabs)
    local rank, level = STRATA[chatFrame:GetFrameStrata()] or 2, chatFrame:GetFrameLevel()
    local container = chatFrame.FontStringContainer
    if container then level = math.min(level, container:GetFrameLevel()) end
    for _, tab in ipairs(tabs) do
        local r, l = STRATA[tab:GetFrameStrata()] or 2, tab:GetFrameLevel()
        if r < rank then
            rank, level = r, l
        elseif r == rank then
            level = math.min(level, l)
        end
    end
    local strata, want = STRATA_NAMES[math.max(1, rank - 1)], 1
    if rank == 1 then want = math.max(0, level - 1) end
    if panel:GetFrameStrata() ~= strata then panel:SetFrameStrata(strata) end
    if panel:GetFrameLevel() ~= want then panel:SetFrameLevel(want) end
end

local function CreatePanel(chatFrame)
    local panel = CreateFrame("Frame", nil, chatFrame)
    panel.bg = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel.bg:SetColorTexture(0, 0, 0, HOVER_ALPHA)
    panel.bg:SetPoint("TOPLEFT", LINE, -LINE)
    panel.bg:SetPoint("BOTTOMRIGHT", -LINE, LINE)
    NativeArt.CreateBox(panel, BOX, false, "BORDER")
    panel:SetAlpha(0)
    return panel
end

-- Convert a screen y from `region`'s frame into an offset up from the chat frame's top.
local function UpFromTop(chatFrame, frame, y)
    local top = chatFrame:GetTop()
    if not (y and top) then return nil end
    return y * frame:GetEffectiveScale() / chatFrame:GetEffectiveScale() - top
end

-- The top of what the panel holds, up from the chat frame's top: the combat log's filter bar
-- sits above its text.
local function ContentTop(chatFrame)
    local bar = CombatLogQuickButtonFrame_Custom
    if bar and IsCombatLogFrame(chatFrame) and bar:IsVisible() then
        local up = UpFromTop(chatFrame, bar, bar:GetTop())
        if up and up > 0 then return up end
    end
    return 0
end

local PlaceInput -- below

local function Layout(chatFrame)
    local panel = panels[chatFrame]
    if not panel then return end
    local tabs = TabsOf(chatFrame)
    PutUnder(panel, chatFrame, tabs)
    local contentTop = ContentTop(chatFrame)

    -- Each label's text bottom, up from the chat frame's top.
    local bottoms, lowest = {}, nil
    for _, tab in ipairs(tabs) do
        local text = TabText(tab)
        local cy
        if text then cy = select(2, text:GetCenter()) end
        local bottom = cy and UpFromTop(chatFrame, tab, cy - (text:GetStringHeight() or 0) / 2)
        if bottom then
            bottoms[tab] = bottom
            lowest = lowest and math.min(lowest, bottom) or bottom
        end
    end

    -- The panel's top line, with less room over the text if a label would sit too close to it.
    local padTop = PAD_TOP
    if lowest then
        local short = TAB_MIN_BELOW - (lowest - contentTop - padTop)
        if short > 0 then padTop = math.max(MIN_PAD_TOP, padTop - short) end
    end
    local lineY = contentTop + padTop
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", -PAD_X - LINE, lineY + LINE)
    panel:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", PAD_X + LINE, -PAD_BOTTOM - LINE)

    -- Side room: the full padding, less where two neighbours would come closer than TAB_GAP.
    -- Both sides of a box get the same, so its label stays in the middle.
    local full = TAB_PAD_X + LINE
    local sides, row = {}, {}
    for _, tab in ipairs(tabs) do
        local l, r = TextSpan(tab)
        if l and r then table.insert(row, { tab = tab, l = l, r = r }) end
        sides[tab] = { full, full }
    end
    table.sort(row, function(a, b) return a.l < b.l end)
    for i = 2, #row do
        local prev, cur = row[i - 1], row[i]
        local space = cur.l - prev.r
        if space < 2 * full + TAB_GAP then
            local pad = math.max(LINE + 2, (space - TAB_GAP) / 2)
            sides[prev.tab][2], sides[cur.tab][1] = pad, pad
        end
    end
    for _, side in pairs(sides) do
        local pad = math.min(side[1], side[2])
        side[1], side[2] = pad, pad
    end

    local tabTop
    for _, tab in ipairs(tabs) do
        local bottom = bottoms[tab]
        if bottom then
            local below = math.max(1, bottom - lineY)
            local up = SizeTabBox(tab, below, sides[tab][1], sides[tab][2])
            if up then tabTop = math.max(tabTop or 0, bottom + up) end
        end
    end
    panel.tabTop = tabTop
    PlaceInput(chatFrame)
end

---------------------------------------------------------------------------
-- Input box on top
---------------------------------------------------------------------------

local inputOn = false
local inputSaved = {}  -- [editBox] = Blizzard's anchors, to put back
local inputHooked = {}
local inputLift = {}   -- [editBox] = the lift we last gave it
local placingInput = false

-- Just above the highest tab box (or the tab itself, before we've drawn one).
local function InputLift(chatFrame)
    local panel = panels[chatFrame]
    if cleanOn and panel and panel.tabTop then return panel.tabTop + 2 end
    local tab = Tab(chatFrame)
    local up = tab and UpFromTop(chatFrame, tab, tab:GetTop())
    return (up or 28) + 2
end

-- Blizzard puts the input box back under the window now and then (logging in, docking): the
-- SetPoint hook moves it up again, so the setting holds.
function PlaceInput(chatFrame, force)
    local editBox = EditBoxOf(chatFrame)
    if not editBox or not inputOn then return end
    inputSaved[editBox] = inputSaved[editBox] or SavePoints(editBox)
    if not inputHooked[editBox] then
        inputHooked[editBox] = true
        hooksecurefunc(editBox, "SetPoint", function()
            if inputOn and not placingInput then PlaceInput(chatFrame, true) end
        end)
    end
    local lift = math.floor(InputLift(chatFrame) + 0.5)
    if not force and inputLift[editBox] == lift then return end
    inputLift[editBox] = lift
    placingInput = true
    editBox:ClearAllPoints()
    editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", -5, lift)
    editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 5, lift)
    placingInput = false
end

local function RestoreInput(chatFrame)
    local editBox = EditBoxOf(chatFrame)
    local points = editBox and inputSaved[editBox]
    if not points then return end
    inputSaved[editBox], inputLift[editBox] = nil, nil
    placingInput = true
    RestorePoints(editBox, points)
    placingInput = false
end

-- With its art hidden, an idle input box is invisible: it takes clicks only while you type.
local clicksHooked = {}

local function UpdateInputClicks(editBox)
    editBox:EnableMouse((not cleanOn) or editBox:HasFocus())
end

local function WatchInputClicks(editBox)
    if not clicksHooked[editBox] then
        clicksHooked[editBox] = true
        editBox:HookScript("OnEditFocusGained", UpdateInputClicks)
        editBox:HookScript("OnEditFocusLost", UpdateInputClicks)
    end
    UpdateInputClicks(editBox)
end

---------------------------------------------------------------------------
-- Scroll-to-bottom arrows: in the frame's bottom-right corner, inside its line. Blizzard
-- re-anchors them now and then; the hook puts them back.
---------------------------------------------------------------------------

local scrollSaved = {} -- [button] = Blizzard's anchors, to put back
local scrollHooked = {}
local placingScroll = false

local function PlaceScrollButton(chatFrame)
    local button = chatFrame.ScrollToBottomButton
    if not button then return end
    scrollSaved[button] = scrollSaved[button] or SavePoints(button)
    if not scrollHooked[button] then
        scrollHooked[button] = true
        hooksecurefunc(button, "SetPoint", function()
            if not placingScroll and scrollSaved[button] then PlaceScrollButton(chatFrame) end
        end)
    end
    placingScroll = true
    button:ClearAllPoints()
    button:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT", PAD_X - 6, 0)
    placingScroll = false
end

local function RestoreScrollButton(chatFrame)
    local button = chatFrame.ScrollToBottomButton
    local points = button and scrollSaved[button]
    if not points then return end
    scrollSaved[button] = nil
    placingScroll = true
    RestorePoints(button, points)
    placingScroll = false
end

---------------------------------------------------------------------------
-- Styling a window
---------------------------------------------------------------------------

local function StyleFrame(chatFrame)
    local name = chatFrame:GetName()
    for _, key in ipairs(BORDERS) do NativeArt.Conceal(_G[name .. key]) end
    NativeArt.Conceal(_G[name .. "Background"])
    if IsCombatLogFrame(chatFrame) then NativeArt.Conceal(_G.CombatLogQuickButtonFrame_CustomTexture) end

    panels[chatFrame] = panels[chatFrame] or CreatePanel(chatFrame)
    panels[chatFrame]:Show()
    styled[chatFrame] = true

    local tab = Tab(chatFrame)
    if tab then
        ConcealTabArt(tab)
        TabBox(tab)
        ShowTabBox(tab, true)
        if not tabHooked[tab] then
            tabHooked[tab] = true
            hooksecurefunc(tab, "SetAlpha", OnTabAlpha)
        end
        if not tabAlpha[tab] then SetTabAlpha(tab, 0) end
    end

    local editBox = EditBoxOf(chatFrame)
    if editBox then
        for _, key in ipairs(EDIT_ART) do NativeArt.Conceal(_G[editBox:GetName() .. key]) end
    end

    if chatFrame.ScrollBar then Park(chatFrame.ScrollBar) end
    PlaceScrollButton(chatFrame)
end

local function UnstyleFrame(chatFrame)
    local name = chatFrame:GetName()
    for _, key in ipairs(BORDERS) do NativeArt.Reveal(_G[name .. key]) end
    NativeArt.Reveal(_G[name .. "Background"])
    if IsCombatLogFrame(chatFrame) then NativeArt.Reveal(_G.CombatLogQuickButtonFrame_CustomTexture) end
    if panels[chatFrame] then panels[chatFrame]:Hide() end
    styled[chatFrame], fade[chatFrame] = nil, nil

    local tab = Tab(chatFrame)
    if tab then
        RevealTabArt(tab)
        ShowTabBox(tab, false)
        tabAlpha[tab] = nil
        if FCFTab_UpdateAlpha then pcall(FCFTab_UpdateAlpha, chatFrame) end
    end

    local editBox = EditBoxOf(chatFrame)
    if editBox then
        for _, key in ipairs(EDIT_ART) do NativeArt.Reveal(_G[editBox:GetName() .. key]) end
    end

    if chatFrame.ScrollBar then Unpark(chatFrame.ScrollBar) end
    RestoreScrollButton(chatFrame)
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

-- The mouse is over a chat window: its panel, or the strip above it where the tabs sit.
local function Hovered(chatFrame)
    if not chatFrame:IsVisible() then return false end
    local panel = panels[chatFrame]
    local up = (panel and panel.tabTop) or 28
    if chatFrame:IsMouseOver(up, -PAD_BOTTOM - LINE, -PAD_X - LINE, PAD_X + LINE) then return true end
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

-- Panel, tabs and text fade in together as soon as the mouse is over the chat (or you type).
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

    for chatFrame in pairs(styled) do
        local panel = panels[chatFrame]
        local shown = chatFrame.hasBeenFaded
            or (chatFrame.isDocked and dockHovered) or Hovered(chatFrame)
            or (typing and chatFrame == SELECTED_CHAT_FRAME)
        local before = fade[chatFrame] or 0
        -- Measured again every so often while it shows.
        if (shown or before > 0) and chatFrame:IsVisible() then
            panel.timer = (panel.timer or 0) + elapsed
            if before == 0 or panel.timer > 0.2 then
                panel.timer = 0
                Layout(chatFrame)
            end
        end
        local now = Step(before, shown and 1 or 0, 1, elapsed)
        fade[chatFrame] = now
        if math.abs(panel:GetAlpha() - now) > 0.001 then panel:SetAlpha(now) end

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
end)

---------------------------------------------------------------------------
-- Text size and room between lines
---------------------------------------------------------------------------
-- The size is the game's own per-window setting (the tab menu's Font Size), saved by the game:
-- the slider sets it on every window at once and goes below the menu's 12. The room between
-- lines is ours (chat.lineSpacing).

Chat.MIN_TEXT_SIZE, Chat.MAX_TEXT_SIZE = MIN_TEXT_SIZE, MAX_TEXT_SIZE

function Chat:GetTextSize()
    local ok, _, size = pcall(GetChatWindowInfo, 1)
    if ok and type(size) == "number" and size > 0 then return math.floor(size + 0.5) end
    return 14
end

function Chat:SetTextSize(size)
    size = math.max(MIN_TEXT_SIZE, math.min(MAX_TEXT_SIZE, math.floor(size + 0.5)))
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame then
            if SetChatWindowSize then pcall(SetChatWindowSize, i, size) end
            local file, _, flags = chatFrame:GetFont()
            if file then chatFrame:SetFont(file, size, flags or "") end
        end
    end
end

local function ApplySpacing()
    local spacing = Cfg("lineSpacing") or 0
    for _, chatFrame in ipairs(ChatFrames()) do
        if chatFrame.SetSpacing then pcall(chatFrame.SetSpacing, chatFrame, spacing) end
    end
end

---------------------------------------------------------------------------
-- Applying the settings
---------------------------------------------------------------------------

function Chat:ApplyWindow()
    local allowed = not self:ChattynatorLoaded()
    local clean = allowed and Cfg("clean") and true or false
    local hideButtons = allowed and Cfg("hideButtons") and true or false
    hoverOnly = clean and Cfg("hoverOnly") and true or false

    if clean then
        cleanOn = true
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
    ApplySpacing()

    inputOn = allowed and Cfg("inputTop") and true or false
    for _, chatFrame in ipairs(ChatFrames()) do
        if inputOn then
            if styled[chatFrame] and chatFrame:IsVisible() then Layout(chatFrame) end
            PlaceInput(chatFrame, true)
        else
            RestoreInput(chatFrame)
        end
        local editBox = EditBoxOf(chatFrame)
        if editBox then WatchInputClicks(editBox) end
    end
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
    Chat:ApplyWindow()
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
            -- Blizzard lays the chat out again once the world is up.
            C_Timer.After(1, function() self:ApplyWindow() end)
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
