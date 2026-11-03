# HANDOVER — session restart brief (2026-10-31)

Self-contained brief so a fresh session can continue without re-deriving anything.
Read `AGENTS.md` first for the repo map; this file is the *state of play* snapshot.

## 1. Goal

Make BG3 **Honour mode** much harder by **adding more mobs to existing encounters**
(HP-ratio tweaks were not enough). Constraints:

- Text-only editing on Linux/Proton (Windows build, `compatdata/1086940`). No Larian GUI editor.
- `Data/Public/` overlay edits = "basegame override" (live, no build step).
- Honour-mode only (`DB_HonorMode_Enabled(1)` gate, or SE-side difficulty check).
- Mark ✅ verified vs ⚠️ needs in-game test in every claim.
- **Achievements do not matter to the user** → mods + Script Extender are fully allowed.
- User wants, eventually, to fold the existing `.txt` functionality into the mod (single artifact).

## 2. Decision made this session

**Route A**: build a `.pak` for Lua + story-goal work. Keep balance/stats `.txt` overrides in
`Data/Public/` (live, no build step) and only port them into the pak later if one artifact is wanted.
Route B (loose folder in `Data/Mods/` + hand-edited `modsettings.lsx`) judged unreliable — evidence:
the user's own loose `Data/Mods/HealthBoostLocal/` folder was ignored by the game entirely.

## 3. EXPERIMENT RESULT — E7 came back NULL (important)

User ran a **new Honour game** on 2026-10-31, walked the prologue (room 2 → room 3 imp battle).
`SharedDev/Story/RawFiles/Goals/MARTIN_SpawnProbe.txt` (two ungated `CombatStarted` rules, separate
once-guards, template A = level-native `S_FirstFight_Imp_Melee_01_07f1512b-…`, template B = foreign
`Wolf_41da0eff-…`) produced **no extra mobs and nothing unusual**.

