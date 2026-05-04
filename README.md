# B.O.L.T

**Brittle and Occasionally Lethal Tweaks** - Quality of life improvements for World of Warcraft that make your gameplay experience smoother without changing core mechanics.

## Current Modules

### Game Menu Enhancements

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

### Skyriding Module

- **Always-On Controls**: Override bindings activate automatically whenever you are Skyriding in a valid area — no button-holding required by default
- **Optional Mouse-Button Mode**: Configurable option to only apply controls while holding the left mouse button
- **Druid Support**: Detects druid skyriding flight form in addition to regular flying mounts
- **Enhanced Movement**: Strafe keys (A/D) become horizontal turning while Skyriding
- **Pitch Control**: Optional W/S mapping for pitch up/down (3D control)
- **Invert Option**: Reverse pitch controls if preferred (W=dive, S=climb)
- **Safe Operation**: Override bindings are cleared instantly on dismount or when leaving a Skyriding-eligible area — no permanent key changes

### Playground Module (Fun Features)

- **Favorite Toy Button**: Quick access to your favorite toy from the ESC menu
- **Speedometer**: Display your movement speed in yards/second

### Sound Muter Module

- **Popup-Managed Muting**: Open a management popup from the config panel to add or remove muted sound IDs
- **Immediate Apply/Remove**: Added sound IDs are muted immediately while the module is enabled, and removing an ID unmutes it again
- **Persistent List**: Your muted sound ID list is saved in the addon settings so it survives reloads and relogs

### Character Snapshot

- **JSON Time Capsule**: One-click export of your character's identity, money, /played, collection counts, achievement points and the full Statistics tab as pretty-printed JSON
- **Copy-Friendly Popup**: Opens a read-only text box from the config panel with the JSON pre-selected so Ctrl+C just works
- **Refresh On Demand**: Refresh the popup to re-pull the latest values (e.g. after gaining gold, dying, or logging more /played)

### Chat Notifier Module

- **Channel Sound Alerts**: Plays a notification sound when a new message appears in monitored chat channels
- **Configurable Channels**: Pick which channels to monitor from a checklist (Guild, Party, Raid, Whisper, Say, Yell, Instance, Custom Channels, etc.)
- **Multiple Sound Options**: Choose from several built-in notification sounds with a preview button
- **Throttled Alerts**: Rapid messages are throttled so sounds don't overlap
- **Self-Filtering**: Your own messages are ignored

### Saved Instances Module

- **Instance Lockout Overview**: Lists all current expansion dungeons and raids alongside your lockout status
- **Slash Command**: Type `/boltsaved` to print unsaved instances to chat
- **Color-Coded Output**: Green for unsaved, orange for in-progress, grey for completed

### Nameplates Enhancement Module

- **Mana User Highlighting**: Enemy nameplate health bars are colored for mana-using units (healers/casters), making them easy to spot in packs
- **Combat Persistent**: Colors survive entering combat and threat updates via a secure post-hook on Blizzard's health color system
- **Enemies Only**: Only enemy nameplates are affected — friendly and neutral units keep their default appearance
- **Instance-Only Mode**: Optional toggle to limit nameplate coloring to dungeons, raids, and scenarios
- **Customizable Mana Color**: Pick any color for mana-user nameplates from the config panel

### Party Frames Center Growth Module

- **Centered Raid-Style Party Growth**: Keeps raid-style party frames centered instead of visually drifting from a fixed corner as the group fills
- **Dynamic Join/Leave Nudging**: Repositions the party anchor as members join or leave so the layout remains centered for party sizes 1-5
- **Party-Only Scope**: Only affects party raid-style frames; raid group frames are untouched

### Achievement Tracker Module

- **Progress Alerts**: Shows a raid-warning style on-screen alert whenever you make progress on any tracked achievement
- **Incremental Scanning**: Scans achievement criteria in small time-budgeted chunks to avoid frame drops, with a minimap spinner while the scan is running
- **Completion Detection**: Recognises when an achievement is fully completed and prunes it from further scanning
- **Throttled Updates**: Rapid criterion changes are debounced so you don't get flooded with alerts

### Auto Rep Switch Module

- **Automatic Watched Faction**: Automatically switches the "watched" reputation bar to whichever faction you just gained reputation with
- **All Factions Supported**: Works across all reputation sources including the modern Renown system
- **Secret Value Safe**: Handles Midnight (12.0) secret-value chat messages gracefully by falling back to snapshot-diff detection

### Smart Ground Mount Module

- **No-Fly Zone Awareness**: When you are in an area where flying is not allowed, summons a random ground-only mount from your favorites instead of a flying mount that would walk awkwardly
- **Favorite Mounts Only**: Only considers mounts you have marked as favorites in the Mount Journal
- **Custom Keybinding**: Bind `BOLT Smart Mount` (under B.O.L.T in Key Bindings) in place of your normal "Summon Random Favorite Mount" key
- **Fallback Behavior**: Falls back to the default random-favorite summon when flying is allowed or the module is disabled

### Smart Teleport Suggestions Module

- **World Map Drawer**: When you open the World Map, a small icon drawer appears showing every teleport destination you can currently reach
- **Broad Coverage**: Covers capital cities, expansion hubs, class-specific portals (Mage, Druid, Death Knight, Monk), engineering wormholes, Hero's Path portal spells earned from Keystone Hero achievements, and your Hearthstone
- **Spell & Item Detection**: Checks both spells and bag items, so engineering gadgets and trinkets are included automatically
- **One-Click Cast**: Click any icon to cast the corresponding teleport spell or use the item

### KeyShare Module

- **Auto Key Link**: Responds to `!keys` in party, raid, or guild chat by posting your current Mythic+ keystone link in the same channel
- **Keystone Roulette**: After you post your key in response to `!keys`, opens a 2-second window to collect keystone links from other players who respond, then randomly announces a winner — useful for deciding which key to run

### Wowhead Link Module

- **Quick Wowhead URL**: Press the configured key (default: Ctrl+C) while hovering over an item, spell, or other linkable object to generate its Wowhead URL
- **Copy Popup**: Displays the URL in a small dialog with the text pre-selected so a second Ctrl+C copies it to the clipboard

## Installation

1. Download the addon files
2. Place the `BOLT` folder in your `World of Warcraft\_retail_\Interface\AddOns\` directory
3. Restart WoW or type `/reload`

## Configuration

Access settings through:

- **Interface Menu**: ESC > Interface > AddOns > B.O.L.T
- **Console Command**: `/bolt` or `/b`

Each module can be enabled/disabled independently with full configuration options.

## Console Commands

- `/b` - Open settings panel
- `/bolt` - Open settings panel
