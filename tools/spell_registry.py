#!/usr/bin/env python3
"""
spell_registry.py - the single source of truth for every spell we may assign:
game stats id -> (display name, BG3 spell level, classes that can learn it).

Why: owner playtests caught wrong-class / wrong-level spells on mobs
(a cleric with Call Lightning; a Goon's-Library warlock casting lvl-6
Sunbeam/Disintegrate). gen_teams.py calls validate() BEFORE generating any
templates - unknown ids, level mismatches and wrong-class assignments are
HARD errors, so the mistake can never reach the pak.

Levels are the real BG3 stat-entry values (data "Level", following `using`
chains) from the full vanilla pak census (Shared/Gustav/GustavX paks, all
layers incl. Honour, 2026-11-03). Class sets follow 5e lists as BG3 ships
them; where BG3 bends the rules we note it (e.g. warlock Chromatic Orb via
the Kindly invocation).

Usage:
  python3 tools/spell_registry.py            # print the table
  python3 tools/spell_registry.py --check    # validate tools/gen_teams.py
Levels refresh: re-dump pak Spell_*.txt and diff data "Level" (see HANDOVER).
"""
import pathlib
import re
import sys

# id -> (display name, BG3 spell level, classes)
# classes: 5e class names; "eldritch_knight"/"arcane_trickster" = 1/3 casters
# drawing from the wizard list. EVERY id + level below cross-checked against the
# vanilla pak census (using-chain resolved), 2026-11-03.
REGISTRY = {
    # ---- cantrips (level 0) ----
    "Projectile_AcidSplash":         ("Acid Splash", 0, {"sorcerer", "wizard"}),
    "Projectile_EldritchBlast":      ("Eldritch Blast", 0, {"warlock"}),
    "Projectile_FireBolt":           ("Fire Bolt", 0, {"sorcerer", "wizard"}),
    "Projectile_PoisonSpray":        ("Poison Spray", 0, {"druid", "sorcerer", "warlock"}),
    "Shout_ProduceFlame":            ("Produce Flame", 0, {"druid"}),  # BG3 ships it lvl 0
    "Target_Guidance":               ("Guidance", 0, {"cleric", "druid"}),
    "Target_MinorIllusion":          ("Minor Illusion", 0, {"bard", "sorcerer", "warlock", "wizard"}),
    "Target_SacredFlame":            ("Sacred Flame", 0, {"cleric", "warlock"}),
    "Target_ThornWhip":              ("Thorn Whip", 0, {"druid", "ranger"}),
    "Target_TollTheDead":            ("Toll the Dead", 0, {"cleric", "warlock"}),
    "Target_ViciousMockery":         ("Vicious Mockery", 0, {"bard"}),

    # ---- 1st level ----
    "Projectile_ChromaticOrb_Acid":  ("Chromatic Orb (Acid)", 1,
                                      {"sorcerer", "wizard", "warlock"}),  # warlock: Kindly invocation (BG3)
    "Projectile_GuidingBolt":        ("Guiding Bolt", 1, {"cleric"}),
    "Projectile_IceKnife":           ("Ice Knife", 1, {"druid", "sorcerer", "wizard"}),
    "Projectile_MagicMissile":       ("Magic Missile", 1, {"wizard", "sorcerer", "eldritch_knight"}),
    "Shout_ArmsOfHadar":            ("Arms of Hadar", 1, {"warlock"}),
    "Shout_ArmorOfAgathys":         ("Armor of Agathys", 1, {"warlock"}),
    "Target_Bane":                   ("Bane", 1, {"cleric", "bard"}),
    "Target_Bless":                  ("Bless", 1, {"cleric", "paladin"}),
    "Target_Command_Halt_NPC":       ("Command", 1, {"cleric", "paladin"}),  # AI-friendly entry
    "Target_CureWounds":             ("Cure Wounds", 1, {"cleric", "druid", "paladin"}),
    "Target_Goodberry":              ("Goodberry", 1, {"druid", "ranger"}),
    "Target_HealingWord":            ("Healing Word", 1, {"cleric", "druid", "bard"}),
    "Target_Hex":                    ("Hex", 1, {"warlock"}),
    "Target_HuntersMark":            ("Hunter's Mark", 1, {"ranger"}),
    "Target_MageArmor":              ("Mage Armor", 1, {"wizard", "sorcerer", "eldritch_knight"}),
    "Target_ShieldOfFaith":          ("Shield of Faith", 1, {"cleric", "paladin"}),
    "Target_Smite_Divine":           ("Divine Smite", 1, {"paladin"}),
    "Target_Smite_Searing":          ("Searing Smite", 1, {"paladin"}),
    "Target_Smite_Thunderous":       ("Thunderous Smite", 1, {"paladin"}),
    "Zone_Thunderwave":              ("Thunderwave", 1, {"sorcerer", "wizard", "bard", "eldritch_knight"}),

    # ---- 2nd level ----
    "Projectile_ScorchingRay":       ("Scorching Ray", 2, {"sorcerer", "wizard"}),
    "Shout_MirrorImage":             ("Mirror Image", 2, {"wizard", "sorcerer", "arcane_trickster"}),
    "Shout_PassWithoutTrace":        ("Pass without Trace", 2, {"druid", "ranger"}),
    "Target_Barkskin":               ("Barkskin", 2, {"druid", "ranger", "eldritch_knight"}),
    "Target_Blindness":              ("Blindness/Deafness", 2, {"bard", "cleric", "sorcerer", "wizard"}),
    "Target_Darkness":               ("Darkness", 2, {"warlock", "sorcerer", "wizard"}),
    "Target_FlamingSphere":          ("Flaming Sphere", 2, {"druid", "wizard"}),
    "Target_HeatMetal":              ("Heat Metal", 2, {"druid"}),
    "Target_HoldPerson":             ("Hold Person", 2, {"cleric", "druid", "wizard", "sorcerer", "warlock", "bard"}),
    "Target_MistyStep":              ("Misty Step", 2, {"wizard", "sorcerer", "warlock"}),
    "Target_Moonbeam":               ("Moonbeam", 2, {"druid", "ranger", "eldritch_knight"}),
    "Target_Shatter":                ("Shatter", 2, {"sorcerer", "wizard", "bard", "eldritch_knight"}),
    "Target_SpiritualWeapon":        ("Spiritual Weapon", 2, {"cleric"}),
    "Target_SpikeGrowth":            ("Spike Growth", 2, {"druid", "ranger"}),
    "Target_WardingBond":            ("Warding Bond", 2, {"cleric"}),
    "Target_Web":                    ("Web", 2, {"wizard", "sorcerer", "eldritch_knight"}),
    "Shout_Aid":                     ("Aid", 2, {"cleric", "paladin", "bard", "arcane_trickster"}),

    # ---- 3rd level ----
    "Shout_HealingWord_Mass":        ("Mass Healing Word", 3, {"cleric", "druid", "bard"}),
    "Shout_SpiritGuardians":         ("Spirit Guardians", 3, {"cleric"}),
    "Target_CallLightning":          ("Call Lightning", 3, {"druid"}),  # DRUID ONLY - never a cleric spell
    "Target_Fly":                    ("Fly", 3, {"sorcerer", "wizard", "warlock"}),  # warlock: Sight of the Fiend (BG3)

    # ---- 4th level ----
    "Target_Blight":                 ("Blight", 4, {"sorcerer", "wizard", "warlock", "eldritch_knight"}),
    "Target_ConjureWoodlandBeings":  ("Conjure Woodland Beings", 4, {"druid"}),
    "Target_FreedomOfMovement":      ("Freedom of Movement", 4, {"cleric", "druid", "ranger"}),
    "Target_IceStorm":               ("Ice Storm", 4, {"druid", "sorcerer", "wizard"}),
    "Wall_WallOfFire":               ("Wall of Fire", 4, {"wizard", "sorcerer", "eldritch_knight"}),

    # ---- 5th level ----
    "Target_ConjureElemental_Elemental_Fire_NPC": ("Conjure Elemental", 5, {"druid", "wizard", "sorcerer"}),
    "Target_CureWounds_Mass":        ("Mass Cure Wounds", 5, {"cleric", "druid"}),
    "Target_FlameStrike":            ("Flame Strike", 5, {"cleric"}),
    "Target_InsectPlague":           ("Insect Plague", 5, {"cleric", "druid", "sorcerer"}),

    # ---- 6th level (need char lvl 11 = 6th slots) ----
    "Target_Heal":                   ("Heal", 6, {"cleric", "druid", "bard"}),
    "Zone_Sunbeam":                  ("Sunbeam", 6, {"druid"}),           # owner: warlock cast it - Goon's Library, not us
    "Projectile_Disintegrate":       ("Disintegrate", 6, {"wizard", "sorcerer"}),

    # ---- banned ids (exist in vanilla but must never be assigned) ----
    "Target_MAG_SpiritualWeapon":    ("Spiritual Weapon (magic-item variant)", 6, set()),
    # ^ Once-per-rest item version at lvl 6; use plain Target_SpiritualWeapon (lvl 2).
}

