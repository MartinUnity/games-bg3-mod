-- "Chaos Reinforcements" flavor module (server side). Ext.Require'd AFTER Common.lua.
-- Names + announcements for LEADER spawns (pack mobs keep their template names by design).

local LEADER_ANNOUNCE = true    -- OpenMessageBox to the host when a leader spawns (testing: on)
local LEADER_RENAME = true      -- overwrite the leader's overhead display name

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

-- announcement texts (%s = villain name); picked at random
local SHOUTS = {
    "Reinforcements! %s has joined the battle!",
    "A war horn echoes - %s arrives to turn the tide!",
    "Fresh enemies pour in, led by %s!",
    "%s strides onto the battlefield. This fight just got serious.",
    "Blood in the water - %s brings reinforcements!",
    "The clatter of armor... %s has come to collect your skulls!",
}

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
            entity:Replicate("DisplayName")
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

-- public: call right after a leader spawned; host gets the popup
function FlavorLeader(created, host)
    local name = villainName()
    if LEADER_RENAME and created then
        tryRename(created, name, 1)
    end
    if LEADER_ANNOUNCE and host then
        local msg = pick(SHOUTS):format(name)
        local okM, eM = pcall(Osi.OpenMessageBox, host, msg)
        if not okM then log("OpenMessageBox threw:", eM) end
        log("leader announced:", name)
    end
end

log("Flavor.lua loaded")
