# B.O.L.T

**Brittle and Occasionally Lethal Tweaks** - Quality of life improvements for World of Warcraft that make your gameplay experience smoother without changing core mechanics.

Supports **Midnight (12.1.5)** and **WoW: Forever**. On Forever, modules built on modern-only systems (Skyriding, Key Share, Smart Teleport, Achievement Tracker) are hidden automatically, and the Interface modules use Forever's own bronze art.

All modules can be toggled independently. New installs start with every module disabled — turn on what you want from the settings panel (`/bolt`) or via the quick toggles in the minimap tracking dropdown.

**Edit Mode**: BOLT's own frames (camp bar, floating ranged timer) move in Edit Mode like Blizzard's. Your whole UI setup is saved with each Edit Mode layout and shared by all your characters: positions, every Edit Mode option, and whether the UI modules (Unit Frames, Minimap, Auto-hide UI, Tooltips, Nameplates, Party Frames Center Growth, Ranged Attack Timer, Campfire) are on. Switching layout switches that setup too, and a new layout starts as a copy of the one you were on. Select a Blizzard frame (Player, Target, Personal Resource Display, Minimap, action bars, micro menu, bags, experience bar, buffs, quest tracker, cast bar, focus, pet and party frames) and a "B.O.L.T" block under its settings says what BOLT can do to that frame, such as "Fade out until needed" or "Flat style (no round portrait)". Ticking one turns its module on when needed. Those options live only in Edit Mode: the settings page turns modules on and off and has an "Open Edit Mode" button.

## Modules

### Interface

Everything that changes how the game's UI looks lives on the **Interface** settings page. These modules restyle Blizzard's own frames with Blizzard's own art (Forever's bronze art on WoW: Forever), so the result looks like it shipped with the game.

#### Unit Frames & Cast Bars

- **Portrait-less Unit Frames**: Player, target, focus, target of target, pet and party frames lose their round portrait; Blizzard's frame stretches over the space and the bars widen and fill flush to the borders
- **Native Art**: Level shown in Blizzard's level circle, elite/rare dragons wrap the end of the target frame
- **Cast Bars**: The spell name sits on the bar instead of in a strip underneath
- **Per-Frame Choice**: Pick which frames to restyle; turning one off takes a `/reload`

#### Minimap

- **Square Minimap**: The map is square, framed with Blizzard's minimap art (bronze on WoW: Forever, Blizzard's dark plates on Midnight)
- **Title Bar**: Zone name and clock in one bar above the map
- **One Button Bar**: Tracking, calendar, mail and crafting orders, expansion summary, instance difficulty, Blizzard's addon list (shown as a small settings cog) and the addon drawer (a gold count) sit in a single bar, without their own frames: a row at the bottom (default) or under the title bar, or a column on the left or right
- **In the Map**: Coordinates in the bottom-right corner and, on WoW: Forever, the day/night dial in the top-right corner, both half faded until you hover the map. While you're resting, the player frame's little Zzz plays inside the dial (in the corner on Midnight)
- **Addon Button Drawer**: Buttons that addons hang on the minimap go into one drawer button that shows how many there are; click it to open them, it closes by itself when the mouse leaves
- **Mouse-Wheel Zoom**: Optional; hides the +/- buttons and zooms back out after 20 seconds
- **Works With Auto-hide UI**: The bars and drawer button fade with the "Minimap buttons" group
- **Screen Edge**: Drag the minimap right into the corner in Edit Mode: by default only the visible map has to stay on screen, so the empty space around it can go past the edge. "Screen edge" at the top of the Minimap's B.O.L.T block switches back to Blizzard's limit or lets it move freely; `/bolt edge` shows what it's doing. Works with or without the square minimap
- Paused while SexyMap, BasicMinimap or ElvUI is loaded. Turning the module off takes a `/reload`

#### Player & Target Frames

- **Hide Them Your Way**: Hide the Player Frame and/or the Target Frame, then pick when each comes back: in combat, with a target (any target, attackable only or not attackable only), or on mouse hover
- **Personal Resource Display**: Turn on Blizzard's health and power bars under your character. When Edit Mode shows it only in combat, it can also show with a target (any, attackable only or not attackable only), fade to an opacity of your choice instead of hiding, and open your menu on right-click (Shift + right-click for your target's)
- **Pet Health Bar**: A half-height bar on top of the Personal Resource Display's health bar shows your pet's health, with the same gold-bordered art, width and spacing as its other bars. Shows while you have a pet out
- **Your Own Immersive Mode**: Hide both frames and turn on the Personal Resource Display. (This replaces the old Immersive Mode toggle; if you had it on, your setup carries over)
- **In Edit Mode**: Select the Player Frame, Target Frame or Personal Resource Display; BOLT's options sit in a "B.O.L.T" block under Blizzard's settings. Every frame shows while you edit

