-- MARTIN_MoreMobs chaos/reinforcement engine v3.1 (server-side Lua).
-- Uses the generated CreatureDB (Ext.Require'd first): every GENERIC spawnable creature in the
-- game, grouped by creature type, with hp + cost (hp/10 budget proxy). Sources: tools/build_creature_db.py.
--
-- Owner spec: stacking trigger (base 20%, +5..25% per miss; TEST_MODE=100% while testing);
-- budget = hostLevel x rand(2-4) x party knob; reinforcements match the ENCOUNTER's creature
-- family; leader rolls only when a pack of >= 2 spawned, ~90% in-type / ~10% cross-type via the
-- AFFINITY map; mob levels = host level +- jitter, but at host level <= 2 the upper bound is
-- the player level (a multiattack harpy at lvl 1 one-shots lvl-1 chars).
--
-- v3.1 playtest fixes (2026-10-31 first combat log):
--   - DB_Is_InCombat has 2 columns -> Get(nil, nil) (arity-1 Get threw "No database named
--     'DB_Is_InCombat(1)'"); plus an EnteredCombat listener roster as fallback/union.
--   - Wave runs on a short Ext.Timer delay so enemies have actually entered combat when we
--     classify them (v3 saw "enemies: 0" -> random-type fallback -> harpy in an imp fight).
--   - SetLevel is verified again after a delay: the immediate read-back logged lvl 1 but the
--     game showed lvl 3, so the first read is not trustworthy.
--
-- Proven spawn sequence unchanged (probe v3): CreateAtObject(Name_GUID, anchor, dx, dy, "", 1)
-- -> SetFaction(EVIL) -> SetHostileAndEnterCombat(EVIL, HERO, created, anchor), E8b pair verbatim.
-- math.random only; no math.randomseed; no Ext.RandomInteger.

local TAG = "CHAOS"
local LINES = {}

local function flush()
    pcall(function () Ext.IO.SaveFile("MARTIN_chaos.log", table.concat(LINES, "\n")) end)
end

local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    LINES[#LINES + 1] = "[" .. TAG .. "] " .. table.concat(parts, " ")
    flush()
end

local EVIL = "Evil_4be9261a-e481-8d9d-3528-f36956a19b17"
local HERO = "Hero_a1542c81-6895-929e-4522-10ce218bb360"

-- Tunables ------------------------------------------------------------------
local TEST_MODE = true              -- 100% trigger while testing
local BASE_CHANCE = 20
local STACK_MIN, STACK_MAX = 5, 25  -- +% per encounter that didn't trigger
local BUDGET_LO, BUDGET_HI = 2, 4   -- budget = hostLevel * rand(LO,HI), costs are hp/10
local PARTY_KNOB = 0.15             -- +15% budget per party member beyond 4
local MAX_SPAWNS = 8                -- total, leader included
local LEVEL_JITTER = 2              -- SetLevel target = hostLevel + rand(-J, +J) above the soft cap
local SOFT_CAP_LEVEL = 2            -- host level <= this: mobs never exceed the player's level
local LEADER_CHANCE = 10            -- % of packs (>=2 mobs) that get a leader
local LEADER_TEST = true            -- 100% leader while testing (still needs pack >= 2)
local SAME_TYPE_LEADER = 90         -- % of leaders drawn from the pack's own type
local LEADER_ALLOWANCE = 2         -- leader may cost up to budget / this, on top of the pack
local WAVE_DELAY_MS = 1500         -- let enemies enter combat before we classify the fight
local VERIFY_DELAY_MS = 2000       -- delayed SetLevel verification

-- race string (Osiris GetRace) -> creature type; grow from discovery logs
local RACE_TO_TYPE = {
    Wolf = "Beast", Bear = "Beast", Bat = "Beast", Hyena = "Beast", Panther = "Beast",
    Spider = "Beast", Rat = "Beast", Crocodile = "Beast",
    Goblinoid = "Humanoid", Goblin = "Humanoid", Hobgoblin = "Humanoid", Duergar = "Humanoid",
    DwarfHill = "Humanoid", Human = "Humanoid", HalfOrc = "Humanoid", Githyanki = "Humanoid",
    Tiefling = "Humanoid", DrowElf = "Humanoid", ElfHigh = "Humanoid",
    Imp = "Fiend", Devil = "Fiend", Demon = "Fiend",
    Skeleton = "Undead", Zombie = "Undead", Ghoul = "Undead",
    Owlbear = "Monstrosity", Bulette = "Monstrosity", HookHorror = "Monstrosity",
    Worg = "Monstrosity", DisplacerBeast = "Monstrosity",
}

-- valid leader types per pack type: same type first, then plausible "in charge of" types.
-- (An undead leading wolves would be weird; a humanoid beastmaster or an owlbear pack alpha
-- would not. Humanoid packs are the most permissive - monsters enslave goblins all the time.)
local AFFINITY = {
    Aberration = { "Aberration", "Humanoid" },
    Beast = { "Beast", "Monstrosity", "Humanoid" },
    Celestial = { "Celestial", "Humanoid" },
    Construct = { "Construct", "Humanoid" },
    Dragon = { "Dragon", "Humanoid" },
    Elemental = { "Elemental", "Humanoid" },
    Fey = { "Fey", "Humanoid" },
    Fiend = { "Fiend", "Humanoid" },
    Giant = { "Giant", "Humanoid", "Monstrosity" },
    Humanoid = { "Humanoid", "Giant", "Monstrosity", "Fiend" },
    Monstrosity = { "Monstrosity", "Beast", "Humanoid" },
    Ooze = { "Ooze", "Humanoid" },
    Plant = { "Plant", "Fey", "Humanoid" },
    Undead = { "Undead", "Humanoid" },
}

local DEFAULT_TYPES = { "Beast", "Monstrosity", "Humanoid", "Undead", "Fiend" }

local misses = 0
local seen = {}
local combatRoster = {}   -- combatGuid -> { enemy-ish participant guids, via EnteredCombat }
local rosterPlayers = {}  -- guid -> true while in DB_Players (skip list), refreshed per wave
local raceDumped = false

local function rand(lo, hi) return math.random(lo, hi) end

-- fact helpers ---------------------------------------------------------------
local function rowGuid(row)
    if type(row) ~= "table" then return row end
    for _, k in ipairs({ "Object", "Character", "Player", "PartyMember", "Target" }) do
        if row[k] ~= nil and row[k] ~= "" then return row[k] end
    end
    for _, v in ipairs(row) do
        if type(v) == "string" and v ~= "" then return v end
    end
    return nil
end

-- ncols MUST match the database's column count (SE names DBs by arity:
-- DB_Is_InCombat(1) vs DB_Is_InCombat(2) are different keys)
local function factGuids(dbName, ncols)
    local db = Osi[dbName]
    if not db then return {} end
    local args = {}
    for _ = 1, (ncols or 1) do args[#args + 1] = nil end
    local ok, rows = pcall(function () return db:Get(table.unpack(args)) end)
    if not ok then log(dbName .. ":Get threw:", rows); return {} end
    local out = {}
    if type(rows) == "table" then
        for _, row in pairs(rows) do
            local g = rowGuid(row)
            if g then out[#out + 1] = g end
        end
    end
    return out
end

-- spawn ----------------------------------------------------------------------
local function spawnCreature(anchor, entry, targetLevel)
    local ok = pcall(function ()
        local dx, dy = rand(1, 3), rand(1, 3)
        local created = Osi.CreateAtObject(entry.id, anchor, dx, dy, "", 1)
        if (not created or created == "") and (dx ~= 1 or dy ~= 1) then
            created = Osi.CreateAtObject(entry.id, anchor, 1, 1, "", 1)
        end
        if created and created ~= "" then
            local newLvl = "?"
            if targetLevel then
                local okL, eL = pcall(Osi.SetLevel, created, targetLevel)
                if okL then
                    newLvl = targetLevel
                    local okG, lvl = pcall(Osi.GetLevel, created)  -- immediate read-back
                    if okG then newLvl = tostring(lvl) end
                    pcall(Ext.Timer.WaitFor, VERIFY_DELAY_MS, function ()
                        local okV, vLvl = pcall(Osi.GetLevel, created)
                        if okV then log("verify", entry.id, "lvl", vLvl, "wanted", targetLevel) end
                    end)
                else
                    log("SetLevel threw:", eL)
                end
            end
            pcall(Osi.SetFaction, created, EVIL)
            local okX, eX = pcall(Osi.SetHostileAndEnterCombat, EVIL, HERO, created, anchor)
            log("spawn", entry.id, "hp", entry.hp, "lvl", newLvl,
                (okX and "hostile" or ("hostility threw: " .. tostring(eX))))
        else
            log("spawn FAILED", entry.id)
        end
    end)
    if not ok then log("spawn threw for", entry.id) end
end

-- discovery: enemy intel + types ----------------------------------------------
local function isFriendly(guid)
    if rosterPlayers[guid] then return true end
    local okF, fac = pcall(Osi.GetFaction, guid)
    if okF and type(fac) == "string" and fac:sub(1, 4) == "Hero" then return true end
    return false
end

local function discover(combatId, players)
    if not raceDumped then
        raceDumped = true
        pcall(function ()
            local all = Ext.StaticData.GetAll("Race")
            local first = all and all[1]
            local res = first and Ext.StaticData.Get(first, "Race")
            log("Race static sample dump:", res and Ext.DumpExport(res) or "none")
        end)
    end

    rosterPlayers = {}
    for _, g in ipairs(players) do rosterPlayers[g] = true end

    -- union of the combat DB (2 columns) and the EnteredCombat roster for this combat
    local candidates = {}
    for _, g in ipairs(factGuids("DB_Is_InCombat", 2)) do
        candidates[#candidates + 1] = g
    end
    for _, g in ipairs(combatRoster[combatId] or {}) do
        candidates[#candidates + 1] = g
    end

    local enemies, dedup = {}, {}
    for _, g in ipairs(candidates) do
        if g and g ~= "" and not dedup[g] and not isFriendly(g) then
            dedup[g] = true
            local lvl = select(2, pcall(Osi.GetLevel, g))
            local race = select(2, pcall(Osi.GetRace, g, 0))
            local fac = select(2, pcall(Osi.GetFaction, g))
            local t = RACE_TO_TYPE[tostring(race)] or "?"
            log("enemy:", g, "lvl", lvl, "race", race, "type", t, "faction", fac)
            enemies[#enemies + 1] = { guid = g, level = tonumber(lvl), race = tostring(race), type = t }
        end
    end
    return enemies
end

local function dominantType(enemies)
    local counts = {}
    for _, e in ipairs(enemies) do
        if e.type ~= "?" then counts[e.type] = (counts[e.type] or 0) + 1 end
    end
    local best, n = nil, 0
    for t, c in pairs(counts) do if c > n then best, n = t, c end end
    return best
end

local function pickFrom(typeName, maxCost)
    local pool = CHAOS_DB and CHAOS_DB[typeName]
    if not pool or #pool == 0 then return nil end
    -- try 20 random picks for one within budget; fall back to cheapest entry
    for _ = 1, 20 do
        local e = pool[rand(1, #pool)]
        if e.cost <= maxCost then return e end
    end
    local cheapest = pool[1]
    for _, e in ipairs(pool) do if e.cost < cheapest.cost then cheapest = e end end
    return cheapest.cost <= maxCost and cheapest or nil
end

-- level math: never above the player's level while they are SOFT_CAP_LEVEL or lower
local function targetLevelFor(base)
    if base <= SOFT_CAP_LEVEL then
        return math.max(1, base + rand(-2, 0))
    end
    return math.max(1, base + rand(-LEVEL_JITTER, LEVEL_JITTER))
end

-- main wave -------------------------------------------------------------------
local function reinforce(host, enemies)
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    local party = #factGuids("DB_Players", 1)
    local budget = math.floor(base * rand(BUDGET_LO, BUDGET_HI) * (1 + PARTY_KNOB * math.max(0, party - 4)))
    local anchors = { host }
    for _, e in ipairs(enemies) do anchors[#anchors + 1] = e.guid end

    local etype = dominantType(enemies) or DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)]
    if not CHAOS_DB[etype] then etype = DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)] end
    local targetLevel = targetLevelFor(base)
    log("wave: type", etype, "budget", budget, "(base", base, "x2-4, party", party .. ")",
        "spawnlevel", targetLevel, "anchors", #anchors)

    -- pack first (leader gets a separate allowance, and only rolls for packs >= 2)
    local spawned, spent = 0, 0
    while spawned < MAX_SPAWNS - 1 and budget - spent > 0 do
        local e = pickFrom(etype, budget - spent)
        if not e then
            e = pickFrom(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], budget - spent)
        end
        if not e then break end
        spawnCreature(anchors[rand(1, #anchors)], e, targetLevel)
        spawned, spent = spawned + 1, spent + e.cost
    end

    -- leader: roll once per pack; same type ~90%, cross-type from the AFFINITY map
    if spawned >= 2 then
        local chance = LEADER_TEST and 100 or LEADER_CHANCE
        if rand(1, 100) <= chance then
            local ltype = etype
            if rand(1, 100) > SAME_TYPE_LEADER then
                local opts = {}
                for _, t in ipairs(AFFINITY[etype] or {}) do
                    if t ~= etype then opts[#opts + 1] = t end
                end
                if #opts > 0 then ltype = opts[rand(1, #opts)] end
            end
            local leader = pickFrom(ltype, math.floor(budget / LEADER_ALLOWANCE))
            if leader then
                local lvl = base <= SOFT_CAP_LEVEL and base or targetLevel + rand(0, 2)
                log("leader: type", ltype, "(pack", etype .. ")", leader.id, "hp", leader.hp, "lvl", lvl)
                spawnCreature(anchors[rand(1, #anchors)], leader, lvl)
                spawned, spent = spawned + 1, spent + leader.cost
            else
                log("leader: no", ltype, "within allowance", math.floor(budget / LEADER_ALLOWANCE))
            end
        end
    end
    log("wave done:", spawned, "spawned,", spent, "/", budget, "spent")
end

-- listeners --------------------------------------------------------------------
local ok, err = pcall(function ()
    -- roster: track who actually entered each combat (backup for the DB read)
    Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", function (object, combatGuid)
        local roster = combatRoster[combatGuid]
        if not roster then
            local n = 0
            for _ in pairs(combatRoster) do n = n + 1 end
            if n >= 40 then combatRoster = {} end   -- old combats are long dead
            roster = {}; combatRoster[combatGuid] = roster
        end
        roster[#roster + 1] = object
    end)

    Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function (combatId)
        if seen[combatId] then return end
        seen[combatId] = true

        local chance = TEST_MODE and 100 or math.min(100, BASE_CHANCE + misses * rand(STACK_MIN, STACK_MAX))
        local roll = rand(1, 100)
        if roll > chance then
            misses = misses + 1
            log("CombatStarted", combatId, "no reinforcements (roll", roll, ">", chance, "stack", misses .. ")")
            return
        end
        misses = 0
        log("CombatStarted", combatId, "TRIGGERED (chance", chance .. "%)")

        -- delay the wave: enemies must have entered combat before we can classify them
        pcall(Ext.Timer.WaitFor, WAVE_DELAY_MS, function ()
            local okH, host = pcall(Osi.GetHostCharacter)
            if not okH then log("GetHostCharacter threw:", host); return end
            if not host or host == "" then log("no host anchor, giving up"); return end
            local players = factGuids("DB_Players", 1)
            local enemies = discover(combatId, players)
            log("party:", #players, "enemies:", #enemies)
            reinforce(host, enemies)
        end)
    end)
end)
if ok then log("Chaos.lua v3.1 loaded; DB types:", CHAOS_DB and "ok" or "MISSING") else log("registration threw:", err) end

-- console: !martin_chaos force wave, !martin_status, !martin_wolf
Ext.RegisterConsoleCommand("martin_chaos", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        local players = factGuids("DB_Players", 1)
        reinforce(host, discover(nil, players))
    end
end)
Ext.RegisterConsoleCommand("martin_status", function ()
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    log("status: misses", misses, "TEST_MODE", tostring(TEST_MODE),
        "LEADER_TEST", tostring(LEADER_TEST), "combats seen", n)
end)
Ext.RegisterConsoleCommand("martin_wolf", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        spawnCreature(host, { id = "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11", hp = 11, cost = 1 }, 1)
    end
end)
