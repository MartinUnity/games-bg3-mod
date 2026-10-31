-- Chaos toggle shouts (server side). Ext.Require'd AFTER Common.lua (log/factGuids).
--
-- Owner wishlist #1-3: an in-game button to enable/disable the chaos features without
-- restarting - e.g. while talking to the dev with the log scrolling ("I can see new
-- random groups forming while I type"). Implementation: two free self-shouts
-- (CHAOS_Spells.txt) granted to every party member; casting flips the matching
-- CHAOS_STATE flag, persists it via Ext.IO.SaveFile (survives restarts) and answers
-- with floating DebugText over the caster (the proven no-sound tell channel).
-- Pattern cribbed from the working "Teleport_To_You" mod pak: SpellData Shout with
-- AIFlags CanNotUse + TargetConditions Self() and NO SpellProperties is castable.
-- Display names come from Localization/English/ChaosReinforcements.loca (built from
-- the .xml via tools/divine.sh -a convert-loca).

TOGGLE_SPELL_WILDS = "Shout_CHAOS_Wilds"
TOGGLE_SPELL_REINFORCE = "Shout_CHAOS_Reinforce"
TOGGLE_SETTINGS_FILE = "ChaosReinforcements.settings"

-- the state the engines read (Chaos.lua: reinforcements, Wild.lua: wild groups).
-- Defaults ON; overwritten by the persisted setting at SessionLoaded.
CHAOS_STATE = { wilds = true, reinforce = true }

-- Per-state description handles (Localization/English/ChaosReinforcements.loca):
-- the spell TOOLTIP carries the current state ("Currently ENABLED/DISABLED...") -
-- owner request 2026-10-31 after the cast gave no visible feedback.
local DESC_ON = {
    wilds = "h7b2e9d4ag1c58g4f6ega3d2g8e1f0b9c4a57;1",
    reinforce = "h4c8b1e6fg2d93g4a7eg9f5cg6a1b7d3e9c24;1",
}
local DESC_OFF = {
    wilds = "h9d4f2a8bg3e71g4c5agb8f6g2a9d0e5c1b83;1",
    reinforce = "h6f3a7c5dg8e42g4b19ga2d7g4f8c1e6b9a35;1",
}

-- reflect state into the spell tooltip; Sync() is required for post-load edits
-- (docs/vendor/bg3se-Lua-API.md "Writing stat attributes")
local function describeSpell(key)
    local spell = key == "wilds" and TOGGLE_SPELL_WILDS or TOGGLE_SPELL_REINFORCE
    local ok, err = pcall(function ()
        local stat = Ext.Stats.Get(spell)
        stat.Description = CHAOS_STATE[key] and DESC_ON[key] or DESC_OFF[key]
        stat:Sync()
    end)
    if not ok then log("toggle: description swap failed for", spell, "-", tostring(err)) end
end

local function persist()
    local ok, err = pcall(Ext.IO.SaveFile, TOGGLE_SETTINGS_FILE,
        (CHAOS_STATE.wilds and 1 or 0) .. " " .. (CHAOS_STATE.reinforce and 1 or 0))
    if not ok then log("toggle: SaveFile threw:", tostring(err)) end
end

local function restore()
    local ok, text = pcall(Ext.IO.LoadFile, TOGGLE_SETTINGS_FILE)
    if not ok then
        log("toggle: LoadFile threw:", tostring(text))
        return
    end
    if type(text) == "string" then
        local w, r = text:match("^(%d+)%s+(%d+)")
        if w then CHAOS_STATE.wilds = w == "1" end
        if r then CHAOS_STATE.reinforce = r == "1" end
    end
    describeSpell("wilds")     -- tooltip matches persisted state from the start
    describeSpell("reinforce")
    log("toggle: restored state wilds =", CHAOS_STATE.wilds and "ON" or "OFF",
        "reinforce =", CHAOS_STATE.reinforce and "ON" or "OFF")
end

local function flip(key, caster)
    CHAOS_STATE[key] = not CHAOS_STATE[key]
    persist()
    describeSpell(key)
    local what = key == "wilds" and "Wild groups" or "Reinforcements"
    local msg = what .. ": " .. (CHAOS_STATE[key] and "ON" or "OFF")
    if caster and caster ~= "" then
        local okD, resD = pcall(Osi.DebugText, caster, msg)
        log("toggle:", msg, "- tell(DebugText):", okD and "shown" or ("threw: " .. tostring(resD)))
    else
        log("toggle:", msg, "(console)")
    end
end

local granted = {}   -- per-character, so late joiners don't re-toast every heartbeat

local function grant(char)
    if not char or char == "" or granted[char] then return end
    local ok1 = pcall(Osi.AddSpell, char, TOGGLE_SPELL_WILDS, 1, 0)
    local ok2 = pcall(Osi.AddSpell, char, TOGGLE_SPELL_REINFORCE, 1, 0)
    if not (ok1 and ok2) then return end   -- stay unmarked so grantAll can retry later
    granted[char] = true
    log("toggle: shouts granted to", char)
end

-- Grant the shouts to everyone in the player DB + the host. MUST NOT run inside the
-- SessionLoaded handler: Osiris DB reads are restricted there (in-game 2026-10-31:
-- "DB_Players:Get threw: ... restricted context", and the follow-up GetHostCharacter
-- kill aborted the whole callback, so nothing was granted). Call this from a timer.
local function grantAll(attempt)
    local ok, err = pcall(function ()
        local players = factGuids("DB_Players", 1)
        local host = Osi.GetHostCharacter()
        if host and host ~= "" and not granted[host] then players[#players + 1] = host end
        for _, p in ipairs(players) do grant(p) end
        -- DB still unreadable (early session)? try again in 2s, give up after ~20s
        if #players == 0 and (attempt or 1) < 10 then
            pcall(Ext.Timer.WaitFor, 2000, function () grantAll((attempt or 1) + 1) end)
        end
    end)
    if not ok then log("toggle: grantAll failed:", tostring(err)) end
end

-- listeners --------------------------------------------------------------------
pcall(function ()
    -- CastedSpell((GUIDSTRING)_Caster, (STRING)_Spell, (STRING)_SpellType,
    --             (STRING)_SpellElement, (INTEGER)_StoryActionID) - story_header.div:1224
    Ext.Osiris.RegisterListener("CastedSpell", 5, "after", function (caster, spell, a, b, c)
        spell = tostring(spell)
        if spell == TOGGLE_SPELL_WILDS then
            flip("wilds", caster)
        elseif spell == TOGGLE_SPELL_REINFORCE then
            flip("reinforce", caster)
        end
    end)

    -- NPC-keeper mod rotates the roster: grant the shouts to late joiners too
    Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function (char)
        grant(char)
    end)

    -- a save can load STRAIGHT INTO combat (owner's test save does), where AddSpell
    -- may be refused; retry whenever a fight anywhere ends (granted-table no-ops it)
    Ext.Osiris.RegisterListener("CombatEnded", 1, "after", function (combatGuid)
        grantAll(nil)
    end)

    Ext.Events.SessionLoaded:Subscribe(function ()
        restore()
        log("Toggle.lua loaded (shouts:", TOGGLE_SPELL_WILDS .. ",", TOGGLE_SPELL_REINFORCE .. ")")
        -- deferred: DB reads are restricted until the story is actually running
        pcall(Ext.Timer.WaitFor, 2000, function () grantAll(1) end)
    end)
end)

-- console fallback (works without the UI): !chaos_toggle wilds | reinforce
Ext.RegisterConsoleCommand("chaos_toggle", function (cmd, arg)
    if arg == "wilds" then
        flip("wilds", nil)
    elseif arg == "reinforce" then
        flip("reinforce", nil)
    else
        log("usage: !chaos_toggle wilds|reinforce")
    end
end)
