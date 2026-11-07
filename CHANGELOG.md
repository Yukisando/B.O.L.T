# B.O.L.T Changelog

**(Brittle and Occasionally Lethal Tweaks)**

Entries below the marker are added automatically by the release workflow from commit messages — newest first.

<!-- AUTO-CHANGELOG -->

## v8-8 (2026-11-07)

- feat: Camp panel for campfires, Double-Click Fishing
- Campfire Rest (WoW: Forever): the sit prompt is now a camp panel on the right of the screen, across from your party frames
- Campfire Rest: click the panel's title to fold it to one line, right-click to hide it until the next fire
- Campfire Rest: a Sit button, a countdown to Camp Benefits and an In range / Too far badge that learns where the fire warms you
- Campfire Rest: sits down again on its own where the fire warmed you, when it would gain you something
- Campfire Rest: lists your active camp benefits and the time left
- Campfire Rest: your camp gear in one list, click to place it or craft it (BOLT knows every camp recipe)
- Campfire Rest: /bolt camp shows what the panel sees
- Double-Click Fishing: double right-click on the world to cast Fishing

## v8-7 (2026-11-06)

- feat: Shoot Wand Key, fix for the Personal Resource Display fade error
- Shoot Wand Key (WoW: Forever): one key targets the enemy under the mouse, sends your pet in and starts wand Shoot
- Immersive Mode: fixed an error that repeated every frame while the Personal Resource Display was faded

## v8-6 (2026-11-06)

- feat: Campfire Rest, Personal Resource Display fade and menus, clearer resting Zzz
- Campfire Rest (WoW: Forever): while you have the Campfire Nearby buff, a prompt offers to sit by the fire
- Immersive Mode: the Personal Resource Display also shows while you have an attackable target
- Immersive Mode: the Personal Resource Display fades to its own opacity out of combat (10% by default) and shows in full on hover
- Immersive Mode: right-click the Personal Resource Display for your menu, Shift + right-click for your target's
- Minimap: the resting Zzz in the day/night dial is bigger, at full strength and shadowed

## v8-5 (2026-11-06)

- fix: Auto Sell works with Baganator and at every merchant, range dot sits higher
- Auto Sell: Alt + right-click now works on every bag button, including Baganator's
- Auto Sell: junk and listed items are sold reliably when a merchant opens, also with addons that change the merchant window
- Nameplates: the range dot sits a little higher above the health bar

## v8-4 (2026-11-06)

- feat: Auto Sell, Tooltips, nameplate range dots, bare tracking spyglass
- Auto Sell (opt-in, Quality of Life): sells every grey item and everything on your sell list when you open a merchant, then prints the total in chat
- Auto Sell: Alt + right-click an item in your bags to add it to the sell list or take it off; the list is shared by all your characters, listed items show a coin on their bag slot (Blizzard bags and Baganator), and the settings have a Clear Sell List button
- Tooltips (opt-in, Interface): see-through black background instead of Blizzard's dark blue, and no health bar under unit tooltips
- Nameplates: the range hint is now a small dot at the top left of the health bar instead of darkening it: dark red out of reach, yellow in melee range for hunters (too close to shoot), none in reach
- Minimap on WoW: Forever: the tracking button shows the bare spyglass without its black disc
- Ranged Attack Timer: sits under the Personal Resource Display in the same style, or floats below your character when that display is off

## v8-3 (2026-11-06)

