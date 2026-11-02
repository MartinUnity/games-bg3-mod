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
--   - support slot (class-appropriate, owner spec 2026-11-01): caster = 0-X scrolls,
--     ranged = bow + 0-X special arrow stacks, melee = 0-X strong poisons/grenades;
--     pool band (low/mid/top) follows encounter rank (group tier), count rides the
--     equip tier - ⚠️ NPC scroll/arrow AI use needs in-game confirmation (logged)
--   - role parity (v3.28, owner: reinforcements must LOOK class-appropriate): role =
--     team slot, or template-name guess for pool mobs (Ranger/Hunter... -> ranged;
--     Caster/Cleric/Wizard/Necro... -> caster). Casters get a QUARTERSTAFF (+scrolls),
--     not a rapier lottery; ranged get bows as the PRIMARY weapon (martial tables at
--     tier 2+, level-scaled at tier 4); Shields-proficient melees carry shields
--     (tank slot 100%, other melee ~55%) - finesse/weirdness gated to melee only
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
-- v3.37 ARMOR FIX (owner: half-elf squad spawned "underwear only" despite AC math
-- proving armor stats): the ST_Light/Medium/HeavyArmor treasure tables reference
-- I_ARM_*_Body loot stats-ids that have NO root template in the live dump
-- (ARM_Leather exists, ARM_Leather_Body does not) -> GenerateTreasure produced
-- ZERO items from them, silently inside pcall. Armor now comes like staff/shields
-- already did: direct TemplateAddTo of real ARM_* root templates (Name_GUID from
-- Chaos_root_templates.txt) -> TemplateAddedTo listener auto-equips -> VISIBLE.
-- Band choice keeps the old proficiency/tier gating.
local ARMOR_BANDS = {
    light  = { "ARM_Padded_63cc7723-245d-4b62-b9e6-5a47283cf777",
               "ARM_Leather_02ae5d88-8044-43df-8363-02a2900776db",
               "ARM_StuddedLeather_19451420-13f6-444c-a15b-7abb6dde3f91" },
    medium = { "ARM_Hide_b78fabcc-d2df-4c74-b5d4-1eda6dc4c071",
               "ARM_ChainShirt_921cd1e1-c39c-44c3-a090-b667322af7f8",
               "ARM_ScaleMail_ca0aafad-0f1e-4d76-8e3b-925397bb436b",
               "ARM_Breastplate_4814825e-23ee-41ed-9784-d9963434150d" },
    heavy  = { "ARM_RingMail_e3a5099a-397a-4bbc-932c-cd0a00043b79",
               "ARM_Splint_8ed82f7e-fdd4-4a9f-94b6-f256c599bfdd",
               "ARM_Plate_95b4e2c4-759a-4d33-a2d1-4e0ee6ed4f29" },
}
local T_RANGED = "ST_SimpleRangedWeapons"           -- longbow/shortbow/light crossbow (all simple)
local T_RANGED_1 = "ST_SimpleRangedWeapons_1"       -- level-scaled variant
local T_RANGED_M = "ST_MartialRangedWeapons"        -- hand crossbow (martial)
local T_RANGED_M1 = "ST_MartialRangedWeapons_1"
-- v3.28 role-parity kit (owner: reinforcements must LOOK class-appropriate):
-- casters get a quarterstaff, Shields-proficient melees get shields (shields are
-- off-hand WPN_* templates; the TemplateAddedTo auto-equip listener places them).
-- ids verified against the live root-template dump (no DONOTUSE/NOT_APPROVED).
local STAFF_0 = "WPN_HUM_Quarterstaff_A_0_96e2abaf-78ff-4dcb-a6a3-a5f0c348bd9f"
local STAFF_1 = "WPN_HUM_Quarterstaff_A_1_2fa18ee4-92df-486f-97d2-dd0a720b6fad"
local SHIELD_BASIC = {
    "WPN_HUM_Shield_B_0_24fa28d4-f679-44bf-865e-c7e70dcb9588",
    "WPN_HUM_Shield_C_0_4491fcaf-03bf-4087-baf3-b638657080f6",
}
local SHIELD_1 = "WPN_HUM_Shield_D_1_26b81847-b0dd-4150-aef7-602fcbb72eca"
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
        { "CONS_Potion_Hill_Giant_Strength_c69fb092-2f4f-4688-82b6-7d92405626b1", 20 },
        { "CONS_Potion_Invisible_A_809d5026-4896-4b3a-986e-95da58da77e2", 18 },
        { "CONS_Poison_Wyvern_eca393b0-3f8e-4862-814b-9e236a0d4129", 15 },
        { "CONS_Poison_Purple_Worm_56e531e9-78e4-430b-bc98-611c1b1ccd08", 12 },
        { POTION_SPEED, 15 },
    },
}
local POTION_BANDS = { { 3, "low" }, { 8, "mid" }, { 99, "top" } }

