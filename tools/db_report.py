#!/usr/bin/env python3
"""Group the CreatureDB pool by power and abilities -> docs/creature-db-report.md.

Reads Server/CreatureDB.lua (ids + native stats) and, when the offline sources are
available (/tmp/opencode/rt/*.lsx + vanilla unpack), also resolves each template's
passives ("notable features") via the stats `using` chain. Rerun after every
build_creature_db.py run:
    python3 tools/db_report.py
"""
import re
import pathlib
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
DB = ROOT / "mods/chaos-reinforcements/Mods/ChaosReinforcements/ScriptExtender/Lua/Server/CreatureDB.lua"
OUT = ROOT / "docs/creature-db-report.md"
RT = pathlib.Path("/tmp/opencode/rt")
VANILLA = pathlib.Path("/home/martin/Documents/mods/bg3-new/bg3-vanilla-data")

ENTRY_RE = re.compile(
    r'\{ id = "([A-Za-z0-9_]+)_([0-9a-f-]{36})", hp = (\d+), cost = (\d+)'
    r'(?:, lvl = (\d+))?(?:, ac = (\d+))?(?:, str = (\d+))?(?:, dex = (\d+))?'
    r'(?:, con = (\d+))?(?:, wis = (\d+))?(?:, cha = (\d+))?'
    r'(?:, ea = (true))?(?:, unarmed = (true))?(?:, prof = "([^"]*)")?')
TYPE_RE = re.compile(r'^\s{2}([A-Za-z]+) = \{')


def load_db():
    types, cur = {}, None
    for line in DB.read_text().splitlines():
        m = TYPE_RE.match(line)
        if m:
            cur = m.group(1)
            types[cur] = []
            continue
        if cur:
            m = ENTRY_RE.search(line)
            if m:
                g = m.groups()
                types[cur].append({
                    "name": g[0], "hp": int(g[2]), "cost": int(g[3]),
                    "lvl": int(g[4]) if g[4] else 1,
                    "ac": int(g[5]) if g[5] else None,
                    "str": int(g[6]) if g[6] else None,
                    "dex": int(g[7]) if g[7] else None,
                    "con": int(g[8]) if g[8] else None,
                    "wis": int(g[9]) if g[9] else None,
                    "cha": int(g[10]) if g[10] else None,
                    "ea": g[11] == "true", "unarmed": g[12] == "true",
                    "prof": g[13] or ""})
    return types


def passives_map(names):
    """template Name -> set of passives (stats using-chain), if sources exist."""
    if not RT.is_dir() or not VANILLA.is_dir():
        return {}
    want = set(names)
    tmap = {}
    name_re = re.compile(r'<attribute id="Name" type="LSString" value="([^"]+)"')
    stats_re = re.compile(r'<attribute id="Stats" type="FixedString" value="([^"]*)"')
    for lx in sorted(RT.glob("*.lsx")):
        last, lasti = None, 0
        for i, line in enumerate(lx.read_text(errors="replace").splitlines()):
            m = name_re.search(line)
            if m:
                last, lasti = m.group(1), i
                if last in want:
                    tmap.setdefault(last, None)
                continue
            m = stats_re.search(line)
            if m and last in want and i - lasti <= 40 and tmap.get(last) is None:
                tmap[last] = m.group(1) or None
                last = None
    entries = {}
    entry_re = re.compile(r'^new entry "([^"]+)"')
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
            m = re.match(r'^data "Passives" "([^"]*)"', line)
            if m and "p" not in entries[cur]:
                entries[cur]["p"] = m.group(1)
                continue
            m = re.match(r'^using "([^"]+)"', line)
            if m and "u" not in entries[cur]:
                entries[cur]["u"] = m.group(1)

    def resolve(st, depth=0):
        e = entries.get(st)
        if e is None or depth > 10:
            return None
        if e.get("p"):
            return e["p"]
        return resolve(e.get("u"), depth + 1)

    out = {}
    for n, st in tmap.items():
        if st:
            pl = resolve(st)
            if pl:
                out[n] = {p.strip() for p in pl.split(";") if p.strip()}
    return out


def bucket(vals, edges):
    counts = defaultdict(int)
    for v in vals:
        if v is None:
            continue
        for e in edges:
            if v <= e:
                counts[e] += 1
                break
        else:
            counts[999] += 1
    return counts


def fmt_rows(rows):
    keys = ("name", "hp", "ac", "str", "dex", "con", "wis", "cha")
    out = ["| " + " | ".join(keys) + " |", "|" + "---|" * len(keys)]
    for r in rows:
        out.append("| " + " | ".join("-" if r.get(k) is None else str(r[k])
                                     for k in keys) + " |")
    return "\n".join(out)


# (player level, hp cap, ac cap, best-stat cap) - mirrors Common.lua GATES
GATES = [(1, 20, 14, 12), (2, 35, 15, 14), (3, 60, 16, 16), (4, 100, 18, 20)]


def passes_at(c, base):
    for lvl, hp, ac, stat in GATES:
        if lvl != base:
            continue
        if c["hp"] > hp:
            return False
        if (c["ac"] or 0) > ac:
            return False
        if max(c["str"] or 0, c["dex"] or 0) > stat:
            return False
        if base <= 2 and c["ea"]:
            return False
        return c["lvl"] <= base + 2
    return True  # level 5+: unrestricted