#### Ranged Attack Timer

- **Shot Timer**: A bar fills between your automatic shots (Auto Shot; on WoW: Forever also wand Shoot), so you can fit casts and moves between them
- **Built In**: One more bar under the Personal Resource Display, in the same style and width, following it as you change it in Edit Mode; floats on its own when the Personal Resource Display is off (or "Attach" is unticked). Move the floating bar and set its width in Edit Mode
- Only offered to classes with a repeating ranged attack. Melee swings can't be timed: the game keeps the combat log from addons

#### Nameplates

- **Mana User Highlighting**: Enemy nameplate health bars are colored for mana users (healers/casters), optionally only in dungeons, raids and scenarios, with a color of your choice
- **Target Emphasis**: Your target's nameplate is larger and the others fade slightly (the game's own nameplate settings, restored to their defaults when turned off)
- **Interrupt Cue**: An enemy cast bar gets an outline and your interrupt's icon when the cast can be interrupted *and* your interrupt is off cooldown, so you know at a glance whether to kick. Works with Midnight's combat restrictions (the game itself decides whether to show the cue)
- **Range Hint**: Enemies out of your reach get a slightly darker health bar, measured with your interrupt (or a basic attack for classes and specs without one)
- **Combat Persistent**: Colors survive entering combat and threat updates via a secure post-hook on Blizzard's health color system

#### Auto-hide UI

- **Fade Until Needed**: The main action bar with the micro menu and bags (one strip: hovering any of them shows all three), the other action bars, experience bar, buffs, debuffs, unit frames, quest tracker, minimap and minimap buttons fade out
- **Smart Reveal**: They fade in when you hover them, are in combat or have a target (any, attackable only, not attackable only, or never), and stay hidden while mounted or on a flight path unless you're in combat
- **Edit Mode Friendly**: Everything shows in Edit Mode; action bars also show while you drag a spell or item
- **Adjustable Opacity**: Choose how visible hidden parts stay

#### Party Frames Center Growth

- **Centered Raid-Style Party Growth**: Keeps raid-style party frames centered instead of visually drifting from a fixed corner as the group fills
- **Dynamic Join/Leave Nudging**: Repositions the party anchor as members join or leave so the layout remains centered for party sizes 1-5
- **Party-Only Scope**: Only affects party raid-style frames; raid group frames are untouched

### Quality of Life

#### Game Menu Enhancements

- **Leave Group Button**: Adds a "Leave Group/Raid/Delve" button below the ESC menu when you're in any group
- **Reload UI Button**: Small refresh button in the top-right corner of the ESC menu for quick UI reloads
- **Group Tools**: Ready Check, Countdown Timer, and Raid Marker buttons on the bottom-right side of the Game Menu
  - Ready Check: Start a ready check for your group (leader/assistant only)
  - Countdown: Start a 5-second pull timer (leader/assistant only)
  - Raid Marker: Set or clear your own raid marker (configurable icon, right-click to clear) — visible even when you're not in a group, as long as Group Tools are enabled
- **Loot Spec Button**: Quick loot specialization switching from the Game Menu
  - Left-click: Cycle through current spec plus all available loot specs for your class
  - Right-click: Pick the exact loot specialization from a menu
  - Gold border: A loot spec override is active instead of following your current specialization
- **Battle Text Toggles**: Quick toggles for damage and healing numbers in scrolling combat text
- **Volume Control Button**: Master volume and music control with visual feedback
  - Shows current volume percentage (or "M" when muted) directly on the button
  - Left-click: Toggle mute/unmute master volume
  - Right-click: Toggle music on/off
  - Mouse wheel: Adjust master volume in 5% increments
  - A "Toggle Master Volume" keybinding is also available under B.O.L.T in Key Bindings

#### Campfire Rest (WoW: Forever)

