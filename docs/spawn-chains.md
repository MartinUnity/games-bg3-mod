# Spawn Chains — getting more mobs into an encounter

Research notes (2026-10-30): can we add **enemies**, not just HP, to the fights the
player actually has — using only the text we already deploy? Companion to
`drop-chains.md` (loot side, and the "text vs binary" split this doc refines) and
`overview.md` §6 (how our overrides load).

Legend: ✅ = read out of files on this install, quotes/line refs given. ⚠️ = plausible
from the grammar/precedent but needs an in-game test before we rely on it.

## 1. Verdict

**Yes.** An Osiris goal file can create brand-new characters at runtime, gate them on
Honour mode, place them at a legal position, and drop them into a combat that is already
running. ✅ Vanilla itself does exactly this (the Hag's "doubles", extra ones **only in
Honour mode**), and it does it in the same loose goal files we already hand-edit.

What stays binary: where an encounter *is* — which mobs the level places, its trigger
regions, its spawn markers, its AI grid. We cannot add a brand-new encounter to a level,
nor move its markers. But we can add bodies to encounters that already exist, anchored on
the level's own spawn markers (addressable by name from goals), on the players, or on
props/casualties.

## 2. Three layers — and a correction to `drop-chains.md` §5

| Layer | Editable? | What lives there |
|---|---|---|
| **Level / scene data** (`.lvl`, `.lsf`, `.lsx` inside `Data/*.pak`) | No | the encounter's placed mobs, trigger regions, spawn-point markers, AI grid, loot wiring |
| **Story goals** (`Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/Goals/*.txt`) | **Yes — already part of our deployment** (`overview.md` §6) | Osiris rules: create/transform/teleport characters, factions, combat grouping, flags, timers |
| **Stat tables** (this repo, `Data/Public/**/Stats/Generated/`) | Yes | template stats, statuses, passives, innate/summon spells, difficulty hooks |