def main():
    types = load_db()
    allc = [c for pool in types.values() for c in pool]
    pm = passives_map([c["name"] for c in allc])

    lines = ["# CreatureDB pool report", "",
             f"Auto-generated by `tools/db_report.py` from `CreatureDB.lua` "
             f"({len(allc)} creatures in {len(types)} types). "
             "Rerun after rebuilding the DB.", ""]

    lines += ["## Type census", "", "| type | count |", "|---|"]
    for t in sorted(types, key=lambda t: -len(types[t])):
        lines.append(f"| {t} | {len(types[t])} |")

    lines += ["", "## HP distribution", "", "| hp bucket | count |", "|---|"]
    for e, n in sorted(bucket((c["hp"] for c in allc), [10, 20, 35, 60, 100, 200]).items()):
        label = f"<= {e}" if e != 999 else "> 200"
        lines.append(f"| {label} | {n} |")
    lines += ["", "Top 15 highest HP:", "", fmt_rows(sorted(allc, key=lambda c: -c["hp"])[:15]), ""]

    lines += ["", "## AC distribution", "", "| ac bucket | count |", "|---|"]
    for e, n in sorted(bucket((c["ac"] for c in allc), [10, 12, 14, 15, 16, 18]).items()):
        label = f"<= {e}" if e != 999 else "> 18"
        lines.append(f"| {label} | {n} |")
    lines += ["", "Top 10 highest AC:", "",
              fmt_rows(sorted((c for c in allc if c["ac"]), key=lambda c: -c["ac"])[:10]), ""]

    lines += ["", "## Ability outliers", ""]
    for ab in ("str", "dex", "con", "wis", "cha"):
        hi = sorted((c for c in allc if (c[ab] or 0) >= 18), key=lambda c: -c[ab])
        names = ", ".join(f"{c['name']} ({c[ab]})" for c in hi[:8])
        more = ", ..." if len(hi) > 8 else ""
        lines.append(f"- **{ab} >= 18**: {len(hi)}" + (f" — {names}{more}" if hi else ""))
    ea = [c["name"] for c in allc if c["ea"]]
    un = [c["name"] for c in allc if c["unarmed"]]
    lines += ["", f"**ExtraAttack**: {len(ea)} creatures — " + ", ".join(ea[:10])
              + (", ..." if len(ea) > 10 else "")]
    lines += [f"**innate/unarmed attackers** (never get equipment): {len(un)} creatures"]

    lines += ["", "## Gate pass census", "",
              "Creatures pickable at each player level (mirrors Common.lua GATES;", 
              "EA blocked at lvl 1-2, native lvl gate <= base+2, Heavy types need lvl 5):",
              "", "| player lvl | pool size |", "|---|"]
    for base, _, _, _ in GATES:
        n = sum(1 for c in allc if passes_at(c, base))
        lines.append(f"| {base} | {n} |")
    lines.append(f"| 5+ | {len(allc)} |")

    lines += ["", "## Proficiency groups", "", "| prof group | count |", "|---|"]
    profs = defaultdict(int)
    for c in allc:
        profs[c["prof"] or "(none / innate)"] += 1
    for p, n in sorted(profs.items(), key=lambda kv: -kv[1]):
        lines.append(f"| {p} | {n} |")

    if pm:
        carrier = defaultdict(list)
        for c in allc:
            for p in pm.get(c["name"], ()):
                carrier[p].append(c["name"])
        spicy = re.compile(r"Multiattack|DeathBurst|Regeneration|Explode|Summon|"
                           r"PackTactics|MagicResistance|Ethereal|Blindsight|Teleport|"
                           r"Rampage|BloodThirsty|MurderHungry|SelfDestruct|Berserk|"
                           r"Frenzy|Incorporeal|ShadowyRetreat|PreferredTarget|Immune", re.I)
        lines += ["", f"## Notable features (passives), {len(pm)} templates resolved", "",
                  "### Spicy (combat-warping) passives", ""]
        for p in sorted((p for p in carrier if spicy.search(p)),
                        key=lambda p: -len(carrier[p])):
            ex = ", ".join(sorted(carrier[p])[:6])
            more = ", ..." if len(carrier[p]) > 6 else ""
            lines.append(f"- **{p}** ({len(carrier[p])}): {ex}{more}")
        mundane = sorted((p for p in carrier if not spicy.search(p)),
                          key=lambda p: -len(carrier[p]))
        lines += ["", f"### Remaining passives ({len(mundane)} distinct)", ""]
        for p in mundane:
            lines.append(f"- {p} ({len(carrier[p])})")
    else:
        lines += ["", "## Notable features: SKIPPED "
                  "(offline sources missing: /tmp/opencode/rt or vanilla unpack)"]

    hi = [c for c in allc if c["lvl"] > 1]
    lines += ["", "## Native level > 1", "",
              ", ".join(f"{c['name']} (lvl {c['lvl']})" for c in hi) or "(none)"]

    OUT.write_text("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes), creatures: {len(allc)}")


if __name__ == "__main__":
    main()
