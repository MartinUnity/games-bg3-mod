# AGENTS.md

## What this repo is

A BG3 "mod" made by editing game files directly: this repo *is* the game's
`Data/Public/` folder, cloned in place (no pak/mod build step — that's what
keeps achievements working). Game data lives in four layers: `Gustav/`,
`GustavDev/`, `Shared/`, `SharedDev/`; an edit takes effect by matching the
vanilla file path and entry name (override).

Where things live:
- Items/spells/passives/balance: `<Layer>/Stats/Generated/Data/*.txt`
  (items: `Armor.txt`, `Weapon.txt`; spells: `Spell_*.txt`; plus `Passive.txt`,
  `Status_BOOST.txt`, `Character.txt`; global balance in `Shared/.../Data.txt`,
  XP curves in `XPData*.txt`)
- Loot: `<Layer>/Stats/Generated/TreasureTable.txt`
- No loca/story files here — those live outside the repo (`Data/Mods/*/Story/`)
- `bg3-vanilla-data/` is a gitignored unpack of vanilla data, used as baseline

After touching treasure tables, validate:
`python3 tools/validate_treasure.py` (exit 1 on duplicate entry names or
dangling `I_`/`T_` references; `--strict` escalates warnings)

## docs/ — reference material

- `overview.md` — repo-wide orientation: layers, what has been changed, how
  overrides load. Start here.
- `drop-chains.md` — drop-side loot wiring: what is editable (table pool
  contents) vs binary/uneditable (encounter→table wiring), `subtable "x,y"`
  semantics, probability math, injected parent tables. Most current of the
  treasure docs.
- `item-chains.md` — vendor-side chain (trader → treasure tables) and Boosts
  grammar. Mostly current, but its §5 "orphaned wrapper" bug and §6 necklace
  plan were superseded by drop-chains §5/§6 — trust drop-chains there.
- `larian_treasuretables_description.md` — official Larian treasure-table
  format reference (columns, DropCount, rarity weights).

Update these docs when you change how items/loot are wired; they are the
project's memory.

## Subagent delegation (guideline, not a rule)

Context is small (~128K), so treat it as a budget: keep the main thread for
user interaction, planning, and final integration. Consider a subagent when
working inline would burn a lot of it — multi-file research (subagent reads,
you get a digest), long/noisy command output, drafting a large self-contained
chunk whose spec can be stated fully, or a fresh-eyes review of a plan/diff.

Skip delegation when the task is smaller than the brief it needs, needs tight
back-and-forth, or can't be described self-contained — and use judgment; this
is a default, not the only allowed way.

If delegating: briefs must be self-contained (objective, exact paths,
definition of done, report format); reports must come back short (~400 words
max, file path + a few lines if the output is a file, never raw transcripts
or full file dumps).
