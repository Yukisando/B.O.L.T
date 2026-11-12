-- BOLT DoT tracking
-- Follows your DoTs on each mob and works out the damage they still have to deal, for the nameplate DoT overlay.
--
-- In WoW: Forever, target health, player stats and auras are secret in combat and the combat log is closed to
-- addons, so addon code can never compare "health vs DoT damage" itself. What stays readable:
--   * our own casts (UNIT_SPELLCAST_SUCCEEDED) and spell descriptions -> which DoT, base damage, duration
--   * UNIT_COMBAT hits on units -> their school and timing (amounts are secret in combat)
--   * the damage meter's per-spell totals after combat -> real average tick sizes
-- StatusBars accept secret values, so the "damage >= health" comparison is done by widgets
-- (Modules/NameplatesEnhancement.lua), not by Lua.

local ADDON_NAME, BOLT = ...
local ns = BOLT.DotTracking

local UPDATE_INTERVAL = 0.1
local DEFAULT_TICK_INTERVAL = 3
-- Seconds either side of an expected tick time. Observed on Forever: the first tick lands within ~0.1s of one
-- interval after the cast, and later ticks within ~0.1s of the first tick's rhythm. Tight windows keep melee
-- auto-attacks (same Physical school as bleeds, similar size, ~1s rhythm) from passing as ticks.
local TICK_MATCH_WINDOW = 0.45
local TICK_MATCH_WINDOW_ANCHORED = 0.25
local MISSED_TICKS_BEFORE_DROP = 2  -- a DoT that never ticks was resisted/immune
-- Projectile DoTs start when the projectile lands, not on the cast event: Serpent Sting's first tick came
-- 3.6-3.9s after the cast instead of 3s (log 253548.7, 12 casts). Their first tick may be this much later.
local PROJECTILE_TRAVEL = 1.5
local PROJECTILE_DOTS = {
    ["Serpent Sting"] = true, ["Fireball"] = true, ["Pyroblast"] = true, ["Frostfire Bolt"] = true,
}
-- Once a DoT's tick size is known, same-school hits further off than this are someone else's (the Imp's
-- Firebolt next to Immolate, white hits next to Rip). Ticks within one cast barely vary (15,15,15,16);
-- the minimum slack of 1 covers rounding (3 vs 4).
local TICK_AMOUNT_TOLERANCE = 0.25
-- Check for the first tick against a size learned on an earlier cast (gear/AP may have changed a little).
local FIRST_TICK_AMOUNT_TOLERANCE = 0.3
-- A crit tick is 1.5-2x a normal one; anything else flagged as a crit (white-hit crits) isn't this DoT.
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
local DB_VERSION = 5                -- bump to discard learned data from older, buggier versions

-- Tick intervals that differ from the 3s default and aren't stated in the description.
local KNOWN_TICK_INTERVALS = {
    ["Insect Swarm"] = 2,
    ["Curse of Agony"] = 2,
    ["Bane of Agony"] = 2, -- Forever's name for Curse of Agony
    ["Fireball"] = 2,
    ["Holy Fire"] = 2,
    ["Rip"] = 2,
    ["Rupture"] = 2,
}

-- DoTs whose ticks aren't even: each tick is the average tick times its factor (factors average 1, so the
-- tooltip total still holds). Agony is back-loaded; seen in-game on Forever (log 166015.8, 72 over 24s):
-- ticks 3,3,3,3 then 6,6,... then 9s. Everything else ticks evenly.
local TICK_SHAPES = {}
do
    local agony = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
    TICK_SHAPES["Bane of Agony"] = agony -- Forever's name
    TICK_SHAPES["Curse of Agony"] = agony
end

-- Descriptions that don't name their school (Siphon Life's, and in Chinese also Corruption's, Fireball's and
-- Pyroblast's periodic part).
local SCHOOL_BY_NAME = {
    ["Siphon Life"] = 32, ["Corruption"] = 32, ["Fireball"] = 4, ["Pyroblast"] = 4,
}

-- Read like DoTs but aren't one on the current target: ground/area effects, channels, traps, and
-- delayed damage (Wyvern Sting only starts after the sleep).
local IGNORED_SPELLS = {
    ["Rain of Fire"] = true, ["Hellfire"] = true, ["Blizzard"] = true, ["Flamestrike"] = true,
    ["Consecration"] = true, ["Hurricane"] = true, ["Volley"] = true,
    ["Drain Life"] = true, ["Drain Soul"] = true, ["Drain Mana"] = true, ["Health Funnel"] = true,
    ["Mind Flay"] = true, ["Arcane Missiles"] = true, ["Starshards"] = true,
    ["Explosive Trap"] = true, ["Wyvern Sting"] = true,
}

-- Traps that put a DoT on the first enemy to walk in. Placing one only arms it (the trap, not the player, casts
-- the DoT when it springs, so no cast event says when or on whom); the DoT starts on the mob that takes the
-- first plausible unmatched tick of its school while it's armed. See springTrap.
local TRAP_DOTS = { ["Immolation Trap"] = true }

-- The name-keyed tables also answer to the names of every registered language, and on ADDON_LOADED to the names
-- this client reports for them (Languages.lua).
local NAME_TABLES = { KNOWN_TICK_INTERVALS, TICK_SHAPES, SCHOOL_BY_NAME, IGNORED_SPELLS, PROJECTILE_DOTS, TRAP_DOTS }
ns.locale.addNames(NAME_TABLES)

local SCHOOL_MASKS = {
    Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64,
    Frostfire = 4 + 16, -- Forever's Frostfire Bolt: combined schools report as the OR of their masks
}

-- Settings, saved with the learned tick sizes in BOLTDB.dotTracking. waitFirstTick is set from BOLT's
-- "Count a DoT only once its first tick has landed" option.
local DEFAULTS = {
    waitFirstTick = "always",
    estimateDuringCast = true,
    debug = false,
}

-- "Wait for first tick": whether a DoT counts toward the marker before its first tick has landed.
-- "unsure" = only when the starting estimate is shaky (finisher with unknown combo points, or no tick size
-- learned yet for that spell).
local WAIT_MODES = {
    { id = "off",    label = "Never (estimate straight away)" },
    { id = "unsure", label = "When unsure" },
    { id = "always", label = "Always (real ticks only)" },
}

local MAX_TRACE_LINES = 500

local db
local dotsByTarget = {}     -- targetKey -> { [spellName] = dot }
local warnedSecretGuid = false

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local T = ns.locale.T

local function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99BOLT|r " .. msg)
end

-- Always recorded to SavedVariables (db.log) for diagnosing accuracy; echoed to chat when db.debug is set.
local function trace(msg)
    if not db then return end
    table.insert(db.log, string.format("%.1f %s", GetTime(), msg))
    if #db.log > MAX_TRACE_LINES then table.remove(db.log, 1) end
    if db.debug then print("|cff888888" .. msg .. "|r") end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- The nameplate token ("nameplate3") of the mob behind `unit`, or nil (no plate, plates off, or unreadable).
-- Reported for Forever's instances: creature GUIDs are secret there, but a
-- mob keeps its nameplate token from NAME_PLATE_UNIT_ADDED to NAME_PLATE_UNIT_REMOVED, and
-- C_NamePlate.GetNamePlateForUnit("target") still finds the target's plate. So the token stands in for the GUID
-- while the plate is up; the nameplate events drop its DoTs before the token goes to another mob.
local function plateTokenFor(unit)
    if type(unit) == "string" and unit:match("^nameplate%d+$") then return unit end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate or isSecret(plate) or type(plate) ~= "table" then return nil end
    local token = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
    if type(token) ~= "string" or isSecret(token) or not token:match("^nameplate%d+$") then return nil end
    return token
end

-- Stable key for the mob behind a unit token, or nil if the unit can't be tracked: its GUID when readable (open
-- world); "plate:nameplateN" when the GUID is secret (instances) and the mob has a nameplate; "target" as the last
-- resort (secret GUID, no plate: only the current target is tracked, and target changes drop its DoTs).
-- The same hit arrives for target, nameplateN and focus, and their GUIDs may not all be readable, so a hidden GUID
-- only affects that one unit token.
local function unitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) then return guid end
    local token = plateTokenFor(unit)
    if token then
        if warnedSecretGuid ~= "plate" then
            warnedSecretGuid = "plate"
            trace("Mob GUIDs are secret here (instance?); tracking each mob by its nameplate instead")
        end
        return "plate:" .. token
    end
    if unit ~= "target" then return nil end
    if warnedSecretGuid ~= "target" then
        warnedSecretGuid = "target"
        trace("Target GUID is secret and it has no nameplate; tracking DoTs on the current target only"
            .. " (turn on enemy nameplates to track several mobs)")
    end
    return "target"
end

local function spellNameAndDescription(spellID)
    local name, desc
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    else
        name = GetSpellInfo(spellID)
    end
    local descFn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if descFn then desc = descFn(spellID) end
    return name, desc
end

local function schoolFromWords(words)
    local school = SCHOOL_MASKS.Physical
    for word in words:gmatch("%a+") do
        if SCHOOL_MASKS[word] then school = SCHOOL_MASKS[word] end
    end
    return school
end

