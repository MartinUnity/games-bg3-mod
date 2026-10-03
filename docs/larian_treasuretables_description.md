# Description

The D:OS 2 treasure system is constructed around Treasure Tables, which are sets of objects (or categories of objects), defined by their stats entries, and the probability to drop these objects. Treasure tables can be nested, so that using one table, you select randomly from several tables. This system is used both for rewards from e.g. killed enemies, and to generate the treasure vendors have for sale.

# Treasure Table Columns

## Name

This column contains the unique ID of the treasure entry that we will use in Glasses in the “Treasure” and “TradeTreasure” fields (for character properties) and the “Inventory” field (for containers). We will also use it to reference other treasure entries. If the name of a table starts with "ST_", it is intended to be used as a subtable to other treasure tables.

## MinLevelDiff and MaxLevelDiff

Each treasure container has a level. This defines the items the treasure will look for. Most items can drop between level 1 and 30 so this is usually not necessary. However, when filled in, it can make a treasure look for and drop items that are lower or higher than its level. For example, if a Treasure Table has “MinLevelDiff = -4” and “MaxLevelDiff = 3”, and a player of Level 10 rolls this table, then items of Levels 6-13 are eligible for drop.

## IgnoreLevelDiff

A treasure table will always try to choose items that are appropriate for the level of its container. Filling in Yes here disables this behaviour, so that the treasure table drops items irrelevant of the level at which they were intended to be dropped.

## UseTreasureGroups

Treasure groups are a system of global balancing of the categories that drop. There is a TreasureGroups table in the Stats editor that you'll need to take a look at for this. There are currently three treasure groups - skillbooks, armour types, and weapon types. In the case of skillbooks, the goal is to make sure that an equal amount of skillbooks of all ability schools are dropped with treasure. As you will see in the TreasureGroups table, all skillbooks types have a weight of 1. This means that the treasure system will do its best to make sure that all skillbook types will drop once before re-starting the cycle. So, if you begin a game and use the console to generate some ST_Skillbook tables, you'll get a skillbook of each ability school once. The same thing happens for armour types and weapon types. The treasure group system is opt-in. In the “UseTreasureGroups” column, you need to set the flag to 1 in order to include your table within the system.

## StartLevel & EndLevel

These fields allow you to disable and enable specific entries in the treasure table depending on level. Specifically, if the container's level is below StartLevel or above EndLevel, that entry will be excluded.

## DropCount

This entry tells the system how many items to choose from the ObjectCategory entry on the same line, and all lines below it with empty DropCount entries. This is a list of possibilities separated by a semicolon. The possibilities are formed as x,y where x is the amount of items that should be picked and y is the chance.

* A negative integer like “-N” means that the Treasure Table uses exactly N instances of the ObjectCategory. This is known as a forced drop, and will ignore level restrictions to get N items if necessary.
* A string of non-negative integers like “n_1,p_1;n_2,p_2;...;n_k,p_k” means that the ObjectCategory can be used n_1, n_2, ... or n_k times. Here, the number n_i will be used with probability p_i/(p_1+p_2+...+p_k). For example, “4,1;5,1;6,2” for “T_ST_ArmorMagic” means that the Treasure Table “ST_ArmorMagic” will be used 4 times with a probability of 1/4, 5 times with a probability of 1/4 and 6 times with a probability of 2/4. The probabilities are decreased when they are successfully rolled. In the example above, if the table rolls 4, then DropCount becomes 4,0;5,1;6,2 for the next roll, meaning that 4 has probability 0, 5 has 1/3 and 6 has 2/3. When all probabilities are zero, they are reset to default values. This way we safeguard against situations where a table with DropCount 0,98;1,2 will drop 1 item five times in a row due to sheer randomness.

## ObjectCategory

This column defines what is actually dropped by the table. This can be one of several things:

1. A reference to a single Item entry by its Stats entry. For this, we use the IDs of items from other stat tables: Object, Weapon, Armor, Potion. To use it, we need to prefix it with “I_”, e.g. for “POTION_Minor_Healing_Potion” it will be “I_POTION_Minor_Healing_Potion”.
2. A reference to another entry from the Treasure Table. This reference copies the contents of that entry to the current entry. To use it, we need to prefix the reference with “T_” (e.g. for “WarriorTrader” it will be “T_WarriorTrader”).
3. A reference to an object category from the Object, Weapon, Armor, or Potion tables (the “ObjectCategory” column there). The probability that a particular item drops from the chosen category is determined by the item’s Priority, which is also set within those tables. Priorities act as weights in their category: for example if Weapon file has 3 stat entries with ObjectCategory Dagger, and first two have Priority 1, while third has Priority 3, then first two have 1/5 chance to drop while the third item has 3/5 chance to drop. Unlike Dropcounts, Priorities do not change during the game in any way.

## Frequency