local pending = {}   -- guid of freshly spawned humanoid -> true (auto-equip guard)

local function rand(lo, hi) return math.random(lo, hi) end

-- v3.28 role guess (equip parity): team slots carry an explicit role; CreatureDB
-- pool mobs get a name-pattern read (verified against the live DB's nm strings:
-- "Goblin Ranger", "Elf Druid", "Human Cultist Bhaal Invoker", "Sahuagin Hunter"...).
-- Order matters: "Ranger Stone Guard" -> ranged (frontline read is secondary).
local RANGED_WORDS = { "Ranger", "Hunter", "Archer", "Scout", "Sniper", "Marksman", "Crossbow", "Bowman" }
local CASTER_WORDS = { "Caster", "Cleric", "Druid", "Warlock", "Wizard", "Mage", "Priest", "Acolyte",
                       "Shaman", "Necro", "Invoker", "Conjurer", "Sorcerer", "Healer", "Bard" }
local function nameHas(hay, words)
    for _, w in ipairs(words) do
        if hay:find(w, 1, true) then return true end
    end
    return false
end
local function weaponRoleFor(entry)
    if entry.role == "ranged" or entry.role == "caster" then return entry.role end
    if entry.role then return "melee" end          -- tank / dps / healer / wildcard slots
    local hay = (entry.nm or "") .. " " .. tostring(entry.id or "")
    if nameHas(hay, RANGED_WORDS) then return "ranged" end
    if nameHas(hay, CASTER_WORDS) then return "caster" end
    return "melee"
end

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

