-- Server bootstrap. Probe.lua stays in the pak as the proven reference implementation but is
-- NOT required anymore (both listeners would double-spawn); Chaos.lua is the product path.
-- CreatureDB.lua (generated CHAOS_DB, 685 creatures in 14 type groups) MUST load before Chaos.
Ext.Require("Server/CreatureDB.lua")
Ext.Require("Server/Chaos.lua")
Ext.Print("[MARTIN] MARTIN_MoreMobs bootstrap loaded")