- **Camp Bar**: While you have the Campfire Nearby buff, a slim bar fades in beside the minimap: what to do now, a bar counting down the minute to Camp Benefits (then their time left), and a Sit button. Right-click it to hide it until the next fire
- **Sit by the Fire**: Click Sit; the bar tells you if you're too far once you sit, and remembers where the fire warmed you so it can sit you down again there (option)
- **Ready Alert**: A sound, a glow and a taskbar flash when Camp Benefits lands, so you can look away during the minute of sitting (option)
- **Camp Drawer**: Click the bar for the camp benefits you got (one row per camp object) and your camp gear: every camp object you carry or can craft, built in for all professions and tiers, each with its own Place and Craft buttons, cooldowns and missing reagents
- **In Edit Mode** ("Camp Bar"): left (default), right, above or under the minimap, or drag it anywhere; set its size and options
- `/bolt camp` prints what the bar sees, for bug reports

#### Auto Rep Switch

- **Automatic Watched Faction**: Automatically switches the "watched" reputation bar to whichever faction you just gained reputation with
- **All Factions Supported**: Works across all reputation sources including the modern Renown system
- **Instance Safe**: Uses Midnight's `FACTION_STANDING_CHANGED` event instead of parsing chat, so it also works inside instances

#### Smart Teleport Suggestions

- **World Map Drawer**: When you open the World Map, a small icon drawer appears showing every teleport destination you can currently reach
- **Broad Coverage**: Covers capital cities, expansion hubs, class-specific portals (Mage, Druid, Death Knight, Monk), engineering wormholes, Hero's Path portal spells earned from Keystone Hero achievements, and your Hearthstone
- **Spell & Item Detection**: Checks both spells and bag items, so engineering gadgets and trinkets are included automatically
- **One-Click Cast**: Click any icon to cast the corresponding teleport spell or use the item

#### Saved Instances

- **Instance Lockout Overview**: Lists all current expansion dungeons and raids alongside your lockout status
- **Slash Command**: Type `/boltsaved` to print unsaved instances to chat
- **Color-Coded Output**: Green for unsaved, orange for in-progress, grey for completed

### Gameplay

#### Shoot Wand Key (WoW: Forever)

- **One Key**: Targets the enemy under the mouse (or keeps your target), sends your pet in and starts wand Shoot; set the key in BOLT settings or Key Bindings

#### Double-Click Fishing

- **Quick Cast**: Double right-click on the world to cast Fishing; ignored in combat, while mounted, over a character, with loot open or while already fishing. A quick right-click followed by holding the button down within 0.4 s also casts, instead of turning the camera

#### Skyriding

