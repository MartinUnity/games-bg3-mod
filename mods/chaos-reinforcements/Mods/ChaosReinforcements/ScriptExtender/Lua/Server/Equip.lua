-- ChaosReinforcements equipment module (server side). Ext.Require'd AFTER Common.lua.
-- Random gear + consumables for spawned humanoid mobs, driven by the creature's OWN stat
-- sheet (CreatureDB `prof` = Proficiency Group, `unarmed` = UnarmedAttackAbility) and the
-- player level, so low-level fights never roll expensive loot:
--   - innate attackers (unarmed, no prof) get NOTHING (never replace innate attacks)
--   - host level 1: always cheapest (simple weapon + light armor), no matter the profile
--   - tier keeps the chaos: tier >= 2 unlocks martial weapons if proficient,
--     tier 3 unlocks medium armor, tier 4 (jackpot) unlocks heavy armor (HEAVY_LEVEL+)
--     and the magic/level-scaled weapon tables ("weapon cost x2" proxy)
--   - WILD groups pass their GROUP tier (core/squad/warband) as the baseline instead of
--     the old per-member re-roll: squad bumps to 2 (20% -> 3), warband to 3 (20% -> 4),
--     boss slot +2; combat reinforcements keep the legacy self-roll (groupTier = nil)
--   - consumables: healing potion is BASELINE (guaranteed from level 3 up, all tiers) so
--     even dps can bail out a teammate with a throw; one extra roll per member from the
--     member-level-band pool (owner spec: low=1-3, mid=4-8, top=9-12) - poisons are the
--     lowest extras, speed the highest (top pool crown jewel, never mid/low)
-- Gear rolls in via Osi.GenerateTreasure (vanilla random tables, level-segmented); the
-- TemplateAddedTo listener auto-equips it; potions stay in inventory (mob AI drinks them).

local EQUIP_MOBS = true

-- vanilla random treasure tables (Shared TreasureTable.txt)
local T_SIMPLE = "ST_SimpleMeleeWeapons"          -- club/dagger/mace/spear/...
local T_SIMPLE_1 = "ST_SimpleMeleeWeapons_1"      -- level-scaled variant
local T_MARTIAL = "ST_MartialMeleeWeapons"        -- battleaxe/longsword/...
local T_MARTIAL_1 = "ST_MartialMeleeWeapons_1"    -- level-scaled variant
local T_FINESSE = "ST_Finesse_MeleeWeapons"       -- dagger/rapier/scimitar/shortsword
local T_FINESSE_MAGIC = "ST_Finesse_MeleeWeapons_Magic"
local T_LIGHT = "ST_LightArmor"
local T_MEDIUM = "ST_MediumArmor"
local T_HEAVY = "ST_HeavyArmor"
-- cosmetic decency fallback (owner 2026-10-31: casters without armor prof spawned
-- weaponless-looking AND naked); vanilla vanity tables, random common/rich garment,
-- sells for nothing, no proficiency requirement, does not block spellcasting
local T_CLOTHES_COMMON = "Clothes_Vanity_Body_Common"
local T_CLOTHES_RICH = "Clothes_Vanity_Body_Rich"

-- potion root templates (Name_GUID from the live root-template dump)
local POTION_HEAL = {
    "CONS_Potion_Healing_A_d47006e9-8a51-453d-b200-9e0d42e9bbab",
    "CONS_Potion_Healing_A_Greater_e3b95c96-dc26-40fe-bfc0-baa05e1abd20",
    "CONS_Potion_Healing_A_Superior_df4f3495-abaf-4732-b82f-55bcccd561db",
    "CONS_Potion_Healing_A_Supreme_7d78f227-e8d4-486d-8121-25cf0bee751d",
}
local POTION_SPEED = "CONS_Potion_Speed_ad9f3f24-d755-48b6-aa7b-c34da068209f"

