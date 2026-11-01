#!/usr/bin/env python3
"""Team composer (iteration 2 of the humanoid-teams plan): paper-level team generator.

Composes enemy humanoid teams the way a PLAYER party is built - roles, classes,
subclasses, fighting styles, feats/ASI - with a fairness ledger (player-equivalent
progression only). This tool is for REVIEW ON PAPER: run it, read
docs/sample-teams.md, tune. The same rules later move into the Lua runtime +
generated stat entries (iteration 3).

Kit grammar (decoded in iteration 1, docs/role-catalog.md):
  Character stat entry "Progressions" = semicolon list of TABLE guids:
    base class + subclass + fighting style (level-specific table) + features/feats + ASI
  UCL tables (UtutsCoreLibrary, optional at runtime via Ext.Mod.IsModLoaded):
  2da3bc36-b4b2-4652-a611-3fe16527417e) give the full grammar; without UCL we fall
  back to vanilla NPC_* class tables (kit = class track only).

Usage: python3 tools/team_composer.py [n_samples_per_cell]
"""
import random
import sys

# --- UCL table vocabulary (guids verified against the installed UtutsCoreLibrary) ----
UCL = {
    # base classes
    "Fighter": "1c4c6006-bb49-4dac-954a-5a83b815a695",
    "Barbarian": "ae343448-6fce-40b2-8eb7-b5e4316dff58",
    "Ranger": "06762adc-24d9-4689-8d09-8dfa9182dd4b",
    "Rogue": "4356e226-3b97-46c6-9e16-2b8f302ab42f",
    "Wizard": "7eefd2dd-5aab-4349-9c22-7c38afe133c4",
    "Sorcerer": "e93883b2-b593-4101-9c97-d6b8c454c053",
    "Warlock": "f34419b6-a50a-46c2-9eb9-28264fd71c55",
    "Cleric": "4577e872-7f55-448b-a6c4-bb3f5a3738b6",
    "Druid": "d3af8a04-c768-487d-bf32-13828fd51f09",
    "Bard": "ef851978-e229-4b50-afd2-8a4e80c5b4a1",
    "Paladin": "14599945-cb3d-461a-9937-8691ac8923ed",
    # subclasses (table min-level noted for the fairness ledger)
    "Champion": (3, "658e5cdc-c04a-47df-9edd-8c1eec8a7ec2"),
    "BattleMaster": (3, "6ff11c41-24ae-47a7-b969-036b1a75c386"),
    "EldritchKnight": (3, "b1316370-2f3d-4f0a-9c09-55e165d17adc"),
    "Berserker": (3, "5be7823a-4611-4bb5-a2ba-cc60be806378"),
    "TotemWarrior": (3, "31d636c6-b955-4e68-a6e7-79d7302453b9"),
    "Hunter": (3, "7839dbea-69da-441f-9668-f91a904ee6b5"),
    "BeastMaster": (3, "a2e24907-b783-4cf7-b240-0e2ce563a256"),
    "GloomStalker": (3, "7dcf10d4-1137-4642-a623-c450c06ab1a9"),
    "Assassin": (3, "999c38da-0409-4368-84b0-84b500e7365d"),
    "EvocationSchool": (2, "35539b35-76aa-4da1-8b56-cb124497eca1"),
    "NecromancySchool": (2, "20c3aeb1-8a5c-4a62-8a21-78b488c3bca8"),
    "BladesingingSchool": (2, "ea47cc9f-e900-45a9-8c17-186730251946"),
    "DraconicBloodline": (1, "348f783f-d3b8-4a05-9bc7-b13217990a50"),
    "WildMagic": (1, "a84b7bc9-88f4-4861-9bcb-77a2fd17cd12"),
    "Fiend": (1, "9c4763f3-c485-4572-9991-b0f5385d61ce"),
    "GreatOldOne": (1, "ffa87dcf-3390-437c-8075-74c2ad37e3e2"),
    "TrickeryDomain": (1, "7b8f76a2-8e55-4ca4-abd5-7c69f3256cac"),
    "LightDomain": (1, "55d4818d-3191-42ef-9719-a66b4ff29811"),
    "WarDomain": (1, "f1de97de-081b-428b-a83b-2eb1c3069886"),
    "SwordsCollege": (3, "2375ac5d-f13b-4a8b-8f1d-da0141cc9b79"),
    "CircleOfTheSpores": (2, "a3842d6e-15ba-4ca9-8ea9-6334daa8e566"),
    # fighting styles: level-specific tables ("_<n>_" = the class level they attach to)
    "style1_archery": "0ed759fc-4856-4568-9405-929d731899dd",
    "style1_dueling": "9b294891-f501-4e14-be10-b932cfe0c3ed",
    "style1_gwf": "f59de40e-deb6-42e8-820a-e41976ca4deb",
    "style2_defence": "a9b4a6ab-736c-4727-99f7-9ee4444fb8e1",
    "style2_archery": "7fa893da-ef8a-458c-a2cf-9de5a0fb0ef4",
    "style2_twf": "5b91e529-a3bb-4fcd-bd59-de914b46f2fa",
    # features
    "ActionSurge_Melee": (2, "e6be4ef3-c002-425e-903e-8595df5c5049"),
    "ActionSurge_Ranged": (2, "52ce2956-83da-4ed2-9107-1ca8db0d9e91"),
    "TwoHander": (4, "b01ff88f-ca24-4d55-b9ba-1b8b835cc2b6"),
    "Sharpshooter": (4, "85ffe605-411e-4f1b-b40b-ebbf2a5372f3"),
    "EldritchBlaster": (2, "2919cea5-a0c1-46e8-9774-4c9f03ba3d5f"),
    "Familiar": (1, "4318cdb8-c4fe-404f-a703-5ba88baaf65c"),
    "SteelDefender": (3, "297e6a65-7167-43b6-a4af-1bb95415d410"),
    # feats / ASI (level 4-8 tables - ledger: pick ONE at lvl>=4, another at lvl>=8)
    "asi_str": "4f22dd35-542c-4aa0-a790-b6c93c3e252f",
    "asi_dex": "defed003-fb89-41b8-b59f-a57dae9e50de",
    "asi_cha": "b40ab293-676f-41d4-919e-bf1f36643548",
    "asi_wis": "181bb485-b676-4e66-8a46-3f7aa1e31415",
    "asi_int": "38416c1a-9b9c-4d62-a2a2-1a9853fcb592",
    "feat_dualwielder": "13abbf29-3a70-4854-805d-c9ede2147adb",
    "feat_sharpshooter": "85ffe605-411e-4f1b-b40b-ebbf2a5372f3",
    "feat_tavernbrawler_str": "1dad8652-72ba-4257-9247-2feaedce6050",
    "feat_crossbowexpert": "d9c06a14-30a1-4b3d-adc8-5915d776c8a3",
    "feat_twohander": "36d19089-578d-474f-bfa0-b37f14a138c8",
    "feat_warcaster_int": "82f2fa2c-0ac8-458a-b1a3-2d82cd4f6639",
    "feat_warcaster_wis": "61ae4889-e080-4e29-a6a9-a68c240744bf",
}