# gen_teams.py build key -> class (hexblade is a warlock build etc.)
BUILD_CLASS = {
    "cleric": "cleric",
    "druid": "druid", "druid_healer": "druid", "druid_shifter": "druid",
    "druid_caster": "druid",
    "wizard": "wizard", "sorcerer": "sorcerer",
    "warlock": "warlock", "hexblade": "warlock",
    "paladin": "paladin", "ranger": "ranger", "bard": "bard",
    "eldritch_knight": "eldritch_knight", "arcane_trickster": "arcane_trickster",
}


def _module_literal(path, name, consts=None):
    """Evaluate a module-level `NAME = {...}` from a python file; Name nodes
    listed in consts (pre-evaluated module dicts like FULL_SLOTS) resolve to them."""
    import ast
    consts = consts or {}

    def ev(node):
        if isinstance(node, ast.Name):
            if node.id in consts:
                return consts[node.id]
            raise ValueError(f"unknown name {node.id}")
        if isinstance(node, ast.Constant):
            return node.value
        if isinstance(node, ast.Dict):
            return {_evk(k): ev(v) for k, v in zip(node.keys, node.values)}
        if isinstance(node, ast.Tuple):
            return tuple(ev(e) for e in node.elts)
        if isinstance(node, ast.List):
            return [ev(e) for e in node.elts]
        if isinstance(node, ast.Set):
            return {ev(e) for e in node.elts}
        raise ValueError(f"malformed node {type(node).__name__}")

    def _evk(k):
        v = ev(k)
        return frozenset(v) if isinstance(v, set) else v

    tree = ast.parse(path.read_text())
    for node in tree.body:
        if (isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id == name):
            return ev(node.value)
    raise KeyError(f"{name} not found in {path}")


