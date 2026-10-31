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
  `…/compatdata/1086940/pfx/drive_c/users/steamuser/Script Extender Logs/Extender Runtime.log`.
  Probe v2 also file-logs via `Ext.IO.SaveFile` → profile `Script Extender/MARTIN_probe.log`
  (channel already proven working). **Not yet verified producing output** (needs one game start
  with the new settings).
- Probe v1 result (2026-10-31, partial ✅): mod enabled + loaded server-side — template dump
  written at SessionLoaded (keys = bare GUIDs; wolf GUID present, prologue imp-instance GUID
  absent — confirms the story-side instance-vs-root finding). Spawn itself invisible (logging dead).
- **Probe v3 result (2026-10-31): POSITIVE — wolf spawns HOSTILE at CombatStarted via Lua.**
  Full pipeline proven: pak → SE v33 → mod → `Osi.CreateAtObject` (name+`_`+GUID root template,
  anchor=GetHostCharacter) → `SetFaction(EVIL)` → `SetHostileAndEnterCombat(EVIL, HERO, ...)`
  with the E8b pair verbatim → joins the fight as a red enemy.
- **Chaos engine v3 = data-driven reinforcement engine (2026-10-31, written+packed, awaiting
  playtest):** owner
  spec: stacking trigger (base 20%, +5..25% per miss; TEST_MODE=true forces 100%), spawn budget
  = host GetLevel x rand(2,4) x (1 + 0.15 x max(0, party-4)), max 8/combat, anchors = existing
  ENEMIES when known (spawns next to the mobs you fight), hostility = proven EVIL/HERO pair.
  **New in v3 (vs v2):** (a) `Server/CreatureDB.lua` — generated offline by
  `tools/build_creature_db.py` (`tools/pool_types.py` is its template→stats→type resolver):
  674 generic spawnable creatures in 14 D&D type groups (Humanoid 417, Undead 61, Beast 50,
  Aberration 39, Elemental 20, Fiend 18, Monstrosity 18 …), each `{id = Name_GUID, hp, cost =
  hp/10}`; sources = `/tmp/opencode/rt/*.lsx` (converted merged root-template tables), the
  16G vanilla unpack at `/home/martin/Documents/mods/bg3-new/bg3-vanilla-data` (stats `using`
  chain → `_Type` + Vitality), and the live 32017-entry dump as instantiation ground truth.
  ⚠️ Regeneration needs those paths; `/tmp` may be wiped. `BootstrapServer.lua` now
  `Ext.Require`s `Server/CreatureDB.lua` BEFORE `Server/Chaos.lua`. CINE_/WIP/TOBEDELETED
  placeholder templates are filtered (they ARE in the live dump and would spawn garbage).
  (b) Type affinity: `RACE_TO_TYPE` (Osiris `GetRace` string → D&D type) + dominant enemy type
  decides the pool; unknown races log `type ?` so the map grows from `MARTIN_chaos.log`.
  (c) Level scaling: `Osi.SetLevel(created, hostLevel + rand(-2,2))` with GetLevel verify
  (owner runs levelmax 20/50 — fodder must not stay level 1). (d) 20% leader wildcard
  (Monstrosity/Humanoid, +0-2 extra levels, ≤ half budget). (e) Sample dump of
  `Ext.StaticData.GetAll("Race")` resource fields (candidate runtime race→type upgrade).
  **Discovery logging**: every CombatStarted logs each enemy's `GetLevel`/`GetRace`/type
  (feeds RACE_TO_TYPE growth; owner wants: same-category mobs,
  occasional leader types, party-size factored in; ~6-8 party chars via NPC-keeper mod).
  Osiris discovery toolkit confirmed in `story_header.div`: queries `GetLevel`, `GetRace(c,0)`,
  `GetDisplayName`, `GetPosition`, `IsInCombat`, `CombatGetInvolvedPartyMembersCount`; facts
  `DB_Is_InCombat` (1272 uses in vanilla goals), `DB_Players`, `DB_PartyMembers`. Header has NO
  Turn/participants facts; third-party "extra enemies honour" mod (unpacked to
  /tmp/opencode/paks/eeh) does it with pre-placed level .lsf characters + anubis .anc — not
  reusable by us, no Lua anywhere in it.
- ⚠️ RNG gotchas (DLL strings + API forensics 2026-10-31): `Ext.RandomInteger` does NOT exist
  in v33 (older docs wrong); use `math.random(lo,hi)` — and NEVER `math.randomseed` (SE ships a
  stub that throws). Lua syntax can be compile-checked offline: `pip` venv + `lupa`,
  `rt.eval('load')(src)` (no interpreter on this box otherwise).
