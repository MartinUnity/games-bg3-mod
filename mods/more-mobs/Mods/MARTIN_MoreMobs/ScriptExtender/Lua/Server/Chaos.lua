-- MARTIN_MoreMobs chaos/reinforcement engine v2 (server-side Lua).
-- Spec (owner, 2026-10-31): stacking chance of reinforcements per encounter (base 20%, +5..25%
-- per non-triggering encounter, resets on trigger; TEST MODE = 100%). Spawn budget driven by
-- player level x random factor (and party size later) so we never dump 8 mobs 3 levels above
-- the party. Reinforcements hostile to the party, joining the live fight.
--
-- v2 adds DISCOVERY: per combat it logs every participant's Osiris GetLevel/GetRace/
-- GetDisplayName + faction, and dumps the raw DB_Is_InCombat/DB_Players fact row shapes once.
-- That data (profile "Script Extender/MARTIN_chaos.log") feeds the next iteration: race-affine
-- pools ("fiend fight => fiends") and real level costs instead of tier proxies.
--
-- Proven pieces kept verbatim from probe v3: CreateAtObject(Name_GUID template, anchor, dx, dy,
-- "", 1) -> SetFaction(EVIL) -> SetHostileAndEnterCombat(EVIL, HERO, created, host) with the
-- E8b faction pair (any other pair is silently inert). math.random only (no randomseed, no
-- Ext.RandomInteger - neither exists in v33).

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
local TEST_MODE = true          -- true => spawn chance forced to 100% while testing
local BASE_CHANCE = 20          -- % base chance of reinforcements
local STACK_MIN, STACK_MAX = 5, 25  -- +% stacking per encounter that didn't trigger
local BUDGET_LO, BUDGET_HI = 2, 4   -- total spawn budget = avgPlayerLevel * rand(LO,HI)
local MAX_SPAWNS = 8            -- hard cap per combat
local OFFSET_MIN, OFFSET_MAX = 1, 3 -- spawn offset tiles around anchor

