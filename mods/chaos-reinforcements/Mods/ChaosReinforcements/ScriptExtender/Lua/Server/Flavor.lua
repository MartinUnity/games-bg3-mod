-- "Chaos Reinforcements" flavor module (server side). Ext.Require'd AFTER Common.lua.
-- Names, buffs and tells for LEADER spawns (pack mobs keep their template names by design).
--
-- v3.9 (owner playtest feedback): the OpenMessageBox announcement broke immersion and halted
-- combat - replaced by a vanilla VOICE BARK on the player (subtitle lingers over the head a
-- few seconds and disappears on its own; VoiceBarkStarted/Failed events are logged).
-- Rename fix: Entity:Replicate() expects the COMPONENT OBJECT, not its name (v3.8 threw
-- "Param 3: expected a light C++ object, got string"). Leader stat buffs (+vit / +ability
-- tiers) come from the custom stats file shipped in the pak
-- (Public/ChaosReinforcements/Stats/Generated/Data/CHAOS_Boosts.txt) and are applied as
-- boost statuses at spawn.

local LEADER_RENAME = true      -- overwrite the leader's overhead display name
local LEADER_BUFFS = true       -- +vit% / +ability boost statuses (CHAOS_VIT_x / CHAOS_STAT_x)
local LEADER_BARK = true        -- player speaks a vanilla combat bark when a leader spawns

-- procedural villain names: FIRST x EPITHET = ~1600 combinations, no external DB needed
local FIRST = {
    "Vorhax", "Grimjaw", "Zarvok", "Skorrv", "Malreth", "Uzzak", "Dreadnought", "Karrgh",
    "Thulsa", "Bexley", "Morgrath", "Vex", "Snikrot", "Halazar", "Uroth", "Krevv",
    "Ashmaw", "Gorthok", "Vilrik", "Zhessa", "Rokka", "Belzior", "Draykk", "Nurv",
    "Skaldis", "Ygrul", "Morthos", "Pesthry", "Czolgar", "Rhazien", "Umbrath", "Kravok",
    "Slizzik", "Thanvur", "Ozrik", "Gnash", "Vhalder", "Skarn", "Moloth", "Zirgath",
}
local EPITHET = {
    "the Cruel", "the Twice-Dead", "the Unforgiving", "of the Howling Fen", "the Flayer",
    "Butcher of Blighted Village", "the Skull-Taker", "of the Black Dawn", "the Wretched",
    "the Iron-Fanged", "of the Rotting Choir", "the Nine-Fingered", "the Sorrow-Bringer",
    "of the Blood Moon", "the Gravewalker", "the Unmourned", "of the Sunken Court",
    "the Horned Shadow", "the Betrayer", "of the Screaming Wood", "the Flesh-Render",
    "the Hollow", "of the Pale Legion", "the Worm-King", "the Ashen Blade",
    "of the Whore of Bones", "the Devil-Debt Collector", "the Mad Prophet",
    "of the Underdeep", "the Gut-Stripper", "the Cursed", "of the Iron Slave-Pits",
    "the Dream-Eater", "the Red Handed", "of the Cold Waste", "the Soul-Broker",
    "the Banished", "of the Whispering Depths", "the Corpse-Marshal", "the Unburied",
}

-- vanilla voice barks that fit "fight escalates" (Name_GUID resource ids from vanilla goals;
-- exact lines are in loca - pick by theme). The bark plays as a short subtitle over the
-- speaker's head and disappears on its own.
local BARKS = {
    "HAV_VB_ShadowSiege_PlayerEntersCombat_9d551bbc-2a39-aecf-cc1f-25cb27f2fe8f",
}

-- leader buff tiers (CHAOS_Boosts.txt in the pak; rolled per leader):
-- vitality +20/35/50% (owner spec: +20-50%), abilities +1/+2/+3 (owner spec: round(+10-20%,1))
local VIT_TIERS = { "CHAOS_VIT_1", "CHAOS_VIT_2", "CHAOS_VIT_3" }
local STAT_TIERS = { "CHAOS_STAT_1", "CHAOS_STAT_2", "CHAOS_STAT_3" }

local function rand(lo, hi) return math.random(lo, hi) end
local function pick(t) return t[rand(1, #t)] end

local function villainName()
    return pick(FIRST) .. " " .. pick(EPITHET)
end

local function tryRename(created, name, attempt)
    local ok, err = pcall(function ()
        local entity = Ext.Entity.Get(created)
        local dn = entity.DisplayName
        if dn then
            dn.Name = name
            entity:Replicate(dn)   -- component OBJECT, not the name string
            log("leader renamed to:", name)
        else
            error("no DisplayName component (attempt " .. attempt .. ")")
        end
    end)
    if not ok then
        log("rename failed:", err)
        if attempt == 1 then
            -- entity may not be fully created yet; retry once after a delay
            pcall(Ext.Timer.WaitFor, 1000, function () tryRename(created, name, 2) end)
        end
    end
end

local function applyLeaderBuffs(created)
    local vit = pick(VIT_TIERS)
    local stats = pick(STAT_TIERS)
    local okV, eV = pcall(Osi.ApplyStatus, created, vit, -1, 1, created)
    local okS, eS = pcall(Osi.ApplyStatus, created, stats, -1, 1, created)
    log("leader buffs:", vit, okV and "ok" or tostring(eV), "|", stats, okS and "ok" or tostring(eS))
end

local function barkTell(player)
    local okB, eB = pcall(Osi.StartVoiceBark, pick(BARKS), player)
    log("leader bark:", okB and "requested" or ("threw: " .. tostring(eB)))
end

-- public: call right after a leader spawned
function FlavorLeader(created, host)
    local name = villainName()
    if LEADER_RENAME and created then
        tryRename(created, name, 1)
    end
    if LEADER_BUFFS and created then
        applyLeaderBuffs(created)
    end
    if LEADER_BARK and host then
        barkTell(host)
    end
end

-- bark outcome diagnostics (logged, not announced)
pcall(function ()
    Ext.Osiris.RegisterListener("VoiceBarkStarted", 2, "after", function (bark, instanceId)
        log("bark started:", bark)
    end)
    Ext.Osiris.RegisterListener("VoiceBarkFailed", 1, "after", function (bark)
        log("bark FAILED:", bark)
    end)
end)

log("Flavor.lua loaded")
