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
   **Owner run pending:** start game → enable "Chaos Reinforcements" → load → read
   `bin/bg3-print.log` (`[MARTIN] ... bootstrap loaded`, SessionLoaded, template dump) + profile
   `Script Extender/Chaos_root_templates.txt` (via `Ext.IO.SaveFile`). That dump settles the
   imp-instance question and enumerates the **global root template pool** the chaos engine draws on.
3. ~~**Chaos engine in Lua**~~ **DONE — v3.1 packed+installed (2026-10-31), awaiting playtest:**
   stacking trigger, typed 622-creature DB, type affinity, budget with party knob, SetLevel
   scaling + delayed verify, leader system (pack ≥ 2, ~90/10 same/cross-type via AFFINITY),
   low-level ceiling (see §5). **Next iteration after playtest:** if SetLevel doesn't stick,
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
