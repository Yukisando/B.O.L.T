-- BOLT DoT tracking: Russian (ruRU) spell descriptions and names. Registers itself with Languages.lua.
-- The Russian patterns only see descriptions the other languages didn't read, and can't match their text (they
-- need "урона"/"здоровья" with "за N сек." or "в течение N сек.", "Завершающий прием", "Длина серии").
--
-- The wording is WoW: Forever's own Russian tooltips (Wowhead's tooltip API, data env Forever, locale 7), for every
-- spell the addon tracks or ignores. Not verified on a Russian client yet. How it differs:
--   * "нанося 40 ед. урона от темной магии за 12 сек." (40 Shadow damage over 12 sec), or "в течение 12 сек.";
--     Moonfire leaves out "ед.": "12 дополнительного урона от тайной магии в течение 9 сек."
--   * the school follows "урона": "от огня", "от темной магии", "от сил природы", "от магии льда", "от светлой
--     магии", "от тайной магии"; bleeds name none, or are worded as lost health: "теряет 15 ед. здоровья за 9 сек."
--   * finishers: "Завершающий прием", then "5 приемов: 189 ед. урона за 12 сек." per combo point count
--   * builders: "Длина серии приемов увеличивается на 1."
-- Wowhead spells "е" where the client may print "ё" (приём, тёмной): the patterns accept both.
-- Digits are spelled [0-9] next to Cyrillic text (multibyte), as in the Korean and Chinese files.

local _, BOLT = ...
local ns = BOLT.DotTracking

local PHYSICAL = 1

-- School words between "урона" and the duration, combined schools first (Frostfire Bolt: fire and frost together).
local function schoolFromWords(words)
    local fire, frost = words:find("огн", 1, true), words:find("льд", 1, true)
    if fire and frost then return 4 + 16 end
    if words:find("темн", 1, true) or words:find("тёмн", 1, true) then return 32 end
    if fire then return 4 end
    if words:find("природ", 1, true) then return 8 end
    if frost then return 16 end
    if words:find("светл", 1, true) then return 2 end
    if words:find("тайн", 1, true) then return 64 end
    return PHYSICAL
end

-- Russian names of the spells in DotTracking.lua's name-keyed tables (Forever's, from Wowhead). Names the client
-- reports by spell ID are added at load anyway (Languages.lua), so these mostly matter for the tests.
local NAMES = {
    ["Insect Swarm"] = { "Рой насекомых" },
    ["Bane of Agony"] = { "Бич агонии" },
    ["Curse of Agony"] = { "Проклятие агонии" }, -- Classic's name; unverified on Forever
    ["Corruption"] = { "Порча" },
    ["Fireball"] = { "Огненный шар" },
    ["Holy Fire"] = { "Священный огонь" },
    ["Rip"] = { "Разорвать" },
    ["Rupture"] = { "Рваная рана" },
    ["Siphon Life"] = { "Вытягивание жизни" },
    ["Serpent Sting"] = { "Укус змеи" },
    ["Pyroblast"] = { "Огненная глыба" },
    ["Rain of Fire"] = { "Огненный ливень" },
    ["Hellfire"] = { "Адское Пламя", "Адское пламя" },
    ["Blizzard"] = { "Снежная буря" },
    ["Flamestrike"] = { "Огненный столб" },
    ["Consecration"] = { "Освящение" },
    ["Hurricane"] = { "Гроза" },
    ["Volley"] = { "Град стрел" },
    ["Drain Life"] = { "Похищение жизни" },
    ["Drain Soul"] = { "Похищение души" },
    ["Drain Mana"] = { "Похищение маны" },
    ["Health Funnel"] = { "Канал здоровья" },
    ["Mind Flay"] = { "Пытка разума" },
    ["Arcane Missiles"] = { "Чародейские снаряды" },
    ["Starshards"] = { "Звездные осколки", "Звёздные осколки" },
    ["Immolation Trap"] = { "Обжигающая ловушка" },
    ["Explosive Trap"] = { "Взрывная ловушка" },
}

-- Decimal commas ("1,5 сек." -> "1.5 сек.") and thousands separators ("1 132", plain or non-breaking space).
local function normalize(desc)
    desc = desc:gsub("([0-9]),([0-9])", "%1.%2")
    desc = desc:gsub("([0-9])\194\160([0-9][0-9][0-9])%f[^0-9]", "%1%2")
    return (desc:gsub("([0-9]) ([0-9][0-9][0-9])%f[^0-9]", "%1%2"))
end

local function isFinisher(desc)
    return desc:find("Завершающий при", 1, true) ~= nil
end

-- "Длина серии приемов увеличивается на 1." (Rake, Sinister Strike, Garrote).
local function comboPointsAwarded(desc)
    return tonumber(desc:match("Длина серии [^0-9]-увеличивается на ([0-9]+)"))
end

-- "5 приемов: 189 ед. урона за 12 сек." per combo point count (Rip, Rupture).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pts, amount, secs in desc:gmatch("([0-9]+) при[^:\n]-: *([0-9]+) ед%. урона за ([0-9]+%.?[0-9]*) сек") do
        local points = tonumber(pts)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, PHYSICAL, entry.duration
end

-- The last "<amount> ... <noun> ... за/в течение <secs> сек." clause in the description, so a direct hit first
-- (Immolate, Moonfire, Fireball) yields the periodic part. No digits between the amount and the duration.
local function lastClause(desc, noun)
    local bestAt, total, words, duration
    for _, lead in ipairs({ " за ", " в течение " }) do
        local pattern = "()([0-9]+)[^0-9]-" .. noun .. "([^0-9]-)" .. lead .. "([0-9]+%.?[0-9]*) сек"
        for at, amount, between, secs in desc:gmatch(pattern) do
            if not bestAt or at > bestAt then bestAt, total, words, duration = at, amount, between, secs end
        end
    end
    if bestAt then return tonumber(total), words, tonumber(duration) end
end

local function parseDot(desc, comboPoints)
    desc = normalize(desc)
    if isFinisher(desc) then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon poisons ("Смазать оружие ядом") are proc DoTs, not cast on the target.
    if desc:find("Смазать оружие", 1, true) then return nil end

    local total, words, duration = lastClause(desc, "урона")
    if total and duration > 0 then return total, schoolFromWords(words), duration end

    -- Bleeds worded as lost health: "теряет 15 ед. здоровья за 9 сек." (Rend), "Противник теряет 27 и
    -- дополнительно 60 здоровья за 9 сек." (Rake). Only with "теряет", so a heal over time is never read.
    if desc:find("теряет", 1, true) then
        total, words, duration = lastClause(desc, "здоровья")
        if total and duration > 0 then return total, PHYSICAL, duration end
    end

    -- A drain stated as a rate: "Вы похищаете у цели 11 ед. здоровья раз в 3 сек. ... Время действия – 30 сек."
    -- (Siphon Life; its school comes from SCHOOL_BY_NAME). Drain Life reads the same way but is ignored by name.
    local amount, every = desc:match("похищаете у цели ([0-9]+) ед%. здоровья раз в ([0-9]+%.?[0-9]*) сек")
    local lasts = desc:match("Время действия [^0-9]-([0-9]+%.?[0-9]*) сек")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), PHYSICAL, lasts, every
        end
    end
end

ns.locale.register({
    tag = "ruRU",
    parseDot = parseDot,
    isFinisher = function(desc) return isFinisher(normalize(desc)) end,
    comboPointsAwarded = comboPointsAwarded,
    names = NAMES,
})
