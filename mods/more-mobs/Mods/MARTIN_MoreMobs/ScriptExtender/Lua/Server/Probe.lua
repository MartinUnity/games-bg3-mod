-- MARTIN_MoreMobs probe v2 (server-side Lua).
-- v1 lesson (2026-10-31): the mod DOES load (template dump was written on SessionLoaded) but the
-- spawn attempts were silent: SE v33 has no "LogEnabled" key and no bg3-print.log -- runtime logs
-- go to <prefix>/drive_c/users/steamuser/Script Extender Logs/Extender Runtime.log and need
-- "LogRuntime": true in bin/ScriptExtenderSettings.json (verified against the v33 DLL strings).
-- v2 still file-logs through Ext.IO.SaveFile (proven on this install) so diagnostics are
-- inspectable offline: profile "Script Extender/MARTIN_probe.log".
--
-- v1 template-dump facts: keys are bare GUIDs (32016 of them); the E8b wolf GUID
-- 41da0eff-b533-... IS present; prologue imp-instance GUID is NOT (matches story findings).

local TAG = "MARTIN"
local LINES = {}

local function flush()
    pcall(function () Ext.IO.SaveFile("MARTIN_probe.log", table.concat(LINES, "\n")) end)
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

-- Factions verified from vanilla goals (Hero_... appears 179x; Evil_fb046e51 is the common Evil).
local EVIL = "Evil_fb046e51-c544-4836-81eb-754ca8a021b6"
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
                    local hostileTo = (hostFaction and hostFaction ~= "" and hostFaction ~= EVIL) and hostFaction or HERO
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
        Ext.IO.SaveFile("MARTIN_root_templates.txt", table.concat(rows, "\n"))
        log("template dump written:", #rows, "entries (GUID<TAB>Name)")
    end)
    if not ok3 then log("template dump failed:", err3) end
end

Ext.Events.SessionLoaded:Subscribe(function ()
    log("SessionLoaded")
    dumpTemplates()
    local ok3, rows = pcall(function () return Osi.DB_CurrentLevel:Get(nil) end)
    log("DB_CurrentLevel:", ok3 and Ext.DumpExport(rows) or ("threw: " .. tostring(rows)))
end)

-- Console command for manual tests: !martin_spawn
Ext.RegisterConsoleCommand("martin_spawn", function ()
    local host = Osi.GetHostCharacter()
    for _, templateId in ipairs(TEMPLATES) do
        local ok3, res = pcall(function ()
            local created = Osi.CreateAtObject(templateId, host, 1, 1, "", 1)
            log("console CreateAtObject", templateId, "->", created)
        end)
        if not ok3 then log("console spawn threw:", res) end
    end
end)
