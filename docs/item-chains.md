# How a stat item reaches the player (item → treasure table → vendor / drop)

Reference chain: the Zeth stat cloaks (`ARM_Zeth_*_Cloak_*`) and the new Zeth stat
necklaces (`ARM_Zeth_*_Necklace_*`).

## 1. The layers

All `Stats/Generated` files with the same name across the four build dirs
(`Gustav/`, `GustavDev/`, `Shared/`, `SharedDev/`) are **one logical table** — the
engine merges them by entry name. An entry defined in `Gustav/Stats/Generated/TreasureTable.txt`
can be referenced as `T_...` from `Shared/Stats/Generated/TreasureTable.txt` and vice
versa. Vanilla (game-pak) entries are the base layer under all of these; redefining a
vanilla entry name in our files overrides it (that is the whole mod's mechanism).

Reference copy of the vanilla unpack: `bg3-vanilla-data/` (repo-local, do not commit).

## 2. Item entry (Armor.txt)

`Shared/Stats/Generated/Data/Armor.txt`, modeled on the cloaks:

```
new entry "ARM_Zeth_STR_Necklace_1"
type "Armor"
using "_Amulet_Magic"                      <- base template (vanilla, also: _Back_Magic, _Ring_Magic, ...)
data "RootTemplate" "<mesh UUID>"          <- which model/texture is worn
data "ValueLevel" "7"                      <- item power level (price/value scaling)
data "Rarity" "Uncommon"                   <- Uncommon = +1, Rare = +2
data "Boosts" "Ability(Strength, 1)"       <- the actual effect; no separate Passive needed
```

`Boosts` grammar used in this mod: `Ability(<Str|Dex|Con|Int|Wis|Cha>, <n>)`,
`Skill(<name>, <n>)`, `ProficiencyBonus(SavingThrow, <Ability>)`,
`UnlockSpell(<spell name>)`. Multiple boosts are `;`-separated.

For plain stat boosts **no Passive.txt entry is needed** — `Boosts` carries it.
Passives are only needed for conditional/triggered effects.

## 3. Treasure tables (TreasureTable.txt)

```
new treasuretable "Name"                   <- referenced elsewhere as T_Name
new subtable "<drop spec>"                 <- "1,1" = roll 1 item (100%); "0,25;1,1" = 1/25 chance to roll 1
StartLevel "7"                             <- optional, player-level window for this subtable
EndLevel "13"                              <- optional
object category "<ref>",<weight>,0,0,0,0,0,0,0
```

- `<ref>` = `I_<ItemEntryName>` (a concrete item), `T_<OtherTable>` (nested table),
  or a raw ObjectCategory name.
- The first number after the name is the **weight** (relative probability inside the
  subtable). The 7 zeros are rarity flags (Common…Unique) — always `0` in this mod.

### Table naming conventions (user-added)

| Prefix / name | Meaning |
|---|---|
| `Clothes_Variation_<slot>_Magic_<tier>` | flat pool of the 6 attribute variants of one tier |
| `Clothes_Magic_<slot>_Random_<tier>` | wrapper pointing at one variation pool (drop side) |
| `ST_ClothArmor_<slot>` | vendor-side level-gated selector (`ST_` = subtable per Larian convention) |
| `EquipmentTrader_BodyArmor_Cloth_<slot>_Magic` | per-slot vendor wrapper (single subtable → ST_ table) |
| `Clothes_Magic_Random` (in Gustav/) | the "giga-random" pool mixed into mob drops |

### The full chain (necklaces)

```
VENDOR (vanilla equipment trader, reads table "EquipmentTrader_BodyArmor_Magic"
       via its Treasure property set in the binary Story data)
  └─ EquipmentTrader_BodyArmor_Magic            Shared/TreasureTable.txt (vanilla name, user-extended)
       └─ T_EquipmentTrader_BodyArmor_Cloth_Necklace_Magic   (user wrapper)
            └─ T_ST_ClothArmor_Necklace                       (StartLevel 7 / 14 gating)
                 ├─ (lvl 7-13)  T_Clothes_Magic_Necklace_Random_1
                 │     └─ T_Clothes_Variation_Necklace_Magic_1
                 │          ├─ I_ARM_Zeth_STR_Necklace_1 ... I_ARM_Zeth_CHA_Necklace_1
                 └─ (lvl 14+)   T_Clothes_Magic_Necklace_Random_2
                       └─ T_Clothes_Variation_Necklace_Magic_2
                            ├─ I_ARM_Zeth_STR_Necklace_2 ... I_ARM_Zeth_CHA_Necklace_2

MOB DROP (phase 2, cloaks already wired):
  GOB_Goblin_Generic_Common / Exploration_Minor / Exploration_Major / ...
    └─ [subtable "0,25;1,1"  i.e. 1/25 chance] T_Clothes_Magic_Random     (Gustav/)
         ├─ (StartLevel 1-6)  I_ARM_Zeth_*_Cloak_1, I_FOR_*, I_ARM_Vanity_*_1  (+ necklaces, phase 2)
         └─ (StartLevel 7+)   I_ARM_Zeth_*_Cloak_2, I_FOR_*_2, I_ARM_Vanity_*_2
```

Level gating for vendors comes from the `StartLevel`/`EndLevel` lines inside the
`ST_ClothArmor_*` subtables — the vendor re-rolls the table against the party level,
so the same vendor sells tier 1 at lvl 7 and tier 2 from lvl 14.

## 4. Vendor wiring details

- The in-game "equipment trader" character gets `Treasure` =
  `EquipmentTrader_BodyArmor_Magic` (and the other `EquipmentTrader_*` tables) from
  the **binary Story data** (goals/`.lsf`) — that part is vanilla and not text-editable.
- The only text-level lever is the *content of those tables*: the user extends the
  vanilla `EquipmentTrader_BodyArmor_Magic` by adding `object category "T_..."` lines.
  That is how the cloth armor and shields currently reach the vendor.
- To sell a new slot: create the wrapper table, then add one subtable line to
  `EquipmentTrader_BodyArmor_Magic`.

## 5. Bugs found & fixed in the cloth chain (2026-10-03)

1. **Fixed:** `ST_ClothArmor_Cloak` referenced `T_Clothes_Magic_Cloak_Random` and
   `ST_ClothArmor_Body` referenced `T_Clothes_Magic_Body_Random` — tables that never
   existed (only the `_1`/`_2` variants do). Both now point at `_Random_1` / `_Random_2`
   with StartLevel windows (Cloak 8–12/12+, Body 3–8/8+).
2. **Fixed:** the "Body" vendor wrapper was misnamed
   `EquipmentTrader_BodyArmor_Cloth_Boots_Magic` (duplicate of the Boots wrapper,
   silently overwriting it). Renamed to `..._Cloth_Body_Magic`.
3. **Still open (needs user decision):** the per-slot vendor wrappers
   `EquipmentTrader_BodyArmor_Cloth_{Cloak,Shoes,Boots,Body}_Magic` are **orphaned** —
   only `T_EquipmentTrader_BodyArmor_Cloth_Magic` (plain body) is added to
   `EquipmentTrader_BodyArmor_Magic`. So cloaks/shoes/boots/body-stat-armor currently
   reach the player **only via mob drops**, never via the vendor. To vendor-sell them,
   add one subtable per wrapper to `EquipmentTrader_BodyArmor_Magic` (the necklace
   wrapper already is).

Validator note: ~40 `I_` refs (e.g. `I_OBJ_Scroll_GuidingBolt`,
`I_ARM_Amulet_Necklace_A_Bronze_A`, `I_I_OBJ_Candle`) are **already dangling in
vanilla** — Larian dead code, harmless. The script downgrades those to warnings.

## 6. Necklace spec (implemented 2026-10-03)

- 12 items in `Shared/Stats/Generated/Data/Armor.txt` (after the cloak block):
  `ARM_Zeth_{STR,DEX,CON,WIS,INT,CHA}_Necklace_1` (+1, Uncommon, ValueLevel 7) and
  `_2` (+2, Rare, ValueLevel 14), `using "_Amulet_Magic"`.
- Visuals: 12 distinct vanilla amulet meshes — tier 1 bronze/silver, tier 2
  silver-purple/pearl/gold (UUIDs from vanilla `ARM_Amulet_Necklace_*` entries).
- Tables added to `Shared/Stats/Generated/TreasureTable.txt` mirroring the cloak layout:
  `Clothes_Variation_Necklace_Magic_1/2`, `Clothes_Magic_Necklace_Random_1/2`,
  `ST_ClothArmor_Necklace` (lvl 7–13 / 14+), `EquipmentTrader_BodyArmor_Cloth_Necklace_Magic`,
  plus one subtable line inside vanilla `EquipmentTrader_BodyArmor_Magic`.
- Phase 2 (mob drops): add the 6 `_1` items to the `StartLevel "7"` subtable of
  `Clothes_Magic_Random` (Gustav/) and the 6 `_2` items to a new `StartLevel "14"`
  subtable.

## 7. Validation

`tools/validate_treasure.py` — parses all 4 layer TreasureTable.txt + Data tables and
reports: duplicate entry names within a file, and `I_`/`T_` references that resolve
neither in the repo nor (with `--vanilla bg3-vanilla-data`) in the vanilla baseline.
