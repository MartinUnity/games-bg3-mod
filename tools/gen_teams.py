#!/usr/bin/env python3
"""Generate CHAOS humanoid team content (iteration 3): stat entries + derived root
templates + the Lua template lookup.

Design (from iterations 1-2, EO/UtutsCoreLibrary precedents):
- stat entries  CHAOST_<role>_L<level>  (72: 6 roles x 12 levels) with the role's
  UCL progression TABLES (class + subclass + style + features + ASI; the engine
  applies nodes up to the character's level), role stat template, HP curve,
  proficiencies, casting ability.
- derived root templates (ParentTemplateId = vanilla humanoid donor, like EO's):
  tiny override nodes with Stats -> our entry + LevelOverride + SpellSet
  CommonNPCActions. File: Public/ChaosReinforcements/RootTemplates/ChaosTeams.lsx
  (one file, many GameObjects - EO ships one file per template, but the region
  structure is what matters; same layout as vanilla _merged).
- Server/TeamTemplates.lua: CHAOS_TEAMS[role][level] = { "Name_<mapkey>", ... }
  for the Lua team composer.

Usage: python3 tools/gen_teams.py
"""
import pathlib
import uuid
import os
import random

# v3.46: spell-kit rolls. CHAOS_SEED=<int> makes them reproducible (tests); by
# default every regen re-rolls every caster's whole spell stack (owner wants the
# chaos: lvl-6 dwarf cleric != lvl-5 dwarf cleric + 1 spell).
if os.environ.get("CHAOS_SEED"):
    random.seed(int(os.environ["CHAOS_SEED"]))

OUT_STATS = pathlib.Path("mods/chaos-reinforcements/Public/ChaosReinforcements/"
                         "Stats/Generated/Data/CHAOS_Teams.txt")
OUT_TEMPLATES = pathlib.Path("mods/chaos-reinforcements/Public/ChaosReinforcements/"
                             "RootTemplates/ChaosTeams.lsx")
OUT_LUA = pathlib.Path("mods/chaos-reinforcements/Mods/ChaosReinforcements/"
                       "ScriptExtender/Lua/Server/TeamTemplates.lua")

XP_CURVE = "206b753f-bc3b-46af-98b9-0c711d98c678"   # vanilla goblin XP curve

# UCL progression TABLE guids (verified against the installed UtutsCoreLibrary)
# v3.44 additions extracted from the UCL pak's Progressions.lsx (name scan) and
# vanilla Shared pak tables for monk (UCL has no monk). Contents forensics:
# /tmp/opencode/v344_prog_notes.md (subagent dump).
UCL = {
    "Fighter": "1c4c6006-0b49-4dac-954a-5a83b815a695",
    "Barbarian": "ae343448-6fce-40b2-8eb7-b5e4316dff58",
    "Ranger": "06762adc-24d9-4689-8d09-8dfa9182dd4b",
    "Wizard": "7eefd2dd-5aab-4349-9c22-7c38afe133c4",
    "Cleric": "4577e872-7f55-448b-a6c4-bb3f5a3738b6",
    "Bard": "ef851978-e229-4b50-afd2-8a4e80c5b4a1",
    "Champion": "658e5cdc-c04a-47df-9edd-8c1eec8a7ec2",
    "Berserker": "5be7823a-4611-4bb5-a2ba-cc60be806378",
    "Hunter": "7839dbea-69da-441f-9668-f91a904ee6b5",
    "EvocationSchool": "35539b35-76aa-4da1-8b56-cb124497eca1",
    "LightDomain": "55d4818d-3191-42ef-9719-a66b4ff29811",
    "SwordsCollege": "2375ac5d-f13b-4a8b-8f1d-da0141cc9b79",
    "style2_defence": "a9b4a6ab-736c-4727-99f7-9ee4444fb8e1",
    "style1_archery": "0ed759fc-4856-4568-9405-929d731899dd",
    "ActionSurge_Melee": "e6be4ef3-c002-425e-903e-8595df5c5049",
    "feat_sharpshooter": "85ffe605-411e-4f1b-b40b-ebbf2a5372f3",
    "asi_str": "4f22dd35-542c-4aa0-a790-b6c93c3e252f",
    "asi_dex": "defed003-fb89-41b8-b59f-a57dae9e50de",
    "asi_int": "38416c1a-9b9c-4d62-a2a2-1a9853fcb592",
    "asi_wis": "181bb485-b676-4e66-8a46-3f7aa1e31415",
    "asi_cha": "b40ab293-676f-41d4-919e-bf1f36643548",
    # ---- v3.44 new class chains (UCL unless noted) ----
    "Druid": "d3af8a04-c768-487d-bf32-13828fd51f09",
    "CircleOfTheMoon": "ac4510fc-ceee-4a0a-873d-b0f7b8808d94",
    "CircleOfTheSpores": "a3842d6e-15ba-4ca9-8ea9-6334daa8e566",
    "Warlock": "f34419b6-a50a-46c2-9eb9-28264fd71c55",
    "OtherworldlyFiend": "9c4763f3-c485-4572-9991-b0f5385d61ce",
    "GreatOldOne": "ffa87dcf-3390-437c-8075-74c2ad37e3e2",
    "Archfey": "a80c1ba4-e6a7-46fe-9bc8-d8fbfdf0866b",
    "Sorcerer": "e93883b2-b593-4101-9c97-d6b8c454c053",
    "WildMagic": "a84b7bc9-88f4-4861-9bcb-77a2fd17cd12",
    "Paladin": "14599945-cb3d-461a-9937-8691ac8923ed",
    "Ancients": "ba5b3a18-3c5f-4fd0-977c-701653edfd36",
    "Rogue": "4356e226-3b97-46c6-9e16-2b8f302ab42f",
    "GloomStalker": "7dcf10d4-1137-4642-a623-c450c06ab1a9",
    "EldritchBlaster1": "2919cea5-a0c1-46e8-9774-4c9f03ba3d5f",
    "EldritchBlaster2": "4b87365a-69a3-4863-8d2f-4f30f630cbeb",
    "style2_gwf": "69eae9b0-d17e-429c-9b61-03145d645d0b",      # GreatWeaponFighting (lvl2)
    # v3.45 VERDICT (owner: Duelist had NO Two Weapon Fighting): UCL_Generic_DualWielder
    # only grants BonusAC@4 + Dex+2@8 - the TWF passive lives in these style tables.
    "style2_twf": "5b91e529-a3bb-4fcd-bd59-de914b46f2fa",      # TwoWeaponFighting (lvl2)
    "prog_twohander": "b01ff88f-ca24-4d55-b9ba-1b8b835cc2b6",  # GWM BonusDamage+BonusAttack
    "feat_dualwielder": "13abbf29-3a70-4854-805d-c9ede2147adb",# DualWielder feat + TWF @2/3
    # UCL has no plain Monk; UCL_FourElements_Thief is an NPC-safe full monk build
    # (Ki, UnarmoredDefense_Monk, MartialArts, Flurry unlock, DeflectMissiles,
    # ExtraAttack, Evasion) with a Thief garnish at 7-9 (notes file forensics).
    "FourElementsThief": "3c756b75-579d-4a6e-9248-4a660261c524",
}

