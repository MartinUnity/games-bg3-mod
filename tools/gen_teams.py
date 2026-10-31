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

OUT_STATS = pathlib.Path("mods/chaos-reinforcements/Public/ChaosReinforcements/"
                         "Stats/Generated/Data/CHAOS_Teams.txt")
OUT_TEMPLATES = pathlib.Path("mods/chaos-reinforcements/Public/ChaosReinforcements/"
                             "RootTemplates/ChaosTeams.lsx")
OUT_LUA = pathlib.Path("mods/chaos-reinforcements/Mods/ChaosReinforcements/"
                       "ScriptExtender/Lua/Server/TeamTemplates.lua")

XP_CURVE = "206b753f-bc3b-46af-98b9-0c711d98c678"   # vanilla goblin XP curve

# UCL progression TABLE guids (verified against the installed UtutsCoreLibrary)
UCL = {
    "Fighter": "1c4c6006-bb49-4dac-954a-5a83b815a695",
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
}

PROF_MARTIAL = ("SimpleWeapons;MartialWeapons;LightArmor;MediumArmor;HeavyArmor;"
                "Shields;Battleaxes")
PROF_LIGHT = "SimpleWeapons;LightArmor"

ROLES = {
    "tank": dict(
        prog=["Fighter", "Champion", "style2_defence", "ActionSurge_Melee", "asi_str"],
        stats={"STR": 15, "DEX": 13, "CON": 15, "INT": 8, "WIS": 12, "CHA": 8},
        hp=lambda lvl: 10 + 9 * lvl, prof=PROF_MARTIAL, armor=14, armor_type="Heavy",
        cast=None),
    "melee_dps": dict(
        prog=["Barbarian", "Berserker", "asi_str"],
        stats={"STR": 16, "DEX": 13, "CON": 14, "INT": 8, "WIS": 10, "CHA": 8},
        hp=lambda lvl: 8 + 9 * lvl, prof=PROF_MARTIAL, armor=12, armor_type="Medium",
        cast=None),
    "ranged": dict(
        prog=["Ranger", "Hunter", "style1_archery", "feat_sharpshooter", "asi_dex"],
        stats={"STR": 10, "DEX": 16, "CON": 13, "INT": 10, "WIS": 14, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof=PROF_MARTIAL, armor=12, armor_type="Medium",
        cast="Wisdom"),
    "caster": dict(
        prog=["Wizard", "EvocationSchool", "asi_int"],
        stats={"STR": 8, "DEX": 14, "CON": 13, "INT": 16, "WIS": 10, "CHA": 8},
        hp=lambda lvl: 6 + 5 * lvl, prof=PROF_LIGHT, armor=10, armor_type="Cloth",
        cast="Intelligence"),
    "healer": dict(
        prog=["Cleric", "LightDomain", "asi_wis"],
        stats={"STR": 12, "DEX": 12, "CON": 14, "INT": 8, "WIS": 16, "CHA": 8},
        hp=lambda lvl: 8 + 7 * lvl, prof=PROF_MARTIAL, armor=12, armor_type="Medium",
        cast="Wisdom"),
    "wildcard": dict(
        prog=["Bard", "SwordsCollege", "asi_cha"],
        stats={"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 12, "CHA": 16},
        hp=lambda lvl: 8 + 6 * lvl, prof=PROF_MARTIAL, armor=11, armor_type="Light",
        cast="Charisma"),
}

# vanilla humanoid donors (ParentTemplateId): proven-spawnable player-race templates
DONORS = [
    ("human_m", "BASE_Humans_Male_Aggressive_e0eaf4bd-1c00-4947-aaa1-b1801fbfadfe"),
    ("elf_f", "BASE_Elves_Female_Drow_0bd09fae-e858-4a6e-8d1a-72dd0eb4cb60"),
    ("halfelf_m", "BASE_HalfElves_Male_Drow_9335e9a8-ad69-4180-b286-6e86c8e444a9"),
    ("halfling_m", "BASE_Halflings_Male_Crowd_Refugee_A_0fc1e8e9-18e2-407f-8ee2-4de350f15b5f"),
    ("dwarf_f", "Dwarves_Female_Duergar_Guard_Melee_94f7da13-e289-494b-9889-166614e3fc6f"),
    ("tiefling_m", "Tieflings_Male_Asmodeus_Guard_Caster_748a7bde-5a75-4d37-0aac-a8ad0f170903"),
    ("gith_m", "Githyanki_Male_Guard_Caster_8f31c26a-67c0-b0bf-8a7a-a08a627b1692"),
]

MAX_LEVEL = 12


def main():
    stats_lines = []
    tpl_lines = []
    lookup = {r: {} for r in ROLES}
    for role, cfg in ROLES.items():
        prog = ";".join(UCL[k] for k in cfg["prog"])
        for lvl in range(1, MAX_LEVEL + 1):
            entry = f"CHAOST_{role}_L{lvl}"
            stats_lines += [
                f'new entry "{entry}"',
                'type "Character"',
                'using "_Human"',
            ]
            for ab, v in cfg["stats"].items():
                stats_lines.append(f'data "{ab}" "{v}"')
            stats_lines += [
                f'data "Vitality" "{cfg["hp"](lvl)}"',
                f'data "Armor" "{cfg["armor"]}"',
                f'data "Level" "{lvl}"',
                f'data "Proficiency Group" "{cfg["prof"]}"',
                f'data "ArmorType" "{cfg["armor_type"]}"',
                f'data "Progressions" "{prog}"',
                f'data "XPReward" "{XP_CURVE}"',
            ]
            if cfg["cast"]:
                stats_lines.append(f'data "SpellCastingAbility" "{cfg["cast"]}"')
            stats_lines.append("")
            for tag, donor in DONORS:
                mapkey = str(uuid.uuid4())
                name = f"CHAOST_{role}_L{lvl}_{tag}"
                lookup[role].setdefault(lvl, []).append(f"{name}_{mapkey}")
                tpl_lines += [
                    '\t\t\t\t\t<node id="GameObjects">',
                    f'\t\t\t\t\t\t<attribute id="Name" type="LSString" value="{name}" />',
                    f'\t\t\t\t\t\t<attribute id="MapKey" type="FixedString" value="{mapkey}" />',
                    f'\t\t\t\t\t\t<attribute id="ParentTemplateId" type="FixedString" value="{donor.split("_")[-1]}" />',
                    f'\t\t\t\t\t\t<attribute id="Stats" type="FixedString" value="{entry}" />',
                    f'\t\t\t\t\t\t<attribute id="LevelOverride" type="int32" value="{lvl}" />',
                    '\t\t\t\t\t\t<attribute id="SpellSet" type="FixedString" value="CommonNPCActions" />',
                    '\t\t\t\t\t\t<attribute id="Type" type="FixedString" value="character" />',
                    "\t\t\t\t\t</node>",
                ]

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
           "-- (role -> level -> list of \"Name_<mapkey>\" ids, one per visual donor)",
           "CHAOS_TEAMS = {"]
    for role in ROLES:
        lua.append(f'  {role} = {{')
        for lvl in range(1, MAX_LEVEL + 1):
            ids = ", ".join(f'"{i}"' for i in lookup[role][lvl])
            lua.append(f"    [{lvl}] = {{ {ids} }},")
        lua.append("  },")
    lua.append("}")
    OUT_LUA.parent.mkdir(parents=True, exist_ok=True)
    OUT_LUA.write_text("\n".join(lua) + "\n")

    n_entries = MAX_LEVEL * len(ROLES)
    n_tpl = n_entries * len(DONORS)
    print(f"stat entries: {n_entries} -> {OUT_STATS}")
    print(f"templates:    {n_tpl} -> {OUT_TEMPLATES}")
    print(f"lua lookup:  -> {OUT_LUA}")


if __name__ == "__main__":
    main()
