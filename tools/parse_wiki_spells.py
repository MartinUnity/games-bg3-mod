#!/usr/bin/env python3
"""
parse_wiki_spells.py - parse bg3.wiki class spell-list pages (owner's
`lynx -dump` captures in docs/wiki-dumps/) and cross-check them against
tools/spell_registry.py. The wiki is the authoritative source for which
class can learn which spell IN BG3 (it deviates from the 5e PHB - e.g. BG3
druids get Thunderwave, Blight, Wall of Fire but NOT Mass Healing Word).

Dump one page per class:
  lynx -dump https://bg3.wiki/wiki/List_of_Druid_spells > docs/wiki-dumps/druid_spells.txt
Filenames: <class>_spells.txt with class in
  bard cleric druid paladin ranger sorcerer warlock wizard
  arcanetrickster eldritchknight

Table rows in the dump look like:
    [50]Guidance [51]Guidance  C Upcast Icon.png Action ...
    [171]Blight [172]Blight 4 Upcast Icon.png Action + Level 4 Spell Slot ...
(level token = C or 1-6, right after the second link)

Usage:
  python3 tools/parse_wiki_spells.py             # parse summary per class
  python3 tools/parse_wiki_spells.py --check     # diff vs spell_registry (warnings only)
"""
import pathlib
import re
import sys

DUMPS = pathlib.Path(__file__).resolve().parent.parent / "docs" / "wiki-dumps"

CLASS_BY_FILE = {
    "bard": "bard", "cleric": "cleric", "druid": "druid",
    "paladin": "paladin", "ranger": "ranger", "sorcerer": "sorcerer",
    "warlock": "warlock", "wizard": "wizard",
    "arcanetrickster": "arcane_trickster", "eldritchknight": "eldritch_knight",
}

ROW = re.compile(
    r'^\s*\[\d+\](.+?)\s+\[\d+\][^\n]*?\s([C1-6])\s+'
    r'(Upcast|Action|Bonus|Reaction|Legend|None|No action|Instant|Mythic|Masked)',
    re.M)


def norm(name):
    """Spell-name normalisation for wiki <-> registry matching."""
    n = name.strip().lower()
    n = n.replace("\u2019", "'").replace("\u2018", "'")
    n = re.sub(r"\s*\((cantrip|spell|[a-z]+)\)\s*", " ", n)  # "(cantrip)", "Bane (spell)", damage tags
    n = n.replace("armour", "armor")                         # bg3.wiki uses British spelling
    n = re.sub(r"\s+", " ", n).strip()
    # wiki singular/plural quirks ("Conjure Woodland Being(s)"):
    n = re.sub(r"beings?$", "being", n)
    return n


def norm_keys(rows):
    """{norm: lvl} with extra slash-alias keys (Blindness/Deafness -> Blindness)."""
    out = {}
    for k, v in rows.items():
        k = norm(k)
        out[k] = v
        if "/" in k:
            out.setdefault(k.split("/")[0].strip(), v)
    return out


def parse_file(path):
    """{normalised spell name: bg3 level int} from one lynx dump."""
    txt = path.read_text(errors="replace")
    rows = {}
    for name, lvl, _cast in ROW.findall(txt):
        rows[norm(name)] = 0 if lvl == "C" else int(lvl)
    return rows


def load_all():
    out = {}
    for path in sorted(DUMPS.glob("*_spells.txt")):
        cls = CLASS_BY_FILE[path.stem.split("_")[0]]
        out[cls] = parse_file(path)
    return out


def check():
    import importlib.util
    here = pathlib.Path(__file__).resolve().parent
    spec = importlib.util.spec_from_file_location("spell_registry",
                                                  here / "spell_registry.py")
    sr = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(sr)
    wiki = {c: norm_keys(rows) for c, rows in load_all().items()}
    manual = getattr(sr, "WIKI_EXCEPTIONS", {})
    features = getattr(sr, "FEATURE_IDS", set())
    probs = []
    for sid, (name, lvl, classes) in sr.REGISTRY.items():
        if sid in features or not classes:
            continue  # class-feature ids and banned ids are not on class lists by design
        n = norm(name)
        cands = [n] + [p.strip() for p in n.split("/")] if "/" in n else [n]
        exc = set(manual.get(sid, {}))

        def wl_get(wl):
            for c in cands:
                if c in wl:
                    return wl[c]
            return None
        # 1) every class the registry claims must list the spell in its wiki page
        for cls in classes - exc:
            wl = wiki.get(cls)
            if wl is None:
                continue
            w = wl_get(wl)
            if w is None:
                probs.append(f"{sid}: registry says {cls}, but {name} is NOT "
                             f"in wiki {cls} list")
            elif w != lvl:
                probs.append(f"{sid}: registry lvl {lvl}, wiki {cls} says {w}")
        # 2) spell level + hidden class memberships
        for cls, wl in wiki.items():
            if cls in classes or cls in exc or wl_get(wl) is None:
                continue
            w = wl_get(wl)
            if w != lvl:
                probs.append(f"{sid}: registry lvl {lvl}, wiki {cls} lists it "
                             f"at {w}")
            else:
                probs.append(f"{sid}: wiki {cls} lists {name} but registry "
                             f"classes are {'/'.join(sorted(classes)) or 'none'}")
    print(f"cross-checked {len(sr.REGISTRY)} registry entries against "
          f"{len(wiki)} wiki class dumps")
    if probs:
        print("\n".join("  " + p for p in probs))
        print(f"\n{len(probs)} discrepancies (review, then fix spell_registry.py)")
        return 1
    print("registry matches all wiki class lists")
    return 0


def main():
    if "--check" in sys.argv[1:]:
        sys.exit(check())
    wiki = load_all()
    for cls, rows in wiki.items():
        by_lvl = {}
        for n, l in rows.items():
            by_lvl.setdefault(l, []).append(n)
        counts = " ".join(f"L{l}:{len(v)}" for l, v in sorted(by_lvl.items()))
        print(f"{cls:17} {len(rows):3} spells   {counts}")


if __name__ == "__main__":
    main()