-- Finishers (Rip, Rupture) list their DoT per combo point:
--   "1 point : 243 damage over 12 sec. 2 points: 396 damage over 12 sec. ..."   (Rip; note the stray space)
--   "1 point: 25 damage over 8 secs\n ... 5 points: 87 damage over 16 secs"      (Rupture)
-- Returns total, school, duration for the given points (clamped to the listed range), or nil if the
-- finisher has no per-point DoT (e.g. Eviscerate).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+) damage over (%d+%.?%d*) sec") do
        local points = tonumber(pointsText)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, SCHOOL_MASKS.Physical, entry.duration
end

-- Returns total damage, school mask, duration and (if the description states it) tick interval.
--   "... 10 Nature damage over 15 sec."  Takes the last such clause, so Immolate's
--       "11 Fire damage and then an additional 20 Fire damage over 15 sec" yields the periodic part.
--   "Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec."  (Siphon Life)
-- comboPoints is only used for finishers. (Rake/Garrote merely award a combo point, so finishers are
-- recognised by "Finishing move", not "combo point".)
local function parseDot(desc, comboPoints)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    if desc:find("Finishing move") then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon enchants (rogue poisons) describe a proc DoT but aren't cast on the target. Match the enchant
    -- wording only: Lacerate's tooltip also mentions "weapon damage".
    if desc:find("[Cc]oats a weapon") then return nil end
    -- Heals over time: Forever's Renew reads "Heals the target of 830 damage over 15 sec".
    if desc:find("^Heals") then return nil end

    local total, school, duration
    for amount, words, secs in desc:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration > 0 then return total, school, duration end

    local amount, words, every = desc:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    if not amount then
        amount, every = desc:match("(%d+) health.-every (%d+%.?%d*) sec")
        words = ""
    end
    local lasts = desc:match("[Ll]asts (%d+%.?%d*) sec")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolFromWords(words), lasts, every
        end
    end
    -- Not English DoT wording: try the registered languages (Languages.lua).
    return ns.locale.parseDot(desc, comboPoints or 5)
end

-- The upfront hit of a spell that also leaves a DoT: the damage named before the DoT's own clause, averaged for a
-- range. English: "11 Fire damage and then an additional 20 Fire damage over 15 sec" (Immolate), "19 damage and an
-- additional 39 damage over 9 sec" (Rake), "20 Fire damage immediately and 28 Fire damage over 12 sec" (Flame
-- Shock). German, before "sowie": "fügt ihm 11 Feuerschaden sowie ...", "9 bis 11 Punkt(e) Arkanschaden sowie ...".
-- 0 when there is none. nil for other languages: an upfront hit can't be told apart there, and the damage meter
-- would teach it to the DoT (learnFromMeter skips such a spell).
local function upfrontIn(head, rangeWord, damageWord)
    local lo, hi = head:match("(%d+) " .. rangeWord .. " (%d+)")
    if lo then return (tonumber(lo) + tonumber(hi)) / 2 end
    return tonumber(head:match("(%d+)[^%d]-" .. damageWord)) or 0
end

local function parseDirectPart(desc)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    if desc:find("damage") or desc:find("health") then
        -- The DoT's clause is the last "<n> ... damage over <n> sec" (not Wrack's "damage over time effects");
        -- what comes before it is the upfront part.
        local clauseAt
        for at in desc:gmatch("()%d+[%a ]-damage over %d") do clauseAt = at end
        if not clauseAt then return 0 end
        return upfrontIn(desc:sub(1, clauseAt - 1), "to", "damage")
    end
    if desc:find("chaden") then
        local head = desc:match("^(.-)%f[%a]sowie%f[%A]")
        if not head then return 0 end
        return upfrontIn(head, "bis", "[Ss]chaden")
    end
    return nil
end

---------------------------------------------------------------------------
-- DoT tracking
---------------------------------------------------------------------------

-- Best known average damage per tick: observed average of non-crit ticks, else learned from earlier casts,
-- else the description. Crits are one-offs, so they never raise the expectation for later ticks. For shaped
-- DoTs (TICK_SHAPES) ticks are stored divided by their factor, so this is the average tick, not the latest.
-- Before its own first tick a DoT keeps the size it was applied with (learnedAtApply): the store is shared by
-- every mob, so another mob's tick (a different debuff set) must not move this one's marker. A DoT applied with
-- nothing learned still picks up a size learned since; Reset, Forget and a relearn drop the snapshot
-- (dropSnapshots).
local function expectedTick(dot)
    if dot.normalTicks > 0 then return dot.tickSum / dot.normalTicks end
    return dot.learnedAtApply or (dot.tickKey and db.ticks[dot.tickKey]) or (dot.total / dot.totalTicks)
end

-- Which tick of the DoT (1 = first) lands around `when`.
local function tickNumberAt(dot, when)
    return math.max(1, math.floor((when - dot.appliedAt) / dot.interval + 0.5))
end

