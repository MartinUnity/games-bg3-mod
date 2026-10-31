# Adding encounters to BG3 — cookbook of every known route

Catalog of every mechanism this project has found (proven or ruled out) for adding mobs /
encounters / encounter pressure to the game on this install (Linux/Proton, text-only editing,
SE v33 available, achievements irrelevant). Cross-refs: `spawn-chains.md` (story channel
forensics + E1–E8b), `lua-modding.md` (SE fundamentals), `drop-chains.md` (loot wiring),
`HANDOVER.md` (state of play). Routes are ranked by how proven they are.

---

## Route 1 — SE Lua runtime spawning (chaos engine) — ✅ PROVEN, THE PRODUCT ROUTE

The engine in `mods/chaos-reinforcements/.../Server/*.lua` does this today. Fully random at runtime,
no level-editing needed.

**Proven primitive chain** (probe v3 + E8b pair, verbatim):

```
created = Osi.CreateAtObject(templateName_GUID, anchor, dx, dy, "", 1)
Osi.SetFaction(created, "Evil_4be9261a-e481-8d9d-3528-f36956a19b17")
Osi.SetHostileAndEnterCombat("Evil_4be9261a-...", "Hero_a1542c81-...", created, anchor)
```

- Template ids = **global root templates** (`Name_GUID` from the live dump; the
  32017-entry `Chaos_root_templates.txt`). Level-placed *instance* ids (`S_*`) do NOT
  resolve as roots.
- Hostility only works with the E8b faction pair verbatim; `GetFaction(host)` returns
  per-player factions (`Hero Player1_<guid>`) and is useless for this; `Evil_fb046e51-…`
  is inert.
- Trigger points available: `CombatStarted` listener (proven), plus any Osiris event
  (`EnteredCombat`, `ObjectTurnEnded`, `Died`, …) and facts read inside combat
  (`DB_Is_InCombat` — 2 columns!, `DB_Players`). Reading DB facts at `SessionLoaded`
  throws (restricted context).
- `Osi.SetLevel(created, n)` sets the level NUMBER but does NOT rescale fixed monster
  stat blocks — difficulty must be chosen at pick time (CreatureDB native stats).
- Equipment at runtime: `Osi.GenerateTreasure(char, "ST_SimpleMeleeWeapons", level, finder)`
  + `TemplateAddTo` for potions + `Osi.Equip`; auto-equip via the `TemplateAddedTo` event.
- Delayed logic: `Ext.Timer.WaitFor(ms, fn)`.
- RNG: `math.random` ONLY (`Ext.RandomInteger` does not exist; `math.randomseed` throws).
- NPCs can be given items to drink (`TemplateAddTo` potions; AI quaffs them).

**Limits**: root templates only (no level-placed instances or their gear/visuals),
spawned mobs start naked (equipment module fixes this for humanoids), no control over
AI personality scripts (vanilla AI picks targets/uses potions on its own — a feature).

## Route 2 — Osiris story goal files in the `Data/Mods` mount — ✅ PROVEN (E8b/E8)

Story text compiles and fires from `Data/Mods/<Module>/Story/RawFiles/Goals/*.txt`
(both appended entries in vanilla files AND invented `MARTIN_*.txt` file names).
`Data/Public/<Module>/Story/` never loads (E1/E7 nulls).

```
// inside a goal file (CRLF endings; validate with tools/check_goal.py)
IF
    DB_Is_InCombat((CHARACTER)_Player, _)
    DB_HonorMode_Enabled(1)          // honour-only gate (vanilla predicate)
THEN
    CreateAtObject("Wolf_41da0eff-...", (SFXGUID)_Anchor, ...);
```

- Our files live in repo `docs/goals/`, mirrored by `tools/deploy_story.sh --copy`.
- Join an existing combat properly: vanilla pattern `PROC_Appear` +
  `PROC_GLO_NarrativeCombat_JoinCombat` (see `Data/Mods/Gustav/.../TUT_Helm.txt:896-1010`).
- ⚠️ A whole-file grammar error **refuses new-game creation**; a bad name in one rule
  silently drops just that rule (imp-instance ids died silently while the wolf rule fired).
