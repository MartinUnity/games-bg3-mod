# Spawn Chains — getting more mobs into an encounter

Research notes (2026-10-30): can we add **enemies**, not just HP, to the fights the
player actually has — using only the text we already deploy? Companion to
`drop-chains.md` (loot side, and the "text vs binary" split this doc refines) and
`overview.md` §6 (how our overrides load).

Legend: ✅ = read out of files on this install, quotes/line refs given. ⚠️ = plausible
from the grammar/precedent but needs an in-game test before we rely on it.

## 1. Verdict

**Yes in principle, unproven on this install.** An Osiris goal file can create brand-new
characters at runtime, gate them on Honour mode, place them at a legal position, and drop
them into a combat that is already running. ✅ Vanilla itself does exactly this (the Hag's
"doubles", extra ones **only in Honour mode**) — see §9 for the call sites. ⚠️ What is *not*
yet verified here is that the engine compiles goal text on this install at all (§3), nor
which mount it reads (§3.1). Experiment E1 (§12) is built to answer both in one minute of
gameplay.

What stays binary: where an encounter *is* — which mobs the level places, its trigger
regions, its spawn markers, its AI grid. We cannot add a brand-new encounter to a level,
nor move its markers. But we can add bodies to encounters that already exist, anchored on
the level's own spawn markers (addressable by name from goals — but only ones some goal
already names, §6), on the players, or on props/casualties.

## 2. Three layers — and a correction to `drop-chains.md` §5