- feat: square Minimap, Immersive Mode, Ranged Attack Timer, Nameplates overhaul
- Settings: a new Interface page gathers everything that changes how the UI looks (Unit Frames & Cast Bars, Minimap, Immersive Mode, Ranged Attack Timer, Nameplates, Auto-hide UI, Party Frames Center Growth); Game Menu, Auto Rep Switch, Smart Teleport and Saved Instances moved to a new Quality of Life page
- Minimap (opt-in): square map framed with Blizzard's own minimap art (bronze on WoW: Forever); zone name and clock in a title bar; tracking, calendar, mail, expansion summary, instance difficulty, addon list (a settings cog) and an addon button drawer (three dots) in one bar at the bottom, under the title, or as a left/right column; coordinates inside the map; optional mouse-wheel zoom that zooms back out after 20 seconds
- Minimap on WoW: Forever: the day/night dial moves into the map's corner and shows the player frame's Zzz while you're resting
- Immersive Mode (opt-in): hides the player and target frames and turns on the Personal Resource Display; off brings them back. Also in the minimap tracking menu
- Ranged Attack Timer (opt-in, hunters; on WoW: Forever also wand users): a thin bar under the Cooldown Manager that fills between automatic shots
- Nameplates: target emphasis, unit-frame bar art, an interrupt cue (outline and your interrupt's icon when the cast can be interrupted and your interrupt is ready) and a subtle darker bar for enemies out of reach, on top of the mana-user colors
- Auto-hide UI: the main action bar, micro menu and bags now show together as one strip; other action bars are their own group
- Settings stay in sync when a module is toggled from the tracking menu or /bolt toggle
- "UI Revamp" is now called Unit Frames

## v8-2 (2026-11-05)

- feat: UI Revamp and Auto-hide UI modules, WoW: Forever fixes
- UI Revamp (opt-in): portrait-less player, target, focus, target of target, pet and party frames drawn with Blizzard's own frame art (Forever's c60 art on Forever); the frame stretches over the portrait, the bars widen and fill flush to the borders, the level sits in Blizzard's level circle, and elite/rare dragons wrap the end of the target frame
- UI Revamp: cast bars show the spell name on the bar instead of in a strip underneath; the reaction-colour strip behind target names is gone
- Auto-hide UI (opt-in): action bars, micro menu and bags, experience bar, buffs, debuffs, unit frames, quest tracker, minimap and minimap buttons fade in on hover, with a target or in combat, and stay hidden while mounted or on a flight path unless in combat; always shown in Edit Mode, action bars also while dragging a spell or item; adjustable opacity while hidden
- Game menu round buttons use the native minimap-style ring on WoW: Forever
- Fixed: the game menu said "Leave Delve" on WoW: Forever, and its buttons broke there because the loot specialization button errored (now hidden on Forever)
- Fixed: the raid marker button was blocked by the game; it now uses Blizzard's secure raid-marker action (not available while in combat)
- WoW: Forever is detected from the client version; toy, mount-copy, countdown and Transmog Presets features hide where the game lacks them
- Settings: multi-select dropdowns and Blizzard's own slider for the new modules

## v8-1 (2026-11-01)

- fix: Skyriding keys no longer get stuck turning after landing mid-turn
- While A/D (or W/S with pitch control) is held, the key overrides now wait until you release it before switching, so the release reaches Turn/Pitch and the movement stops. Taking off while holding a key no longer leaves you strafing either
- Landing in combat can't be handled that way (addons can't change bindings in combat); a stuck key there is detected and fixed by tapping it once after combat
- Fixed the remap never applying in v8-0: the secure snippet couldn't read the key list because its attribute names started with "_"

## v8-0 (2026-11-01)

- refactor: overhaul for Midnight 12.1.5 and WoW: Forever [major]
- Supports Midnight 12.1.5 (120105) and WoW: Forever (16001) from one TOC; modules that need modern-only systems (Skyriding, Key Share, Smart Teleport, Achievement Tracker) hide themselves on Forever
- Skyriding now switches key overrides through a secure state driver, so A/D and W/S return to normal the moment you land, even in combat
- Settings rebuilt from declarative tables on non-deprecated templates; the settings page now appears in Options without typing /bolt first
- Admin panel and hardcore/dismount chat triggers work again; settings are saved account-wide and the password typed in chat is no longer sent to the channel
- Transmog Presets ported to Midnight's outfit API: presets are staged in the transmog window and confirmed with Blizzard's Apply button
- Auto Rep Switch uses FACTION_STANDING_CHANGED, so it also works in instances and detects every gain (not only rank-ups)
- Achievement Tracker no longer hitches (time budget was 500 ms per frame instead of ~2 ms) and can't get stuck after a scan error; un-ticking Exploration now persists
- Toy picker restores your Toy Box filters after scanning instead of changing them
- Wowhead links cover toys, mounts, auras, currencies, NPCs, quests and achievements, use the Forever database on Forever, and only claim Ctrl+C if it is unbound
- Smart Teleport works again after being disabled and re-enabled
- Fixed: settings that defaulted to true could not be turned off; Copy Target Mount wrongly reported uncollected mounts; Edit Mode switching no longer taints Edit Mode; missing TRP3 keybinding name
- Shared helpers for dialogs, chat sending and the game menu watcher; removed dead code

## v7-30 (2026-06-12)

- fix: dispatch package workflow from release so CurseForge upload isn't skipped
- The packager skips branch-push builds whose HEAD commit is tagged
- ('Found future tag'), so packaging in the same push-triggered run never
- uploaded. The release workflow now triggers the package workflow via
- workflow_dispatch, which the packager accepts.

## v7-29 (2026-06-12)

- chore: test automated release pipeline (changelog + CurseForge upload)

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
