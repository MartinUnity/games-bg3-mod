#!/usr/bin/env python3
"""Build Server/CreatureDB.lua: every generic, spawnable creature root template in the game,
tagged with creature type (Aberration..Undead) and base HP, for the ChaosReinforcements chaos engine.

Sources (all local, offline):
1. Root-template tables: _merged.lsf from Shared/SharedDev/Gustav/GustavDev/Honour/GustavX paks,
   converted to lsx XML via tools/divine.sh (extract-single-file + convert-resource -i lsf -o lsx)
   into /tmp/opencode/rt/*.lsx. Node attrs used: Name, MapKey (own guid), Stats, Type=="character".
2. Vanilla stats (bg3-vanilla-data unpack): stats entry -> `using` chain -> `_Type` parent + Vitality.
3. In-game root-template dump (profile Script Extender/Chaos_root_templates.txt): the ground truth
   for what GetAllRootTemplates actually contains (guid -> name). A DB entry must appear there,
   otherwise CreateAtObject cannot instantiate it.

Filters: only Type=="character", resolvable type, non-story/novelty names (S_*, bosses, named
NPCs, summons, wildshapes, civilians, hallucinations...).

Output: mods/chaos-reinforcements/Mods/ChaosReinforcements/ScriptExtender/Lua/Server/CreatureDB.lua
Usage:  python3 tools/build_creature_db.py
"""
import re
import pathlib
import sys

RT = pathlib.Path("/tmp/opencode/rt")
LSX_FILES = ["merged.lsx", "shareddev.lsx", "gustav.lsx", "gustavdev.lsx", "honour.lsx", "gustavx.lsx"]
VANILLA = pathlib.Path("/home/martin/Documents/mods/bg3-new/bg3-vanilla-data")
DUMP = pathlib.Path("/home/martin/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/"
                    "users/steamuser/AppData/Local/Larian Studios/Baldur's Gate 3/Script Extender/"
                    "Chaos_root_templates.txt")
OUT = pathlib.Path("mods/chaos-reinforcements/Mods/ChaosReinforcements/ScriptExtender/Lua/Server/CreatureDB.lua")

TYPESET = {"Aberration", "Beast", "Celestial", "Construct", "Dragon", "Elemental", "Fey",
           "Fiend", "Giant", "Humanoid", "Monstrosity", "Ooze", "Plant", "Undead"}

# name patterns that mark story/unique/novelty creatures we never want as generic chaos mobs
BAD_NAME = re.compile(
    r"(^S_|_S_|^UNI_|^SCL_|^TUT_|^ACT\d|^MO_|^DEN_|^LOW_|^UPP_|^CMP_|^WLD_|^GLO_|^QRY_|^DRD_|^MS_"
    r"|^QUEST_|^Footstep_|Elder_Brain|NetherBrain|Doppelganger|Shapechanger"
    r"|Boss|Raphael|Vlaakith|Gortash|Orin|Yugot|Endbringer|Absolute|Cazador|Kasster|Thaniel"
    r"|Companion|Summon|Wildshape|Portrait|Civilian|PlayerWildshape|Hallucination|Duplicity"
    r"|Mannequin|_Act\d|DrinkingBuddy|Cub\b|Dad\b|Pregnant|Tutorial|Children|Baby|Hunt|Dialog|Double"
    r"|Gazer_.*Mylac|Gazemaster|Woe_|Mephit_Grease_Young|Crippled"
    r"|^\[WIP\]|(^|_)CINE_|(^|_)WIP_|TOBEDELETED"
    r"|^BHAAL_|HouseOfHope|Redcap_Pirate|Sharran_|DarkJusticiar|SteelWatcher|"
    r"DeathKnight|ApostleOfMyrkul|Dog_Ghost|FallenWizard|AnimateDead|WYR_Wyrmsway)", re.I)

# stats entries may also betray bossiness
BAD_STATS = re.compile(r"(Boss|Commander|General|Prince|Pope)", re.I)