-- The factor for tick `number` (1 for evenly ticking DoTs). Shapes are stretched to the DoT's tick count.
local function tickShape(dot, number)
    local shape = dot.shape
    if not shape then return 1 end
    local i = math.ceil(math.min(math.max(number, 1), dot.totalTicks) / dot.totalTicks * #shape)
    return shape[math.max(1, math.min(i, #shape))]
end

-- A waiting DoT doesn't count toward the marker until its first tick lands (see WAIT_MODES).
-- A doubtful DoT (an avoid right after the cast that may not have been its own) always waits.
local function isWaiting(dot)
    if dot.ticksSeen > 0 then return false end
    if dot.doubtful or db.waitFirstTick == "always" then return true end
    return db.waitFirstTick == "unsure" and dot.unsure
end

-- Real tick sizes from Blizzard's damage meter. Forever hides UNIT_COMBAT amounts in combat, so ticks
-- are matched on school and timing and teach no size. After combat the damage meter's per-spell totals are
-- readable, so each DoT's total over the ticks counted this combat is its real average tick (Agony's ticks are
-- weighted by their shape factors). A spell's upfront hit (Immolate) is in the same total: it's split off in the
-- description's proportion. combatTally: learned-size key -> what this combat counted (its casts' DoTs too);
-- combatUntracked: spells cast at no known mob; combatReadable: keys a readable tick taught this combat. The meter
-- counts every mob, the tally only what was seen, so learnFromMeter only learns when the two can match.
local combatTally, combatUntracked, combatReadable = {}, {}, {}

-- This combat's tally, and a fresh one for the next (a new pull right after must not mix into it).
local function takeCombatTally()
    local counted = { keys = combatTally, untracked = combatUntracked, readable = combatReadable }
    combatTally, combatUntracked, combatReadable = {}, {}, {}
    return counted
end

local function tallyFor(dot)
    if not dot.tickKey then return nil end
    local t = combatTally[dot.tickKey]
    if not t then
        t = { spellID = dot.spellID, name = dot.name, factors = 0, ticks = 0, direct = 0,
            descTick = dot.total / dot.totalTicks, dots = {} }
        combatTally[dot.tickKey] = t
    end
    return t
end

-- direct nil: the description's upfront hit can't be told apart (another client language).
local function tallyCast(dot, direct)
    local t = tallyFor(dot)
    if not t then return end
    t.dots[#t.dots + 1] = dot
    if direct == nil then t.unclear = true else t.direct = t.direct + direct end
end

local function tallyHiddenTick(dot, factor)
    local t = tallyFor(dot)
    if t then
        t.factors = t.factors + factor
        t.ticks = t.ticks + 1
    end
end

-- Combo points, for finishers. By UNIT_SPELLCAST_SUCCEEDED they're already spent, so they're read when the
-- cast is sent. They were unreadable in combat on the Forever beta, so the addon also counts them itself:
-- builders say "Awards N combo point(s)" in their tooltips; a dodge/parry/miss right after takes them back;
-- a finisher or a target change resets the count. If neither source knows, finishers assume the lowest
-- entry, so the estimate errs low (no false skull) and nothing is learned from that cast.
local COMBO_CAP = 5
local COMBO_CACHE_SECONDS = 3
local comboAtSend, lastComboPoints, lastComboAt = nil, nil, 0
local countedPoints = 0

-- Cast outcomes. UNIT_COMBAT reports a dodge/parry/miss/resist/immune on the target, but not which attack it
-- belongs to. A cast's own result arrives almost at once (same frame in the logs), so the first outcome on the
-- target right after a cast decides: a hit means it landed, an avoid means it didn't. A melee auto-attack
-- avoided in that instant is rare; it makes the addon drop a DoT that landed, which errs low (never a false
-- kill). Results can also arrive just before the cast event, hence the short look-back.
local OUTCOME_WINDOW = 0.4
local OUTCOME_LOOKBACK = 0.25
local AVOIDED_ACTIONS = {
    MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true, DEFLECT = true, RESIST = true, REFLECT = true,
}
-- Spells can't be dodged or parried: next to a spell DoT, these were someone's melee (usually the pet's).
local MELEE_ONLY_AVOIDS = { DODGE = true, PARRY = true, DEFLECT = true }
local lastBuilder    -- { key, points, at }: builder whose outcome isn't known yet
-- A DoT with a direct part (Rake, Immolate) gets two results: the direct part can hit while the DoT itself is
-- IMMUNE (a bleed on a mob immune to bleeds). So a cast whose direct part hit stays pending (landedAt) for the
-- rest of its window, and only an IMMUNE can still remove its DoT.
local lastDotCast    -- { key, name, dot, previous, at, landedAt, comboRead }: DoT cast whose outcome isn't known yet
-- A finisher DoT dropped for an avoid, until the combo points say whose avoid it was (see removeAvoidedDot).
local FINISHER_CHECK_DELAY = 0.5
local finisherCheck  -- { cast, dot, replaced, action, school, at }
local lastOutcome    -- { key, avoided, action, school, at, immune }: most recent outcome on a mob; a hit keeps
                     -- an IMMUNE just before it in .immune
local armedTrap      -- { spellID, name, total, school, duration, interval, placedAt, expiresAt }: see TRAP_DOTS
-- The mob each cast was aimed at, by cast GUID, taken when the cast is sent. An instant DoT's
-- UNIT_SPELLCAST_SUCCEEDED comes a server round trip later, and a player who tabs to the next mob straight
-- away has changed target by then: the DoT used to be put on the new target.
local sentTargets = {} -- castGUID -> { key, at }
local SENT_TARGET_SECONDS = 10

local function describeReading(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if isSecret(value) then return "secret" end
    return tostring(value)
end

-- The combo points the game's own display shows (ComboFrame, a lit ComboPointN.Highlight per point), for when the
-- number itself is secret: the display stays readable in combat. 0 when the frame is hidden, nil if unreadable.
-- Unverified in-game here.
local function displayedComboPoints()
    local frame = _G and _G.ComboFrame
    if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return nil end
    local ok, shown = pcall(frame.IsShown, frame)
    if not ok or isSecret(shown) then return nil end
    if not shown then return 0 end
    local count = 0
    for index = 1, 12 do
        local point = _G["ComboPoint" .. index]
        local highlight = type(point) == "table" and point.Highlight
        if type(highlight) ~= "table" or type(highlight.GetAlpha) ~= "function" then break end
        local okV, visible = pcall(point.IsShown, point)
        local okA, alpha = pcall(highlight.GetAlpha, highlight)
        if not okV or not okA or isSecret(visible) or isSecret(alpha) then return nil end
        if type(alpha) ~= "number" then return nil end
        if visible and alpha > 0.5 then count = count + 1 end
    end
    return count
end

-- Returns the best plain reading (or nil) and a description of what each API returned, for the log.
local function readComboPoints()
    local best, parts = nil, {}
    local function consider(label, ok, points)
        table.insert(parts, label .. "=" .. describeReading(ok, points))
        if ok and type(points) == "number" and not isSecret(points) then best = math.max(best or 0, points) end
    end
    if GetComboPoints then consider("GetComboPoints", pcall(GetComboPoints, "player", "target")) end
    if UnitPower and Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        consider("UnitPower", pcall(UnitPower, "player", Enum.PowerType.ComboPoints))
    end
    -- Only when neither API gave a number (secret in combat): the display is read by appearance, so it must
    -- never raise a readable count (too many points would mean a too-high estimate, a false kill icon).
    if best == nil then
        consider("display", true, displayedComboPoints())
    else
        table.insert(parts, "display=not needed")
    end
    return best, table.concat(parts, " ")
end

local function rememberComboPoints()
    local points = readComboPoints()
    if points and points > 0 then lastComboPoints, lastComboAt = points, GetTime() end
    return points
end

local function isFinisherDescription(desc)
    return type(desc) == "string" and not isSecret(desc)
        and (desc:find("Finishing move") ~= nil or ns.locale.isFinisher(desc))
end

-- The mob a cast is going to. UNIT_SPELLCAST_SENT only names it, so a cast whose name matches the focus but not
-- the target (a /cast [@focus] macro) goes on the focus, and one whose name
-- matches the soft enemy (a mouseover or soft-target cast) goes on that. A same-named target wins, as before. A
-- focus or soft enemy whose GUID is secret can't be tracked, so that cast is skipped (false), not put on the target.
-- A friendly hard target never takes a cast: with one selected, the soft enemy is the cast's default mob.
-- Blizzard's own Mouseover Cast (Options > Combat, no macro): with it on and its key held (or none set), a cast
-- goes on the mob under the mouse whatever the target is, so names can't tell: in a pack every mob shares the
-- target's name. True only when the client says so plainly.
local function nativeMouseoverCast()
    local getCVar = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
    if not getCVar then return false end
    local ok, enabled = pcall(getCVar, "enableMouseoverCast")
    if not ok or isSecret(enabled) or not enabled then return false end
    if GetModifiedClick then
        local okKey, key = pcall(GetModifiedClick, "MOUSEOVERCAST")
        if okKey and key == "NONE" then return true end
    end
    if not IsModifiedClick then return false end
    local okHeld, held = pcall(IsModifiedClick, "MOUSEOVERCAST")
    return okHeld and not isSecret(held) and held == true
end

local function sentTargetKey(targetName)
    -- An attackable, living mouseover mob takes a native mouseover cast, unless the cast names some other mob.
    if nativeMouseoverCast() then
        local okA, attackable = pcall(UnitCanAttack, "player", "mouseover")
        local okD, dead = pcall(UnitIsDeadOrGhost, "mouseover")
        local okN, name = pcall(UnitName, "mouseover")
        local named = type(targetName) ~= "string" or isSecret(targetName) or targetName == ""
            or (okN and not isSecret(name) and name == targetName)
        if okA and not isSecret(attackable) and attackable == true and not (okD and dead == true) and named then
            local key = unitKey("mouseover")
            if key then return key end
        end
    end
    local okAttack, attackable = pcall(UnitCanAttack, "player", "target")
    -- With action targeting the corpse of the last kill can stay the hard target while the next mob (often of the
    -- same name) is the soft enemy: a corpse can't be cast at, so the cast goes to the soft enemy.
    local okDead, dead = pcall(UnitIsDeadOrGhost, "target")
    local targetDead = okDead and not isSecret(dead) and dead == true
    local targetKey
    if (okAttack and not isSecret(attackable) and attackable == false) or targetDead then
        targetKey = unitKey("softenemy")
    else
        -- Attackable, or the client cannot say: keep the old target behaviour.
        targetKey = unitKey("target")
    end
    if type(targetName) ~= "string" or isSecret(targetName) or targetName == "" then return targetKey end
    local function nameOf(unit)
        local ok, name = pcall(UnitName, unit)
        if ok and type(name) == "string" and not isSecret(name) then return name end
    end
    if not targetDead and nameOf("target") == targetName then return targetKey end
    if nameOf("focus") == targetName then return unitKey("focus") or false end
    -- A mouseover/soft-target cast names the soft enemy even while an attackable hard target is selected.
    if nameOf("softenemy") == targetName then return unitKey("softenemy") or false end
    -- A /cast [@mouseover] macro names the mob under the mouse, which is the soft enemy only with soft targeting
    -- on.
    if nameOf("mouseover") == targetName then return unitKey("mouseover") or false end
    return targetKey
end

local function onCastSent(spellID, castGUID, targetName)
    local now = GetTime()
    for guid, sent in pairs(sentTargets) do
        if now - sent.at > SENT_TARGET_SECONDS then sentTargets[guid] = nil end
    end
    if castGUID and not isSecret(castGUID) then
        sentTargets[castGUID] = { key = sentTargetKey(targetName), at = now }
    end
    local ok, _, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not isFinisherDescription(desc) then return end
    local points, readings = readComboPoints()
    comboAtSend = points
    trace("COMBO at send: " .. readings .. ", counted=" .. countedPoints)
end

-- The mob a cast went to: the target when it was sent, else (no send seen) the target now.
local function castTargetKey(castGUID)
    local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
    if not sent then return unitKey("target") end
    sentTargets[castGUID] = nil
    return sent.key
end

-- An avoid on `key` that arrived just before the cast event (see OUTCOME_LOOKBACK), or nil. With
-- includeImmune, also an IMMUNE followed by a hit (a DoT's direct part landed, the DoT didn't); builders leave
-- it out, since their direct part landing awarded the points.
local function avoidJustBefore(key, includeImmune)
    if not lastOutcome or lastOutcome.key ~= key then return nil end
    local now = GetTime()
    if lastOutcome.avoided and now - lastOutcome.at <= OUTCOME_LOOKBACK then return lastOutcome end
    local immune = includeImmune and lastOutcome.immune
    if immune and now - immune.at <= OUTCOME_LOOKBACK then return immune end
end

-- A builder was cast: count its points unless it was already avoided, else wait for its outcome.
local function onBuilderCast(key, points)
    local avoided = avoidJustBefore(key)
    if avoided then
        trace("COMBO builder " .. avoided.action .. " (before cast event), counted=" .. countedPoints)
        return
    end
    countedPoints = math.min(COMBO_CAP, countedPoints + points)
    lastBuilder = { key = key, points = points, at = GetTime() }
end

-- A DoT cast whose result was avoided isn't on the target: drop it. (Waiting for a first tick to prove it
-- instead doesn't work for bleeds: melee white hits look just like ticks.) A recast replaced a DoT that is
-- still ticking, so that one is put back.
-- Spell DoTs are different: the pet and other players' melee miss all the time, and their ticks are told apart
-- from melee by school. So an avoid that can't be the spell's is ignored, and one that might not be (not
-- reported in the spell's school) makes a new DoT wait for its first tick instead of dropping it.
-- Returns false if the avoid was ignored, so the cast's own outcome may still come.
local function removeAvoidedDot(cast, action, school)
    local dot = cast.dot
    local dots = dotsByTarget[cast.key]
    if not dots or dots[cast.name] ~= dot then return true end
    local spellSchool = type(school) == "number" and not isSecret(school) and school == dot.school
    if dot.school ~= SCHOOL_MASKS.Physical and not spellSchool then
        if MELEE_ONLY_AVOIDS[action] then
            trace(string.format("AVOID %s (school %s) right after %s: not the spell, ignored", action,
                tostring(school), cast.name))
            return false
        end
        if not cast.previous then
            dot.doubtful = true
            trace(string.format("AVOID %s (school %s) right after %s: may be someone else's, waiting for its first tick",
                action, tostring(school), cast.name))
            return true
        end
    end
    if cast.previous then
        dots[cast.name] = cast.previous
        trace(string.format("AVOID %s (school %s) right after %s recast; keeping the earlier one", action,
            tostring(school), cast.name))
    else
        dots[cast.name] = nil
        trace(string.format("AVOID %s (school %s) right after %s; dropped", action, tostring(school), cast.name))
    end
    -- A cat's or rogue's white swing missing in that instant looks the same as the finisher missing (in-game
    -- 2026-11-09: a Rip that landed was dropped). A finisher that misses keeps its combo points, one that lands
    -- spends them, so a finisher whose points were read at send is judged again once they've settled.
    if cast.comboRead then
        finisherCheck = { cast = cast, dot = dot, replaced = dots[cast.name], action = action, school = school,
            at = GetTime() + FINISHER_CHECK_DELAY }
    end
    return true
end

-- The combo points after a dropped finisher: spent means it landed (the avoid was a white swing), so it's put
-- back; still there, unreadable, or the target changed (the points belong to the target) leaves it dropped.
-- Unverified in-game that Forever keeps a missed finisher's combo points.
local function resolveFinisherCheck(now)
    local check = finisherCheck
    if not check or now < check.at then return end
    finisherCheck = nil
    local cast = check.cast
    if unitKey("target") ~= cast.key then
        trace("COMBO after " .. cast.name .. "'s " .. check.action .. ": target changed, stays dropped")
        return
    end
    local points, readings = readComboPoints()
    if not points or points >= cast.comboRead then
        trace(string.format("COMBO after %s's %s: %s (had %d), it missed", cast.name, check.action, readings,
            cast.comboRead))
        return
    end
    local dots = dotsByTarget[cast.key]
    if (dots and dots[cast.name]) ~= check.replaced or now >= check.dot.expiresAt then return end
    dotsByTarget[cast.key] = dots or {}
    dotsByTarget[cast.key][cast.name] = check.dot
    trace(string.format("COMBO after %s's %s: %s (had %d), spent: it landed, restored", cast.name, check.action,
        readings, cast.comboRead))
end

local function onAvoided(key, action, school)
    local now = GetTime()
    lastOutcome = { key = key, avoided = true, action = action, school = school, at = now }
    if lastBuilder and lastBuilder.key == key then
        if now - lastBuilder.at <= OUTCOME_WINDOW then
            countedPoints = math.max(0, countedPoints - lastBuilder.points)
            trace("COMBO builder " .. action .. ", counted=" .. countedPoints)
        end
        lastBuilder = nil
    end
    if lastDotCast and lastDotCast.key == key then
        if now - lastDotCast.at > OUTCOME_WINDOW then
            lastDotCast = nil
        elseif lastDotCast.landedAt then
            -- Its direct part hit: other avoids are someone else's, but the DoT itself may be immune.
            if action == "IMMUNE" then
                trace("IMMUNE after " .. lastDotCast.name .. "'s direct hit: the DoT didn't land")
                if removeAvoidedDot(lastDotCast, action, school) then lastDotCast = nil end
            end
        elseif removeAvoidedDot(lastDotCast, action, school) then
            lastDotCast = nil
        end
    end
end

-- A hit on a mob: the pending casts on it landed (a later avoid belongs to something else, except an IMMUNE for
-- a DoT's own part). For a spell DoT only a hit in its school says so (Immolate's direct damage); a melee hit is
-- someone else's.
local function onHit(key, school)
    local now = GetTime()
    local prior = lastOutcome
    lastOutcome = { key = key, avoided = false, at = now }
    if prior and prior.key == key and prior.action == "IMMUNE" and now - prior.at <= OUTCOME_LOOKBACK then
        lastOutcome.immune = prior
    end
    if lastBuilder and lastBuilder.key == key then lastBuilder = nil end
    -- UNIT_COMBAT can hand out a secret school; this runs before the amount/school guard, so never compare it.
    local schoolKnown = not isSecret(school)
    if lastDotCast and lastDotCast.key == key and not lastDotCast.landedAt
        and (lastDotCast.dot.school == SCHOOL_MASKS.Physical
            or (schoolKnown and lastDotCast.dot.school == school)) then
        lastDotCast.landedAt = now
    end
end

local function resetComboCount()
    countedPoints, lastBuilder = 0, nil
    -- The cached reading belongs to the old target too: a finisher on a new target would otherwise use the points
    -- built on the previous one (5 points' damage instead of the cautious 1-point entry).
    lastComboPoints, lastComboAt = nil, 0
end

-- Returns points and where they came from, or nil and "unknown".
local function comboPointsForCast()
    local points, source = comboAtSend, "read"
    if not (points and points > 0) then
        if lastComboPoints and GetTime() - lastComboAt <= COMBO_CACHE_SECONDS then
            points, source = lastComboPoints, "cached"
        elseif countedPoints > 0 then
            points, source = countedPoints, "counted"
        else
            points, source = nil, "unknown"
        end
    end
    comboAtSend = nil
    resetComboCount()
    return points, source
end

-- A DoT as it stands the moment it's applied, before any tick.
local function newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
    return {
        spellID = spellID,
        tickKey = tickKey,
        -- The size learned before this cast: a same-slot collision is judged against it, not against the value
        -- the disputed tick just wrote (referenceTickSize).
        learnedAtApply = tickKey and db.ticks[tickKey] or nil,
        school = SCHOOL_BY_NAME[name] or school,
        total = total,
        duration = duration,
        interval = interval,
        totalTicks = math.max(1, math.floor(duration / interval + 0.5)),
        shape = TICK_SHAPES[name],
        travel = PROJECTILE_DOTS[name] and PROJECTILE_TRAVEL or nil,
        appliedAt = now,
        expiresAt = now + duration,
        nextTickAt = now + interval,
        tickSum = 0,        -- non-crit ticks only
        normalTicks = 0,
        ticksSeen = 0,      -- including crits
        missed = 0,
    }
end

-- Returns the target key the DoT was applied to, or nil if the cast wasn't a tracked DoT.
local function onPlayerCast(spellID, castGUID)
    local key = castTargetKey(castGUID)
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) then return end
    if type(desc) == "string" and not isSecret(desc) then
        local awarded = tonumber(desc:match("Awards (%d+) combo point")) or ns.locale.comboPointsAwarded(desc)
        if awarded then onBuilderCast(key, awarded) end
        -- Only one Fire trap can be active: any new one (Explosive Trap too) replaces the armed one.
        if armedTrap and desc:find("Fire trap") then armedTrap = nil end
    end
    if IGNORED_SPELLS[name] then return end
    local isFinisher = isFinisherDescription(desc)
    local comboPoints, comboSource
    if isFinisher then comboPoints, comboSource = comboPointsForCast() end
    -- Unknown points: parse the lowest entry (errs low), and don't use or teach learned tick sizes.
    local total, school, duration, statedInterval = parseDot(desc, comboPoints or 1)
    if not total then
        if not isSecret(desc) and ns.locale.shouldLogUnread(spellID, desc) then
            trace(string.format("NOT READ %s (id %d): %s", name, spellID, desc))
        end
        return
    end
    -- A finisher's tick size depends on the points spent, so learned sizes are kept per point count.
    local tickKey = spellID
    if isFinisher then tickKey = comboPoints and (spellID .. "x" .. comboPoints) or nil end

    local now = GetTime()
    if TRAP_DOTS[name] then
        -- A new trap replaces the armed one ("Only one Fire trap can be active at a time").
        local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
        school = SCHOOL_BY_NAME[name] or school
        local lifetime = tonumber(desc:match("[Tt]rap will exist for (%d+) min"))
        armedTrap = { spellID = spellID, name = name, total = total, school = school, duration = duration,
            interval = interval, placedAt = now, expiresAt = now + (lifetime or 1) * 60 }
        trace(string.format("TRAP %s (id %d) armed: %d dmg over %ss, school %d, per-tick %s", name, spellID, total,
            duration, school, db.ticks[spellID] and ("learned " .. db.ticks[spellID]) or "from description"))
        return
    end

    if not key then
        combatUntracked[spellID] = true -- the damage meter still counts what this cast deals
        return
    end

    dotsByTarget[key] = dotsByTarget[key] or {}
    local previous = dotsByTarget[key][name]
    local dot = newDot(spellID, tickKey, name, total, school, duration, statedInterval, now)
    dotsByTarget[key][name] = dot
    lastDotCast = { key = key, name = name, dot = dot, previous = previous, at = now,
        comboRead = isFinisher and comboSource == "read" and comboPoints or nil }
    dot.name = dot.name or name
    tallyCast(dot, isFinisher and 0 or parseDirectPart(desc)) -- a finisher's point table is no upfront hit
    local learned = tickKey and db.ticks[tickKey]
    -- The starting estimate is shaky without a learned tick size (description numbers leave out spell power
    -- and attack power) or, for finishers, without knowing the combo points.
    dot.unsure = not learned
    trace(string.format("CAST %s (id %d)%s: %d dmg over %ss, school %d, tick every %ss, per-tick %s%s%s", name, spellID,
        isFinisher and string.format(" %s combo points (%s)", comboPoints or "?", comboSource) or "",
        total, duration, dot.school, dot.interval, learned and ("learned " .. learned) or "from description",
        isWaiting(dot) and ", waiting for first tick" or "",
        key ~= unitKey("target") and (" on " .. tostring(key) .. ", the target when sent") or ""))
    local avoided = avoidJustBefore(key, true)
    if avoided and removeAvoidedDot(lastDotCast, avoided.action, avoided.school) then
        lastDotCast = nil
        if dotsByTarget[key] and dotsByTarget[key][name] == dot then return key, isWaiting(dot) end
        return nil
    end
    return key, isWaiting(dot)
end

-- Your pet's DoTs (BOLT, 2026-11-12): UNIT_SPELLCAST_SUCCEEDED also reports the pet's casts. A pet DoT goes on
-- the pet's target and is then tracked like yours: description at cast, ticks matched by school and timing, real
-- tick sizes from the damage meter (which folds pet spells into your line). No combo points, traps or cast-time
-- estimate. Unverified in-game which pets have DoTs on Forever, or that the event fires for the pet there.
local function onPetCast(spellID)
    local key = unitKey("pettarget")
    if not key then return end
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) or IGNORED_SPELLS[name] or TRAP_DOTS[name] then return end
    if type(desc) ~= "string" or isSecret(desc) or isFinisherDescription(desc) then return end
    local total, school, duration, statedInterval = parseDot(desc, 1)
    if not total then return end

    local now = GetTime()
    dotsByTarget[key] = dotsByTarget[key] or {}
    local previous = dotsByTarget[key][name]
    local dot = newDot(spellID, spellID, name, total, school, duration, statedInterval, now)
    dot.name, dot.fromPet = name, true
    dot.unsure = not db.ticks[spellID]
    dotsByTarget[key][name] = dot
    lastDotCast = { key = key, name = name, dot = dot, previous = previous, at = now }
    tallyCast(dot, parseDirectPart(desc))
    trace(string.format("PET CAST %s (id %d) on %s: %d dmg over %ss, school %d, tick every %ss, per-tick %s%s",
        name, spellID, tostring(key), total, duration, dot.school, dot.interval,
        db.ticks[spellID] and ("learned " .. db.ticks[spellID]) or "from description",
        isWaiting(dot) and ", waiting for first tick" or ""))
    local avoided = avoidJustBefore(key, true)
    if avoided and removeAvoidedDot(lastDotCast, avoided.action, avoided.school) then lastDotCast = nil end
end

-- "Estimate during casting": a DoT with a cast time shows from UNIT_SPELLCAST_START, with the estimate its
-- cast would make. It's kept out of dotsByTarget, so ticks never match it and housekeeping leaves it alone,
-- and it stands in for a DoT of the same name that the cast would refresh (replaces, never adds). On success
-- onPlayerCast takes over exactly as without it. A failed or interrupted cast, or a target change, just drops
-- it, so a DoT it was about to refresh keeps ticking as if nothing happened. STOP ends every cast, successful
-- or not, and may come just before SUCCEEDED, so a stopped cast is only dropped if no success follows shortly.
local CAST_STOP_GRACE = 0.5
local CAST_MAX_SECONDS = 15 -- a lost end event never leaves an estimate behind
local castInProgress -- { key, name, dot, castGUID, spellID, startedAt, stoppedAt }

-- Whether an event's castGUID (or, when either GUID is unreadable, its spell ID) is the cast in progress.
local function sameCast(cast, castGUID, spellID)
    if cast.castGUID and castGUID ~= nil and not isSecret(castGUID) then return castGUID == cast.castGUID end
    return not isSecret(spellID) and spellID == cast.spellID
end

local function dropCastInProgress(reason)
    if not castInProgress then return end
    trace("CASTING " .. castInProgress.name .. " " .. reason .. "; estimate removed")
    castInProgress = nil
end

-- UNIT_SPELLCAST_START (player). Returns the target key when a DoT now shows for the cast.
local function onCastStart(castGUID, spellID)
    castInProgress = nil
    if not db.estimateDuringCast or isSecret(spellID) then return end
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) or IGNORED_SPELLS[name] or isFinisherDescription(desc) then return end
    local total, school, duration, statedInterval = parseDot(desc, 1)
    if not total then return end
    -- The mob it was sent at (a [@focus] macro's focus), else the target. Kept for the cast's success.
    local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
    local key
    if sent then key = sent.key else key = unitKey("target") end
    if not key then return end
    local now = GetTime()
    local dot = newDot(spellID, spellID, name, total, school, duration, statedInterval, now)
    local learned = db.ticks[spellID]
    dot.unsure = not learned
    dot.provisional = true
    castInProgress = { key = key, name = name, dot = dot, spellID = spellID, startedAt = now,
        castGUID = not isSecret(castGUID) and castGUID or nil }
    trace(string.format("CASTING %s (id %d): %d dmg over %ss, per-tick %s%s", name, spellID, total, duration,
        learned and ("learned " .. learned) or "from description", isWaiting(dot) and ", waiting for first tick" or ""))
    return key
end

-- UNIT_SPELLCAST_SUCCEEDED (player), just before onPlayerCast: the cast's own DoT replaces the estimate.
local function onCastSucceeded(castGUID, spellID)
    if castInProgress and sameCast(castInProgress, castGUID, spellID) then castInProgress = nil end
end

-- UNIT_SPELLCAST_STOP / FAILED / INTERRUPTED (player). Returns true when the estimate was removed.
local function onCastEnded(event, castGUID, spellID)
    if not castInProgress or not sameCast(castInProgress, castGUID, spellID) then return end
    if event == "UNIT_SPELLCAST_STOP" then
        castInProgress.stoppedAt = castInProgress.stoppedAt or GetTime()
        return
    end
    dropCastInProgress(event == "UNIT_SPELLCAST_INTERRUPTED" and "interrupted" or "failed")
    return true
end

-- Seconds between now and the nearest expected tick time, and that tick's index. Anchored on the first tick
-- once seen (ticks keep its rhythm; anchoring on the latest tick would let jitter add up), else on the cast.
-- Using the nearest multiple of the interval means one missed tick doesn't lose the DoT.
local function distanceToExpectedTick(dot, now)
    local anchor = dot.firstTickAt or dot.appliedAt
    if not dot.firstTickAt and dot.travel then
        -- Still in flight: the DoT started anywhere up to `travel` seconds after the cast.
        local late = now - (anchor + dot.interval)
        if late > 0 then anchor = anchor + math.min(late, dot.travel) end
    end
    local k =math.max(1, math.floor((now - anchor) / dot.interval + 0.5))
    return math.abs(now - (anchor + k * dot.interval)), k
end

local function plausibleTickAmount(dot, amount, isCrit, number)
    local known, tolerance
    if dot.normalTicks > 0 then
        known, tolerance = dot.tickSum / dot.normalTicks, TICK_AMOUNT_TOLERANCE
    else
        known, tolerance = dot.tickKey and db.ticks[dot.tickKey], FIRST_TICK_AMOUNT_TOLERANCE
    end
    if not known then return true end
    known = known * tickShape(dot, number)
    if isCrit then
        return amount >= known * CRIT_MIN_RATIO - 1 and amount <= known * CRIT_MAX_RATIO + 1
    end
    return math.abs(amount - known) <= math.max(1, known * tolerance)
end

-- Tick size to judge a same-slot collision by: the average of the DoT's earlier ticks, or with fewer than two
-- ticks the size learned before this cast, else the description's per-tick share. Learned first: descriptions
-- leave out spell and attack power, so their share sits far below real ticks (Rake: 13 vs 26), and judging by it
-- took a white hit for the tick and learned that.
local function referenceTickSize(dot)
    if dot.normalTicks > 1 then
        return (dot.tickSum - dot.lastTickAmount / dot.lastTickShape) / (dot.normalTicks - 1)
    end
    return dot.learnedAtApply or (dot.total / dot.totalTicks)
end

local function saveLearnedTick(dot)
    if dot.tickKey and dot.normalTicks > 0 then
        db.ticks[dot.tickKey] = math.floor(dot.tickSum / dot.normalTicks * 10 + 0.5) / 10
        combatReadable[dot.tickKey] = true -- the meter's total then holds ticks the tally didn't count
    end
end

-- A running DoT that has not ticked yet keeps the size it was applied with (expectedTick). When the store is
-- reset, forgotten or relearned, that snapshot is as wrong as the store was: drop it so the DoT follows the store
-- again. key nil = every DoT.
local function dropSnapshots(key)
    for _, dots in pairs(dotsByTarget) do
        for _, dot in pairs(dots) do
            if dot.normalTicks == 0 and (key == nil or dot.tickKey == key) then dot.learnedAtApply = nil end
        end
    end
end
ns.dropSnapshots = dropSnapshots

-- Moves a DoT's tick bookkeeping to the tick in slot `index` that landed at `now`.
local function anchorTick(dot, index, now)
    dot.missed = 0
    if dot.firstTickAt then
        dot.lastTickIndex = index
    else
        dot.firstTickAt, dot.lastTickIndex = now, 0
        -- A projectile DoT started when it landed: count its ticks from there.
        if dot.travel then dot.appliedAt = now - index * dot.interval end
    end
    dot.lastTickAt = now
    dot.nextTickAt = now + dot.interval
    -- Re-anchor expiry on the observed tick: ticks arrive slightly after their nominal time, and an
    -- expiry based on the cast event would otherwise cut off the final tick.
    local tickIndex = math.max(1, math.floor((now - dot.appliedAt) / dot.interval + 0.5))
    dot.expiresAt = now + (dot.totalTicks - tickIndex) * dot.interval
    return tickIndex
end

-- Two same-school hits in one tick slot (e.g. Shadow Bolt landing with a Corruption tick, log 123506.4): the
-- first one was taken as the tick. If this one is closer to the expected size, it was the real tick.
local SAME_SLOT_SECONDS = 0.2
local function trySwapSameSlot(dot, name, amount, isCrit, now)
    if isCrit or amount <= 0 or dot.lastTickCrit or not dot.lastTickAt
        or dot.lastTickAmount <= 0 or now - dot.lastTickAt > SAME_SLOT_SECONDS then
        return false
    end
    local factor = dot.lastTickShape
    local reference = referenceTickSize(dot) * factor
    if math.abs(amount - reference) >= math.abs(dot.lastTickAmount - reference) then return false end
    trace(string.format("SWAP %s tick: %d was another hit, %d is the tick", name, dot.lastTickAmount, amount))
    dot.tickSum = dot.tickSum + (amount - dot.lastTickAmount) / factor
    dot.lastTickAmount = amount
    saveLearnedTick(dot)
    return true
end

-- A learned size that's wrong rejects every real tick (log: Corruption learned 29 from Shadow Bolts, real ticks
-- 10-11, every cast dropped). Hits rejected only on size, but landing on the DoT's rhythm in two consecutive
-- slots and agreeing with each other, are the real ticks: relearn from them.
-- Description damage omits stat bonuses; a band around it or the old learned size can lock out real ticks.
local function tryRelearn(dot, name, amount, isCrit, index, distance, now)
    local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
    local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
    if isCrit or amount <= 0 or not freshSlot or distance > window then return false end
    local previous = dot.offBeatCandidate
    local factor = tickShape(dot, tickNumberAt(dot, now))
    local average = amount / factor
    dot.offBeatCandidate = { index = index, amount = amount, average = average, at = now }
    if not previous or index ~= previous.index + 1
        or math.abs(average - previous.average) > math.max(1, previous.average * TICK_AMOUNT_TOLERANCE) then
        return false
    end
    trace(string.format("RELEARN %s: ticks of %d and %d on its rhythm didn't fit %.1f/tick", name,
        previous.amount, amount, expectedTick(dot)))
    dot.offBeatCandidate = nil
    dot.tickSum, dot.normalTicks = previous.average + average, 2
    dot.ticksSeen = dot.ticksSeen + 2
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, false
    saveLearnedTick(dot)
    if dot.tickKey then dropSnapshots(dot.tickKey) end -- other mobs' DoTs that haven't ticked must not keep the old size
    if not dot.firstTickAt then
        dot.firstTickAt, dot.lastTickIndex = previous.at, 0
        index = 1
    end
    anchorTick(dot, index, now)
    return true
end

-- Counts a hit as the DoT's tick in slot `index`. Returns the tick's number (1 = first) and shape factor.
local function recordTick(dot, amount, isCrit, index, now)
    local factor = tickShape(dot, tickNumberAt(dot, now))
    dot.ticksSeen = dot.ticksSeen + 1
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, isCrit
    dot.offBeatCandidate = nil
    if not isCrit and amount > 0 then
        dot.tickSum = dot.tickSum + amount / factor
        dot.normalTicks = dot.normalTicks + 1
        saveLearnedTick(dot)
    end
    return anchorTick(dot, index, now), factor
end

-- An armed trap's first tick: an unmatched hit of its school and size on any mob, at least one tick interval
-- after the trap was placed (the DoT ticks first one interval after it springs). Starts the DoT there, as tick
-- 1. Without a learned size the description's share is only a rough guide (it may leave out attack power), so
-- the range is wide (0.5-2.5x). If the trapped mob's first tick went unseen (not the target, focus or a visible
-- nameplate), a later tick is taken for the first and the estimate runs high for that trap.
local function springTrap(key, unit, amount, school, isCrit, now)
    local trap = armedTrap
    if not trap or school ~= trap.school then return false end
    if now > trap.expiresAt + trap.interval + TICK_MATCH_WINDOW then armedTrap = nil; return false end
    if now < trap.placedAt + trap.interval - TICK_MATCH_WINDOW then return false end
    local dot = newDot(trap.spellID, trap.spellID, trap.name, trap.total, trap.school, trap.duration,
        trap.interval, now - trap.interval)
    if db.ticks[trap.spellID] then
        if not plausibleTickAmount(dot, amount, isCrit, 1) then return false end
    else
        local share = trap.total / dot.totalTicks
        local low, high = share * 0.5, share * 2.5
        if isCrit then low, high = low * CRIT_MIN_RATIO, high * CRIT_MAX_RATIO end
        if amount < low or amount > high then return false end
    end
    armedTrap = nil
    dotsByTarget[key] = dotsByTarget[key] or {}
    dotsByTarget[key][trap.name] = dot
    local tickIndex = recordTick(dot, amount, isCrit, 1, now)
    trace(string.format("TRAP %s sprung on %s: first tick %d%s %.1fs after placing (tick %d/%d)", trap.name, unit,
        amount, isCrit and " CRIT" or "", now - trap.placedAt, tickIndex, dot.totalTicks))
    return true
end

-- Returns the target key when this hit was the first tick of a DoT that was waiting for it (so the display
-- can flash now that the DoT shows), else nil.
-- The same hit arrives once per unit token showing the mob (target, nameplateN, focus...) and must count once. But
-- two DoTs of one school can tick for the same amount in the same instant: those are two hits from the same token.
-- So within an instant each signature (mob, amount, school) remembers its token and the DoTs it fed: a repeat
-- from the same token feeds another DoT, one from another token is a copy and is dropped.
local combatFrameAt
local combatFrameHits = {}

-- Within one instant, the record for a hit's signature: a repeat from the same token feeds another DoT, one from
-- another token is a copy (returns nil). See combatFrameHits above.
local function hitRecord(signature, unit, now)
    if combatFrameAt ~= now then
        combatFrameHits = {}
        combatFrameAt = now
    end
    local hit = combatFrameHits[signature]
    if hit then
        if hit.unit ~= unit then return nil end
    else
        hit = { unit = unit, fed = {} }
        combatFrameHits[signature] = hit
    end
    return hit
end

-- Forever hides UNIT_COMBAT damage amounts in combat (secret), while the action and school stay
-- readable. Without a size, a hit is matched on school and timing alone: one in a DoT's school, on its rhythm,
-- in a slot not yet taken, is its tick. That keeps the DoT (a resisted one still gets no ticks and is dropped)
-- and anchors its rhythm, but teaches no size: the estimate keeps the learned or description tick.
-- Physical bleeds can take a white hit landing in the window for a tick, so their hidden hits never move the
-- rhythm: they stay on the schedule from the cast (first ticks land within ~0.1s of it). Anchoring on white hits
-- let Rend's schedule drift a little earlier with each one, until the marker ran out a tick before Rend did
--.
local function countHiddenTickOnSchedule(dot, index)
    dot.missed = 0
    dot.hiddenSlot = index
    local nextTickAt = dot.appliedAt + (index + 1) * dot.interval
    if nextTickAt > dot.nextTickAt then dot.nextTickAt = nextTickAt end
    return index
end

local function onHiddenAmountHit(key, unit, school)
    local dots = dotsByTarget[key]
    if not dots then return end
    local now = GetTime()
    local hit = hitRecord(key .. ":hidden:" .. school, unit, now)
    if not hit then return end
    local best, bestName, bestDistance, bestIndex
    for name, dot in pairs(dots) do
        if not hit.fed[name] and dot.school == school then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            local freshSlot
            if dot.firstTickAt then
                freshSlot = index > dot.lastTickIndex
            else
                freshSlot = index > (dot.hiddenSlot or 0)
            end
            if freshSlot and distance <= window and (not bestDistance or distance < bestDistance) then
                best, bestName, bestDistance, bestIndex = dot, name, distance, index
            end
        end
    end
    if not best then
        trace(string.format("HIT (amount hidden) school %d on %s not matched to a DoT", school, unit))
        return
    end
    local wasWaiting = isWaiting(best)
    best.ticksSeen = best.ticksSeen + 1
    best.lastTickAmount, best.lastTickShape, best.lastTickCrit = 0, tickShape(best, tickNumberAt(best, now)), false
    best.offBeatCandidate = nil
    local tickIndex
    if school == 1 and not best.firstTickAt then
        tickIndex = countHiddenTickOnSchedule(best, bestIndex)
    else
        tickIndex = anchorTick(best, bestIndex, now)
    end
    hit.fed[bestName] = true
    tallyHiddenTick(best, best.lastTickShape)
    trace(string.format("TICK %s (amount hidden) on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName,
        unit, tickIndex, best.totalTicks, expectedTick(best) * best.lastTickShape,
        wasWaiting and ", now shown" or ""))
    if wasWaiting then return key end
end

local LEARN_MIN_FACTORS = 2              -- at least two (average) ticks' worth this combat
local LEARN_RATIO_MIN, LEARN_RATIO_MAX = 0.5, 2.5  -- real vs description outside this: something else got mixed in
local LEARN_WEIGHT_CAP = 20             -- older fights count as at most this many ticks, so gear changes catch up

-- Why a key isn't learned from this combat, or nil. "" skips quietly (nothing was counted).
local function meterSkipReason(key, t, counted, totals, keysPerSpell)
    if t.factors < LEARN_MIN_FACTORS then
        return t.ticks > 0 and string.format("only %d tick(s) counted", t.ticks) or ""
    end
    if counted.readable[key] then return "a readable tick already taught it" end
    if t.unclear then return "its upfront hit can't be told apart in this client's language" end
    -- Ticks of a DoT cast before this combat (Feign Death, an evade) or by a trap: the casts that fed the meter
    -- aren't in this tally, so nothing can say whether every tick was seen.
    if #t.dots == 0 then return "not cast this combat" end
    if counted.untracked[t.spellID] then return "a cast had no known target, so the meter has damage not counted here" end
    for _, dot in ipairs(t.dots) do
        if dot.ticksSeen == 0 then return "a cast's DoT never showed a tick (out of sight, or the mob died first)" end
    end
    if not totals[t.spellID] then return "no readable damage meter total" end
    if keysPerSpell[t.spellID] > 1 then return "several combo point sizes share one meter total" end
end

-- spells: the damage meter's per-spell rows for the combat that just ended ({ spellID, totalAmount }); counted:
-- that combat's tally (takeCombatTally; by default the current one, which then starts over). Learns a real average
-- tick for every DoT whose ticks were counted. Returns how many sizes were learned.
local function learnFromMeter(spells, counted)
    counted = counted or takeCombatTally()
    db.tickWeights = db.tickWeights or {}
    local totals = {}
    for _, sp in ipairs(spells or {}) do
        local id, amount = sp.spellID, sp.totalAmount
        if not isSecret(id) and not isSecret(amount) and type(amount) == "number" then totals[id] = amount end
    end
    local keysPerSpell = {}
    for _, t in pairs(counted.keys) do keysPerSpell[t.spellID] = (keysPerSpell[t.spellID] or 0) + 1 end
    local learned = 0
    for key, t in pairs(counted.keys) do
        local total, name = totals[t.spellID], t.name or tostring(t.spellID)
        local skip = meterSkipReason(key, t, counted, totals, keysPerSpell)
        if skip then
            if skip ~= "" then trace(string.format("LEARN %s skipped: %s", name, skip)) end
        else
            local ratio = total / (t.direct + t.descTick * t.factors)
            if ratio < LEARN_RATIO_MIN or ratio > LEARN_RATIO_MAX then
                trace(string.format("LEARN %s skipped: meter %d over %d tick(s) is %.2fx the description", name,
                    total, t.ticks, ratio))
            else
                local tick = ratio * t.descTick
                local old, weight = db.ticks[key], math.min(db.tickWeights[key] or 0, LEARN_WEIGHT_CAP)
                if not old then weight = 0 end
                local blended = (((old or 0) * weight) + tick * t.factors) / (weight + t.factors)
                db.ticks[key] = math.floor(blended * 10 + 0.5) / 10
                db.tickWeights[key] = weight + t.factors
                dropSnapshots(key)
                learned = learned + 1
                trace(string.format("LEARN %s: meter %d over %d tick(s)%s = %.1f per tick (description %.1f), saved %.1f",
                    name, total, t.ticks, t.direct > 0 and " minus upfront hit" or "", tick, t.descTick, db.ticks[key]))
            end
        end
    end
    return learned
end
ns.learnFromMeter = learnFromMeter

local function onUnitCombat(unit, action, flag, amount, school)
    if isSecret(action) then return end
    -- A fully absorbed tick still landed (a shield ate it): it proves the DoT is on and keeps its rhythm, so ABSORB
    -- matches like WOUND, but a 0 never feeds tick sizes. With two DoTs it could be, it's ignored.
    local absorbed = action == "ABSORB"
    if not AVOIDED_ACTIONS[action] and action ~= "WOUND" and not absorbed then return end
    local key = unitKey(unit)
    if not key then return end
    if AVOIDED_ACTIONS[action] then return onAvoided(key, action, school) end
    if action == "WOUND" or absorbed then onHit(key, school) end
    if isSecret(amount) and not isSecret(school) and type(school) == "number" then
        return onHiddenAmountHit(key, unit, school)
    end
    if isSecret(amount) or isSecret(school) or type(amount) ~= "number" then return end
    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    if not dotsByTarget[key] and not armedTrap then return end
    local dots = dotsByTarget[key] or {}

    -- The same hit fires for target, nameplateN, softenemy...: handle it once (see combatFrameHits above).
    local now = GetTime()
    local hit = hitRecord(key .. ":" .. amount .. ":" .. school, unit, now)
    if not hit then return end
    local lastCombatFed = hit.fed

    local best, bestName, bestDistance, bestIndex
    local zeroAbsorb = absorbed and amount == 0
    local candidates = 0
    for name, dot in pairs(dots) do
        if not lastCombatFed[name] and dot.school == school
            and (zeroAbsorb or plausibleTickAmount(dot, amount, isCrit, tickNumberAt(dot, now))) then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            -- Each tick slot takes one hit: a second hit near an already-matched tick is someone else's.
            local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
            if freshSlot and distance <= window then
                candidates = candidates + 1
                if not bestDistance or distance < bestDistance then
                    best, bestName, bestDistance, bestIndex = dot, name, distance, index
                end
            end
        end
    end
    -- A zero absorb has no size to distinguish two same-school DoTs.
    if zeroAbsorb and candidates ~= 1 then return end
    if not best then
        -- Not a tick as things stand; it may still correct one (same-slot swap, or a wrong learned size).
        for name, dot in pairs(dots) do
            if not lastCombatFed[name] and dot.school == school then
                local distance, index = distanceToExpectedTick(dot, now)
                local wasWaiting = isWaiting(dot)
                if trySwapSameSlot(dot, name, amount, isCrit, now) then
                    lastCombatFed[name] = true
                    return
                end
                if tryRelearn(dot, name, amount, isCrit, index, distance, now) then
                    lastCombatFed[name] = true
                    return wasWaiting and key or nil
                end
            end
        end
        -- Returned like a waiting DoT's first tick: the trap's DoT shows (and flashes) from now.
        if springTrap(key, unit, amount, school, isCrit, now) then return key end
        trace(string.format("HIT %d%s school %d on %s not matched to a DoT", amount, isCrit and " (crit)" or "",
            school, unit))
        return
    end

    local wasWaiting = isWaiting(best)
    local tickIndex, factor = recordTick(best, amount, isCrit, bestIndex, now)
    lastCombatFed[bestName] = true
    trace(string.format("TICK %s %d%s on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName, amount,
        isCrit and " CRIT" or "", unit, tickIndex, best.totalTicks, expectedTick(best) * factor,
        wasWaiting and ", now shown" or ""))
    if wasWaiting then return key end
end

-- Whether hits on a mob reach the addon right now. UNIT_COMBAT only reports unit tokens (the target, focus and
-- visible nameplates), so a mob you tabbed away from, with nameplates off or out of their range, ticks unseen.
-- Its DoTs used to be dropped as "never ticked", which lost every earlier mob when chain pulling.
local function isObservable(key)
    if unitKey("target") == key or unitKey("focus") == key then return true end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and unitKey(unit) == key then return true end
    end
    return false
end

local function housekeep(now)
    resolveFinisherCheck(now)
    for key, dots in pairs(dotsByTarget) do
        for name, dot in pairs(dots) do
            local late = (dot.ticksSeen == 0 and dot.travel) or 0
            while dot.nextTickAt < now - TICK_MATCH_WINDOW - late and dot.nextTickAt <= dot.expiresAt do
                dot.nextTickAt = dot.nextTickAt + dot.interval
                -- Only a tick that could have been seen counts as missed.
                if dot.ticksSeen == 0 and isObservable(key) then dot.missed = dot.missed + 1 end
            end
            if now > dot.expiresAt + TICK_MATCH_WINDOW then
                dots[name] = nil
                trace("EXPIRE " .. name)
            elseif dot.ticksSeen == 0 and dot.missed >= MISSED_TICKS_BEFORE_DROP then
                dots[name] = nil
                trace("DROP " .. name .. " never ticked (resisted or immune?)")
            end
        end
        if next(dots) == nil then dotsByTarget[key] = nil end
    end
    if castInProgress then
        if castInProgress.stoppedAt and now - castInProgress.stoppedAt > CAST_STOP_GRACE then
            dropCastInProgress("stopped without succeeding")
        elseif now - castInProgress.startedAt > CAST_MAX_SECONDS then
            dropCastInProgress("never finished")
        end
    end
end

local function remainingDamage(dot)
    if dot.nextTickAt > dot.expiresAt + dot.interval / 2 then return 0 end
    local ticksLeft = math.floor((dot.expiresAt - dot.nextTickAt) / dot.interval + 0.5) + 1
    if not dot.shape then return ticksLeft * expectedTick(dot) end
    local average, total = expectedTick(dot), 0
    for number = math.max(1, dot.totalTicks - ticksLeft + 1), dot.totalTicks do
        total = total + average * tickShape(dot, number)
    end
    return total
end

-- Remaining damage per DoT on a mob (by unitKey), oldest application first. DoTs still waiting for their first
-- tick are left out. A DoT being cast on the mob replaces the one of the same name it would refresh.
local function dotBreakdown(key)
    local dots = key and dotsByTarget[key]
    local cast = key and castInProgress and castInProgress.key == key and castInProgress or nil
    local list = {}
    if not dots and not cast then return list end
    for name, dot in pairs(dots or {}) do
        if not isWaiting(dot) and not (cast and name == cast.name) then
            table.insert(list, { name = name, spellID = dot.spellID, school = dot.school, appliedAt = dot.appliedAt,
                expiresAt = dot.expiresAt, damage = remainingDamage(dot), fromPet = dot.fromPet })
        end
    end
    if cast and not isWaiting(cast.dot) then
        table.insert(list, { name = cast.name, spellID = cast.spellID, school = cast.dot.school,
            appliedAt = cast.dot.appliedAt, expiresAt = cast.dot.expiresAt, damage = remainingDamage(cast.dot),
            provisional = true })
    end
    table.sort(list, function(a, b) return a.appliedAt < b.appliedAt end)
    return list
end

-- Returns what the target's DoTs still have to deal, how many DoTs count toward it, and the per-DoT
-- breakdown (see dotBreakdown).
local function targetRemainingDamage()
    local list = dotBreakdown(unitKey("target"))
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return math.floor(total + 0.5), #list, list
end

---------------------------------------------------------------------------
-- Settings and what BOLT reads
---------------------------------------------------------------------------

local function applyDefaults()
    for key, value in pairs(DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
end

-- The DoTs on the mob behind `unit` (e.g. "nameplate3"): per-DoT breakdown and total remaining damage.
function ns.dotBreakdownForUnit(unit)
    local list = dotBreakdown(unitKey(unit))
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return list, total
end

function ns.resetLearnedTicks()
    wipe(db.ticks)
    if db.tickWeights then wipe(db.tickWeights) end
    dropSnapshots()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")   -- combo points, before a finisher spends them
-- Estimate during casting: DoTs with a cast time show from the cast's start until it ends.
frame:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")   -- keeps a recent combo point reading as backup
frame:RegisterEvent("UNIT_COMBAT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")   -- plate tokens stand in for secret GUIDs (see plateTokenFor)
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
-- Never register COMBAT_LOG_EVENT_UNFILTERED: Forever forbids it and shows a "blocked" popup.

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        BOLTDB = BOLTDB or {}
        BOLTDB.dotTracking = BOLTDB.dotTracking or {}
        db = BOLTDB.dotTracking
        if db.version ~= DB_VERSION then
            db.ticks, db.intervals, db.version = nil, nil, DB_VERSION
        end
        db.ticks = db.ticks or {}
        db.log = db.log or {}
        applyDefaults()
        ns.db = db
        trace("===== session start =====")
        local added = ns.locale.addClientNames(NAME_TABLES, function(spellID)
            local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
            if name and not isSecret(name) and type(name) == "string" then return name end
        end)
        if #added > 0 then trace("NAMES from this client: " .. table.concat(added, ", ")) end
        self:UnregisterEvent("ADDON_LOADED")

    elseif not db or not ns.enabled then -- ns.enabled follows the nameplate DoT overlay setting
        return

    elseif event == "PLAYER_TARGET_CHANGED" then
        dotsByTarget.target = nil -- only used when the target's GUID is secret
        resetComboCount() -- combo points belong to the target they were built on
        dropCastInProgress("target changed")
        trace("TARGET changed to " .. (unitKey("target") or "none"))
        ns.refresh()

    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, targetName, castGUID, spellID = ...
        onCastSent(spellID, castGUID, targetName)

    elseif event == "UNIT_POWER_FREQUENT" then
        local _, powerType = ...
        if not isSecret(powerType) and powerType == "COMBO_POINTS" then rememberComboPoints() end

    elseif event == "UNIT_SPELLCAST_START" then
        local _, castGUID, spellID = ...
        if onCastStart(castGUID, spellID) then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED"
        or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local _, castGUID, spellID = ...
        if onCastEnded(event, castGUID, spellID) then ns.refresh() end

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        if unit == "pet" then
            if not isSecret(spellID) then onPetCast(spellID) end
        else
            onCastSucceeded(castGUID, spellID)
            onPlayerCast(spellID, castGUID)
        end
        ns.refresh()

    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        -- A plate token goes to the next mob that gets a plate: DoTs keyed by it belonged to the old one.
        local token = ...
        if type(token) == "string" and not isSecret(token) and dotsByTarget["plate:" .. token] then
            dotsByTarget["plate:" .. token] = nil
            trace("PLATE " .. token .. (event == "NAME_PLATE_UNIT_REMOVED" and " removed" or " reused")
                .. ": its DoTs were for the mob it showed before")
            ns.refresh()
        end

    elseif event == "UNIT_COMBAT" then
        if onUnitCombat(...) then ns.refresh() end
    end
end)

local sinceUpdate = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate < UPDATE_INTERVAL or not db or not ns.enabled then return end
    sinceUpdate = 0
    ns.refresh()
end)

-- After combat: read this combat's per-spell totals from the damage meter and learn tick sizes from them. The
-- totals can take a few seconds to show up and stop being secret, so it tries again for a while ("wait"). Every
-- table is checked before it's read (a row can be secret or off limits), all under one pcall: an error here would
-- otherwise come back after every combat.
local METER_TRIES, METER_RETRY_SECONDS = 20, 0.5

local function readableTable(v)
    if isSecret(v) or type(v) ~= "table" then return false end
    if type(canaccesstable) ~= "function" then return true end
    local ok, allowed = pcall(canaccesstable, v)
    return ok and allowed == true
end

local function meterSpellsNow()
    local DM = C_DamageMeter
    if type(DM) ~= "table" or type(DM.GetCombatSessionSourceFromType) ~= "function" then return nil, "no damage meter" end
    if type(DM.IsDamageMeterAvailable) == "function" then
        local okAvailable, available = pcall(DM.IsDamageMeterAvailable)
        if okAvailable and available == false then return nil, "switched off" end
    end
    local dmgType = Enum and Enum.DamageMeterType and Enum.DamageMeterType.DamageDone or 0
    local current = Enum and Enum.DamageMeterSessionType and Enum.DamageMeterSessionType.Current or 1
    local ok, spells, why = pcall(function()
        local src = DM.GetCombatSessionSourceFromType(current, dmgType, UnitGUID("player"))
        if not readableTable(src) or not readableTable(src.combatSpells) then return nil, "wait" end
        local list = src.combatSpells
        local n = #list
        if isSecret(n) or type(n) ~= "number" or n == 0 then return nil, "wait" end
        local rows = {}
        for i = 1, n do
            local sp = list[i]
            if readableTable(sp) then
                if isSecret(sp.totalAmount) or isSecret(sp.spellID) then return nil, "wait" end
                rows[#rows + 1] = { spellID = sp.spellID, totalAmount = sp.totalAmount }
            end
        end
        return rows
    end)
    if not ok then return nil, "unreadable" end
    return spells, why
end

local function learnAfterCombat(counted, triesLeft)
    if InCombatLockdown() then
        trace("LEARN skipped: a new fight started before the damage meter could be read")
        return
    end
    local spells, why = meterSpellsNow()
    if not spells and why == "wait" and triesLeft > 0 then
        C_Timer.After(METER_RETRY_SECONDS, function() learnAfterCombat(counted, triesLeft - 1) end)
        return
    end
    if not spells then
        trace("LEARN skipped: damage meter " .. (why == "wait" and "still empty or hidden" or tostring(why)))
        return
    end
    learnFromMeter(spells, counted)
end

local meterFrame = CreateFrame("Frame")
meterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
meterFrame:SetScript("OnEvent", function()
    local counted = takeCombatTally()
    if not db or not ns.enabled or next(counted.keys) == nil then return end
    C_Timer.After(METER_RETRY_SECONDS, function() learnAfterCombat(counted, METER_TRIES) end)
end)