-- "extra" consumable ladder (owner spec 2026-11-01): pool gated by the MEMBER's level
-- band - low = lvl 1-3, mid = 4-8, top = 9-12 - most members sit in mid. Poisons are
-- the lowest extras (applied with the free "use" action; NPC AI handles it), speed is
-- the crown jewel and lives ONLY in the top pool. DONOTUSE variants excluded; ids from
-- the live root-template dump (profile Script Extender/Chaos_root_templates.txt).
-- entries: { template, weight }
local POTION_POOLS = {
    low = {   -- lvl 1-3
        { "CONS_Poison_Basic_28645376-e6e8-436a-8e9a-c62877fae07d", 45 },
        { "CONS_Potion_Antitoxin_f0c7d8bb-85e9-4937-96bb-49ba69d28631", 15 },
        { "CONS_Potion_Fire_Resistance_2608c096-a0f5-4172-ad04-c1b170e10d95", 12 },
        { "CONS_Potion_Lightning_Resistance_05257244-ab59-4eab-9745-d1fea7b8cd10", 12 },
        { "CONS_Poison_Crawler_Mucus_5865caed-4a5d-45b7-b365-1113334a8e7b", 16 },
    },
    mid = {   -- lvl 4-8
        { "CONS_Potion_Heroism_A_bb27cc17-5af9-4d53-818b-3e620f3f59f2", 30 },
        { "CONS_Potion_Poison_Resistance_ae28b14c-0881-45fe-8237-9fcb1c951d3d", 15 },
        { "CONS_Potion_Psychic_Resistance_164ac6f3-8f93-4d74-9f72-e7c49723dedb", 15 },
        { "CONS_Potion_Necrotic_Resistance_f3c0aefb-a399-42c6-8d85-7fdceb6d18f5", 15 },
        { "CONS_Poison_Drow_f528a334-bdb3-4cf1-b74c-0e08942daeb1", 15 },
        { "CONS_Poison_Malice_d990fefe-e0f3-46ba-915e-35aebc6c6599", 10 },
    },
    top = {   -- lvl 9-12 - speed last: highest tier, weight = crown-jewel share
        { "CONS_Potion_Heroism_A_bb27cc17-5af9-4d53-818b-3e620f3f59f2", 20 },
        { "CONS_Potion_Regeneration_A_f768dbf5-d829-4f15-be1c-ee1f0d71f775", 20 },
        { "CONS_Potion_Invisible_A_809d5026-4896-4b3a-986e-95da58da77e2", 18 },
        { "CONS_Poison_Wyvern_eca393b0-3f8e-4862-814b-9e236a0d4129", 15 },
        { "CONS_Poison_Purple_Worm_56e531e9-78e4-430b-bc98-611c1b1ccd08", 12 },
        { POTION_SPEED, 15 },
    },
}
local POTION_BANDS = { { 3, "low" }, { 8, "mid" }, { 99, "top" } }

local pending = {}   -- guid of freshly spawned humanoid -> true (auto-equip guard)

local function rand(lo, hi) return math.random(lo, hi) end

local function healPotionFor(base)
    if base >= 11 then return POTION_HEAL[3] end
    if base >= 6 then return POTION_HEAL[2] end
    return POTION_HEAL[1]
end

local function potionPoolFor(lvl)
    for _, b in ipairs(POTION_BANDS) do
        if lvl <= b[1] then return POTION_POOLS[b[2]] end
    end
    return POTION_POOLS.top
end

local function rollPotion(pool)
    local total = 0
    for _, e in ipairs(pool) do total = total + e[2] end
    local r = rand(1, total)
    for _, e in ipairs(pool) do
        r = r - e[2]
        if r <= 0 then return e[1] end
    end
    return pool[1][1]
end

