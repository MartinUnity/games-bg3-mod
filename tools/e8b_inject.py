#!/usr/bin/env python3
"""E8b: inject the spawn-probe rules INTO existing vanilla goal files in the
Data/Mods story mount (docs/spawn-chains.md sec.3.1.2).

Why: E1/E7 were nulls, but each changed two variables at once (new mount AND new
file name). The stats analogue proves the loader keys on *file identity*, so E8b
appends the same rules verbatim into vanilla-named goal files that are certainly
compiled. Two hosts, so one game restart splits all remaining sub-cases:

  SharedDev/Story/RawFiles/Goals/GLO_HonorMode.txt    -> mount test (docs' pick:
                                                        small, always-compiled)
  GustavDev/Story/RawFiles/Goals/GLO_BackgroundGoals.txt
                                      -> also splits "wrong module" (base module
                                                        per modsettings is
                                                        GustavDev, prologue goals
                                                        live in Gustav/GustavDev;
                                                        this host is an empty
                                                        wrapper, zero own rules)

Rules are global once compiled, so inserting into the host's KBSECTION is enough.

Backups go to tools/e8b_backup/ (gitignored, outside Data/Mods). The first
backup wins and is never overwritten, so re-injecting cannot corrupt the copy.

Usage:
    tools/e8b_inject.py              # dry run: show what would happen
    tools/e8b_inject.py --inject     # backup + inject (refuses if already done)
    tools/e8b_inject.py --status     # marker + backup state per host
    tools/e8b_inject.py --restore    # copy backups back over the hosts

After --inject: restart the game (story text is compiled at startup), fight ONE
combat, count bodies. Extra imp and/or wolf = mount is live. Then --restore.

Exit 0 = ok, 1 = problem.
"""
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
MODS = REPO.parent / "Mods"                  # Data/Mods (sibling of Data/Public)
BACKUP = REPO / "tools" / "e8b_backup"
SRC = REPO / "docs" / "goals" / "MARTIN_SpawnProbe.txt"

HOSTS = [
    MODS / "SharedDev" / "Story" / "RawFiles" / "Goals" / "GLO_HonorMode.txt",
    MODS / "GustavDev" / "Story" / "RawFiles" / "Goals" / "GLO_BackgroundGoals.txt",
]

MARKER = b"DB_MARTIN_ProbeA"                 # present iff our rules are in the host
BANNER = b"// --- MARTIN E8b probe (tools/e8b_inject.py; remove via --restore) ---"
SECTIONS = ["INITSECTION", "KBSECTION", "EXITSECTION", "ENDEXITSECTION"]


def rule_block() -> bytes:
    """KBSECTION body of the master probe file, verbatim, CRLF bytes."""
    raw = SRC.read_bytes()
    start = raw.find(b"KBSECTION\r\n")
    end = raw.find(b"\r\nEXITSECTION", start)
    if start < 0 or end < 0:
        sys.exit(f"error: cannot find KBSECTION..EXITSECTION block in {SRC}")
    return raw[start + len(b"KBSECTION\r\n"):end]


def structural_problems(raw: bytes) -> list[str]:
    """Section markers in order, no stray CR - cheap guard on hand-edited hosts."""
    problems = []
    if raw.count(b"\n") != raw.count(b"\r\n"):
        problems.append("line endings are no longer pure CRLF")
    if b"\r" in raw.replace(b"\r\n", b""):
        problems.append("stray lone CR")
    marks = [s.strip() for s in raw.decode("utf-8", errors="replace").splitlines() if s.strip() in SECTIONS]
    if marks != [s for s in SECTIONS if s in marks]:
        problems.append(f"section markers out of order: {marks}")
    return problems


def backup_of(host: pathlib.Path) -> pathlib.Path:
    return BACKUP / f"{host.parent.parent.parent.parent.name}__{host.name}"


def do_status() -> int:
    ok = True
    for host in HOSTS:
        if not host.is_file():
            print(f"MISSING HOST  {host}")
            ok = False
            continue
        injected = MARKER in host.read_bytes()
        bak = backup_of(host)
        state = "injected" if injected else "pristine"
        bstate = "backup present" if bak.is_file() else "NO BACKUP"
        if not injected and not bak.is_file():
            bstate = "no backup needed (pristine, none taken)"
        print(f"{state:9s}  {bstate:34s}  {host}")
    print(f"source rules: {SRC}" + ("" if SRC.is_file() else "  <- MISSING"))
    return 0 if ok else 1


def do_inject(dry: bool) -> int:
    if not SRC.is_file():
        print(f"error: probe source {SRC} not found", file=sys.stderr)
        return 1
    block = rule_block()
    bad = False
    if not dry:
        BACKUP.mkdir(parents=True, exist_ok=True)
    for host in HOSTS:
        if not host.is_file():
            print(f"error: host missing: {host}", file=sys.stderr)
            bad = True
            continue
        raw = host.read_bytes()
        bak = backup_of(host)
        if MARKER in raw:
            print(f"skip (already injected): {host}")
            continue
        if not bak.is_file() and MARKER in raw:
            print(f"error: injected host without backup, refusing: {host}", file=sys.stderr)
            bad = True
            continue
        idx = raw.find(b"\r\nEXITSECTION")
        if idx < 0:
            print(f"error: no EXITSECTION line in {host}", file=sys.stderr)
            bad = True
            continue
        new = raw[:idx] + b"\r\n" + BANNER + b"\r\n" + block + b"\r\n" + raw[idx:]
        problems = structural_problems(new)
        if problems:
            print(f"error: refusing to write, result would be broken: {host}")
            for p in problems:
                print(f"  - {p}", file=sys.stderr)
            bad = True
            continue
        if dry:
            print(f"would inject {len(block)} bytes of rules into {host}")
            if not bak.is_file():
                print(f"  and back it up to {bak}")
            continue
        if not bak.is_file():
            bak.write_bytes(raw)
            print(f"backed up: {host} -> {bak}")
        host.write_bytes(new)
        print(f"injected: {host}")
    if not dry:
        print("next: restart the game (story compiles at startup), ONE combat, count bodies;")
        print("then: tools/e8b_inject.py --restore")
    return 1 if bad else 0


def do_restore() -> int:
    bad = False
    for host in HOSTS:
        bak = backup_of(host)
        if not bak.is_file():
            print(f"no backup for {host} - left alone")
            continue
        host.write_bytes(bak.read_bytes())
        if host.read_bytes() == bak.read_bytes() and MARKER not in host.read_bytes():
            print(f"restored: {host}")
        else:
            print(f"error: restore verification failed for {host}", file=sys.stderr)
            bad = True
    return 1 if bad else 0


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--dry-run"
    if mode == "--dry-run":
        return do_inject(dry=True)
    if mode == "--inject":
        return do_inject(dry=False)
    if mode == "--status":
        return do_status()
    if mode == "--restore":
        return do_restore()
    print("usage: tools/e8b_inject.py [--dry-run|--inject|--status|--restore]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
