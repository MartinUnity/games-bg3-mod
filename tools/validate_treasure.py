#!/usr/bin/env python3
"""Validate item references in the mod's treasure tables.

Checks:
  1. Duplicate `new entry` / `new treasuretable` names within a single file (error).
  2. Every `object category` reference in TreasureTable.txt resolves to a known
     treasure table (`T_...`) or item entry (`I_...` / raw name) in the repo
     layers, optionally against the vanilla unpack (default: bg3-vanilla-data).

Usage: python3 tools/validate_treasure.py [--vanilla PATH] [--quiet]
Exit code 1 if errors are found, 0 otherwise.
"""
import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LAYERS = ["Gustav", "GustavDev", "Shared", "SharedDev"]
DATA_GLOBS = ["Stats/Generated/Data/*.txt", "Stats/Generated/Data/**/*.txt"]
TABLE_GLOB = "Stats/Generated/TreasureTable.txt"

RE_ENTRY = re.compile(r'^new entry "([^"]+)"')
RE_TABLE = re.compile(r'^new treasuretable "([^"]+)"')
RE_OBJECT = re.compile(r'^object category "([^"]+)"')


def parse_files(paths, collect_entries, collect_tables, collect_objects):
    for p in paths:
        if not p.exists():
            continue
        with open(p, encoding="utf-8", errors="replace") as f:
            for lineno, line in enumerate(f, 1):
                line = line.strip()
                m = RE_ENTRY.match(line)
                if m:
                    collect_entries.setdefault(str(p), []).append((m.group(1), lineno))
                    continue
                m = RE_TABLE.match(line)
                if m:
                    collect_tables.setdefault(str(p), []).append((m.group(1), lineno))
                    continue
                m = RE_OBJECT.match(line)
                if m:
                    collect_objects.setdefault(str(p), []).append((m.group(1), lineno))


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--vanilla", default=str(ROOT / "bg3-vanilla-data"),
                    help="path to vanilla unpack (default: bg3-vanilla-data)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()
    quiet = args.quiet

    repo_tables, repo_objects = {}, {}
    table_paths = []
    for layer in LAYERS:
        p = ROOT / layer / TABLE_GLOB
        if p.exists():
            table_paths.append(p)
    parse_files(table_paths, {}, repo_tables, repo_objects)

    repo_entries = {}
    entry_paths = []
    for layer in LAYERS:
        for g in DATA_GLOBS:
            entry_paths.extend((ROOT / layer).glob(g))
    entry_paths = sorted(set(entry_paths))
    parse_files(entry_paths, repo_entries, {}, {})

    vanilla_root = Path(args.vanilla)
    vanilla_tables, vanilla_entries, vanilla_refs = {}, {}, {}
    vpaths = []
    if vanilla_root.is_dir():
        for top in ("Gustav", "Shared"):
            for layer in LAYERS:
                base = vanilla_root / top / "Public" / layer
                vpaths.append(base / TABLE_GLOB)
                vpaths.extend((base / "Stats" / "Generated" / "Data").glob("*.txt"))
                vpaths.extend((base / "Stats" / "Generated" / "Data").glob("*/*.txt"))
        parse_files(vpaths, vanilla_entries, vanilla_tables, vanilla_refs)
        if not quiet:
            print(f"[vanilla] {len(vpaths)} files, {sum(len(v) for v in vanilla_entries.values())} entries, "
                  f"{sum(len(v) for v in vanilla_tables.values())} tables")

    # 1. duplicates within a file
    errors, warnings = [], []
    for label, store in (("entry", repo_entries), ("treasuretable", repo_tables)):
        for fpath, items in store.items():
            seen = {}
            for name, lineno in items:
                if name in seen:
                    errors.append(f"{fpath}:{lineno}: duplicate {label} '{name}' (first at line {seen[name]})")
                else:
                    seen[name] = lineno

    # 2. reference resolution
    table_names = {n for f in repo_tables.values() for n, _ in f} | \
                  {n for f in vanilla_tables.values() for n, _ in f}
    item_names = {n for f in repo_entries.values() for n, _ in f} | \
                 {n for f in vanilla_entries.values() for n, _ in f}

    vanilla_ref_set = {r for refs in vanilla_refs.values() for r, _ in refs}

    for fpath, refs in sorted(repo_objects.items()):
        for ref, lineno in refs:
            if ref.startswith("T_"):
                if ref[2:] not in table_names:
                    msg = f"{fpath}:{lineno}: undefined treasure table {ref}"
                    (warnings if ref in vanilla_ref_set else errors).append(
                        msg + (" (already dangling in vanilla)" if ref in vanilla_ref_set else ""))
            elif ref.startswith("I_"):
                if ref[2:] not in item_names:
                    msg = f"{fpath}:{lineno}: undefined item {ref}"
                    (warnings if ref in vanilla_ref_set else errors).append(
                        msg + (" (already dangling in vanilla)" if ref in vanilla_ref_set else ""))
            else:
                if ref not in item_names and ref not in table_names:
                    warnings.append(f"{fpath}:{lineno}: unknown category '{ref}' (not an entry in repo/vanilla)")

    for w in warnings:
        if not quiet:
            print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)
    if not quiet:
        print(f"[repo] {len(table_paths)} treasure files, {sum(len(v) for v in repo_tables.values())} tables, "
              f"{sum(len(v) for v in repo_entries.values())} entries")
        print(f"result: {len(errors)} error(s), {len(warnings)} warning(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
