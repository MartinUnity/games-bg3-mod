#!/usr/bin/env python3
"""Build docs/role-catalog.md: the NPC class-progression catalog for humanoid teams.

Sources (all offline):
1. Vanilla Progressions.lsx (Shared + SharedDev): every Progression node = one
   class/subclass/race level with its UUID, Boosts (spell slots, proficiencies),
   PassivesAdded (ExtraAttack@5, RecklessAttack, ...) and Selectors.
   ProgressionType: 0 = class level, 1 = subclass level, 2 = race/base level.
   The NPC_* tracks are Larian's own pre-balanced kits for NPC combatants (no
   player-choice selectors) - the backbone for our role teams.
2. Installed rework-mod Character.txt overrides (EncountersOverhaul,
   Enemies_full_rework, Extra_encounters_plus): which Progressions GUIDs they give
   humanoid enemies - reference for what "dangerous goblins" actually carry.

Output: docs/role-catalog.md (for owner review - iteration 1 of the humanoid-teams plan).
Usage:  python3 tools/role_catalog.py
"""
import re
import pathlib

VANILLA = pathlib.Path("/home/martin/Documents/mods/bg3-new/bg3-vanilla-data")
MINE = pathlib.Path("/tmp/opencode/mine")

ROLE_MAP = [
    # role, display note, candidate NPC tracks in priority order
    ("tank", "frontliner: highest-AC armor + shield, CON-biased stats",
     ["NPC_FlamingFist_Melee_Defender", "NPC_Fighter", "NPC_Paladin"]),
    ("melee_dps", "big 2h or dual-wield bruiser",
     ["NPC_FlamingFist_Melee_Attacker", "NPC_Barbarian", "NPC_Fighter_Rogue"]),
    ("ranged", "bows / special arrows",
     ["NPC_FlamingFist_Melee_Ranger", "NPC_Ranger"]),
    ("caster", "the party-enders",
     ["NPC_FlamingFist_Melee_Caster", "NPC_Wizard", "NPC_Warlock", "NPC_Druid"]),
    ("healer", "heals + healing potions",
     ["NPC_FlamingFist_Melee_Cleric", "NPC_Cleric", "NPC_Druid"]),
]


def parse_progressions():
    rows = []
    # LIVE extracts first (current patch; the 2023 vanilla unpack predates many nodes -
    # the installed rework mods reference GUIDs that only exist post-patch). Rebuild via:
    #   tools/divine.sh -g bg3 -a extract-package -s <Game>/Data/Shared.pak -d /tmp/opencode/prog -x "*Progressions.lsx"
    #   tools/divine.sh -g bg3 -a extract-package -s <Game>/Data/Gustav.pak -d /tmp/opencode/prog -x "*Progressions.lsx"
    live = sorted(pathlib.Path("/tmp/opencode/prog").glob("Public/*/Progressions/Progressions.lsx"))
    # UtutsCoreLibrary = shared NPC-class library the installed rework mods borrow their
    # custom progression GUIDs from (extracted from the installed pak to /tmp/opencode/mine3)
    ututs = sorted(pathlib.Path("/tmp/opencode/mine3").glob("Public/*/Progressions/Progressions.lsx"))
    subs = [str(p) for p in live + ututs] or [
        "Shared/Public/Shared/Progressions/Progressions.lsx",
        "Shared/Public/SharedDev/Progressions/Progressions.lsx",
        "Gustav/Public/Gustav/Progressions/Progressions.lsx",
        "Gustav/Public/GustavDev/Progressions/Progressions.lsx",
    ]
    for sub in subs:
        path = pathlib.Path(sub)
        if not path.exists():
            print(f"missing: {path}")
            continue
        src = path.read_text(errors="replace")
        n = 0
        for b in re.split(r'<node id="Progression">', src)[1:]:
            end = b.find("</node>")
            chunk = b[:end if end != -1 else len(b)]

            def attr(name):
                m = re.search(r'id="%s" type="[^"]*" value="([^"]*)"' % name, chunk)
                return m.group(1) if m else ""

            rows.append(dict(uuid=attr("UUID"), name=attr("Name"), level=attr("Level"),
                             ptype=attr("ProgressionType"), passives=attr("PassivesAdded"),
                             boosts=attr("Boosts"), selectors=attr("Selectors"),
                             improve=attr("AllowImprovement"), table=attr("TableUUID"),
                             src=sub.split("/")[2]))
            n += 1
        print(f"{sub}: {n} nodes")
    return rows


def parse_mod_progressions():
    """Character.txt entries from installed rework mods: entry name -> progressions used."""
    out = []  # (mod, entry, guids)
    for d in sorted(MINE.glob("*/Public/*/Stats/Generated/Data/Character.txt")):
        mod = d.parts[-4]
        cur, guids = None, []
        for line in d.read_text(errors="replace").splitlines():
            m = re.match(r'new entry "([^"]+)"', line)
            if m:
                if cur and guids:
                    out.append((mod, cur, guids))
                cur, guids = m.group(1), []
                continue
            m = re.match(r'data "Progressions" "([^"]*)"', line)
            if m and cur:
                guids += [g.strip() for g in m.group(1).split(";") if g.strip()]
        if cur and guids:
            out.append((mod, cur, guids))
    return out


