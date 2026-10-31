-- "Chaos Reinforcements" wild encounters module (server side). Ext.Require'd AFTER
-- Common.lua, CreatureDB.lua, Equip.lua, Flavor.lua.
--
-- Owner spec (2026-10-31): random mob groups standing in the world, NOT ambushing:
-- spawned out of sight of the player, they stay put and stay neutral until the player
-- walks close - vigilant players can avoid them entirely. No wandering (backlog).
-- Group sizes: <=80%: 2-6 mobs, no leader; <=98%: +1-4 mobs + 1 leader;
-- >98%: +2-8 mobs + 2 leaders + 1 BOSS (placeholder: a leader with "BOSS " name prefix).
-- While testing this runs ONLY in TUT_* levels (level gate via the LevelLoaded event);
-- safe havens/towns are deferred until we know it works in TUT.

-- Tunables ------------------------------------------------------------------
local WILD_LEVEL_PATTERN = "^TUT_"    -- level-name gate (testing: tutorial only)
local WILD_HEARTBEAT_MS = 45000      -- spawn roll interval while exploring
local WILD_CHANCE = 25               -- % per heartbeat
local WILD_TEST = true               -- 100% per heartbeat while testing
local WILD_MAX_GROUPS = 3            -- concurrent wild groups
local WILD_SPAWN_MIN, WILD_SPAWN_MAX = 18, 28   -- meters from the player
local WILD_CLUSTER = 4               -- max meters between group members
local WILD_AGGRO_RANGE = 12          -- meters: player this close -> the group attacks
local WILD_MONITOR_MS = 2000        -- proximity check interval

local currentLevel = ""
local groups = {}   -- { { members = { guid, ... }, type = "..." } }

local function rand(lo, hi) return math.random(lo, hi) end

