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
    log("toggle: restored state wilds =", CHAOS_STATE.wilds and "ON" or "OFF",
        "reinforce =", CHAOS_STATE.reinforce and "ON" or "OFF")
end

local function flip(key, caster)
    CHAOS_STATE[key] = not CHAOS_STATE[key]
    persist()
    local what = key == "wilds" and "Wild groups" or "Reinforcements"
    local msg = what .. ": " .. (CHAOS_STATE[key] and "ON" or "OFF")
    if caster and caster ~= "" then
        pcall(Osi.DebugText, caster, msg)
    end
    log("toggle:", msg, caster and ("(cast by " .. tostring(caster) .. ")") or "(console)")
end

local granted = {}   -- per-character, so late joiners don't re-toast every heartbeat

local function grant(char)
    if not char or char == "" or granted[char] then return end
    granted[char] = true
    pcall(Osi.AddSpell, char, TOGGLE_SPELL_WILDS, 1, 0)
    pcall(Osi.AddSpell, char, TOGGLE_SPELL_REINFORCE, 1, 0)
    log("toggle: shouts granted to", char)
end

local function grantAll()
    local players = factGuids("DB_Players", 1)
    local host = Osi.GetHostCharacter()
    if host and host ~= "" and not granted[host] then players[#players + 1] = host end
    for _, p in ipairs(players) do grant(p) end
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

    Ext.Events.SessionLoaded:Subscribe(function ()
        restore()
        grantAll()
        log("Toggle.lua loaded (shouts:", TOGGLE_SPELL_WILDS .. ",", TOGGLE_SPELL_REINFORCE .. ")")
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