- Good for: *deterministic* encounter changes at specific story points (a chosen fight
  that always gets +N mobs). Not random per se — combine with Route 1 for chaos.

## Route 3 — Pre-placed level instances via `.lsf` level editing — 🟡 WORKS (third-party proof), STATIC

How the third-party "extra enemies (honour)" mod does it (unpacked to `/tmp/opencode/paks/eeh`):
extra characters **pre-placed in the level `.lsf` files** + anubis `.anc` data. No Lua.

- Tools: `tools/divine.sh` can extract/convert level `.lsf` → `.lsx` (text) → repack into a
  pak. Placed characters keep their vanilla gear/visuals/AI (unlike root-template spawns).
- Downsides: fully static (no randomness), large diff surface, must patch many level files
  for game-wide coverage, conflicts with other mods that touch the same levels.
- Useful for: a handful of *authored* new encounters (e.g., an ambush on a road) rather
  than global chaos.

## Route 4 — Treasure-table re-wiring (loot for encounters) — ✅ PROVEN (docs + runtime)

- Offline: edit `<Layer>/Stats/Generated/TreasureTable.txt` (pool contents, subtable
  probabilities, `subtable "x,y"` semantics — see `drop-chains.md`). Encounter→table
  wiring itself is binary/uneditable.
- Runtime (SE): `Osi.GenerateTreasure(inventoryHolder, tableID, level, finder)` rolls any
  table into any character at any level — this is how the equipment module works.
- Generic tables worth knowing: `ST_RandomWeapon`, `ST_Simple/MartialMeleeWeapons`,
  `ST_Light/Medium/HeavyArmor`, `ST_Finesse_MeleeWeapons`, `ST_RandomPotion`,
  `ST_RandomConsumable`, `ST_Throwable`, `EquipmentTrader_*` (vendor-side).

## Route 5 — Custom stat blocks in the pak (own creature variants) — 🔜 PLANNED (phase 2+)

A pak can carry `Public/ChaosReinforcements/Stats/Generated/Data/*.txt` with NEW stat
entries (unlike loose `Data/Public` files, pak stats files load). Use cases:

- bespoke `CHAOS_*` boost statuses (HP/stat scaling to replace the disabled
  `HEALTHBOOST_HARDCORE` override, and to make spawned mobs scale at high player levels);
- custom character entries that `using`-inherit vanilla ones (e.g. "Goblin, but +2 CR")
  referenced from Lua via the `Stats` field on custom root templates (Route 6).
- Validate expectations first: pak-stats loading on this install is *documented for
  vanilla-named files only* (E8b); a brand-new pak stats file needs one probe test.

## Route 6 — Custom root templates via pak-level template files — 🟠 POSSIBLE, UNTESTED

New root templates (with visuals/gear baked in) could be authored as `.lsx` character
templates and shipped in the pak's `RootTemplates/` — that is how mods add fully-dressed
creatures. Then `Osi.CreateAtObject` works with them like any root template. Untested
here; the live-dump cross-check in `tools/build_creature_db.py` shows the game's root
template table is data, so pak templates should merge — needs a probe.

## Route 7 — Ruled out on this install

- **Loose goal files under `Data/Public/*/Story/`** — never compiles (E1/E7).
- **Loose folders in `Data/Mods/` with `Mod.json`/no `meta.lsx`** — ignored entirely
  (post-mortem of `HealthBoostLocal` in `lua-modding.md` §3).
- **Editing encounter→loot or encounter→level wiring in text** — binary (drop-chains.md).
- **`Ext.RandomInteger` / `math.randomseed`** — do not exist / throw in SE v33.
- **`Osi.DB_*:Get` in restricted contexts** (SessionLoaded) — throws; read facts in combat.

## Combining routes (recommended shapes)

| Goal | Route |
|---|---|
| Random reinforcements everywhere (current engine) | 1 |
| One specific story fight always escalated | 2 (+1 for the random part) |
| Authored ambush with dressed NPCs at a map spot | 3 or 6 |
| Loot/pressure scaling without touching levels | 1 + 4 (+5 for bespoke boosts) |
| Fully-custom creature variants, game-wide | 5 + 6, spawned via 1 |
