# Backlog — could-look-into notes

Small parking lot for observations and half-ideas that are NOT worth fixing right now,
so they don't get lost. Move items to HANDOVER "ranked next moves" (or resolve them)
when they graduate. Date each entry; delete when done or rejected.

## Wild ambushes: random fights WITHOUT an existing combat (owner question, 2026-10-31)

Vanilla has NO engine-level random encounters: the Osiris header only offers
`Random(modulo, out)` + trigger hooks (`EnteredTrigger`, `TriggerGetRandomPosition`),
and triggers are level objects placed in binary level data — every vanilla "random"
ambush is a designer-authored trigger + small authored candidate set rolled at runtime.
BUT the chaos engine can do genuinely unprovoked random fights with proven primitives:
- heartbeat `Ext.Timer` loop (30-60 s) while exploring + not-in-combat/not-in-dialog
  checks (guard with `DB_Is_InCombat` / `IsInCombat` query);
- spawn near but not on the player: `GetPosition(player)` then `CreateAt(template,
  x, y, z, ...)` (raw coordinates — call exists, story_header.div:507) with offsets,
  or `CreateAtObject` at larger distances;
- `SetFaction` + `SetHostileAndEnterCombat` STARTS the combat (no existing fight
  needed — the call's purpose is starting one);
- same pools/budget/gates/leader logic as the reinforcement engine; maybe a lower
  chance + the existing stacking trigger, and honour-gate at release.
Candidate UX wrinkle: pick mob type by the region? (no cheap region->theme map yet;
RACE_TO_TYPE-style discovery would be needed — or just roll the DEFAULT_TYPES pool).

## Spawn placement / combat edge (owner note, 2026-10-31)

A leader spawned next to an enemy at the edge of the player's vision and stood OUT of
combat, joining only when the player approached. Probably the anchor enemy's combat did
not propagate to the spawned mob at `SetHostileAndEnterCombat` time (distance or turn
boundaries). Owner verdict: fine for now, keep an eye on it.
Possible fix directions if it becomes annoying:
- after spawn, verify with `Osi.IsInCombat(created, ...)` and if false, force-join via
  the combat id we already have from `CombatStarted`;
- spawn closer to the fight's "center" instead of a random single enemy anchor
  (e.g. average of enemy positions, or the dominant-type enemy);
- `CreateAtObject` offsets (`dx, dy` 1-3) could try larger radii so mobs path INTO
  the fight rather than standing at the rim.

## In-game announcements: IMGUI toast MVP shipped (2026-10-31), verdict pending

Osiris DebugText is dead (silent no-op, see Toggle feedback entry), and BG3 has NO Osiris
combat-log call (CombatLogText/DisplayText are DOS2-family, absent from story_header.div).
MVP now in the pak, replacing the old experiment plan below:
- server pushes `Channels.Announce:Broadcast(text)` (Shared/Channels.lua, `Ext.Net.CreateChannel`
  - the doc pattern + proven live by ManyMoreMonsters on this install; SAME channel object
  required by BOTH bootstraps);
- client (new BootstrapClient.lua) shows a Dear-ImGui toast: `Ext.IMGUI.NewWindow`,
  `win:AddText`, `obj:SetColor("Text", {r,g,b,a})`, `Ext.IMGUI.GetViewportSize()` - all
  cribbed from MMM's working code; auto-destroys after 5s (client Ext.Timer assumed, pcall'd);
  logs to profile `ChaosReinforcements_client.log`.
- wired to: leader/boss join (Flavor), wild group spawn (Wild), toggle flips (Toggle).
UNVERIFIED until next playtest: Ext.Net CreateChannel/SetHandler/Broadcast on our mod,
client Ext.Timer.WaitFor, IMGUI flag fields (NoTitleBar etc.) + win.Position. Watch the
client log for "toast FAILED/flag refused" lines. The Noesis route (Ext.UI.GetRoot, crash
risk, needs Ext.UI.Defer in v33) stays parked unless IMGUI proves insufficient.

## Toggle feedback: RESOLVED (2026-10-31)

