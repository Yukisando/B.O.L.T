# ColdSnap Changelog

## [1.2.0] - 2025-09-01
### Added
- **Mythic Plus Module**: New module with keystone window enhancements
- **Ready Check & Countdown Buttons**: Two small buttons on the keystone window for easy ready checks and pull countdowns
- **Smart Positioning**: Buttons appear at the top left of the keystone socket window with game-consistent styling

### Removed
- **Auto Confirm Exit**: Removed this feature as it may not work reliably with WoW's protected popup system and could interfere with other addons

### Changed
- Cleaned up Game Menu module by removing auto-confirm exit functionality
- Updated configuration UI to remove auto-confirm exit option
- Enhanced slash commands to support mythic+/keystone module toggle

### Features
- **Game Menu Enhancements**: Leave Group button, Reload UI button
- **Playground Module**: Favorite toy button and other fun features
- **Mythic Plus Module**: Ready check and countdown buttons on keystone window
- **Modular Configuration**: Separate toggles for all feature categories

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