-- Tier-proxy cost: 1 weak / 2 normal / 4 elite. Replace with real mob levels once the
-- discovery log has told us what GetLevel/GetRace return for encounter mobs.
local POOLS = {
    weak = 1, normal = 2, elite = 4,
}
local POOL_IDS = {
    weak = {
        "Imp_feb1d610-4644-4dd0-8432-6e6a7be130d5",
        "Imp_Weak_836eb759-4663-4aad-b02b-f46513e31e97",
        "Spider_Tiny_3c88c158-eebe-4e8a-bc20-e0c4ae336163",
        "Bat_A_6aac7aa0-9a97-4c6a-82d9-f1e3aad461bf",
        "Goblins_Female_Melee_48eb6d1e-78a7-4396-b597-fa149243521e",
        "Goblins_Male_Melee_2db928f2-f1c5-4b5a-8751-168f9f292249",
        "Goblins_Female_Caster_9e9000e1-c4cf-42cf-8f5c-60e4cda2bca5",
        "Goblins_Male_Caster_01fa8d64-f63e-4bb8-9ee4-cba84dad3781",
        "Goblins_Female_Ranger_f5f1adc6-bc9a-418c-af58-af412f8b9c5d",
        "Goblins_Male_Ranger_bdf828ab-4335-4626-b159-312b67397011",
        "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11",
        "Hyena_A_045f416c-7c67-413d-a06f-2c2fdbb282a8",
        "Harpy_A_821cd768-2778-488d-9ea8-3a8ba8bab6b2",
        "Skeleton_Armored_A_e29c34ab-0863-4775-b8af-964fa90451d2",
        "Mephit_Grease_53af9627-5afb-4985-a584-3fa532b3078e",
    },
    normal = {
        "Wolf_Dire_67f39af3-b9ea-4e95-8237-7aa4f6bd7cef",
        "Worg_A_d011a942-cb4c-4e25-b829-31c460631525",
        "Worg_White_A_5f236ff6-44ea-4eb5-b07f-ff0c44b1152d",
        "Goblins_Female_Melee_Tier2_c9e5bbd8-0857-4161-a9ff-80fd1ba2c8f1",
        "Goblins_Male_Melee_Tier2_eb092260-3e6f-4576-b029-83b22ed56c0f",
        "Goblins_Female_Guard_Caster_9e95c64d-577f-40f0-b169-8f9b7781a91f",
        "Goblins_Male_Guard_Caster_460a6c53-1022-4845-8ec0-b6fddcfeb076",
        "Hobgoblins_Male_d1686869-2610-494a-8b12-93bdd2d18bba",
        "Hobgoblins_Male_Devastator_52540830-11e2-4f7a-9647-f2b84aa3d7d7",
        "Owlbear_6cd57ec0-7f04-452c-8fb9-31cae384b916",
        "Bulette_0ea356fc-7a6f-4c60-8017-86349e2777ab",
        "Panther_Sabre_A_00c5b55e-c9f8-4f2f-a223-c1f21c9f7878",
        "Bear_b2754d31-198e-4ae6-87ec-5399a3669639",
        "Bear_Polar_7d3466c7-af68-48c2-a601-8c5e4d8af9ec",
        "Duergar_Male_Guard_92f0ebda-0023-4a7c-b0ac-64392c382db5",
        "Duergar_Female_Guard_3ba1929e-c220-486d-b2ea-58e991f924fa",
        "Ogres_Female_A_535a319c-d578-4dd4-bfb2-4f7369ba6d67",
        "Ogres_Male_A_cfef7d2e-39f1-41c3-8b76-05d47b73fc16",
        "Hyena_A_Black_d9ae21e7-edd4-4915-ad8d-ac904c4c2567",
        "HookHorror_A_bfe9ad10-c5f7-4a08-a2af-acefb296ffcc",
    },
    elite = {
        "Owlbear_Armoured_f5d6b4e5-e0ea-44cb-b69b-a52d639cc4c9",
        "Githyanki_Male_Gish_a04825f0-869c-44bf-8ac6-a8fb6c0feb0c",
        "Githyanki_Female_Gish_7764910f-cfdd-4684-b1c2-11bd49d0079b",
        "Githyanki_Male_Gish_Strong_73813152-927c-42c3-b3d9-b19ff041dc13",
        "Githyanki_Female_Gish_Strong_66487c2e-972e-40ad-af97-e2f286c8c501",
        "Githyanki_Male_Warrior_Strong_79556c5e-c4bd-4923-831e-4523c9208925",
        "Githyanki_Female_Warrior_Strong_916160bc-4764-4123-8c3e-f31eccbd9ce4",
        "SteelWatcher_Biped_A_27385ea6-d768-47ce-91b8-8d957c0aabd9",
        "SteelWatcher_Biped_B_ec2820db-afd7-4428-90bd-a0838949cc69",
        "SteelWatcher_Quadruped_A_26fa3fe9-608c-4113-99a6-727781351ea4",
        "SteelWatcher_Quadruped_B_9b687adf-7319-411e-bd02-af18859e9c7b",
        "Hag_Green_14dc7910-84b9-47e4-973c-b19f7e437142",
        "Cambion_Male_db4e657f-13d4-45a9-871e-bc55e26f1a2a",
        "MindFlayer_Caster_10e9dc14-b26c-4ec3-a628-8f31e1a031e3",
        "Phase_Spider_Queen_6047fffd-f7d3-4956-8b7a-ef82c08f8867",
        "Goblins_Male_Boss_b0f372f0-f74f-4c00-84e6-34ba09117578",
        "Ogres_Male_A_Guard_e6b6f2dd-cc9c-43fe-8d9a-32a8fa2f5540",
    },
}

local function rand(lo, hi)
    return math.random(lo, hi)
end

-- state ---------------------------------------------------------------------
local misses = 0     -- encounters since last trigger (stacking chance)
local seen = {}     -- combatId guard
local dumpedShapes = false

local function spawnOne(anchor, templateId)
    local ok = pcall(function ()
        local dx, dy = rand(OFFSET_MIN, OFFSET_MAX), rand(OFFSET_MIN, OFFSET_MAX)
        local created = Osi.CreateAtObject(templateId, anchor, dx, dy, "", 1)
        if (not created or created == "") and (dx ~= 1 or dy ~= 1) then
            created = Osi.CreateAtObject(templateId, anchor, 1, 1, "", 1)
        end
        log("spawn", templateId, "at", anchor, "->", created)
        if created and created ~= "" then
            pcall(Osi.SetFaction, created, EVIL)
            local okX, eX = pcall(Osi.SetHostileAndEnterCombat, EVIL, HERO, created, anchor)
            if not okX then log("hostility threw:", eX) end
        end
    end)
    if not ok then log("spawn threw for", templateId) end
    return ok