# passives that betray story-scripted NPCs (death scripts, location buffs, plot bonds);
# the template names above catch most, this catches the rest data-driven
BAD_PASSIVE = re.compile(
    r"EternalDebtors|BlushingMermaid|HouseOfGrief|Houndmaster|VisionOfShar|"
    r"ConsumeTheFaithful|NecroticAttacks_DeathKnight|SelfDestruct_SteelWatcher", re.I)


def load_stats():
    entries = {}
    entry_re = re.compile(r'^new entry "([^"]+)"')
    using_re = re.compile(r'^using "([^"]+)"')
    # fields captured (first occurrence wins - child entries override parents)
    fields = {f: re.compile(r'^data "%s" "([^"]*)"' % f) for f in
              ("Vitality", "Strength", "Dexterity", "Constitution", "Armor", "Passives", "Level",
               "Proficiency Group", "UnarmedAttackAbility")}
    for f in sorted(VANILLA.rglob("Stats/Generated/Data/Character*.txt")):
        cur = None
        for line in f.read_text(errors="replace").splitlines():
            m = entry_re.match(line)
            if m:
                cur = m.group(1)
                entries.setdefault(cur, {})
                continue
            if cur is None:
                continue
            if line.startswith("new "):
                cur = None
                continue
            m = using_re.match(line)
            if m and "using" not in entries[cur]:
                entries[cur]["using"] = m.group(1)
                continue
            for name, rx in fields.items():
                if name not in entries[cur]:
                    m = rx.match(line)
                    if m:
                        entries[cur][name] = m.group(1)
                        break
    return entries


def resolve_type(stats, entries, depth=0):
    e = entries.get(stats)
    if e is None or depth > 10:
        return None, None
    parent = e.get("using")
    if parent is None or parent == "_Base":
        return None, e.get("Vitality")
    t = parent.lstrip("_")
    if t.endswith("s"):  # vanilla uses plural parents, e.g. _Giants -> Giant
        t = t[:-1]
    if t in TYPESET:
        return t, e.get("Vitality")
    t2, hp2 = resolve_type(parent, entries, depth + 1)
    return t2, (e.get("Vitality") or hp2)


def resolve_field(stats, entries, field, depth=0):
    """Walk the `using` chain; the closest entry defining the field wins."""
    e = entries.get(stats)
    if e is None or depth > 10:
        return None
    v = e.get(field)
    if v is not None:
        return v
    parent = e.get("using")
    if parent is None or parent == "_Base":
        return None
    return resolve_field(parent, entries, field, depth + 1)


def load_dump_keys():
    keys, names = set(), {}
    if not DUMP.is_file():
        print(f"WARN: no in-game dump at {DUMP}; skipping instantiation check")
        return keys, names
    for line in DUMP.read_text(errors="replace").splitlines():
        parts = line.split("\t")
        if parts:
            keys.add(parts[0].strip())
            if len(parts) > 1:
                names[parts[0].strip()] = parts[1].strip()
    return keys, names


def scan_templates():
    """name -> (guid, statsname); attributes are alphabetical, so per node the order is
    MapKey (own guid) -> Name -> Stats -> Type; each MapKey opens a record."""
    out = {}
    name_re = re.compile(r'<attribute id="Name" type="LSString" value="([^"]+)"')
    mapkey_re = re.compile(r'<attribute id="MapKey" type="FixedString" value="([^"]+)"')
    stats_re = re.compile(r'<attribute id="Stats" type="FixedString" value="([^"]*)"')
    type_re = re.compile(r'<attribute id="Type" type="FixedString" value="([^"]+)"')

    def flush(cur):
        if cur.get("name") and cur.get("guid") and cur.get("type") == "character":
            out[cur["name"]] = (cur["guid"], cur.get("stats", ""))

    for fn in LSX_FILES:
        p = RT / fn
        if not p.is_file():
            print(f"WARN: missing {p}")
            continue
        cur = {}
        for line in p.read_text(errors="replace").splitlines():
            m = mapkey_re.search(line)
            if m:
                flush(cur)
                cur = {"guid": m.group(1)}
                continue
            m = name_re.search(line)
            if m and cur.get("guid"):
                cur["name"] = m.group(1)
                continue
            m = stats_re.search(line)
            if m and cur.get("guid"):
                cur["stats"] = m.group(1)
                continue
            m = type_re.search(line)
            if m and cur.get("guid"):
                cur["type"] = m.group(1)
        flush(cur)
    return out


