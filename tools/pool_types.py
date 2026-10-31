#!/usr/bin/env python3
"""Tag MARTIN_MoreMobs pool templates with creature type + HP.

Two-step offline resolution:
1. Root templates (converted Shared.pak `Public/Shared/RootTemplates/_merged.lsf` ->
   /tmp/opencode/rt/merged.lsx via tools/divine.sh -a convert-resource -i lsf -o lsx):
   template Name -> Stats stats-entry name (attributes are alphabetical: Name precedes Stats).
2. Vanilla stats files (bg3-vanilla-data unpack, Character*.txt under Stats/Generated/Data):
   stats entry -> `using` chain -> the `_Type` parent (_Beast/_Fiend/_Undead/... = the D&D
   creature type) + base Vitality as a power proxy.

Note: template name != stats name (e.g. Goblins_Male_Melee -> stats "Goblin_Melee").

Usage: tools/pool_types.py --from-lua FILE   # template names harvested from Chaos.lua pools
       tools/pool_types.py NAME [NAME...]
"""
import re
import sys
import pathlib

VANILLA = pathlib.Path("/home/martin/Documents/mods/bg3-new/bg3-vanilla-data")
MERGED = pathlib.Path("/tmp/opencode/rt/merged.lsx")

TYPESET = {"Aberration", "Beast", "Celestial", "Construct", "Dragon", "Elemental", "Fey",
           "Fiend", "Giant", "Humanoid", "Monstrosity", "Ooze", "Plant", "Undead"}


def stats_for_templates(names):
    want = set(names)
    out = {}
    last_name = None
    last_line = 0
    name_re = re.compile(r'<attribute id="Name" type="LSString" value="([^"]+)"')
    stats_re = re.compile(r'<attribute id="Stats" type="FixedString" value="([^"]*)"')
    if not MERGED.is_file():
        print(f"(missing {MERGED}; convert Shared.pak _merged.lsf first - see docstring)")
        return out
    for i, line in enumerate(MERGED.read_text(errors="replace").splitlines()):
        m = name_re.search(line)
        if m:
            last_name, last_line = m.group(1), i
            if last_name in want:
                out.setdefault(last_name, None)
            continue
        m = stats_re.search(line)
        if m and last_name and last_name in want and i - last_line <= 40:
            out[last_name] = m.group(1) or None
            last_name = None
    return out


def load_entries():
    entries = {}
    files = sorted(VANILLA.rglob("Stats/Generated/Data/Character*.txt"))
    entry_re = re.compile(r'^new entry "([^"]+)"')
    using_re = re.compile(r'^using "([^"]+)"')
    vit_re = re.compile(r'^data "Vitality" "(\d+)"')
    for f in files:
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
            if line.startswith("type "):
                continue
            m = using_re.match(line)
            if m and "using" not in entries[cur]:
                entries[cur]["using"] = m.group(1)
                continue
            m = vit_re.match(line)
            if m and "hp" not in entries[cur]:
                entries[cur]["hp"] = int(m.group(1))
    return entries


def resolve(stats, entries, depth=0):
    e = entries.get(stats)
    if e is None or depth > 10:
        return None, None
    parent = e.get("using")
    if parent is None or parent == "_Base":
        return None, e.get("hp")
    ptype = parent.lstrip("_")
    if ptype in TYPESET:
        return ptype, e.get("hp")
    ptype2, hp2 = resolve(parent, entries, depth + 1)
    return ptype2, (e.get("hp") or hp2)


def names_from_lua(path):
    txt = pathlib.Path(path).read_text()
    out = []
    for m in re.finditer(r'"([A-Za-z0-9_]+)_([0-9a-f]{8}-[0-9a-f-]{27})"', txt):
        if m.group(1) not in ("Evil", "Hero"):
            out.append((m.group(1), m.group(2)))
    return out


def main():
    if len(sys.argv) > 2 and sys.argv[1] == "--from-lua":
        pairs = names_from_lua(sys.argv[2])
    else:
        pairs = [(n, None) for n in sys.argv[1:]]
    entries = load_entries()
    print(f"(parsed {len(entries)} vanilla stats entries)")
    tmap = stats_for_templates([n for n, _ in pairs])
    for name, guid in sorted(set(pairs)):
        stats = tmap.get(name)
        t, hp = (resolve(stats, entries) if stats else (None, None))
        g = f"_{guid}" if guid else ""
        print(f"{name}{g}\t{stats or '?'}\t{t or '?'}\t{hp if hp is not None else '?'}")


if __name__ == "__main__":
    main()
