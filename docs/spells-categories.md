# Spells - Healer 

## Cleric

### Healing spells (Prio 1)

|Spell|Pri|lvl|
|-----|---|---|
|Cure Wounds|1|1|
|Healing Word|2|1|
|Mass Healing Word|1|3|
|Mass Cure Wounds|1|5|
|Heal|1|6|

### Buff spells (prio 2)

|Spell|Pri|lvl|
|-----|---|---|
|Bless|1|1|
|Aid|3|2|
|Shield of Faith|2|1|
|Warding Bond|2|2|
|Freedom of Movement|3|4|

### Summoning + Debuff + damage spells (prio 3)

|Spell|Pri|lvl|
|-----|---|---|
|Bane|2|1|
|Hold Person|1|2|
|Spiritual Weapon|1|2|
|Guiding Bolt|2|1|
|Command|2|1|
|Spirit Guardians|2|3|
|Flame Strike|2|5|
|Insect Plague|2|5|

### Cantrips

|Spell|Pri|lvl|
|-----|---|---|
|Sacred Flame|2|0|
|Toll the Dead|1|0|

## Druid

### Healing spells (Prio 1)

|Spell|Pri|lvl|
|-----|---|---|
|Cure Wounds|1|1|
|Healing Word|2|1|
|Mass Cure Wounds|1|5|
|Heal|1|6|

### Buff + summoning spells (prio 2)

|Spell|Pri|lvl|
|-----|---|---|
|Freedom of Movement|3|4|
|Flaming Sphere|2|2|
|Conjure Minor Elemental|2|4|
|Conjure Woodland Being|2|4|
|Conjure Elemental|2|5|

### Debuff + damage spells (prio 3)

|Spell|Pri|lvl|
|-----|---|---|
|Heat Metal|1|2|
|Hold Person|2|2|
|Ice Knife|1|1|
|Thunderwave|2|1|
|Spike Growth|3|2|
|Moonbeam|1|2|
|Call Lightning|1|3|
|Blight|3|5|
|Ice Storm|1|4|
|Insect Plague|2|5|

### Cantrips

|Spell|Pri|lvl|
|-----|---|---|
|Thorn Whip|1|0|
|Poison Spray|2|0|

---

## Implementation notes (v3.46, for extending this doc)

Rolled by `tools/gen_teams.py` (`SPELL_CATS`/`CANTRIPS`/`roll_spell_kit`):
slot-by-slot, priority groups cycle prio1→prio2→prio3→loop; within a group the
Pri column weights the pick 6/3/1; one spell known per slot; every character
level rolls independently and every template regen re-rolls all stacks
(`CHAOS_SEED=<int>` pins the rolls if you ever want a reproducible build).

Stat-id mapping used (all validated against the vanilla pak census - spell files
from Shared.pak/Gustav.pak/GustavX.pak, incl. SharedDev/GustavDev/Honour layers):
Cure Wounds=`Target_CureWounds`, Mass Cure Wounds=`Target_CureWounds_Mass`,
Mass Healing Word=`Shout_HealingWord_Mass`, Heal=`Target_Heal`, Aid=`Shout_Aid`,
Warding Bond=`Target_WardingBond`, Freedom of Movement=`Target_FreedomOfMovement`,
Command=`Target_Command_Halt_NPC` (the AI-friendly entry), Spiritual
Weapon=`Target_MAG_SpiritualWeapon`, Flame Strike=`Target_FlameStrike`, Insect
Plague=`Target_InsectPlague`, Toll the Dead=`Target_TollTheDead`, Flaming
Sphere=`Target_FlamingSphere`, Conjure Woodland Beings=`Target_ConjureWoodlandBeings`,
Conjure Elemental=`Target_ConjureElemental_Elemental_Fire_NPC`, Ice
Knife=`Projectile_IceKnife`, Ice Storm=`Target_IceStorm`, Blight=`Target_Blight`,
Moonbeam=`Target_Moonbeam`, Heat Metal=`Target_HeatMetal`, Poison
Spray=`Projectile_PoisonSpray`.

Not in BG3 vanilla (dropped from the roll): **Conjure Minor Elemental** (only
exists folded into the Conjure Elemental container spell).

For the upcoming full-caster (wizard/sorcerer/warlock/bard), half-caster
(paladin/ranger) and one-third (eldritch knight/arcane trickster) lists: just add
the same `### Group (prio N)` + `|Spell|Pri|lvl|` tables here - I mirror them into
the generator's `SPELL_CATS`, and every spell name gets validated against the
vanilla census before it's baked into templates.
