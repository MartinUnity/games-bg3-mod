#!/usr/bin/env python3
"""Grow RACE_TO_TYPE (Chaos.lua) from discovery logs.

Parses the ChaosReinforcements.log 'enemy: NAME lvl N race R type T faction F' lines
and reports, per race string:
  - RESOLVED counts (already mapped: race -> type)
  - UNKNOWN counts (type ? - candidates for a new map entry)
  - suggestions: candidate races NOT yet in the map, sorted by frequency,
    with sample template names (the name often contains the creature/stats name,
    which can be cross-checked against vanilla stats _Type chains).

Usage: python3 tools/grow_race_to_type.py [logfile...]
Default log: profile 'Script Extender/ChaosReinforcements.log' (Proton prefix).
Manual step after: add the suggested lines to RACE_TO_TYPE in Chaos.lua.
"""
import re, sys, pathlib, collections

PROFILE = pathlib.Path(
    "/home/martin/.local/share/Steam/steamapps/compatdata/1086940/pfx/drive_c/users/steamuser/"
    "AppData/Local/Larian Studios/Baldur's Gate 3/Script Extender/ChaosReinforcements.log")
MAP = pathlib.Path(__file__).resolve().parent.parent / \
    "mods/chaos-reinforcements/Mods/ChaosReinforcements/ScriptExtender/Lua/Server/Chaos.lua"

enemy_re = re.compile(r"enemy: (\S+) lvl (\S+) race (\S+) type (\S+) faction (\S+)")
mapline_re = re.compile(r'(\w+) = "(\w+)",')

def current_map():
    txt = MAP.read_text()
    start = txt.index("local RACE_TO_TYPE = {")
    end = txt.index("}", start)
    return {m.group(1): m.group(2) for m in mapline_re.finditer(txt[start:end])}

def main():
    files = [pathlib.Path(f) for f in sys.argv[1:]] or [PROFILE]
    known = current_map()
    resolved = collections.Counter()
    unknown = collections.Counter()
    samples = collections.defaultdict(set)
    total = 0
    for f in files:
        if not f.is_file():
            print(f"WARN: no such log: {f}")
            continue
        for line in f.read_text(errors="replace").splitlines():
            m = enemy_re.search(line)
            if not m:
                continue
            total += 1
            name, _, race, typ = m.group(1), m.group(2), m.group(3), m.group(4)
            base = re.sub(r"_[0-9a-fA-F-]{36}$", "", name)
            if typ == "?" or typ == "nil":
                if race != "nil":
                    unknown[race] += 1
                    if len(samples[race]) < 4:
                        samples[race].add(base)
            else:
                resolved[(race, typ)] += 1
    print(f"enemy lines parsed: {total}; map currently has {len(known)} races\n")
    print("RESOLVED (race -> type, with counts):")
    for (race, typ), n in sorted(resolved.items(), key=lambda kv: -kv[1]):
        flag = "" if known.get(race) == typ else "   <-- map says " + str(known.get(race, "MISSING"))
        print(f"  {race:20} -> {typ:12} x{n}{flag}")
    cand = [(r, n) for r, n in unknown.most_common() if r not in known]
    print("\nCANDIDATES (unmapped, frequency-sorted) - verify type vs vanilla stats, then add:")
    if not cand:
        print("  (none new)")
    for r, n in cand:
        print(f'  {r} = "?",  # x{n}  e.g. {", ".join(sorted(samples[r]))}')
    stale = [r for r in known if resolved and r not in {k[0] for k in resolved} and r not in unknown]
    if stale:
        print(f"\nnever seen in these logs (kept, harmless): {', '.join(sorted(stale))}")

if __name__ == "__main__":
    main()