# vanilla NPC tables (fallback, no UCL): class -> table guid (docs/role-catalog.md)
NPC_TABLES = {
    "Fighter": "fe0fa98b-52be-4993-830f-7b4fe4c5f803",
    "Barbarian": "TODO_NPC_Barbarian_table",
    "Ranger": "TODO_NPC_Ranger_table",
    "Wizard": "TODO_NPC_Wizard_table",
    "Cleric": "TODO_NPC_Cleric_table",
    "Warlock": "TODO_NPC_Warlock_table",
    "Druid": "TODO_NPC_Druid_table",
    "Rogue": "TODO_NPC_Rogue_table",
    "Bard": "TODO_NPC_Bard_table",
    "Paladin": "TODO_NPC_Paladin_table",
}

# --- role definitions ----------------------------------------------------------------
# stat arrays: player point-buy flavored (before ASI), keyed by role
ROLE_STATS = {
    "tank":      {"STR": 15, "DEX": 13, "CON": 15, "INT": 8,  "WIS": 12, "CHA": 8},
    "melee_dps": {"STR": 16, "DEX": 13, "CON": 14, "INT": 8,  "WIS": 10, "CHA": 8},
    "ranged":    {"STR": 10, "DEX": 16, "CON": 13, "INT": 10, "WIS": 14, "CHA": 8},
    "caster":    {"STR": 8,  "DEX": 14, "CON": 13, "INT": 16, "WIS": 10, "CHA": 8},
    "healer":    {"STR": 12, "DEX": 12, "CON": 14, "INT": 8,  "WIS": 16, "CHA": 8},
    "wildcard":  {"STR": 10, "DEX": 14, "CON": 12, "INT": 10, "WIS": 12, "CHA": 16},
}

