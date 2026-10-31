-- MARTIN_MoreMobs probe (server-side Lua).
-- Purpose: prove the Lua channel works end to end, and answer the two questions the
-- story-overlay experiment could not (docs/spawn-chains.md sec.3.1.1):
--   (1) does the rule run at all?  -> every step is logged
--   (2) which creature templates can actually be instantiated here?
-- Every API used below appears in docs/vendor/bg3se-Lua-API.md; the Osiris signatures come
-- from Data/Mods/GustavDev/Story/RawFiles/story_header.div (CreateAtObject 508, SetFaction
-- 933, SetHostileAndEnterCombat 921, GetPosition 543).
--
-- Log output needs Script Extender logging on: bin/ScriptExtenderSettings.json
-- {"LogEnabled": true} -> bg3-print.log next to bin/bg3.exe.

local TAG = "MARTIN"

local function log(...)
    Ext.Print("[" .. TAG .. "]", ...)
end

-- Templates to try. A: a character the prologue level itself places (named by vanilla goals
-- in Gustav/Story/RawFiles/Goals/TUT_LowerDeck.txt), so it must exist in TUT_Avernus_C.
-- B: the template from Larian's own spawn test (Gustav/.../Goals/Test.txt:353), which lives
-- in a different level - the control case for "can we use a foreign template".
local TEMPLATES = {
    "S_FirstFight_Imp_Melee_01_07f1512b-efe9-4eb8-8ade-783435e9d7c9",
    "Wolf_41da0eff-b533-43cc-a014-218f7d23fa11",
}

local EVIL = "Evil_4be9261a-e481-8d9d-3528-f36956a19b17"
local HERO = "Hero_a1542c81-6895-929e-4522-10ce218bb360"

local function spawnOne(anchor, templateId)
    local created = Osi.CreateAtObject(templateId, anchor, 1, 1, "", 1)
    if not created then
        log("CreateAtObject produced nothing for", templateId)
        return nil
    end
    log("created", templateId, "->", created)
    Osi.SetFaction(created, EVIL)
    Osi.SetHostileAndEnterCombat(EVIL, HERO, created, anchor)
    return created
end

local function spawnAll(anchor)
    for _, templateId in ipairs(TEMPLATES) do
        local ok, err = pcall(spawnOne, anchor, templateId)
        if not ok then log("spawn threw for", templateId, ":", err) end
    end
end

-- One-off dump of every root template in the loaded game, so template naming can be checked
-- offline instead of guessed at. Written to the Script Extender folder in the profile dir.
local dumped = false
local function dumpTemplates()
    if dumped then return end
    dumped = true
    local ok, err = pcall(function ()
        local names = {}
        for name, _ in pairs(Ext.Template.GetAllRootTemplates()) do
            names[#names + 1] = tostring(name)
        end
        table.sort(names)
        Ext.IO.SaveFile("MARTIN_root_templates.txt", table.concat(names, "\n"))
        log("template dump written:", #names, "root templates")
    end)
    if not ok then log("template dump failed:", err) end
end

-- Proof of life: runs on every save load, and prints the level from Osiris state we know
-- exists (DB_CurrentLevel is maintained by Shared/.../__AAA_FirstGoal.txt:2954).
Ext.Events.SessionLoaded:Subscribe(function ()
    dumpTemplates()
    local rows = Osi.DB_CurrentLevel:Get(nil)
    log("SessionLoaded; DB_CurrentLevel rows:", Ext.DumpExport and Ext.DumpExport(rows) or rows)
end)

-- The experiment itself: one extra body per template for every combat that starts, logged at
-- each step. Arity 1 matches CombatStarted(_CombatGuid).
Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function (combatId)
    local ok, err = pcall(function ()
        local host = Osi.GetHostCharacter()
        log("CombatStarted", combatId, "host", host)
        spawnAll(host)
    end)
    if not ok then log("CombatStarted handler threw:", err) end
end)

-- Dev-console handle so a spawn can be tested without starting a fight: !martin_spawn
Ext.RegisterConsoleCommand("martin_spawn", function ()
    spawnAll(Osi.GetHostCharacter())
end)
