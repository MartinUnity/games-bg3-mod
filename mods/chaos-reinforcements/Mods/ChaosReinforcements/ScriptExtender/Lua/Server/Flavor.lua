-- "Chaos Reinforcements" flavor module (server side). Ext.Require'd AFTER Common.lua.
-- Names, buffs and tells for LEADER spawns (pack mobs keep their template names by design).
--
-- v3.13: the display-name-swap tell is REMOVED at owner request (risk of save weirdness);
-- the tell is now Osiris DebugText (story_header.div:648 - the only floating-text call in
-- BG3; the DOS2 CombatLogText family does NOT exist here) over the player AND the leader.
-- ⚠️ CORRECTION (owner, 2026-10-31): DebugText's visible effect is UNVERIFIED - probably
-- NEVER rendered (the one "confirmation" was in a cinematic->combat scene, indistinguishable
-- from nothing; toggle casts show no floating text either). The call logs as "shown" but
-- is likely a release-build no-op - see the tell section below. There is NO Osiris
-- combat-log call in BG3 - a combat-log entry would need SE client-side Lua (Ext.UI), an
-- open experiment. The v3.10 restore-bug repair and the !chaos_rename escape hatch stay as
-- safety nets. Leader rename (SetStoryDisplayName with a raw string) and leader buffs
-- (CHAOS_Boosts.txt statuses) are proven working.

local LEADER_RENAME = true       -- rename the leader to a villain name
local LEADER_BUFFS = true        -- +vit% / +ability boost statuses (CHAOS_VIT_x / CHAOS_STAT_x)
-- (no TELL_* config anymore: every tell channel is dead - Osiris DebugText confirmed a
-- silent no-op in-game 2026-10-31, voice barks fire party-wide, display-name swap removed
-- at owner request. A leader-join combat-log/banner line needs SE client Lua, backlog.)

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

-- overhead tell texts REMOVED 2026-10-31: DebugText is a confirmed silent no-op (the call
-- logs "shown", nothing renders) and barks fire party-wide - no live tell channel exists.

-- leader buff tiers (CHAOS_Boosts.txt in the pak; rolled per leader):
-- vitality +20/35/50% (owner spec: +20-50%), abilities +1/+2/+3 (owner spec: round(+10-20%,1))
local VIT_TIERS = { "CHAOS_VIT_1", "CHAOS_VIT_2", "CHAOS_VIT_3" }
local STAT_TIERS = { "CHAOS_STAT_1", "CHAOS_STAT_2", "CHAOS_STAT_3" }

local dnDumped = false

local function rand(lo, hi) return math.random(lo, hi) end
local function pick(t) return t[rand(1, #t)] end

local function villainName()
    return pick(FIRST) .. " " .. pick(EPITHET)
end

-- rename via the story call, with a raw string as the "localized key"
local function renameViaStory(created, name)
    local ok, err = pcall(Osi.SetStoryDisplayName, created, name)
    log("rename(SetStoryDisplayName):", ok and "called" or ("threw: " .. tostring(err)))
    -- once per session: dump the DisplayName component to learn its real fields
    if ok and not dnDumped then
        dnDumped = true
        pcall(function ()
            local dn = Ext.Entity.Get(created).DisplayName
            log("DisplayName component dump:", Ext.DumpExport(dn))
        end)
    end
    return ok
end

local function applyLeaderBuffs(created)
    local vit = pick(VIT_TIERS)
    local stats = pick(STAT_TIERS)
    local okV, eV = pcall(Osi.ApplyStatus, created, vit, -1, 1, created)
    local okS, eS = pcall(Osi.ApplyStatus, created, stats, -1, 1, created)
    log("leader buffs:", vit, okV and "ok" or tostring(eV), "|", stats, okS and "ok" or tostring(eS))
end

-- "name" tell: temporarily replace the player's overhead display name with the message.
-- v3.11: the restore MUST use the display TEXT (from DisplayName.Name:Get()), never the
-- GetDisplayName resource key (v3.10 "restored" a host to the literal string
-- "ResStr_1233106546" - raw text is exactly what SetStoryDisplayName writes).
local function displayNameText(char)
    local ok, text = pcall(function () return Ext.Entity.Get(char).DisplayName.Name:Get() end)
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
end

-- public: name + buff a leader (no tell). isBoss prefixes "BOSS " (placeholder until real
-- boss mechanics exist - owner decision 2026-10-31). Returns the name used.
function FlavorLeaderCommon(created, isBoss)
    local name = villainName()
    if isBoss then name = "BOSS " .. name end
    if LEADER_RENAME and created then
        renameViaStory(created, name)
    end
    if LEADER_BUFFS and created then
        applyLeaderBuffs(created)
    end
    if created then
        pcall(GiveLeaderGold, created, isBoss)   -- defined in Equip.lua (loaded first)
    end
    return name
end

-- public: call right after a reinforcement leader spawned (name + buffs)
-- NOTE: no player-facing tell channel exists anymore: Osiris DebugText is CONFIRMED a
-- silent no-op in BG3 (logs "shown", renders nothing - in-game 2026-10-31) and voice
-- barks fire for every char (owner rejected). Leader-join visibility is: villain name
-- + buffs + gold in the log file; a combat-log/banner line needs SE client Lua
-- (Ext.UI, backlog). Do not re-enable DebugText - it is confirmed dead.
function FlavorLeader(created, host)
    local name = FlavorLeaderCommon(created, false)
    return name
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

-- repair for saves hit by the v3.10 restore bug (host stuck with literal "ResStr_<id>"
-- as its display name): at session load, known companion GUIDs whose displayed text
-- looks like a resource key get their proper name back.
local REPAIR_NAMES = {
    ["S_Player_Laezel_58a69333-40bf-8358-1d17-fff240d7fb12"] = "Lae'zel",
    -- other origin companions can be added by GUID if ever needed
}

pcall(function ()
    Ext.Events.SessionLoaded:Subscribe(function ()
        for guid, proper in pairs(REPAIR_NAMES) do
            local text = displayNameText(guid)
            if text and text:find("^ResStr_%d") then
                local okR, eR = pcall(Osi.SetStoryDisplayName, guid, proper)
                log("repair:", guid, "->", proper, okR and "ok" or ("threw: " .. tostring(eR)))
            end
        end
    end)
end)

-- manual escape hatch: !chaos_rename <text> renames the host character
Ext.RegisterConsoleCommand("chaos_rename", function (...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    local text = table.concat(parts, " ")
    local host = Osi.GetHostCharacter()
    if host and host ~= "" and text ~= "" then
        local okR, eR = pcall(Osi.SetStoryDisplayName, host, text)
        log("chaos_rename:", host, "->", text, okR and "ok" or ("threw: " .. tostring(eR)))
    else
        log("chaos_rename: need a host and a non-empty name")
    end
end)

log("Flavor.lua loaded (leader flavor: rename + buffs; no tell channel)")