-- class-appropriate "support" slot (owner spec 2026-11-01): casters get 0-X spell
-- scrolls, ranged get 0-X special arrows (BG3 ammo is shared arrows/bolts) + a bow so
-- the arrows are usable, melee gets stronger poisons + alchemist grenades. POOL BAND
-- (low/mid/top) follows the encounter rank (group tier, equip tier 3+ pushes up one);
-- COUNT is 0-X binomial on the equip tier (X = groupTier + equip bonuses, cap 4).
-- ⚠️ playtest: scrolls may need the spell known by the caster kit, and NPC AI may
-- ignore arrows/scrolls - the log lines mark who got what for that follow-up.
-- ids = Name_<guid> from the live root-template dump.
local SUPPORT_POOLS = {
    caster = {
        { "LOOT_SCROLL_MagicMissile_945cd4f0-991b-4663-b72e-790d49fee27e",
          "LOOT_SCROLL_BurningHands_bc00df72-3c98-4bf2-9650-28e08f79b57c",
          "LOOT_SCROLL_ChromaticOrb_c6aef37e-bc4d-46e7-a963-15b4cd8163bd",
          "LOOT_SCROLL_WitchBolt_e69f52a4-3d86-4f08-a9b4-c70ba4cc3070",
          "LOOT_SCROLL_Thunderwave_94caa680-50b8-46b1-b775-19150d783b2f" },
        { "LOOT_SCROLL_Fireball_79d2bb95-53fc-4e41-a004-5e1b83db8de7",
          "LOOT_SCROLL_Web_2eedb4ac-47fa-4039-9684-8b4bb0923a26",
          "LOOT_SCROLL_Shatter_2ad118cb-b11f-45ca-a206-7575bbbaccc6",
          "LOOT_SCROLL_ChainLightning_13105f7d-55fa-4292-abfe-b9d80054b48e",
          "LOOT_SCROLL_Confusion_7634cc33-d16b-4640-ba7c-8c6a26653591" },
        { "LOOT_SCROLL_Sunbeam_049d70c4-7ea3-4b6c-af6f-44dab7813a89",
          "LOOT_SCROLL_WallOfFire_0f3c7369-d0bd-4b97-960d-1407f4c8eebf",
          "LOOT_SCROLL_Cloudkill_0e793d2d-1cd7-4b90-a71b-821423e50969",
          "LOOT_SCROLL_Disintegrate_3f737706-57ca-45e6-b0d1-45238da76329",
          "LOOT_SCROLL_Fly_1df15994-c860-4930-beed-3135b74025fa" },
    },
    ranged = {
        { "ARR_Arrow_Of_Fire_9a142fae-bcea-4e88-a407-16d3b27468b9",
          "ARR_Arrow_Of_Ice_2e297d80-823b-4200-926e-6ca23f488090",
          "ARR_Arrow_Of_Lightning_1b0f095b-cb22-4bf9-aecf-4e5a26504ec8",
          "ARR_Arrow_Of_Acid_0bfb72d2-0e8e-4d16-aeae-3159b0d4b195" },
        { "ARR_Arrow_Of_Ricochet_b11b3f7f-d8ec-41db-93b9-24474aea31e3",
          "ARR_Arrow_Of_Piercing_eee2f284-1a42-462a-8b38-50bd2e3885c5",
          "ARR_Arrow_Of_Smokepowder_0788a2bb-c732-4ebb-abf9-2ef150f509be",
          "ARR_Arrow_Of_Fire_9a142fae-bcea-4e88-a407-16d3b27468b9" },
        { "ARR_Arrow_Of_Detonation_a0985797-4ec7-475c-8e11-0361e387f39a",
          "ARR_Arrow_Of_Lightning_1b0f095b-cb22-4bf9-aecf-4e5a26504ec8",
          "ARR_Arrow_Of_Ice_2e297d80-823b-4200-926e-6ca23f488090" },
    },
    melee = {
        { "CONS_Poison_Serpent_Venom_b0385b93-f525-4740-8126-471a76fa31a2",
          "ALCH_Solution_Grenade_Light_c3236e6e-21e4-4e39-a5b4-fda105d8ce3f" },
        { "CONS_Poison_Drow_f528a334-bdb3-4cf1-b74c-0e08942daeb1",
          "CONS_Poison_Malice_d990fefe-e0f3-46ba-915e-35aebc6c6599",
          "ALCH_Solution_Grenade_Web_a4d98266-948b-4467-96cd-6a316f37ceda",
          "ALCH_Solution_Grenade_SporesConfusion_cbc47f2b-b88a-4bd8-99cd-aacc2dc2ea44" },
        { "CONS_Poison_Wyvern_eca393b0-3f8e-4862-814b-9e236a0d4129",
          "CONS_Poison_Purple_Worm_56e531e9-78e4-430b-bc98-611c1b1ccd08",
          "ALCH_Solution_Grenade_SporesToxic_9320005f-18c6-4c2b-be7f-e168d3b15573" },
    },
}

local function supportRoleFor(entry)
    -- v3.28: same name/role read as the weapon side (pool mobs now get caster scrolls
    -- and ranged arrow stacks too); team healers keep the melee kit (poisons/grenades,
    -- they heal with potions - playtest-confirmed AI behaviour).
    if entry.role == "healer" then return "melee" end
    return weaponRoleFor(entry)
end

