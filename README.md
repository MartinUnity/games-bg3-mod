# BG3 'mod'

Clone this repo as `Data/Public` inside the BG3 install (Steam -> right-click game ->
Manage -> Browse Local Files -> `Data`). Editing game files directly instead of using
.pak mods keeps achievements alive for the stats-side changes; the Script Extender
feature (below) ships as one pak via `tools/pack_mod.sh` and does flag saves as modded.

## The 10 biggest things implemented

- **Chaos reinforcements engine** (Script Extender Lua mod, the centrepiece): ongoing fights get surprise reinforcement waves - level-budgeted, stacking spawn chance, faction-correct, in any encounter.
- **Class-built squads, not stat blocks**: mobs are composed as real 5e builds - fighter, barbarian, monk, rogue, paladin, ranger, cleric, druid, bard, wizard, sorcerer, warlock, hexblade (class-gated ones only appear at party level 5+).
- **Real class features**: spell slots + spell kits, two-weapon fighting, Great Weapon Fighting/Master, divine smites, wild shape, monk flurry, eldritch blast ladder, hexblade charisma melee.
- **Rolled spell kits**: cleric/druid known spells are re-rolled every level at template generation, weighted by a priority design (`docs/spells-categories.md`) - two lvl-6 clerics never share a toolkit.
- **Spell registry gate** (`tools/spell_registry.py`): every spell we assign is validated by game id, real BG3 spell level and class list, so wrong-class spells can never reach a mob.
- **Level-tiered gear**: weapon/armor quality bands follow level (plate only at 8+ with proficiency), healers always carry 1-h + shield, humanoids get potions/consumables - and they actually drink them (in-game verified).
- **Bosses and pack leaders**: packs roll a leader (~10%), leaders/bosses get capped +1 magic gear; low-level parties are protected by level ceilings.
- **Race-coherent spawns**: a goblin ambush reinforces with goblins, a drow patrol with drow - one donor race per wave, matching the fight.
- **Placement smarts**: never spawns at a campsite, quiet windows after save-loads, no false-aggro fizzles, orphaned/over-level spawns are cleaned up on a retry ladder.
- **Old-school balance tweaks still live**: 10x carry weight, 3 short rests, level cap 50 with tuned XP curves, custom armors/weapons/passives, buffed pets and companions.

Testing in-game: console commands `!chaos`, `!chaos_status`, `!chaos_wolf`, `!chaos_root`,
`!chaos_force` (see `docs/console-commands.md`); details and design notes in `docs/`.
