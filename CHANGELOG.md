# B.O.L.T Changelog

**(Brittle and Occasionally Lethal Tweaks)**

Entries below the marker are added automatically by the release workflow from commit messages — newest first.

<!-- AUTO-CHANGELOG -->

## v7-30 (2026-06-12)

- fix: dispatch package workflow from release so CurseForge upload isn't skipped
- The packager skips branch-push builds whose HEAD commit is tagged
- ('Found future tag'), so packaging in the same push-triggered run never
- uploaded. The release workflow now triggers the package workflow via
- workflow_dispatch, which the packager accepts.
- Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>

## v7-29 (2026-06-12)

- chore: test automated release pipeline (changelog + CurseForge upload)
- Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>

## v7-28 (2026-06-05)

- feat: Add OOC Edit Mode profile selection and update roleplay configuration

## v7-27 (2026-06-03)

- feat: Add roleplay configuration options for TRP toolbar visibility and Edit Mode profile selection

## v7-26 (2026-05-29)

- feat: Add Total RP 3 integration with toggle for RP status and update Skyriding module

## v7-25 (2026-05-16)

- refactor: Remove Smart Ground Mount module and update related configurations

## v7-24 (2026-05-04)

- feat: Update Skyriding module with always-on controls and improved usability features

## v7-23 (2026-05-03)

- refactor: Simplify Skyriding module logic and improve state management

## v7-22 (2026-05-02)

- feat: Add option to require mouse button for Skyriding activation and update UI accordingly

## v7-21 (2026-05-02)

- feat: Add auto-roulette functionality to KeyShare module for random keystone selection

## v7-20 (2026-05-02)

- feat: Add Smart Ground Mount module to summon ground-only mounts in no-fly zones

## v7-19 (2026-05-01)

- feat: Remove InCombatLockdown checks from GameMenu buttons for improved usability

## v7-18 (2026-04-29)

- feat: Add middle-click functionality for dialog audio toggle in volume button

## v7-17 (2026-04-28)

- feat: Add Character Snapshot module with JSON export functionality

## v7-16 (2026-04-24)

- feat: Improve player speed retrieval with error handling for GetUnitSpeed

## v7-15 (2026-04-22)

- Bump verison

## v7-14 (2026-04-10)

- feat: Enhance Battle Rez module with event handling and UI updates for Mythic+ tracker

## v7-13 (2026-04-09)

- feat: Refactor Battle Rez module and enhance Wowhead Link functionality

## v7-12 (2026-04-08)

- feat: Enhance cooldown management for buttons in various modules

## v7-11 (2026-04-04)

- feat: Add Sound Muter module with management popup for muting sound IDs

## v7-10 (2026-04-03)

- feat: Add Battle Rez Counter module and integrate Loot Spec button in Game Menu

## v7-9 (2026-03-31)

- feat: Update keystone link description and enhance KeyShare module functionality

## v7-8 (2026-03-30)

- feat: Add Admin section with button to show password popup in Config module

## v7-7 (2026-03-29)

- feat: Integrate minimap tracking menu for module toggles in Core and remove from AchievementTracker

## v7-6 (2026-03-29)

- feat: Add KeyShare module to link current Mythic+ keystone in chat

## v7-5 (2026-03-29)

- feat: Refactor Config module to improve panel management and section handling

## v7-4 (2026-03-19)

- feat: Add option to close game menu on cast in Playground module and update related configurations

## v7-3 (2026-03-18)

- feat: Remove Sound Muter module and related configurations to streamline functionality

## v7-2 (2026-03-17)

- feat: Implement delayed initialization for modules after player login to reduce UI taint risk

## v7-1 (2026-03-17)

- feat: Delay module initialization until after player login to prevent UI taint issues

## v7-0 (2026-03-17)

- feat: Implement QueueReapplyBurst function for improved party frame updates and integrate with EditModeUnitFrameSystemMixin [major]

## v6-13 (2026-03-17)

- feat: Add Party Frames Center Growth module to enhance party frame alignment and dynamics

## v6-12 (2026-03-17)

-  GameMenu functionality with volume settings

## v6-11 (2026-03-17)

- feat: Enhance database initialization and configuration handling for nameplates and modules

## v6-10 (2026-03-15)

- feat: Add Druid support to Skyriding Module and enhance drawer handling in SmartTeleport module

## v6-9 (2026-03-14)

- feat: Enhance module initialization and Game Menu handling to improve stability and performance during combat

## v6-8 (2026-03-14)