PROF_MARTIAL = ("SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;HeavyArmor;"
                "Shields;Battleaxes")
PROF_LIGHT = "SimpleWeapons;LightArmor"
PROF_MARTIAL_SH = ("SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;HeavyArmor;Shields")

# ---- v3.44 CLASS BUILD FRAMEWORK (owner spec) --------------------------------
# Team slots roll CLASS BUILDS instead of one fixed class each. Every build is a
# full stat-block recipe (progression chain + stats + kit + equip directive).
# Banned-until-gated classes (owner: they one-shot players below lvl ~5):
# monk/rogue/sorcerer/paladin/warlock/hexblade have min=5.
# wp (equip directive, read by Equip.lua):
#   "table"     legacy treasure-table roll (role-driven)
#   "twohanded" guaranteed 2h martial kit, no shield
#   "dual"      two LIGHT melee weapons (off-hand gets one), no shield, light armor only
#   "javelins"  melee kit + 3-8 javelins (thrower barbarian)
#   "1h_shield" HEAL_1H kit + shield (paladin/hexblade/healers)
#   "staff"     quarterstaff kit (casters/druids)
#   "unarmed"   no weapons, no armor (monk; FlurryOfBlows from the table)
BUILDS = {
    # ---- tank slot ----
    "fighter_brute": dict(  # the big brawny 2h: GreatWeaponFighting + GreatWeaponMaster
        label="Guardian", vis="melee", wp="twohanded", min=1,
        prog=["Fighter", "prog_twohander", "style2_gwf", "ActionSurge_Melee", "asi_str"],
        stats={"STR": 16, "DEX": 10, "CON": 15, "INT": 8, "WIS": 12, "CHA": 8},
        hp=lambda lvl: 10 + 9 * lvl, prof=PROF_MARTIAL_SH, armor=14, armor_type="Heavy",
        cast=None),
    "fighter_dual": dict(   # the agile dex dual-wielder: TWF + Dual Wielder, LIGHT armor only
        # (v3.45: TWF comes from style2_twf - the DualWielder feat table alone does NOT
        # grant it, owner-verified in-game)
        label="Duelist", vis="melee", wp="dual", min=1,
        prog=["Fighter", "style2_twf", "feat_dualwielder", "asi_dex"],
        stats={"STR": 10, "DEX": 16, "CON": 14, "INT": 8, "WIS": 12, "CHA": 8},
        hp=lambda lvl: 10 + 9 * lvl, prof=PROF_MARTIAL_SH, armor=13, armor_type="Light",
        cast=None),
    "paladin": dict(        # lvl5+; 1h + shield + CHA smites
        label="Paladin", vis="melee", wp="1h_shield", min=5,
        prog=["Paladin", "Ancients", "asi_cha"],
        stats={"STR": 15, "DEX": 10, "CON": 14, "INT": 8, "WIS": 10, "CHA": 16},
        hp=lambda lvl: 10 + 9 * lvl, prof=PROF_MARTIAL_SH, armor=14, armor_type="Heavy",
        cast="Charisma"),
    # ---- melee_dps slot ----
    "barb_brute": dict(     # 75% of barbarians: the usual 2h crazy brute
        label="Berserker", vis="melee", wp="twohanded", min=1,
        prog=["Barbarian", "Berserker", "asi_str"],
        stats={"STR": 16, "DEX": 13, "CON": 14, "INT": 8, "WIS": 10, "CHA": 8},
        hp=lambda lvl: 8 + 9 * lvl, prof=PROF_MARTIAL_SH, armor=12, armor_type="Medium",
        cast=None),
    "barb_thrower": dict(   # 25% of barbarians: javelin thrower (3-8 javelins)
        label="Sky Guardian", vis="melee", wp="javelins", min=1,
        prog=["Barbarian", "Berserker", "asi_dex"],
        stats={"STR": 14, "DEX": 16, "CON": 14, "INT": 8, "WIS": 10, "CHA": 8},
        hp=lambda lvl: 8 + 9 * lvl, prof=PROF_MARTIAL_SH, armor=12, armor_type="Medium",
        cast=None),
    "monk": dict(           # lvl5+; unarmed (FourElementsThief table grants Ki/Flurry/Unarmored)
        label="Monk", vis="melee", wp="unarmed", min=5,
        prog=["FourElementsThief"],
        stats={"STR": 12, "DEX": 17, "CON": 14, "INT": 8, "WIS": 14, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof="", armor=10 + 3, armor_type="None",
        cast=None),
    "rogue": dict(          # lvl5+; finesse pair, light armor
        # (v3.45: TWF passive via boost - the fighter style tables would be a Fighter
        # context; UnlockPassive is the same passive, and rogues are lvl5+ gated anyway)
        label="Rogue", vis="melee", wp="dual", min=5,
        prog=["Rogue", "GloomStalker", "asi_dex"],
        stats={"STR": 10, "DEX": 17, "CON": 13, "INT": 10, "WIS": 11, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof="SimpleWeapons;MartialWeapons;LightArmor;Shields",
        armor=13, armor_type="Light", cast=None,
        boosts=["UnlockPassive(FightingStyle_TwoWeaponFighting)"]),
    "hexblade": dict(       # 25% of warlocks: melee using Charisma for hit/damage
        label="Hexblade", vis="melee", wp="1h_shield", min=5, cast="Charisma",
        prog=["Warlock", "OtherworldlyFiend", "asi_cha"],
        stats={"STR": 12, "DEX": 12, "CON": 14, "INT": 8, "WIS": 8, "CHA": 17},
        hp=lambda lvl: 8 + 7 * lvl, prof=PROF_MARTIAL_SH, armor=13, armor_type="Medium",
        # SHILLELAGH precedent grammar (vanilla Status_BOOST): melee uses SpellCastingAbility
        boosts=["WeaponAttackRollAbilityOverride(SpellCastingAbility)"]),
    "druid_shifter": dict(  # 75% of druid dps: shapeshifter (CircleOfTheMoon)
        label="Shapechanger", vis="melee", wp="staff", min=2,
        prog=["Druid", "CircleOfTheMoon", "asi_wis"],
        stats={"STR": 12, "DEX": 12, "CON": 14, "INT": 10, "WIS": 16, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof="SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;Shields",
        armor=12, armor_type="Medium", cast="Wisdom"),
    # ---- ranged slot ----
    "ranger": dict(
        label="Hunter", vis="ranged", wp="table", min=1,
        prog=["Ranger", "Hunter", "style1_archery", "feat_sharpshooter", "asi_dex"],
        stats={"STR": 10, "DEX": 16, "CON": 13, "INT": 10, "WIS": 14, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof=PROF_MARTIAL_SH, armor=12, armor_type="Medium",
        cast="Wisdom"),
    # ---- healer slot: 75% cleric / 25% druid (owner) ----
    "cleric": dict(
        label="Cleric", vis="caster", wp="1h_shield", min=1,
        prog=["Cleric", "LightDomain", "asi_wis"],
        stats={"STR": 12, "DEX": 12, "CON": 14, "INT": 8, "WIS": 16, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof=PROF_MARTIAL_SH, armor=12, armor_type="Medium",
        cast="Wisdom"),
    "druid_healer": dict(
        label="Druid", vis="caster", wp="1h_shield", min=1,
        prog=["Druid", "asi_wis"],
        stats={"STR": 11, "DEX": 12, "CON": 14, "INT": 8, "WIS": 16, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof="SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;Shields",
        armor=12, armor_type="Medium", cast="Wisdom"),
    # ---- caster slot ----
    "wizard": dict(
        label="Wizard", vis="caster", wp="staff", min=1,
        prog=["Wizard", "EvocationSchool", "asi_int"],
        stats={"STR": 8, "DEX": 14, "CON": 13, "INT": 16, "WIS": 10, "CHA": 8},
        hp=lambda lvl: 6 + 5 * lvl, prof=PROF_LIGHT, armor=10, armor_type="Cloth",
        cast="Intelligence"),
    "sorcerer": dict(       # lvl5+
        label="Sorcerer", vis="caster", wp="staff", min=5,
        prog=["Sorcerer", "WildMagic", "asi_cha"],
        stats={"STR": 8, "DEX": 14, "CON": 14, "INT": 10, "WIS": 10, "CHA": 16},
        hp=lambda lvl: 6 + 5 * lvl, prof=PROF_LIGHT, armor=10, armor_type="Cloth",
        cast="Charisma"),
    "warlock": dict(        # lvl5+; 75% of warlocks are this caster
        label="Warlock", vis="caster", wp="staff", min=5,
        prog=["Warlock", "GreatOldOne", "asi_cha"],
        stats={"STR": 8, "DEX": 12, "CON": 13, "INT": 12, "WIS": 8, "CHA": 17},
        hp=lambda lvl: 8 + 6 * lvl, prof=PROF_LIGHT, armor=10, armor_type="Cloth",
        cast="Charisma"),
    "druid_caster": dict(   # 25% of druid dps: caster variant
        label="Druid", vis="caster", wp="staff", min=2,
        prog=["Druid", "CircleOfTheSpores", "asi_wis"],
        stats={"STR": 10, "DEX": 12, "CON": 14, "INT": 12, "WIS": 16, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof="SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;Shields",
        armor=12, armor_type="Medium", cast="Wisdom"),
    # ---- wildcard slot ----
    "bard": dict(
        label="Bard", vis="melee", wp="table", min=1,
        prog=["Bard", "SwordsCollege", "asi_cha"],
        stats={"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 12, "CHA": 16},
        hp=lambda lvl: 8 + 6 * lvl, prof=PROF_MARTIAL_SH, armor=11, armor_type="Light",
        cast="Charisma"),
}

# slot -> weighted build list; builds whose min level exceeds the wave level are
# dropped from the roll (renormalized). Barbarian 75/25 split (brute/thrower),
# druid dps 75/25 shifter/caster, warlock 75/25 caster/hexblade (owner spec).
SLOT_VARIANTS = {
    "tank":      [("fighter_brute", 50), ("fighter_dual", 30), ("paladin", 20)],
    "melee_dps": [("barb_brute", 23), ("barb_thrower", 8), ("druid_shifter", 15),
                  ("monk", 15), ("rogue", 15), ("hexblade", 12)],
    "ranged":    [("ranger", 100)],
    "healer":    [("cleric", 75), ("druid_healer", 25)],
    "caster":    [("wizard", 40), ("druid_caster", 15), ("sorcerer", 15), ("warlock", 15),
                  ("hexblade", 15)],
    "wildcard":  [("bard", 100)],
}

# ---- v3.38 SPELL KITS (owner: mobs had class features but cast NOTHING - cleric
# meleeing, ranger never marking). Vanilla census (subagent, 2026-11-02): Character
# entries have no spell-list token; generic mobs get spells from root-template
# SpellSet attr, named casters grant via UnlockSpell(...) + slots via
# ActionResource(SpellSlot,count,level) boosts (precedents: Goblin_Cleric
# DefaultBoosts, Roland's DEN_Rolan_DefaultSpells passive, TWN_Githyanki_Warlock).
# We take the proven stats-only channel: per-entry DefaultBoosts (our CHAOST entries
# are per-level, so gating is direct). ALL spell ids validated against vanilla
# Spell_*.txt (no I_ARM_*_Body-style silent drops); _Human/_Humanoid define no
# DefaultBoosts, so adding ours overrides nothing. Slot curves = vanilla NPC_Cleric/
# player tables; UnlockSpell form from Passive.txt:808 (spell,,,,ability).
FULL_SLOTS = {  # cleric/wizard curve: level -> {slot_level: count}
    1: {1: 2}, 2: {1: 3}, 3: {1: 4, 2: 2}, 4: {1: 4, 2: 3},
    5: {1: 4, 2: 3, 3: 2}, 6: {1: 4, 2: 3, 3: 3}, 7: {1: 4, 2: 3, 3: 3},
    8: {1: 4, 2: 3, 3: 3, 4: 1}, 9: {1: 4, 2: 3, 3: 3, 4: 2},
    10: {1: 4, 2: 3, 3: 3, 4: 2, 5: 1}, 11: {1: 4, 2: 3, 3: 3, 4: 2, 5: 1},
    12: {1: 4, 2: 3, 3: 3, 4: 2, 5: 1},
}
HALF_SLOTS = {  # ranger/bard curve
    1: {}, 2: {1: 2}, 3: {1: 3}, 4: {1: 3},
    5: {1: 4, 2: 2}, 6: {1: 4, 2: 2}, 7: {1: 4, 2: 3}, 8: {1: 4, 2: 3},
    9: {1: 4, 2: 3, 3: 2}, 10: {1: 4, 2: 3, 3: 2},
    11: {1: 4, 2: 3, 3: 2, 4: 1}, 12: {1: 4, 2: 3, 3: 2, 4: 1},
}
# ---- v3.46 ROLLED SPELL KITS (owner design: docs/spells-categories.md) --------
# Caster builds roll their known spells at GENERATION time so every level - and
# every regen - shows a different toolkit (owner: a lvl6 dwarf cleric shouldn't be
# an exact lvl5 clone +1 spell). Design: walk spell levels 1..max; for each slot,
# cycle the owner's priority GROUPS in order (prio1 group, prio2, prio3, loop back
# once all groups were used); within a group pick weighted by the table's intra-group
# Pri column (Pri1 ~6x, Pri2 ~3x, Pri3 ~1x). One spell known per slot; picks are
# without replacement. Set CHAOS_SEED=<int> for reproducible rolls; default = fresh
# random every regen.
# ids validated against vanilla Spell_*.txt from Shared.pak+Gustav.pak+GustavX.pak
# (covers Shared/SharedDev/Gustav/GustavDev/Honour layers, 2026-11-03 census):
# Mass Cure Wounds = Target_CureWounds_Mass, Mass Healing Word = Shout_HealingWord_Mass,
# Command (NPC AI entry) = Target_Command_Halt_NPC, Spiritual Weapon = MAG_ variant,
# Flame Strike/Insect Plague/Ice Storm/Blight/Ice Knife/TollTheDead all EXIST.
# NOT in vanilla (dropped): Conjure Minor Elemental (folded into the Conjure
# Elemental container; only a MudMephit claw ref exists).
SPELL_CATS = {
    "cleric": [
        ("healing", [("Target_CureWounds", 1, 1), ("Target_HealingWord", 1, 2),
                     ("Shout_HealingWord_Mass", 3, 1), ("Target_CureWounds_Mass", 5, 1),
                     ("Target_Heal", 6, 1)]),
        ("buff", [("Target_Bless", 1, 1), ("Target_ShieldOfFaith", 1, 2),
                  ("Target_WardingBond", 2, 2), ("Shout_Aid", 2, 3),
                  ("Target_FreedomOfMovement", 4, 3)]),
        ("summon_debuff_damage",
         [("Target_HoldPerson", 2, 1), ("Target_MAG_SpiritualWeapon", 2, 1),
          ("Target_Bane", 1, 2), ("Projectile_GuidingBolt", 1, 2),
          ("Target_Command_Halt_NPC", 1, 2), ("Shout_SpiritGuardians", 3, 2),
          ("Target_FlameStrike", 5, 2), ("Target_InsectPlague", 5, 2)]),
    ],
    "druid": [
        ("healing", [("Target_CureWounds", 1, 1), ("Target_HealingWord", 1, 2),
                     ("Target_CureWounds_Mass", 5, 1), ("Target_Heal", 6, 1)]),
        ("buff_summon", [("Target_FlamingSphere", 2, 2),
                         ("Target_ConjureWoodlandBeings", 4, 2),
                         ("Target_ConjureElemental_Elemental_Fire_NPC", 5, 2),
                         ("Target_FreedomOfMovement", 4, 3)]),
        ("debuff_damage",
         [("Projectile_IceKnife", 1, 1), ("Target_HeatMetal", 2, 1),
          ("Target_Moonbeam", 2, 1), ("Target_CallLightning", 3, 1),
          ("Target_IceStorm", 4, 1), ("Target_HoldPerson", 2, 2),
          ("Zone_Thunderwave", 1, 2), ("Target_InsectPlague", 5, 2),
          ("Target_SpikeGrowth", 2, 3), ("Target_Blight", 5, 3)]),
    ],
}
CANTRIPS = {
    "cleric": [("Target_TollTheDead", 1), ("Target_SacredFlame", 2)],
    "druid": [("Target_ThornWhip", 1), ("Projectile_PoisonSpray", 2)],
}
# build -> (casting ability, slot curve, SPELL_CATS key)
ROLL_KITS = {
    "cleric": ("Wisdom", FULL_SLOTS, "cleric"),
    "druid_healer": ("Wisdom", FULL_SLOTS, "druid"),
    "druid_shifter": ("Wisdom", FULL_SLOTS, "druid"),
    "druid_caster": ("Wisdom", FULL_SLOTS, "druid"),
}
PRI_WEIGHT = {1: 6, 2: 3, 3: 1}

def _wpick(pool):
    w = [PRI_WEIGHT.get(pri, 1) for (_, _, pri) in pool]
    return pool.pop(random.choices(range(len(pool)), weights=w)[0])

def roll_spell_kit(catkey, curve, lvl):
    ids = []
    # cantrips: 2 known, +1 at char lvl 4 and 10 (5e progression), own Pri weights
    pool = [(sid, 0, pri) for (sid, pri) in CANTRIPS[catkey]]
    ncan = min(2 + (1 if lvl >= 4 else 0) + (1 if lvl >= 10 else 0), len(pool))
    for _ in range(ncan):
        ids.append(_wpick(pool)[0])
    # one spell known per slot, cycling the priority groups per spell level
    cats = SPELL_CATS[catkey]
    for slvl in sorted(curve.get(lvl, {})):
        pools = [[(sid, sl, pri) for (sid, sl, pri) in spells if sl == slvl]
                 for (_, spells) in cats]
        ci, n = 0, curve[lvl][slvl]
        for _ in range(n):
            for attempt in range(len(cats)):
                c = (ci + attempt) % len(cats)
                if pools[c]:
                    ids.append(_wpick(pools[c])[0])
                    ci = c + 1
                    break
            else:
                break                       # spell level exhausted across all groups
    return ids

# build -> (casting ability, slot curve, [(min char level, spell stats id), ...])
# STATIC kits (owner's category lists cover cleric+druid so far; full/half/1-3
# casters come later - these stay fixed-order until then). All ids validated.
WARLOCK_SLOTS = {  # warlock pact magic: few slots, upcast high
    1: {}, 2: {1: 1}, 3: {1: 2}, 4: {1: 2}, 5: {2: 1}, 6: {2: 1},
    7: {2: 1}, 8: {2: 1}, 9: {3: 1}, 10: {3: 1}, 11: {3: 1}, 12: {3: 1},
}
SPELLS = {
    "wizard": ("Intelligence", FULL_SLOTS, [
        (1, "Projectile_FireBolt"), (1, "Projectile_AcidSplash"),  # cantrips
        (1, "Projectile_MagicMissile"), (1, "Zone_Thunderwave"), (1, "Target_MageArmor"),
        (3, "Projectile_ScorchingRay"), (3, "Target_Web"),
        (3, "Projectile_ChromaticOrb_Acid"), (5, "Shout_MirrorImage")]),
    "sorcerer": ("Charisma", FULL_SLOTS, [     # same blast package, CHA-powered
        (1, "Projectile_FireBolt"), (1, "Projectile_AcidSplash"),  # cantrips
        (1, "Projectile_MagicMissile"), (1, "Zone_Thunderwave"),
        (3, "Projectile_ScorchingRay"), (3, "Projectile_ChromaticOrb_Acid"),
        (5, "Shout_MirrorImage")]),
    "warlock": ("Charisma", WARLOCK_SLOTS, [   # eldritch blast core (owner refs pending)
        (1, "Projectile_EldritchBlast"),       # cantrip
        (2, "Target_Hex"),
        (5, "Projectile_ChromaticOrb_Acid")]),
    "hexblade": ("Charisma", WARLOCK_SLOTS, [  # melee CHA warlock; staff blast backup
        (1, "Projectile_EldritchBlast"),       # cantrip
        (2, "Target_Hex")]),
    "paladin": ("Charisma", HALF_SLOTS, [      # smite ladder (smites burn own slots)
        (1, "Target_SacredFlame"),             # cantrip
        (2, "Target_Smite_Divine"), (3, "Target_Smite_Searing"),
        (5, "Target_Smite_Thunderous")]),
    "ranged": ("Wisdom", HALF_SLOTS, [
        (2, "Target_HuntersMark"), (2, "Target_Barkskin"),
        (5, "Target_SpikeGrowth"), (5, "Target_Goodberry"),
        (7, "Shout_PassWithoutTrace")]),
    "bard": ("Charisma", HALF_SLOTS, [
        (1, "Target_ViciousMockery"),         # cantrip
        (2, "Target_HealingWord")]),
}

# vanilla humanoid donors (ParentTemplateId): proven-spawnable player-race templates.
# ⚠️ 2026-11-02 lesson: tiefling_m/gith_m first carried RUNTIME INSTANCE guids copied
# from an equip-log line ("TemplateName_<instance-guid>", not the template MapKey) -
# dangling ParentTemplateId => invisible body + fallback portrait (owner report:
# 2-person tiefling team invisible with shadowed human-face icon). Donors are now
# validated against the live root-template dump at generation time (see main()).
DONORS = [
    ("human_m", "BASE_Humans_Male_Aggressive_e0eaf4bd-1c00-4947-aaa1-b1801fbfadfe"),
    ("elf_f", "BASE_Elves_Female_Drow_0bd09fae-e858-4a6e-8d1a-72dd0eb4cb60"),
    ("halfelf_m", "BASE_HalfElves_Male_Drow_9335e9a8-ad69-4180-b286-6e86c8e444a9"),
    ("halfling_m", "BASE_Halflings_Male_Crowd_Refugee_A_0fc1e8e9-18e2-407f-8ee2-4de350f15b5f"),
    ("dwarf_f", "Dwarves_Female_Duergar_Guard_Melee_94f7da13-e289-494b-9889-166614e3fc6f"),
    ("tiefling_m", "Tieflings_Male_Asmodeus_Guard_Caster_806815fc-a6ae-4ad0-b928-10c189597abb"),
    ("gith_m", "Githyanki_Male_Guard_Caster_49567bbf-6d5c-4685-80ce-cde321572841"),
    # v3.29 race-coherence donors (owner: goblin fights spawned HUMAN reinforcements -
    # odd mix; CHAOST squads now pick a donor race matching the fight's dominant enemy
    # race). All donor ids are validated against the live dump at generation time.
    ("goblin_m", "BASE_Goblins_Male_fb1af356-55c0-4b63-8418-353170bfeb75"),
    ("goblin_f", "BASE_Goblins_Female_9629600b-2e80-4862-9ddb-1ae8e2ee824c"),
    ("halforc_m", "BASE_HalfOrcs_Male_0350f048-11f5-42fe-8399-228e419f4789"),
    ("halforc_f", "BASE_HalfOrcs_Female_Guard_01bb9053-324a-41e9-8c44-7717f070d9f2"),
]

MAX_LEVEL = 12

# v3.41 BAKED-ARMOR LOOK: the client does NOT attach body-armor item art to NPC bodies
# (only hand props -> weapons showed, armor never did; AC was always correct). Vanilla
# NPCs "wear" gear through their per-template CharacterVisualResourceID body mesh
# (Guard_* templates carry armored bodies; our BASE_* donors are civilian/naked-ish).
# Override CVRID per CHAOST template. Harvested from vanilla root templates' own CVRIDs
# (guard/ranger/caster gear-styled bodies; HalfOrcs live in SharedDev _merged).
# Backlog: goblin _Tier2 bodies (fb5c6d24/66a0dc01/b1825b38) for tier>=3 squads.
# (v3.44: build cfgs carry their own "vis" class - melee/ranged/caster.)
RACE_VISUALS = {
    "human_m":    {"melee": "f70e62b1-4c33-df8a-674d-3533518224bd",
                   "ranged": "67fb31a5-dcd6-d719-61a9-2a1e527617f1",
                   "caster": "f70e62b1-4c33-df8a-674d-3533518224bd"},
    "elf_f":      {"melee": "04a453b4-8195-25c7-da7e-dc82621ad792",
                   "ranged": "8334eb6d-7aa5-1543-8af5-c65adf8adb65",
                   "caster": "dabc3b41-ab12-c480-7deb-31991fcff959"},
    "halfelf_m":  {"melee": "eaf54c93-b352-2b0d-4826-a8612b89b277",
                   "ranged": "238c39bf-cc0b-0b4f-dae2-b9e1997243bf",
                   "caster": "f87255bc-40a8-a7ec-efd4-a650181719d9"},
    "halfling_m": {"melee": "e682cca7-3c57-475a-66a2-e7e4d1726afe",
                   "ranged": "9e36debd-d0de-08bc-dac8-884d75c8f078",
                   "caster": "91d0c768-02d0-054d-ed11-231ddb33292e"},
    "dwarf_f":    {"melee": "ef5208d8-aef6-a411-77ef-fbf4139b1006",
                   "ranged": "d2c289c6-8c97-3f1d-a489-61116f47403a",
                   "caster": "ef5208d8-aef6-a411-77ef-fbf4139b1006"},
    "tiefling_m": {"melee": "351d13d4-a4de-0dd0-24df-3a194285c7e6",
                   "ranged": "351d13d4-a4de-0dd0-24df-3a194285c7e6",
                   "caster": "a178a41d-05c3-3bc8-4879-15d2effe3300"},
    "gith_m":     {"melee": "c217f7f3-ea9c-8a64-a658-c840cf351768",
                   "ranged": "b1e09345-43ff-f39e-aa5c-47a8500abca6",
                   "caster": "c217f7f3-ea9c-8a64-a658-c840cf351768"},
    "goblin_m":   {"melee": "fd51396f-20ee-e253-0b8e-9392b4ad5dd3",
                   "ranged": "d1e40d4e-b212-5887-cfab-c157e1db04a4",
                   "caster": "90dc73a3-5072-c4b1-2bab-a6610289d8b7"},
    "goblin_f":   {"melee": "e0e4ca2d-532b-76a1-e20f-ab57cdd243fd",
                   "ranged": "ebad5850-ddf4-0a35-0205-c62e0d8534a9",
                   "caster": "6a11ddfa-cf03-b126-a05f-2fa7a7a121f7"},
    "halforc_m":  {"melee": "815f28c9-17ff-5e92-b14b-9c28ca7ad13e",
                   "ranged": "815f28c9-17ff-5e92-b14b-9c28ca7ad13e",
                   "caster": "815f28c9-17ff-5e92-b14b-9c28ca7ad13e"},
    "halforc_f":  {"melee": "2572d868-df2e-47ae-12d3-f7c159bf0339",
                   "ranged": "2572d868-df2e-47ae-12d3-f7c159bf0339",
                   "caster": "2572d868-df2e-47ae-12d3-f7c159bf0339"},
}


DUMP = pathlib.Path("/home/martin/.local/share/Steam/steamapps/compatdata/1086940/"
                    "pfx/drive_c/users/steamuser/AppData/Local/Larian Studios/"
                    "Baldur's Gate 3/Script Extender/Chaos_root_templates.txt")


def validate_donors():
    """Every donor id must be a real root-template MapKey (live dump: guid\\tName).
    Guards against the 2026-11-02 instance-guid mixup: a dangling ParentTemplateId
    spawns fine but inherits NO visual (invisible mob + fallback portrait)."""
    dump = {}
    for line in DUMP.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split("\t")
        if len(parts) == 2:
            dump[parts[0]] = parts[1]
    bad = []
    for tag, donor in DONORS:
        tpl, guid = donor.rsplit("_", 1)
        if guid not in dump:
            hits = [g for g, n in dump.items() if n == tpl]
            bad.append(f"  {tag}: {guid} not a template MapKey (by name: {hits})")
        elif dump[guid] != tpl:
            bad.append(f"  {tag}: {guid} is '{dump[guid]}', wanted '{tpl}'")
    if bad:
        raise SystemExit("DONOR VALIDATION FAILED - refusing to generate:\n" + "\n".join(bad))


def main():
    validate_donors()
    stats_lines = []
    tpl_lines = []
    lookup = {b: {l: [] for l in range(1, MAX_LEVEL + 1)} for b in BUILDS}
    for build, cfg in BUILDS.items():
        prog = ";".join(UCL[k] for k in cfg["prog"])
        kit = SPELLS.get(build)
        extra_boosts = cfg.get("boosts") or []
        for lvl in range(cfg["min"], MAX_LEVEL + 1):
            entry = f"CHAOST_{build}_L{lvl}"
            stats_lines += [
                f'new entry "{entry}"',
                'type "Character"',
                'using "_Human"',
            ]
            for ab, v in cfg["stats"].items():
                # v3.37 BUGFIX: stats tokens are FULL names ("Strength"), the
                # abbreviations (STR/DEX/...) were silently dropped by the stats
                # parser -> every CHAOST mob ran on _Human base scores (owner:
                # lvl-7 ranger with 10 dex). Abbrev keys in BUILDS stay readable.
                full = {"STR": "Strength", "DEX": "Dexterity", "CON": "Constitution",
                        "INT": "Intelligence", "WIS": "Wisdom", "CHA": "Charisma"}.get(ab, ab)
                stats_lines.append(f'data "{full}" "{v}"')
            stats_lines += [
                # v3.39 HP DOUBLE-COUNT FIX: LevelOverride+Progressions make the engine
                # level the mob FOR REAL (rolled hit dice per level - owner wants that
                # dice variance kept, NOT deterministic 5e pools), so Vitality must be
                # the LVL-1 pool only; the old cumulative curve stacked UNDER the dice
                # = ~2x HP (owner: L7 barbarian 187, L5 110). Expect now ~curve +/- roll.
                f'data "Vitality" "{cfg["hp"](1)}"',
                f'data "Armor" "{cfg["armor"]}"',
                f'data "Level" "{lvl}"',
                f'data "Proficiency Group" "{cfg["prof"]}"',
                f'data "ArmorType" "{cfg["armor_type"]}"',
                f'data "Progressions" "{prog}"',
                f'data "XPReward" "{XP_CURVE}"',
            ]
            if cfg["cast"]:
                stats_lines.append(f'data "SpellCastingAbility" "{cfg["cast"]}"')
            boosts = []
            rolled = ROLL_KITS.get(build)
            if rolled:
                # v3.46: per-level ROLLED kit (docs/spells-categories.md design)
                ab, curve, catkey = rolled
                boosts += [f'ActionResource(SpellSlot,{cnt},{slvl})'
                           for slvl, cnt in sorted(curve.get(lvl, {}).items())]
                boosts += [f'UnlockSpell({sid},,,,{ab})'
                           for sid in roll_spell_kit(catkey, curve, lvl)]
            elif kit:
                ab, curve, spells = kit
                boosts += [f'ActionResource(SpellSlot,{cnt},{slvl})'
                           for slvl, cnt in sorted(curve.get(lvl, {}).items())]
                boosts += [f'UnlockSpell({sid},,,,{ab})'
                           for need, sid in spells if lvl >= need]
            boosts += extra_boosts   # v3.44 build-specific (e.g. hexblade CHA attacks)
            if boosts:
                stats_lines.append('data "DefaultBoosts" "' + ";".join(boosts) + '"')
            stats_lines.append("")
            for tag, donor in DONORS:
                mapkey = str(uuid.uuid4())
                name = f"CHAOST_{build}_L{lvl}_{tag}"
                lookup[build][lvl].append(f"{name}_{mapkey}")
                vis = RACE_VISUALS.get(tag, {}).get(cfg["vis"])
                if not vis:
                    print(f"WARN: no CVRID visual for {tag}/{build}")
                tpl_lines += [
                    '\t\t\t\t\t<node id="GameObjects">',
                    f'\t\t\t\t\t\t<attribute id="Name" type="LSString" value="{name}" />',
                    f'\t\t\t\t\t\t<attribute id="MapKey" type="FixedString" value="{mapkey}" />',
                    f'\t\t\t\t\t\t<attribute id="ParentTemplateId" type="FixedString" value="{donor.split("_")[-1]}" />',
                    f'\t\t\t\t\t\t<attribute id="Stats" type="FixedString" value="{entry}" />',
                    f'\t\t\t\t\t\t<attribute id="LevelOverride" type="int32" value="{lvl}" />',
                    '\t\t\t\t\t\t<attribute id="SpellSet" type="FixedString" value="CommonNPCActions" />',
                    '\t\t\t\t\t\t<attribute id="Type" type="FixedString" value="character" />',
                ]
                if vis:
                    tpl_lines.append(
                        f'\t\t\t\t\t\t<attribute id="CharacterVisualResourceID" type="FixedString" value="{vis}" />')
                tpl_lines.append("\t\t\t\t\t</node>")

    OUT_STATS.parent.mkdir(parents=True, exist_ok=True)
    OUT_STATS.write_text("\r\n".join(stats_lines) + "\r\n")
    OUT_TEMPLATES.parent.mkdir(parents=True, exist_ok=True)
    OUT_TEMPLATES.write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\r\n'
        "<save>\r\n\t<version major=\"4\" minor=\"0\" revision=\"9\" build=\"0\" />\r\n"
        '\t<region id="Templates">\r\n\t\t<node id="Templates">\r\n'
        "\t\t\t<children>\r\n" + "\r\n".join(tpl_lines) +
        "\r\n\t\t\t</children>\r\n\t\t</node>\r\n\t</region>\r\n</save>\r\n")

    lua = ["-- Auto-generated by tools/gen_teams.py - team spawn template ids",
           "-- v3.44: CHAOS_TEAMS is keyed by CLASS BUILD (not slot); TEAM_SLOTS maps",
           "-- a wave slot to weighted build variants (min-level gates baked in BUILDS).",
           "CHAOS_TEAMS = {"]
    for build in BUILDS:
        lua.append(f'  {build} = {{')
        for lvl in range(1, MAX_LEVEL + 1):
            ids = ", ".join(f'"{i}"' for i in lookup[build][lvl])
            lua.append(f"    [{lvl}] = {{ {ids} }},")
        lua.append("  },")
    lua.append("}")
    lua.append("TEAM_SLOTS = {")
    for slot, variants in SLOT_VARIANTS.items():
        parts = ", ".join(f'{{ build = "{b}", w = {w} }}' for b, w in variants)
        lua.append(f"  {slot} = {{ {parts} }},")
    lua.append("}")
    lua.append("BUILD_PROFS = {")
    for build, cfg in BUILDS.items():
        lua.append(f'  {build} = "{cfg["prof"]}",')
    lua.append("}")
    lua.append("BUILD_LABEL = {")
    for build, cfg in BUILDS.items():
        lua.append(f'  {build} = "{cfg["label"]}",')
    lua.append("}")
    lua.append("BUILD_WP = {")
    for build, cfg in BUILDS.items():
        lua.append(f'  {build} = "{cfg["wp"]}",')
    lua.append("}")
    lua.append("BUILD_MIN = {")
    for build, cfg in BUILDS.items():
        lua.append(f'  {build} = {cfg["min"]},')
    lua.append("}")
    OUT_LUA.parent.mkdir(parents=True, exist_ok=True)
    OUT_LUA.write_text("\n".join(lua) + "\n")

    n_entries = sum(MAX_LEVEL - cfg["min"] + 1 for cfg in BUILDS.values())
    n_tpl = n_entries * len(DONORS)
    print(f"stat entries: {n_entries} -> {OUT_STATS}")
    print(f"templates:    {n_tpl} -> {OUT_TEMPLATES}")
    print(f"lua lookup:  -> {OUT_LUA}")
    print("rolled-kit samples (re-roll every regen):")
    for ck in ("cleric", "druid"):
        for L in (5, 8):
            print(f"  {ck} L{L}:", ", ".join(roll_spell_kit(ck, FULL_SLOTS, L)))


if __name__ == "__main__":
    main()
