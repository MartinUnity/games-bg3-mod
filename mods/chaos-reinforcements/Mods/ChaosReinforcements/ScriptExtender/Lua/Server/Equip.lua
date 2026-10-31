-- ChaosReinforcements equipment module (server side). Ext.Require'd AFTER Common.lua.
-- Random gear + consumables for spawned humanoid mobs, driven by the creature's OWN stat
-- sheet (CreatureDB `prof` = Proficiency Group, `unarmed` = UnarmedAttackAbility) and the
-- player level, so low-level fights never roll expensive loot:
--   - innate attackers (unarmed, no prof) get NOTHING (never replace innate attacks)
--   - host level 1: always cheapest (simple weapon + light armor), no matter the profile
--   - tier roll keeps the chaos: tier >= 2 unlocks martial weapons if proficient,
--     tier 4 (jackpot) unlocks medium armor if proficient (heavy at HEAVY_LEVEL+) and the
--     magic/level-scaled weapon tables ("weapon cost x2" proxy)
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

local pending = {}   -- guid of freshly spawned humanoid -> true (auto-equip guard)

local function rand(lo, hi) return math.random(lo, hi) end

local function healPotionFor(base)
    if base >= 11 then return POTION_HEAL[3] end
    if base >= 6 then return POTION_HEAL[2] end
    return POTION_HEAL[1]
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

    -- armor: ceiling = prof, actual tier decides how far up; lvl 1 always light
    local armor
    if base <= 1 then
        armor = T_LIGHT
    elseif tier == 4 then
        if prof:find("HeavyArmor", 1, true) and base >= HEAVY_LEVEL then armor = T_HEAVY
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

function EquipMob(created, base, entry)
    if not EQUIP_MOBS then return end
    pending[created] = true
    -- owner's bands: <=80% basic, <=95% more, <=98% even more, else jackpot
    local roll = rand(1, 100)
    local tier = roll <= 80 and 1 or (roll <= 95 and 2 or (roll <= 98 and 3 or 4))
    if base <= 1 then tier = 1 end                                  -- lvl 1: cheapest gear only
    local weapon, armor = equipmentFor(entry, base, tier)
    -- no armor (innate/native AC) -> still give a random garment so the mob isn't
    -- naked; jackpot tier gets the rich wardrobe (owner: "make it interesting")
    local clothes = nil
    if not armor then
        clothes = (tier == 4) and T_CLOTHES_RICH or T_CLOTHES_COMMON
    end
    log("equip: tier", tier, "(roll", roll .. ")",
        weapon or "innate", "+", armor or (clothes and "clothes" or "native-armor"),
        "prof", entry.prof or (entry.unarmed and "innate" or "-"))
    if weapon then pcall(Osi.GenerateTreasure, created, weapon, base, created) end
    if armor then pcall(Osi.GenerateTreasure, created, armor, base, created) end
    if clothes then pcall(Osi.GenerateTreasure, created, clothes, base, created) end
    -- consumables
    local potions = {}
    if tier == 1 then
        if rand(1, 100) <= 10 then potions[#potions + 1] = healPotionFor(base) end
    elseif tier == 2 then
        if rand(1, 100) <= 25 then potions[#potions + 1] = healPotionFor(base) end
    elseif tier == 3 then
        potions[#potions + 1] = healPotionFor(base)
    else
        potions[#potions + 1] = healPotionFor(base)
        potions[#potions + 1] = healPotionFor(base)
        potions[#potions + 1] = POTION_SPEED   -- "extra random thing", not overpowered
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
