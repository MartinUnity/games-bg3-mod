-- Server bootstrap. Probe.lua stays in the pak as the proven reference implementation but is
-- NOT required anymore (both listeners would double-spawn); Chaos.lua is the product path.
Ext.Require("Server/Chaos.lua")
Ext.Print("[MARTIN] MARTIN_MoreMobs bootstrap loaded")
