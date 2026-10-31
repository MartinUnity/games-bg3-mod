# AGENTS.md

## What this repo is

A BG3 "mod" made by editing game files directly: this repo *is* the game's
`Data/Public/` folder, cloned in place (no pak/mod build step — that's what
keeps achievements working). Game data lives in four layers: `Gustav/`,
`GustavDev/`, `Shared/`, `SharedDev/`; an edit takes effect by matching the
vanilla file path and entry name (override).

⚠️ Loading is keyed on **file identity** (`docs/overview.md` §6.1): overrides inside a file vanilla
already defines are applied, but **invented file names under `Data/Public` are not loaded** —
confirmed positive/negative in-game by the owner (the live Honour HP boost works as an appended entry
in an existing `Status_BOOST.txt`; new `MARTIN_*`-style stat files never did). New file names count
only inside a `.pak`, which is also the leading explanation for the null story-goal tests.

Where things live:
- Items/spells/passives/balance: `<Layer>/Stats/Generated/Data/*.txt`
  (items: `Armor.txt`, `Weapon.txt`; spells: `Spell_*.txt`; plus `Passive.txt`,
  `Status_BOOST.txt`, `Character.txt`; global balance in `Shared/.../Data.txt`,
  XP curves in `XPData*.txt`)
- Loot: `<Layer>/Stats/Generated/TreasureTable.txt`
- Story/goal text: our own files go in `<Layer>/Story/RawFiles/Goals/MARTIN_*.txt`
  (CRLF, in git). The vanilla goal text still lives outside the repo at
  `Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/Goals/*.txt` —
  944 files, all still stock vanilla (install mtime 2025-09-06). **Resolved 2026-10-31:** the
  live story channel IS that `Data/Mods` mount — rules appended into a vanilla-named goal file
  there compiled and spawned a wolf in-game (E8b ✅, `docs/spawn-chains.md` §3.1.2), while the
  `Data/Public/<Module>/Story/` mount never fires (E1/E7 nulls). A whole-file grammar error
  *refuses new-game creation* ("likely due to mods"); a bad name in one rule can also drop just
  that rule silently (our imp rule died, wolf rule fired — instance-vs-root templates, §3.1.2).
  E8 (same day) **positive**: *invented* `MARTIN_*.txt` file names compile and fire in that mount
  too — so features ship as our own goal files under
  `Data/Mods/<Module>/Story/RawFiles/Goals/`, mirrored from repo masters in `docs/goals/` via
  `tools/deploy_story.sh --copy` (probes since removed; mount vanilla again). `Data/Mods` is
  writable (ro bind fixed).
  This is the Windows
  build under Proton: prefix `compatdata/1086940`, logs `bin/gold.*.log`, profile
  `…/AppData/Local/Larian Studios/Baldur's Gate 3/` — live load order is
  `PlayerProfiles/Public/modsettings.lsx` (base module **GustavX**, mods enabled), NOT the stale
  2024 root-level file. Vanilla keeps its helper library in
  `Data/Mods` — `Shared/Story/RawFiles/Goals/__PROC.txt`
  declares 457 `PROC_`/`QRY_` rules — worth reading, but cross-module visibility is unverified
  so our own files declare everything they use. No loca files anywhere in the repo.
- Lua / Script Extender route (⚠️ parallel channel, not the override workflow; **user wants this
  for the real feature: randomised spawn pools need Lua logic**): fundamentals in
  `docs/lua-modding.md`, upstream API vendored at `docs/vendor/bg3se-Lua-API.md`, mod workspace
  `mods/more-mobs/`. **SE v33 loads and our Lua runs** (probe v1 wrote its template dump on
  SessionLoaded, 2026-10-31) — the historical problem was invisible errors: v33 logging needs
  `"LogRuntime": true` in `bin/ScriptExtenderSettings.json` (`LogEnabled`/`bg3-print.log` are
  obsolete); logs land in the prefix at `drive_c/users/steamuser/Script Extender Logs/Extender
  Runtime.log`, and probes also file-log to profile `Script Extender/MARTIN_probe.log` via
  `Ext.IO.SaveFile`. `bin/DWrite.dll` = official Oct-12 v33 updater (old kept `.bak-2024`;
  `WINEDLLOVERRIDES="DWrite.dll=n,b"` still required — launch options have it). SE itself stages
  under AppData `BG3ScriptExtender/`, not `bin/`. **Spawn-on-combat PROVEN (probe v3: hostile
  wolf joins fights); chaos engine v1 installed** (`Server/Chaos.lua`: per-combat roll — silence/
  weak swarm/normal/elite/jackpot — 52 curated root templates in tiered pools, `Name_GUID` ids
  from the root-template dump, E8b faction pair verbatim, RNG = `math.random` only
  (`Ext.RandomInteger` doesn't exist, `math.randomseed` throws); log = profile
  `Script Extender/MARTIN_chaos.log`; console `!martin_chaos`/`!martin_wolf`; offline syntax
  check via python+lupa). Pak toolchain: native lslib Divine at
  `tools/divine.sh` + `tools/pack_mod.sh` (proven). A loaded mod flags the save as modded
  (achievements off — user doesn't care).
- Difficulty hook: `Shared/Stats/Generated/Data/Character.txt` entry `_Base` carries
  `DifficultyStatuses` (`STATUS_HARD: HEALTHBOOST_HARDCORE` → live override at
  `GustavDev/Stats/Generated/Data/Status_BOOST.txt:11620-11630`,
  `IncreaseMaxHP(1d6+6);IncreaseMaxHP(Level*2d12)`; the drafts at 11518-11618 in that file are
  commented out, so grep before trusting a line number). The story-side equivalent is the
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
`DB_` predicates, misplaced `;`, non-CRLF endings, and query/call misuse — QUERY-in-THEN etc.;
that class does NOT fail silently: it refuses new-game creation (confirmed 2026-10-31), while a
wrong name in one rule may drop just that rule.
`tools/deploy_story.sh` (--dry-run by default, `--copy`, `--remove`) mirrors
them into the `Data/Mods` story mount when needed. `tools/e8b_inject.py`
(--dry-run/--inject/--status/--restore) is the E8b story-mount test: it appends probe
rules into vanilla-named goal files in `Data/Mods` and restores them from gitignored
`tools/e8b_backup/`.

## docs/ — reference material

- `overview.md` — repo-wide orientation: layers, what has been changed, how
  overrides load. Start here.
- `HANDOVER.md` — dated state-of-play snapshot for a fresh session (open experiments, E7 null
  result, pak-toolchain progress, ranked next moves). Read after `overview.md` when resuming.
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