def main():
    stats = load_stats()
    dump_keys, dump_names = load_dump_keys()
    templates = scan_templates()
    print(f"stats entries: {len(stats)}; root templates (character): {len(templates)}; dump keys: {len(dump_keys)}")

    rows = {}
    for name, (guid, statsname) in templates.items():
        if BAD_NAME.search(name) or BAD_STATS.search(statsname):
            continue
        if statsname not in stats:
            continue
        t, hp = resolve_type(statsname, stats)
        if not t or hp is None:
            continue
        try:
            hp = int(hp)
        except ValueError:
            continue
        # must be instantiable per the live dump
        if dump_keys and guid not in dump_keys:
            continue
        ac = resolve_field(statsname, stats, "Armor")
        strength = resolve_field(statsname, stats, "Strength")
        dex = resolve_field(statsname, stats, "Dexterity")
        con = resolve_field(statsname, stats, "Constitution")
        passives = resolve_field(statsname, stats, "Passives") or ""
        if BAD_PASSIVE.search(passives):
            continue
        ea = "ExtraAttack" in passives
        level = resolve_field(statsname, stats, "Level")
        prof = resolve_field(statsname, stats, "Proficiency Group") or ""
        unarmed = resolve_field(statsname, stats, "UnarmedAttackAbility") or ""
        cost = max(1, round(hp / 10))
        try:
            level = int(level) if level else 1
        except ValueError:
            level = 1
        rows[name] = (guid, t, hp, cost, statsname, level,
                      ac, strength, dex, con, ea, prof, unarmed != "")

    print(f"generic spawnable creatures: {len(rows)}")
    bytype = {}
    for name, (guid, t, hp, cost, sn, level, ac, strength, dex, con, ea, prof, unarmed) in rows.items():
        bytype.setdefault(t, []).append((name, guid, hp, cost, level, ac, strength, dex, con, ea, prof, unarmed))
    for t in sorted(bytype):
        print(f"  {t}: {len(bytype[t])}")

    def num(v):
        try:
            return int(v)
        except (TypeError, ValueError):
            return None

    lines = ["-- Auto-generated by tools/build_creature_db.py - do not edit by hand.",
             "-- ChaosReinforcements creature DB: generic spawnable root templates,",
             "-- grouped by creature type. {id, hp, cost = hp/10, ac (Armor), str, dex, con,",
             "-- ea = ExtraAttack passive, prof = Proficiency Group, unarmed = UnarmedAttackAbility,",
             "-- lvl = native stat Level (rarely > 1; gated at pick time vs player level)",
             "-- - NATIVE stat blocks; SetLevel does not rescale them. prof/unarmed drive",
             "-- equipment choice (innate attackers have no prof group at all).",
             "CHAOS_DB = {"]
    for t in sorted(bytype):
        lines.append(f"  {t} = {{")
        for name, guid, hp, cost, level, ac, strength, dex, con, ea, prof, unarmed in sorted(bytype[t]):
            extra = f", lvl = {level}" if level > 1 else ""
            extra += f", ac = {num(ac)}" if num(ac) is not None else ""
            extra += f", str = {num(strength)}" if num(strength) is not None else ""
            extra += f", dex = {num(dex)}" if num(dex) is not None else ""
            extra += f", con = {num(con)}" if num(con) is not None else ""
            extra += ", ea = true" if ea else ""
            if unarmed:
                extra += ", unarmed = true"
            if prof and prof != "None":
                extra += f', prof = "{prof}"'
            lines.append(f'    {{ id = "{name}_{guid}", hp = {hp}, cost = {cost}{extra} }},')
        lines.append("  },")
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    sys.exit(main())