Interpretation: with E1 (honour-gated, `SharedDev`) *and* E7 (ungated, any level, both template
flavours) both silent, the mount hypothesis is now the leading explanation — i.e.
`Data/Public/<Module>/Story/RawFiles/Goals/*.txt` is **not** part of the story compile path.
Vanilla ships story text only under `Data/Mods/<Module>/Story/RawFiles/` (944 goal files, all stock).
Remaining untested sub-cases: (a) wrong mount (`Data/Public` never scanned for `Story/`),
(b) wrong module (`SharedDev` not searched for the TUT levels' goals, which live in Gustav/GustavDev),
(c) the engine never compiles loose goal text at all on this install.

✅ Resolved afterwards (owner, same day): the **stats** side does work on a new game — the HP boost is
live (see "E8b" below). So the overlay is healthy; it is specifically the **story-goal** channel that
is dead. The earlier worry about `modsettings.lsx` (base module `GustavDev`, mtime 2024-08-02) is not
the cause for stats, and `GustavDev` is the layer where the working override lives.

### E8b — preferred over E8 (owner confirmed the stats analogue on 2026-10-31)

The owner's **HP change works** — the live one is an appended entry inside an existing vanilla file:
`GustavDev/Stats/Generated/Data/Status_BOOST.txt:11620-11630` (`HEALTHBOOST_HARDCORE`,
`IncreaseMaxHP(1d6+6);IncreaseMaxHP(Level*2d12)`), reached via `Character.txt` →
`DifficultyStatuses` → `STATUS_HARD`. Their new, separately-named stat files **never** worked.
So the repo's loading rule is **file identity**: only files vanilla already defines are read, and
changes land as entry-name overrides inside them. Codified in `docs/overview.md` §6.1 and in
`AGENTS.md`. (Also fixed: AGENTS.md credited a `Status_BOOST.txt` override that was commented out —
grep before trusting line numbers in this repo.)

Why it matters for spawning: E1 and E7 were both a **new file name** *and* a **new mount**, so
neither experiment isolated the variable. E8b appends the probe rules into an existing vanilla goal
file in the story mount (back it up first — `Data/Mods` is not in git; e.g.
`Data/Mods/SharedDev/Story/RawFiles/Goals/GLO_HonorMode.txt`), which tests the mount without also
changing file identity. Full protocol in `docs/spawn-chains.md` §3.1.2.

**E8b FINAL RESULT (later 2026-10-31): POSITIVE.** Fresh Honour game, room 3: vanilla 5 imps, then
**our wolf spawned mid-combat and attacked** — the exact mechanism wanted. Confirmed: `Data/Mods`
goal text compiles into sessions and fires; cross-level **global** templates instantiate fine
(`Wolf_…` fired in TUT_Avernus_C); `GetHostCharacter` = the host *player* (wolf dropped on the
party — placement needs real anchoring later); per-rule compile drops are silent (the imp rule
never fired — likely because `S_FirstFight_Imp_*` ids are level-placed *instances*, not root
templates). Hosts `--restore`d after the test; `Data/Public/Story/` remains dead (E1/E7 explained).
E8 FINAL: POSITIVE (same day) — with the probe as a **new-named** file
(`Data/Mods/GustavX/Story/RawFiles/Goals/MARTIN_SpawnProbe.txt`) the wolf spawned again, so
invented `MARTIN_*.txt` names work in the live mount too; probe since deleted, mount vanilla.
Full detail: `docs/spawn-chains.md` §3.1.2.

### E8 — cheap, no tooling (superseded by E8b above, but it costs one command)

`Data/Mods/` is writable now (user fixed the ro bind). Put the probe where vanilla goal text
provably lives, then restart the game (story text is compiled at start, so a restart is required):

```
tools/deploy_story.sh --copy          # mirrors repo MARTIN_*.txt -> Data/Mods/<Module>/Story/RawFiles/Goals/
```

Also consider hand-copying it to `Data/Mods/GustavDev/Story/RawFiles/Goals/` as well, since the
prologue levels' goals live in Gustav/GustavDev and the base module is GustavDev — that splits
sub-case (b) from (a). Then: any combat in a new game ⇒ story channel is live from the `Data/Mods`
mount, ship goals there (and via the pak). Still nothing ⇒ loose goal text is not compiled at all;
go through the pak (and/or lslib `StoryCompiler`) instead.

## 4. Pak toolchain — where the investigation stopped

> **SUPERSEDED same day (2026-10-31):** native Linux Divine build landed — `tools/divine.sh`
> + `tools/pack_mod.sh` (see §8 item 2). The notes below are kept only for the lslib source
> map (StoryCompiler/StoryDecompiler etc. still live there).

- Cloned `https://github.com/Norbyte/lslib.git` → `/tmp/opencode/pak/lslib` (⚠️ `/tmp` may be wiped;
  re-clone with `git clone --depth 1`, or put it in a gitignored `tools/vendor/lslib`).
- `LSTools.sln` projects: `LSLib`, `Divine`, `StatParser`, `StoryCompiler`, `StoryDecompiler`,
  `LSLibStats`, `RconClient`, `VTexTool`, `DebuggerFrontend`, `ConverterApp`.
- **`ConverterApp` is the only pak UI and is `net8.0-windows` (WinForms) → does not build natively here.**
- **No console project in the repo does pak pack/unpack** → plan is a ~40-line C# console app that
  references `LSLib` directly. API surface lives in:
  - `LSLib/LS/PackageReader.cs` — `class Package`, `class PackageReader`
  - `LSLib/LS/PackageWriter.cs` — `PackageWriter`, `PackageWriter_V7/V13/V15`, `PackageWriterFactory`
  - `LSLib/LS/PackageCommon.cs` — `PackagedFileInfo`
  - `LSLib/LS/PackageFormat.cs` — `PackageHeaderCommon`
  - usage example to copy: `ConverterApp/PackagePane.cs` (~lines 100–200: sets `build.Compression =
    CompressionMethod.Zstd|LZ4|Zlib`, `build.Version <= PackageVersion.V9` rules)
- `LSLib.csproj` is `net8.0` and its **PreBuildEvent runs `external/gppg/binaries/GpLex` + `Gppg`**
  (Windows binaries, not in the repo; README wants GPLex 1.2.2 + GPPG 1.5.2 zips from
  `s3.eu-central-1.amazonaws.com/nb-stor/dos-legacy/ExportTool/`). `StoryCompiler` additionally pulls
  `Grpc.Tools`/protoc. ⚠️ Linux build may need the generated `Goal.lex.cs`/`Goal.yy.cs` handled
  manually or the tools run under wine.
- Tool inventory on this box ✅: `dotnet 8.0.424`, `wine 10.0`, `python3 3.14`, `node v24`, `go`,
  7-zip, zstd. No cargo, no mono. Network OK (GitHub API intermittently rate-limited,
  `raw.githubusercontent.com` fine).
- **Prove-before-trust step (not yet done):** round-trip an existing pak —
  `…/AppData/Local/Larian Studios/Baldur's Gate 3/Mods/ModFixer.pak` (282 B) or
  `Automated Summons SE.pak` (47 KB). Also worth checking pak magic/compression of vanilla paks.
- Alternatives not tried: BG3 Modder's Multitool (`ShinyHobo`, WinForms, under wine), `Nefere/magical`
  (Rust CLI mod manager, cross-platform — no cargo here but releases may have Linux binaries),
  BG3 Mod Manager under Proton (Nexus guide, Oct 2025), Vilsol/bg3.

## 5. Script Extender state (corrected 2026-10-31, see lua-modding.md §1)

- **Correction:** SE v33 WAS already staged/running (pkg under
  `AppData/Local/BG3ScriptExtender/ScriptExtender/33.0.0.0_…`, mtime Oct 30 20:44 — the old
  April-2024 updater did fetch it). What was broken was **visibility**: no valid logging config
  ever, so Lua mods failed silently for years. `bin/DWrite.dll` replaced with the official
  Oct-12 v33 updater anyway (old kept as `bin/DWrite.dll.bak-2024`); launch options already correct.
- Logging FIXED 2026-10-31 (the earlier `LogEnabled` key is fake in v33 — no log was ever
  written). Correct keys: `{"LogRuntime": true}` in `bin/ScriptExtenderSettings.json` →
  per-session logs in the Larian profile at `Script Extender Logs/Extender Runtime*.log`
  (under AppData `Larian Studios/Baldur's Gate 3/`; an earlier note here said the drive_c
  prefix home — stale).
  Probe v2 also file-logs via `Ext.IO.SaveFile` → profile `Script Extender/Chaos_probe.log`
  (channel already proven working). **Not yet verified producing output** (needs one game start
  with the new settings).
- Probe v1 result (2026-10-31, partial ✅): mod enabled + loaded server-side — template dump
  written at SessionLoaded (keys = bare GUIDs; wolf GUID present, prologue imp-instance GUID
  absent — confirms the story-side instance-vs-root finding). Spawn itself invisible (logging dead).
- **Probe v3 result (2026-10-31): POSITIVE — wolf spawns HOSTILE at CombatStarted via Lua.**
  Full pipeline proven: pak → SE v33 → mod → `Osi.CreateAtObject` (name+`_`+GUID root template,
  anchor=GetHostCharacter) → `SetFaction(EVIL)` → `SetHostileAndEnterCombat(EVIL, HERO, ...)`
  with the E8b pair verbatim → joins the fight as a red enemy.
- **Chaos engine v3.1 = data-driven reinforcement engine (2026-10-31, packed+installed,
  one playtest done, see below):** owner
  spec: stacking trigger (base 20%, +5..25% per miss; TEST_MODE=true forces 100%), spawn budget
  = host GetLevel x rand(2,4) x (1 + 0.15 x max(0, party-4)), max 8/combat, anchors = existing
  ENEMIES when known (spawns next to the mobs you fight), hostility = proven EVIL/HERO pair.
  **CreatureDB.lua** — generated offline by `tools/build_creature_db.py`
  (`tools/pool_types.py` is its template→stats→type resolver):
  **622** generic spawnable creatures in 14 D&D type groups (Humanoid 403, Undead 56, Beast 48,
  Aberration 17, Monstrosity 17, Elemental 20, Giant 1 …), each `{id = Name_GUID, hp, cost =
  hp/10}`; sources = `/tmp/opencode/rt/*.lsx` (converted merged root-template tables), the
  16G vanilla unpack at `/home/martin/Documents/mods/bg3-new/bg3-vanilla-data` (stats `using`
  chain → `_Type` + Vitality; NOTE vanilla uses PLURAL parents — `_Giants` → strip trailing
  `s` → Giant), and the live 32017-entry dump as instantiation ground truth.
  ⚠️ Regeneration needs those paths; `/tmp` may be wiped. `BootstrapServer.lua` now
  `Ext.Require`s `Server/CreatureDB.lua` BEFORE `Server/Chaos.lua`.
  **Type affinity:** `RACE_TO_TYPE` (Osiris `GetRace` string → D&D type) + dominant enemy type
  decides the pool; unknown races log `type ?` so the map grows from `ChaosReinforcements.log`.
  **Low-level ceiling:** at host level ≤ 2, mob levels never exceed the player's level
  (level-3 harpy multiattack one-shots a level-1 party). **Leader:** rolls only when a pack of
  ≥ 2 spawned; ~10% chance (LEADER_TEST=true forces 100% while testing); ~90% same type,
  ~10% cross-type from the `AFFINITY` map (Beast pack → Beast/Monstrosity/Humanoid leaders,
  never e.g. an undead leading wolves); leader is spawned OUTSIDE the budget (the 10% roll is
  the jackpot escalation — biased to the beefier half of the pool; no cross-type while the
  low-level ceiling is active); Level scaling: `Osi.SetLevel(created, target)` with immediate + delayed
  (2 s `Ext.Timer.WaitFor`) GetLevel verification.
- **v3 first-playtest results (owner, 2026-10-31, tutorial imp fight) → all three issues
  fixed in v3.1:**
  1. **`QUEST_Monitor_Incubus_…` spawned (displayed "Raphael")** — display names live in loca
     (invisible offline), so name regexes can't catch everything; fix = filter template-name
     prefixes. Added to `build_creature_db.py` BAD_NAME: `^QUEST_` (32 entries!), `^Footstep_`
     (6 FX "characters"), `Elder_Brain|NetherBrain` (endgame boss parts), `Doppelganger|
     Shapechanger` (quest templates) → 674→622 entries.
  2. **Harpy (Monstrosity) joined a fiend fight** — not a leader artifact: `DB_Is_InCombat:Get(nil)`
     threw `No database named 'DB_Is_InCombat(1)' exists` because **SE names DBs by arity** —
     `DB_Is_InCombat` has 2 columns (char, combatGuid) → must call `Get(nil, nil)`. Result was
     `enemies: 0` → random-type fallback. v3.1: correct arity + an `EnteredCombat(object,
     combatGuid)` listener roster as union fallback + the whole wave runs after a 1.5 s
     `Ext.Timer.WaitFor` so enemies have actually entered combat before classification.
  3. **Spawn log said lvl 1 but the game showed lvl 3** — the immediate GetLevel read-back
     after SetLevel is not trustworthy (SetLevel likely applies async). v3.1 logs a delayed
     (2 s) verification line `verify <id> lvl <n> wanted <t>` per spawn — read those after the
     next playtest to decide whether SetLevel works at all.
  Also observed: `DB_Players` (arity 1) worked and returned 2 in the tutorial; the Race
  static-resource dump shows fields `Name` (e.g. "Humanoid", i.e. race names, NOT D&D creature
  types), `ParentGuid`, `Tags` — so a runtime race→type walk would still need a name map;
  RACE_TO_TYPE stays the mechanism.
  Osiris discovery toolkit confirmed in `story_header.div`: queries `GetLevel`, `GetRace(c,0)`,
  `GetDisplayName`, `GetPosition`, `IsInCombat`, `CombatGetInvolvedPartyMembersCount`; facts
  `DB_Is_InCombat` (2 cols; 1272 uses in vanilla goals), `DB_Players` (1 col), `DB_PartyMembers`;
  event `EnteredCombat` (line 1161). Third-party "extra enemies honour" mod (unpacked to
  /tmp/opencode/paks/eeh) does it with pre-placed level .lsf characters + anubis .anc — not
  reusable by us, no Lua anywhere in it.
- ⚠️ RNG gotchas (DLL strings + API forensics 2026-10-31): `Ext.RandomInteger` does NOT exist
  in v33 (older docs wrong); use `math.random(lo,hi)` — and NEVER `math.randomseed` (SE ships a
  stub that throws). Lua syntax can be compile-checked offline: `pip` venv + `lupa`,
  `rt.eval('load')(src)` (no interpreter on this box otherwise).
- Probe v2 result (2026-10-31): **wolf spawns via Lua** (CreateAtObject + host anchor work) but
  stays neutral/yellow. Log (`Chaos_probe.log`) showed SetFaction/SetHostileAndEnterCombat
  "ok"-without-effect: v2 used `Evil_fb046e51…` + the host's real **per-player faction**
  (`GetFaction(host)` = `Hero Player1_<guid>`). Lesson: replicate the E8b-proven pair verbatim
  (`Evil_4be9261a-e481-8d9d-3528-f36956a19b17` vs `Hero_a1542c81-6895-929e-4522-10ce218bb360`)
  → probe v3. Other facts: `Osi.DB_*:Get` at SessionLoaded throws "restricted context"; runtime
  logs live in profile `Script Extender Logs/`; template dump = GUID<TAB>Name (wolf = name
  "Wolf"), and GetAllRootTemplates includes props/items — filter creature templates for pools.
- Probe mod **packed + installed** (pak toolchain proven, `tools/pack_mod.sh --install`):
  `…/Baldur's Gate 3/Mods/ChaosReinforcements.pak`. Source `mods/chaos-reinforcements/` =
  `meta.lsx` (UUID `d5afd252-101b-449b-ae74-c792a73d64ff`, `Folder=ChaosReinforcements`,
  Type int32=1 — fixed from stale wiki format), `ScriptExtender/Config.json`
  (`RequiredVersion: 33`, `ModTable: ChaosReinforcements`, `FeatureFlags:["Lua"]`),
  `BootstrapServer.lua`, `Server/Probe.lua` (logs on `SessionLoaded`, dumps every root template
  to `Chaos_root_templates.txt` via `Ext.IO.SaveFile`, spawns imp + wolf on `CombatStarted`,
  registers `!chaos_spawn`).
- **v3.3 playtest results (owner, 2026-10-31, game #2: solo lvl-1 Merregon nearly TPK'd a
  2-char party) → fixes in v3.3 (all read from `ChaosReinforcements.log`):**
  1. **Discovery + affinity WORK** (5 imps → `wave: type Fiend`), via the `EnteredCombat`
     roster fallback — but my arity "fix" had a Lua bug: `args[#args+1] = nil` never grows a
     table, so `Get` received ZERO args → `DB_Is_InCombat(0)` / `DB_Players(0)` throws. Fixed
     with `db:Get(table.unpack({}, 1, ncols))`.
  2. **Laezel was classified enemy** (faction `Companion1_…`, party fact empty in tutorial) →
     `isFriendly` now treats `Hero…`/`Companion…` faction prefixes as friendly; party size
     prefers `Osi.CombatGetInvolvedPartyMembersCount(combatId)` (story_header.div:746).
  3. **`verify lvl 1 wanted 1` — yet the Merregon kept 45hp/AC16/str18/ExtraAttack:**
     **`Osi.SetLevel` sets the level NUMBER but does NOT rescale fixed monster stat blocks.**
     Pivot: difficulty control happens at PICK time, using NATIVE stats now stored in
     CreatureDB (`ac` from stats `data "Armor"`, `str`/`dex`/`con`, `ea` = ExtraAttack passive
     — resolved through the `using` chain by `resolve_field`). `build_creature_db.py` emits
     `{id, hp, cost, ac, str, dex, con, ea}`; 623 entries.
  4. **Native-stat gates** (owner-suggested values): level 1 → hp ≤ 20, AC ≤ 14, best ability
     ≤ 12, no ExtraAttack; level 2 → hp ≤ 35, AC ≤ 15, ability ≤ 14 (still no ExtraAttack);
     level 3+ ungated except `HEAVY_TYPES` (Dragon/Giant/Celestial) which need host level ≥ 5
     (a dragon at lvl 3 = doom). Offline pool check: lvl-1 Fiend pool = 3 (imps/butler),
     lvl-1 Monstrosity = 0 (the harpy TPK is now impossible), lvl-2 Monstrosity = 3.
  5. **Honour HP boost DISABLED for calibration** (owner request): the live
     `IncreaseMaxHP(1d6+6);IncreaseMaxHP(Level*2d12)` line in
     `GustavDev/Stats/Generated/Data/Status_BOOST.txt` (`HEALTHBOOST_HARDCORE`) is commented
     out (entry still defined, now inert); Lua-side `MOB_HP_BOOST = ""` placeholder in
     Chaos.lua stays off until native mob stats are gauged — reimplementation needs the
     custom-stats-file route (Lua cannot define stat boosts directly).
  6. **Equipment phase 1 implemented in v3.4** (owner chose: Larian tables now, own item DB
     next; consumables in). Key discoveries: mobs' gear lives on level-placed instances, NOT
     on root templates (merged.lsx has no equipment attrs; no vanilla EquipmentSet stats) —
     BUT vanilla ships generic random tables (`ST_SimpleMeleeWeapons`, `ST_MartialMeleeWeapons`,
     `ST_LightArmor`/`ST_MediumArmor`/`ST_HeavyArmor`, level-segmented via StartLevel/EndLevel)
     and Osiris has `GenerateTreasure(holder, tableId, level, finder)` (story_header.div:786)
     + `TemplateAddTo(template, holder, count, showNotification)` (:411) + `Equip(character,
     item, addToMainInventoryOnFail, …)` (:160) + event `TemplateAddedTo(tmpl, object, holder,
     addType)` (:1237). v3.4 flow: HUMANOID spawns only (others keep innate attacks — a sword
     would REPLACE a monster's innate multiattack); owner's band tiers (≤80% simple+light,
     ≤95% martial+light+25% potion, ≤98% martial+medium+1 potion, jackpot martial+heavy+2
     potions+speed potion; tier forced to 1 at host lvl ≤2; heavy armor needs lvl ≥5); potions
     added via `TemplateAddTo` (healing potion scales with player level: A/Greater/Superior
     at 1-5/6-10/11+); `TemplateAddedTo` listener auto-equips rolled gear (potions fail into
     inventory and mob AI drinks them). No sqlite in SE v33 (grepped vendor API) — generated
     Lua modules remain the DB medium. Phase 2 (when we want cost control): ItemDB.lua from
     Weapon.txt/Armor.txt/Object.txt (`RootTemplate` GUID → dump Name_GUID, `ValueScale`,
     `ValueLevel`, `Proficiency Group`).
- **v3.6: proficiency-driven equipment** (owner insight: spawned humanoids fought barehanded;
  real Merregons wield glaives). Vanilla stats expose the intent: weapon-users carry
  `data "Proficiency Group"` (Merregon = `MartialWeapons;SimpleWeapons;HeavyArmor`), innate
  attackers (Wolf) have NONE — only `UnarmedAttackAbility`. CreatureDB entries now carry
  `prof` + `unarmed`; equipment rolls: martial→`ST_MartialMeleeWeapons` / simple table /
  dex>str→`ST_Finesse_MeleeWeapons`; unarmed-without-prof = designed innate attacker → no
  weapon (never replace innate attacks); armor = highest prof tier, no armor prof → keep
  native AC; jackpot tier (lvl ≥4) upgrades to magic/scaled tables (`ST_*_1`,
  `ST_Finesse_MeleeWeapons_Magic`). Useful extra vanilla tables found: `ST_RandomPotion`,
  `ST_RandomConsumable`, `ST_Throwable` (chaos fodder for later).
- **v3.14: Wild.lua — standing world encounters** (owner spec 2026-10-31): random mob
  groups spawned OUT of combat, standing and neutral, ~18-28 m from the player at a
  random angle (out of sight ring; `CreateAt` at raw coords from `GetPosition`).
  NOT ambushing (owner decision: vigilant players must be able to avoid them; wandering
  deferred to backlog). A 2 s proximity monitor turns a group hostile (SetFaction +
  SetHostileAndEnterCombat per member) only when a player comes within 12 m — so the
  fight starts on approach, not on spawn. Group tiers per owner spec: <=80%: 2-6 mobs;
  <=98%: +1-4 mobs + 1 leader; >98%: +2-8 mobs + 2 leaders + 1 "BOSS " (placeholder =
  leader with prefix, via `FlavorLeaderCommon(created, isBoss)`). **Gated to `^TUT_`
  levels only while testing** (LevelLoaded event tracks the level name; safe-haven/town
  exemption deferred until proven). Heartbeat 45 s, 100% roll while testing
  (`WILD_TEST`), max 3 concurrent groups, level-appropriate pools (same GATES),
  humanoid groups get equipment, mobs SetLevel'd to `targetLevelFor(base)`.
  Shared engine helpers moved from Chaos.lua to Common.lua (DEFAULT_TYPES, GATES,
  factGuids/rowGuid, passesGate/gatedPool/pickFrom/pickLeaderFrom/targetLevelFor).
  Bootstrap order: Common → CreatureDB → Equip → Flavor → Chaos → Wild.
- **v3.27 CHAOST team spawns were dead — RootTemplates load as binary .lsf only
  (owner 2026-11-01: first team-mode roll after load = `CreateAtObject failed for
  CHAOST_*` x5, "group spawn FAILED (no members)"):** diagnosis chain — rosters↔lsx
  fully consistent (420/420 ids, 504 templates), parents valid in live dump, pak
  contained the files — BUT vanilla ships RootTemplates as `_merged.lsf`, and every
  working third-party pak here (ManyMoreMonsters, EncountersOverhaul, extra_enemies
  _honour, Goon's) ships binary `.lsf`; we shipped only `ChaosTeams.lsx` → the engine
  registered ZERO CHAOST templates (encounters.md Route 6 verdict: lsx-only = dead).
  Fix: `divine -a convert-resource -i lsx -o lsf` (roundtrip-verified byte-identical
  semantics on EO's shipped pair + our 504-template file); `tools/pack_mod.sh` now
  auto-converts every staged `RootTemplates/*.lsx` → `.lsf` at build time (never
  stale; both formats ship, EO precedent); generated .lsf gitignored. Also fixed a
  real stats bug: `CHAOST_*` Progressions "Fighter" table was `1c4c6006-BB49-...` —
  UCL's actual TableUUID is `1c4c6006-0B49-...` (one char off; 12 stats entries +
  gen_teams/team_composer corrected; the other 20 UCL GUIDs verified against the
  installed UCL's Progressions.lsx — note Progressions reference TableUUID, NOT node
  UUID). Robustness: failed team slot now retries with a pool mob (`teamFallback`,
  group never empties on template trouble); new `!chaos_root` console probe counts
  CHAOST_* among `Ext.Template.GetAllRootTemplates()` (⚠️ confirm 504 REGISTERED
  in-game next boot). Owner's related load-save suspicion was wrong: template
  registration is boot-time, unrelated to save loading.
- **v3.28 equip role-parity + save-load reinforcement guard (owner 2026-11-01):**
  playtest confirmations: healing-potion AI ✅ ("they use healing potions to heal
  each other"), camp guard ✅, 25%/90s pacing ✅. Owner feedback drove this release:
  (a) the 5 combat-reinforcement mobs were "mostly naked" + a caster felt wrong —
  (b) LOADING a save into an ongoing fight spawned a SECOND wave: log proved the
  game re-fires `CombatStarted` on restore (+00:00:04 SessionLoaded toggle-restore,
  +00:00:16 `CombatStarted … TRIGGERED (chance 30%)`, +00:00:18 wave). Fix:
  `LOAD_QUIET_MS = 20000` — SessionLoaded sets `loadQuietUntil = MonotonicMs() + 20 s`
  (helper `MonotonicMs()` added to Common.lua); CombatStarted listener skips rolls
  inside the window WITHOUT touching the miss stack ("skipped: save-load quiet
  window"). Cost: a genuinely fresh fight within 20 s of a load misses one roll.
  Equip parity ("option 1, cheap route"): role read = team slot, else template-name
  patterns over `nm`+id (`weaponRoleFor`: Ranger/Hunter/Archer/Scout/Sniper/Marksman/
  Crossbow/Bowman → ranged; Caster/Cleric/Druid/Warlock/Wizard/Mage/Priest/Acolyte/
  Shaman/Necro/Invoker/Conjurer/Sorcerer/Healer/Bard → caster). `equipmentFor` now
  returns (weapon, armor, extras): caster = QUARTERSTAFF template (needs SimpleWeapons
  or Quarterstaffs prof; `WPN_HUM_Quarterstaff_A_0` GUID 96e2abaf…, tier4 `A_1`
  GUID 2fa18ee4…) instead of a rapier lottery (finesse gated to melee ONLY); ranged
  = bow as PRIMARY weapon (ST_SimpleRangedWeapons, martial table at tier>=2+prof,
  _1 variants at tier4; old duplicate support-bow removed); Shields-proficient melees
  get shield templates (tank slot 100%, other melee 55%; B_0 24fa28d4/C_0 4491fcaf,
  tier4 D_1 26b81847) — shields are off-hand WPN_* templates, the auto-equip listener
  places them. supportRoleFor unified onto the same guess (pool mobs now get
  scrolls/arrows too; team healers keep the melee consumable kit). Offline sim
  (EquipPlanFor grid, seed 42) verified all paths incl. "Sahuagin Hunter"→bow.
  Cosmetic note for owner: tooltips still show the template's native "Level 1"
  (SetLevel removed; stat blocks are fixed anyway — HP/ExtraAttack don't derive
  from that number). ⚠️ in-game: first CHAOST class-teams + parity + quiet-window
  verdict all pending this boot (owner running the v3.28 pak).
- **v3.29 team-mode reinforcements (option 2, owner: "last wave had humans + 2
  goblins + 1 Meazel — too odd; option 2 will largely fix this as bonus"):**
  `reinforce()` now runs the CHAOST class-team composer for Humanoid fights instead
  of the bag-of-pool-mobs pick. Composer pieces MOVED from Wild.lua to Common.lua
  as shared globals (TEAM_PROFS/TEAM_FILL/teamSlots/teamLevelFor/teamEntry) + new:
  `donorRaces()` (parsed from template ids), `RACE_TO_DONOR` (GetRace key -> donor:
  Goblin/Hobgoblin/Goblinoid→goblin, Duergar→dwarf, DrowElf/ElfHigh→elf, HalfOrc→
  halforc...), `dominantRaceKey(enemies)`, `teamEntry(role, lvl, raceKey)` (filters
  CHAOS_TEAMS to one donor race + sets display `nm` = "Goblin Vanguard" style via
  RACE_LABEL/ROLE_LABEL -> FlavorNameFix), `poolForRace(pool, raceKey)` (race-
  coherent pool fallback). Donors expanded 7→9 in gen_teams.py: goblin_m/f
  (BASE_Goblins_Male_fb1af356 / Female_9629600b), halforc_m/f
  (BASE_HalfOrcs_Male_0350f048 / Female_Guard_01bb9053) — verified in the live
  root-template dump; NO Hobgoblin/Bugbear/Gnoll/Meazel BASE_* donors exist.
  792 templates now (was 504); TeamTemplates.lua + ChaosTeams.lsx regenerated.
  Team-mode gate: etype==Humanoid AND base >= TEAM_MIN_LEVEL(3) (baked CHAOST
  levels bypass the low-level GATES below 3 — legacy pool path there) AND wave
  size >= 2 where size = min(MAX_SPAWNS-1, floor(budget/(max(2,ceil(lvl*TEAM_COST
  0.7))))) — CHAOST hp ≈ 11/lvl but class chars are weaker per-HP than fixed
  monsters, hence the 0.7 discount. Race = dominantRaceKey(enemies), 20%
  TEAM_CHAOS_CHANCE rolls a random donor race anyway; unknown/nil race → random
  donor. Leader roll UNCHANGED (pool mob, outside budget) in both modes. Wild
  squads also got the one-race-per-group rule (random donor, logged `race <key>`;
  team-slot pool retries go through poolForRace first). teamSlots(2) bug found by
  offline sim: guaranteed trio didn't shrink for count<3 -> now trims (drops
  ranged); Wild masked it (loop ran to count), Chaos would have over-spawned.
  Offline sim (/tmp/opencode/luachk/sim_v329.py, seed 7): goblin squad 12lvls x
  6roles x8 picks all race-correct, level ceilings hold, wave-size distribution
  sane (base 5 → 2-6 mobs). ⚠️ in-game: first race-coherent reinforcement waves
  + `!chaos_root` now expects **792 REGISTERED**; wild log gained a `race <key>`
  field.)
- **v3.30 over-level leak fix + nameless-mob mystery solved (owner Orthon log
  2026-11-01):** a lvl-5 Fiend wave picked `Orthon_A` (hp105 → cost 10 fits budget);
  the native-lvl self-check saw lvl 10 and deferred the delete — but `SetFaction(EVIL)`
  ran BEFORE the check, dragging the devil into combat, and the deferred delete then
  *refused* ("skipped (in combat)") **permanently** → two lvl-10 devils fought in the
  lvl-5 fight. Owner's clue: they showed only "lvl 10" with NO name — that's the
  whole nameless-mob pattern: despawn-path mobs return before `FlavorNameFix` (the
  blank-name fallback, which exists because templates like Orthon_A render BLANK
  names), so every over-level despawn survivor = a nameless beefy mob. Fixes:
  (a) **pick-time lvl gate made real** — `passesGate` already rejected `e.lvl >
  base+2` but the DB only read stats `data "Level"` (2 entries game-wide!); levels
  actually live as **root-template `LevelOverride`** (Orthon_A node = 10).
  build_creature_db.py now parses it (note: attrs alphabetical, LevelOverride comes
  BEFORE MapKey which opens the record → pending-buffer) → 132/560 entries lvl-aware,
  Orthon lvl=10 → never picked under lvl 8. ⚠️ this also prunes other hidden lvl-
  bombs from low-level pools (Floating_Head etc. now actually gated);
  (b) spawnCreature (both engines) checks level BEFORE any faction/hostility call —
  an over-level spawn stays neutral (never engages, delete succeeds outside combat);
  (c) single 3s-delete-skip replaced by `ScheduleOverlevelDelete` ladder (Common.lua):
  3s/+10s/+30s/+90s retries, STUCK log if never deletable; (d) `FlavorNameFix` moved
  before the despawn branch so even a STUCK survivor renders a proper name;
  (e) spawn log now prints the DB `lvl` (the old `lvl nil` was a dead-variable
  artifact from the removed SetLevel code); (f) party-knob undercount fix: involved-
  count read lagged (party 6 seen in log, budget used party 1 because the API
  returned 1 at +1.5 s while players trickled in) → party = max(DB_Players, involved).
  Offline sim (/tmp/opencode/luachk/sim_v330.py): Orthon OUT at base≤7 / IN at 8+,
  0 lvl-gate violations across all pools, ladder deletes at 3rd attempt, stuck case
  logs. ⚠️ in-game: expect `over-level despawn done:` (or no over-level line at all
  for lvl-aware entries) and NO nameless mobs.
- **v3.31 wild-roll stacking (owner 2026-11-01: "10+ rolls in a row without any
  spawns - add 2-8% per miss; the wild chance is fixed at 25%"):** correct, the wild
  heartbeat was memoryless (reinforcements already stack). `WILD_CHANCE=25` is now a
  BASE; each heartbeat that produces NO group adds +rand(WILD_STACK_MIN=2,
  WILD_STACK_MAX=8)% to the next roll (cap 100), reset on a successful group spawn.
  A *triggered* heartbeat that fails to place a group (no pool / no valid spot /
  empty group) counts as a miss too (spawnWildGroup now returns true/false);
  skip-gates (camped/backoff/max-groups/combat/safe-haven) do NOT touch the stack,
  mirroring the Chaos.lua quiet-window rule. Miss count shows in the roll log
  (`chance roll 71 (need <=45, miss 4)`) and in `!chaos_status`
  (`misses N (next lo-hi%)`). Sim: avg misses 3.0→2.0, worst-case streak 35→11,
  P(≥10 misses) 5.7%→0.1% (the owner's exact complaint). Pak 228146 B.
- **v3.32 invisible-template fix (owner: "Phase Spider has no visible body, portrait
  looks like a human with a shadow over its face; only this encounter"):** the spawn
  was `BASE_Quadruped_Beast_Spider_Phase` — a root template whose node carries an
  explicit EMPTY `VisualTemplate=""` (overriding inherited art) and NO own
  `CharacterVisualResourceID` → engine has no body art (invisible) + placeholder
  portrait. `tools/build_creature_db.py` now filters ALL such templates (parse
  VisualTemplate/CharacterVisualResourceID per node — CVRID sorts BEFORE MapKey via
  pending-buffer, VisualTemplate AFTER) and drops entries where `vis=="" AND no own
  CVRID` → **34 artless entries removed** (560→526), including the spider, VINE
  tentacles, and guild/Mephistopheles humanoid variants (all have visible alternatives).
  ⚠️ 29 DB entries with `vis==""` were KEPT because they carry their own CVRID
  (body-art anchor — the confirmed-invisible spider had neither; goblin/elf-female
  soldier variants, Kuotoa, ScryingEye, Myconid_Sovereign, VINE tentacles A/B/D/E…)
  — if one of THOSE shows up invisible in-game, tighten the rule to `vis==""` alone.
  The Phase Spider pool slot is covered by the concrete `SPIDER_Phaser` (own full art,
  identical stats). Offline sim: no artless spider leaks, gated-pool totals healthy
  (base 1=104..base 12=526), Orthon still lvl=10. Pak 226738 B.
- **v3.33 owner-verdicts batch + team-leader coherence + housekeeping (2026-11-02):**
  VERDICTS IN: fizzle-aware backoff ✅ "works well", IMGUI announce toasts ✅ "works well"
  (backlog entries resolved). Housekeeping (owner OK): dead mods DELETED from the story
  mount - `Data/Mods/HealthBoostLocal/` + `Data/Mods/HPChaos_0e6a9a3c-.../` (never worked;
  no modsettings.lsx references); TEST_MODE / LEADER_TEST / WILD_TEST force-knobs REMOVED
  (Chaos.lua/Wild.lua - controlled iteration replaced blanket triggers; `!chaos_wolf`/
  `!chaos_root` console probes stay). **B1 RACE_TO_TYPE growth:** seeded Bugbear/Gnoll/
  Ogre/Raven/HalfElf/Halfling/Meazel (verified vs vanilla stats _Type chains: Bugbear/
  Gnoll->_Humanoid, Raven->_Critter->_Beast, Ogre->_Giants = DB's own Giant typing;
  Bugbear was a live "type ?") + new `tools/grow_race_to_type.py` aggregates discovery
  logs into frequency-sorted paste-ready suggestions. **B2 race-coherent leaders:**
  reinforce() TEAM mode leader now draws the wave's donor race CHAOST tank (wildcard
  backup, pool fallback only if both miss) at min(base+J+T, teamLevel+0..2) so the baked
  LevelOverride can never trip the v3.30 over-level despawn; cross-type chaos rolls keep
  drawing pool mobs on purpose; log line `leader: TEAM race goblin ...`. Wild team-mode
  leaders were already baked same-race (v3.29) - untouched. Sim: 3000/3000 leader picks
  resolve across lvls (tank templates exist 1-12 for all 9 donors), 0 cap violations.
  Compile OK, Pak 227506 B. Still pending verdicts: !chaos_root 792, race-coherent waves,
  nameless-gone confirmation, scroll/bow/grenade AI, lvl-2 gate, party-knob.
- **v3.47 SPELL REGISTRY + README rewrite:** new `tools/spell_registry.py` = single
  source of truth id -> (display name, real BG3 spell level [using-chain resolved
  from the pak census], classes that can learn it), plus BANNED ids (e.g.
  `Target_MAG_SpiritualWeapon` = lvl-6 once-per-rest item variant; use plain
  `Target_SpiritualWeapon` lvl 2). gen_teams.py main() calls `spell_registry.validate()`
  BEFORE generating: unknown id / level mismatch / wrong-class kit / kit-key-not-a-build
  = hard exit (6 negative tests pass: cleric+CallLightning, warlock+Sunbeam, Heal-as-lvl5,
  MAG_ id, bogus id, "ranged" typo all caught). Registry self-audit vs census fixed 9
  entries on first run (MinorIllusion/ArmorOfAgathys/MistyStep/Darkness/WallOfFire ids,
  ArmsOfHadar lvl 1, ConjureWoodlandBeings lvl 4, ProduceFlame lvl 0). Caught real kit
  bugs at the gate: **ranger had ZERO spells since v3.44** (SPELLS key was `ranged`,
  never matched build `ranger` - fixed); paladin kit lost Sacred Flame (no paladin
  cantrips in the 2014 ruleset). ⚠️ GATE LESSON: class sets must follow **BG3's lists,
  not the 5e PHB** - the gate first wrongly rejected druid Thunderwave+Blight (both
  ARE BG3 druid spells; bg3.wiki List_of_Druid_spells + owner's own in-game druid
  confirmed; registry fixed, both back in the roll). Owner dumped bg3.wiki class
  pages as lynx text into `docs/wiki-dumps/` (druid first) - the authoritative
  cross-check for registry class sets; BG3 also has exclusive spells (Enhance Leap,
  Create or Destroy Water). Wiki cross-check fixes: **Conjure Minor Elemental DOES
  exist** (`Target_ConjureElementals_Minor_Container` lvl 4 - v3.46 'absent' was a
  bad regex; re-added to druid roll prio2), Mass Healing Word is NOT BG3-druid,
  Wall of Fire IS. Wiki druid dump parses ~62 rows with one regex
  (`[n]Name [n+1]Link <C|1-6> <CastType>`).
- **v3.47b WIKI DUMPS AS CLASS GROUND TRUTH:** owner dumped ALL 10 bg3.wiki
  class spell pages (lynx text) into `docs/wiki-dumps/<class>_spells.txt`
  (bard cleric druid paladin ranger sorcerer warlock wizard arcanetrickster
  eldritchknight). New `tools/parse_wiki_spells.py`: generic parser (row regex;
  norm handles bg3.wiki quirks: British "Armour", "Bane (spell)" suffixes,
  "Conjure Woodland Being(s)") + `--check` cross-checks EVERY spell_registry
  entry (class membership AND spell level) against all dumps. Registry class
  sets REBUILT from the wiki (~30 entries changed): AT/EK get wizard cantrips +
  a few 1st/2nd spells; BG3 druid has NO Mass Healing Word; Thorn Whip + Moonbeam
  are NOT ranger spells in BG3; no Sacred Flame for warlocks; Cure Wounds IS
  bard+ranger (BG3); Heat Metal IS bard; Sunbeam IS sorcerer/wizard (lvl 6);
  Sunbeam IS sorcerer/wizard (lvl 6); Fly on NO class list (scrolls/items only
  -> empty set); Freedom of Movement NOT ranger (is bard). Exceptions in
  spell_registry.py: WIKI_EXCEPTIONS (Chromatic Orb warlock = Kindly invocation,
  not on lists) + FEATURE_IDS (Target_Smite_Divine = paladin feature, absent
  from spell tables by design); BANNED ids skip the check. Workflow: after any
  registry edit run BOTH `python3 tools/spell_registry.py --check` (kits) and
  `python3 tools/parse_wiki_spells.py --check` (wiki truth). Re-dump pages when
  bg3.wiki changes: `lynx -dump https://bg3.wiki/wiki/List_of_<Class>_spells`.
  Pak 452019 B. Slot curves now PHB-exact:
  FULL_SLOTS 4s@7, 5s@9, **6th slot @11/12 so Target_Heal (lvl 6) is reachable**
  (owner: Heal needs lvl 11); HALF_SLOTS no 4s at 11/12. Warlock Sunbeam/Disintegrate
  in owner log = Goon's Library, not our boosts (GOB_/UCL forensics dead-ended; owner:
  don't chase). README.md rewritten: 10 one-line bullets (owner: nothing in the old
  one held true - verified the classic tweaks still live: CarryWeightPerStr 10000,
  MaxShortRestPoints 3, XPData MaxXPLevel 50). Pak 451891 B. ⚠️ in-game verdicts
  pending: ranger casts Hunter's Mark now, cleric L11+ Heal, per-spawn toolkit variety.
- **v3.46 ROLLED SPELL KITS for cleric + druid (owner design:
  docs/spells-categories.md):** caster spell stacks are no longer static lists -
  gen_teams.py `SPELL_CATS`/`CANTRIPS` encode the owner's priority GROUPS (cleric:
  healing/buff/summon+debuff+damage; druid: healing/buff+summon/debuff+damage) with
  each spell's intra-group Pri column. `roll_spell_kit`: walk spell levels 1..max;
  each slot cycles the groups in prio order (prio1, prio2, prio3, loop once all
  used), picks WITHIN a group weighted by Pri (6/3/1 - sim: druid lvl2 picks
  HeatMetal+Moonbeam ~47% combined, HoldPerson 14.5%, SpikeGrowth 5.3%; Bless ~2x
  ShieldOfFaith). One spell known per slot; empty groups at that spell level are
  skipped, truly-empty spell levels leave the slot unfilled (mob upcasts its known
  spell - engine doesn't require 1:1). Cantrips: 2 known +1@4 +1@10, own Pri
  weights. EVERY LEVEL ROLLS INDEPENDENTLY and every regen re-rolls everything
  (`CHAOS_SEED=<int>` for reproducible rolls; default fresh random) - owner wanted
  the lvl-6 dwarf cleric to NOT be the lvl-5 clone +1 spell. Applied to cleric +
  all 3 druid builds; wizard/sorc/warlock/hexblade/paladin/ranger/bard keep static
  kits until the owner adds their category lists. ID census re-done from
  Shared.pak+Gustav.pak+GustavX.pak Spell_*.txt (all 5 layers incl. Honour, 4682
  ids, /tmp/opencode/sp3_ids.txt): all 33 used ids validated; Mass Cure Wounds =
  Target_CureWounds_Mass, Mass Healing Word = Shout_HealingWord_Mass, Command =
  Target_Command_Halt_NPC (AI entry), Heal = Target_Heal, Flame Strike EXISTS
  (Target_FlameStrike, SharedDev - earlier "doesn't exist" was a wrong-file grep);
  Conjure Minor Elemental does NOT exist (folded into Conjure Elemental container).
  Pak 451955 B. ⚠️ in-game verdict pending (cleric/druid toolkits vary per spawn).
- **v3.45 owner-playtest fixes (pak 451379 B):** (1) **Duelist had NO Two Weapon
  Fighting** - the subagent note "DualWielder table includes TWF@2/3" was WRONG
  (UCL_Generic_DualWielder rows are only BonusAC@4 + Dex+2@8); re-added
  `style2_twf` (UCL_2_FightingStyle_TwoWeaponFighting 5b91e529, L2 row grants the
  vanilla FightingStyle_TwoWeaponFighting passive) to fighter_dual's prog chain, and
  gave the rogue (also wp=dual) `UnlockPassive(FightingStyle_TwoWeaponFighting)` via
  DefaultBoosts (lvl5+ gated anyway). (2) **BOSS Duelist spawned with a single magic
  WARHAMMER** (log `magic: BOSS lvl 10 45% ... got WPN_HUM_Warhammer_A_1`) - the
  magicGear weapon slot always drew the generic 1h pool; the warhammer auto-equipped
  2-handed (versatile) so DEX was dead for hit/dmg and the light pair got displaced.
  magicGear weapon pool is now **kit-aware**: wp=dual -> WP_DUAL_1 (light pair),
  wp=twohanded -> WP_2H_1 (greatsword/greataxe/maul/halberd _1), else legacy
  MAGIC_WEAPON[band] (1h_shield/table/javelins), ranged keeps bows. Offline harness:
  350+ rolls per kit, 0 wrong-kit. (3) **clerics had Call Lightning** (owner: that is
  a DRUID spell; clerics' only 3rd-level attack option is Spirit Guardians) - removed
  from the cleric kit (druid healer/caster keep it; Flame Strike checked then and
  reported absent — WRONG, it exists as Target_FlameStrike in SharedDev, later
  restored via the v3.46 rolled kits where the owner lists it). Verdicts in from owner: cleric shields ✅, hexblade skills/
  stats ✅. ⚠️ pending re-verdicts: duelist dual-wields with TWF, magic kits match
  build, no lone-warhammer recurrences.
- **v3.44 CLASS-BUILD ROSTER (framework shipped, owner refs pending; pak 451056 B,
  178 stat entries / 1958 CHAOST templates, `!chaos_root` now expects 1958):** team
  slots now roll CLASS BUILDS (owner spec). gen_teams.py: `BUILDS` recipe table +
  `SLOT_VARIANTS` weighted lists → TeamTemplates.lua emits `CHAOS_TEAMS` (keyed by
  BUILD now), `TEAM_SLOTS`, `BUILD_PROFS/LABEL/WP/MIN`. Common.lua: `pickBuild(slot,
  lvl)` weighted roll with BUILD_MIN gate (monk/rogue/sorcerer/paladin/warlock/
  hexblade lvl5+ only - owner: they one-shot sub-lvl-4 parties; weights renormalize),
  `teamEntry` returns entry.build/wp. Offline sim: melee_dps lvl3 = barb 50/thrower
  17/druid 32; lvl8 all six; healer 75/25 cleric/druid ✅. Builds: fighter_brute
  (2h kit + prog_twohander GWM + style2_gwf), fighter_dual (Dex max, DualWielder table
  incl TWF@2/3, LIGHT armor at ANY lvl - wp dual, 2 light weapons), paladin (Ancients
  ba5b3a18 = real one; second same-named table 3835c8ee is Devotion mislabelled),
  barb_brute/barb_thrower (75/25, javelins wp = 3-8 WPN_HUM_Javelin templates), monk
  via **UCL_FourElements_Thief 3c756b75** (UCL has no plain monk; this is an NPC-safe
  full monk: Ki/Unarmored_Monk/MartialArts/Flurry/Deflect/ExtraAttack/Evasion + Thief
  at 7-9; vanilla Monk fe1319a2 rejected: SubClass entity refs + Select prompts),
  rogue (UCL_Rogue sneak ladder + GloomStalker), hexblade (25% of warlocks: Warlock+
  Fiend + DefaultBoost `WeaponAttackRollAbilityOverride(SpellCastingAbility)` with
  SpellCastingAbility=Charisma - SHILLELAGH grammar precedent; WPN_*_Pact templates
  exist but grant NO CHA boost, vanilla precedent is proficiency-only), druid healer
  (25% of healers), druid_shifter (CircleOfTheMoon; UCL_Druid lvl2 grants
  ActionResource(WildShape,2,0) via BOOST only, Moon adds tier passives + PrimalStrike),
  druid_caster (Spores), warlock (blast via UCL_CanEldritchBlast_1/2/3 PASSIVES at
  1/5/10 - not a spell row; WARLOCK_SLOTS curve + Hex unlock; GreatOldOne), sorcerer
  (WildMagic, CHA; no metamagic rows), wizard/ranger/cleric/bard = old configs renamed
  to build keys. Equip.lua `equipmentFor` wp directives: twohanded (WP_2H kit, no
  shield), dual (WP_DUAL 2 light weapons + armor forced light at any lvl/tier),
  javelins (melee table + 3-8 WP_JAVELIN), 1h_shield (HEAL_1H kit, covers paladin/
  hexblade), staff, unarmed (monk: no weapon/armor). All item ids live-dump validated.
  Progression forensics: /tmp/opencode/v344_prog_notes.md (1365 lines, subagent).
  ⚠️ IN-GAME VERDICTS PENDING: class mix variety in logs (`equip: tier ... role`),
  javelin throwers actually throwing, wild shape usable by druids, monk flurry,
  paladin smites, hexblade CHA melee, warlock blasts. Owner owes: build/item refs
  (warlock kit, hexblade details) - see backlog.
- **v3.43 armor-tier bands per level + capped MAGIC GEAR on leaders/bosses (owner spec
  after v3.42 playtest: "lvl7+ consistently wore heavy; 8+ should be plate"):**
  (1) band table replaces the v3.42 floor: lvl 3-4 floor2, **lvl 5 coin-flip floor2/3**,
  lvl 6-7 floor3 (medium), lvl 8+ floor4 (heavy/plate unlock); offline sim confirms
  base5 ~50/50 t2/t3, base6 100% t3, base8+ 100% t4. Boss +2 tier bump REMOVED -
  leaders/bosses get the SAME baseline as the encounter. (2) MAGIC GEAR replaces that
  bump: `magicGear()` in Equip.lua fires only for leaders (wild slotMap slots) and the
  boss at mlvl>=5; per-slot independent rolls - leaders 10/20/30%, bosses 15/30/45% by
  band 5-6/7-8/9+; item cap = band (1/2/3); slots (weapon-or-bow / armor / shield) are
  shuffled and rolled in random order; items = **vanilla quality-1 templates** (WPN_*_1
  carry WeaponEnchantment(1)+Magical, ARM_*_1 have AC+1 - no new stats content needed;
  all 16 ids validated in the live root-template dump: armor Padded f5faa6c5/Leather
  90a79e46/StuddedLeather 58d7927f/Hide 94ed8ec8/ChainShirt eac652ed/ScaleMail
  dc748177/Splint ecfb1364/Plate dd905194, shield WPN_HUM_Shield_A_1 cb2d6c27, weapons
  Warhammer 3e1b3db9/Battleaxe c17ee133/Morningstar deea755b/Mace 5a948b12, bows
  Shortbow a46173b7/Longbow 049173ec/HeavyCrossbow 6af59cba). +1 ceiling on purpose
  (owner: don't flood player loot). Magic item added via TemplateAddTo; the
  TemplateAddedTo listener auto-equips it and the replaced item drops as loot.
  isLeader plumbed Wild.lua spawnWildMob (slotMap[i]) -> EquipMob; combat
  reinforcements have no leader concept (no magic there). Log: `magic: BOSS/leader lvl N
  P% roll(s) got ARM_.../none on <guid>`. Pak 249709 B. ⚠️ in-game verdict pending.
  NOTE: vanilla "_1" = quality-1 items already enchant-1; ARM_Shield_1 stats point at
  WPN_HUM_Shield_A_1 root (cb2d6c27). v3.44 = class roster expansion (druid healer
  25%, 2x fighter dps, barb thrower 25%, warlock/monk/rogue/sorcerer/paladin lvl5+
  gate, hexblade 25%, druid shapeshifter 75%/caster 25% dps) - BLOCKED on progression
  TableUUIDs for the new classes (not yet extracted; look in vanilla pak
  ProgressionTable .lsx via divine -a extract-package -x "*rogression*").
- **v3.42 healer kit + level tier floor (owner v3.41 verdict: Githyanki squad looks
  GREAT, baked-look vs rolled-gear mismatch explicitly ACCEPTED; HP ✅ - L8 berserker
  108, L5 cleric 60, L6 hunter 70, L5 vanguard 70 = right chaos band):** two balance
  fixes. (1) HEALERS ALWAYS 1h+shield (owner: "cleric wields a 2h weapon, should always
  be 1h+shield for more AC"): composer `entry.role=="healer"` short-circuits the weapon
  tables; kit = validated WPN_HUM_Mace/Warhammer/Battleaxe/Morningstar _A_0 templates
  (_A_1 at tier 4) + shield 100% when Shields-proficient (HEAL_1H/HEAL_1H_1).
  (2) TIER FLOOR per level (owner: "no lvl6-8 fighter in stock light/padded"): lvl3-5
  never tier1, lvl6+ never below tier3 (= medium unlock; heavy stays tier-4 jackpot);
  group-roll bump/boss +2 still stack above the floor. Pak 247982 B.
- **v3.41 NAKED-MOB MYSTERY CLOSED as render-layer (owner verdict v3.40: "AC 16 hunter /
  AC 15 tank in fight, weapons from round 0 - but still naked"):** equip mechanics are
  PROVEN (gear probes Breast=OK + AC math). The `equip REFUSED` lines were a log artifact:
  Osiris CALLs return nil even on success, so only an explicit `false` is a refusal.
  Root visual cause: the client does NOT attach body-armor item art to NPC bodies at all
  - vanilla NPCs wear their gear BAKED INTO the per-template CharacterVisualResourceID
  body mesh (armored AbsoluteGuard CVRID 10058599 vs our civilian BASE_Humans_Male
  c0807a07; same generic VisualTemplate 3773c64c). Hand props (weapons) DO attach, which
  is why only weapons showed. FIX: gen_teams now overrides `CharacterVisualResourceID`
  on every CHAOST node with vanilla guard-style bodies per donor race x role class
  (tank/melee/wildcard -> Guard_Melee body, ranged -> Ranger, healer/caster -> Caster;
  table RACE_VISUALS/ROLE_VIS, harvested from vanilla templates' OWN CVRIDs incl.
  HalfOrcs which live in SharedDev/_merged - new extraction /tmp/opencode/rt3; that also
  explained probe CVs 9ec94019/e23ab84d = HalfOrcs_M/F base bodies = inheritance works).
  PROBE_GEAR=false now. Pak 247086 B, 792/792 nodes carry the override. BACKLOG: goblin
  _Tier2 bodies (fb5c6d24/66a0dc01/b1825b38) for tier>=3 squads; tiefling bodies are a
  gamble (Asmodeus Player_Strong/InvokeDuplicity - iterate on owner verdict); human_m
  caster reuses the guard body (no clean vanilla cleric CVRID found; TEST_* skipped).
- **v3.39 (owner verdict on v3.38: "Equipment works! Stats work!"):** naming ✅ (live log:
  "Elf Cleric"/"Human Vanguard" namefix lines), ARM_* equip lines ✅, casting pending
  more observation. Two follow-ups. (1) **HP still ~2x** — diagnosis CONFIRMED: L7
  barbarian 187 (that one was the LEADER: + CHAOS_VIT_1 buff on top), L5 110 vs curve 53,
  L4-5 grunts 70-110 vs a lvl-5 party at 50-60. Fix applied: Vitality = **level-1 pool
  only** (hp(1)) in gen_teams; the engine's LevelOverride+Progressions leveling adds the
  per-level hit dice. Owner explicitly wants the DICE kept (deterministic 5e class pools
  rejected — "rolling hit dice per level... exactly what we want with the chaos system").
  Expect L7 barbarian ~60-80 now. (2) **Blue-robe mystery:** armor equips per log, but
  every team member renders the same blue robe (weapon art fine). Excluded: our pipeline
  (clothes gated `if not armor`), dead art (plain ARM_* root templates DO carry
  VisualTemplate - earlier regex lied because root .lsx uses GameObject nodes, not
  "record"), race-suffixed variants (none exist). Robe is game-side: visual fallback or
  inherited donor item. FURTHER EXONERATIONS: donor BASE_* node carries NO item children
  (BASE_* families live in GustavDev _merged, not Shared); the ST_* weapon tables hold
  ONLY I_WPN_* (no garments). Prime suspect: OutfitOverride (vanilla default-outfit
  channel for unspecced BASE_* civilians - Commoners' Robes ARE that blue robe) - the
  probe dumps it too. v3.39 ships a ONE-SHOT gear probe (PROBE_GEAR=true in Equip.lua):
  first 3 armored spawns dump Equipment+Inventory+OutfitOverride components to profile
  file Chaos_gear_dump.txt (file, not main log). Read it next session to name the robe,
  then flip PROBE_GEAR=false. Pak 233517 B.
  PROBE v1 RESULT (2026-11-02 late session): raw field access ent.Equipment/Inventory =
  NIL server-side (Equipment is the CLIENT-side component; server data lives in
  GetComponent("ServerCharacter") per ECS docs). Owner also now sees patrols TOTALLY
  NAKED (weapons in hand) - earlier "blue robe" was v3.38 half-elf teams, today's
  tiefling/goblin teams naked; both had clean 'equipped ARM_*' log lines. Probe v2
  (pak 233774 B) dumps GetAllComponentNames + ServerCharacter + named components, cap 2
  mobs. Read Chaos_gear_dump.txt next session.
  PROBE v2 RESULT + ROOT CAUSE FOUND (2026-11-03): the 53K ServerCharacter dump has ZERO
  ARM_/WPN_ refs (item instances aren't held in that component - the dump was a dead
  end) BUT it exposed the vanilla-vs-us delta: `PlayerStats.Equipment: ""`, while vanilla
  armored NPCs carry an equipment SET (Equipment.txt EQP_* sets, e.g.
  EQP_Halberd_Plate_Shortbow, plus EquipmentRace/EquipmentTypes/ItemList nodes; the
  render-attachment machinery lives in Mods/Shared/EquipmentSettings/*.lsx). Decisive
  evidence came from story_header.div + vanilla goals: `Equip(char, item, 1, 0, 1)`'s
  trailing args are HAND args (the offhand example uses 1,0,0) - OUR listener forced MAIN
  HAND on everything, so body armor failed at Osiris level (EquipFailed event exists,
  arity 2) while weapons "equipped" fine because they wanted the main hand. Our pcall
  success-log never checked the Osiris return. v3.40 FIX: bare Osi.Equip(char,item) =
  engine auto-slot (vanilla precedent). Probe v3 replaces the ECS dump: GetEquippedItem
  (mob,"Breast") + GetEquippedWeapon -> one compact 'gear probe:' log line per mob
  (cap 4) + capped EquipFailed listener. Slot names from vanilla goals: "Breast",
  "Melee Main Weapon", "Melee Offhand Weapon". If Breast still EMPTY after the fix,
  next lever = CharacterGiveEquipmentSet(EQP_*) - the native vanilla outfit channel.
- **v3.38 casting + team naming (owner team-fight reports, `game-logs/team-fight-1.txt`;
  note: those fights ran v3.36, so the v3.37 armor/ability fixes are still UNVERIFIED):**
  AI quality praised (potion-throwing between allies, web grenades, Action Surge, weapon
  actions, Warding Flare reaction, barbarian popping a Dancing Lights scroll) - the gap:
  ZERO castable spells (cleric only meleeed, ranger never marked). Vanilla census
  (subagent 2026-11-02): Character entries NEVER carry spell tokens; generic mobs get
  spells from the root-template `SpellSet` attr (MOO_Guard_Cleric), named casters grant
  via `UnlockSpell(...)` in DefaultBoosts/passives (Goblin_Cleric, DEN_Rolan,
  TWN_Githyanki_Warlock); slots = `ActionResource(SpellSlot,n,lvl)` or NPC_* progression
  rows. We take the stats channel: per-level `DefaultBoosts` on each CHAOST_<role>_L<lvl>
  = vanilla slot curves (FULL_SLOTS cleric/wizard, HALF_SLOTS ranger/bard) + level-gated
  UnlockSpell kits for healer/caster/ranged/wildcard. ALL spell ids validated vs vanilla
  Spell_*.txt (Target_SacredFlame, Target_MAG_SpiritualWeapon, Shout_SpiritGuardians,
  Target_HuntersMark, Projectile_FireBolt, Zone_Thunderwave...; NO generic
  Suggestion/DissonantWhispers/LightningBolt entries exist). Naming: tooltip showed the
  DONOR's loca name ("Drow Half-Elf") because FlavorNameFix only renamed BLANK names -
  CHAOST mobs now relabeled unconditionally to entry.nm, and ROLE_LABEL went
  class-flavored (Cleric/Wizard/Hunter/Berserker/Vanguard/Bard) -> "Half-Elf Cleric".
  Owner's Proton/Vulkan fix: Full screen -> **Borderless window** = permanent cure for
  both the minimize-on-click-outside and the swapchain thrash (worth a line in any
  Linux/Proton install notes). Also corroborated v3.37: saving-throw profs + weapon
  actions prove Progressions apply, and "12 in primary stat, 10 rest" = base 10 + the
  asi_* progression node's +2 (our stats lines were still dropped in v3.36) -> with the
  token fix expect real scores (dex-16 ranger etc). Pak 232879 B. Pending: everything
  v3.37 pending + visible spell bars + AI actually casting + "Half-Elf Cleric" tooltips.
- **v3.37 team look & stats fixes (owner 2026-11-02 half-elf squad report):**
  THREE findings. (a) **Underwear armor:** the ST_Light/Medium/HeavyArmor treasure
  tables reference I_ARM_*_Body loot stats-ids with NO root template in the live
  dump (ARM_Leather exists, ARM_Leather_Body doesn't) -> GenerateTreasure silently
  yielded ZERO armor (bare pcall hid it for dozens of versions). Armor now comes via
  direct TemplateAddTo of REAL ARM_* root templates (light/medium/heavy bands,
  TemplateAddedTo auto-equip listener, ids validated against the live dump - all 10
  OK) -> equipped AND visible; GenerateTreasure failures now log loudly.
  (b) **Abilities never applied:** gen_teams wrote `data "STR"/"DEX"/...` but stats
  tokens are FULL names -> parser dropped them silently, every CHAOST mob ran on
  _Human base scores (lvl-7 ranger with 10 dex). Regenerated all 72 stat entries
  with Strength/Dexterity/... (roles keep 16-stat mains). (c) **Black-screen crash
  re-diagnosed:** owner saved gold/network logs to repo `game-logs/` - gold log
  shows 13x "SwapChain: got 0x0 extent -> going offscreen" churn after repeated
  alt-tabs, zero Lua/mod errors, network log clean => Proton/Vulkan focus thrash,
  NOT the mod (v3.34 dangling-visual renderer hypothesis downgraded). Tell: avoid
  rapid alt-tabbing (or borderless window). AC math verified our stats Armor token
  DOES apply (tank 16 = natural 14 + shield 2, melee 12 = natural 12). Compile OK,
  792 templates regenerated, Pak 231985 B. Pending: visible armoured squads, real
  ability scores (dex-16 ranger hits/sharps). HP MYSTERY SOLVED OFFLINE (hypothesis,
  pending in-game confirm): our GustavDev HEALTHBOOST_HARDCORE override is loaded
  (Boosts all commented -> no vanilla +30% interference), yet observed HP = curve +
  EXACT max class hit dice: two d10 L7 mobs +70 (10+6x10), barbarian L4 +46~48
  (d12 max) -> LevelOverride+Progressions make the engine GRANT real class levels
  on top of the already-cumulative Vitality curve (double-count). Prediction to test:
  CON mods now apply, so tank L7 (CON 15) should land ~73+70+14=157 and ranged L7
  (CON 13) ~57+70+7=134; if confirmed, fix = drop the cumulative Vitality curve
  (Vitality = level-1 hit die only) and let leveling do the rest, OR strip Progressions.
- **v3.36 log hygiene (owner 2026-11-02):** the one-shot "Race static sample dump"
  (Ext.DumpExport of a Race static resource = hundreds of lines, spammed the main log
  unreadable) moved OUT of ChaosReinforcements.log -> profile file
  `Script Extender/Chaos_race_dump.txt` (Ext.IO.SaveFile; the probe was a race-format
  one-off, race work now = GetRace discovery lines + grow_race_to_type.py). Fight
  bookends added in Chaos.lua: unconditional `================ COMBAT <id> STARTED/ENDED ================`
  separators on CombatStarted (after dedup) / CombatEnded (new listener) - wild-group
  aggros fire CombatStarted too, so spawned fights are bookended as well. Compile OK,
  Pak 230832 B.
- **v3.35 wake-camp loophole + force console + spawn coords (owner 2026-11-02):**
  camp guard worked, but sleep->wake let a warband spawn 19 s after "at CAMP": the
  wake sequence re-fires TeleportedToCamp/FromCamp for EVERY character (party,
  summons, Scratch the dog, courier dog) and releases the HOST latch silently
  (the "camp done" log only fires when `campers` empties — summons/pets never
  leave). Fix = `WILD_CAMP_QUIET_MS` 30 s quiet window refreshed by ANY camp event
  either direction (while camp machinery flaps, no spawns/aggro) + explicit
  `host LEFT CAMP - quiet ~30s` log. Scratch verdict: red herring — non-party
  members never trigger spawns (heartbeat gates on host only). Also: NEW
  `!chaos_force spawn on|off | type <Type>|off | tier 1-3|off | off` console overrides
  (owner wants controlled humanoid-TEAM iterations: force roll pass + flavor; forced
  type beats region theme, forces evil packs -> TEAM mode; gates stay respected;
  replaces dead setterless one-shot WILD_FORCE_TIER), and wild spawn lines now carry
  `map (x, z) h y` coords (BG3 horizontal plane = x/z, matches the minimap readout).
  `!chaos_status` shows force state + camp-quiet countdown. Compile OK, Pak 230256 B.
- **v3.34 false-aggro race + invisible CHAOST donors fix (owner 2026-11-02: "3 groups
  in a row spawned and instantly 'aggro fizzled' while I stood still 60-70m away;
  2-person tiefling team totally invisible with fallback portrait; game hangs to
  black screen during wandering-mob fights, 2-3x"):** TWO bugs, both found from the
  log. **(a) False-aggro race:** heartbeat (90s) and monitor (2s) both start at
  SessionLoaded and 90%2==0 → PHASE-LOCKED, monitor tick always fires right after the
  heartbeat's spawn block while AppearAtPosition teleports are unsettled and
  GetPosition still reads the host-adjacent CreateAtObject spot → "player within 12m"
  → spurious aggro from 60-75m → group leaves tracking → SetHostileAndEnterCombat on
  distant mid-appear mobs never sustains → "never engaged" 6s later, no backoff, next
  heartbeat spawns another victim (the old pre-v3.25 "aggroed + backoff 10min" lines
  were the same bug silently eating spawn chances). Fix (Wild.lua): `WILD_SETTLE_MS`
  5s settle stamp on group creation (no aggro/expiry while settling), member-position
  sanity (only members within `WILD_MEMBER_SANITY_M`=25m of the recorded group center
  count for aggro - also ignores the observed ~937m AppearAtPosition fallback), and
  **de-orphan**: a "never engaged" verdict re-adds the group to tracking (mobs are
  alive out there) so proximity + TTL govern them again; brief-but-real fights
  (combatMs>0) stay untracked (a TTL delete could strip lootable corpses).
  **(b) Invisible team members:** gen_teams.py DONORS for tiefling_m/gith_m carried
  RUNTIME INSTANCE guids copied from an equip-log line ("TemplateName_<instance>",
  not the template MapKey) → dangling ParentTemplateId → no visual inheritance →
  invisible body + shadowed fallback portrait (stats/kit fine - explicit on the
  node, matching the owner's "proper lvl7 barbarian" inspection). Real donors:
  tiefling_m = `Tieflings_Male_Asmodeus_Guard_Caster_806815fc-...`, gith_m =
  `Githyanki_Male_Guard_Caster_49567bbf-...` (both vanilla merged.lsx, both proven
  visible as wild pool spawns). All 792 CHAOST templates regenerated (new mapkeys);
  `validate_donors()` in gen_teams.py now hard-fails if any donor id is not a real
  MapKey in the live root-template dump. ⚠️ Crash hypothesis (unproven): renderer
  hang on dangling-visual characters (all black-screen hangs happened during
  wandering-mob fights; no dumps/crash artifacts in SE logs or journal) - expect it
  to disappear with the donor fix; if it persists, look at orphaned invisible packs
  from PRE-fix sessions (gone after session restart - temporary=1). Pak shipped,
  lsf verified (72x each corrected donor, 0x bogus). Pending verdicts: visible
  tiefling/gith teams, no more spawn-time "aggroed" lines, settle-guard no-aggro.
- **v3.26 HOTFIX: `os` does not exist in SE server Lua (owner: "no log output anymore,
  new game on v3.25"):** the Extender Runtime log (profile `Script Extender Logs/`,
  per-session files — the prefix-home path in AGENTS.md is stale) showed
  `Common.lua:14: attempt to index a nil value (global 'os')` at every log() call:
  v3.23's "fail-soft" `pcall(os.date, ...)` evaluated `os.date` BEFORE pcall guarded
  it. Since log() runs in module main chunks (Chaos.lua:336), the SessionLoaded
  handler (Wild.lua:683, BEFORE the heartbeat/monitor timer lines) and Osiris
  listeners, the whole wild engine silently never started: no spawns + no game-log
  lines for every session running the v3.23+ pak (v3.23-25 were effectively untested
  in-game; the timestampless tail lines in ChaosReinforcements.log were an OLD pak
  session still open until 15:00). Fixes: clockStr feature-detects
  `Ext.IO.GetCurrentDateTime` (wall HH:MM:SS), falls back to
  `Ext.Timer.MonotonicTime` (+HH:MM:SS session-relative — v3.26.1: MonotonicTime is
  OS-BOOT time, owner's `+332:32:15` stamp was machine uptime; the first reading is
  now anchored as t=0), then to no stamp; log() body
  is fully pcall-guarded (must never throw at callers) with varargs passed EXPLICITLY
  into the inner fn (nested `...` is Lua 5.2+ syntax; lupa/LuaJIT compile-check
  caught that second bug); `Ext.Print` at BootstrapServer:15 removed (nil on server,
  threw every load — pre-existing noise), client one pcall-guarded. ⚠️ RESTART
  REQUIRED to load the fixed pak; v3.24 (SetLevel crash fix), v3.25 (fizzle backoff)
  and the owner's bc04df4 potion fix all ride along, still awaiting first real play.
- **v3.25: fizzle-aware wild backoff + camp guard confirmed (owner 2026-11-01):** owner
  ruling on the dry-spell tuning question — a FIZZLED aggro (e.g. the camp brief-
  initiative) "should count as an anomaly and not start the backoff counter".
  `aggroGroup` no longer arms the 8-10 min backoff; instead the monitor adjudicates the
  last aggroed group via `pendingEngage` (aggroed groups leave `groups`, so it needs
  its own tracker, checked every 2 s tick BEFORE the empty/max-group returns):
  `combatMs` accumulates while any member has `IsInCombat`=1; backoff arms once
  `combatMs >= WILD_REAL_COMBAT_MS` (15 s — "real fight confirmed"); `goneMs >=
  WILD_ENGAGE_GRACE_MS` (6 s out of combat) closes the verdict as "fight lasted ~Ns -
  fizzle" or "never engaged", logging the anomaly with NO backoff. Grace also absorbs
  mid-fight 2-4 s `IsInCombat` blips (sim-tested S4) and aggro-startup lag. Frozen
  while camped (combat cannot happen there; verdict resolves after leaving camp).
  `!chaos_status` gained a `fight` field (`-` / `pending` / `~Ns, arming?`). Offline
  lupa sims: real fight arms, 4-s fizzle does not, never-engaged does not, blippy
  fight arms. Camp guard ⚠️ resolved ✅ (see v3.22/v3.23 notes); backlog camp-confirm
  item removed.
- **v3.24: `Osi.SetLevel` REMOVED from both spawn engines (first hard game crash,
  2026-11-01):** crash-handler backtrace = `bg3.exe ← bg3se::OsirisWrappers::CallWrapper
  ← OsiCall`, Lua frames `Wild.lua:211` inside `spawnWildMob`'s pcall — that line was
  `pcall(Osi.SetLevel, mob, targetLevelFor(base))` in the installed v3.22/23 build
  (owner thought it was the old pak, but the line numbers match current numbering).
  **pcall cannot survive native engine faults**, and the v3.3 lesson already showed
  SetLevel only sets the level NUMBER (never rescales fixed stat blocks) — purely
  cosmetic next to a crash. Removed from `spawnWildMob` (Wild.lua) and `spawnCreature`
  (Chaos.lua, incl. the 2 s verify timer; `VERIFY_DELAY_MS` const dropped). Over-level
  self-correction guard now reads the template's NATIVE `GetLevel` in both engines
  (Wild keeps the `fixedLevel` team-template exemption). Difficulty stays controlled at
  PICK time via gatedPool's native-stat gates. `spawnCreature` still takes the unused
  `targetLevel` param and `targetLevelFor()` is still computed at Chaos.lua — deliberate
  dead weight for now. ⚠️ playtest: crash must not recur; mobs show their native levels.
- **v3.23: log timestamps + self-diagnosing heartbeat (owner 2026-11-01, "10-min dry
  spell" report):** every `log()` line now carries `[CHAOS HH:MM:SS]` (fail-soft
  `os.date`), and every heartbeat gate that blocks a spawn states its reason via
  `wildIdle()` — camp latch?, no host, safe haven (crime/level), max groups,
  **encounter backoff ~Nmin left**, host in combat, chance roll N (need <=25) — logged
  on reason change, re-stated every 8 ticks (~12 min). Diagnosis of the dry spell was
  pure math, NOT a bug: `aggroGroup` arms an 8-10 min backoff (WILD_BACKOFF_MIN/MAX)
  on ANY aggro — even the fizzled camp fight — and it keeps ticking down after the
  group expires; after that it's 25% per 90s heartbeat (~6 min expected per attempt).
  The post-camp `crime-region` lines proved the heartbeat was alive and the v3.22 camp
  guard NOT latched. ⚠️ still open: `wild: at CAMP` never appeared in that log — either
  no camp inside the 10-min window or `TeleportedToCamp/FromCamp` don't fire for the
  camp UI; next camp MUST show it (if not: fallback = camp crime-region value, which
  is now visible via the heartbeat's crime probe + timestamps).
  **RESOLVED 2026-11-01: owner confirmed in-game — camping logs `wild: at CAMP` and the
  camp guard works; no crime-region fallback needed.**
- **v3.22: camp guard (owner incident 2026-11-01: warband spawned AT the campfire):**
  making camp does NOT swap the Osiris level — no `LevelLoaded` fires, the wild gate
  stayed OPEN on `WLD_Main_A` while camped, and the heartbeat anchored 4 skeletons at
  the host's campsite (brief interrupted combat + despawns; log excerpt confirmed).
  Wild.lua now tracks `campers{char}` from the `TeleportedToCamp`/`TeleportedFromCamp`
  Osiris events (story_header.div 1218-1219, arity 1 — the engine teleports the party
  to the campsite, that IS the camp signal); heartbeat skips while the HOST is camped,
  monitor skips aggro+expiry too (groups idle at their spots). Per-char tracking so a
  single companion sent to camp (`SendToCamp`) doesn't freeze world spawns; `LevelLoaded`
  resets `campers` (fast-travel may lack a FromCamp event). ⚠️ playtest: camping must log
  `wild: at CAMP (...)` — if it never appears, the events don't fire for the camp UI and
  the fallback is the camp crime-region value (heartbeat already logs region changes).
  **✅ CONFIRMED 2026-11-01 by owner playtest: camping logs `wild: at CAMP (...)`,
  spawns pause, and the campsite stays clear.**
- **v3.21: class-appropriate "support" slot (owner spec 2026-11-01, same day as v3.20):**
  role-keyed extra pocket in `EquipMob` — **casters** get 0-X `LOOT_SCROLL_*` (low: cantrips/
  1st-level like MagicMissile/Thunderwave; mid: Fireball/Web/ChainLightning/Confusion; top:
  Sunbeam/WallOfFire/Cloudkill/Disintegrate/Fly), **ranged** get a bow (`ST_SimpleRangedWeapons`
  via GenerateTreasure, so ammo is usable) + 0-X `ARR_Arrow_Of_*` stacks of 3-5 (low: elemental
  fire/ice/lightning/acid; mid: Ricochet/Piercing/Smokepowder; top: Detonation), **melee** get
  0-X stronger poisons + `ALCH_Solution_Grenade_*` throws (low: Serpent venom/light grenade;
  mid: Drow/Malice + Web/Confusion spores; top: Wyvern/PurpleWorm + toxic spores). Pool band =
  group tier (+1 when equip tier ≥3, clamped 1-3); COUNT = binomial cap `min(groupTier + tier3
  +1 + tier4 +1, 4)` at p = 30/60/80/100% per equip tier — offline sim: warband caster ~3.5
  items/member, core caster ~0.4, ranged stacks avg 4.4, boss tank (tier 4) full 4-load. Role
  from team `entry.role` (Wild's `teamEntry` now tags it); CreatureDB pool mobs get a caster
  guess when they have no weapon/armor profs, else melee. ⚠️ NPC AI actually USING scrolls/
  arrows/grenades is unverified (backlog playtest item); log line `support: <role> band <n>`.
  Lua gotcha hit: `supportSlot` early-returning `0` (= truthy) made `ipairs(0)` throw — return
  `nil` for the picked list.
- **v3.20: equip tier keyed to the wild GROUP tier + potion ladder (owner review 2026-11-01):**
  `spawnWildGroup` now passes its group tier (and `isBoss` for the boss slot) through
  `spawnWildMob` into `EquipMob` — no more independent per-member equip lottery for wild
  packs: tier baseline = group tier, 20% chance one band up, boss +2 (combat reinforcements
  keep the legacy self-roll). Equip tier 3 finally *does* something: unlocks medium armor
  (heavy + magic/scaled weapon tables stay tier-4-only). Consumables became a baseline +
  ladder: healing potion guaranteed for every member lvl ≥ 3 (old 10%/25% odds stay below
  that — the dps-can-throw-a-potion intent), then ONE extra roll from the member-level-band
  pool (owner bands: low 1-3 = Basic poison heavy + antitoxin/resistances, mid 4-8 = heroism/
  resistances + Drow/Malice poison, top 9-12 = regen/invisibility/Wyvern/PurpleWorm poison
  with **Speed as crown jewel, only in top**); DONOTUSE templates excluded, ids from the live
  root-template dump. Also fixed: leaked `boss` global in `spawnWildGroup` (a tier-3 roll
  used to make every later group's slot-1 a BOSS with +3 lvl) — `equip tier (group N)` now
  visible in `ChaosReinforcements.log`. Offline sim sanity-checked via lupa (equipsim pattern).
- **v3.9: leader flavor (owner playtest feedback round 2):** the v3.8 popup
  (`OpenMessageBox`) broke immersion AND halted combat until clicked — REMOVED. Replaced
  by a vanilla **voice bark** on the player: `Osi.StartVoiceBark(barkResource, source)`
  (story_header.div:1308) — subtitle lingers over the head a few seconds and disappears on
  its own; bark texts live in loca (unreadable offline), so barks are picked by NAME theme
  (currently `HAV_VB_ShadowSiege_PlayerEntersCombat_…`); `VoiceBarkStarted`/`Failed`
  listeners log the outcome. **Rename root cause found:** `Entity:Replicate()` expects the
  component OBJECT, not its name string (v3.8: "Param 3: expected a light C++ object, got
  string") — the `dn.Name = name` write itself succeeded. **Leader stat buffs landed (the
  deferred custom-stats route, partially):** pak now ships
  `Public/ChaosReinforcements/Stats/Generated/Data/CHAOS_Boosts.txt` (NEW file names count
  inside a pak) with boost statuses `CHAOS_VIT_1/2/3` (`IncreaseMaxHP(20/35/50%)`) and
  `CHAOS_STAT_1/2/3` (`Ability(Strength,N);Ability(Dexterity,N);Ability(Constitution,N)`;
  the ability-increase functor is `Ability(<Ability>,<n>)`), applied per leader via
  `Osi.ApplyStatus(created, tier, -1, 1, created)` with a random tier each — the tier
  ladder approximates the owner's `+20-50% vit / round(+10-20%,1) stats` spec.
  `tools/pack_mod.sh` now stages `Public/` next to `Mods/`. ⚠️ All three (rename,
  bark, boost statuses) need the next playtest to verify — log lines: `leader renamed to:`,
  `bark started:/FAILED:`, `leader buffs: … ok`.
- **v3.7: module split + lvl-1 cheapest-gear rule** (owner request): Lua is now
  `Server/Common.lua` (log + shared constants: EVIL/HERO pair, SOFT_CAP_LEVEL, HEAVY_LEVEL,
  HEAVY_TYPES) → `Server/CreatureDB.lua` → `Server/Equip.lua` (all equipment logic:
  `EquipMob`, `EquipPlanFor` exposed for offline tests, auto-equip listener) →
  `Server/Chaos.lua` (engine only). BootstrapServer requires them in that order. Equipment
  rules now: host lvl 1 = ALWAYS cheapest (simple/finesse weapon + light armor, innate
  attackers still get nothing) regardless of prof or tier; lvl 2+ tiers roll again and
  martial weapons unlock at tier ≥ 2 if proficient; armor tier 1-3 = light (if any armor
  prof), tier 4 = medium if prof (heavy only at HEAVY_LEVEL, prof required); jackpot magic
  weapon tables only at lvl ≥ 4. Offline-verified via lupa (Merregon plan table in git
  history). **New doc: `docs/encounters.md`** — cookbook of all encounter-adding routes
  (SE Lua, story goals, .lsf pre-placement, treasure tables, custom stats/templates, ruled
  out) for future features.
- Deploy helper: `tools/deploy_lua_mod.sh` (dry-run verified; Route B only — kept as fallback).
- Post-mortem of the user's dead Lua mods (`Data/Mods/HealthBoostLocal/`,
  `Data/Mods/HPChaos_…/`, also in game-root `Mods/`): no `meta.lsx` (they used `Mod.json`), not in load
  order, no `ScriptExtender/Config.json`, and invented APIs (`Ext.RegisterListener`,
  `Ext.GetDifficulty`, `Ext.StatusAdd`, `Ext.Debug`, `Ext.Random`). Safe to delete **pending user OK**.

## 6. Reference material already distilled

- `docs/spawn-chains.md` — Osiris goal channel, §3 (+§3.1.1) mount forensics and E1/E7 protocol,
  §5 primitives, §12 test walkthrough.
- `docs/lua-modding.md` — SE layout rules, load-order reality, post-mortem, spawn API table.
- `docs/vendor/bg3se-Lua-API.md` — upstream SE Lua API vendored (2013 lines, 84 KB, "v30" text for
  SE v33). **Grep this before using any `Ext.*`/`Osi.*` name.**
- `../Mods/GustavDev/Story/RawFiles/story_header.div` — authoritative signatures: `CreateAt` 507,
  `CreateAtObject` 508, `FindValidPosition` 573, `GetPosition` 543, `SetHostileAndEnterCombat` 921,
  `SetFaction` 933.
- `../Mods/Gustav/Story/RawFiles/Goals/Test.txt:345-356` — Larian's own spawn test (wolf template).
- `../Mods/Gustav/Story/RawFiles/Goals/TUT_Helm.txt:896-1010` — vanilla mid-combat reinforcements via
  `PROC_Appear` + `PROC_GLO_NarrativeCombat_JoinCombat`.
- Validators: `python3 tools/check_goal.py` (currently ok), `python3 tools/validate_treasure.py` (0 errors).

## 7. Osiris/Lua facts worth not re-deriving

- `CreateAtObject(TemplateId, Anchor, Temporary, PlaySpawn, SpawnFinishEvent, MatchOrientation, out)`;
  `CreateAt(TemplateId, X, Y, Z, Temporary, PlaySpawn, SpawnFinishEvent, out)`;
  `GetPosition(out X,Y,Z)`.
- Factions in use: `Evil_4be9261a-e481-8d9d-3528-f36956a19b17`, `Hero_a1542c81-6895-929e-4522-10ce218bb360`.
- Real SE entry points: `Ext.Require`, `Ext.Osiris.RegisterListener(name, arity, "after", fn)`,
  `Ext.Events.SessionLoaded:Subscribe`, `Osi.*`, `Osi.DB_X:Get/Delete`,
  `Ext.Template.GetAllRootTemplates()`, `Ext.Level.GetHeightsAt(x,z)`, `Ext.IO.SaveFile`,
  `Ext.RegisterConsoleCommand`, console `reset` to reload Lua VMs. Server state owns Osiris;
  SE Lua object handles expire per game loop.
- Imp-room templates named by vanilla goals: `S_FirstFight_Imp_Melee_01_07f1512b-…`,
  `…_Melee_02_5c5bd50b-…`, `…_Ranged_01_38d1ce2f-…`, `…_Ranged_02_df44fa65-…`.
- Cross-level template instantiation ✅ works for **global** root templates (E8b wolf). The imp
  rule's silence points at level-placed **instance** ids (`S_FirstFight_Imp_*`, vanilla casts them
  `(CHARACTER)`) not resolving as `CHARACTERROOT_` literals → use global templates for spawns;
  the SE template dump enumerates them.
- `GetHostCharacter` = the network host's PLAYER — spawning "on" it drops mobs on the party.
  For reinforcements, anchor elsewhere and use the vanilla join pattern: `PROC_Appear` +
  `PROC_GLO_NarrativeCombat_JoinCombat` (`Gustav/.../TUT_Helm.txt:896-1010`).
- Save files (`HonourMode.lsv`, LSOF + one zstd frame) carry no `DB_` fact strings → useless for
  reading story state. No precompiled story cache anywhere (`Data/Generated/` = Public/Engine/Assets
  only). Game logs `bin/gold.*.log` / `bin/network.*.log` show no story-compile output.

## 8. Ranked next moves

1. ~~**E8 — armed**~~ **DONE, POSITIVE (2026-10-31):** the new-name copy spawned the wolf, so
   invented `MARTIN_*.txt` goal names compile+fire in the live mount. Probe deleted; story mount
   100% vanilla. Shipping shape settled: own files in `Data/Mods/<Module>/Story/.../Goals/`
   mirrored by `tools/deploy_story.sh --copy`; pak = pure packaging/portability later.
2. **Pak CLI ✅ DONE (2026-10-31):** native Linux Divine build (`tools/divine.sh`), ModFixer.pak
   round-tripped, probe mod packed+installed via `tools/pack_mod.sh --install` →
   `…/Baldur's Gate 3/Mods/ChaosReinforcements.pak`. SE v33 updater installed to `bin/DWrite.dll`.
   **Owner run DONE (2026-10-31):** mod enabled, SE v33 loaded, Lua ran. Forget `bg3-print.log`
   (obsolete) — signals are the profile `Script Extender Logs/` runtime log + profile
   `Script Extender/ChaosReinforcements.log` + `Chaos_root_templates.txt` (32017-entry dump,
   read via `Ext.IO.SaveFile`). That dump settled the
   imp-instance question and enumerates the **global root template pool** the chaos engine draws on.
3. ~~**Chaos engine in Lua**~~ **DONE — v3.1 packed+installed (2026-10-31), awaiting playtest:**
   stacking trigger, typed 622-creature DB, type affinity, budget with party knob, SetLevel
   scaling + delayed verify, leader system (pack ≥ 2, ~90/10 same/cross-type via AFFINITY),
   low-level ceiling (see §5). *(v3.1-era wording; SetLevel later proved number-only AND a
   crash source — REMOVED v3.3, difficulty moved to pick-time gates. Current state: HANDOVER
   v3.x entries.)* **Next iteration after playtest:** if SetLevel doesn't stick,
   switch to custom stats file in
   the pak (`Public/ChaosReinforcements/Stats/Generated/Data/`) with CHAOS buff statuses for
   HP/stat scaling on spawned mobs (fold into single artifact, keeps high-level play
   interesting); tune budget formula with observed party size; grow RACE_TO_TYPE from the
   discovery log.
4. Optional big win: lslib **`StoryCompiler`** to compile `MARTIN_*.txt` offline — now much
   closer: gplex/gppg work on this box (Springcomp dotnet tools + QUT.Gppg swap, see
   lua-modding.md §4), and `story_header.div`/`story_definitions.div` exist under
   `Data/Mods/*/Story/RawFiles/`. Whole-file errors already refuse new games (detectable), but
   the *silent per-rule drops* (imp-rule class) are exactly what an offline compile catches.
5. ~~Cleanup, pending user OK~~ **DONE 2026-11-02 (owner OK):** deleted dead
   `Data/Mods/HealthBoostLocal/` and `Data/Mods/HPChaos_0e6a9a3c-5b69-3e25-9d0f-75f692fc7aaa/`
   (no modsettings.lsx references; never worked).
6. Confound rule **lifted** (E8 read done): enabling the SE mod no longer risks a story signal;
   SE Lua can now be used to *verify* the text channel (listeners on `CombatStarted`, DB fact
   reads) and to observe spawns while building the feature.

## 9. Git state

Commits this session: `2ddd041` (E7 probe + E1 forensics), `aeadb2d` (SE/Lua docs + skeleton +
deploy script), `d09c810` (this handover + AGENTS.md pointer), plus a follow-up commit adding
`spawn-chains.md` sec.3.1.2 (E7 result, E8 plan). Same-day follow-ups: `6ed3c6a` (E8b armed,
e8b_inject.py), `5bb1ea0` (new-game-refusal diagnosis: query-in-AND fix, check_goal.py
query/call placement, GustavX host, live-modsettings correction), and the E8b-positive + E8-armed
docs commit. Then `c79e339` (toolchain), `2032746`/`da9e266` (SE probe v2/v3), `8e3eed9`
(chaos v1), `46e1ed9` (chaos v2). Latest: **v3 commit** (Chaos.lua v3 DB-driven rewrite,
CreatureDB.lua 674 creatures, build_creature_db.py + pool_types.py, BootstrapServer require
order, this handover update). `bg3-vanilla-data/` is gitignored and **absent/empty** on this
checkout — the 16G unpack the tools use lives at `/home/martin/Documents/mods/bg3-new/
bg3-vanilla-data` (external, also outside git).

## 10. Session hygiene note

Late in the session, some tool calls rendered into the chat as literal text instead of executing.
Pattern observed: the calls that failed had awkward arguments (backslash escapes, `|` in regex
patterns, embedded double quotes, `>` in grep patterns); re-issued versions with plain, simple
arguments worked immediately, including `grep`, `edit`, `write`, `shell`. So: keep tool arguments
plain — short single-quoted paths, no regex alternation, no escaped quotes, no `echo` separators.
`docs/spawn-chains.md` sec.3.1.2 now carries the E7 result and the E8 plan (this file and that
section overlap on purpose: this one is the session brief, that one is the project memory).
