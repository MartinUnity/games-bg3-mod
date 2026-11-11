# GOTCHAS.md — API findings & landmines (read on demand)

Durable engine/API findings from live in-game testing. Facts only — the "we tried X,
then Y" narrative lives in git (`git log --oneline --grep=v3.4`, or per-version
commit messages, which are full changelog entries). Append new findings HERE; only
promote to AGENTS.md if a session could trip over it without looking.

## 1. Loading & mounts

- Overrides load by **file identity**: edits take effect only at a vanilla file path
  with a vanilla entry name. **Invented file names under `Data/Public` are NOT
  loaded** (confirmed positive/negative in-game: the Honour HP boost works as an
  appended entry in existing `Status_BOOST.txt`; `MARTIN_*` stat files never did).
  New file names count **only inside a `.pak`**. (`docs/overview.md` §6.1)
- Story live channel = the **`Data/Mods/<Module>/Story/RawFiles/Goals/`** mount
  (E8b ✅ 2026-10-31: vanilla-named file with appended rules spawned a wolf). The
  `Data/Public/<Module>/Story/` mount **never fires** (E1/E7 nulls). Invented
  `MARTIN_*.txt` names DO compile+fire in the Data/Mods mount (E8) — our features
  ship as own files there, mirrored from repo masters in `docs/goals/` via
  `tools/deploy_story.sh --copy`. `Data/Mods` is writable (ro bind fixed).
- Goal-file errors are not silent uniformly: a **whole-file grammar error refuses
  new-game creation** ("likely due to mods"); a **wrong name in one rule can drop
  just that rule silently** (our imp rule died, wolf rule fired — instance-vs-root
  templates, `docs/spawn-chains.md` §3.1.2).
- Vanilla goal text lives at `Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/Goals/`
  — 944 files, all stock vanilla. Vanilla's helper library `Shared/.../Goals/__PROC.txt`
  declares 457 `PROC_`/`QRY_` rules — worth reading, but **cross-module visibility is
  unverified**, so our files declare everything they use.
