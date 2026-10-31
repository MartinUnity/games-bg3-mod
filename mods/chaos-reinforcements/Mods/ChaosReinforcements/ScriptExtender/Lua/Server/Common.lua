-- ChaosReinforcements shared utilities + project-wide constants (server side).
-- MUST be Ext.Require'd FIRST: every other Server/*.lua uses log()/constants from here.
-- Log lands in the profile: Script Extender/ChaosReinforcements.log

local LINES = {}
local function flush()
    pcall(function () Ext.IO.SaveFile("ChaosReinforcements.log", table.concat(LINES, "\n")) end)
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
LEVEL_JITTER = 2     -- SetLevel target = hostLevel + rand(-J, +J) above the soft cap

-- Shared engine helpers (used by Chaos.lua AND Wild.lua):
DEFAULT_TYPES = { "Beast", "Monstrosity", "Humanoid", "Undead", "Fiend" }

-- native-stat gates: at low levels pick creatures that are NATIVELY harmless
GATES = {
    [1] = { stat = 12, ac = 14, hp = 20 },
    [2] = { stat = 14, ac = 15, hp = 35 },
}

function rowGuid(row)
    if type(row) ~= "table" then return row end
    for _, k in ipairs({ "Object", "Character", "Player", "PartyMember", "Target" }) do
        if row[k] ~= nil and row[k] ~= "" then return row[k] end
    end
    for _, v in ipairs(row) do
        if type(v) == "string" and v ~= "" then return v end
    end
    return nil
end

-- ncols MUST match the database's column count (SE names DBs by arity)
function factGuids(dbName, ncols)
    local db = Osi[dbName]
    if not db then return {} end
    local ok, rows = pcall(function () return db:Get(table.unpack({}, 1, ncols or 1)) end)
    if not ok then log(dbName .. ":Get threw:", rows); return {} end
    local out = {}
    if type(rows) == "table" then
        for _, row in pairs(rows) do
            local g = rowGuid(row)
            if g then out[#out + 1] = g end
        end
    end
    return out
end

-- native-stat gate for the player's level: nil = entry is fine
function passesGate(e, base)
    -- native level gate: a stat block that is natively several levels above the party
    -- (Floating_Head etc.) is out-of-depth even when its hp/ac pass (lvl-7 vs lvl-2 party)
    if e.lvl and e.lvl > base + LEVEL_JITTER then return false end
    local g = GATES[base]
    if g then
        if e.hp > g.hp then return false end
        if e.ac and e.ac > g.ac then return false end
        local best = math.max(e.str or 0, e.dex or 0)
        if best > g.stat then return false end
        if e.ea then return false end  -- ExtraAttack at lvl 1-2 = TPK fuel
    end
    return true
end

function gatedPool(typeName, base)
    local pool = CHAOS_DB and CHAOS_DB[typeName]
    if not pool or #pool == 0 then return nil end
    if HEAVY_TYPES[typeName] and base < HEAVY_LEVEL then return nil end
    local out = {}
    for _, e in ipairs(pool) do
        if passesGate(e, base) then out[#out + 1] = e end
    end
    return out
end

function pickFrom(typeName, maxCost, base)
    local pool = gatedPool(typeName, base)
    if not pool or #pool == 0 then return nil end
    -- try 20 random picks for one within budget; fall back to cheapest entry
    for _ = 1, 20 do
        local e = pool[math.random(1, #pool)]
        if e.cost <= maxCost then return e end
    end
    local cheapest = pool[1]
    for _, e in ipairs(pool) do if e.cost < cheapest.cost then cheapest = e end end
    return cheapest.cost <= maxCost and cheapest or nil
end

-- leaders are deliberately OUTSIDE the budget: pick from the beefier half of the gated pool
function pickLeaderFrom(typeName, base)
    local pool = gatedPool(typeName, base)
    if not pool or #pool == 0 then return nil end
    local sorted = {}
    for _, e in ipairs(pool) do sorted[#sorted + 1] = e end
    table.sort(sorted, function (a, b) return a.cost < b.cost end)
    local from = math.max(1, math.floor(#sorted / 2) + 1)
    return sorted[math.random(from, #sorted)]
end

-- level math: never above the player's level while they are SOFT_CAP_LEVEL or lower
function targetLevelFor(base)
    if base <= SOFT_CAP_LEVEL then
        return math.max(1, base + math.random(-2, 0))
    end
    return math.max(1, base + math.random(-LEVEL_JITTER, LEVEL_JITTER))
end
