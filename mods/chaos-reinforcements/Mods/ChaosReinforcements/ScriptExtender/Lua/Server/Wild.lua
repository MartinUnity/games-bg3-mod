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
local WILD_HEARTBEAT_MS = 90000      -- spawn roll interval while exploring (owner: 1-2 min)
local WILD_CHANCE = 25               -- % per heartbeat
local WILD_TEST = true               -- 100% per heartbeat while testing
local WILD_BACKOFF_MIN, WILD_BACKOFF_MAX = 8, 10   -- minutes: no new groups after an encounter
local WILD_EXPIRE_MIN, WILD_EXPIRE_MAX = 20, 30   -- minutes: group lifespan ("wanders on")
local WILD_WATCHED_M = 15             -- closer than this, a group's expiry clock holds
local WILD_FORCE_TIER = 3            -- TESTING: force the NEXT group's tier (nil = off)
local WILD_EVIL_FACTION = "Evil NPC_64321d50-d516-b1b2-cfac-2eb773de1ff6"
local WILD_EVIL_CHANCE = 50         -- % of groups that spawn as (red) Evil NPC; the rest
-- keep their template-default faction (observed: generic "Neutral NPC" = harmless
-- yellow "resting mercenaries" the player can run through - owner likes the mix).
-- Evil NPC is a CHILD of our proven Evil 4be9261a pair (vanilla Factions.lsx), so
-- red groups are crime/approval-free to attack and no template can inherit a story
-- settlement faction when the override applies. Evil groups may attack on sight.
local WILD_COUNTDOWN_EVERY = 60       -- monitor ticks between "time to despawn" logs (60 x 2s = 2min)

local nextGroupId = 0
local WILD_MAX_GROUPS = 3            -- concurrent wild groups
local WILD_SPAWN_MIN, WILD_SPAWN_MAX = 50, 75   -- meters from the player (owner: keep
-- groups far enough out that a new pack can't lock onto an existing one and chain
-- the player into their fight - observed in-game when an evil pack spawned near a
-- neutral traveler group and the two went to war next to the player)
local WILD_GROUP_GAP = 25            -- min meters between two wild group centers
local WILD_SPOT_SLACK = 5        -- FindValidPosition correction allowance around the target
local WILD_SPOT_TRIES = 6       -- angle attempts before giving up on a spot
local WILD_CLUSTER = 4               -- max meters between group members
local WILD_AGGRO_RANGE = 12          -- meters: player this close -> the group attacks
local WILD_MONITOR_MS = 2000        -- proximity check interval

local currentLevel = ""
local groups = {}   -- { { members = { guid, ... }, type = "..." } }
local backoffMs = 0 -- remaining encounter cooldown; ticked down by the monitor

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

-- pick a valid, out-of-sight group spot: random angle/radius, then FindValidPosition
-- corrects the raw point to the nearest walkable ground within WILD_SPOT_SLACK; if the
-- correction is bigger than that (target was inside a wall / off the map - common in
-- cramped TUT interiors), try another angle.
local function findGroupSpot(px, py, pz, host)
    for _ = 1, WILD_SPOT_TRIES do
        local angle = math.random() * 2 * math.pi
        local radius = rand(WILD_SPAWN_MIN, WILD_SPAWN_MAX)
        local tx, tz = px + math.cos(angle) * radius, pz + math.sin(angle) * radius
        local ok, vx, vy, vz = pcall(Osi.FindValidPosition, tx, py, tz, WILD_SPOT_SLACK, host, 1)
        if ok and type(vx) == "number" then
            local drift = math.sqrt((vx - tx) ^ 2 + (vz - tz) ^ 2)
            if drift <= WILD_SPOT_SLACK then
                -- keep new groups away from existing ones (no pack-on-pack chain aggro)
                local clash = false
                for _, g in ipairs(groups) do
                    if g.cx and math.sqrt((vx - g.cx) ^ 2 + (vz - g.cz) ^ 2) < WILD_GROUP_GAP then
                        clash = true break
                    end
                end
                if not clash then return vx, vy, vz, radius end
            end
        end
    end
    return nil
