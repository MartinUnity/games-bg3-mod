# AGENTS.md

## Use git as snapshot

Check git log for reference; basically commit work as snapshots for potential restore at point-in-time.
The per-version chaos-engine changelog lives in commit messages — they are full entries:
`git log --oneline --grep='^v3'`, search e.g. `--grep=v3.44`.

## Where new findings go (keep this file lean)

AGENTS.md is injected into every session, so it holds only rules, pointers, and landmines —
never version narrative, never feature internals. Budget: ~10KB.

- New durable API/engine finding → append to `docs/GOTCHAS.md` (promote here only a
  one-liner if a session could trip over it without looking).
- State of play / what's open now → `docs/HANDOVER.md` (newest entry on top; when an
  entry is fully superseded, cut it — git log is the archive).
- "Could look into" → `docs/backlog.md`.
- Version story ("we tried X, then Y") → the commit message you're already writing.

## What this repo is

A BG3 "mod" made by editing game files directly: this repo *is* the game's
`Data/Public/` folder, cloned in place (no pak/mod build step for overrides — that's what
keeps achievements working; the SE mod is a separate packed artifact). Game data lives in
four layers: `Gustav/`, `GustavDev/`, `Shared/`, `SharedDev/`; an edit takes effect by
matching the vanilla file path and entry name (override).

Where things live:
- Items/spells/passives/balance: `<Layer>/Stats/Generated/Data/*.txt`
  (items: `Armor.txt`, `Weapon.txt`; spells: `Spell_*.txt`; plus `Passive.txt`,
  `Status_BOOST.txt`, `Character.txt`; global balance in `Shared/.../Data.txt`,
  XP curves in `XPData*.txt`)
- Loot: `<Layer>/Stats/Generated/TreasureTable.txt`
- Story/goal text: masters in `docs/goals/MARTIN_*.txt` (CRLF, in git) deployed via
  `tools/deploy_story.sh --copy` into the LIVE story mount
  `Data/Mods/<Module>/Story/RawFiles/Goals/` (own file names work there — E8)
- Lua / Script Extender (the product route: randomised spawn pools need Lua logic):
  mod workspace `mods/chaos-reinforcements/`, packed with `tools/pack_mod.sh`;
  fundamentals in `docs/lua-modding.md`, upstream API vendored at
  `docs/vendor/bg3se-Lua-API.md` — **grep the vendored API before using any
  `Ext.*`/`Osi.*` name.**
- Difficulty hook (dormant): `Shared/.../Data/Character.txt` `_Base` → `DifficultyStatuses`
  → the `HEALTHBOOST_HARDCORE` override at `GustavDev/Stats/Generated/Data/Status_BOOST.txt`
  is **DISABLED** (Boosts commented out for calibration — grep before trusting line numbers);
  superseded by Lua-side spawn difficulty. Story gate: `DB_HonorMode_Enabled(1)`.

## Landmines (details + more in `docs/GOTCHAS.md`)

- ⚠️ Loading is keyed on **file identity**: overrides inside vanilla-defined files apply,
  but **invented file names under `Data/Public` are NOT loaded**; new names count only
  inside a `.pak`. The `Data/Public/<Module>/Story/` mount never fires — the live story
  channel is the `Data/Mods/.../Story/RawFiles/Goals/` mount.
- ⚠️ Pak RootTemplates load as binary **`.lsf` ONLY** (lsx-only = silently ZERO
  templates); `pack_mod.sh` auto-converts staged `.lsx`.
- ⚠️ Goal files: a whole-file grammar error **refuses new-game creation**; a wrong name
  in ONE rule can drop just that rule silently. Always run `tools/check_goal.py`.
- ⚠️ Server Lua: **`os` is nil**; `Ext.Print` nil on server; RNG = `math.random` only.
- ⚠️ SE v33 logging needs `"LogRuntime": true` in `bin/ScriptExtenderSettings.json`
  (`LogEnabled`/`bg3-print.log` obsolete); logs live in the Larian profile
  (`Script Extender Logs/…`, mod log `Script Extender/ChaosReinforcements.log`).
- ⚠️ SE databases are keyed by **arity** (`DB_Is_InCombat:Get(nil, nil)`); Osiris
  CALLs return nil even on success (only explicit `false` = refusal).
- ⚠️ `pcall` can't survive native faults: `Osi.SetLevel` hard-crashed bg3.exe — and it
  only set the level NUMBER anyway. Difficulty = pick-time gating.
- ⚠️ Stats gotchas: real level = root-template **LevelOverride** (not `data "Level"`);
  ability tokens must be spelled out (`Strength`, NOT `STR` — abbreviations silently
  dropped); `Progressions` refs UCL **TableUUIDs** exactly; LevelOverride+Progressions
  grant real levels on top of the cumulative Vitality curve → set Vitality = level-1 pool.
- ⚠️ Visuals: body-armor art is BAKED into `CharacterVisualResourceID` — BG3 never
  attaches body gear to NPC bodies (hand props only); explicit `VisualTemplate=""` +
  no own CVRID = invisible mob; parent/donor ids must be root-template **MapKeys**
  (runtime instance GUIDs → invisible).
