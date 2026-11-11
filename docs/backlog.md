# Backlog — could-look-into notes

Small parking lot for observations and half-ideas that are NOT worth fixing right now,
so they don't get lost. Move items to HANDOVER "Open right now" (or resolve them)
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
- ~~`CreateAtObject` offsets (`dx, dy` 1-3) could try larger radii~~ **FALSE PREMISE
  (2026-11-02 correlation):** args 3/4 of `CreateAtObject` are `_Temporary`/`_PlaySpawn`,
  not x/y offsets (legacy naming in old call sites) — placement radius work must happen
  in our own anchor math (Common.lua), not in the call args.

## In-game announcements: IMGUI toast RESOLVED (2026-11-02, owner: "imgui toasts works well")

Osiris DebugText is dead (silent no-op, see Toggle feedback entry), and BG3 has NO Osiris
combat-log call (CombatLogText/DisplayText are DOS2-family, absent from story_header.div).
The MVP (in the pak since 2026-10-31) is CONFIRMED WORKING in playtests:
- server pushes `Channels.Announce:Broadcast(text)` (Shared/Channels.lua, `Ext.Net.CreateChannel`
  - the doc pattern + proven live by ManyMoreMonsters on this install; SAME channel object
  required by BOTH bootstraps);
- client (BootstrapClient.lua) shows a Dear-ImGui toast: `Ext.IMGUI.NewWindow`,
  `win:AddText`, `obj:SetColor("Text", {r,g,b,a})`, `Ext.IMGUI.GetViewportSize()`;
  auto-destroys after 5s; logs to profile `ChaosReinforcements_client.log`.
- wired to: leader/boss join (Flavor), wild group spawn (Wild), toggle flips (Toggle).
Noesis route (Ext.UI.GetRoot, crash risk, needs Ext.UI.Defer in v33) stays parked.

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
- shields: ✅ shipped v3.28 — `ST_ArmorShield` unusable (StartLevel 6 gate), direct
  `WPN_HUM_Shield_B_0/C_0/D_1` templates instead; shields are off-hand weapons, the
  auto-equip listener places them (tank 100%, other Shields-prof melee ~55%);
- ranged weapons for dex-based humanoids: ✅ shipped v3.28 as the ranged-ROLE primary
  weapon (name-pattern role guess + ST_SimpleRangedWeapons/Martial + _1 at tier 4) —
  ✅ bow + elemental arrows CONFIRMED used in-game (owner, 2026-11-11; see playtest item);
- chaos fodder tables: `ST_RandomPotion`, `ST_RandomConsumable`, `ST_Throwable`.
- **support-slot playtest** (v3.21 shipped the slot; ⚠️ needs in-game confirmation): does NPC
  AI actually **use** the new items — scrolls (`LOOT_SCROLL_*` cast without knowing the spell?),
  special arrows (ammo consumed? bow picked up from `ST_SimpleRangedWeapons` and fired?),
  grenades/poisons (thrown/applied?) — and does the bow grant interfere with melee-role weapon
  rolls. Log lines `support: <role> band <n> ...` in `ChaosReinforcements.log` mark recipients;
  if AI ignores items, consider swapping to items kits natively use, or drop the dead pools.
  **Partial verdict (owner 2026-11-01): healing potions ✅** — "they use healing potions to heal
  each other" (the item-use AI path works). Scroll still untested: the Chromatic-Orb caster died
  before acting (owner keeping one alive next fight); arrows/grenades/poisons open. v3.28 moved
  the bow into the ranged role's PRIMARY weapon slot, so the support-bow/melee-weapon
  interference question is moot.
  **Partial verdict (owner 2026-11-11): special arrows ✅** — ranged mobs fire the
  elemental stacks (fire/thunder…), i.e. bows get picked up AND used; **potions broadly
  ✅** — self-strengthening (Haste etc.) AND offensive use, and damaging/debuff flasks
  get thrown at the party. Still NOT observed: scroll casting, poison application
  (vanilla goblins DO poison when they carry it — likely just no poison-carrying team
  encountered, keep watching), and thrown grenades as such (flask-throwing works, so the
  throw-AI path exists — `ALCH_Solution_Grenade_*` likely fine, awaiting a sighting).
