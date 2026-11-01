-- ChaosReinforcements chaos/reinforcement engine (server side). Ext.Require'd AFTER
-- Common.lua (log + constants), CreatureDB.lua (CHAOS_DB) and Equip.lua (EquipMob).
--
-- Owner spec: stacking trigger (base 30%, +10..30% per miss; TEST_MODE=100% while testing);
-- budget = hostLevel x rand(2-4) x party knob; reinforcements match the ENCOUNTER's creature
-- family; leader rolls only when a pack of >= 2 spawned, ~90% in-type / ~10% cross-type via
-- the AFFINITY map, spawned OUTSIDE the budget (jackpot escalation); at host level <= 2 mobs
-- never exceed the player's level.
--
-- Learnings baked in (see docs/HANDOVER.md):
--   - NO Osi.SetLevel calls anywhere (game hard-crash 2026-11-01: it faults inside
--     OsirisWrappers::CallWrapper -> bg3.exe; pcall cannot survive native crashes -
--     and it only sets the level NUMBER, never rescales fixed monster stat blocks);
--     difficulty control happens at PICK time (CreatureDB native stats + GATES below).
--   - SE databases are keyed by ARITY: DB_Is_InCombat has 2 columns -> Get(nil, nil) via
--     table.unpack({}, 1, ncols). Appending nils to a table does not grow it.
--   - Companions ("Companion..." factions) are friendly; party size via
--     CombatGetInvolvedPartyMembersCount when in a combat.
--   - Anchors: spawn next to the fight's own enemies ("near their allies"); the host char is
--     only a fallback when the fight could not be classified.

-- Tunables ------------------------------------------------------------------
local TEST_MODE = false             -- real odds: base 30% + 10..30% per miss
local BASE_CHANCE = 30
local STACK_MIN, STACK_MAX = 10, 30 -- +% per encounter that didn't trigger
local BUDGET_LO, BUDGET_HI = 2, 4   -- budget = hostLevel * rand(LO,HI), costs are hp/10
local PARTY_KNOB = 0.15             -- +15% budget per party member beyond 4
local MAX_SPAWNS = 8                -- total, leader included
local LEADER_CHANCE = 10            -- % of packs (>=2 mobs) that get a leader
local LEADER_TEST = false           -- real odds: 10% leader for packs >= 2
local SAME_TYPE_LEADER = 90         -- % of leaders drawn from the pack's own type
local WAVE_DELAY_MS = 1500         -- let enemies enter combat before we classify the fight
-- Save-load quiet window (owner 2026-11-01: loading a save into an ONGOING fight
-- re-fires CombatStarted ~12 s after SessionLoaded -> a second reinforcement wave
-- spawned around a restored goblin fight). Rolls are suppressed this long after
-- every session load; live log showed CombatStarted at +16 s vs SessionLoaded +4 s.
local LOAD_QUIET_MS = 20000

