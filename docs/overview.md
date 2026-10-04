# Gustav Mod — Repository Overview

_Created 2026-10-03. Working notes on what this repo is, what it contains, and how it
relates to the live game install._

## 1. What this is

A personal BG3 data-mod, maintained as a git repo cloned into the game's
`Data/Public/` directory (per `README.md`). Content is authored in Larian's
divine editor (decompile → edit → re-export) and consists of **stat table
overrides** plus a set of **decompiled story-file overrides** living outside the
repo (see §6).

- Repo root: `…/Baldurs Gate 3/Data/Public/` (this git repo)
- Game install: `…/Baldurs Gate 3/` (Proton/Steam Linux)
- First commit: `e9688a8` 2023-10-10 (only `.gitignore` + README)
- **Decompile baseline: `ffdc1a0` "Initial #2" 2023-10-10** — every user change
  since the original decompile can be recovered with
  `git diff ffdc1a0 HEAD -- <table>` (≈ +51,870 / −353 lines across the repo).
- 70 commits total, latest `41098ea` "Prep" (2026-10-03).

## 2. Branches

| Branch            | Notes |
|-------------------|-------|
| `main`            | Full build (all 4 dirs). Currently == `prepare`. |
| `prepare`         | (current) `main` + README Proton-path cleanup. |
| `honor-mode`      | Reduced: no `GustavDev/`, drops `SharedDev/Status_BOOST`, `XPData-80`, `TreasureTable`, `setXPMode.sh` (≈ −46k lines). |
| `honor-mode-solo` | == `main`/`prepare` (merged via PR #1, `624ce62`). |

## 3. Directory layout

Four "build" folders, each `Stats/Generated/Data/*.txt` (+ one `TreasureTable.txt`):

| Table | Gustav | GustavDev | Shared | SharedDev |
|---|---|---|---|---|
| Armor | 151 | 355 | 513 | — |
| Weapon | — | — | 301 | — |
| Passive | 167 | 608 | 471 | 465 |
| Character | — | — | 398 | 329 |
| Spell_Shout | — | — | 353 | 334 |
| Spell_Target | — | — | 684 | 1064 |
| Status_BOOST | — | 1236 | — | 845 |
| XPData{,-67,-80,-FAST} | — | — | ✓ | ✓ |
| Data.txt (global balance keys) | — | — | ✓ | — |
| TreasureTable | 517 tbls | 532 tbls | 465 tbls | 64 tbls |
| HealthBoosts.StatusData | — | ✓ (2.3 KB) | — | — |
| setXPMode.sh | — | — | ✓ | ✓ |

`Gustav` = campaign build (older, Oct–Dec 2023). `GustavDev` = the newer
campaign build (added 2024-07-31, `df09703`), superset-style. `Shared` =
global changes. `SharedDev` = newer/expanded global changes (added
2024-08, plus `Status_BOOST`/`TreasureTable` later).

## 4. File formats (Larian editor text export, CRLF line endings)

- **Stat tables** (Armor/Weapon/Passive/Character/Spell_*/Status_BOOST):
  ```
  new entry "WPN_Longsword_10"
  type "Weapon"
  using "WPN_Longsword"          ← inheritance / base reference
  data "Key" "Value"             ← field overrides
  ```
  Empty stub entries like `_TWN_a`, `_CRA_a` (name+type only) are export
  artifacts — harmless.
- **TreasureTable.txt**: `new treasuretable "Name"` / `new subtable "lvl ranges"` /
  `object category "I_…ItemUUID",count,per-rarity flags…`
- **XPData*.txt**: flat `key "LevelN","xp"` + `key "MaxXPLevel","N"`, heavily
  commented with the XP math. `setXPMode.sh` swaps which variant is active
  (FAST / -67 / -80 / default; default `MaxXPLevel` 50 in FAST variant).
- **Data.txt**: global gameplay constants (throw distance, haste multiplier,
  disease radius, …).
- **HealthBoosts.StatusData**: small status-data blob for the health-boost mechanic
  (touched by `HealthBoostLocal` ScriptExtender mod, see §6).

## 5. Content catalog (what the user actually added/changed)

Derived from `git diff ffdc1a0 HEAD` (added entries) + inspection.

### Shared/ (global, present since the 2023-10-10 baseline)
- **Armor +161 entries**: stat-specific generic loot gear and visual variants —
  `FOR_Boots/Shoes/Random_Ring_{Cha,Con,Dex,Int,Str,Wis}`, `ARM_Zeth_*_Cloak`,
  `ARM_Vanity_Body_Refugee_Gray_*`, plus `ARM_*_Body_NN` / `ARM_Shield_NN`
  cosmetic variations. (No *new* magic sets here — those live in GustavDev.)
- **Weapon +75**: `WPN_*_NN` visual variants + stat-specific
  (`WPN_Greatclub_{Con,Dex,Int,Str,Wis}`, `WPN_Longsword_Tanking_150`).
- **Passive +46**: tiered enchantment passives — `ARM_{Stealthy,ExceptionalPlate,
  SuperiorPadding,SuperiorPlate,Ambusher,Balance,BodyAid,Elegant}_{1,10,11}`
  (+`_root`), `MAG_Generic_Leeching_{low,middle,high}(_fire)`,
  `MAG_Reflect_Armor_{low,middle,high}`, `MAG_Monky_Passive_*`, `HP_Buff_low`,
  `CompanionsBond_Extra`, `GOB_PainPriest_Scourge_Passive_Fire_*`.
- **Character, Data, XPData, TreasureTable, Spell_Target (+1:
  `Target_Sting_Imp_Summon`), Spell_Shout**: 0 new entries — value-only edits
  to existing entries (balance tuning, XP curve, loot re-roll; treasure tables
  were reworked "lvl+random based" on 2025-04-17, `74e8a8d`).
- A design note `INFO.md.txt` (CON-scaling table per level/armor tier) lived in
  `Shared/Stats/Generated/Data/` and was **deleted** in `cdbf76a` (2026-10-03).

### Gustav/ (campaign build, late 2023)
- Armor: 0 new entries (tuning only).
- Passive: 167 (whole file is post-baseline) — campaign enchantment passives.
- TreasureTable: 517 tables (whole file post-baseline).

### GustavDev/ (campaign build #2, 2024-07-31 `df09703`; all files are new)
- **Armor 355**: vanilla re-decompile + story/custom items —
  `TWN_BondedByLove_{Husbands,Wifes}Ring`, `TWN_TollCollector_ArmorPart_*` (6-pc
  set), `TWN_ShieldOfWatcher`, `TWN_RegretfulHunter_SoulAmulet`,
  `TWN_NecklaceOfCharming`, `TWN_Tollhouse_TradersRing`,
  `TWN_BootsOfApparentDeath`, `TWN_AasimarSurvivor_HazmatSuit`,
  `MAG_TWN_Surgeon_ParalyzingCritical_Amulet`, `MOO_Ketheric_Armor`.
- **Passive 608**: incl. 18× `TWN_*`, `Dos2_Join_{Drum,Flute,Lute,Lyre,
  Violin,Whistle}` (bardic-instrument join passives).
- **Status_BOOST 1236** (new file): incl. 65× `TWN_*` statuses.
- **TreasureTable 532**, **HealthBoosts.StatusData**.

### SharedDev/ (global build #2, 2024-08)
- Character/Spell_Target existed at baseline (value edits only).
- **New since baseline**: Passive 465 (whole file), Spell_Shout 334,
  Status_BOOST 845 (whole file), TreasureTable 64 tables, XPData variants.

> Caveat: files added *after* the baseline count every entry as "added"; only
> the Shared/* + Gustav/Armor tables above distinguish true additions from
> the original decompile.

## 6. How it actually loads (confirmed with owner, 2026-10-03)

**`Data/Public/` (this repo) is live as-is.** The engine auto-picks up any data
under `Data/Public/` as a direct extension of the game — **no `.pak`, no mod
registration, no build step, no copy.** It sits inside the actual BG3
deployment (not the user-config/mod area), so it is always player-authored
data and is unreachable by normal mods. To override an existing item you place
a file at the same path the original occupies
(`Gustav/Stats/Generated/...`) and reuse the original entry **name**, changing
only the payload lines you care about. Everything is hand-edited text — the
Larian mod tools do not work properly on this Linux install.

**Gustav / GustavX / Shared / SharedDev / GustavDev** as they appear in
`modsettings.lsx` are **Larian-internal content modules** (the ~7 GB game-data
set in this same text format), not user mods — ignore them when identifying
"the mod." The genuine third-party paks (AppData/Mods) are:
`5eSpells`, `UtutsCoreLibrary`, `EncountersOverhaul`,
`EncountersOverhaul5eSpells`, `Teleport_To_You`.
(Extras present but not relied on: ManyMoreMonsters, d20initiative,
enemies_full_rework, extra_encounters_plus, extra_enemies_honour,
configurablepartylimit, noinspirationreroll, flarecommonerclass, Goon's
Library, all-in-one-collector, Automated Summons SE, dynamicsidebar, impui,
musicperformworkaround, ModFixer.)

**Story / goal changes** (level cap, 3 short rests, companion & pet changes, …)
live **outside** the repo, edited in place under
`Data/Mods/{Gustav,GustavDev,GustavX,Shared,SharedDev}/Story/RawFiles/` —
decompiled vanilla story files, also hand-edited, also part of the deployment
(not registered mods). Edited-since-2024 counts: Gustav 253, GustavDev 554,
Shared 122, SharedDev 17, GustavX 8. Not version-controlled here.

### Other on-disk notes
- `Data/Armor.txt` (loose at Data root, mtime 2023-08-21) is **byte-identical**
  to `GustavDev/Stats/Generated/Data/Armor.txt` — a pre-repo leftover; the live
  armor override is the one in the repo. Candidate for deletion.
- `Mods/HealthBoostLocal/`: ScriptExtender Lua mod — **did not work** on this
  Linux install (same mod-tools limitation). Disregard.
- `Mods/HPChaos/`: scrapped, never worked. Disregard.
- Saves: several `__HonourMode` + `Zirini`/`Zhari`/`Zhavi` quicksaves; last
  gold log 2026-08-22/23; game pak updated 2026-09-29 (Patch 8 HotFix 10).

## 7. Status / open items

- The **current repo is the authoritative, complete set** of stat changes
  (owner-confirmed). `HealthBoostLocal` and `HPChaos` are non-functional and
  can be ignored.
- Minor, not yet decided: whether to delete the stale loose `Data/Armor.txt`;
  whether the `honor-mode` branch / `modsettings.lsx` copies are still wanted
  or can be archived.