| Layer | Editable? | What lives there |
|---|---|---|
| **Level / scene data** (`.lvl`, `.lsf`, `.lsx`; packed in `Data/*.pak` per Larian's format — ⚠️ not verified on this install, §3) | No | the encounter's placed mobs, trigger regions, spawn-point markers, AI grid, loot wiring |
| **Story goals** (`Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/Goals/*.txt`) | Loose text is present and editable — ⚠️ never edited by us, runtime loading unproven (§3) | Osiris rules: create/transform/teleport characters, factions, combat grouping, flags, timers |
| **Stat tables** (this repo, `Data/Public/**/Stats/Generated/`) | Yes | template stats, statuses, passives, innate/summon spells, difficulty hooks |

`drop-chains.md`:121 says new-encounter wiring "is not possible in text". Correct for
**loot wiring** (a spawned body still has no text hook that says "its corpse rolls table
X"), but **the mob itself can be created in text**. ⚠️ Whether a script-spawned character
drops anything (equipment only? nothing?) is untested — check before depending on spawns
for loot.

## 3. What we actually know about the goal channel (read this before trusting §1)

- ✅ `Data/Mods/*/Story/RawFiles/Goals/` holds **944 loose goal `.txt` files** on this install
  (Gustav 251, GustavDev 552, Shared 120, SharedDev 15, GustavX 6) plus `story_header.div`
  and an **empty (0-byte) `story_definitions.div`** per module. `GustavDev/.../GLO_ActivitiesPS5.txt`
  among them says this tree shipped with a console/PS5-flavoured install.
- ✅ Those files are all vanilla: every one has the install mtime (2025-09-06), and
  `find Data/Mods -name '*.txt' -newermt 2025-11-20` returns nothing — **we have never edited a
  story file here.** The "level cap / 3 short rests / companion changes" in `overview.md` §6 are
  implemented in **stats**, not in these goal files (grepping the story tree for
  `SHORT_REST_LIMIT`/`MaxShortRest`/`LevelCap` finds nothing). ⚠️ So there is currently **no
  local evidence that loose goal text is read at runtime** — §1's verdict rests on the grammar
  and on vanilla precedent, and the experiment in §12 is what settles it.
- ✅ The header file is machine-generated text listing the engine's installed calls and
  queries (`story_header.div`, "Story header automatically generated. Do not modify!") —
  558 `call`, 425 `query`, 320 `event` lines in the GustavDev copy (Shared: 541/407/311). It
  declares **no** `DB_` predicates, so a new goal file may introduce its own `DB_`/`FLAG`/`TAG`
  names without registering them anywhere. ⚠️ (Unique names are still on us; collisions are silent.)
- ⚠️ **Pak contents cannot be checked by grepping on this box.** There is no `limpak`/`bg3pak`
  installed, and `grep -a` over `Data/*.pak` is useless: it finds `Stats/Generated` and
  `TreasureTable` only 3 times each (and those files are certainly in the pak) because the
  payloads and the file-name index are compressed. Any earlier claim of the form "`limpak -l`
  shows no story/level paths in the paks" was a **missing-binary artifact, not a result** —
  including the "no `.lvl` in paks" claim in §2's table, which is Larian's documented format,
  not something we verified here. Install a pak reader before restating either direction.

### 3.1 Which mount a *new* goal file is compiled from — unresolved

| Location | Writable? | What it holds |
|---|---|---|
| `Data/Public/<Module>/Story/RawFiles/Goals/` | **yes** — this repo, a `rw` bind mount | our master copy; no vanilla goal ever lived here |
| `Data/Mods/<Module>/Story/RawFiles/Goals/` | **no** — `/home/martin/.local` is mounted `ro` (`findmnt`: `errors=remount-ro`); only `Data/Public` is a separate `rw` mount | where the vanilla loose goals actually sit |

`tools/deploy_story.sh --copy` mirrors our `MARTIN_*.txt` goals into `Data/Mods/…`; it
refuses to run if the target is not writable (needs `sudo mount -o remount,rw /home/martin/.local`
first). The in-game test in §12 settles the question: if `martin_spawn` works with only the
repo copy present, `Data/Public` is compiled and no fallback is needed.

### 3.1.1 E1 in-game result: **nothing spawned** (2026-10-30, fresh Honour game, imp room)

The first live test (repo copy in `Data/Public/SharedDev/Story/…`, rooms 2 and 3 of the
prologue) produced no extra bodies and no print. Evidence gathered afterwards, all ✅ from disk:

- **The prologue level name was right.** Every `TUT_*.txt` goal that gates on a level uses
  `DB_CurrentLevel("TUT_Avernus_C")` (4 hits) — no other level name appears in them. So the
  `LevelLoaded`/level-gate part of E1 was aimed correctly.
- **`Data/Public` has no precedent for story text.** The only `Story/` directory anywhere under
  `Data/Public` is the one we created; vanilla ships story text only in
  `Data/Mods/{Shared,SharedDev,Gustav,GustavDev,GustavX}/Story/RawFiles/`. Stats have always
  shipped in both (`Data/Public/*/Stats/...` *and* paks), which is why the stats channel works
  from Public — that precedent does **not** transfer to `Story/`.
- **There is no pre-compiled story cache to blame.** `Data/Generated/` holds only
  `Public/Engine/Assets`; nothing that looks like a compiled Osiris program.
- **`Data/Mods` really is unwritable right now** (`touch` → `Read-only file system`).
- **Template choice was a second, independent suspect.** `Wolf_41da0eff-…` comes from
  `Gustav/…/Goals/Test.txt`, i.e. a *different level*; whether a template that is not in the
  current level can be instantiated is untested and may be the reason a compiled rule still
  spawns nothing.
- Install forensics for future runs (✅): this is the **Windows** build under Proton, prefix
  `steamapps/compatdata/1086940`; logs are `bin/gold.<timestamp>.log` + `bin/network.…` (no
  story/Osiris compile output), profile at `…/compatdata/1086940/pfx/drive_c/users/steamuser/
  AppData/Local/Larian Studios/Baldur's Gate 3/` (`modsettings.lsx` load order: **GustavDev** +
  5eSpells + Ututu's + EncountersOverhaul + Teleport To You, file mtime 2024-08-02 → stale).
  Saves are `HonourMode.lsv` (LSOF container, first zstd frame decodes but carries no `DB_`
  fact strings) — **not** a usable channel for reading story facts.

**E7** was `SharedDev/Story/RawFiles/Goals/MARTIN_SpawnProbe.txt` (the E1 file is parked at
`docs/goals/MARTIN_Reinforcements.txt` so exactly one goal file is in the compile path): two
ungated `CombatStarted` rules, each its own once-guard, one spawning the level-native imp
`S_FirstFight_Imp_Melee_01_07f1512b-…` (cited from `TUT_LowerDeck.txt`, so it exists in
`TUT_Avernus_C`) and one the cross-level `Wolf_41da0eff-…`. Any extra body proves the mount;
nothing at all, in *any* combat, points at the mount rather than the rule.

### 3.1.2 E7 in-game result: **still nothing** (2026-10-31, fresh Honour game, prologue rooms 2-3)

User started a new Honour game and fought the imp battle in room 3: no extra bodies, nothing out
of the ordinary. So both the honour-gated E1 and the ungated any-level E7 are silent, and the
**mount hypothesis is now the leading explanation**: `Data/Public/<Module>/Story/RawFiles/` is
very likely not part of the story compile path (vanilla ships goal text only under
`Data/Mods/<Module>/Story/RawFiles/`). Untested sub-cases left: wrong mount (`Data/Public` never
scanned for `Story/`), wrong module (goal text for the TUT levels lives in Gustav/GustavDev, not
SharedDev), or loose goal text not compiled at all on this install.

**E8 (next, cheap, no tooling):** `Data/Mods` is writable now, so run
`tools/deploy_story.sh --copy` and hand-copy the probe into
`Data/Mods/GustavDev/Story/RawFiles/Goals/` as well (base module per `modsettings.lsx` is
GustavDev, and that splits the module question from the mount question). Restart the game — story
text is compiled at start. Any spawn means the `Data/Mods` story mount is live and goals ship
there (and inside the pak); still nothing means loose goal text is not compiled here at all and
the pak (and/or lslib `StoryCompiler`) is the only route.

Balance/stats overrides were not separately confirmed in that run ("nothing out of the normal" is
ambiguous about the HP/damage edits). If stats turn out to be dead too, suspect the stale
`modsettings.lsx` base-module choice (`GustavDev`, mtime 2024-08-02) before blaming the overlay.

Where not to iterate blind: the Script Extender Lua channel (`docs/lua-modding.md`, skeleton
`mods/more-mobs/`) runs after the story compiler, logs every step, and can dump every creature
template name in the loaded game. Achievements are not a concern for this user, so the Lua probe
is now the main instrument rather than just the lab; the pak is the packaging route
(`docs/HANDOVER.md` sec.4).

### 3.2 Trust only names you have grepped

An earlier research pass over this material invented plausible API names. Confirmed **not to
exist** anywhere on this install: `CombatGetCombatGroupIDFor`, `PlayerEnteredTrigger`,
`GetLevelName`, `GetEntityList`, `CharacterGetGuid`, `RemoveCharacter`. The real ones are in
`story_header.div` (§5, §8). `python3 tools/check_goal.py` now enforces this: every
call/query/event in a goal file we write must appear in a `story_header.div`, and every
`DB_` predicate must be written by at least one vanilla goal (or by our own file).

## 4. Goal file skeleton ✅

```
Version 1
SubGoalCombiner SGC_AND
INITSECTION
DB_My_Predicate(...);            // seed state; runs once per story load
KBSECTION
IF
<Event>(...)                    // engine event
AND
QRY_My_Check(...)               // local subgoal (PROC = side effects, QRY = lookup)
THEN
CreateAt(<CHARACTERROOT uuid>, _X, _Y, _Z, 1, 1, "", _New);   // actions
EXITSECTION

ENDEXITSECTION
ParentTargetEdge "GLO_Hag"      // optional: attach to another goal (see GLO_HagDoubles_PostEA.txt:85)
```

The goal's *name* is its file name; there is no registry to update. Real example end to
end: `GustavDev/.../Goals/Act1_FOR_DangerousBook_PostEA.txt:32-72`.

Mechanical rules we verified on this install ✅ (and which `tools/check_goal.py` enforces):

- Every goal file on disk is **CRLF**; write CRLF.
- `EXITSECTION` + `ENDEXITSECTION` are a required **pair**, even when the exit section is
  empty (our file keeps only a comment there).
- Conditions never end with `;`; every action in a `THEN` block must.
- A goal file may declare its own `DB_`/`QRY_`/`PROC_` names: a bare `PROC` or `QRY` line,
  then the declaration (`PROC_MakeNPCHostile((CHARACTER)_Player,(CHARACTER)_Npc)`), then its
  own `AND` conditions and `THEN` block — see `Shared/.../Goals/_Attitude.txt:6-13`.
- Vanilla keeps a **shared helper library** in `Shared/`, and calls it from the story modules:
  `Shared/.../Goals/__PROC.txt` declares 457 `PROC_`/`QRY_` rules (e.g.
  `PROC_SetRelationMutual` at `:987`), `_Greevers_Little_Helpers.txt` declares
  `QRY_OnlyOnce((STRING)_OnlyOnceUUID)` (`:892`) and `QRY_IsInRange` (`:2270`),
  `_CRIME_CrimeTriggers.txt:792-811` declares `PROC_CharacterDisableAllCrimes`.
  Corpus-wide mention counts: `QRY_OnlyOnce` 2461, `PROC_SetRelationMutual` 305,
  `PROC_CharacterDisableAllCrimes` 111, `PROC_MakeNPCHostile` 36, `QRY_IsInRange` 59 — all
  defined in `Shared/` and used from `Gustav`/`GustavDev` goals, so rule names resolve across
  the whole story compile rather than per file. ⚠️ That is inference from vanilla depending
  on it; we cannot see the compiler, and the loose corpus is partial, so **our own files
  declare everything they use** (`check_goal.py` rejects a `QRY_`/`PROC_` that no file in
  this checkout declares). Engine calls/queries/events are the safe set: all of them are in
  `story_header.div`.
- Factoring work into a `PROC` and calling it from several `THEN` blocks is normal vanilla
  style (`PROC_HAG_SpawnDoubles(...)` is *called* 8× in `GLO_HagDoubles.txt`), so it is safe
  for our own reuse.

## 5. Making bodies: the primitives ✅

Signatures verbatim from `GustavDev/Story/RawFiles/story_header.div` (line numbers
there; other modules' headers differ slightly):

| Line | Primitive |
|---|---|
| 588 | `CreateAt(_TemplateId, _X, _Y, _Z, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` |
| 589 | `CreateAtObject(_TemplateId, _Anchor, _Temporary, _PlaySpawn, _SpawnFinishEvent, _MatchOrientation, out _CreatedObject)` — no coordinates needed, anchors on any object/character |
| 590 | `CreateOutOfSightAtDirection(_TemplateId, _X,_Y,_Z, _DirectionAngle, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` — ambush arrivals |
| 591 | `CreateOutOfSightAtDirectionFromObject(_TemplateId, _AnchorObject, _DirectionFrom, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` — the crime-guard spawn idiom (`Shared/.../_CRIME_CrimeGuards.txt:1647-1661`) |
| 98-100 | `AppearAt(_Character,_Target,…)`, `AppearAtPosition(_Character,_X,_Y,_Z,…)`, `AppearOutOfSightTo(_Character,_Target,_DirectionFrom,…)` — teleport an *existing* NPC in |
| 898 | `Transform(_Object, _TargetTemplate, _ShapeshiftRules)` — swap one body for another, e.g. escort → monster; vanilla uses it in the prologue lab (`Gustav/.../TUT_Laboratory.txt:80`) |

Notes on the shared argument shape: `_Temporary` `1` = summon-like (vanilla Hag doubles
pass `1`); `_PlaySpawn` `1` = play the spawn VFX; `_SpawnFinishEvent` is a script event
string (`""` is fine); `_MatchOrientation` `1` = face the anchor. Templates are
`CHARACTERROOT` UUID names, e.g. `Hag_Green_Act1Hag_Double_8c85932d-12dd-4046-a694-6534071470a2`,
`Shadow_A_749b1e7d-63a1-4a3d-b0ca-f237b9ada5c4`, `Kobolds_Melee_Drunk_45e31b7d-32ec-4f3d-8067-79061aeec77b`,
`Wolf_41da0eff-b533-43cc-a014-218f7d23fa11` (Larian's own spawn test —
`Gustav/.../Goals/Test.txt:345-356`: `GetPosition(_Player,_X,_Y,_Z)` (:349) +
`RealSum(_X,2.0,_XOffset)` (:351) + `CreateAt((CHARACTERROOT)Wolf_…, _XOffset,_Y,_Z, 1, 0, "", _Wolf)` (:353)
then `SetFaction(_Wolf,(FACTION)Evil_…)` (:355) + `PROC_MakeNPCHostile(_Wolf,_Player)` (:356);
note `_Temporary=1`, `_PlaySpawn=0`, and that the hostility helper there is a Shared-module
PROC, not an engine call). It is also the template our E1 file seeds.

Working vanilla call sites ✅:
- Barrel → kobold: `GustavDev/.../Act1b_CRE_Brewery.txt:120` — `CreateAtObject((CHARACTERROOT)Kobolds_Melee_Drunk_…, _Barrel, 0, 1, "", 1, _Kobold)` fired by `DB_PermaDefeated(_Barrel)`.
- N copies at a position: `GustavDev/.../Act1_FOR_DangerousBook_PostEA.txt:49-57` — `PROC_…_SummonShades(3, _X,_Y,_Z)` + `QRY_DoNTimes(_Num)` loop + `CreateAt(Shadow_A_…, _PosX,_PosY,_PosZ, 0, 1, "", _Creature)` + `SetFaction(...)`.
- Item → creature: `SharedDev/.../GLO_CombatNPCs_PostEA.txt:598-606`.

Which primitive to pick (our heuristic, vanilla-consistent): anchor on something that already
exists (`CreateAtObject`, 589) whenever there is a usable anchor — it needs no coordinates, and
every extra query in a rule is another chance for the rule to fail silently (§6). Fall back to
`CreateAt` + `FindValidPosition` (§9) when the anchor tile is contested or the body appears
inside geometry; use `CreateOutOfSightAtDirection(FromObject)` (590/591) when the arrival should
not be witnessed.

## 6. Legal positions, factions, and joining a running fight ✅

- **Don't spawn inside geometry.** `FindValidPosition(_X,_Y,_Z, _Radius, _Object,
  _AvoidDangerousSurfaces, out _NX,_NY,_NZ)` (`story_header.div:654`). Vanilla wraps it in a
  `QRY` plus a plain-position fallback: `QRY_HAG_SpawnDoubles_FindValidPosition` at
  `Gustav/.../GLO_HagDoubles.txt:251-257` (solver) and `:261-267` (fallback, guarded by
  `NOT DB_HAG_SpawnDoubles_FindValidPosition(_Char,_,_,_)`), consumed at `:201-205` before
  `CreateAt(…,1,1,"",_HagDouble)`. Inline in a rule chain also works (vanilla does it inside
  the QRY at `:255`).
- **Anchor sources**: level spawn markers are addressable *by name* from goals — vanilla seeds
  trigger GUIDs into a predicate: `DB_LOW_HagDoublesSpawnPoints((TRIGGER)S_LOW_BlushingMermaid_DoublesSpawnPoint_001_…)`
  (`GustavDev/.../Act3b_LOW_BlushingMermaid.txt:149-152`). Those `S_…` names come from the level
  and are copied into goals by Larian, so **a marker you want is only usable if some goal already
  names it**. Position helpers: `GetPosition` (624), `GetDistanceTo` (626), `GetClosestAlivePlayer(_Target,
  out _Player, out _Dist)` (895), `IsInTrigger` (652), `PositionIsInTrigger` (653),
  `CharacterTemplatesInTrigger(_CHARACTERROOT, _TRIGGER, out _Count)` (1309).
- **Join the combat that is already going.** `SetCombatGroupID(_New,"<GroupID>")` (946) —
  vanilla sets the encounter's own group string: `SetCombatGroupID(_HagDouble,"HAG_Hag_State_HagInLair")`
  (`GLO_HagDoubles.txt:218`) and `SetCombatGroupID(_HagDouble,"LOW_HagBossFight")`
  (`GLO_HagDoubles_PostEA.txt:18`); read one with `GetCombatGroupID(_Target,out _GroupID)` (945),
  or set-and-fight with `SetCombatGroupAndEnterCombat(_Target,_GroupID,_Enemy)` (1003).
  `EnterCombat(_Source,_Target)` (993) is used directly, e.g.
  `EnterCombat(S_HAG_Hag_c457d064-…,_Player)`. The late-join initiative penalty is skipped by
  tagging: `SetTag(_New,(TAG)IGNORE_COMBAT_LATE_JOIN_PENALTY_6d60bed7-10cc-4b52-8fb7-baa75181cd49)`
  (`GLO_HagDoubles_PostEA.txt:15`). ⚠️ There is **no** `CombatGetCombatGroupIDFor` — that name
  appears in some online write-ups and does not exist in this header.
- **Make them mean.** `SetHostileAndEnterCombat((FACTION)_A,(FACTION)_B,_Attacker,_Target)` (1002)
  is the vanilla one-liner, always written with a real faction pair, e.g.
  `SetHostileAndEnterCombat((FACTION)Act3_LOW_ArajBloodMerchant_4f198d21-…, (FACTION)Hero_a1542c81-6895-929e-4522-10ce218bb360, S_MOO_InfernalVendor_…, _Player)`.
  `Hero_a1542c81-6895-929e-4522-10ce218bb360` is the player faction; `Evil_4be9261a-e481-8d9d-3528-f36956a19b17`
  is the catch-all hostile faction (`Gustav/.../Goals/Test.txt:355`). Set one directly with
  `SetFaction(_Target,(FACTION)…)` (1014), read one with `GetFaction` (1015), or wire relations
  with the vanilla helper `PROC_SetRelationMutual((FACTION)_A,(FACTION)_B,_Value)` (declared
  once at `Shared/Story/RawFiles/Goals/__PROC.txt:987`, 305 call sites corpus-wide; the Shared
  helper library is described in §4).
- **Clean up:** `RemoveSummons(_Character,_Die)` (240); `_Temporary=1` bodies go away with the
  combat; `SetImmortal((CHARACTER)_C,1)` (193) and the `DB_PermaDefeated` / `DB_Defeated`
  predicates control death handling; `IsInCombat` (776) / `SetCanJoinCombat` (779) gate participation.
- **Rule hygiene — why E1 looks so plain.** A rule that never fires is silent: no compile
  error, no log. Every condition in the `IF` chain (and every query with an `out` argument) is
  another way the whole rule can quietly fail, so keep the condition set as small as the
  behaviour allows, do the work in one `PROC` that all trigger rules call, and let
  `tools/check_goal.py` cover the grammar/names (§3.2, §11). If a test run shows nothing,
  *subtract* conditions before adding features.

## 7. Honour-mode gating ✅ (this is the piece that makes it "Honour only")

`SharedDev/Story/RawFiles/Goals/GLO_HonorMode.txt` is a vanilla global goal that keeps a
single predicate in step with the ruleset modifier:

- `:8,19,26` dev-console `TextEvent`s `honormode` / `honormodeon` / `honormodeoff`
- `:10,39,53` `CheckRulesetModifierBool(HONOUR_STATS_ef0506df-da9f-40e2-903a-1349523c1ae4,…)` (header `:1042`)
- `:36-62` on `LevelLoaded(_LevelName)` and on `RulesetModifierChangedBool(…)` (header `:1292`)
  it runs `PROC_HonorMode_Enable/_Disable`
- `:65-77` those PROCs flip the single predicate `DB_HonorMode_Enabled(1)`

So **any** goal we write can simply say `DB_HonorMode_Enabled(1)`. Verified vanilla consumers:
`GustavDev/.../GLO_HagDoubles_PostEA.txt:22,58`, `GustavDev/.../GLO_HonorMode_Gustav.txt:14,30`,
`GustavDev/.../GLO_Tutorials.txt:1012,1037`, `GustavDev/.../Act3b_LOW_BhaalTemple_Combat.txt:261,268`,
`Gustav/.../Act1_GOB_SpiderNest.txt:1363,1370`, `SharedDev/.../GLO_CombatNPCs_PostEA.txt:878,890`.
A clean one to copy — honour-only status on a level-placed NPC:

```
// Gustav/Story/RawFiles/Goals/Act1_GOB_SpiderNest.txt:1360-1365
PROC
PROC_GOB_SpiderNest_ProcessVictimFall((CHARACTER)S_GOB_GoblinKing_11337af0-…)
AND
DB_HonorMode_Enabled(1)
THEN
ApplyStatus((CHARACTER)S_GOB_GoblinKing_11337af0-…, "GOB_DROR_UNLOCK_SPIDER_SPELL", -1.0);
```

Two other difficulty levers we already use or could pair with this:
- Stats layer: `Shared/Stats/Generated/Data/Character.txt:25` (`_Base`) →
  `DifficultyStatuses "STATUS_EASY: HEALTHREDUCTION_EASYMODE; STATUS_HARD: HEALTHBOOST_HARDCORE"`,
  live override at `GustavDev/Stats/Generated/Data/Status_BOOST.txt:11621`.
- Script layer can also set HP, and it has to fight that status for control: vanilla
  defers `SetHitpoints` to `EnteredCombat` *"so `HEALTHBOOST_HARDCORE` doesn't override it"*
  (`GLO_HagDoubles.txt:224-230`) — same interaction applies to anything we spawn.
- NPC level-ups by region, no new bodies needed: `DB_CMB_LevelUpNpcInRegion((CHARACTER)S_…, "CTY_Main_A", 11, "LOW_WULBREN_LEVEL_11")` (`GLO_CombatNPCs_PostEA.txt:44-58`).

## 8. Hooks available in goals ✅ (header line numbers; vanilla use counts noted inline)

| Hook (header line) | Use for |
|---|---|
| `CombatStarted(_CombatGuid)` (1197), `EnteredCombat(_Object,_CombatGuid)` (1194), `CombatEnded(_CombatGuid)` (1199) | reinforcement waves, one-per-combat rules |
| `CombatGetInvolvedPlayersCount` (765), `CombatGetInvolvedPlayer(_Guid,_Index,out _Player)` (770), `CombatGetInvolvedPartyMembersCount` (769) / `CombatGetInvolvedPartyMember` (771), `CombatGetActiveEntity` (773), `IsInCombat` (776) | size the response off the fight; enumerate who is in it |
| `LevelLoaded(_NewLevel)` (1141), `LevelGameplayStarted(_LevelName,_)` (1134), `EnteredLevel` (1144) / `LeftLevel` (1145), `DB_CurrentLevel(_L)` | scope a rule to one level. `DB_CurrentLevel` is maintained for us: `IF LevelLoaded((STRING)_NewRegion) THEN DB_CurrentLevel(_NewRegion);` at `Shared/.../Goals/__AAA_FirstGoal.txt:2954-2957` |
| `EnteredTrigger((CHARACTER)_Character,(TRIGGER)_Trigger)` (347), `LeftTrigger` (348), `IsInTrigger` (652) | the moment the player walks into an encounter. The event is `EnteredTrigger` — **not** `PlayerEnteredTrigger` |
| `StatusApplied(_Object,_Status,_Causee,_StoryActionID)` (1169), `StatusRemoved` (1170), `UsingSpell(_Caster,_Spell,…)` (1267), `Saw(_A,_B,_WasSneaking)` (341), `Died((CHARACTER)_C)` (312), `ShortRested(_C)` (1247) | reactive spawns (barrel→kobold, hag counterswap) |
| `EntityEvent(_Object,_Event)` (1158) / `DualEntityEvent` (1159) + `SetEntityEvent` (600), `SetEntityEventReal` (602), `IterateActiveObjectsInSameCombatGroup(_Object,_Event,_CompletionEvent)` (609) | fan a rule out to every participant of the running combat |
| `Random(_Modulo,out _Random)` (97), `QRY_OnlyOnce("key")` (~2.6k call sites), `QRY_DoNTimes(_N)` (~50), `TimerLaunch(_Timer,_Time)` (676) / `TimerFinished(_Timer)` (1139), `PROC_LevelLoadedOnce("<level>")` | chance gates, caps, waves, once-per-level. `QRY_OnlyOnce` is declared at `Shared/.../_Greevers_Little_Helpers.txt:892`, `QRY_DoNTimes` at `:3146`, `PROC_LevelLoadedOnce` at `:4835` / `Shared/.../ZZZ_LastGoal.txt:207` — all three are Shared-module *helpers*, not engine primitives (`QRY_DoNTimes` is not in `story_header.div`), so treat them as unverified for our files (§4); the once-guard shape is `NOT DB_X(k)` in the conditions + `DB_X(k);` in the `THEN` |
| `SetLevel(_Object,_Level)` (598) + `GetLevel` (599) + `RequestAutoLevel(_Target)` (985) | level up the mobs the level already placed |
| `SetAmbushing(_Entity,1)` (1129) | make *existing* mobs hidden reinforcements — no spawn at all |

There is **no damage/hit event** in the header (no `event *Damage*` line), so "react when an
enemy is hurt" is not available in text; the closest are `StatusApplied` and `Died`.

DOS2-era `EncounterPrepare` / `SpawnGroup` / `CrowdSpawnRegion` are **gone** in BG3. ⚠️ No
text-visible "encounter size × difficulty" knob exists; honour-mode crowd sizes are baked
into the levels.

## 9. Canonical example to copy (Honour-only extra enemies, mid-combat) ✅

The hag "doubles" are vanilla creating new characters **during** a fight. Read end to end:

```
// GustavDev/.../GLO_HagHonourMode.txt:4-12    how many extra, keyed off the spell that triggers it
DB_GLO_NewDoublesByCounteredSpellLevel("Shout_HAG_Counterswap_5", 3);
DB_GLO_MaximumHagDoublesAmount(9);
// GustavDev/.../GLO_HagHonourMode.txt:104-111  fire the spawner
PROC_HAG_SpawnDoubles_GetAvailableSpawnPoints(S_HAG_Hag_c457d064-…);
PROC_HAG_SpawnDoubles(S_HAG_Hag_c457d064-…, _NewDoublesToSpawn);

// Gustav/.../GLO_HagDoubles.txt:193-230       the spawn itself
PROC_HAG_SpawnDoubles((CHARACTER)_Char,(INTEGER)_Int)
AND _Int != 0
AND DB_HAG_HagLair_DoublesSpawnPoints_Available(_Trigger)          // spawn markers seeded by name
AND QRY_HAG_SpawnDoubles_FindValidPosition(_Char,_Trigger)         // FindValidPosition + fallback, :251-267
AND DB_HAG_SpawnDoubles_FindValidPosition(_Char,_X,_Y,_Z)
AND CreateAt(Hag_Green_Act1Hag_Double_8c85932d-…, _X,_Y,_Z, 1, 1, "", _HagDouble)
AND GetHitpoints(_Char,_Hp)
THEN
DB_HAG_HagLair_Doubles(_HagDouble);
SetImmortal((CHARACTER)_HagDouble,1);
PROC_CharacterDisableAllCrimes(_HagDouble, 1);
SetCombatGroupID(_HagDouble,"HAG_Hag_State_HagInLair");            // the level's own group string
PROC_HAG_SetDoublesAttitudeToPlayers(_HagDouble);                  // faction/hostility wiring
// :224-230 — HP is set later, "so HEALTHBOOST_HARDCORE doesn't override it"
IF EnteredCombat(_HagDouble,_CombatID) AND DB_GLO_SetHagDoubleHP(_HagDouble,_Hp)
THEN SetHitpoints(_HagDouble,_Hp);

// GustavDev/.../GLO_HagDoubles_PostEA.txt:9-22  per-region post-spawn setup, Honour-gated at :22
SetTag(_HagDouble,(TAG)IGNORE_COMBAT_LATE_JOIN_PENALTY_6d60bed7-…);
ApplyStatus(_HagDouble,"LOW_HAG_MAGICRESISTANCE",-1.0);
SetCombatGroupID(_HagDouble,"LOW_HagBossFight");
```

Two things to notice: the doubles' **HP is a story-side number** (`SetHitpoints` deferred to
`EnteredCombat`) because our stats-layer `HEALTHBOOST_HARDCORE` would otherwise win — see
`AGENTS.md` difficulty hook; and hostility is done by a helper PROC, not by hand.

Plus the spawn-pool-with-cap pattern (guards): `Shared/.../_CRIME_CrimeGuards.txt:1647-1661`
— `DB_…SpawnPool(_Region,_Pool,_Home,_Chest,_Max,_InUse)` + `_InUse < _Max` +
`CreateOutOfSightAtDirectionFromObject(…)` + bump `_InUse`. Copy that shape for any
"max N extra mobs at a time" rule.

## 10. Recipes, ranked

| # | Recipe | Layer | Confidence | Notes |
|---|---|---|---|---|
| E1 | **Global Honour-only reinforcements**: `CombatStarted(_CombatGuid) AND DB_HonorMode_Enabled(1) AND NOT DB_MARTIN_CombatDone(_CombatGuid)` + level blacklist → `PROC_MARTIN_SpawnAtHost` = `GetHostCharacter` → `CreateAtObject(template,_Host,1,1,"",1,_N)` → `SetFaction(_N,(FACTION)Evil_…)` + `SetHostileAndEnterCombat((FACTION)Evil_…,(FACTION)Hero_…,_N,_Host)` | story | **implemented**, in-game result pending | live at `SharedDev/Story/RawFiles/Goals/MARTIN_Reinforcements.txt` + `LevelLoaded` probe + Nautiloid room probes (E6), §12 |
| E2 | **Per-encounter reinforcements** = E1 + `DB_CurrentLevel("<lvl>")` and `EnteredTrigger((CHARACTER)_C,(TRIGGER)S_…)` scoped rules, reusing the level's own spawn markers where a vanilla goal already names them | story | ⚠️ | Precise, avoids story fights. Level names: §12. Marker `S_…` GUIDs must be copied out of existing goals (§6) — they are not enumerable from text |
| E3 | **Elite-ify what the level already placed**: `ApplyStatus(_M,"OUR_STATUS",-1.0)` on `CombatStarted`, `SetLevel(_M,_L+2)` (`GetLevel` first), `SetAmbushing(_M,1)` before the fight, `DB_CMB_LevelUpNpcInRegion` for named NPCs (`SharedDev/.../GLO_CombatNPCs_PostEA.txt:43-58`), honour-gated `ApplyStatus` on a named NPC (`Gustav/.../Act1_GOB_SpiderNest.txt:1360-1365`) | story + stats | ✅ primitives confirmed | Cheapest, no new bodies → no loot/XP/perf surprises. Needs named NPCs or a way to enumerate enemies (§8 `IterateActiveObjectsInSameCombatGroup`) |
| E4 | **Stats-layer summons**: give encounter leaders innate/castable summon spells (`SpellProperties "…Summon(<uuid>,…)"`, 183 occurrences in `SharedDev/…/Spell_Target.txt`), or a status whose passive `TriggerRandomCast(chance,,Spell)` (`Shared/…/Passive.txt:1623` `WildMagic`) fires it. A passive on `_Base` + `DifficultyStatuses "STATUS_HARD: …"` would make it Honour-only | stats | ⚠️ the AI has to actually cast it; `OnCombatStarted`/`OnRound` functor contexts exist in `Enumerations.xml` but are used 0× by vanilla passives | Slower to iterate than E1/E2, and summon-AI is the weak link |
| E5 | Edit the levels themselves (add mobs to the encounter) | binary | ❌ not available | No Divine/editor on this install, no `.lvl` tooling, and nothing level-shaped loose on disk — this repo carries only stats text (29 `.txt` + one `.StatusData`) |

## 11. Costs and gotchas

- **Same-path loose file replaces the vanilla file wholesale** — true for our stat tables;
  ⚠️ **untested for goal files**, and we have never edited a vanilla one (§3). Adding a *new*
  file is the safer first move; keep our goal names unique (`MARTIN_*`) so nothing collides.
  ⚠️ Two modules can hold related goal names (`GLO_HagDoubles.txt` in `Gustav`,
  `GLO_HagDoubles_PostEA.txt` in `GustavDev`) — be deliberate about which module a new file goes in.
- **Story text is a separate deploy from stats.** Our goal masters live in the repo at
  `SharedDev/Story/RawFiles/Goals/MARTIN_*.txt` (CRLF, git-tracked). The vanilla goal files
  in `Data/Mods/*/Story/` are **not** in git and a game patch can rewrite that tree, so keep
  our changes in our own files rather than editing vanilla ones. `tools/deploy_story.sh`
  mirrors our files into `Data/Mods/…` if that mount turns out to be the one that is compiled (§3.1).
- **A bad goal file fails silently.** Run `python3 tools/check_goal.py` before testing: it
  rejects unknown call/query/event names, unknown `DB_` predicates, `;` in the wrong places
  and LF line endings (§3.2 — this already caught a name that does not exist).
- **XP / loot / achievements**: spawned bodies may grant XP (inflating Honour-mode XP that
  we deliberately tuned in `XPData*.txt`) and may drop nothing at all. ⚠️ Measure on the
  first test.
- **Performance**: extra bodies = extra pathfinding per round; cap concurrent spawns (the
  `_Max`/`_InUse` pool shape, §9) and prefer `_Temporary=1`.
- **Faction mistakes are invisible**: wrong faction → spawns that ignore the fight, or
  that attack other enemies. Copy the faction of an existing combatant.
- **`_Temporary=1` bodies vanish at combat end** — good for hygiene, bad for loot.
- **Cutscenes and companion-critical fights** (Myrnath, Ketheric, the Emperor…) are scripted
  state machines; reinforcements there break scripts. Gate by level/trigger.

## 12. E1 + E6 (Nautiloid room probes) as implemented, and how to test them

File: `SharedDev/Story/RawFiles/Goals/MARTIN_Reinforcements.txt` (in this repo, CRLF,
git-tracked). Validator-clean: `python3 tools/check_goal.py`. Delete the file to remove the
feature; `martin_off` disables it without a restart.

Seeded in `INITSECTION`:

| Predicate | Purpose |
|---|---|
| `DB_MARTIN_AutoEnabled(1)` | master switch, flipped by the `martin_on`/`martin_off` console events |
| `DB_MARTIN_LevelBlacklist("<level>")` ×6 | no bodies on `CRE_Main_A`, `INT_Main_A`, `BGO_Main_A`, `IRN_Main_A`, `END_Main`, `EPI_Main_A` (tutorial/underdark city/iron throne/endgame/epilogue). **`TUT_Avernus_C` is deliberately not blacklisted** — the Nautiloid is the test bed |
| `DB_MARTIN_ReinforcementTemplate((CHARACTERROOT)Wolf_41da0eff-b533-43cc-a014-218f7d23fa11)` | the wolf Larian's own spawn test uses (`Gustav/.../Goals/Test.txt:353`). Add more rows to diversify |

Rules in `KBSECTION`:

1. `martin_on` / `martin_off` — `TextEvent` toggles, the same idiom as
   `SharedDev/.../GLO_HonorMode.txt:8,19,26`.
2. **Probe (proof of life, no console needed):** `LevelLoaded("TUT_Avernus_C")` +
   `NOT DB_MARTIN_ProbeDone("TUT_Avernus_C")` → `DebugText(...)` + `PROC_MARTIN_SpawnAtHost(0)`.
   A second, generic probe `LevelLoaded(_Level)` + `DB_HonorMode_Enabled(1)` +
   `NOT DB_MARTIN_AnyLevelProbe(_Level)` fires on **any** level, so loading an existing
   Honour save is a valid (faster) test. If you see the message and/or a wolf, the engine
   compiles goal text from this mount and `CreateAtObject` + `SetFaction` +
   `SetHostileAndEnterCombat` all work. ⚠️ `DebugText` may be a no-op in a release build —
   the **wolf is the reliable signal**. Probes spawn with `_Temporary=0` because the
   prologue applies `TUT_SUMMON_BLOCK` to players (`TUT_LowerDeck.txt:36-38`) and whether
   that also blocks script-made temporary bodies is unverified. The once-guards are
   deliberately our own `DB_` facts rather than vanilla's `QRY_OnlyOnce`, so a
   null result cannot be explained away by cross-module helper visibility (§4, §13).
3. **Nautiloid room probes (E6)** — `EnteredTrigger((CHARACTER)_Char,(TRIGGER)S_…)` +
   `DB_HonorMode_Enabled(1)` + `DB_MARTIN_AutoEnabled(1)` + own once-guard
   `NOT DB_MARTIN_RoomDone("…")` → `DebugText(_Char,"MARTIN probe: …")` + `PROC_MARTIN_SpawnAt(_Char)`.
   The triggers are registered in `INITSECTION` with the engine call
   `TriggerRegisterForPlayers` (header:1305 — the call vanilla wraps in
   `PROC_TriggerRegisterForPlayers`, `Shared/.../__AAA_FirstGoal.txt:3044`), so no
   Shared helper is needed. Anchors, all named by vanilla goals (✅ GUIDs diffed against
   `Data/Mods`):

   | Room | Trigger | Vanilla names it at |
   |---|---|---|
   | 2 (transform chamber, Shadowheart's pod) | `S_TUT_TransformChamber_EnterChamber_096ae849-…` | `TUT_TransformChamber.txt:153` |
   | 2b (lab rubble room, devourer callout) | `S_TUT_Misc_RubbleRoom_001_5873b16d-…` | `TUT_Laboratory.txt:515` |
   | 3 (imp room entry, pre-combat) | `S_TUT_ImpRoom_ShakeTrigger_711cd164-…` | `TUT_LowerDeck.txt:9,396` |
   | 3b (imp combat region) | `S_TUT_LowerDeck_CombatEvent_5eb34cda-…` | `TUT_LowerDeck.txt:4` |
   | 3c (lower-deck room) | `S_TUT_LowerDeck_RoomTrigger_ebbf3bb5-…` | `TUT_LowerDeck.txt:418` |

   Room 2/3 probes spawn a *hostile* wolf on the entering character (`_Temporary=0`) — i.e.
   they create a brand-new fight in a room that has none (room 2) or reinforce the first
   combat (room 3). The `CombatStarted` rule spawns with `_Temporary=1`.
   The imp room's own NPCs are also nameable if an imp anchor is ever wanted:
   `S_FirstFight_Imp_Melee_01_07f1512b-…`, `_Ranged_01_38d1ce2f-…`, `_Melee_02_5c5bd50b-…`,
   `_Ranged_02_df44fa65-…` (`TUT_LowerDeck.txt:15-21`), and
   `TUT_ImpRoom_CombatPlayerPosition_001_df89b981-…` is a position marker vanilla reads
   with `GetPosition` (`TUT_LowerDeck.txt:329`).
4. **Auto rule:** `CombatStarted(_CombatGuid)` + `DB_HonorMode_Enabled(1)` +
   `DB_MARTIN_AutoEnabled(1)` + `NOT DB_MARTIN_CombatDone(_CombatGuid)` +
   `DB_CurrentLevel(_LevelName)` + `NOT DB_MARTIN_LevelBlacklist(_LevelName)` → marks the
   combat done, calls the spawner. One body per combat, nothing else.
5. **Spawner PROC:** `PROC_MARTIN_SpawnAtHost` = `GetHostCharacter` → `PROC_MARTIN_SpawnAt(_Host)`;
   `PROC_MARTIN_SpawnAt((CHARACTER)_Anchor)` = `CreateAtObject((CHARACTERROOT)_Template,_Anchor,1,1,"",1,_Spawn)`
   (temporary, spawn VFX on, matched orientation) → `SetFaction(_Spawn,(FACTION)Evil_…)`
   → `SetHostileAndEnterCombat((FACTION)Evil_…,(FACTION)Hero_…,_Spawn,_Anchor)`.
   `CreateAtObject` (header:589) is chosen over `CreateAt` because it needs no coordinates:
   fewer queries in the rule = fewer ways for it to silently fail. If it turns up on top of
   the host, switch to the `CreateAt` + `FindValidPosition` shape of §9.
6. **Bookkeeping:** forget spawned bodies that reach `DB_Defeated`.

Test protocol (≈5 minutes, no save needed — this is the Nautiloid walkthrough):

1. Start a **new Honour-mode** game.
2. **Room 1 (pod):** expected if the file is live: a `MARTIN_Reinforcements loaded` debug
   print and/or a wolf attacking on load.
3. Walk to **room 2** (transform chamber, then the rubble room): expect the
   `MARTIN probe: room 2…` prints and a hostile wolf spawning on top of you — a new
   encounter created from text in a room that has none.
4. Walk to **room 3** (imp room): expect the room-3 probe wolf *and*, when the imp fight
   starts, the `CombatStarted` rule's wolf — i.e. reinforcements joining an existing
   encounter. (Up to ~3 wolves total here: one per room probe that fired + one per combat.)
5. If you have the dev console (`bg3.exe` dev build, or a beta-branch launch option — ⚠️ not
   verified on this install), also try `martin_hello`, `martin_spawn`, `martin_off`,
   `martin_on`. The vanilla analogue is documented at `GLO_HonorMode.txt:6-31`.
6. Negative control: start a non-Honour save → no prints, no spawns.
7. Fast variant: load any existing **Honour** save → the any-level probe should spawn a
   wolf on load (once per level per save).

Test log: run 1 (new Honour game, walked to rooms 2/3) — nothing seen there; room-1 probe
result not recorded, which is the key missing data point. Run 2 uses the `_Temporary=0`
probes + any-level probe to remove the `TUT_SUMMON_BLOCK` confound.

Interpreting a null result: nothing appearing anywhere (room 1, rooms 2/3, any-level probe
on an existing Honour save) means **the channel or the mount is wrong**, not the rule — the
checker already guarantees the grammar and names (§3.2). Then:

```
sudo mount -o remount,rw /home/martin/.local      # Data/Mods is on a ro mount (§3.1)
cd "$(dirname "$(find /home/martin/.local -name deploy_story.sh -path '*/tools/*' | head -1)")/.."
tools/deploy_story.sh --copy                      # mirrors MARTIN_*.txt into Data/Mods/SharedDev/Story/...
```

If it works from `Data/Mods` but not from `Data/Public`, the repo copy becomes a master that
must be deployed, and §3.1 gets closed. If it works from **neither**, the working hypothesis
is that on this install the runtime story comes from the compiled story database inside
`Data/Mods/<Module>/*.pak` (Gustav.pak etc.) and loose `RawFiles/Goals/*.txt` are editor
source only — stats tables are read loose (that is why this repo works), story text is not.
That would close the question in the negative: no new encounters in text on this install,
and the difficulty work stays in the stats layer (E4).

## 13. Open questions

- **Live or not?** Whether goal text under `Data/Public` (or even `Data/Mods`) is compiled at
  runtime on this install (§3, §3.1). The probe in §12 answers it; nothing else on disk does.
- **Dev console availability** on this Proton install: is `TextEvent` reachable at all? If not,
  all interaction must go through automatic rules like the probe above.
- **Cross-module helper visibility**: vanilla defines `PROC_`/`QRY_` helpers in `Shared/`
  (`__PROC.txt`, 457 rules) and calls them from `Gustav`/`GustavDev` goals thousands of times,
  which suggests one story compile — but we have not proven it here, and paks may carry the
  same source. E1 avoids the question entirely by declaring everything it uses; once the probe
  works, a follow-up test could call `QRY_OnlyOnce("…")` to settle it (§4).
- Do script-spawned characters roll corpse loot, and can their level/`Treasure` property be
  set from a goal (`SetLevel` 598 / `GetLevel` 599 / `RequestAutoLevel` 985)? Where
  `drop-chains.md` and this doc meet.
- Do `OnCombatStarted` / `OnRound` `StatsFunctorContext`s and `Summon()` inside
  `OnApplyFunctors` actually fire (E4's weak link — 0 vanilla precedents found).
- Real XP cost of one extra body per combat against the `XPData*.txt` tuning.
- Exact `.lvl` inventory of the paks (encounters, level names, spawn markers) — needs a
  working pak reader; none is installed and byte-grepping a 13 GB pak proves nothing (§3).