# class -> subclass options (a subclass must belong to the picked CLASS)
SUBCLASSES = {
    "Fighter": ["Champion", "BattleMaster", "EldritchKnight"],
    "Barbarian": ["Berserker", "TotemWarrior"],
    "Ranger": ["Hunter", "BeastMaster", "GloomStalker"],
    "Rogue": ["Assassin"],
    "Wizard": ["EvocationSchool", "NecromancySchool", "BladesingingSchool"],
    "Sorcerer": ["DraconicBloodline", "WildMagic"],
    "Warlock": ["Fiend", "GreatOldOne"],
    "Cleric": ["TrickeryDomain", "LightDomain", "WarDomain"],
    "Druid": ["CircleOfTheSpores"],
    "Bard": ["SwordsCollege"],
}
STYLE_BY_CLASS = {  # fighting styles only for martial classes that have them
    "Fighter": "style2_defence", "Ranger": "style1_archery",
}

# role -> (primary class, feature options, feat pools); class variety via CLASSES_BY_ROLE
ROLE_KITS = {
    "tank": ("Fighter", ["ActionSurge_Melee"], ["asi_str", "feat_dualwielder", "feat_tavernbrawler_str"]),
    "melee_dps": ("Barbarian", [], ["asi_str", "feat_twohander", "feat_tavernbrawler_str"]),
    "ranged": ("Ranger", ["Familiar", "ActionSurge_Ranged"], ["asi_dex", "feat_sharpshooter", "feat_crossbowexpert"]),
    "caster": ("Wizard", [], ["asi_int", "feat_warcaster_int"]),
    "healer": ("Cleric", [], ["asi_wis", "feat_warcaster_wis"]),
    "wildcard": ("Bard", [], ["asi_cha", "feat_dualwielder"]),
}
CLASSES_BY_ROLE = {  # variety: additional class options per role
    "caster": ["Sorcerer", "Warlock"],
    "healer": ["Druid"],
    "melee_dps": ["Fighter"],
    "ranged": ["Rogue"],
    "wildcard": ["Sorcerer", "Warlock", "Rogue", "Bard"],
}

def fmt(t):
    if isinstance(t, tuple):
        return f"{t[0]} (needs lvl {t[1]})"
    return t

def build_kit(role, level, ucl=True):
    """Role -> kit dict: class, subclass (if level allows), style, features, feats, tables."""
    cls, feats_extra, feat_pool = ROLE_KITS[role]
    classes = [cls] + CLASSES_BY_ROLE.get(role, [])
    cls = random.choice(classes)
    subs = SUBCLASSES.get(cls, [])
    style = STYLE_BY_CLASS.get(cls)
    kit = {"role": role, "class": cls, "subclass": None, "style": None,
           "features": [], "feats": [], "tables": []}
    if not ucl:
        kit["tables"] = [f"vanilla NPC_{cls} table (no subclass/styles - UCL absent)"]
        return kit
    kit["tables"].append(UCL[cls])
    sub = random.choice(subs)
    minlvl, guid = UCL[sub]
    if level >= minlvl and random.random() < 0.8:   # 80% subclassed, else plain
        kit["subclass"] = sub
        kit["tables"].append(guid)
    if style and level >= int(style[5]):
        kit["style"] = style
        kit["tables"].append(UCL[style])
    for f in feats_extra:
        minlvl, guid = UCL[f]
        if level >= minlvl:
            kit["features"].append(f)
            kit["tables"].append(guid)
    # fairness ledger: feat/ASI only at the player's own feat levels
    if level >= 4:
        f = random.choice(feat_pool)
        kit["feats"].append(f)
        kit["tables"].append(UCL[f])
    if level >= 8:
        f = random.choice(feat_pool)
        kit["feats"].append(f)
        kit["tables"].append(UCL[f])
    return kit