def _module_keys(path, name):
    """Dict keys of a module-level `NAME = {...}` (values may be dict()/lambda)."""
    import ast
    tree = ast.parse(path.read_text())
    for node in tree.body:
        if (isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
                and node.targets[0].id == name and isinstance(node.value, ast.Dict)):
            return [ast.literal_eval(k) for k in node.value.keys]
    raise KeyError(f"{name} not found in {path}")


def validate(gen_teams_path):
    """Hard-error if anything gen_teams.py would bake is unknown / wrong level /
    wrong class. Returns list of warnings."""
    p = pathlib.Path(gen_teams_path)
    errs, warns = [], []

    builds = _module_keys(p, "BUILDS")
    consts = {nm: _module_literal(p, nm)
              for nm in ("FULL_SLOTS", "HALF_SLOTS", "WARLOCK_SLOTS")}
    cats = _module_literal(p, "SPELL_CATS")
    cantrips = _module_literal(p, "CANTRIPS")
    roll_kits = _module_literal(p, "ROLL_KITS", consts)
    static = _module_literal(p, "SPELLS", consts)

    # kit keys must be real build names (catches the v3.44 "ranged" vs "ranger" typo)
    for src, table in (("SPELLS", static), ("ROLL_KITS", roll_kits)):
        for build in table:
            if build not in builds:
                errs.append(f"{src}[{build}]: not a BUILDS key (kit would never apply)")

    def spell(sid, where, want_class):
        ent = REGISTRY.get(sid)
        if ent is None:
            errs.append(f"{where}: {sid} not in spell_registry (add it with name/level/classes)")
            return None
        name, lvl, classes = ent
        if not classes:
            errs.append(f"{where}: {sid} ({name}) is BANNED in the registry "
                        f"(item/variant id - pick the real spell id)")
        if want_class and want_class not in classes:
            errs.append(f"{where}: {sid} ({name}) not castable by {want_class} "
                        f"(registry allows: {'/'.join(sorted(classes)) or 'nobody'})")
        return name, lvl, classes

    # ROLLED kits: priority-group tables, (sid, spell_level, pri)
    for catkey, groups in cats.items():
        cls = BUILD_CLASS.get(catkey, catkey)
        for gname, table in groups:
            for sid, lvl, _pri in table:
                ent = spell(sid, f"SPELL_CATS[{catkey}/{gname}]", cls)
                if ent and ent[1] != lvl:
                    errs.append(f"SPELL_CATS[{catkey}/{gname}]: {sid} declared spell "
                                f"level {lvl}, BG3 level is {ent[1]}")
    for catkey, table in cantrips.items():
        cls = BUILD_CLASS.get(catkey, catkey)
        for sid, _pri in table:
            ent = spell(sid, f"CANTRIPS[{catkey}]", cls)
            if ent and ent[1] != 0:
                errs.append(f"CANTRIPS[{catkey}]: {sid} is not a cantrip (BG3 level {ent[1]})")

    # STATIC kits: (min char level, sid)
    for build, (_ab, _curve, kit) in static.items():
        cls = BUILD_CLASS.get(build)
        for _need, sid in kit:
            spell(sid, f"SPELLS[{build}]", cls)

    if errs:
        raise SystemExit("spell_registry validation FAILED:\n  " + "\n  ".join(errs))
    return warns


def main():
    args = sys.argv[1:]
    here = pathlib.Path(__file__).resolve().parent
    if "--check" in args:
        validate(here / "gen_teams.py")
        print(f"spell_registry: OK ({len(REGISTRY)} spells; gen_teams.py kits all valid)")
        return
    rows = sorted(REGISTRY.items(), key=lambda kv: (kv[1][1], kv[1][0].lower()))
    print(f"{'Spell':32} {'GameID':45} {'Lvl':>3}  Classes")
    print("-" * 105)
    for sid, (name, lvl, classes) in rows:
        cs = "/".join(sorted(classes)) if classes else "BANNED"
        print(f"{name:32} {sid:45} {lvl:>3}  {cs}")


if __name__ == "__main__":
    main()