- Probe v2 result (2026-10-31): **wolf spawns via Lua** (CreateAtObject + host anchor work) but
  stays neutral/yellow. Log (`MARTIN_probe.log`) showed SetFaction/SetHostileAndEnterCombat
  "ok"-without-effect: v2 used `Evil_fb046e51…` + the host's real **per-player faction**
  (`GetFaction(host)` = `Hero Player1_<guid>`). Lesson: replicate the E8b-proven pair verbatim
  (`Evil_4be9261a-e481-8d9d-3528-f36956a19b17` vs `Hero_a1542c81-6895-929e-4522-10ce218bb360`)
  → probe v3. Other facts: `Osi.DB_*:Get` at SessionLoaded throws "restricted context"; runtime
  logs live in profile `Script Extender Logs/`; template dump = GUID<TAB>Name (wolf = name
  "Wolf"), and GetAllRootTemplates includes props/items — filter creature templates for pools.
- Probe mod **packed + installed** (pak toolchain proven, `tools/pack_mod.sh --install`):
  `…/Baldur's Gate 3/Mods/MARTIN_MoreMobs.pak`. Source `mods/more-mobs/` =
  `meta.lsx` (UUID `d5afd252-101b-449b-ae74-c792a73d64ff`, `Folder=MARTIN_MoreMobs`,
  Type int32=1 — fixed from stale wiki format), `ScriptExtender/Config.json`
  (`RequiredVersion: 33`, `ModTable: MARTIN_MoreMobs`, `FeatureFlags:["Lua"]`),
  `BootstrapServer.lua`, `Server/Probe.lua` (logs on `SessionLoaded`, dumps every root template
  to `MARTIN_root_templates.txt` via `Ext.IO.SaveFile`, spawns imp + wolf on `CombatStarted`,
  registers `!martin_spawn`).
- **Waiting on owner (reinforcement v3 playtest):** restart → mod stays enabled → play a few
  real combats (TEST_MODE = 100% spawn right now). Then read profile
  `Script Extender/MARTIN_chaos.log`: it shows party size, every enemy's
  level/race/type (feeds RACE_TO_TYPE growth) and the spawn sequence. Watch for:
  enemies identified count (if 0 at CombatStarted, `DB_Is_InCombat` is populated later → need
  a tick-delayed retry), whether `SetLevel` stuck (spawn lines show `lvl <verified>`; if it
  shows the target instead of the read-back level or `SetLevel threw:`, `SetLevel` on a
  freshly created template instance needs a tick delay), type affinity sanity (fiend fight →
  Fiend pool), mob placement next to existing enemies, and the Race static-resource dump line
  (first combat only) — if its fields include a usable race→type walk, replace the seeded
  RACE_TO_TYPE map with a runtime resolver next iteration.
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
   `…/Baldur's Gate 3/Mods/MARTIN_MoreMobs.pak`. SE v33 updater installed to `bin/DWrite.dll`.
   **Owner run pending:** start game → enable "MARTIN More Mobs" → load → read
   `bin/bg3-print.log` (`[MARTIN] ... bootstrap loaded`, SessionLoaded, template dump) + profile
   `Script Extender/MARTIN_root_templates.txt` (via `Ext.IO.SaveFile`). That dump settles the
   imp-instance question and enumerates the **global root template pool** the chaos engine draws on.
3. ~~**Chaos engine in Lua**~~ **DONE — v3 packed+installed (2026-10-31), awaiting playtest:**
   stacking trigger, typed 674-creature DB, type affinity, budget with party knob, SetLevel
   scaling, leader wildcard (see §5). **Next iteration after playtest:** custom stats file in
   the pak (`Public/MARTIN_MoreMobs/Stats/Generated/Data/`) with CHAOS buff statuses for
   HP/stat scaling on spawned mobs (fold into single artifact, keeps high-level play
   interesting); tune budget formula with observed party size; grow RACE_TO_TYPE from the
   discovery log (or runtime StaticData Race walk if the sample dump shows usable fields).
4. Optional big win: lslib **`StoryCompiler`** to compile `MARTIN_*.txt` offline — now much
   closer: gplex/gppg work on this box (Springcomp dotnet tools + QUT.Gppg swap, see
   lua-modding.md §4), and `story_header.div`/`story_definitions.div` exist under
   `Data/Mods/*/Story/RawFiles/`. Whole-file errors already refuse new games (detectable), but
   the *silent per-rule drops* (imp-rule class) are exactly what an offline compile catches.
5. Cleanup, pending user OK: delete dead `Data/Mods/HealthBoostLocal/` and
   `Data/Mods/HPChaos_0e6a9a3c-5b69-3e25-9d0f-75f692fc7aaa/`.
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
