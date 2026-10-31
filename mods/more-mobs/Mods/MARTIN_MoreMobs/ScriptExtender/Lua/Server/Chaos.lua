-- MARTIN_MoreMobs chaos/reinforcement engine v3 (server-side Lua).
-- Uses the generated CreatureDB (Ext.Require'd first): every GENERIC spawnable creature in the
-- game, grouped by creature type, with hp + cost (hp/10 budget proxy). Sources: tools/build_creature_db.py.
--
-- Owner spec (2026-10-31): stacking trigger (base 20%, +5..25% per miss; TEST_MODE=100% while
-- testing); total spawn budget ~ player level x random factor (never a pile of +3-level mobs);
-- reinforcements should match the ENCOUNTER's creature family (fiends -> fiends, beasts ->
-- beasts) with a chance of a "leader" wildcard; scale spawns to party level via Osi.SetLevel
-- (owner runs levelmax 20/50 mods, so spawns must not stay level-1 fodder).
--
-- Enemy type detection (v3, no risky APIs): from the discovery log we learn each enemy's Osiris
-- GetRace string; RACE_TO_TYPE below maps those strings to the 14 creature types. Unknown races
-- log as race=<x> type=? so the map grows every session. (Candidate upgrade: Ext.StaticData
-- "Race" resource walk - a sample dump is logged to learn its fields.)
--
-- Proven spawn sequence unchanged (probe v3): CreateAtObject(Name_GUID, anchor, dx, dy, "", 1)
-- -> SetFaction(EVIL) -> SetHostileAndEnterCombat(EVIL, HERO, created, host), E8b pair verbatim.
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
local MAX_SPAWNS = 8
local LEVEL_JITTER = 2              -- SetLevel target = hostLevel + rand(-J, +J)
local LEADER_CHANCE = 20            -- % of triggered fights get one bigger wildcard
local OFFSET_MIN, OFFSET_MAX = 1, 3

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

local DEFAULT_TYPES = { "Beast", "Monstrosity", "Humanoid", "Undead", "Fiend" }
local LEADER_TYPES = { "Monstrosity", "Humanoid" }

local misses = 0
local seen = {}
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

local function factGuids(dbName)
    local db = Osi[dbName]
    if not db then return {} end
    local ok, rows = pcall(function () return db:Get(nil) end)
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
        local dx, dy = rand(OFFSET_MIN, OFFSET_MAX), rand(OFFSET_MIN, OFFSET_MAX)
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
                    local okG, lvl = pcall(Osi.GetLevel, created)  -- verify it stuck
                    if okG then newLvl = tostring(lvl) end
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
local function discover(players, host)
    if not raceDumped then
        raceDumped = true
        pcall(function ()
            local all = Ext.StaticData.GetAll("Race")
            local first = all and all[1]
            local res = first and Ext.StaticData.Get(first, "Race")
            log("Race static sample dump:", res and Ext.DumpExport(res) or "none")
        end)
    end
    local hostFac = select(2, pcall(Osi.GetFaction, host))
    local skip = {}
    for _, g in ipairs(players) do skip[g] = true end
    local enemies = {}
    for _, g in ipairs(factGuids("DB_Is_InCombat")) do
        if g and not skip[g] then
            local lvl = select(2, pcall(Osi.GetLevel, g))
            local race = select(2, pcall(Osi.GetRace, g, 0))
            local fac = select(2, pcall(Osi.GetFaction, g))
            if fac and fac ~= "" and fac ~= hostFac then
                local t = RACE_TO_TYPE[tostring(race)] or "?"
                log("enemy:", g, "lvl", lvl, "race", race, "type", t)
                enemies[#enemies + 1] = { guid = g, level = tonumber(lvl), race = tostring(race), type = t }
            end
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

-- main wave -------------------------------------------------------------------
local function reinforce(host, enemies)
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    local party = #factGuids("DB_Players")
    local budget = math.floor(base * rand(BUDGET_LO, BUDGET_HI) * (1 + PARTY_KNOB * math.max(0, party - 4)))
    local anchors = { host }
    for _, e in ipairs(enemies) do anchors[#anchors + 1] = e.guid end

    local etype = dominantType(enemies) or DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)]
    if not CHAOS_DB[etype] then etype = DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)] end
    local targetLevel = math.max(1, base + rand(-LEVEL_JITTER, LEVEL_JITTER))
    log("wave: type", etype, "budget", budget, "(base", base, "x2-4, party", party .. ")",
        "spawnlevel", targetLevel, "anchors", #anchors)

    local spawned, spent = 0, 0
    if rand(1, 100) <= LEADER_CHANCE then
        local lt = LEADER_TYPES[rand(1, #LEADER_TYPES)]
        local leader = pickFrom(lt, math.floor(budget / 2))
        if leader then
            spawnCreature(anchors[rand(1, #anchors)], leader, targetLevel + rand(0, 2))
            spawned, spent = spawned + 1, spent + leader.cost
        end
    end
    while spawned < MAX_SPAWNS and budget - spent > 0 do
        local e = pickFrom(etype, budget - spent)
        if not e then
            e = pickFrom(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], budget - spent)
        end
        if not e then break end
        spawnCreature(anchors[rand(1, #anchors)], e, targetLevel)
        spawned, spent = spawned + 1, spent + e.cost
    end
    log("wave done:", spawned, "spawned,", spent, "/", budget, "spent")
end

-- listener --------------------------------------------------------------------
local ok, err = pcall(function ()
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

        local okH, host = pcall(Osi.GetHostCharacter)
        if not okH then log("GetHostCharacter threw:", host); return end
        if not host or host == "" then log("no host anchor, giving up"); return end

        local players = factGuids("DB_Players")
        local enemies = discover(players, host)
        log("party:", #players, "enemies:", #enemies)
        reinforce(host, enemies)
    end)
end)
if ok then log("Chaos.lua v3 loaded; DB types:", CHAOS_DB and table.getn and "ok" or "ok") else log("registration threw:", err) end

-- console: !martin_chaos force wave, !martin_status, !martin_wolf
Ext.RegisterConsoleCommand("martin_chaos", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then reinforce(host, discover(factGuids("DB_Players"), host)) end
end)
Ext.RegisterConsoleCommand("martin_status", function ()
    log("status: misses", misses, "TEST_MODE", tostring(TEST_MODE))
end)
Ext.RegisterConsoleCommand("martin_wolf", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        spawnCreature(host, { id = "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11", hp = 11, cost = 1 }, 1)
    end
end)