- **Enhanced Movement**: Strafe keys (A/D) become horizontal turning while Skyriding
- **Pitch Control**: Optional W/S mapping for pitch up/down (3D control), with an invert option
- **Mouse-Button Mode**: Optionally only apply the controls while holding the left mouse button (default on; the button state can't change mid-combat)
- **Combat Safe**: A secure state driver switches the key overrides on `[advflyable,flying]`, so they turn off the moment you land — even in combat. Steady Flight is ignored
- **Emergency Reset**: `/bolt reset` or `/boltreset` clears the overrides if anything ever feels stuck

### Social

#### Chat Notifier

- **Channel Sound Alerts**: Plays a notification sound when a new message appears in monitored chat channels
- **Configurable Channels**: Pick which channels to monitor from a checklist (Guild, Party, Raid, Whisper, Say, Yell, Instance, Custom Channels, etc.)
- **Multiple Sound Options**: Choose from several built-in notification sounds with a preview button
- **Throttled Alerts**: Rapid messages are throttled so sounds don't overlap
- **Self-Filtering**: Your own messages are ignored

#### Auto Party Chat

- **Group Channel by Default**: Joining a group switches the chat box to Party, Raid or Instance chat to match the group
- **Back to Say**: Leaving the group puts the chat box back on Say
- **Leaves Your Choices Alone**: Only switches away from Say or a group channel; Guild, whispers and custom channels stay as you set them

#### Wowhead Link

- **Quick Wowhead URL**: Press the configured key (default: Ctrl+C, only if that key is free) while hovering an item, toy, spell, aura, mount, currency, NPC, quest or achievement to generate its Wowhead URL
- **Forever Aware**: On WoW: Forever the link points to Wowhead's Forever database
- **Copy Popup**: Displays the URL in a small dialog with the text pre-selected so a second Ctrl+C copies it to the clipboard

### Tracking

#### Achievement Progress Tracker

- **Progress Messages**: Prints a chat message whenever an action you perform advances progress on any achievement (e.g. /love a critter, completing a quest, defeating a boss)
- **Category Filter**: Choose which top-level achievement categories to track (defaults to Exploration; tick them all to track everything)
- **Incremental Scanning**: Scans achievement criteria in small time-budgeted chunks to avoid frame drops, with a minimap spinner while the scan is running
- **Completion Detection**: Recognises when an achievement is fully completed and prunes it from further scanning
- **Throttled Updates**: Rapid criterion changes are debounced so you don't get flooded with messages

### Extras

#### Playground (Fun Features)

- **Favorite Toy Button**: Quick access to your favorite toy from the ESC menu, with a searchable toy picker and an optional "close game menu on cast" setting
- **Speedometer / FPS**: Display your movement speed (as % of run speed) and/or FPS in a configurable screen corner; fades out while standing still
- **Copy Target Mount**: Summon the same mount your target is riding — via `/copymount` (`/cm`) or the "Copy Target Mount" keybinding

#### Key Share

- **Auto Key Link**: Responds to `!keys` in party, raid, or guild chat by posting your current Mythic+ keystone link in the same channel
- **Keystone Roulette**: After you post your key in response to `!keys`, opens a 2-second window to collect keystone links from other players who respond, then randomly announces a winner — useful for deciding which key to run (can be disabled)

#### Sound Muter

- **Popup-Managed Muting**: Open a management popup from the config panel to add or remove muted sound IDs
- **Immediate Apply/Remove**: Added sound IDs are muted immediately while the module is enabled, and removing an ID unmutes it again
- **Persistent List**: Your muted sound ID list is saved in the addon settings so it survives reloads and relogs

#### Character Snapshot

- **JSON Time Capsule**: One-click export of your character's identity, money, /played, collection counts, achievement points and the full Statistics tab as pretty-printed JSON
- **Copy-Friendly Popup**: Opens a read-only text box from the config panel with the JSON pre-selected so Ctrl+C just works
- **Refresh On Demand**: Refresh the popup to re-pull the latest values (e.g. after gaining gold, dying, or logging more /played)

### Roleplay

#### Transmog Presets

- **Account-Wide Looks**: Save the appearance you're wearing as a named preset any character on the account can use (`/bolt transmog`)
- **Stage at a Transmogrifier**: Pick a preset and click Stage; it's loaded into the transmog window as pending changes so you see the cost, then confirm with Blizzard's Apply button
- **Collection Check**: Shows each slot's appearance name and flags ones this character hasn't collected

#### Total RP 3 Integration

Requires [Total RP 3](https://www.curseforge.com/wow/addons/total-rp-3) to be installed.

- **IC/OOC Toggle Keybinding**: Bind "Toggle RP Status" (under B.O.L.T in Key Bindings) to flip your Total RP 3 status between In Character and Out of Character with one key
- **Toolbar Visibility**: Optionally show the TRP toolbar while In Character and hide it while Out of Character
- **Edit Mode Profile Switching**: Optionally switch to a chosen Edit Mode (UI layout) profile when going In Character, and a different one when going Out of Character — e.g. a minimal immersive layout for RP and your normal layout otherwise

#### Everyday Emotes

- **One Key per Emote**: Hello, Goodbye, Thanks and Sit each get a keybind slot in the Roleplay settings (also under B.O.L.T in Key Bindings). Emotes are aimed at your target when you have one. Total RP 3 not needed
- **Thank Your Buffers** (on by default): when another player buffs you, you /thank them 2 seconds later. Out of combat only, once a minute per player

## Installation

1. Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/bolt) or the GitHub releases
2. Place the `BOLT` folder in the `Interface\AddOns\` directory of the game version you play (e.g. `World of Warcraft\_retail_\Interface\AddOns\`)
3. Restart WoW or type `/reload`

## Configuration

Access settings through:

- **Interface Menu**: ESC > Options > AddOns > B.O.L.T (with Interface, Gameplay, Social, Tracking, Extras, and Roleplay categories)
- **Console Command**: `/bolt` or `/b`
- **Minimap Tracking Menu**: Quick enable/disable toggles for every module in the minimap tracking dropdown
- **Game Menu**: Right-click the gear button above the ESC menu

Each module can be enabled/disabled independently; a disabled module's options collapse in the settings.

## Console Commands

- `/bolt` or `/b` - Open settings panel
- `/bolt help` - List commands
- `/bolt status` - Show which modules are enabled
- `/bolt toggle <module>` - Toggle a module (`/bolt toggle debug` toggles debug output)
- `/bolt transmog` - Open Transmog Presets
- `/bolt reset`, `/boltreset` or `/boltnuke` - Clear Skyriding key overrides
- `/boltsaved` - Print current-expansion lockouts (Saved Instances module)
- `/copymount` or `/cm` - Summon the same mount as your target (Playground module)