- feat: Update version to 2.5.1 and enhance compatibility with Midnight (12.0) by adjusting API usage and improving event handling across modules

## v6-7 (2026-03-14)

- feat: Update button creation in GameMenu to avoid taint issues and improve event handling in NameplatesEnhancement for better performance

## v6-6 (2026-03-14)

- feat: Improve UI panel handling in GameMenu and SmartTeleport modules to prevent taint issues

## v6-5 (2026-03-14)

- feat: Improve Game Menu positioning and enhance interrupt handling for nameplates

## v6-4 (2026-03-13)

- feat: Simplify nameplate color application by removing recursion and enhancing mana color handling

## v6-3 (2026-03-13)

- feat: Refactor interrupt handling and nameplate color application for improved performance

## v6-2 (2026-03-13)

- feat: Add interrupt warning feature to nameplates with customizable color and cooldown tracking

## v6-1 (2026-03-13)

- feat: Add instance-only mode for nameplate coloring and update descriptions

## v6-0 (2026-03-13)

- [major] new nameplate module

## v5-37 (2026-03-13)

- feat: Add Recent Sounds feature to Sound Muter for easy access to last played sounds

## v5-36 (2026-03-13)

- feat: Refresh sound muter list on module enable and during configuration updates

## v5-35 (2026-03-12)

- feat: Add Sound Muter module to mute specific sound IDs with UI management

## v5-34 (2026-03-12)

- FIXED VOLUME RESET

## v5-33 (2026-03-11)

- feat: Update volume control persistence to use global database for preMuteVolume

## v5-32 (2026-03-11)

- feat: Update map IDs for Silvermoon, The Arcantina, and Quel'Thalas in SmartTeleport module

## v5-31 (2026-03-10)

- feat: Limit displayed teleport suggestions to a maximum number of icons

## v5-30 (2026-03-09)

- feat: Add new teleport locations and update spell/item IDs in SmartTeleport module

## v5-29 (2026-03-09)

- feat: Enhance volume control persistence and update display on volume change

## v5-28 (2026-03-08)

- feat: Adjust achievement tracker UI spacing and close dropdown on selection

## v5-27 (2026-03-08)

- feat: Add "None" option to deselect all tracked achievement categories in the configuration UI

## v5-26 (2026-03-08)

- feat: Add achievement category tracking and rescan functionality in the configuration UI

## v5-25 (2026-03-07)

- Update after .git recovery

## v5-24 (2026-02-27)

- feat: Enhance chat functionality with safe message sending and update teleport pin template

## v5-23 (2026-02-22)

- refactor: Remove Teleports Data Provider, Pin Mixin, and Secure UI modules

## v5-22 (2026-02-22)

- feat: Expand Smart Teleport Suggestions with additional Hero's Path locations

## v5-21 (2026-02-21)

- feat: Add Teleports Data Provider, Pin Mixin, and Secure UI modules

## v5-20 (2026-02-20)

- feat: Add new sound options to Chat Notifier module

## v5-19 (2026-02-19)

- feat: Replace channel checkboxes with a multi-select dropdown in Chat Notifier configuration

## v5-18 (2026-02-15)

- feat: Remove Smart Teleport Suggestions binding and related localization entries

## v5-17 (2026-02-13)

- feat: Add circular border to icon buttons for improved aesthetics

## v5-16 (2026-02-08)

- feat: Implement account-wide module state management and migration from old profile system

## v5-15 (2026-02-08)

- feat: Add multi-select dropdowns for dismount and hardcore channels in admin panel

## v5-14 (2026-02-08)

- Teleport popup no longer prepopulates with keybind letter

## v5-13 (2026-01-31)

- feat: Add PetJournal to Lua diagnostics globals and improve error handling in Wowhead link module

## v5-12 (2026-01-31)

- feat: Enhance Wowhead link functionality to support spell links and improve item ID parsing

## v5-11 (2026-01-31)

- feat: Enhance item retrieval functionality with additional tooltip and frame checks

## v5-10 (2026-01-31)

- feat: Refactor teleport functionality to use secure pins for direct teleportation and update related UI components

## v5-9 (2026-01-31)

- feat: Enhance item retrieval functionality with additional tooltip and frame checks

## v5-8 (2026-01-30)

- Refactor teleport pin implementation and add secure teleport functionality

## v5-7 (2026-01-30)

- feat: Implement secure teleport confirmation popup and refactor teleport handling

## v5-6 (2026-01-30)

- feat: fixed teleport not visible

