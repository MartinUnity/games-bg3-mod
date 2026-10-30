#!/usr/bin/env python3
"""Sanity-check an Osiris goal file before deploying it.

We hand-edit story goal files (docs/spawn-chains.md) and a broken one fails silently:
the story compiler skips it, or drops the rule that used an unknown name. This catches
the mechanical mistakes that grammar makes easy:

  - section markers missing or out of order (INIT / KB / EXIT / ENDEXIT)
  - wrong line endings (every vanilla goal file on this install is CRLF)
  - a condition line that ends with ';', or a THEN action that does not
  - a call/query/event name the engine does not expose -> typo, or a helper PROC that
    only exists in some other module's goals. Checked against story_header.div
    (the machine-generated list of installed calls/queries/events); SysClear/SysCount
    are engine helpers the header does not list, so Sys* is allowed.
  - our own DB_/QRY_/PROC_ names used without ever being introduced in the same file,
    unless some vanilla goal introduces them (DB_CurrentLevel, DB_Defeated, ...).

Usage:
    tools/check_goal.py SharedDev/Story/RawFiles/Goals/MARTIN_Reinforcements.txt [...]
    tools/check_goal.py            # every MARTIN_*.txt goal in the repo

Exit 0 = clean, 1 = problems found.
"""
import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MODS = REPO.parent / "Mods"
HEADERS = sorted(MODS.glob("*/Story/RawFiles/story_header.div"))
GOALS = sorted(MODS.glob("*/Story/RawFiles/Goals/*.txt"))

SECTIONS = ["INITSECTION", "KBSECTION", "EXITSECTION", "ENDEXITSECTION"]
RULE_KINDS = {"PROC", "QRY"}
KEYWORDS = {"IF", "AND", "OR", "NOT", "THEN", "PROC", "QRY"}
LOCAL = re.compile(r"^(DB_|QRY_|PROC_)")
NAME_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\s*\(")
FACT_AT_LINE_START = re.compile(r"^(?:NOT\s+)?(DB_[A-Za-z0-9_]*)\s*\(")


def engine_api() -> set[str]:
    """call/query/event names the engine exposes."""
    names: set[str] = set()
    for header in HEADERS:
        for line in header.read_text(encoding="utf-8", errors="replace").splitlines():
            m = re.match(r"\s*(?:call|query|event)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", line)
            if m:
                names.add(m.group(1))
    return names


def vanilla_facts() -> tuple[set[str], set[str]]:
    """DB_ predicates and QRY_/PROC_ rules introduced by at least one vanilla goal file."""
    facts: set[str] = set()
    procs: set[str] = set()
    for goal in GOALS:
        lines = goal.read_text(encoding="utf-8", errors="replace").splitlines()
        for lineno, s, section, in_then, is_decl in statements(lines):
            if is_decl and (s.startswith("QRY_") or s.startswith("PROC_")):
                procs.add(s.split("(")[0])
            elif section == "INITSECTION" or in_then:
                m = FACT_AT_LINE_START.match(s)
                if m:
                    facts.add(m.group(1))
    return facts, procs


def statements(lines: list[str]):
    """Yield (lineno, text, section, in_then, is_rule_declaration)."""
    section, in_then, decl_next = None, False, False
    for i, raw in enumerate(lines, start=1):
        s = raw.strip()
        if not s or s.startswith("//"):
            continue
        if s in SECTIONS:
            section, in_then, decl_next = s, False, False
            continue
        if decl_next:
            decl_next = False
            yield i, s, section, False, True
            continue
        head = s.split()[0].rstrip(";")
        if head in ("IF", "OR"):
            in_then = False
            continue
        if head in RULE_KINDS:
            in_then, decl_next = False, True
            continue
        if head == "THEN":
            in_then = True
            continue
        yield i, s, section, in_then, False


def check(path: pathlib.Path, api: set[str], facts: set[str], procs: set[str]) -> list[str]:
    raw = path.read_bytes()
    problems: list[str] = []
    if b"\r\n" not in raw:
        problems.append("no CRLF line endings (vanilla goal files are CRLF)")
    if b"\r" in raw.replace(b"\r\n", b""):
        problems.append("stray lone CR")

    lines = raw.decode("utf-8", errors="replace").splitlines()
    marks = [s.strip() for s in lines if s.strip() in SECTIONS]
    if marks != [s for s in SECTIONS if s in marks]:
        problems.append(f"section markers out of order: {marks}")

    referenced: set[str] = set()
    introduced: set[str] = set()
    for lineno, s, section, in_then, is_decl in statements(lines):
        if section not in ("INITSECTION", "KBSECTION", "EXITSECTION"):
            continue
        if is_decl:
            introduced.add(s.split("(")[0])
            continue
        if in_then or section == "INITSECTION":
            head = s.split("(")[0].replace("NOT ", "").strip()
            if LOCAL.match(head):
                introduced.add(head)
        if in_then and not s.endswith(";"):
            problems.append(f"line {lineno}: THEN action must end with ';' -> {s[:60]}")
        if not in_then and section != "INITSECTION" and s.endswith(";"):
            problems.append(f"line {lineno}: condition must not end with ';' -> {s[:60]}")
        body = s[4:] if s.startswith("NOT ") else s
        for name in NAME_RE.findall(body.rstrip(";")):
            if name in KEYWORDS:
                continue
            referenced.add(name)

    local_unknown = sorted(
        n for n in referenced
        if n.startswith("DB_") and n not in introduced and n not in facts
    )
    if local_unknown:
        problems.append("DB_ predicate no vanilla goal ever writes (typo?): " + ", ".join(local_unknown))
    proc_unknown = sorted(
        n for n in referenced
        if (n.startswith("QRY_") or n.startswith("PROC_")) and n not in introduced and n not in procs
    )
    if proc_unknown:
        problems.append("QRY_/PROC_ not defined in this file or any vanilla goal: " + ", ".join(proc_unknown))
    engine_unknown = sorted(n for n in referenced if n not in api and not LOCAL.match(n) and not n.startswith("Sys"))
    if engine_unknown:
        problems.append("not declared in story_header.div (typo, or another module's PROC): " + ", ".join(engine_unknown))
    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*", type=pathlib.Path)
    args = ap.parse_args()

    files = args.files or sorted(REPO.glob("*/Story/RawFiles/Goals/MARTIN_*.txt"))
    if not files:
        print("no goal files to check")
        return 0
    if not HEADERS:
        print(f"error: no story_header.div under {MODS}", file=sys.stderr)
        return 1

    api = engine_api()
    facts, procs = vanilla_facts()
    bad = 0
    for f in files:
        problems = check(f, api, facts, procs)
        if problems:
            bad += 1
            print(f"FAIL {f}")
            for p in problems:
                print(f"  - {p}")
        else:
            print(f"ok   {f}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
