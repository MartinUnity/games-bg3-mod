-- Client bootstrap (SE auto-loads BootstrapClient.lua when present). Channel first
-- (same object as the server side), then the announcement toast receiver.
Ext.Require("Shared/Channels.lua")
Ext.Require("Client/AnnounceClient.lua")
Ext.Print("[CHAOS] Chaos Reinforcements client bootstrap loaded")
