# Mob & Chest Drop Chains

How items reach the player through drops, and how our custom items plug in.
Companion to `item-chains.md` (vendor side) and `larian_treasuretables_description.md` (Larian's own format reference).

## 1. Two layers: text vs binary

| Layer | Editable? | What lives there |
|---|---|---|
| **Text stats** (`Data/Public/**/Stats/Generated/`) | Yes | `TreasureTable.txt` (loot pools + probabilities), `Data/Armor.txt` etc. (item definitions) |
| **Binary story/scene data** | No | Which chest in which scene rolls which table, which mob corpse rolls which table, vendor stock assignments, scripted item grants |

Verified: no `Character.txt` entry (vanilla, all layers) contains any `Treasure`/`Inventory`/`Loot`/`Corpse`/`Drop` field, and chest entries (e.g. `DEN_BardChest`) exist **only** in `TreasureTable.txt` — the containers themselves live in binary scene data.

Consequences:
- We **cannot** in text say "this new mob drops X" or "this new chest rolls Y". The encounter→table wiring is fixed by Larian's binary data.
- The **only text lever** is the *content* of existing loot pools: whatever table an encounter/chest/corpse already rolls, we control what can come out of it.
- "Scripted" drops (specific story rewards) and "random low chance pr. encounter" (corpse/chest pools) are both wired in binary; the difference is only whether the rolled table uses `subtable "1,1"` (guaranteed) or a weighted `0,N;1,1` (low chance).

## 2. File format refresher (`TreasureTable.txt`)

```
treasure itemtypes "Common","Uncommon","Rare","Epic","Legendary","Divine","Unique"
new treasuretable "NAME"            // a table; referenced elsewhere as "T_NAME"
new subtable "dropcounts"           // weighted drop-count roll, see §3
StartLevel "7"                      // optional: subtable only active if container level in window
EndLevel "13"
object category "X",F,C,U,R,E,L,D,U // Frequency + 7 rarity-type weights
```

- `object category "T_..."` → roll a *subtable* (nested table). `ST_`-prefixed names are the convention for tables meant to be used only as subtables.
- `object category "I_..."` → drop that item directly (rarity columns unused for concrete items; `Frequency` is the weight).
- Table-level flags exist in the editor (`MinLevelDiff`, `MaxLevelDiff`, `IgnoreLevelDiff`, `UseTreasureGroups`); decompiled files omit them when default.

## 3. `new subtable "x,y"` — drop-count semantics

The string is a list of weighted pairs `"<count>,<weight>"`. On a roll the engine picks one pair by weight and drops that many items from the subtable.

| Spec | Meaning |
|---|---|
| `"1,1"` | always 1 item |
| `"2,1"` | always 2 items |
| `"0,25;1,1"` | 25/26 = 96.2% nothing, **1/26 ≈ 3.8% one item** |
| `"0,5;1,1"` | 1/6 ≈ 16.7% one item |
| `"0,1;1,1"` | 50% one item |
| `"1,3; 2,1"` | 75% one item, 25% two items |

Anti-streak: the engine tracks consumed drop-counts **per shared subtable** — with `"0,1;1,1"` you cannot miss twice in a row; with `"0,25;1,1"` you can (that's the point of the big weight: truly rare). Reusing one shared subtable across many parent tables balances outcomes globally.

## 4. Probability of a specific item

```
P(item) = P(parent table is rolled)
        × P(drop-count ≥ 1 in the subtable)
        × freq(T_pool or item) / Σ freq of all objects in that subtable
        × 1 / (items in pool)        // or recurse into nested tables
```

Example — a generic goblin corpse, player level ≤ 6:

```
corpse rolls GOB_Goblin_Generic                       (binary-wired, 100%)
 → GOB_Goblin_Generic_Common                          100%
   → subtable "0,25;1,1":  T_FOR_Random_Ring freq 5   1/26 × 5/9
     T_Clothes_Magic_Random freq 4                    1/26 × 4/9
 → Clothes_Magic_Random, subtable SL 1–6: 24 items    1/24
P(one specific tier-1 item, per goblin) ≈ 0.0385 × 0.444 × 0.0417 ≈ 0.00071 (0.07%)
```

## 5. The current injection surface for magic clothes

`Clothes_Magic_Random` is **our table** (not in vanilla). We reach every Larian encounter/chest/corpse by re-emitting their tables (decompile → append one subtable block) and adding `T_Clothes_Magic_Random` to it. Verified pattern, e.g. `GOB_Goblin_Generic_Common`:

```diff
 object category "T_ST_Alchemy_Mushroom_Common",2,0,0,0,0,0,0,0
+new subtable "0,25;1,1"
+object category "T_FOR_Random_Ring",5,0,0,0,0,0,0,0
+object category "T_Clothes_Magic_Random",4,0,0,0,0,0,0,0
```

All 25+ parent tables were injected this way. Grouped by roll chance:

**Guaranteed when the table rolls (`"1,1"`)** — fixed/scripted rewards
- `TUT_Mindflayer_Dead`, `TUT_Monster_Mindflayer` (dead mindflayer always drops magic clothes)
- `FOR_DeathOfATrueSoul_TrueSoul`, `FOR_DeathOfATrueSoul_Novice`
- `FOR_Spiders_Cocoon` — actually `"1,3; 2,1"` (75% one / 25% two)

**50%** (`"0,1;1,1"`)
- `FOR_SchoolOgre_Stash_Valuables`, `FOR_UnfortunateGnome_MillCellarChest`, `WLD_CRA_RidgeSecretChest`

**≈33%** (`"0,2;1,1"`) — `TUT_Victim_Generic`

**≈17%** (`"0,5;1,1"`)
- `TUT_Imp_Handaxe`, `TUT_Imp_Dagger`, `TUT_Imp_Scimitar`, `TUT_Imp_Crossbow`, `TUT_Chest_Potions`

**≈3.8%** (`"0,25;1,1"`) — the main "low chance pr. encounter" band
- Corpses: `GOB_Goblin_Generic_Common`, `GOB_Goblin_Generic_Rare` (via `GOB_Goblin_Generic`, also used by `GOB_Goblin_Kid`, `FOR_Village_SleepingBugbear`)
- Chests/stashes: `DEN_BardChest`, `DEN_Entrance_Trade`, `DEN_Weaponsmith_Trade`, `DEN_GoblinHunt_RewardBag`, `DEN_Harpy_HiddenChest`, `FOR_DeathOfATrueSoul_SeluneStash`
- Vendor stock: `ST_DEN_Trader_Ranged_Arrows` (traders may stock one magic clothing, 4%)

**≈2%** (`"0,50;1,1"`) — generic exploration pools (these feed the biggest surface: dozens of area chests/ambushes)
- `Exploration_Minor`, `Exploration_Additional` (Shared layer) — rolled `"1,1"` by `HAG_Swamp_Chest`, `HAG_WoodWoad_Chest`, `PLA_Cave_BanditChest`, `UND_KC_TrappedChasmChest`, `UND_SeluneOutpost_Treasure`, `LOW_Undercity_Ambush_Treasure`, `FOR_Goblin_OverlookChest`, `FOR_VillageFightReward`, ...
- `Exploration_Major` (Shared layer) — same pattern via `HAG_*`, `S_HAV_BuriedChest_02`, `S_TWN_BuriedChest_06`, `S_WYR_BuriedChest_08/09`, `UND_KC_*`, `UND_Tower_SecretCellar_RewardChest`, `GOB_WaterfallChest`, `TUT_BackupCambion_Reward` (`"2,1"`), `Combat_Major`

**Inside `Clothes_Magic_Random`** (Gustav, our table):
- subtable `"1,1"` SL 1–6: 6 Shoes + 6 Boots + 6 Vanity body + 6 Zeth Cloak_1 = 24 tier-1 items
- subtable `"1,1"` SL 7+: 6 Shoes_2 + 6 Boots_2 + 6 Vanity body_2 + 6 Zeth Cloak_2 = 24 tier-2 items

So the "orphaned" vendor wrappers (`EquipmentTrader_BodyArmor_Cloth_{Cloak,Shoes,Boots,Body}_Magic`) are not a bug: cloaks/shoes/boots/body-cloth reach players through the drop surface above; the vendor table only needs the *extra* pool we want to also sell (currently plain body cloth + necklaces).

## 6. Phase 2 (necklaces) — implemented

Done by editing only `Clothes_Magic_Random`; the entire existing injection surface (corpses, chests, exploration pools, vendor stock) carries the necklaces automatically:

1. The 6 `_1` necklaces appended to the existing SL 7+ subtable → 30-item pool (max spread, chosen over separate subtables).
2. New subtable `"1,1"` SL 14+ with the 6 `_2` necklaces.

Because **all eligible subtables roll independently** (see §3 / Example 3 in the Larian doc), at player level 14+ every magic-clothes drop yields **two** items: one from the 30-item SL7+ pool and one guaranteed `_2` necklace. Below 14, the `_1` necklaces simply add to the 30-item pool.

Probability per goblin corpse (level 7–13): 1/26 × 4/9 × 1/30 ≈ 0.00057 per specific necklace, plus the much larger exploration-pool surface at 2–3.8% parent roll.

Caveats:
- Adding items to a shared subtable **dilutes** every existing item in it (1/24 → 1/30). If that matters, use a separate subtable/parent slot instead.
- New *encounter* wiring (a new mob or chest that drops our items) is **not possible in text**; it requires the binary story data we don't edit.
