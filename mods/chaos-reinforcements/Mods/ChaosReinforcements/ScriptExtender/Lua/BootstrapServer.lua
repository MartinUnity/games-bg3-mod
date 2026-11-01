-- Server bootstrap. Probe.lua stays in the pak as the proven reference implementation but is
-- NOT required anymore (both listeners would double-spawn).
-- Require order matters: Common (log + shared helpers) -> CreatureDB (CHAOS_DB) -> Equip
-- -> Flavor -> Toggle (CHAOS_STATE, before the engines read it) -> Chaos (reinforcement
-- engine) -> Wild (standing world encounters).
Ext.Require("Shared/Channels.lua")
Ext.Require("Server/Common.lua")
Ext.Require("Server/CreatureDB.lua")
Ext.Require("Server/TeamTemplates.lua")
Ext.Require("Server/Equip.lua")
Ext.Require("Server/Flavor.lua")
Ext.Require("Server/Toggle.lua")
Ext.Require("Server/Chaos.lua")
Ext.Require("Server/Wild.lua")
Ext.Print("[CHAOS] Chaos Reinforcements bootstrap loaded")