local function supportSlot(entry, groupTier, tier)
    local gt = groupTier or 1
    local band = gt + (tier >= 3 and 1 or 0)
    band = math.max(1, math.min(band, 3))
    local cap = math.min(gt + (tier >= 3 and 1 or 0) + (tier == 4 and 1 or 0), 4)
    local p = (tier == 1 and 30) or (tier == 2 and 60) or (tier == 3 and 80) or 100
    local n = 0
    for _ = 1, cap do
        if rand(1, 100) <= p then n = n + 1 end
    end
    if n == 0 then return supportRoleFor(entry), band, nil end
    local role = supportRoleFor(entry)
    local pool = SUPPORT_POOLS[role][band]
    local picked = {}
    local qty = 1
    for _ = 1, n do
        local t = pool[rand(1, #pool)]
        if role == "ranged" then
            qty = rand(3, 5) + (tier >= 3 and 1 or 0)   -- arrows come in stacks
        end
        picked[#picked + 1] = { t, qty }
    end
    return role, band, picked
end

-- weapon + armor table for this creature/tier, or nil for "designed without".
-- v3.28 role parity (owner: reinforcements must look class-appropriate):
--   caster -> quarterstaff TEMPLATE (not a rapier lottery); needs weapon proficiency,
--             tier 4 gets the level-scaled staff
--   ranged -> bow/crossbow table as the PRIMARY weapon (was an ad-hoc bow in support)
--   melee/tank -> shield when Shields-proficient: tank always, other melee ~55%
-- third return = extra root templates (staff/shield) added directly; the
-- TemplateAddedTo auto-equip listener places them (shields are off-hand weapons).
local function equipmentFor(entry, base, tier)
    local prof = entry.prof or ""
    if entry.unarmed and prof == "" then return nil, nil end   -- innate attacker
    local role = weaponRoleFor(entry)
    local martial = prof:find("MartialWeapons", 1, true) ~= nil
    local staffed = role == "caster"
        and (prof:find("SimpleWeapons", 1, true) or prof:find("Quarterstaffs", 1, true)) ~= nil
    local finesse = (entry.dex or 10) > (entry.str or 10)
                    and role ~= "caster" and role ~= "ranged"  -- high-dex casters/ranged keep their kit
    local weapon
    if staffed then
        weapon = nil                                           -- the staff IS the weapon (extras below)
    elseif role == "ranged" then
        if base <= 1 then weapon = T_RANGED
        elseif tier >= 2 and martial then weapon = T_RANGED_M
        else weapon = T_RANGED end
    elseif base <= 1 then
        weapon = T_SIMPLE                                      -- lvl 1: cheapest, period
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
        elseif weapon == T_RANGED then weapon = T_RANGED_1
        elseif weapon == T_RANGED_M then weapon = T_RANGED_M1
        elseif weapon == T_SIMPLE then weapon = T_SIMPLE_1 end
    end

    -- armor: ceiling = prof, actual tier decides how far up; lvl 1 always light;
    -- tier 3 unlocks medium, heavy stays tier-4-only (HEAVY_LEVEL+)
    local armor
    if base <= 1 then
        armor = "light"
    elseif tier >= 3 then
        if tier == 4 and prof:find("HeavyArmor", 1, true) and base >= HEAVY_LEVEL then armor = "heavy"
        elseif prof:find("MediumArmor", 1, true) then armor = "medium"
        else armor = "light" end
    else
        armor = "light"
    end
    if not (prof:find("Armor", 1, true) or base <= 1) then
        armor = nil                                                  -- no armor prof: native AC
    end
    -- class kit extras (v3.28): staff for casters, shields for Shields-proficient
    -- melees (tank slot always, other melee ~55%; caster/ranged hands stay in kit).
    local extras
    if staffed then
        extras = { (tier == 4 and base >= 4) and STAFF_1 or STAFF_0 }
    elseif role == "melee" and prof:find("Shields", 1, true)
           and rand(1, 100) <= (entry.role == "tank" and 100 or 55) then
        extras = { (tier == 4) and SHIELD_1 or SHIELD_BASIC[rand(1, #SHIELD_BASIC)] }
    end
    return weapon, armor, extras
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
    local weapon, armor, extras = equipmentFor(entry, base, tier)
    -- no armor (innate/native AC) -> still give a random garment so the mob isn't
    -- naked; jackpot tier gets the rich wardrobe (owner: "make it interesting")
    local clothes = nil
    if not armor then
        clothes = (tier == 4) and T_CLOTHES_RICH or T_CLOTHES_COMMON
    end
    local tag = groupTier and ("(group " .. groupTier .. (isBoss and " boss" or "") .. ")") or "(roll)"
    log("equip: tier", tier, tag, "role", weaponRoleFor(entry),
        weapon or (extras and "kit-only") or "innate",
        "+", armor and (armor .. "-armor") or (clothes and "clothes" or "native-armor"),
        "+", extras and (#extras .. " extra") or "no extra",
        "prof", entry.prof or (entry.unarmed and "innate" or "-"))
    -- v3.37: GenerateTreasure failures must be LOUD (the armor tables failed silently
    -- for dozens of versions - bare pcalls hid it)
    if weapon then
        local okT, errT = pcall(Osi.GenerateTreasure, created, weapon, base, created)
        if not okT then log("equip: GenerateTreasure FAILED", weapon, "-", tostring(errT)) end
    end
    if armor then
        local band = ARMOR_BANDS[armor]
        local pick = band[rand(1, #band)]
        local okA, errA = pcall(Osi.TemplateAddTo, pick, created, 1, 0)
        if okA then log("equip: armor", pick:match("^[%w_]+") .. " (" .. armor .. ")")
        else log("equip: armor TemplateAddTo FAILED", pick, "-", tostring(errA)) end
    end
    if clothes then
        local okT, errT = pcall(Osi.GenerateTreasure, created, clothes, base, created)
        if not okT then log("equip: GenerateTreasure FAILED", clothes, "-", tostring(errT)) end
    end
    if extras then
        for _, t in ipairs(extras) do
            pcall(Osi.TemplateAddTo, t, created, 1, 0)
        end
        log("equip: class kit", #extras, "template(s) on", created)
    end
    -- class-appropriate support slot (v3.28: the ranged bow is now the PRIMARY weapon
    -- via equipmentFor, no separate bow roll here - the special arrows need it)
    local role, band, support = supportSlot(entry, groupTier, tier)
    if support then
        for _, s in ipairs(support) do
            pcall(Osi.TemplateAddTo, s[1], created, s[2], 0)
        end
        log("support:", role, "band", band, #support, "item rolls on", created)
    end
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
    -- rolls but no visible weapons/armor on the mobs); staff counts as the weapon
    local probe = weapon or (extras and (extras[1] == STAFF_0 or extras[1] == STAFF_1))
    if probe then
        pcall(Ext.Timer.WaitFor, 1500, function ()
            local okW, w = pcall(Osi.GetEquippedWeapon, created)
            log("arm check:", (okW and w and w ~= "") and tostring(w) or "NO WEAPON EQUIPPED",
                "on", created)
        end)
    end
    probeGear(created, armor ~= nil)
end

-- v3.39 ONE-SHOT DIAGNOSTIC (owner: ARM_* equips per log, but every team member renders
-- the same blue robe - weapon art shows, armor art does not; our pipeline provably adds
-- no garments for armored mobs, so WHERE does the robe ride in?). Dumps the full
-- Equipment + Inventory components of the first 3 armored spawns to profile file
-- Chaos_gear_dump.txt (file, not main log - owner hates spam). Flip PROBE_GEAR=false
-- once the robe mystery is solved.
local PROBE_GEAR = true
local GEAR_FILE = "Chaos_gear_dump.txt"
local GEAR_DUMP = ""
local gearProbes = 0
function probeGear(mob, armored)
    if not PROBE_GEAR or not armored or gearProbes >= 3 then return end
    gearProbes = gearProbes + 1
    pcall(Ext.Timer.WaitFor, 2000, function ()
        local okE, ent = pcall(Ext.Entity.Get, mob)
        if not okE or not ent then log("gear: entity gone", mob) return end
        local chunk = "=== mob " .. tostring(mob) .. " (probe " .. gearProbes .. ") ===\n"
        for _, comp in ipairs({ "Equipment", "Inventory", "OutfitOverride" }) do
            local okC, c = pcall(function () return ent[comp] end)
            if okC and c ~= nil then
                local okD, d = pcall(Ext.DumpExport, c)
                chunk = chunk .. "-- " .. comp .. " --\n"
                chunk = chunk .. (okD and tostring(d) or ("dump threw: " .. tostring(d))) .. "\n"
            else
                chunk = chunk .. "-- " .. comp .. ": NIL --\n"
            end
        end
        GEAR_DUMP = GEAR_DUMP .. chunk .. "\n"
        local okIO, eIO = pcall(Ext.IO.SaveFile, GEAR_FILE, GEAR_DUMP)
        log("gear: dumped", tostring(mob):sub(1, 8), okIO and "ok" or ("SAVE FAILED " .. tostring(eIO)),
            "-> " .. GEAR_FILE)
    end)
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