-- pick a mob type that has entries for this level (no fight to classify - demographic
-- targeting by region is deferred per owner; for now a random pool type)
local function wildType(base)
    local opts = {}
    for _, t in ipairs(DEFAULT_TYPES) do
        if gatedPool(t, base) then opts[#opts + 1] = t end
    end
    if #opts == 0 then return nil end
    return opts[rand(1, #opts)]
end

-- spawn one mob at a position; returns the created guid (or nil)
local function spawnWildMob(entry, x, y, z, base, doEquip)
    local ok, created = pcall(function ()
        local jitter = WILD_CLUSTER
        local mx = x + rand(-jitter, jitter) * 0.5
        local mz = z + rand(-jitter, jitter) * 0.5
        local mob = Osi.CreateAt(entry.id, mx, y, mz, 1, 1, "")
        if not mob or mob == "" then return nil end
        pcall(Osi.SetLevel, mob, targetLevelFor(base))
        if doEquip then EquipMob(mob, base, entry) end
        -- NOTE: no SetFaction / no SetHostileAndEnterCombat here - the group stays put
        -- and neutral until the player walks into WILD_AGGRO_RANGE (monitor below)
        return mob
    end)
    return ok and created or nil
end

local function aggroGroup(group, player)
    for _, guid in ipairs(group.members) do
        pcall(Osi.SetFaction, guid, EVIL)
        pcall(Osi.SetHostileAndEnterCombat, EVIL, HERO, guid, player)
    end
    log("wild: group aggroed by", player, "(", #group.members, "mobs )")
end

local function spawnWildGroup(host, base)
    local etype = wildType(base)
    if not etype then log("wild: no viable pool at level", base); return end

    -- tier roll (owner spec)
    local roll = rand(1, 100)
    local tier = roll <= 80 and 1 or (roll <= 98 and 2 or 3)
    local count = rand(2, 6)
    local leaderSlots = {}
    if tier == 2 then count = count + rand(1, 4); leaderSlots = { 2 } end
    if tier == 3 then count = count + rand(2, 8); leaderSlots = { 2, 3 }; boss = true end
    count = math.min(count, 12)
    local slotMap = {}
    for _, s in ipairs(leaderSlots) do slotMap[s] = true end

    -- spawn position: out of sight ring around the player
    local okP, px, py, pz = pcall(Osi.GetPosition, host)
    if not okP or type(px) ~= "number" then
        log("wild: GetPosition failed, skipping")
        return
    end
    local angle = math.random() * 2 * math.pi
    local radius = rand(WILD_SPAWN_MIN, WILD_SPAWN_MAX)
    local x, z = px + math.cos(angle) * radius, pz + math.sin(angle) * radius

    local group = { members = {}, type = etype }
    local spawnedHumanoid = (etype == "Humanoid")
    for i = 1, count do
        local pool = gatedPool(etype, base) or gatedPool(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], base)
        if not pool then break end
        local entry = pool[rand(1, #pool)]
        local guid = spawnWildMob(entry, x, py, z, base, spawnedHumanoid)
        if guid then
            group.members[#group.members + 1] = guid
            if boss and i == 1 then
                log("wild: BOSS", FlavorLeaderCommon(guid, true))
            elseif slotMap[i] then
                log("wild: leader", FlavorLeaderCommon(guid, false))
            end
        end
    end

    if #group.members == 0 then
        log("wild: group spawn FAILED (no members)")
        return
    end
    groups[#groups + 1] = group
    log("wild: spawned group tier", tier, "(roll", roll .. ")", #group.members, "mobs,",
        "type", etype, "at ~", radius .. "m")
end

-- heartbeat: try to spawn a wild group while exploring
local function heartbeat()
    pcall(Ext.Timer.WaitFor, WILD_HEARTBEAT_MS, heartbeat)
    if not currentLevel:find(WILD_LEVEL_PATTERN) then return end
    local host = Osi.GetHostCharacter()
    if not host or host == "" then return end
    if #groups >= WILD_MAX_GROUPS then return end
    local okC, inCombat = pcall(Osi.IsInCombat, host)
    if okC and inCombat == 1 then return end
    local chance = WILD_TEST and 100 or WILD_CHANCE
    if rand(1, 100) > chance then return end
    local okL, hostLevel = pcall(Osi.GetLevel, host)
    local base = (okL and tonumber(hostLevel)) or 3
    spawnWildGroup(host, base)
end

-- proximity monitor: the group turns hostile only when the player gets close
local function monitor()
    pcall(Ext.Timer.WaitFor, WILD_MONITOR_MS, monitor)
    if #groups == 0 then return end
    local players = factGuids("DB_Players", 1)
    local host = Osi.GetHostCharacter()
    if host and host ~= "" then players[#players + 1] = host end
    if #players == 0 then return end

    local remaining = {}
    for _, group in ipairs(groups) do
        local nearest, nearDist = nil, math.huge
        for _, guid in ipairs(group.members) do
            local okM, mx, my, mz = pcall(Osi.GetPosition, guid)
            if okM then
                for _, p in ipairs(players) do
                    local okP, px, py, pz = pcall(Osi.GetPosition, p)
                    if okP then
                        local d2 = (mx - px) ^ 2 + (mz - pz) ^ 2
                        if d2 < nearDist then nearest, nearDist = p, d2 end
                    end
                end
            end
        end
        if nearDist <= WILD_AGGRO_RANGE * WILD_AGGRO_RANGE then
            aggroGroup(group, nearest)
        else
            remaining[#remaining + 1] = group
        end
    end
    groups = remaining
end

-- listeners -------------------------------------------------------------------
pcall(function ()
    Ext.Osiris.RegisterListener("LevelLoaded", 1, "after", function (level)
        currentLevel = tostring(level)
        groups = {}   -- old level's wilds are gone after a level swap
        log("wild: level", currentLevel)
    end)
    Ext.Events.SessionLoaded:Subscribe(function ()
        log("Wild.lua loaded (level gate:", WILD_LEVEL_PATTERN .. ")")
        pcall(Ext.Timer.WaitFor, WILD_HEARTBEAT_MS, heartbeat)
        pcall(Ext.Timer.WaitFor, WILD_MONITOR_MS, monitor)
    end)
end)