A Frequency entry determines the chance of an ObjectCategory being selected in its group (i.e. among all of the ObjectCategory entries using the same DropCount entry.

## Item Rarities from Common to Divine

Item rarity represents the probability of adding a rarity modifier to an item, which is a measure of how good, rare, and 'special' it is for its level. They work similarly to frequencies and are also counted and saved.
If ObjectCategory entry is a table (starts with “T_”), then the corresponding Item Rarity will override the rarity of the table. To prevent override, simply leave all rarity counters empty.

## Comment

A field to leave comments on the purpose & correct use of a table.

# Examples

Below are a few examples to demonstrate the use of the treasure tables:

## Example 1

|Name|MinLevelDiff|MaxLevelDiff|StartLevel|EndLevel|DropCount|ObjectCategory|Frequency|
|----|------------|------------|----------|--------|---------|--------------|---------|
|    |            |            |          |        |10,1     |Ingredient    |1        |
|    |            |            |          |        |0,3;1,1;2,1|Sword       |1        |
|    |            |            |          |        |-1       |Dagger        |1        |
|    |            |            |          |        |0,1;1,1;2,1;3,1;4,1|Painting|3    |
|    |            |            |          |        |         |Precious      |1        |
|    |            |            |          |        |         |T_ST_Dogs     |1        |
|    |            |            |          |        |0,1      |Food          |1        |

On the initial roll, the above table:

* Will always spawn 10 items of the Ingredient category (x,y is 10,1: amount is 10, chance is 1 out of 1 because that’s the only possibility)
*  Has 3 out of 5 chance to drop nothing (0,3 and total chance is 3+1+1)

* Has 1 out of 5 chance to drop 1 item of the Sword category (1,1 and total chance is 3+1+1)
* Has 1 out of 5 chance to drop 2 item of the Sword category (2,1 and total chance is 3+1+1)

* Will be forced to spawn something of the Dagger category, ignoring level restrictions if necessary.
* Has 1 out of 5 chance to drop nothing (0,1 and total chance is 1+1+1+1+1)

* Has 1 out of 5 chance to drop something from Painting OR Precious OR T_ST_Dogs (1,1 and total chance is 1+1+1+1+1)
* Has 1 out of 5 chance to drop two things from Painting OR Precious OR T_ST_Dogs (2,1 and total chance is 1+1+1+1+1)
* Has 1 out of 5 chance to drop three things from Painting OR Precious OR T_ST_Dogs (3,1 and total chance is 1+1+1+1+1)
* Has 1 out of 5 chance to drop four things from Painting OR Precious OR T_ST_Dogs (4,1 and total chance is 1+1+1+1+1)

* In the last case, the subtable ST_Dogs will go over its own possibilities if it is selected. If the subtable ST_Dogs itself has a DropCount entry that says 5,1, and it gets selected once, it will drop 5 items.
* Will _never_ drop any Food.
* The tables has a greater chance of dropping Paintings than it does of dropping something Precious or something from the ST_Dogs table. It will actually be chosen 3 out of 5 times, because is Frequency is 3 and the total of Frequencies for its entire group (i.e. the Painting, Precious and T_ST_Dogs entries) is 3+1+1=5.

After the initial roll, the selected DropCounts will be removed. If the table drops 2 Swords this time, it won't do so again until it has dropped 1 Sword once and no Swords thrice.

## Example 2

|DropCount|ObjectCategory|Frequency|Common|Uncommon|Rare|Epic|Legendary|
|---------|--------------|---------|------|--------|----|----|---------|
|5,1      |T_ST_WeaponNormal|1     |3     |1       |    |1   |         | 	
|3,1      |T_ST_ArmorNormal |1     |2     |        |    |    |1        |
|2,1      |T_ST_RingAmuletBeltNormal|1|1  |        |1   |1   |         | 	
|1,1      |Trader Gold      |1     |      |        |    |    |         | 					

The above table will:

* Roll on the ST_WeaponNormal table five times. The resulting items have a 3/5 chance to be Common, 1/5 chance to be Uncommon, and a 1/5 chance to be Epic.
* Roll on the ST_ArmorNormal table three times. The resulting items have a 2/3 chance to be Common, and 1/3 chance to be Legendary.
* Roll on the ST_RingAmuletBeltNormal table twice times. The resulting items have a 1/2 chance to be Rare, and a 1/2 chance to be Epic.
* Create 1 object of the Trader Gold category.

## Example 3

|Name|MinLevelDiff|MaxLevelDiff|IgnoreLevelDiff|UseTreasureGroups|StartLevel|EndLevel|DropCount|ObjectCategory|
|----|------------|------------|---------------|-----------------|----------|--------|---------|--------------|
|Animals_Owl|     |            |               |                 |1         |12      |1,1      |I_Loot_Feather_A|
|                 |            |               |                 |1         |12      |1,1      |I_Loot_Essence_Air_A|
|                 |            |               |                 |13        |        |1,1      |I_Loot_Feather_A_Fancy|
|                 |            |               |                 |13        |        |1,1      |I_Loot_Essence_Air_Step2_A|


Looking at this table, we can see that the following will happen if a character kills an owl:

* If they are level 1 to 12, they will get 1 Feather, provided Loot_Feather_A is not restricted from dropping at their level.
* If they are level 1 to 12, they will get 1 Air Essence, provided Loot_Essence_Air_A is not restricted from dropping at their level.
* If they are level 13 or above, they will get 1 Fancy Feather, provided Loot_Feather_A_Fancy is not restricted from dropping at their level.
* If they are level 13 or above, they will get 1 Step 2 Air Essence (i.e. a higher-tier Air Essence), provided Loot_Essence_Air_Step2_A is not restricted from dropping at their level.

# On Well-Balanced Treasure

There are a few practices that will ensure a more even spread of your treasure:

* Avoid using large numbers for Frequency and DropCount. If you have a dropcount of 0,50;1,50, then on average the player has a 1/2 chance of getting something, but they may have to wait until the 51st time they search a container with that treasure table until they actually do. In fact, they may even find something 50 times in a row, then nothing 100 times in a row (with the Dropcount resetting halfway through), then something 50 times in a row again. If the Dropcount is 0,1;1,1 they won't have to wait more than 2 tries between finding something.
* Try to use existing subtables to take advantage of the fact the game keeps track of the DropCount within them. Three separate tables, each of which drops Diamonds and Eyeballs independently, may wind up each dropping an Eyeball, whereas if they use one shared Eyeball/Diamond subtable, the player will get a balanced amount of Diamonds and Eyeballs between them.

