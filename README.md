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

- **Mouse-Activated Controls**: Hold left mouse button to activate enhanced skyriding controls
- **Druid Support**: Detects druid skyriding flight form in addition to regular flying mounts
- **Enhanced Movement**: While holding mouse, strafe keys (A/D) become horizontal turning
- **Pitch Control**: Optional W/S mapping for pitch up/down movement when mouse is held (3D control)
- **Invert Option**: Reverse pitch controls if preferred (W=dive, S=climb)
- **Safe Operation**: Controls only active while mouse button is held - no permanent key changes

### Playground Module (Fun Features)

- **Favorite Toy Button**: Quick access to your favorite toy from the ESC menu
- **Speedometer**: Display your movement speed in yards/second

### Sound Muter Module

- **Popup-Managed Muting**: Open a management popup from Extras to add or remove muted sound IDs
- **Immediate Apply/Remove**: Added sound IDs are muted immediately while the module is enabled, and removing an ID unmutes it again
- **Persistent List**: Your muted sound ID list is saved in the addon settings so it survives reloads and relogs

### Character Snapshot

- **JSON Time Capsule**: One-click export of your character's identity, money, /played, collection counts, achievement points and the full Statistics tab as pretty-printed JSON
- **Copy-Friendly Popup**: Opens a read-only multi-line text box from Extras with the JSON pre-selected so Ctrl+C just works
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