end

-- spawn one mob at a position; returns the created guid (or nil).
-- Raw CreateAt refuses even FindValidPosition-validated spots in cramped interiors
-- (in-game v3.15: every member spawn failed on walkable ground), so instead we use
-- the PROVEN anchor route (CreateAtObject: engine solves placement at the host) and
-- then AppearAtPosition to move the mob out to the target spot - with
-- PreventTeleportOnFailure=0 the engine falls back to the nearest valid position on
-- its own if the exact spot is bad. A delayed verify pass logs the final position so
-- playtests can confirm the mob actually left the host's feet.
local function spawnWildMob(entry, host, x, y, z, base, doEquip, faction)
    local ok, created = pcall(function ()
        local mob = Osi.CreateAtObject(entry.id, host, 1, 0, "", 1)
        if not mob or mob == "" then
            log("wild: CreateAtObject failed for", entry.id)
            return nil
        end
        local okA = pcall(Osi.AppearAtPosition, mob, x, y, z, 0, "", "", 0)
        if not okA then
            log("wild: AppearAtPosition errored for", mob, "- it stays near the host!")
        end
        if faction then
            -- NOTE: GetFaction right after SetFaction returns the STALE template
            -- default (verified in-game: spawn lines showed old factions while the
            -- combat discovery later showed Evil NPC) - verified in the 500ms check
            pcall(Osi.SetFaction, mob, faction)
        end
        pcall(Osi.SetLevel, mob, targetLevelFor(base))
        if doEquip then EquipMob(mob, base, entry) end
        -- NOTE: no SetFaction / no SetHostileAndEnterCombat here - the group stays put
        -- and neutral until the player walks into WILD_AGGRO_RANGE (monitor below)
        -- verify (deferred: appear + faction change resolve next frame)
        pcall(Ext.Timer.WaitFor, 500, function ()
            local okP, mx, my, mz = pcall(Osi.GetPosition, mob)
            if okP and type(mx) == "number" then
                local drift = math.sqrt((mx - x) ^ 2 + (mz - z) ^ 2)
                local fac = "-"
                if faction then
                    local okF, f = pcall(Osi.GetFaction, mob)
                    if okF then fac = tostring(f) end
                end
                log("wild: member placed, drift", string.format("%.1fm", drift), fac)
            end
        end)
        return mob
    end)
    return ok and created or nil
end

local function aggroGroup(group, player)
    for _, guid in ipairs(group.members) do
        pcall(Osi.SetFaction, guid, EVIL)
        pcall(Osi.SetHostileAndEnterCombat, EVIL, HERO, guid, player)
    end
    backoffMs = rand(WILD_BACKOFF_MIN, WILD_BACKOFF_MAX) * 60000
    log("wild: group", group.id, "aggroed by", player, "(", #group.members, "mobs ); backoff",
        math.floor(backoffMs / 60000) .. "min")
end

