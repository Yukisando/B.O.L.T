# B.O.L.T

**Brittle and Occasionally Lethal Tweaks**: small quality-of-life upgrades for World of Warcraft. BOLT tidies up Blizzard's own UI with Blizzard's own art and adds a handful of handy tools, without changing how the game plays.

| Game version | Status |
|---|---|
| **WoW: Forever** | ✅ Fully supported, with extra Forever-only features and Forever's bronze UI art |
| **Retail (Midnight 12.1.5)** | ✅ Fully supported |

One download works on both. BOLT detects which game it runs in: features that need modern systems (Skyriding, Mythic+ keys, achievements...) hide themselves on Forever, and Forever-only features hide on Retail.

<!-- Screenshot: overview of a full UI with BOLT (square minimap, Personal Resource Display with pet bar, faded bars) -->

---

## ⭐ New on WoW: Forever

These features only exist on WoW: Forever, built around its classic-style systems:

- **Quick Feed (hunters)**: the pet health bar takes your pet's mood colour (green, amber, red) and softly pulses when your pet is hungry. Click it to feed the cheapest food your pet eats, without opening your bags. Shift-click feeds it any time. Hover it to see the food and your pet's mood.
- **Full Swing Timer**: main hand, off hand and ranged swings, for every class, read from the game's own swing timer.
- **Campfire Rest**: a camp bar counting down to Camp Benefits, right-click a campfire to sit, an alert when the benefits land, and a drawer with every camp object you can place or craft.
- **DoT Overlay**: a striped shield on enemy nameplates shows how much damage your DoTs (and your pet's) will still deal. It turns gold when they alone will finish the mob.
- **Wand & Pet Attack Key**: one key targets the enemy under the mouse, sends your pet in and starts your wand.
- **Hawk and Totem Timers**: your hunter's hawk as a round countdown node above the pet bar.
- **Ammo Count**: after each shot, how many arrows or bullets you have left.
- **Day/Night Dial**: Forever's day/night dial sits inside the square minimap.
- **Bronze Art**: every restyled frame uses Forever's own bronze UI art, so it looks like it shipped with the game.
- **Wowhead Links** point to Wowhead's Forever database.

<!-- Screenshot: Quick Feed pulse + tooltip on the pet bar -->
<!-- Screenshot: Campfire camp bar and drawer -->

---

## Getting started

1. Install from [CurseForge](https://www.curseforge.com/wow/addons/bolt) (or put the `BOLT` folder in `World of Warcraft\_forever_\Interface\AddOns\` or `\_retail_\Interface\AddOns\`).
2. Type `/bolt` in game. **Every feature starts off**: tick the ones you want.
3. Open **Edit Mode** (ESC > Edit Mode) and click a Blizzard frame (minimap, action bars, player frame...). A **B.O.L.T** panel next to the Edit Mode window lists what BOLT can do to that frame.

Your BOLT setup is saved with each Edit Mode layout and shared by all your characters: switch layout and your BOLT setup switches with it.

---

## What's inside

Features marked **Forever** only appear on WoW: Forever; **Retail** ones only on Retail. Everything else works on both.

### Interface

Blizzard's own frames, restyled with Blizzard's own art.

#### Square Minimap

<!-- Screenshot: square minimap with title bar and button bar -->

- A square map in Blizzard's minimap frame, with the zone name and clock in a title bar.
- Tracking, calendar, mail and the other minimap buttons in one tidy bar (bottom, top, left or right).
- Addon buttons go into one drawer that opens on click.
- Coordinates in the corner, a resting Zzz, the day/night dial (**Forever**).
- Optional mouse-wheel zoom.
- **Snug in the corner**: drag the map right against the screen edge, or even partly off screen. It stays there after a reload.
- Pauses itself while SexyMap, BasicMinimap or ElvUI is loaded.

#### Personal Resource Display

<!-- Screenshot: Personal Resource Display with pet bar, target bars and swing sweep -->

Blizzard's health and power bars under your character, made into a complete mini HUD:

- **Pet health bar** above your health bar, coloured by your pet's mood on Forever, with **Quick Feed** (**Forever**). Click it like the Pet Frame.
- **Target bars**: your target's health, plus your target's target on the same row. Clickable like unit frames.
- **Hawk and totem timers** as round nodes above the pet bar.
- **Pet damage share** after each fight, **ammo count** after each shot (**Forever**).
- Show it in combat only, also with a target, or faded to an opacity of your choice.
- **Hide the Player and Target frames** and bring each back in combat, with a target or on hover, for a clean, immersive screen.

#### Swing Timer

- A faint sweep across the Personal Resource Display's bars between your auto attacks, so you can fit casts in between. Floating bars if you prefer.
- **Forever**: main hand, off hand and ranged, every class. **Retail**: Auto Shot only (the game reports no other swings).

#### Unit Frames and Cast Bars

- Player, target, focus, target of target, pet and party frames without the round portrait: the bars widen to fill the space.
- Cast bars with the spell name inside the bar.
- Party members' names in their class colour.
- Raid-style party frames stay centred as people join and leave.

#### Nameplates

- **Interrupt cue**: an enemy cast bar lights up with your interrupt's icon when you can kick it right now.
- **Range hint**: enemies out of your reach get a darker health bar.
- **Target emphasis**: your target's plate grows, the others fade a little.
- **Healer and caster highlight**: enemy mana users in a colour of your choice.
- **Friendly target plate**: only the friend you target shows a nameplate.
- **DoT Overlay** (**Forever**): see above. `/bolt dots` lists what it counts.

#### Auto-hide UI

<!-- Screenshot: Edit Mode with a B.O.L.T panel showing "Fades with" -->

- Put frames (action bars, micro menu, bags, XP bar, buffs, unit frames, quest tracker, minimap, chat) in up to four **fade groups**.
- Each group fades back in by its own rules: mouse over, combat, a target, in a group, in an instance, and not while mounted.
- Set it from any frame in Edit Mode.

#### Small fixes

- The quest tracker remembers whether you collapsed it.

### Gameplay

- **Wand & Pet Attack Key** (**Forever**): one key for wand, pet attack and pet Assist mode.
- **My Damage**: a small, quiet panel with only your numbers: your rank in the group, your dps, and your spells and pets.
- **Cheetah Warning** (hunters): a gentle reminder when you enter combat with Aspect of the Cheetah or the Pack on.
- **Double-Click Fishing**: double right-click the world to cast Fishing.
- **Skyriding** (**Retail**): strafe keys turn while skyriding, with optional pitch control.

### Quality of Life

- **Game Menu buttons**: Leave Group, Reload UI, ready check, pull countdown, raid marker, volume and mute, combat text toggles, and loot spec switching (**Retail**).
- **Campfire Rest** (**Forever**): see above.
- **Auto Rep Switch**: the reputation bar follows the faction you just gained rep with.
- **Saved Instances**: your dungeon and raid lockouts. `/boltsaved`
- **Smart Teleport** (**Retail**): every teleport you own for the zone you're viewing, under the World Map.

### Social

- **Chat**: Blizzard's chat made quiet. No borders or button clutter, text only while you look at it, chat history kept after a reload, copy chat, a sound on new messages, and small popups for whispers, party chat, skill ups, money, rep and XP.
- **Auto Party Chat**: the chat box switches to Party, Raid or Instance when you join a group, and back to Say when you leave.
- **Wowhead Link**: hover almost anything and press Ctrl+C for its Wowhead link.

### Roleplay

- **Transmog Presets**: save looks once and use them on any character.
- **Everyday Emotes**: one key each for Hello, Goodbye, Thanks and Sit, and an automatic thank-you to players who buff you.
- **Total RP 3**: a key to switch In Character / Out of Character, with an optional UI layout for each.

### Extras

- **Playground**: a favourite toy button, a speedometer and FPS display, copy your target's mount (`/cm`).
- **Sound Muter**: mute any game sound by its ID.
- **Character Snapshot**: export your character's stats as JSON.
- **Achievement Tracker** and **Key Share** (**Retail**): achievement progress messages in chat, and `!keys` replies with a keystone roulette.

---

## Settings and commands

- `/bolt` (or `/b`) opens the settings, also at ESC > Options > AddOns > B.O.L.T.
- Frame options live in **Edit Mode**: click a frame and use its B.O.L.T panel.
- Quick on/off toggles in the minimap tracking menu.

| Command | What it does |
|---|---|
| `/bolt` | Open settings |
| `/bolt help` | List all commands |
| `/bolt status` | Which features are on |
| `/bolt transmog` | Transmog Presets |
| `/bolt edge` | What the minimap's screen-edge setting is doing |
| `/bolt dots` | What the DoT Overlay counts on your target (Forever) |
| `/bolt camp` | What the camp bar sees, for bug reports (Forever) |
| `/bolt reset` | Clear stuck Skyriding keys (Retail) |
| `/boltsaved` | Your current lockouts |
| `/cm` | Summon your target's mount |

---

Bugs and ideas: [GitHub issues](https://github.com/Yukisando/B.O.L.T/issues).