-- equipment tier baseline: WILD groups pass their group tier (owner: gear richness
-- follows the encounter rank, not an independent per-member lottery); a small bump
-- keeps the chaos (80% baseline, 20% one band up; boss slot rides +2). Combat
-- reinforcements (groupTier = nil) keep the legacy owner bands <=80/<=95/<=98/jackpot.
local function tierBaseline(groupTier, isBoss)
    if not groupTier then
        local roll = rand(1, 100)
        return roll <= 80 and 1 or (roll <= 95 and 2 or (roll <= 98 and 3 or 4))
    end
    local t = groupTier + (isBoss and 2 or 0)
    if rand(1, 100) <= 20 then t = t + 1 end
    return math.min(t, 4)
end

-- weapon + armor table for this creature/tier, or nil for "designed without"
local function equipmentFor(entry, base, tier)
    local prof = entry.prof or ""
    if entry.unarmed and prof == "" then return nil, nil end   -- innate attacker

    local finesse = (entry.dex or 10) > (entry.str or 10)
    local martial = prof:find("MartialWeapons", 1, true) ~= nil
    local weapon
    if base <= 1 then
        weapon = T_SIMPLE                                            -- lvl 1: cheapest, period
    elseif tier >= 2 and martial then
        weapon = T_MARTIAL
    else
        weapon = T_SIMPLE
    end
    if finesse then
        weapon = T_FINESSE   -- covers simple (dagger/shortsword) and martial (rapier/scimitar)
    end
    -- jackpot: magic / level-scaled weapon tables (never at lvl 1)
    if tier == 4 and base >= 4 then
        if finesse then weapon = T_FINESSE_MAGIC
        elseif weapon == T_MARTIAL then weapon = T_MARTIAL_1
        else weapon = T_SIMPLE_1 end
    end

    -- armor: ceiling = prof, actual tier decides how far up; lvl 1 always light;
    -- tier 3 unlocks medium, heavy stays tier-4-only (HEAVY_LEVEL+)
    local armor
    if base <= 1 then
        armor = T_LIGHT
    elseif tier >= 3 then
        if tier == 4 and prof:find("HeavyArmor", 1, true) and base >= HEAVY_LEVEL then armor = T_HEAVY
        elseif prof:find("MediumArmor", 1, true) then armor = T_MEDIUM
        else armor = T_LIGHT end
    else
        armor = T_LIGHT
    end
    if not (prof:find("Armor", 1, true) or base <= 1) then
        armor = nil                                                  -- no armor prof: native AC
    end
    return weapon, armor
end

-- public ------------------------------------------------------------------------

EquipPlanFor = equipmentFor   -- exposed for offline testing/debugging

function EquipResetPending()
    pending = {}
end