- **fizzle-backoff watch** (v3.25): ✅ RESOLVED 2026-11-02 — owner: "fizzle backoff ...
  works well" (real-fight confirmation vs fizzle anomaly, and the backoff pacing feel right).

## Balancing / tuning (from playtests)

- RACE_TO_TYPE map grows from discovery logs (`enemy: ... type ?` lines) — v3.33 seeded
  it with stats-verified entries (Bugbear/Gnoll/Ogre/Raven/HalfElf/Halfling/Meazel) and
  added `tools/grow_race_to_type.py`: parses the log, groups resolved/unknown races with
  frequency + sample templates, prints ready-to-paste suggestion lines. Run it after long
  sessions, verify each candidate against vanilla stats `_Type` chains, add to Chaos.lua.
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
- ~~TEST_MODE / LEADER_TEST / EQUIP test knobs -> config or remove~~ **DONE v3.33
  (2026-11-02):** TEST_MODE/LEADER_TEST/WILD_TEST deleted (no EQUIP knobs ever existed);
  targeted console probes (`!chaos*`) stay.
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

## Reinforcements never got the team/group composition treatment (owner feedback, 2026-11-01)

Owner playtest vs the ambush goblins: human reinforcements looked "kinda half-done":
High-elf Harper_Caster (INT18/WIS) got rapier+cloak, no caster vibe (scrolls did land —
support slot); gnome "tank" AC12, scale-mail look but no shield; goblin Sharp-Eye (DEX15,
"Sharpsooter: Low ground") got a scimitar, only later a shortbow; Dragonborn Fighter =
correct. Also: goblin joined the Humanoid pool mix (expected — Goblin maps to type
Humanoid via RACE_TO_TYPE; it IS the type-affinity feature working).

Answer at the time: yes, this was a deliberate deferral — combat reinforcements still use
the LEGACY per-member equip rolls (no group tier, no roles), while wild groups got tiered
composition (v3.14→v3.21). Options if the owner wants parity, ranked:
1. **Cheap parity (Equip.lua only):** pick weapon tables by role guess + profs — casters:
   staff/no weapon + more scrolls; Shield-profits get a shield (`ST_Shields`?); finesse
   tables only when DEX is the higher attack stat. Fixes most "wrong vibe" cases, no new tech.
2. **Full parity:** run combat reinforcements through the same CHAOST team composer
   (templates now finally register — see HANDOVER v3.27 .lsf fix; ⚠️ verify `!chaos_root`
   first). Bigger change: reinforce() has no group plan today; needs slotting + level math
   per wave (budget already exists).
3. **Naked/underwear look:** vanilla NPC root templates carry NO equipment (gear lives on
   level instances), so spawns start visually bare before our equip lands; consider a
   baseline clothing pass (cheap alch/loot clothing ids) or accept as "rough mercenary".

**STATUS v3.28 (2026-11-01): option 1 SHIPPED** (role parity in Equip.lua — see HANDOVER
v3.28: staff for casters, bow-primary for ranged, Shields-prof shields, finesse gated to
melee, unified role guess; offline grid-sim verified incl. the owner's exact complaint
cases). ⚠️ in-game verdict pending next playtest. **Option 2 is the agreed next move** once
the owner confirms parity + first CHAOST class-teams on v3.28: route `reinforce()` through
the team composer (slots per wave budget; budget math already exists in Chaos.lua).
Cosmetic side-note from the same playtest: tooltips show the template's native "Level 1"
for reinforcements (SetLevel removed v3.3; the number is cosmetic — HP/ExtraAttack come
from the fixed stat block). Not fixable via Lua; only stat-file edits would change it —
do not chase this.

