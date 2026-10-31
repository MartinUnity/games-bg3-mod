-- ChaosReinforcements probe v2 (server-side Lua).
-- v1 lesson (2026-10-31): the mod DOES load (template dump was written on SessionLoaded) but the
-- spawn attempts were silent: SE v33 has no "LogEnabled" key and no bg3-print.log -- runtime logs
-- go to profile "Script Extender Logs/Extender Runtime*.log" and need "LogRuntime": true in
-- bin/ScriptExtenderSettings.json (verified against the v33 DLL strings).
-- v2 still file-logs through Ext.IO.SaveFile (proven on this install) so diagnostics are
-- inspectable offline: profile "Script Extender/Chaos_probe.log".
--
-- v1 template-dump facts: keys are bare GUIDs (32016 of them); the E8b wolf GUID
-- 41da0eff-b533-... IS present; prologue imp-instance GUID is NOT (matches story findings).

local TAG = "CHAOS_PROBE"
local LINES = {}

local function flush()
    pcall(function () Ext.IO.SaveFile("Chaos_probe.log", table.concat(LINES, "\n")) end)
end

local function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    LINES[#LINES + 1] = "[" .. TAG .. "] " .. table.concat(parts, " ")
    flush()
end

-- E8b-proven global root template, plus the level-placed prologue instance (expected failure).
local TEMPLATES = {
    "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11",
    "S_FirstFight_Imp_Melee_01_07f1512b-efe9-4eb8-8ade-783435e9d7c9",
}

-- Faction pair copied VERBATIM from the E8b story probe that made this wolf attack the party
-- (docs/goals/MARTIN_SpawnProbe.txt:55-56). v2 used Evil_fb046e51 + the host's real per-player
-- faction ("Hero Player1_<guid>", surfaced by GetFaction) and the pair silently did nothing --
-- wolf spawned neutral/yellow.
local EVIL = "Evil_4be9261a-e481-8d9d-3528-f36956a19b17"
local HERO = "Hero_a1542c81-6895-929e-4522-10ce218bb360"

log("Probe.lua loaded")

local ok, err = pcall(function ()
    Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function (combatId)
        log("CombatStarted", combatId)
        local host = nil
        local okH, h = pcall(Osi.GetHostCharacter)
        if okH then host = h else log("GetHostCharacter threw:", h) end
        if (not host or host == "") and Osi.DB_CurrentLevel ~= nil then
            local okP, players = pcall(Osi.GetPlayers)
            if okP and players and players[1] then host = players[1] end
        end
        log("anchor host:", host)
        if not host or host == "" then log("no anchor, giving up"); return end

        local hostFaction = nil
        local okF, f = pcall(Osi.GetFaction, host)
        if okF then hostFaction = f else log("GetFaction threw:", f) end
        log("host faction:", hostFaction)

        for _, templateId in ipairs(TEMPLATES) do
            local okS, res = pcall(function ()
                local created = Osi.CreateAtObject(templateId, host, 1, 1, "", 1)
                log("CreateAtObject", templateId, "->", created)
                if created and created ~= "" then
                    local okG, eG = pcall(Osi.SetFaction, created, EVIL)
                    log("SetFaction EVIL:", okG and "ok" or eG)
                    local hostileTo = HERO  -- E8b-proven fixed pair; do NOT use the per-player faction
                    local okX, eX = pcall(Osi.SetHostileAndEnterCombat, EVIL, hostileTo, created, host)
                    log("SetHostileAndEnterCombat (EVIL vs", hostileTo, "):", okX and "ok" or eX)
                end
            end)
            if not okS then log("spawn threw for", templateId, ":", res) end
        end
    end)
end)
if ok then log("CombatStarted listener registered") else log("registration threw:", err) end

-- Template dump: key GUID + name where available (v1 dumped GUIDs only).
local dumped = false
local function dumpTemplates()
    if dumped then return end
    dumped = true
    local ok3, err3 = pcall(function ()
        local rows = {}
        for key, tmpl in pairs(Ext.Template.GetAllRootTemplates()) do
            local nm = "?"
            pcall(function () nm = tmpl.Name end)
            rows[#rows + 1] = tostring(key) .. "\t" .. tostring(nm)
        end
        table.sort(rows)
        Ext.IO.SaveFile("Chaos_root_templates.txt", table.concat(rows, "\n"))
        log("template dump written:", #rows, "entries (GUID<TAB>Name)")
    end)
    if not ok3 then log("template dump failed:", err3) end
end

Ext.Events.SessionLoaded:Subscribe(function ()
    log("SessionLoaded")
    dumpTemplates()
    -- NB: do NOT read Osiris DB facts here -- v2 hit "Attempted to read Osiris database in
    -- restricted context" for Osi.DB_CurrentLevel:Get(nil) at SessionLoaded time.
end)

-- Console command for manual tests: !chaos_spawn
Ext.RegisterConsoleCommand("chaos_spawn", function ()
    local host = Osi.GetHostCharacter()
    for _, templateId in ipairs(TEMPLATES) do
        local ok3, res = pcall(function ()
            local created = Osi.CreateAtObject(templateId, host, 1, 1, "", 1)
            log("console CreateAtObject", templateId, "->", created)
        end)
        if not ok3 then log("console spawn threw:", res) end
    end
end)
