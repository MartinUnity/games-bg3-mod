-- MARTIN_MoreMobs shared utilities + project-wide constants (server side).
-- MUST be Ext.Require'd FIRST: every other Server/*.lua uses log()/constants from here.
-- Log lands in the profile: Script Extender/MARTIN_chaos.log

local LINES = {}
local function flush()
    pcall(function () Ext.IO.SaveFile("MARTIN_chaos.log", table.concat(LINES, "\n")) end)
end

function log(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    LINES[#LINES + 1] = "[CHAOS] " .. table.concat(parts, " ")
    flush()
end

-- The E8b-proven hostile faction pair (verbatim; GetFaction(host) returns per-player
-- factions and the Evil_fb046e51 pair is inert - see docs/spawn-chains.md sec.3.1.2).
EVIL = "Evil_4be9261a-e481-8d9d-3528-f36956a19b17"
HERO = "Hero_a1542c81-6895-929e-4522-10ce218bb360"

-- Level-design constants shared between engine and equipment:
SOFT_CAP_LEVEL = 2   -- host level <= this: mob levels never exceed the player's
HEAVY_LEVEL = 5      -- heavy types (below) and heavy armor need this player level
HEAVY_TYPES = { Dragon = true, Giant = true, Celestial = true }
