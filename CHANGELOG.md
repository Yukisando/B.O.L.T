# B.O.L.T Changelog
**(Brittle and Occasionally Lethal Tweaks)**

## [Unreleased]
### Added
- **Character Snapshot (Extras)**: New "Export Snapshot (JSON)" button in the Extras tab opens a copy-friendly popup containing a JSON time-capsule of the character — identity, money, /played, collection counts (mounts/pets/toys), achievement points and the full Statistics tab.

### Fixed
- **Skyriding Module**: Druid skyriding flight form now counts as a valid skyriding state, and shapeshift changes trigger an immediate refresh.
- **Sound Muter**: Removed the runtime sound interception and recent-audio browser after they started tainting Blizzard UI flows.

## [2.5.1] - 2026-01-20
### Fixed (Midnight 12.0 compatibility audit)
- **WowheadLink**: Fixed `C_Spell.GetSpellInfo` usage — the API returns a table in Midnight (the deprecated global `GetSpellInfo` is removed); now correctly extracts `.name` from the result table.
- **AutoRepSwitch**: Added `issecretvalue` guard on `CHAT_MSG_COMBAT_FACTION_CHANGE` messages — in Midnight, chat messages received inside instances are Secret Values; comparing them would cause Lua errors. When the message is secret the module now falls back to the snapshot-comparison path. Also registered the new `FACTION_STANDING_CHANGED` event (added in Midnight 12.0.0) as an additional trigger alongside `UPDATE_FACTION` for more reliable reputation change detection.

## [1.5.0] - 2026-01-01
### Added
- **Auto Rep Switch Module**: Automatically switches the watched reputation to the faction you just gained reputation with.


## [1.4.1] - 2025-09-29
### Changed
- **Major Rebranding**: Addon renamed from ColdSnap to B.O.L.T (Brittle and Occasionally Lethal Tweaks)
- **Updated Commands**: New slash commands `/bolt` and `/b` (replaces `/coldsnap` and `/cs`)
- **Updated Database**: SavedVariables now use BOLTDB instead of ColdSnapDB

## [1.4.0] - 2025-09-16
### Changed
- **Skyriding Module**: Major behavior change - overrides now only activate while holding left mouse button
- **Safer Operation**: No more permanent key binding changes that could get stuck
- **User Control**: Full control over when enhanced controls are active

### Fixed
- Resolved held-down key issues in skyriding mode
- Improved safety when exiting skyriding or entering combat
- Better handling of key state conflicts

### Features
- **Mouse-Triggered Controls**: Hold left mouse button to activate enhanced skyriding movement
- **Instant Deactivation**: Release mouse button to immediately return to normal controls
- **Combat Safety**: All overrides automatically cleared when combat starts

## [1.0.7] - 2025-08-30
### Added
- **Playground Module**: New module for fun features with limited practical use
- **Auto Confirm Exit**: Automatically skip the "Are you sure you want to exit game?" confirmation popup

### Changed
- Moved favorite toy feature from Game Menu module to new Playground module
- Reorganized configuration UI with separate sections for Game Menu and Playground modules
- Updated module structure for better organization of practical vs fun features

### Features
- **Game Menu Enhancements**: Leave Group button, Reload UI button, Auto Exit confirmation
- **Playground Module**: Favorite toy button and other fun features
- **Auto Exit Confirmation**: Skip exit confirmation dialog when enabled
- **Modular Configuration**: Separate toggles for practical and fun features

## [1.0.0] - 2025-08-26
### Added
- Leave Group/Raid/Delve button in ESC menu
- Reload UI button in ESC menu top-right corner
- Configuration UI accessible via `/cs` command
- Integration with WoW's Interface > AddOns settings
- Module-based architecture for easy expansion
- Smart group detection (parties, raids, delves, scenarios)
- Leadership transfer before leaving groups

### Features
- **Game Menu Enhancements**: Two toggleable buttons in the ESC menu
- **Leave Group Button**: Automatically detects group type and leaves appropriately
- **Reload UI Button**: Quick UI reload without typing commands
- **Configuration Panel**: Easy toggle switches for all features
- **Smart Detection**: Only shows relevant buttons when in groups/instances

### Technical
- Modular addon architecture
- Per-character saved variables
- Cross-version compatibility
- Debug logging system