**STATUS v3.29 (2026-11-01): option 2 SHIPPED** (trigger was the owner's "humans + 2
goblins + 1 Meazel — too odd" wave): `reinforce()` runs the CHAOST composer for Humanoid
fights at base ≥ 3; ONE donor race per wave from `dominantRaceKey(enemies)` (goblin fight
→ goblin squad; 20% chaos override = random race); composer moved to Common.lua shared
globals; goblin + half-orc donors added (504 → 792 templates). Wild squads race-coherent
too. ⚠️ in-game: race-match verdict + `!chaos_root` 792 pending next boot. Remaining
composition follow-ups: ~~leader is still a pool mob even in team mode~~ **RESOLVED
v3.33: donor-race CHAOST tank leads team waves** (wildcard backup, capped level, pool
fallback); non-Humanoid fights stay on the pool path (no
creature-class content for them); Meazel-style oddities now only via the 20% override.

**Cosmetic visuals (v3.41, 2026-11-03)** — NPC gear is baked into the template's
CharacterVisualResourceID body; every CHAOST node now stamps a vanilla guard-style body
per race (RACE_VISUALS in gen_teams.py). Parking lot:
- Goblin **_Tier2** bodies (fb5c6d24 melee / 66a0dc01 f / b1825b38 ranger) = beefier
  look for tier>=3 squads (swap by group tier inside EquipMob? no — CVRID is template
  static, would need per-tier CHAOST variants or accept one look per race).
- Tiefling body CHOSEN on taste only (Asmodeus Player_Strong melee / InvokeDuplicity
  caster) — needs owner in-game verdict; originals looked "naked".
- human_m + dwarf_f casters reuse the melee body (no clean vanilla cleric CVRID;
  TEST_Humans_Male_JOBO_CC_Previs_* skipped as dev placeholders).
- Body vs stats mismatch is cosmetic: rolled armor (AC) may not match the baked look
  (e.g. plate AC on a light-armored body). Accept unless owner complains.

**v3.44 class roster — owner follow-ups (2026-11-03)** — framework shipped; these
need owner references / in-game verdicts before tuning:
- ✅ VERDICTS IN: hexblade skills/stats good; cleric shields work; Duelist looked
  right EXCEPT missing TWF + lone magic warhammer (both FIXED v3.45 — re-verdict:
  duelist now fights with a light pair + off-hand bonus attack).
- WARLOCK KIT: current = blast passive + Hex + ChromaticOrb; owner to supply a
  reference build (invocations/patron taste). GreatOldOne chosen arbitrarily.
- HEXBLADE: melee CHA via WeaponAttackRollAbilityOverride(SpellCastingAbility) +
  Fiend patron (no hexblade table exists). Check to-hit/damage numbers match CHA;
  owner may want 2h pact (WPN_*_Pact exist) or shield.
- BARB THROWER: 3-8 javelins added, but NPC AI may not THROW them (melee-first);
  verdict needed — may require a thrown-weapon spell or Tag, compare vanilla
  javelin mobs (BASE_WEAPON_Javelins donor exists for reference).
  **Update 2026-11-11: still no javelin throw observed** — the barb instead picked up an
  environment ROCK and threw it (the vanilla throw path works; our javelin kit never
  triggered). Next lever: diff against the BASE_WEAPON_Javelins donor / try a
  thrown-weapon spell or Tag on the kit.
- DRUID SHIFTER: WildShape granted as ActionResource boost (UCL lvl2) — engine NPCs
  may never activate it; if unused in fights, consider shifter = PrimalStrike melee.
- SORCERER: no metamagic rows in UCL_WildMagic (points granted, unused) — cosmetic.
- MONK: UCL_FourElements_Thief carries a Thief layer (lvl 7-9: fast hands/purse) —
  acceptable garnish or swap to vanilla fe1319a2+Shadow if owner objects.
- Weights are first-guess (tank 50/30/20, caster 40/15/15/15/15): tune on feel.