## v5-5 (2026-01-29)

- feat: Add warning for empty toy list after population attempts

## v5-4 (2026-01-29)

- feat: Add edit mode for teleport pins allowing users to add/remove pins and update UI accordingly

## v5-3 (2026-01-29)

- feat: Update teleport pin functionality with improved visibility and interaction handling

## v5-2 (2026-01-29)

- feat: Enhance packaging workflow with dynamic release type input and remove redundant package job

## v5-1 (2026-01-29)

- feat: Implement teleport functionality with UI options and map integration - Added teleport management UI and functionality - Created Data Provider for WorldMap pins - Introduced TeleportData.lua for default teleport locations - Added TeleportPins.xml for pin templates - Refactored Config and Teleports modules for improved handling - Enhanced teleport list management with user-added entries

## v5-0 (2026-01-29)

- feat: Add teleport management UI and functionality

## v4-28 (2026-01-25)

- Refactor workflow triggers: change package.yml to use workflow_dispatch and update release.yml for version output handling

## v4-27 (2026-01-24)

- Enhance Game Menu and Config: improve panel visibility handling and suppress immediate OnShow behavior

## v4-26 (2026-01-24)

- Enhance Game Menu functionality: add loading completion checks and ensure widgets are hidden when not shown

## v4-25 (2026-01-23)

- Update BOLT.toc

## v4-24 (2026-01-23)

- Refactor release workflow: rename job and improve version tag handling; add packaging step for CurseForge

## v4-23 (2026-01-23)

- Improve version determination logic in release workflow with clearer error messaging

## v4-22 (2026-01-23)

- Refactor release workflow to improve version determination logic and condition checks

## v4-21 (2026-01-23)

- Refactor Config module for improved readability and consistency in function formatting

## v4-5 (2026-01-23)

- Add Auto Rep Switch and Copy Item IDs features to README [major]

---

## Historical notes (pre-automation)

These hand-written entries predate the automated changelog and use the old version scheme.

### [2.5.1] - 2026-01-20

#### Fixed (Midnight 12.0 compatibility audit)

- **WowheadLink**: Fixed `C_Spell.GetSpellInfo` usage — the API returns a table in Midnight (the deprecated global `GetSpellInfo` is removed); now correctly extracts `.name` from the result table.
- **AutoRepSwitch**: Added `issecretvalue` guard on `CHAT_MSG_COMBAT_FACTION_CHANGE` messages — in Midnight, chat messages received inside instances are Secret Values; comparing them would cause Lua errors. When the message is secret the module now falls back to the snapshot-comparison path. Also registered the new `FACTION_STANDING_CHANGED` event (added in Midnight 12.0.0) as an additional trigger alongside `UPDATE_FACTION` for more reliable reputation change detection.

### [1.5.0] - 2026-01-01

#### Added

- **Auto Rep Switch Module**: Automatically switches the watched reputation to the faction you just gained reputation with.

### [1.4.1] - 2025-09-29

#### Changed

- **Major Rebranding**: Addon renamed from ColdSnap to B.O.L.T (Brittle and Occasionally Lethal Tweaks)
- **Updated Commands**: New slash commands `/bolt` and `/b` (replaces `/coldsnap` and `/cs`)
- **Updated Database**: SavedVariables now use BOLTDB instead of ColdSnapDB

### [1.4.0] - 2025-09-16

#### Changed

- **Skyriding Module**: Major behavior change - overrides now only activate while holding left mouse button
- **Safer Operation**: No more permanent key binding changes that could get stuck
- **User Control**: Full control over when enhanced controls are active

#### Fixed

- Resolved held-down key issues in skyriding mode
- Improved safety when exiting skyriding or entering combat
- Better handling of key state conflicts

### [1.0.7] - 2025-08-30

#### Added

- **Playground Module**: New module for fun features with limited practical use
- **Auto Confirm Exit**: Automatically skip the "Are you sure you want to exit game?" confirmation popup

#### Changed

- Moved favorite toy feature from Game Menu module to new Playground module
- Reorganized configuration UI with separate sections for Game Menu and Playground modules

### [1.0.0] - 2025-08-26

#### Added

- Leave Group/Raid/Delve button in ESC menu
- Reload UI button in ESC menu top-right corner
- Configuration UI accessible via `/cs` command
- Integration with WoW's Interface > AddOns settings
- Module-based architecture for easy expansion
- Smart group detection (parties, raids, delves, scenarios)
- Leadership transfer before leaving groups
