-- Server bootstrap. Probe.lua stays in the pak as the proven reference implementation but is
-- NOT required anymore (both listeners would double-spawn).
-- Require order matters: Common (log + constants) -> CreatureDB (CHAOS_DB) -> Equip -> Flavor -> Chaos.
Ext.Require("Server/Common.lua")
Ext.Require("Server/CreatureDB.lua")
Ext.Require("Server/Equip.lua")
Ext.Require("Server/Flavor.lua")
Ext.Require("Server/Chaos.lua")
Ext.Print("[CHAOS] Chaos Reinforcements bootstrap loaded")
