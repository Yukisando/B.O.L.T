# ColdSnap Changelog

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