The toggle spell tooltips now carry the live state and the owner VERIFIED in-game that
the description swaps correctly on cast (Ext.Stats Description swap + Sync() works - the
hotbar does NOT cache it). Casting the shout also leaves its own entry in the combat log
(from the shout invocation itself), which doubles as confirmation feedback. DebugText is
CONFIRMED DEAD: the call logs "shown" while nothing renders (owner saw no floating text
on any toggle cast) - removed from Toggle.lua and Flavor.lua; do not re-enable. A
leader-join combat-log/banner line remains an Ext.UI (client Lua) experiment, below.

## Leader visual distinction (owner idea, earlier)

Beyond the villain name + buffs: tint/color or VFX the leader. Candidate primitives:
- `Osi.PlayEffect(object, fxName, bone, scale)` (story_header.div:635) — needs valid
  effect resource names (probe: dump/try common ones);
- an overhead status icon: add a visible (NOT DisableOverhead) CHAOS_LeaderStatus to
  `CHAOS_Boosts.txt` — the buff statuses are proven to apply, just drop the
  Disable* flags on a variant.

## Equipment phase 2: own ItemDB with cost control (deferred by design)

`tools/` can generate an ItemDB.lua from Weapon.txt/Armor.txt/Object.txt
(`RootTemplate` GUID -> dump Name_GUID, `ValueScale`, `ValueLevel`, `Proficiency
Group`) for the owner's exact cost-multiplier tiers. Currently Larian tables
approximate it. Also queued:
- shields (no `ST_Shields` table -> `TemplateAddTo` a shield root template;
  Merregon prof includes Shields);
- ranged weapons for dex-based humanoids (tables exist: `ST_SimpleRangedWeapons`,
  `ST_MartialRangedWeapons` — but melee AI may not use bows; needs a probe);
- chaos fodder tables: `ST_RandomPotion`, `ST_RandomConsumable`, `ST_Throwable`.

## Balancing / tuning (from playtests)

- RACE_TO_TYPE map grows only from discovery logs (`enemy: ... type ?` lines) —
  collect from longer play sessions and extend the map in Chaos.lua.
- Level-2 gate (hp<=35/ac<=15/ability<=14) is guessed, not playtested at lvl 2 yet.
- Budget formula vs party size: `CombatGetInvolvedPartyMembersCount` worked in the
  tutorial (returned 3); re-check with the real 6-8 char party (NPC-keeper mod).
- Global HP boost migration: `MOB_HP_BOOST` placeholder in Chaos.lua is OFF; once
  native stats are gauged, implement as a CHAOS status in `CHAOS_Boosts.txt`
  (statuses proven) and remove the commented override in
  `GustavDev/Stats/Generated/Data/Status_BOOST.txt`.

## Release prep (when the mod leaves this machine)

- Honour-only gate: vanilla predicate `DB_HonorMode_Enabled(1)` or an SE-side
  difficulty check (currently the engine runs on every difficulty — intentional for
  testing).
- TEST_MODE / LEADER_TEST / EQUIP test knobs -> config or remove.
- Custom bark/bark-like text: loca route now PROVEN and in the pak
  (`Localization/English/ChaosReinforcements.loca`, recipe in docs/lua-modding.md) - if we
  ever want custom tell lines instead of DebugText, just extend the xml and reconvert.
- Version bump + workshop-ready description in meta.lsx.

## DECISION: all spawns stay Temporary=1 (owner confirmed 2026-10-31)

Everything the mod spawns (wild groups + wave reinforcements) uses CreateAtObject
Temporary=1 and is therefore excluded from savegames; group state (TTLs, registry,
backoff) lives in Lua memory only and resets with the session. Owner explicitly
rejected the persistent alternative (Temporary=0 + Ext.IO.SaveFile state +
re-adopting groups at SessionLoaded) as "way too potentially troublesome".
Do not revisit without a new owner request. (Side effect: save-scumming removes
a wave mid-fight - accepted as a feature.)

CORRECTION (same day, in-game evidence): BG3 DOES save temporary characters -
a wild imp pack survived save/load and attacked in a later session. Consequence:
orphaned packs (no Lua state after reload) are now recognized by persistent
signatures instead: every spawn gets the CHAOS_Spawn tag (SetTag; IsTagged
survives saves) and evil wild packs carry our unique Evil NPC faction string;
the reinforcement engine skips fights against anything matching either. The
"wipe-on-exit" expectation above is wrong; the owner decision (keep Temporary=1)
stands unchanged.