end

-- Fact row helper: SE rows are tables; field access shape learned from the v2 discovery dump.
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
    if not db then log("no fact", dbName); return {} end
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

-- Discovery: log combat roster intel (levels/races/names/factions) + raw fact shapes once.
local function discover(players, host)
    if not dumpedShapes then
        dumpedShapes = true
        pcall(function ()
            log("DB_Is_InCombat rows dump:", Ext.DumpExport(Osi.DB_Is_InCombat:Get(nil)))
            log("DB_Players rows dump:", Ext.DumpExport(Osi.DB_Players:Get(nil)))
        end)
    end
    local hostFac = select(2, pcall(Osi.GetFaction, host))
    log("host faction:", hostFac)
    local enemyList = {}
    local seenG = {}
    for _, g in ipairs(players) do seenG[g] = true end
    for _, g in ipairs(factGuids("DB_Is_InCombat")) do
        if g and not seenG[g] then
            seenG[g] = true
            local lvl = select(2, pcall(Osi.GetLevel, g))
            local race = select(2, pcall(Osi.GetRace, g, 0))
            local nm = select(2, pcall(Osi.GetDisplayName, g))
            local fac = select(2, pcall(Osi.GetFaction, g))
            local hostile = (fac and fac ~= hostFac and fac ~= "") and true or false
            log("in-combat:", g, "lvl", lvl, "race", race, "name", nm, "faction", fac, hostile and "ENEMY" or "")
            if hostile then enemyList[#enemyList + 1] = { guid = g, level = tonumber(lvl), race = race } end
        end
    end
    return enemyList
end

local function weightedTier()
    local r = rand(1, 100)
    if r <= 50 then return "weak" end
    if r <= 85 then return "normal" end
    return "elite"
end

local function reinforce(host, enemyList)
    -- player level baseline: host level (average over party later if needed)
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    local budget = base * rand(BUDGET_LO, BUDGET_HI)
    -- anchors: prefer spawning next to existing enemies (fallback: host)
    local anchors = { host }
    for _, e in ipairs(enemyList) do anchors[#anchors + 1] = e.guid end

    log("budget:", budget, "(base lvl", base, "x rand", BUDGET_LO .. "-" .. BUDGET_HI, ")", "anchors:", #anchors - 1 + 1)
    local spawned, spent = 0, 0
    while spawned < MAX_SPAWNS do
        local tier = weightedTier()
        local cost = POOLS[tier]
        if budget - spent < cost then
            -- try cheaper tiers before giving up
            if budget - spent >= POOLS.weak then tier = "weak"; cost = POOLS.weak
            else break end
        end
        local ids = POOL_IDS[tier]
        local templateId = ids[rand(1, #ids)]
        local anchor = anchors[rand(1, #anchors)]
        spawnOne(anchor, templateId)
        spawned = spawned + 1
        spent = spent + cost
    end
    log("done:", spawned, "spawned,", spent, "of", budget, "budget spent")
end

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
        log("party size (DB_Players):", #players)

        local enemyList = {}
        local okP, pc = pcall(Osi.CombatGetInvolvedPartyMembersCount, combatId)
        if okP then log("combat party count:", pc) end
        enemyList = discover(players, host)
        log("enemies identified:", #enemyList)
        reinforce(host, enemyList)
    end)
end)
if ok then log("Chaos.lua v2 loaded, CombatStarted listener registered") else log("registration threw:", err) end

-- Dev console: !martin_chaos (force one reinforcement wave at host), !martin_status, !martin_wolf
Ext.RegisterConsoleCommand("martin_chaos", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then
        local players = factGuids("DB_Players")
        reinforce(host, discover(players, host))
    end
end)
Ext.RegisterConsoleCommand("martin_status", function ()
    log("status: misses", misses, "TEST_MODE", tostring(TEST_MODE))
end)
Ext.RegisterConsoleCommand("martin_wolf", function ()
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then spawnOne(host, "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11") end
end)
