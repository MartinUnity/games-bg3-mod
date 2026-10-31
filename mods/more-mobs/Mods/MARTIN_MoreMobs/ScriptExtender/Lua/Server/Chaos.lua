-- MARTIN_MoreMobs chaos/reinforcement engine v3.3 (server-side Lua).
-- Uses the generated CreatureDB (Ext.Require'd first): every GENERIC spawnable creature in the
-- game, grouped by creature type, with NATIVE stat blocks (hp, cost=hp/10, ac, str, dex, con,
-- ea=ExtraAttack). Sources: tools/build_creature_db.py.
--
-- Owner spec: stacking trigger (base 20%, +5..25% per miss; TEST_MODE=100% while testing);
-- budget = hostLevel x rand(2-4) x party knob; reinforcements match the ENCOUNTER's creature
-- family; leader rolls only when a pack of >= 2 spawned, ~90% in-type / ~10% cross-type via the
-- AFFINITY map, spawned OUTSIDE the budget (jackpot escalation); at host level <= 2 mobs never
-- exceed the player's level.
--
-- v3.3 playtest learnings (2026-10-31, game #2: solo lvl-1 Merregon nearly TPK'd the party):
--   - Osi.SetLevel changes the LEVEL NUMBER but does NOT rescale fixed monster stat blocks
--     (Merregon: "lvl 1", still 45hp/str18/AC16/ExtraAttack). So difficulty control happens at
--     PICK time: GATES below cap native hp/AC/ability scores at levels 1-2 and ban ExtraAttack;
--     HEAVY_TYPES (Dragon/Giant/Celestial) need host level >= 5.
--   - factGuids arity bug fixed: appending nils to a table does not grow it, so Get got zero
--     args and SE looked up e.g. 'DB_Players(0)'. Use table.unpack({}, 1, ncols).
--   - companions (faction 'Companion...') are friendly, not enemies (Laezel was classified
--     enemy in game #2); party size via CombatGetInvolvedPartyMembersCount when in combat.
--   - the GustavDev Status_BOOST HP override (HEALTHBOOST_HARDCORE) is commented out in the
--     .txt for calibration; Lua-side MOB_HP_BOOST placeholder stays off.
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
local WAVE_DELAY_MS = 1500         -- let enemies enter combat before we classify the fight
local VERIFY_DELAY_MS = 2000       -- delayed SetLevel verification

-- HP boost formerly in GustavDev Status_BOOST.txt (HEALTHBOOST_HARDCORE, disabled there
-- 2026-10-31 for calibration). Lua-side reimplementation will use a custom stats file;
-- "" = off. Do not enable while calibrating native mob stats.
local MOB_HP_BOOST = ""

-- native-stat gates: SetLevel does NOT rescale fixed monster stat blocks (playtest: Merregon
-- kept 45hp/str18/AC16 at "lvl 1"), so at low levels we pick creatures that are NATIVELY
-- harmless instead: hp/AC/ability caps per host level, plus an ExtraAttack ban (the Merregon's
-- 2x hits were the actual killer). From level 3 anything goes except heavy types.
local GATES = {
    [1] = { stat = 12, ac = 14, hp = 20 },
    [2] = { stat = 14, ac = 15, hp = 35 },
}
local HEAVY_TYPES = { Dragon = true, Giant = true, Celestial = true }
local HEAVY_LEVEL = 5

-- Equipment (phase 1: Larian random tables via GenerateTreasure; own item-cost DB later).
-- Only HUMANOID spawns get gear - other types have innate attacks an equipped weapon would
-- replace (and imps do not hold swords). Tiers follow the owner's band spec; "cost x1.5/x2"
-- maps to the next-better vanilla random table. Loot tables are level-segmented internally
-- (ST_LightArmor switches contents at level 5), so we pass the player level.
local EQUIP_MOBS = true
local POTION_HEAL = {
    "CONS_Potion_Healing_A_d47006e9-8a51-453d-b200-9e0d42e9bbab",
    "CONS_Potion_Healing_A_Greater_e3b95c96-dc26-40fe-bfc0-baa05e1abd20",
    "CONS_Potion_Healing_A_Superior_df4f3495-abaf-4732-b82f-55bcccd561db",
    "CONS_Potion_Healing_A_Supreme_7d78f227-e8d4-486d-8121-25cf0bee751d",
}
local POTION_SPEED = "CONS_Potion_Speed_ad9f3f24-d755-48b6-aa7b-c34da068209f"
local equipPending = {}   -- guid of freshly spawned humanoid -> true (auto-equip guard)

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
    local ok, rows = pcall(function () return db:Get(table.unpack({}, 1, ncols or 1)) end)
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

-- equipment: roll loot tables + consumables into the mob's inventory. The TemplateAddedTo
-- listener below auto-equips whatever gear lands there; potions stay in inventory (mob AI
-- drinks them on its own).
local function healPotionFor(base)
    if base >= 11 then return POTION_HEAL[3] end
    if base >= 6 then return POTION_HEAL[2] end
    return POTION_HEAL[1]
end

local function equipMob(created, base)
    if not EQUIP_MOBS then return end
    equipPending[created] = true
    -- owner's bands: <=80% basic, <=95% weapon up, <=98% weapon+armor up, else jackpot
    local roll = rand(1, 100)
    local tier = roll <= 80 and 1 or (roll <= 95 and 2 or (roll <= 98 and 3 or 4))
    if base <= SOFT_CAP_LEVEL then tier = 1 end           -- early game: cheap gear only
    local weaponTable = tier == 1 and "ST_SimpleMeleeWeapons" or "ST_MartialMeleeWeapons"
    local armorTable = "ST_LightArmor"
    if tier == 3 then armorTable = "ST_MediumArmor" end
    if tier == 4 then armorTable = base >= HEAVY_LEVEL and "ST_HeavyArmor" or "ST_MediumArmor" end
    log("equip: tier", tier, "(roll", roll .. ")", weaponTable, "+", armorTable)
    pcall(Osi.GenerateTreasure, created, weaponTable, base, created)
    pcall(Osi.GenerateTreasure, created, armorTable, base, created)
    -- consumables
    local potions = {}
    if tier == 1 then
        if rand(1, 100) <= 10 then potions[#potions + 1] = healPotionFor(base) end
    elseif tier == 2 then
        if rand(1, 100) <= 25 then potions[#potions + 1] = healPotionFor(base) end
    elseif tier == 3 then
        potions[#potions + 1] = healPotionFor(base)
    else
        potions[#potions + 1] = healPotionFor(base)
        potions[#potions + 1] = healPotionFor(base)
        potions[#potions + 1] = POTION_SPEED   -- "extra random thing", not overpowered
    end
    for _, p in ipairs(potions) do
        pcall(Osi.TemplateAddTo, p, created, 1, 0)
    end
    if #potions > 0 then log("equip: potions", #potions) end
end

-- spawn ----------------------------------------------------------------------
local function spawnCreature(anchor, entry, targetLevel, doEquip, base)
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
            log("spawn", entry.id, "hp", entry.hp, "ac", entry.ac or "?",
                "str", entry.str or entry.dex or "?",
                (entry.ea and "ExtraAttack " or ""), "lvl", newLvl,
                (okX and "hostile" or ("hostility threw: " .. tostring(eX))))
            if doEquip then equipMob(created, base or 1) end
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
    if okF and type(fac) == "string" then
        return fac:sub(1, 4) == "Hero"          -- player chars: "Hero Player1_<guid>"
            or fac:sub(1, 9) == "Companion"    -- NPC-keeper/hired companions (Laezel etc.)
    end
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

-- native-stat gate for the player's level: nil = entry is fine
local function passesGate(e, base)
    local g = GATES[base]
    if g then
        if e.hp > g.hp then return false end
        if e.ac and e.ac > g.ac then return false end
        local best = math.max(e.str or 0, e.dex or 0)
        if best > g.stat then return false end
        if e.ea then return false end  -- ExtraAttack at lvl 1-2 = TPK fuel
    end
    return true
end

local function gatedPool(typeName, base)
    local pool = CHAOS_DB and CHAOS_DB[typeName]
    if not pool or #pool == 0 then return nil end
    if HEAVY_TYPES[typeName] and base < HEAVY_LEVEL then return nil end
    local out = {}
    for _, e in ipairs(pool) do
        if passesGate(e, base) then out[#out + 1] = e end
    end
    return out
end

local function pickFrom(typeName, maxCost, base)
    local pool = gatedPool(typeName, base)
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

-- leaders are deliberately OUTSIDE the budget: the ~10% roll is meant to occasionally
-- escalate a fight hard. Pick from the beefier half of the gated pool.
local function pickLeaderFrom(typeName, base)
    local pool = gatedPool(typeName, base)
    if not pool or #pool == 0 then return nil end
    local sorted = {}
    for _, e in ipairs(pool) do sorted[#sorted + 1] = e end
    table.sort(sorted, function (a, b) return a.cost < b.cost end)
    local from = math.max(1, math.floor(#sorted / 2) + 1)
    return sorted[rand(from, #sorted)]
end

-- level math: never above the player's level while they are SOFT_CAP_LEVEL or lower
local function targetLevelFor(base)
    if base <= SOFT_CAP_LEVEL then
        return math.max(1, base + rand(-2, 0))
    end
    return math.max(1, base + rand(-LEVEL_JITTER, LEVEL_JITTER))
end

-- main wave -------------------------------------------------------------------
local function reinforce(host, enemies, combatId)
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    -- party size: count the members actually involved in this combat when we can
    local party = #factGuids("DB_Players", 1)
    local okN, n = pcall(Osi.CombatGetInvolvedPartyMembersCount, combatId)
    if combatId and okN and tonumber(n) then party = tonumber(n) end
    local budget = math.floor(base * rand(BUDGET_LO, BUDGET_HI) * (1 + PARTY_KNOB * math.max(0, party - 4)))
    local anchors = { host }
    for _, e in ipairs(enemies) do anchors[#anchors + 1] = e.guid end

    local etype = dominantType(enemies)
    -- no heavy types (dragons, giants...) below HEAVY_LEVEL even if the encounter is one
    if not etype or (HEAVY_TYPES[etype] and base < HEAVY_LEVEL) then
        etype = DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)]
    end
    if not gatedPool(etype, base) then etype = DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)] end
    local targetLevel = targetLevelFor(base)
    log("wave: type", etype, "budget", budget, "(base", base, "x2-4, party", party .. ")",
        "spawnlevel", targetLevel, "anchors", #anchors,
        base <= SOFT_CAP_LEVEL and "gate " .. base or "")

    -- pack first (leader gets a separate allowance, and only rolls for packs >= 2)
    local spawned, spent = 0, 0
    equipPending = {}
    while spawned < MAX_SPAWNS - 1 and budget - spent > 0 do
        local e = pickFrom(etype, budget - spent, base)
        if not e then
            e = pickFrom(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], budget - spent, base)
        end
        if not e then
            log("pack: nothing fits budget", budget - spent, "at level", base)
            break
        end
        spawnCreature(anchors[rand(1, #anchors)], e, targetLevel, etype == "Humanoid", base)
        spawned, spent = spawned + 1, spent + e.cost
    end

    -- leader: roll once per pack (>= 2 mobs); same type ~90%, cross-type from the AFFINITY map.
    -- Spawned OUTSIDE the budget - the 10% roll is the "fight just got serious" jackpot.
    if spawned >= 2 then
        local chance = LEADER_TEST and 100 or LEADER_CHANCE
        if rand(1, 100) <= chance then
            local ltype = etype
            -- no cross-type surprises while the low-level ceiling is active (lvl-1 owlbear = TPK)
            if base > SOFT_CAP_LEVEL and rand(1, 100) > SAME_TYPE_LEADER then
                local opts = {}
                for _, t in ipairs(AFFINITY[etype] or {}) do
                    if t ~= etype then opts[#opts + 1] = t end
                end
                if #opts > 0 then ltype = opts[rand(1, #opts)] end
            end
            local leader = pickLeaderFrom(ltype, base)
            if leader then
                local lvl = base <= SOFT_CAP_LEVEL and base or targetLevel + rand(0, 2)
                log("leader: type", ltype, "(pack", etype .. ")", leader.id,
                    "hp", leader.hp, "cost", leader.cost, "lvl", lvl, "(outside budget)")
                spawnCreature(anchors[rand(1, #anchors)], leader, lvl, ltype == "Humanoid", base)
                spawned = spawned + 1
            else
                log("leader: no", ltype, "entries in DB")
            end
        end
    end
    log("wave done:", spawned, "spawned, pack", spent, "/", budget, "spent (leader outside budget)")
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

    -- auto-equip gear that GenerateTreasure rolls into our spawned humanoids
    Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function (tmpl, object, holder, addType)
        if equipPending[holder] then
            -- weapons/armor equip into their slot; potions fail into inventory (param 3)
            local okE, eE = pcall(Osi.Equip, holder, object, 1, 0, 1)
            if okE then log("equipped", object, "on", holder) end
        end
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
            reinforce(host, enemies, combatId)
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