local function spawnWildGroup(host, base)
    local etype = wildType(base)
    if not etype then log("wild: no viable pool at level", base); return end

    -- tier roll (owner spec)
    local roll
    if WILD_FORCE_TIER then
        roll = 99   -- consumes the one-shot test override
        log("wild: forced tier", WILD_FORCE_TIER, "(test knob consumed)")
        WILD_FORCE_TIER = nil
    else
        roll = rand(1, 100)
    end
    local tier = roll <= 80 and 1 or (roll <= 98 and 2 or 3)

    -- per-group faction roll: red Evil NPC pack or harmless neutral "travelers"
    local groupFaction = (rand(1, 100) <= WILD_EVIL_CHANCE) and WILD_EVIL_FACTION or nil
    local count = rand(2, 6)
    local leaderSlots = {}
    if tier == 2 then count = count + rand(1, 4); leaderSlots = { 2 } end
    if tier == 3 then count = count + rand(2, 8); leaderSlots = { 2, 3 }; boss = true end
    count = math.min(count, 12)
    local slotMap = {}
    for _, s in ipairs(leaderSlots) do slotMap[s] = true end

    -- spawn position: valid ground in an out-of-sight ring around the player
    local okP, px, py, pz = pcall(Osi.GetPosition, host)
    if not okP or type(px) ~= "number" then
        log("wild: GetPosition failed, skipping")
        return
    end
    local x, y, z, radius = findGroupSpot(px, py, pz, host)
    if not x then
        log("wild: no valid spot found within", WILD_SPAWN_MIN .. "-" .. WILD_SPAWN_MAX ..
            "m (cramped interiors?), skipping this heartbeat")
        return
    end

    nextGroupId = nextGroupId + 1
    local group = { id = nextGroupId, members = {}, type = etype,
                    faction = groupFaction, cx = x, cy = y, cz = z,
                    ttlMs = rand(WILD_EXPIRE_MIN, WILD_EXPIRE_MAX) * 60000 }
    local spawnedHumanoid = (etype == "Humanoid")
    for i = 1, count do
        local pool = gatedPool(etype, base) or gatedPool(DEFAULT_TYPES[rand(1, #DEFAULT_TYPES)], base)
        if not pool then break end
        local entry = pool[rand(1, #pool)]
        -- per-member jitter around the validated group center (WILD_CLUSTER/2 each way)
        local jitter = rand(-WILD_CLUSTER, WILD_CLUSTER) * 0.5
        local jitterZ = rand(-WILD_CLUSTER, WILD_CLUSTER) * 0.5
        local guid = spawnWildMob(entry, host, x + jitter, y, z + jitterZ, base, spawnedHumanoid, groupFaction)
        if guid then
            group.members[#group.members + 1] = guid
            if boss and i == 1 then
                log("wild: boss spawned:", FlavorLeaderCommon(guid, true))
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
    log("wild: spawned group", nextGroupId, "tier", tier, "(roll", roll .. ")", #group.members, "mobs,",
        groupFaction and "(evil pack)" or "(neutral travelers)",
        "type", etype, "at ~", radius .. "m")
end

-- heartbeat: try to spawn a wild group while exploring
local function heartbeat()
    pcall(Ext.Timer.WaitFor, WILD_HEARTBEAT_MS, heartbeat)
    if not currentLevel:find(WILD_LEVEL_PATTERN) then return end
    local host = Osi.GetHostCharacter()
    if not host or host == "" then return end
    if #groups >= WILD_MAX_GROUPS then return end
    if backoffMs > 0 then return end   -- encounter cooldown (owner: no back-to-back combat)
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
    if backoffMs > 0 then backoffMs = backoffMs - WILD_MONITOR_MS end
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
        if nearDist <= WILD_AGGRO_RANGE * WILD_AGGRO_RANGE and group.faction then
            aggroGroup(group, nearest)   -- neutral travelers never auto-aggro
        elseif nearDist <= WILD_WATCHED_M * WILD_WATCHED_M then
            remaining[#remaining + 1] = group   -- watched: expiry clock holds
        else
            -- expire quietly out of sight ("they wandered on"); never mid-combat
            group.ttlMs = group.ttlMs - WILD_MONITOR_MS
            group.ticks = (group.ticks or 0) + 1
            if group.ticks % WILD_COUNTDOWN_EVERY == 0 then
                log("wild: group", group.id, "despawns in ~",
                    math.max(1, math.ceil(group.ttlMs / 60000)), "min")
            end
            local inCombat = false
            for _, guid in ipairs(group.members) do
                local okI, ic = pcall(Osi.IsInCombat, guid)
                if okI and ic == 1 then inCombat = true break end
            end
            if group.ttlMs <= 0 and not inCombat then
                for _, guid in ipairs(group.members) do
                    pcall(Osi.RequestDeleteTemporary, guid)
                end
                log("wild: group", group.id, "expired (", #group.members, "mobs wandered on )")
            else
                remaining[#remaining + 1] = group
            end
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