- Loose mod folders under `Data/Mods/` without `meta.lsx` are ignored entirely
  (dead HealthBoostLocal/HPChaos used `Mod.json`, weren't in load order, invented APIs).
  Live load order = `PlayerProfiles/Public/modsettings.lsx` (base module **GustavX**,
  mods enabled) — NOT the stale 2024 root-level file.
- **Pak RootTemplates load as binary `.lsf` ONLY** — lsx-only = silently ZERO
  templates. Working paks ship .lsf; vanilla uses `_merged.lsf`. `tools/pack_mod.sh`
  auto-converts staged `RootTemplates/*.lsx` via `divine -a convert-resource -i lsx -o lsf`
  (absolute paths; roundtrip-verified).
- Display names live in **loca** (invisible offline) — the pak carries
  `Localization/English/ChaosReinforcements.loca` (xml source in the mod workspace;
  recipe in `docs/lua-modding.md`). Name regexes can't filter story mobs — filter by
  **template-name patterns** instead (`^QUEST_`, `CINE_`, `^Footstep_`, `Elder_Brain`, bosses…).

## 2. Script Extender / server Lua

- SE v33 loads and runs; `bin/DWrite.dll` = official Oct-12 v33 updater (old kept
  `.bak-2024`); `WINEDLLOVERRIDES="DWrite.dll=n,b"` is still required (launch options
  have it). SE itself stages under AppData `BG3ScriptExtender/`, not `bin/`.
- v33 logging needs **`"LogRuntime": true`** in `bin/ScriptExtenderSettings.json`
  (`LogEnabled`/`bg3-print.log` are obsolete/fake — the historical failure mode was
  years of invisible errors). Per-session logs land in the Larian profile at
  `Script Extender Logs/Extender Runtime*.log` (under AppData `Larian Studios/Baldur's
  Gate 3/`; the old drive_c prefix-home path is stale). The mod file-logs to profile
  `Script Extender/ChaosReinforcements.log` (+ probe/dump files) via `Ext.IO.SaveFile`.
- **`os` IS NIL in server Lua** (v3.26 incident: an `os.date` in log() threw at
  bootstrap for 3 versions — zero spawns, zero game-log lines; only the Extender
  Runtime log showed it). `Ext.Print` is nil on the server (client-only).
- RNG: `math.random` only — `Ext.RandomInteger` doesn't exist, `math.randomseed` throws.
- **SE databases are keyed by ARITY**: `DB_Is_InCombat` has 2 columns → `Get(nil, nil)`
  (e.g. via `table.unpack({}, 1, ncols)`); `Get(nil)` throws
  `No database named 'DB_Is_InCombat(1)' exists`.
- **Osiris CALLs return nil even on success** — only an explicit `false` is a refusal
  (our "REFUSED" equip logs were an artifact of `not ret` checks).
- **`pcall` cannot survive native faults**: an `Osi.SetLevel` crash
  (OsirisWrappers::CallWrapper fault → bg3.exe hard crash) took the game down (v3.3 lesson).
- `Osi.SetLevel` only sets the level NUMBER — it does NOT rescale fixed monster stat
  blocks. Difficulty must be controlled at PICK time (gate on template native GetLevel +
  CreatureDB `{ac, str, dex, con, ea}` stats).
- Newer SE `Ext.Template.GetAllRootTemplates()` returns a host
  `Map<FixedString, GameObjectTemplate>`, not a Lua table — `pairs()` iterates it, but
  match on value `.Name` as well as key (map keys are GUIDs).
- Lua gotcha hit: an early-return of `0` is truthy — `ipairs(0)` throws; return `nil`
  for empty picked lists.
- Offline compile-checks: python+lupa, venv `/tmp/opencode/luachk` — runs under LuaJIT,
  so nested `...` in closures is a syntax error (pass varargs explicitly).

## 3. Osiris / spawn & combat behaviour

- `CreateAtObject(TemplateId, Anchor, Temporary, PlaySpawn, SpawnFinishEvent,
  MatchOrientation, out)`; `CreateAt(TemplateId, X, Y, Z, ...)` — absolute coords, not
  dx/dy. `GetPosition(out X,Y,Z)`. Minimap axes are **x/z**, y = height
  (`Ext.Level.GetHeightsAt(x,z)`).
- Level-placed **instance** ids (`S_FirstFight_Imp_*`) do NOT resolve as
  `CHARACTERROOT_` literals — spawn only from **global root templates** (`Name_GUID`),
  as enumerated by the live template dump.
- `GetHostCharacter` = the network host's PLAYER — spawning "on" it drops mobs on the party.
- Spawn position is UNSETTLED briefly after `CreateAtObject`/`AppearAtPosition`:
  `GetPosition` keeps reading the host-adjacent create spot (the AppearAtPosition
  fallback spot is ~937m away). A 2s monitor phase-locked to a 90s heartbeat
  (90%2==0, both start at SessionLoaded) always ticked right after a spawn → false
  "player within 12m" aggro on distant mobs → never-engaged loop (v3.34 fix:
  `WILD_SETTLE_MS` 5s settle stamp + member-position sanity within 25m of group center).
- Making a spawn hostile BEFORE checking its level drags despawn-candidates into
  combat, so the deferred delete is refused forever — gate level FIRST, then
  SetFaction/hostility. Over-level despawn uses a retry ladder (3/10/30/90s, STUCK log).
- LOADING a save into an ongoing fight re-fires `CombatStarted` ~12s after
  SessionLoaded (live log: toggle-restore +04s, wave +16s) — SessionLoaded sets a
  20s load-quiet window that skips rolls (v3.28).
- Making camp fires NO Osiris `LevelLoaded`/`LevelUnloaded` (party teleports to the
  campsite inside the same level). Only signal: `TeleportedToCamp`/`TeleportedFromCamp`
  events (arity 1). WAKE re-fires the camp event pair for EVERY character (party,
  summons, dogs) — the camp guard is a 30s quiet window refreshed by ANY camp event
  (v3.22/v3.35; ✅ in-game).
- Faction pair (verbatim, proven): Evil `4be9261a-e481-8d9d-3528-f36956a19b17` /
  Hero `a1542c81-6895-929e-4522-10ce218bb360`; hostility = `SetHostileAndEnterCombat`.
- NPC AI uses healing potions on each other ✅ (2026-11-01); scrolls / arrows /
  grenades still unverified.
- Vanilla mid-combat reinforcement pattern: `PROC_Appear` +
  `PROC_GLO_NarrativeCombat_JoinCombat` (`Gustav/.../TUT_Helm.txt:896-1010`).
- Leader flavor: `OpenMessageBox` popups break immersion AND halt combat — use vanilla
  voice barks `Osi.StartVoiceBark(barkResource, source)` (bark texts live in loca;
  pick by NAME theme). Rename: `Entity:Replicate()` expects the component OBJECT, not
  its name string.
- Save files (LSOF + one zstd frame) carry no `DB_` fact strings, and there is no
  precompiled story cache — story state is unreadable offline. Game logs
  (`bin/gold.*.log`) show no story-compile output either.

## 4. Stats / progressions / spells

- **LevelOverride + Progressions grant REAL class levels on top of the cumulative
  Vitality curve** → observed HP = curve + max hit dice. Custom stat blocks must set
  Vitality = level-1 pool only; the engine rolls real hit dice per level (v3.37
  diagnosis, v3.39 fix; owner wants the dice variance, deterministic 5e pools rejected).
- The stats token `data "Level"` exists on only ~2 entries — a template's real level
  is **LevelOverride** in root templates (build_creature_db parses it via a
  pending-buffer since LevelOverride sorts before the MapKey opening the node).
- Ability tokens: abbreviations are silently DROPPED — `data "STR"` is a no-op,
  `data "Strength"` works (all CHAOST mobs ran on base 10s until v3.37).
- `Progressions` refs UCL progression **TableUUIDs** — a 1-char typo silently yields
  no class (Fighter entry `1c4c6006-0b49…`).
- Vanilla Characters NEVER carry spell-list tokens in stats; generic mobs' spells come
  from the root-template `SpellSet` attribute. Custom spells/slots go via per-level
  `DefaultBoosts`: `ActionResource(SpellSlot,n,lvl)` curves + level-gated
  `UnlockSpell(id,,,,ability)` kits (vanilla precedent, v3.38).
- Eldritch Blast comes from `UCL_CanEldritchBlast` passives at levels 1/5/10 — NOT a
  spell row.
- The `DualWielder` feature table does NOT grant Two-Weapon Fighting (only
  BonusAC@4/Dex+2@8) — re-add `style2_twf 5b91e529` in prog or
  `UnlockPassive(FightingStyle_TwoWeaponFighting)`.
- Hexblade-style CHA melee: `WeaponAttackRollAbilityOverride(SpellCastingAbility)` via
  DefaultBoosts (SHILLELAGH grammar); `WPN_*_Pact` item templates grant NO CHA boost.
- Monk: UCL has none; vanilla Monk progression table uses SubClass-entity refs +
  selectors — unusable; `UCL_FourElements_Thief 3c756b75` is the stand-in.
- Treasure tables with item ids that have no root template (`I_ARM_*_Body`) silently
  drop ZERO items — body armor goes via direct `TemplateAddTo` of real `ARM_*`
  templates instead; log GenerateTreasure failures loudly (v3.37).
  `ST_ArmorShield` unusable (StartLevel 6).
- Spell ids/class/level must pass BOTH checks after any registry edit:
  `tools/spell_registry.py` (id→name/BG3-level/classes + BANNED, hard-gated in
  gen_teams.py) and `tools/parse_wiki_spells.py --check` vs `docs/wiki-dumps/`
  (re-dump a class page: `lynx -dump .../List_of_<Class>_spells`). BG3 deviates from
  the 5e PHB (druid HAS Thunderwave/Blight/WallOfFire, NO MassHealingWord; Fly on no
  list; Sunbeam also sorc/wiz lvl6).
- `tools/build_creature_db.py` inputs: converted merged root-template lsx + vanilla
  stats `using` chains (**plural parents**: `_Giants`→Giant) + the live 32017-entry
  root-template dump. Generated `CreatureDB.lua` MUST be `Ext.Require`d BEFORE
  Chaos in BootstrapServer.

## 5. Templates / visuals

- **BG3 does NOT attach body-armor art to NPC bodies** — body art is BAKED into each
  template's `CharacterVisualResourceID` mesh; only hand props attach. A mob "wearing"
  armor needs a template with the baked body (v3.41: gen_teams stamps CVRID per CHAOST
  node from RACE_VISUALS — vanilla Guard_Melee/Ranger/Caster bodies per donor race;
  HalfOrc bodies live in SharedDev/_merged root templates).
- Root templates overriding inherited art with an explicit EMPTY `VisualTemplate=""`
  AND lacking own `CharacterVisualResourceID` spawn INVISIBLE (Phase Spider case);
  build_creature_db drops them (vis=="" WITH own CVRID is kept).
- Parent/donor template ids must be root-template **MapKeys** from the live dump —
  runtime INSTANCE guids (e.g. from an equip-log line) create dangling
  ParentTemplateId → invisible mob, stats fine (v3.34; gen_teams `validate_donors()`
  now hard-fails non-MapKey donors).
- Blank-name templates render NAMELESS mobs — flavor-name fixing must run BEFORE any
  despawn branch (Orthon mystery, v3.30).
- Gear lives on **level instances**, NOT root templates. Non-humanoids keep innate
  attacks — equipping would replace them.
- `Osi.Equip(char, item, 1, 0, 1)` — trailing args are HAND args (vanilla offhand uses
  1,0,0): main-hand was forced on everything and body armor failed at Osiris level.
  Bare `Osi.Equip(char, item)` auto-slots (v3.40, verified in-game AC 15/16).
- Raw `ent.Equipment` / `ent.Inventory` components are CLIENT-side — nil on server.
- Auto-equip of added items: `TemplateAddedTo` listener + `Osi.Equip`.
- Tooltips showing template-native "Level 1" on high-level mobs is cosmetic — don't chase.

## 6. Environment (Proton)

- Windows build under Proton: prefix `compatdata/1086940`, game logs `bin/gold.*.log`,
  profile `…/AppData/Local/Larian Studios/Baldur's Gate 3/`.
- Black-screen hangs during fights = Proton/Vulkan swapchain thrash from rapid
  alt-tabbing (13x "0x0 extent → offscreen" in gold log, zero mod errors — logs kept in
  `game-logs/`), NOT the mod. Owner PERM fix: **Borderless window** instead of Full
  screen.