function EquipMob(created, base, entry, groupTier, isBoss)
    if not EQUIP_MOBS then return end
    pending[created] = true
    local tier = tierBaseline(groupTier, isBoss)
    -- member level (team templates bake their own) decides the potion band:
    -- low 1-3 / mid 4-8 / top 9-12 (owner spec)
    local mlvl = entry.fixedLevel or base
    if base <= 1 then tier = 1 end                                  -- lvl 1: cheapest gear only
    local weapon, armor = equipmentFor(entry, base, tier)
    -- no armor (innate/native AC) -> still give a random garment so the mob isn't
    -- naked; jackpot tier gets the rich wardrobe (owner: "make it interesting")
    local clothes = nil
    if not armor then
        clothes = (tier == 4) and T_CLOTHES_RICH or T_CLOTHES_COMMON
    end
    local tag = groupTier and ("(group " .. groupTier .. (isBoss and " boss" or "") .. ")") or "(roll)"
    log("equip: tier", tier, tag,
        weapon or "innate", "+", armor or (clothes and "clothes" or "native-armor"),
        "prof", entry.prof or (entry.unarmed and "innate" or "-"))
    if weapon then pcall(Osi.GenerateTreasure, created, weapon, base, created) end
    if armor then pcall(Osi.GenerateTreasure, created, armor, base, created) end
    if clothes then pcall(Osi.GenerateTreasure, created, clothes, base, created) end
    -- consumables: healing potion is the BASELINE from lvl 3 up, one per member at
    -- every group tier (owner: even dps can bail a teammate out with a throw);
    -- below lvl 3 the old rare-roll odds stay (10%/25%, tier 3+ = grown playtest odds).
    -- Then ONE "extra" roll from the member's band pool (poisons low, speed top);
    -- equip tier 4 doubles the healing and guarantees the extra.
    local potions = {}
    local heal = healPotionFor(math.max(base, mlvl))
    if mlvl >= 3 then
        potions[#potions + 1] = heal
    elseif tier >= 3 or rand(1, 100) <= (tier == 2 and 25 or 10) then
        potions[#potions + 1] = heal
    end
    if tier == 4 then
        potions[#potions + 1] = heal
        potions[#potions + 1] = rollPotion(potionPoolFor(mlvl))
    elseif rand(1, 100) <= (tier == 3 and 50 or (tier == 2 and 25 or 10)) then
        potions[#potions + 1] = rollPotion(potionPoolFor(mlvl))
    end
    for _, p in ipairs(potions) do
        pcall(Osi.TemplateAddTo, p, created, 1, 0)
    end
    if #potions > 0 then log("equip: potions", #potions) end
    -- deferred ground-truth probe: did the weapon actually reach the slot?
    -- (works even if the TemplateAddedTo route is dead - in-game logs showed gear
    -- rolls but no visible weapons/armor on the mobs)
    if weapon then
        pcall(Ext.Timer.WaitFor, 1500, function ()
            local okW, w = pcall(Osi.GetEquippedWeapon, created)
            log("arm check:", (okW and w and w ~= "") and tostring(w) or "NO WEAPON EQUIPPED",
                "on", created)
        end)
    end
end

-- level-appropriate pocket gold for leaders (owner spec 2026-10-31): leader gets a
-- small gold drop, boss the next tier. Vanilla pocket tables scale with the level
-- param of GenerateTreasure (subtable counts: Poor = 1-2x meager, Modest = 2x gold).
local LEADER_GOLD_TABLE = "Gold_Pocket_Poor"
local BOSS_GOLD_TABLE = "Gold_Pocket_Modest"
function GiveLeaderGold(mob, isBoss)
    local okL, lvl = pcall(Osi.GetLevel, mob)
    local level = (okL and tonumber(lvl)) or 1
    local table = isBoss and BOSS_GOLD_TABLE or LEADER_GOLD_TABLE
    local okG = pcall(Osi.GenerateTreasure, mob, table, level, mob)
    if okG then log("gold:", table, "lvl", level, "on", mob) end
end

-- auto-equip gear that GenerateTreasure rolls into our spawned mobs.
-- DIAGNOSTIC HISTORY: matched on the `pending` table keyed by CreateAtObject's
-- "Name_<guid>" string, but no "equipped" line EVER appeared in playtest logs -
-- either TemplateAddedTo's holder guid uses the raw shape, or Equip fails silently
-- inside the pcall (old code only logged success). Now matches via the shared
-- SPAWNED registry (normalized guids, works for Chaos AND Wild mobs) and logs
-- failures too, so the next log pinpoints the real cause.
-- weapons/armor equip into their slot; potions/gold fail into inventory (param 3).
local ok, err = pcall(function ()
    Ext.Osiris.RegisterListener("TemplateAddedTo", 4, "after", function (tmpl, object, holder, addType)
        if isSpawned(holder) then
            local okE, eE = pcall(Osi.Equip, holder, object, 1, 0, 1)
            if okE then
                log("equipped", object, "on", holder)
            else
                log("equip FAILED:", object, "on", holder, "-", tostring(eE))
            end
        end
    end)
end)
if ok then log("Equip.lua loaded") else log("Equip listener threw:", err) end
