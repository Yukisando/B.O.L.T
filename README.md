# ColdSnap

A World of Warcraft addon that provides quality of life improvements and small tweaks to enhance your gaming experience.

## Features

### Game Menu Enhancements
- **Leave Group Button**: Adds a "Leave Group" or "Leave Raid" button to the in-game exit menu (ESC key) when you're in a party or raid
  - Automatically handles leadership transfer if you're the group leader
  - Only appears when you're actually in a group
  - Smart positioning within the game menu

## Installation

1. Download or clone this repository
2. Place the `ColdSnap` folder in your World of Warcraft AddOns directory:
   - `World of Warcraft\_retail_\Interface\AddOns\ColdSnap`
3. Restart World of Warcraft or type `/reload` if the game is running
4. The addon will automatically load and be ready to use

## Usage

### Basic Commands
- `/coldsnap` or `/cs` - Show help and available commands
- `/coldsnap status` - Display the status of all modules
- `/coldsnap toggle <module>` - Enable/disable specific modules
- `/coldsnap reload` - Reload the UI (same as `/reload`)

### Module Management
- **Game Menu Module**: `gamemenu` or `menu`
  - Controls the leave group button functionality

Example: `/coldsnap toggle menu` - Toggles the game menu enhancements

## Configuration

Configuration is stored per character and persists between sessions. You can use the slash commands to manage settings, or look forward to a future GUI configuration interface.

## Development

### Adding New Features

The addon is designed with a modular architecture. To add new features:

1. Create a new module file in the `Modules/` directory
2. Add the file to `ColdSnap.toc`
3. Register your module using `ColdSnap:RegisterModule("ModuleName", ModuleTable)`
4. Implement `OnInitialize()` and `OnEnable()` methods in your module

### File Structure
```
ColdSnap/
├── ColdSnap.toc          # Addon metadata and file loading order
├── ColdSnap.lua          # Main addon file with slash commands
├── Core/
│   ├── Core.lua          # Core addon framework
│   ├── Database.lua      # Saved variables and configuration
│   └── Utils.lua         # Utility functions
└── Modules/
    └── GameMenu.lua      # Game menu enhancements
```

### API Reference

#### Core Functions
- `ColdSnap:RegisterModule(name, module)` - Register a new module
- `ColdSnap:GetConfig(...)` - Get configuration values
- `ColdSnap:SetConfig(value, ...)` - Set configuration values
- `ColdSnap:IsModuleEnabled(moduleName)` - Check if module is enabled

#### Utility Functions
- `ColdSnap:IsInGroup()` - Check if player is in any group
- `ColdSnap:CanLeaveGroup()` - Check if player can leave current group
- `ColdSnap:LeaveGroup()` - Safely leave current group
- `ColdSnap:GetGroupTypeString()` - Get "Party" or "Raid" string

## Version History

### v1.0.0
- Initial release
- Added game menu "Leave Group" button
- Modular architecture for future expansions
- Configuration system with saved variables
- Slash command interface

## License

This addon is released under the MIT License. Feel free to modify and distribute as needed.

## Contributing

If you'd like to contribute new features or improvements:

1. Fork the repository
2. Create a feature branch
3. Make your changes following the existing code style
4. Test thoroughly in-game
5. Submit a pull request

## Support

For bug reports or feature requests, please create an issue in the repository or contact the addon author in-game.

---

*ColdSnap - Making World of Warcraft a little more comfortable, one quality of life improvement at a time.*