- ⚠️ Behaviour: making camp fires NO `LevelLoaded` — only `TeleportedToCamp`/
  `TeleportedFromCamp`; loading a save into a fight re-fires `CombatStarted` (~12s after
  SessionLoaded); spawn positions are unsettled briefly after creation (settle guard).
- ⚠️ Spell ids/class/level pass TWO gates: `tools/spell_registry.py` +
  `tools/parse_wiki_spells.py --check` — BG3 deviates from the 5e PHB.
- ⚠️ Proton: `WINEDLLOVERRIDES="DWrite.dll=n,b"` required to launch; black-screen hangs
  = alt-tab swapchain thrash → use **Borderless window**; live load order is
  `PlayerProfiles/Public/modsettings.lsx` (base module **GustavX**), not the stale 2024 file.
- A loaded mod flags the save as modded (achievements off — user doesn't care).
- ⚠️ Do NOT re-unpack the 16G vanilla data locally (`bg3-vanilla-data/` is gitignored and
  empty): the working unpack is `/home/martin/Documents/mods/bg3-new/bg3-vanilla-data`
  (STATS ONLY — race strings from stats `_Type` chains or discovery logs). Vanilla .paks
  are in `Data/` (NOT `Data/Paks`); `tools/divine.sh` needs absolute paths.

## Chaos engine — current state

SE Lua mod `mods/chaos-reinforcements/` (pak, Script Extender v33): combat
reinforcements + wild ambushes + CHAOST team composer; current version **v3.47b**
(class-build roster: 178 entries × 11 donors = **1958 templates — `!chaos_root` expects
1958**; rolled spell kits + registry gates). Engine internals live in the code
(`Server/{Common,CreatureDB,Equip,Chaos}.lua`, loaded in that order) — not documented here.
Console commands (`!chaos`, `!chaos_status`, `!chaos_wolf`, `!chaos_root`, `!chaos_force`):
`docs/console-commands.md`. Per-version history: `git log --grep=v3`. Open items: `docs/HANDOVER.md`.

## Validate after touching things

- Treasure tables: `python3 tools/validate_treasure.py` (exit 1 on duplicate entry
  names or dangling `I_`/`T_` refs; `--strict` escalates warnings)
- Story goals: `python3 tools/check_goal.py` (validates `MARTIN_*.txt` against
  `story_header.div`: unknown calls/queries/events, misplaced `;`, non-CRLF, QUERY-in-THEN
  etc.). `tools/deploy_story.sh` (--dry-run default, `--copy`, `--remove`) mirrors masters
  into the story mount; `tools/e8b_inject.py` (--dry-run/--inject/--status/--restore) is
  the E8b story-mount probe tool (restores from gitignored `tools/e8b_backup/`).
- Team templates / spells: `tools/gen_teams.py` hard-validates against
  `tools/spell_registry.py`; run `tools/parse_wiki_spells.py --check` after registry edits;
  offline Lua syntax check via python+lupa (venv `/tmp/opencode/luachk`).
- Pak: `tools/pack_mod.sh` (+ `tools/divine.sh`; unpack verb
  `divine -a extract-package -g bg3`; absolute paths).

## docs/ — reference material

- `GOTCHAS.md` — durable API/engine findings & landmines (append new ones here).
- `overview.md` — repo-wide orientation: layers, what has been changed, how
  overrides load. Start here.
- `HANDOVER.md` — dated state-of-play, newest on top (rotate old entries out — git keeps them).
- `backlog.md` — parking lot for "could look into" items. Move items to HANDOVER
  next-moves when they graduate.
- `drop-chains.md` — drop-side loot wiring: editable pool contents vs binary
  encounter→table wiring, `subtable "x,y"` semantics, probability math. Most current
  treasure doc. `item-chains.md` — vendor-side chain + Boosts grammar (its §5/§6 were
  superseded by drop-chains §5/§6 — trust drop-chains there).
- `encounters.md` — cookbook of every route to add mobs/encounter pressure on this
  install (SE Lua spawns = product route, story goals, `.lsf` pre-placement, loot
  re-wiring, custom stats/templates — and what is ruled out). Read before designing
  encounter features.
- `console-commands.md` — every in-game `!chaos*` command: what it does, gates skipped
  vs respected, sample output, raw-Lua escape hatch, wishlist. Update when adding or
  removing a RegisterConsoleCommand.
- `lua-modding.md` — SE fundamentals on this box; `spells-categories.md` — rolled
  spell-kit design; `wiki-dumps/` — class-spell ground truth; `vendor/bg3se-Lua-API.md`
  — vendored upstream API.
- `spawn-chains.md` — more mobs on existing encounters via the Osiris goal channel:
  primitives, spawn-position solving, ranked recipes, experiment E1 (§12 = how tested).
  **Headline verdicts in §1/§3 predate the 2026-10-31 E8/E8b resolution** — read §3.1.2
  and that banner first.
- `larian_treasuretables_description.md` — official Larian treasure-table format
  reference (columns, DropCount, rarity weights).

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
