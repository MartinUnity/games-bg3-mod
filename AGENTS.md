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
- Story/goal text: our own files go in `<Layer>/Story/RawFiles/Goals/MARTIN_*.txt`
  (CRLF, in git). The vanilla goal text still lives outside the repo at
  `Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/Goals/*.txt` —
  944 files, all still stock vanilla (install mtime 2025-09-06). Whether the engine
  compiles loose goal text at all, and from which mount, is **unverified** — see
  `docs/spawn-chains.md` §3. `Data/Mods` is on a read-only mount; only `Data/Public` is
  writable. Vanilla keeps a helper library there — `Shared/Story/RawFiles/Goals/__PROC.txt`
  declares 457 `PROC_`/`QRY_` rules — worth reading, but cross-module visibility is unverified
  so our own files declare everything they use. No loca files anywhere in the repo.
- Difficulty hook: `Shared/Stats/Generated/Data/Character.txt` entry `_Base` carries
  `DifficultyStatuses` (`STATUS_HARD: HEALTHBOOST_HARDCORE` → overridden in
  `GustavDev/Stats/Generated/Data/Status_BOOST.txt`); the story-side equivalent is the
  vanilla predicate `DB_HonorMode_Enabled(1)`, usable from any goal file (maintained by
  `Data/Mods/SharedDev/.../Goals/GLO_HonorMode.txt:66-70`)
- `bg3-vanilla-data/` is gitignored and meant to be an unpack of vanilla data used as a
  baseline; on this checkout it is **absent/empty**, so re-unpack before relying on it

After touching treasure tables, validate:
`python3 tools/validate_treasure.py` (exit 1 on duplicate entry names or
dangling `I_`/`T_` references; `--strict` escalates warnings)

After touching story goals, validate:
`python3 tools/check_goal.py` (checks our `MARTIN_*.txt` goals against
`Data/Mods/*/Story/RawFiles/story_header.div`: unknown calls/queries/events, unknown
`DB_` predicates, misplaced `;`, non-CRLF endings). A broken goal file fails silently
in game. `tools/deploy_story.sh` (--dry-run by default, `--copy`, `--remove`) mirrors
them into the `Data/Mods` story mount when needed.

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
- `spawn-chains.md` — adding **more mobs** to existing encounters in text: the Osiris
  goal-file channel (`CreateAt`/`CreateAtObject`, `DB_HonorMode_Enabled(1)` honour gate,
  combat-group joining, spawn-position solving), what stays binary (level layout),
  ranked recipes, and experiment **E1** (implemented at
  `SharedDev/Story/RawFiles/Goals/MARTIN_Reinforcements.txt`, §12 = how to test it).
  Read §3 first: whether loose goal text loads at all on this install is still unproven.
  Refines drop-chains' "not possible in text" claim.
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