def compose(party_size, level, ucl=True):
    """Team shape per owner spec: core 3-5, squad 6-8 (+leader), warband 9-10 (+boss/2 sub)."""
    tier = "core" if party_size <= 5 else ("squad" if party_size <= 8 else "warband")
    slots = []
    slots.append("tank")
    n_dps = random.randint(1, 2)
    slots += ["melee_dps"] * n_dps
    slots.append("ranged")
    if party_size >= 3:
        slots.append(random.choice(["caster", "healer"]))
    while len(slots) < min(party_size, 5):
        slots.append(random.choice(["melee_dps", "ranged", "caster", "healer", "wildcard"]))
    if tier in ("squad", "warband"):
        while len(slots) < min(party_size, 7 if tier == "squad" else 9):
            slots.append(random.choice(["melee_dps", "ranged", "caster", "healer", "wildcard"]))
    members = []
    for s in slots:
        lvl = max(1, min(level + random.randint(-2, 2), level + 3))
        members.append((s, lvl, build_kit(s, lvl, ucl)))
    leaders = []
    if tier in ("squad", "warband"):
        leaders.append(("leader", min(level + 2, level + 3), build_kit("tank", level + 2, ucl)))
    if tier == "warband":
        leaders.append(("subleader", level + 1, build_kit(random.choice(["caster", "ranged"]), level + 1, ucl)))
        leaders.append(("BOSS", level + 3, build_kit(random.choice(["tank", "caster"]), level + 3, ucl)))
    return tier, members, leaders


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    out = []
    w = out.append
    w("# Sample humanoid teams (iteration 2 - paper review)")
    w("")
    w("Auto-generated by `tools/team_composer.py`. Roles, classes, subclasses, styles and")
    w("feats are composed player-fairly: subclasses only from their minimum class level,")
    w("feat/ASI only at levels 4 and 8 (the player's own feat levels). UCL kits are used")
    w("when UtutsCoreLibrary is installed (runtime: `Ext.Mod.IsModLoaded`); without it the")
    w("team falls back to vanilla `NPC_*` class tracks (shown in the last section).")
    w("")
    for level in (2, 4, 7, 10):
        for party in (4, 6, 9):
            for i in range(n):
                random.seed(hash((level, party, i)) & 0xFFFFFFFF)
                tier, members, leaders = compose(party, level, ucl=True)
                w(f"## Team: party {party} vs player lvl {level} - {tier} (seed {i})")
                w("")
                for role, lvl, kit in members:
                    w(f"- **{role}** lvl {lvl} - {kit['class']}"
                      + (f" / {kit['subclass']}" if kit["subclass"] else "")
                      + (f", style {kit['style']}" if kit["style"] else "")
                      + (f", features {', '.join(kit['features'])}" if kit["features"] else "")
                      + (f", feats {', '.join(kit['feats'])}" if kit["feats"] else "")
                      + f" - stats {ROLE_STATS[role]}")
                for role, lvl, kit in leaders:
                    w(f"- **{role}** lvl {lvl} - {kit['class']}"
                      + (f" / {kit['subclass']}" if kit["subclass"] else "")
                      + (f", feats {', '.join(kit['feats'])}" if kit["feats"] else "")
                      + f" - stats {ROLE_STATS[kit['role']]}")
                w("")
    w("## No-UCL fallback shape (vanilla NPC tracks only)")
    w("")
    random.seed(1)
    tier, members, leaders = compose(6, 5, ucl=False)
    w(f"Party 6 vs player lvl 5 - {tier}:")
    for role, lvl, kit in members + leaders:
        w(f"- **{role}** lvl {lvl} - {kit['tables'][0]}")
    w("")
    import pathlib
    pathlib.Path("docs/sample-teams.md").write_text("\n".join(out))
    print(f"wrote docs/sample-teams.md: {len(out)} lines")


if __name__ == "__main__":
    main()
