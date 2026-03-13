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
- **Battle Text Toggles**: Quick toggles for damage and healing numbers in scrolling combat text
- **Volume Control Button**: Master volume and music control with visual feedback
  - Shows current volume percentage (or "M" when muted) directly on the button
  - Left-click: Toggle mute/unmute master volume
  - Right-click: Toggle music on/off
  - Mouse wheel: Adjust master volume in 5% increments

### Skyriding Module

- **Mouse-Activated Controls**: Hold left mouse button to activate enhanced skyriding controls
- **Enhanced Movement**: While holding mouse, strafe keys (A/D) become horizontal turning
- **Pitch Control**: Optional W/S mapping for pitch up/down movement when mouse is held (3D control)
- **Invert Option**: Reverse pitch controls if preferred (W=dive, S=climb)
- **Safe Operation**: Controls only active while mouse button is held - no permanent key changes

### Playground Module (Fun Features)

- **Favorite Toy Button**: Quick access to your favorite toy from the ESC menu
- **Speedometer**: Display your movement speed in yards/second

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

### Sound Muter Module

- **Mute Specific Sounds**: Add sound IDs to a list and they will be completely silenced in-game
- **Persistent List**: Muted sounds are saved and automatically re-applied on login
- **Easy Management**: Add or remove sound IDs from the config panel with a scrollable list
- **Preview Button**: Test a sound ID before adding it to hear what it is
- **Recent Sounds Detection**: Hooks into PlaySound/PlaySoundFile to capture the last 10 sounds played — click "Recent Sounds" to browse them and mute any entry with one click

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
