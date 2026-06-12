# B.O.L.T

**Brittle and Occasionally Lethal Tweaks** - Quality of life improvements for World of Warcraft that make your gameplay experience smoother without changing core mechanics.

All modules can be toggled independently. New installs start with every module disabled — turn on what you want from the settings panel (`/bolt`) or via the quick toggles in the minimap tracking dropdown.

## Modules

### Interface

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

#### Nameplates Enhancement

- **Mana User Highlighting**: Enemy nameplate health bars are colored for mana-using units (healers/casters), making them easy to spot in packs
- **Combat Persistent**: Colors survive entering combat and threat updates via a secure post-hook on Blizzard's health color system
- **Enemies Only**: Only enemy nameplates are affected — friendly and neutral units keep their default appearance
- **Instance-Only Mode**: Optional toggle to limit nameplate coloring to dungeons, raids, and scenarios
- **Customizable Mana Color**: Pick any color for mana-user nameplates from the config panel

#### Party Frames Center Growth

- **Centered Raid-Style Party Growth**: Keeps raid-style party frames centered instead of visually drifting from a fixed corner as the group fills
- **Dynamic Join/Leave Nudging**: Repositions the party anchor as members join or leave so the layout remains centered for party sizes 1-5
- **Party-Only Scope**: Only affects party raid-style frames; raid group frames are untouched

### Gameplay

#### Skyriding

- **Always-On Controls**: Override bindings activate automatically whenever you are Skyriding in a valid area — no button-holding required by default
- **Optional Mouse-Button Mode**: Configurable option to only apply controls while holding the left mouse button
- **Druid Support**: Detects druid skyriding flight form in addition to regular flying mounts
- **Enhanced Movement**: Strafe keys (A/D) become horizontal turning while Skyriding
- **Pitch Control**: Optional W/S mapping for pitch up/down (3D control)
- **Invert Option**: Reverse pitch controls if preferred (W=dive, S=climb)
- **Safe Operation**: Override bindings are cleared instantly on dismount or when leaving a Skyriding-eligible area — no permanent key changes
- **Emergency Reset**: `/boltreset` (or `/boltnuke`) clears all override bindings if anything ever gets stuck

#### Auto Rep Switch

- **Automatic Watched Faction**: Automatically switches the "watched" reputation bar to whichever faction you just gained reputation with
- **All Factions Supported**: Works across all reputation sources including the modern Renown system
- **Secret Value Safe**: Handles Midnight (12.0) secret-value chat messages gracefully by falling back to snapshot-diff detection

#### Smart Teleport Suggestions

- **World Map Drawer**: When you open the World Map, a small icon drawer appears showing every teleport destination you can currently reach
- **Broad Coverage**: Covers capital cities, expansion hubs, class-specific portals (Mage, Druid, Death Knight, Monk), engineering wormholes, Hero's Path portal spells earned from Keystone Hero achievements, and your Hearthstone
- **Spell & Item Detection**: Checks both spells and bag items, so engineering gadgets and trinkets are included automatically
- **One-Click Cast**: Click any icon to cast the corresponding teleport spell or use the item

#### Saved Instances

- **Instance Lockout Overview**: Lists all current expansion dungeons and raids alongside your lockout status
- **Slash Command**: Type `/boltsaved` to print unsaved instances to chat
- **Color-Coded Output**: Green for unsaved, orange for in-progress, grey for completed

### Social

#### Chat Notifier

- **Channel Sound Alerts**: Plays a notification sound when a new message appears in monitored chat channels
- **Configurable Channels**: Pick which channels to monitor from a checklist (Guild, Party, Raid, Whisper, Say, Yell, Instance, Custom Channels, etc.)
- **Multiple Sound Options**: Choose from several built-in notification sounds with a preview button
- **Throttled Alerts**: Rapid messages are throttled so sounds don't overlap
- **Self-Filtering**: Your own messages are ignored

#### Wowhead Link

- **Quick Wowhead URL**: Press the configured key (default: Ctrl+C) while hovering over an item, spell, or other linkable object to generate its Wowhead URL
- **Copy Popup**: Displays the URL in a small dialog with the text pre-selected so a second Ctrl+C copies it to the clipboard

### Tracking

#### Achievement Progress Tracker

- **Progress Messages**: Prints a chat message whenever an action you perform advances progress on any achievement (e.g. /love a critter, completing a quest, defeating a boss)
- **Category Filter**: Choose which top-level achievement categories to track (defaults to Exploration; select none to track everything)
- **Incremental Scanning**: Scans achievement criteria in small time-budgeted chunks to avoid frame drops, with a minimap spinner while the scan is running
- **Completion Detection**: Recognises when an achievement is fully completed and prunes it from further scanning
- **Throttled Updates**: Rapid criterion changes are debounced so you don't get flooded with messages

### Extras

#### Playground (Fun Features)

- **Favorite Toy Button**: Quick access to your favorite toy from the ESC menu, with a searchable toy picker and an optional "close game menu on cast" setting
- **Speedometer**: Display your movement speed in yards/second, with a configurable screen corner
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

#### Total RP 3 Integration

Requires [Total RP 3](https://www.curseforge.com/wow/addons/total-rp-3) to be installed.

- **IC/OOC Toggle Keybinding**: Bind "Toggle RP Status" (under B.O.L.T in Key Bindings) to flip your Total RP 3 status between In Character and Out of Character with one key
- **Toolbar Visibility**: Optionally show the TRP toolbar while In Character and hide it while Out of Character
- **Edit Mode Profile Switching**: Optionally switch to a chosen Edit Mode (UI layout) profile when going In Character, and a different one when going Out of Character — e.g. a minimal immersive layout for RP and your normal layout otherwise

## Installation

1. Download the addon from [CurseForge](https://www.curseforge.com/wow/addons/bolt) or the GitHub releases
2. Place the `BOLT` folder in your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or type `/reload`

## Configuration

Access settings through:

- **Interface Menu**: ESC > Options > AddOns > B.O.L.T (with Interface, Gameplay, Social, Tracking, Extras, and Roleplay categories)
- **Console Command**: `/bolt` or `/b`
- **Minimap Tracking Menu**: Quick enable/disable toggles for common modules in the minimap tracking dropdown

Each module can be enabled/disabled independently with full configuration options.

## Console Commands

- `/bolt` or `/b` - Open settings panel
- `/boltsaved` - Print unsaved instances to chat (Saved Instances module)
- `/copymount` or `/cm` - Summon the same mount as your target (Playground module)
- `/boltreset` or `/boltnuke` - Emergency reset of Skyriding override bindings