`drop-chains.md`:121 says new-encounter wiring "is not possible in text". Correct for
**loot wiring** (a spawned body still has no text hook that says "its corpse rolls table
X"), but **the mob itself can be created in text**. ⚠️ Whether a script-spawned character
drops anything (equipment only? nothing?) is untested — check before depending on spawns
for loot.

## 3. Why this channel is known-live (the question that gated everything)

- ✅ `overview.md` §6: our story/goal edits ("level cap, 3 short rests, companion & pet
  changes") are hand-edited files under `Data/Mods/*/Story/RawFiles/`, deployed with the
  game, not registered as mods. They work in game → the engine reads loose goal text.
- ✅ `Data/Mods/*/Story/RawFiles/Goals/` on this install holds 944 loose `.txt` goals
  (Gustav 253, GustavDev 554, Shared 122, SharedDev 17, GustavX 8) and **nothing compiled**
  — no `.osiris`/`.loca` story blobs anywhere on disk.
- ✅ The header file is machine-generated text listing the engine's installed calls and
  queries (`story_header.div`, "Story header automatically generated. Do not modify!") —
  558 `call`, 425 `query`, 320 `event` lines in the GustavDev copy. It declares **no**
  `DB_` predicates, so a new goal file may introduce its own `DB_`/`FLAG`/`TAG` names
  without registering them anywhere. ⚠️ (Unique names are still on us; collisions are silent.)

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

## 5. Making bodies: the primitives ✅

Signatures verbatim from `GustavDev/Story/RawFiles/story_header.div` (line numbers
there; other modules' headers differ slightly):

| Line | Primitive |
|---|---|
| 588 | `CreateAt(_TemplateId, _X, _Y, _Z, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` |
| 589 | `CreateAtObject(_TemplateId, _Anchor, _Temporary, _PlaySpawn, _SpawnFinishEvent, _MatchOrientation, out _CreatedObject)` — no coordinates needed, anchors on any object/character |
| 590 | `CreateOutOfSightAtDirection(_TemplateId, _X,_Y,_Z, _DirectionAngle, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` — ambush arrivals |
| — | `CreateOutOfSightAtDirectionFromObject(_TemplateId, _AnchorObject, _DirectionFrom, _Temporary, _PlaySpawn, _SpawnFinishEvent, out _CreatedObject)` — the crime-guard spawn idiom (`Shared/.../_CRIME_CrimeGuards.txt:1647-1661`) |
| 100 | `AppearOutOfSightTo(_Character, _Target, _DirectionFrom, _PlaySpawn, _Anim, _Event, _PreventTeleportOnFailure)` — also `AppearAt`, `AppearAtPosition` — teleport an *existing* NPC in |
| — | `Transform(_Object, _TargetTemplate, _ShapeshiftRule)` (158 uses in loose goals) — swap one body for another, e.g. escort → monster |

Notes on the shared argument shape: `_Temporary` `1` = summon-like (vanilla Hag doubles
pass `1`); `_PlaySpawn` `1` = play the spawn VFX; `_SpawnFinishEvent` is a script event
string (`""` is fine); `_MatchOrientation` `1` = face the anchor. Templates are
`CHARACTERROOT` UUID names, e.g. `Hag_Green_Act1Hag_Double_8c85932d-12dd-4046-a694-6534071470a2`,
`Shadow_A_749b1e7d-63a1-4a3d-b0ca-f237b9ada5c4`, `Kobolds_Melee_Drunk_45e31b7d-32ec-4f3d-8067-79061aeec77b`.

Working vanilla call sites ✅:
- Barrel → kobold: `GustavDev/.../Act1b_CRE_Brewery.txt:120` — `CreateAtObject((CHARACTERROOT)Kobolds_Melee_Drunk_…, _Barrel, 0, 1, "", 1, _Kobold)` fired by `DB_PermaDefeated(_Barrel)`.
- N copies at a position: `GustavDev/.../Act1_FOR_DangerousBook_PostEA.txt:49-57` — `PROC_…_SummonShades(3, _X,_Y,_Z)` + `QRY_DoNTimes(_Num)` loop + `CreateAt(Shadow_A_…, _PosX,_PosY,_PosZ, 0, 1, "", _Creature)` + `SetFaction(...)`.
- Item → creature: `SharedDev/.../GLO_CombatNPCs_PostEA.txt:598-606`.

## 6. Legal positions, factions, and joining a running fight ✅

- **Don't spawn inside geometry.** `FindValidPosition(_X,_Y,_Z, _Radius, _Object, _AvoidDangerousSurfaces, out _NX,_NY,_NZ)` (`story_header.div:654`) with a plain-position fallback — this is exactly what vanilla does in `Gustav/.../GLO_HagDoubles.txt:249-266`, then `CreateAt(…,1,1,"",_HagDouble)` at `:205`.
- **Anchor sources**: level spawn markers are addressable *by name* from goals
  (`DB_LOW_HagDoublesSpawnPoints((TRIGGER)…)` → `GLO_HagDoubles_PostEA.txt:68-78`; trigger
  GUIDs appear in goals all the time, e.g. `GLO_CombatNPCs_PostEA.txt:10`). Also
  `GetPosition` (588→624), `GetDistanceTo` (626), `GetClosestAlivePlayer(_Target, out _Player, out _Dist)` (895),
  `CharacterTemplatesInTrigger(_CHARACTERROOT, _TRIGGER, out _Count)` (1309).
- **Join the combat that is already going:** `SetCombatGroupID(_New, "<GroupID>")` (946) —
  vanilla: `SetCombatGroupID(_HagDouble,"HAG_Hag_State_HagInLair")` (`GLO_HagDoubles.txt:218`);
  the group-ID string is authored in level data, so **reuse one you can read in a goal file**.
  `SetCombatGroupAndEnterCombat(_New, _GroupID, _Enemy)` (922) or plain
  `EnterCombat(_Source,_Target)` (993; used directly in goals, e.g.
  `EnterCombat(S_SHA_Necromancer_FleshGolem_…, _Char)`).
  `IGNORE_COMBAT_LATE_JOIN_PENALTY_6d60bed7-…` tag exists to skip the late-join initiative
  penalty (`GLO_HagDoubles_PostEA.txt:14`).
- **Make them mean:** copy an existing faction rather than inventing one —
  `GetFaction(_ExistingEnemy,_F)` then `SetFaction(_New,_F)`; or the vanilla hostility
  engine `PROC_SetRelationMutual((FACTION)_Mine,_Faction,0)` on `Saw(_A,_B,_)`
  (`Act1_FOR_DangerousBook_PostEA.txt:64-79`). `SetHostileAndEnterCombat(_FA,_FB,_A,_B)` (921).
- **Clean up:** `RemoveSummons(_Character, _Die)` (240); `_Temporary=1` bodies go away with
  the combat; `DB_PermaDefeated`/`SetImmortal` control death handling.

## 7. Honour-mode gating ✅ (this is the piece that makes it "Honour only")

`SharedDev/Story/RawFiles/Goals/GLO_HonorMode.txt` is a vanilla global goal that keeps a
single predicate in step with the ruleset modifier:

- `:10` `CheckRulesetModifierBool(HONOUR_STATS_ef0506df-da9f-40e2-903a-1349523c1ae4, 1, _Return)`
- `:31-45` on `LevelLoaded(_LevelName)` / `RulesetModifierChangedBool(…)` it runs
  `PROC_HonorMode_Enable/Disable`
- `:66-77` which flips `DB_HonorMode_Enabled(1)`

So **any** goal we write can simply say `DB_HonorMode_Enabled(1)`. Vanilla uses it that way
in `GLO_HagHonourMode.txt`, `GLO_HagDoubles_PostEA.txt:22,58`,
`SharedDev/.../GLO_CombatNPCs_PostEA.txt:878,890`, `Gustav/.../Act1_GOB_SpiderNest.txt:1363`.
`GLO_HonorMode.txt:6-27` also wires the dev console: `TextEvent("honormode")`,
`"honormodeon"`, `"honormodeoff"` → handy for A/B testing a spawn rule without restarting.

Two other difficulty levers we already use or could pair with this:
- Stats layer: `Shared/Stats/Generated/Data/Character.txt:25` (`_Base`) →
  `DifficultyStatuses "STATUS_EASY: HEALTHREDUCTION_EASYMODE; STATUS_HARD: HEALTHBOOST_HARDCORE"`,
  live override at `GustavDev/Stats/Generated/Data/Status_BOOST.txt:11621`.
- Script layer can also set HP, and it has to fight that status for control: vanilla
  defers `SetHitpoints` to `EnteredCombat` *"so `HEALTHBOOST_HARDCORE` doesn't override it"*
  (`GLO_HagDoubles.txt:224-230`) — same interaction applies to anything we spawn.
- NPC level-ups by region, no new bodies needed: `DB_CMB_LevelUpNpcInRegion((CHARACTER)S_…, "CTY_Main_A", 11, "LOW_WULBREN_LEVEL_11")` (`GLO_CombatNPCs_PostEA.txt:44-58`).

## 8. Hooks available in goals (counts = uses across the 944 loose goals) ✅

| Hook | Use for |
|---|---|
| `CombatStarted(_CombatID)` (27), `CombatRoundStarted(_CombatID,_Round)` (35), `EnteredCombat(_A,_ID)`, `CombatEnded(` (164) | reinforcement waves, round-N ambushes |
| `DB_Is_InCombat(_Char,_ID)`, `CombatGetInvolvedPlayersCount(_ID,out _N)` (765), `CombatGetActiveEntity` | size the response off the fight |
| `LevelLoaded("TUT_…")` / `DB_CurrentLevel("CTY_Main_A")` | scope a rule to one level (198 uses of `DB_CurrentLevel("CTY_Main_A")` alone) |
| `PlayerEnteredTrigger((TRIGGER)S_…)` | the moment the player walks into an encounter |
| `StatusApplied(_C,"STATUS",_,_)`, `UsingSpell(_C,"Spell",_,_,_)`, `CharacterDied(` | reactive spawns (barrel/kobold, hag counterswap) |
| `Saw(_A,_B,_)`, `DB_Sees`, `QRY_IsEnemyToAnyPlayerInCombat` | aggro/faction wiring |
| `Random(_Modulo, out _R)` (97), `QRY_OnlyOnce("key")` (2458), `QRY_DoNTimes(_N)` (34), `TimerLaunch`/`TimerFinished`, `DB_PermaDefeated` | chance gates, caps, waves |
| `SetAmbushing(_Entity,1)` (1129) | make *existing* mobs hidden reinforcements — no spawn at all |

DOS2-era `EncounterPrepare` / `SpawnGroup` / `CrowdSpawnRegion` are **gone** in BG3. ⚠️ No
text-visible "encounter size × difficulty" knob exists; honour-mode crowd sizes are baked
into the levels.

## 9. Canonical example to copy (Honour-only extra enemies, mid-combat) ✅

```
// SharedDev/.../GLO_HagHonourMode.txt:4-10   — how much extra, per spell level
DB_GLO_NewDoublesByCounteredSpellLevel("Shout_HAG_Counterswap_5", 3);
//                                          :107-110  — fire it, Honour only
// Gustav/.../GLO_HagDoubles.txt:201-230     — the spawn itself
QRY_HAG_SpawnDoubles_FindValidPosition(_Char,_Trigger)          // FindValidPosition + fallback :249-266
CreateAt(Hag_Green_Act1Hag_Double_…, _X,_Y,_Z, 1, 1, "", _HagDouble)
DB_HAG_HagLair_Doubles(_HagDouble);
SetImmortal((CHARACTER)_HagDouble, 1);
PROC_CharacterDisableAllCrimes(_HagDouble, 1);
SetCombatGroupID(_HagDouble, "HAG_Hag_State_HagInLair");        // joins the running combat
PROC_HAG_SetDoublesAttitudeToPlayers(_HagDouble);               // faction/hostility
IF EnteredCombat(_HagDouble,_CombatID) THEN SetHitpoints(_HagDouble,_Hp);   // after HEALTHBOOST_HARDCORE
```

Plus the spawn-pool-with-cap pattern (guards): `Shared/.../_CRIME_CrimeGuards.txt:1647-1661`
— `DB_…SpawnPool(_Region,_Pool,_Home,_Chest,_Max,_InUse)` + `_InUse < _Max` +
`CreateOutOfSightAtDirectionFromObject(…)` + bump `_InUse`. Copy that shape for any
"max N extra mobs at a time" rule.

## 10. Recipes, ranked

| # | Recipe | Layer | Confidence | Notes |
|---|---|---|---|---|
| E1 | **Global Honour-only reinforcements**: new goal file, `CombatStarted(_ID) AND DB_HonorMode_Enabled(1) AND QRY_OnlyOnce(…)` → `GetClosestAlivePlayer` → `FindValidPosition` → `CreateAt(template,…,1,1,"",_N)` → copy faction of an involved enemy → `EnterCombat(_N,_Player)` | story | ⚠️ untested, but every primitive is vanilla-used | Best first experiment: works everywhere, one file, easy to bound (cap per level, `Random` gate, level blacklist for cutscenes/companions) |
| E2 | **Per-encounter reinforcements** = E1 + `DB_CurrentLevel("<lvl>")` / `PlayerEnteredTrigger((TRIGGER)S_…)` and reuse of the level's own spawn markers named in existing goals | story | ⚠️ | Precise, avoids story fights; needs the level name and a trigger GUID — both are readable in the existing goal files |
| E3 | **Elite-ify what the level already placed**: on `EnteredCombat`, `ApplyStatus` our own HP/extra-action statuses, `SetAmbushing(_M,1)` before the fight, `DB_CMB_LevelUpNpcInRegion` for regional mobs | story + stats | ✅ primitives confirmed | Cheapest, no new bodies → no loot/XP/perf surprises |
| E4 | **Stats-layer summons**: give encounter leaders innate/castable summon spells (`SpellProperties "…Summon(<uuid>,…)"`, 183 occurrences in `SharedDev/…/Spell_Target.txt`), or a status whose passive `TriggerRandomCast(chance,,Spell)` (`Shared/…/Passive.txt:1623` `WildMagic`) fires it. A passive on `_Base` + `DifficultyStatuses "STATUS_HARD: …"` would make it Honour-only | stats | ⚠️ the AI has to actually cast it; `OnCombatStarted`/`OnRound` functor contexts exist in `Enumerations.xml` but are used 0× by vanilla passives | Slower to iterate than E1/E2, and summon-AI is the weak link |
| E5 | Edit the levels themselves (add mobs to the encounter) | binary | ❌ not available | No Divine on this install, no `.lvl` compiler in lslib, nothing loose on disk |

## 11. Costs and gotchas

- **Same-path loose file replaces the vanilla file wholesale** (as with our tables). Adding
  a *new* goal file is safer than editing a big vanilla one; keep our goal names unique
  (`MARTIN_*`) so nothing collides. ⚠️ Two modules can contain the same goal name
  (`GLO_HagDoubles.txt` in `Gustav`, `GLO_HagDoubles_PostEA.txt` in `GustavDev`) — be
  deliberate about which module a new file goes in.
- **Story files are outside git** (`overview.md` §6: "Not version-controlled here"). Any
  spawn experiment is unreproducible and a game patch can reset those folders. Pull the
  goal files we touch into the repo (or at least copy them to a branch) before experimenting.
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

## 12. Fastest in-game test (the Nautiloid lab)

Second room after the start: Myrnath strapped to the chair, "Us" the intellect devourer.
Good testbed because a new game reaches it in ~1 minute and it contains a live searchable
NPC. Its wiring is `Gustav/Story/RawFiles/Goals/TUT_Laboratory.txt` — note that everything
in it is a **pre-placed level entity** (`S_TUT_Lab_…` names) driven by
`SetOnStage`/`TeleportTo`/`UseSpell`/`Transform`; the *freeing* of "Us" is not a spawn, it's
a state change on a level-placed character (`Transform(victim, QUEST_TUT_LAB_TrappedDevourerVictim_Brainless_…)`).
So this room proves the opposite of "everything is spawnable from level data": the level's
cast is fixed, but a goal can still add bodies to it (E2). Steps:

1. Pick an `INITSECTION`-free new file, e.g. `GustavDev/Story/RawFiles/Goals/MARTIN_SpawnTest.txt`.
2. Gate: `DB_HonorMode_Enabled(1)` + `DB_CurrentLevel("<nautiloid level name>")` —
   get the name by logging it with `TextEvent("lvl")` + `DB_CurrentLevel(_L)` + `DebugText`
   (pattern at `GLO_HonorMode.txt:6-16`).
3. Spawn one obvious creature (`Shadow_A_749b1e7d-…`) near `GetClosestAlivePlayer`,
   faction-copy an enemy, `EnterCombat`.
4. Verify in ~2 minutes of a new game; iterate with the `honormodeon/off` console commands.

## 13. Open questions (next research pass)

- Do script-spawned characters roll corpse loot at all, and can their level/`Treasure`
  property be set from a goal (`SetLevel`? `RequestAutoLevel`?) — this is where
  `drop-chains.md` and this doc meet.
- Do `OnCombatStarted` / `OnRound` `StatsFunctorContext`s and `Summon()` inside
  `OnApplyFunctors` actually fire (E4's weak link — 0 vanilla precedents).
- Exact `.lvl` inventory of the paks (which encounters exist, their level names and spawn
  markers) — needs a working pak unpacker; `Data/Gustav.pak` is 13 GB, TOC-only is enough.
- Whether a *new* goal file in a module whose story we also override wholesale is always
  picked up (we only ever edited existing files so far).