-- v3.29 team-mode reinforcements (option 2, owner: "humans among goblins is too odd" -
-- combat reinforcements get the same CHAOST class-team composer as wild squads, with
-- ONE donor race per wave matching the fight's dominant enemy race).
local TEAM_MIN_LEVEL = 3        -- below this, CHAOST baked levels bypass the calibrated
                                -- low-level pool GATES (a lvl-3 team vs a lvl-2 party is
                                -- a TPK) -> legacy gated-pool path instead
local TEAM_CHAOS_CHANCE = 20    -- % of waves that ignore the enemy race for a random one
local TEAM_COST = 0.7           -- member cost ~= lvl * this (baked CHAOST hp ~ 11/lvl but
                                -- class chars are squishier per HP than fixed monsters)

-- HP boost formerly in GustavDev Status_BOOST.txt (HEALTHBOOST_HARDCORE, disabled there
-- 2026-10-31 for calibration). Lua-side reimplementation will use a custom stats file;
-- "" = off. Do not enable while calibrating native mob stats.
local MOB_HP_BOOST = ""

-- native-stat gates: at low levels pick creatures that are NATIVELY harmless:
-- hp/AC/ability caps per host level, plus an ExtraAttack ban (the Merregon's 2x hits were
-- the actual killer). From level 3 anything goes except heavy types (HEAVY_TYPES/HEAVY_LEVEL).

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

local misses = 0
local seen = {}
local loadQuietUntil = 0     -- MonotonicMs() deadline: no reinforcement rolls after a session load
local combatRoster = {}   -- combatGuid -> { participant guids, via EnteredCombat }
local rosterPlayers = {}  -- guid -> true (skip list), refreshed per wave
local raceDumped = false

local function rand(lo, hi) return math.random(lo, hi) end

-- spawn ----------------------------------------------------------------------
local function spawnCreature(anchor, entry, targetLevel, doEquip, base)
    local ok, created = pcall(function ()
        local dx, dy = rand(1, 3), rand(1, 3)
        local created = Osi.CreateAtObject(entry.id, anchor, dx, dy, "", 1)
        if (not created or created == "") and (dx ~= 1 or dy ~= 1) then
            created = Osi.CreateAtObject(entry.id, anchor, 1, 1, "", 1)
        end
        if created and created ~= "" then
            -- NO Osi.SetLevel here (game hard-crash 2026-11-01: SetLevel faulted inside
            -- bg3se OsirisWrappers::CallWrapper -> bg3.exe; pcall cannot survive engine
            -- crashes - and v3.3 proved SetLevel only sets the level NUMBER, it never
            -- rescales fixed monster stat blocks, i.e. cosmetic next to the crash risk).
            pcall(Osi.SetFaction, created, EVIL)
            -- self-correction on the template's NATIVE level (nothing re-levels anymore):
            -- a native lvl-10 caster among lvl-3s is a TPK, despawn and re-pick
            local okG, lvlNow2 = pcall(Osi.GetLevel, created)
            local lvlNow = tonumber(okG and lvlNow2 or nil)
            if lvlNow and base and lvlNow > base + LEVEL_JITTER + OVERLEVEL_TOLERANCE then
                log("over-level despawn:", entry.id, "lvl", lvlNow,
                    "> base", base, "+ tolerance - re-picking")
                -- DEFERRED delete (crash suspect 2026-11-02): deleting a character
                -- milliseconds after creation crashed the game once (summon-lifecycle
                -- template). 3s settle time; if it managed to enter combat meanwhile,
                -- leave it (deleting a combatant mid-fight is worse than one hot mob).
                pcall(Ext.Timer.WaitFor, 3000, function ()
                    local okI, ic = pcall(Osi.IsInCombat, created)
                    if okI and ic == 1 then
                        log("over-level despawn skipped (in combat):", entry.id)
                    else
                        pcall(Osi.RequestDeleteTemporary, created)
                    end
                end)
                return nil
            end
            local okX, eX = pcall(Osi.SetHostileAndEnterCombat, EVIL, HERO, created, anchor)
            log("spawn", entry.id, "hp", entry.hp, "ac", entry.ac or "?",
                "str", entry.str or entry.dex or "?",
                (entry.ea and "ExtraAttack " or ""), "lvl", newLvl,
                (okX and "hostile" or ("hostility threw: " .. tostring(eX))))
            markSpawned(created)
            if entry.nm then FlavorNameFix(created, entry.nm) end   -- blank-name fallback (Flavor.lua)
            tagAsOurs(created)
            if doEquip then EquipMob(created, base or 1, entry) end
            return created
        else
            log("spawn FAILED", entry.id)
            return nil
        end
    end)
    if not ok then log("spawn threw for", entry.id) end
    return ok and created or nil
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
            enemies[#enemies + 1] = { guid = g, level = tonumber(lvl), race = tostring(race),
                                       type = t, fac = tostring(fac) }
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

-- main wave -------------------------------------------------------------------
local function reinforce(host, enemies, combatId)
    -- never stack reinforcements on top of our own patrols/leftovers (owner request:
    -- wave survivors became a roving pack, and the engine waved again onto them).
    -- Covers ORPHANS too: BG3 saves temporary chars, so packs from a previous
    -- session (no registry entries) are recognized by tag or by our wild
    -- evil-pack faction - both persist in the savegame.
    for _, e in ipairs(enemies) do
        if isOurs(e.guid) or e.fac == WILD_EVIL_FACTION then
            markSpawned(e.guid)
            log("fight vs our own patrol - no reinforcements")
            return
        end
    end
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    -- party size: count the members actually involved in this combat when we can
    local party = #factGuids("DB_Players", 1)
    local okN, n = pcall(Osi.CombatGetInvolvedPartyMembersCount, combatId)
    if combatId and okN and tonumber(n) then party = tonumber(n) end
    local budget = math.floor(base * rand(BUDGET_LO, BUDGET_HI) * (1 + PARTY_KNOB * math.max(0, party - 4)))
    -- anchor at the fight's own enemies when we know them ("reinforcements arrive near their
    -- allies"); the host is only a fallback for fights we could not classify
    local anchors = {}
    for _, e in ipairs(enemies) do anchors[#anchors + 1] = e.guid end
    if #anchors == 0 then anchors = { host } end

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

    -- v3.29 TEAM MODE (option 2, owner spec): Humanoid fights with enough budget run
    -- the CHAOST class-team composer (slots/roles/level like wild squads) instead of
    -- the bag-of-pool-mobs pick, and ONE donor race for the whole wave matching the
    -- fight's dominant enemy race (goblin fight -> goblin squad, not human mobs).
    -- Gated to base >= TEAM_MIN_LEVEL: below that, baked CHAOST levels bypass the
    -- calibrated low-level pool GATES. TEAM_CHAOS_CHANCE keeps a random race mix.
    local teamMode, teamSlotList, teamRaceKey, teamLevel, teamCost = false, nil, nil, nil, 0
    if etype == "Humanoid" and base >= TEAM_MIN_LEVEL and CHAOS_TEAMS ~= nil then
        teamRaceKey = dominantRaceKey(enemies)
        local races = donorRaces()
        if #races > 0 and (not teamRaceKey or rand(1, 100) <= TEAM_CHAOS_CHANCE) then
            teamRaceKey = races[rand(1, #races)]
        end
        teamLevel = teamLevelFor(base)
        teamCost = math.max(2, math.ceil(teamLevel * TEAM_COST))
        local size = math.min(MAX_SPAWNS - 1, math.floor(budget / teamCost))  -- leader slot free
        if size >= 2 then
            teamMode = true
            teamSlotList = teamSlots(size)
            log("wave: TEAM mode -", table.concat(teamSlotList, "/"),
                "race", teamRaceKey or "?", "lvl", teamLevel, "cost", teamCost, "size", size)
        end
    end

    -- pack first (leader gets a separate allowance, and only rolls for packs >= 2)
    local spawned, spent = 0, 0
    EquipResetPending()
    local fails = 0
    if teamMode then
        for i = 1, #teamSlotList do
            local role = teamSlotList[i]
            local entry = teamEntry(role, teamLevel, teamRaceKey)
            if not entry then
                log("team: no CHAOST template for", role, "- pool fallback")
            end
            local created = entry and spawnCreature(anchors[rand(1, #anchors)], entry,
                                                    teamLevel, true, base)
            if entry and not created then
                log("team: slot", role, "spawn failed - pool retry")
                entry = nil
            end
            if not entry then
                local pool = gatedPool("Humanoid", base)
                if pool then
                    pool = poolForRace(pool, teamRaceKey) or pool   -- keep the squad coherent
                    local e = pool[rand(1, #pool)]
                    if e then
                        created = spawnCreature(anchors[rand(1, #anchors)], e, targetLevel, true, base)
                        if created then spent = spent + e.cost end
                    end
                end
            end
            if created then spawned = spawned + 1 end
        end
        if spent == 0 then spent = spawned * teamCost end   -- log bookkeeping only
    else
    while spawned < MAX_SPAWNS - 1 and budget - spent > 0 do
        local e = pickFrom(etype, budget - spent, base)
        if not e then
            e = pickFrom(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], budget - spent, base)
        end
        if not e then
            log("pack: nothing fits budget", budget - spent, "at level", base)
            break
        end
        local created = spawnCreature(anchors[rand(1, #anchors)], e, targetLevel, etype == "Humanoid", base)
        if created then
            spawned, spent = spawned + 1, spent + e.cost
        else
            fails = fails + 1   -- over-level despawn or spawn failure: re-pick
            if fails >= 3 then log("pack: giving up after 3 failed spawns"); break end
        end
    end
    end   -- if teamMode / else legacy pack

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
                local created = spawnCreature(anchors[rand(1, #anchors)], leader, lvl, ltype == "Humanoid", base)
                if created then
                    spawned = spawned + 1
                    pcall(FlavorLeader, created, host)   -- villain name + popup announcement
                end
            else
                log("leader: no", ltype, "entries in DB")
            end
        end
    end
    log("wave done:", spawned, "spawned, pack", spent, "/", budget, "spent (leader outside budget)")
end

-- listeners --------------------------------------------------------------------
local ok, err = pcall(function ()
    -- save-load quiet window: loading a save into an ONGOING fight makes the game
    -- re-fire CombatStarted (live log 2026-11-01: SessionLoaded +04 s, CombatStarted
    -- +16 s -> a second wave spawned around the restored fight). Suppress rolls for
    -- LOAD_QUIET_MS after every session load; a fresh fight inside that window is
    -- rare and only costs one roll.
    Ext.Events.SessionLoaded:Subscribe(function ()
        local now = MonotonicMs()
        if now then
            loadQuietUntil = now + LOAD_QUIET_MS
            log("SessionLoaded: reinforcement rolls quiet for", LOAD_QUIET_MS / 1000, "s (save-load restore guard)")
        else
            loadQuietUntil = 0   -- clock unavailable: no window, behave like before
        end
    end)

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

        -- in-game toggle (Toggle.lua shout): no rolls, stack untouched
        if not CHAOS_STATE.reinforce then
            log("CombatStarted", combatId, "skipped (reinforcements toggled OFF)")
            return
        end

        -- save-load quiet window (see SessionLoaded subscription above): the game
        -- re-fires CombatStarted when it restores an in-progress fight on load.
        -- Don't roll AND don't touch the miss stack - this isn't a real encounter.
        local nowMs = MonotonicMs()
        if loadQuietUntil > 0 and nowMs and nowMs < loadQuietUntil then
            log("CombatStarted", combatId, "skipped: save-load quiet window (restored combat?)")
            return
        end

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
if ok then log("Chaos.lua loaded; DB types:", CHAOS_DB and "ok" or "MISSING") else log("registration threw:", err) end

-- console: !chaos force wave, !chaos_status, !chaos_wolf
Ext.RegisterConsoleCommand("chaos", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        local players = factGuids("DB_Players", 1)
        reinforce(host, discover(nil, players))
    end
end)
Ext.RegisterConsoleCommand("chaos_status", function ()
    local n = 0
    for _ in pairs(seen) do n = n + 1 end
    log("status: misses", misses, "TEST_MODE", tostring(TEST_MODE),
        "LEADER_TEST", tostring(LEADER_TEST), "combats seen", n,
        "| toggles: wilds", CHAOS_STATE.wilds and "ON" or "OFF",
        "reinforce", CHAOS_STATE.reinforce and "ON" or "OFF")
    if WILD_STATUS then log(WILD_STATUS()) end   -- wild pipeline snapshot (Wild.lua)
end)
Ext.RegisterConsoleCommand("chaos_wolf", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        spawnCreature(host, { id = "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11", hp = 11, cost = 1 }, 1)
    end
end)
-- !chaos_root: are our CHAOST_* root templates registered in the live game?
-- (2026-11-01: every CreateAtObject for CHAOST_* failed - root templates only load
-- as BINARY .lsf from paks; the lsx-only pak registered nothing.)
Ext.RegisterConsoleCommand("chaos_root", function ()
    local ok, all = pcall(Ext.Template.GetAllRootTemplates)
    if not ok or type(all) ~= "table" then
        log("chaos_root: GetAllRootTemplates failed:", tostring(all))
        return
    end
    local total, found = 0, 0
    for k in pairs(all) do
        total = total + 1
        if tostring(k):find("CHAOST") then found = found + 1 end
    end
    log("chaos_root:", found, "CHAOST templates among", total, "root templates",
        found > 0 and "- REGISTERED" or "- NOT LOADED (check pak .lsf!)")
end)