def main():
    prog = parse_progressions()
    by_uuid = {}
    for r in prog:
        if r["uuid"]:
            by_uuid.setdefault(r["uuid"], r)
    # Character stat "Progressions" fields reference TABLE guids (one table = all levels
    # of a track; the character's Level decides how far it applies) - verified: vanilla
    # stat entries list e.g. Origin_Karlach's barbarian TABLE uuid
    by_table = {}
    for r in prog:
        if r["table"]:
            t = by_table.setdefault(r["table"], dict(name=r["name"], levels={}, nodes=0))
            t["nodes"] += 1
            t["levels"][int(r["level"] or 0)] = r

    npc = [r for r in prog if r["name"].startswith("NPC_") and r["uuid"]]
    # group: class -> {level -> row}
    tracks = {}
    for r in npc:
        tracks.setdefault(r["name"], {})[int(r["level"] or 0)] = r

    lines = []
    w = lines.append
    w("# Role catalog - NPC class progressions for humanoid teams")
    w("")
    w("Auto-generated by `tools/role_catalog.py` (iteration 1 of the humanoid-teams plan).")
    w("Progression node types: **0 = class level**, 1 = subclass level, 2 = race/base level.")
    w("The `NPC_*` tracks are Larian's own pre-balanced NPC kits (no player-choice selectors).")
    w("**The `data \"Progressions\"` stat field references TABLE guids** (one table = all")
    w("levels of a track; the character's `Level` field decides how many levels apply) -")
    w("verified against vanilla (Origin_Karlach's barbarian table) and the rework mods.")
    w("This is how the installed rework mods make goblins dangerous.")
    w("")

    w("## Role -> track proposal")
    w("")
    w("| Role | Notes | Candidate tracks (priority order) |")
    w("|---|---|---|")
    for role, note, cands in ROLE_MAP:
        w(f"| {role} | {note} | {'; '.join(c + (' ✅' if c in tracks else ' ❌ missing') for c in cands)} |")
    w("")
    w("FlamingFist variants are Larian's own ROLE kits (Defender/Attacker/Caster/Cleric/Ranger)")
    w("- the strongest precedent for exactly this feature; prefer them, fall back to the")
    w("generic class tracks.")
    w("")

    w("## NPC class tracks (level -> UUID, key grants)")
    w("")
    for name in sorted(tracks):
        levels = tracks[name]
        maxlvl = max(levels)
        table = levels[min(levels)]["table"]
        w(f"### {name} (levels 1-{maxlvl}, {len(levels)} nodes, TABLE `{table}`)")
        w("")
        w("| Level | UUID | PassivesAdded | Key boosts (slots/profs trimmed) |")
        w("|---|---|---|---|")
        for lvl in sorted(levels):
            r = levels[lvl]
            boosts = "; ".join(b.strip() for b in r["boosts"].split(";") if b.strip())
            boosts = re.sub(r"ProficiencyBonus\(SavingThrow,\w+\);?", "", boosts).strip("; ")
            p = r["passives"] or ""
            w(f"| {lvl} | `{r['uuid']}` | {p} | {boosts[:110]} |")
        w("")

    w("## What the installed rework mods give their humanoids (reference)")
    w("")
    mods = parse_mod_progressions()
    by_name = {}
    for mod, entry, guids in mods:
        for g in guids:
            t = by_table.get(g)
            if t:
                by_name.setdefault((mod, t["name"]), set()).update(sorted(t["levels"]))
    w("Progression tracks referenced, per mod:")
    w("")
    for (mod, name), lvls in sorted(by_name.items()):
        w(f"- **{mod}** -> `{name}` levels {sorted(lvls)}")
    w("")
    w("Sample overridden stat entries (kit composition in practice):")
    w("")
    shown = 0
    for mod, entry, guids in mods:
        resolved = []
        for g in guids:
            t = by_table.get(g)
            resolved.append(t["name"] if t else f"UNKNOWN({g[:8]})")
        w(f"- `{entry}` ({mod.split('_')[0]}): {'; '.join(resolved)}")
        shown += 1
        if shown >= 15:
            w(f"- ... ({len(mods) - shown} more)")
            break
    w("")

    w("## Notes / open questions for iteration 2 (team composer)")
    w("")
    w("- Stats themselves (STR/CON/...) come from the Character stat entry, not progressions;")
    w("  the composer must distribute player-fair point-buy per role.")
    w("- Feats: player tracks have AllowImprovement nodes at L4/8/12; NPC tracks skip them.")
    w("  Feats can still be added via `data \"Passives\"` (mods do: `Alert;MartialAdvantage;...`).")
    w("- Spell lists are NOT in progressions; NPC casters pick them up via spell-set selectors")
    w("  or vanilla caster stat entries (`SpellCastingAbility` + spell slots + class spell list).")
    w("  Verify in iteration 3 whether NPC_Wizard track + casting stat yields a live spellbook.")
    w("- Levels above the NPC track maxima (e.g. NPC_Wizard caps at 6/8): either stack the")
    w("  highest node again (Larian's own multiclass trick: NPC_Fighter_Rogue) or switch to")
    w("  the player track for high levels.")
    w("- **Composition grammar learned from the rework mods (UtutsCoreLibrary)**: an NPC kit")
    w("  = base-class table + subclass table + optional style/feature tables + ASI/feat")
    w("  table, e.g. Fighter + EldritchKnight + GWF style + ActionSurge + TwoHander + Str ASI.")
    w("  Our role generator should emit the same shape. Whether we reuse UCL tables directly")
    w("  (dependency) or write our own vanilla-table equivalents (self-contained) is an")
    w("  owner decision for iteration 2/3 - vanilla NPC_* tables cover base classes only.")
    w("- Track table guids for the vanilla NPC tracks are printed per class below; the stat")
    w("  entry needs `data \"Progressions\" \"<table-guid>\"` (semicolon-join for multi-table).")
    w("")

    out = pathlib.Path("docs/role-catalog.md")
    out.write_text("\n".join(lines))
    print(f"wrote {out}: {len(lines)} lines, {len(tracks)} NPC tracks, {len(mods)} mod kit refs")


if __name__ == "__main__":
    main()
