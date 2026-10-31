-- Net channels - required by BOTH BootstrapServer.lua and BootstrapClient.lua
-- (the doc + proven ManyMoreMonsters pattern: create the same channel in both contexts).
Channels = {}

-- server pushes announcement text; client shows an IMGUI toast
Channels.Announce = Ext.Net.CreateChannel(ModuleUUID, "ChaosAnnounce")
