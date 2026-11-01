-- Chaos announcement receiver (CLIENT side). Ext.Require'd from BootstrapClient.lua.
-- Listens on the shared net channel (Shared/Channels.lua) and shows a small Dear-ImGui
-- toast near the top of the screen: "leader joined", "wild group formed", etc.
-- API vocabulary cribbed from the working ManyMoreMonsters pak on this install:
--   Ext.IMGUI.NewWindow(title) / win:AddText(str) / obj:SetColor("Text", {r,g,b,a})
--   Ext.IMGUI.GetViewportSize() -> {w, h}; everything below is pcall-guarded and the
-- outcome logged to ChaosReinforcements_client.log (profile "Script Extender" folder).

local LINES = {}
local function clog(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    LINES[#LINES + 1] = "[CHAOS-c] " .. table.concat(parts, " ")
    pcall(function () Ext.IO.SaveFile("ChaosReinforcements_client.log", table.concat(LINES, "\n")) end)
end

local TOAST_MS = 5000   -- how long a toast stays on screen
local current = nil     -- only one toast at a time; a new one replaces the old

local function toast(text)
    -- out with the old
    if current then pcall(function () current:Destroy() end) current = nil end

    local ok, err = pcall(function ()
        local win = Ext.IMGUI.NewWindow("ChaosReinforcements_toast")
        current = win
        -- minimal chrome (flag fields: probe assumptions, logged if refused)
        for _, k in ipairs({ "NoTitleBar", "NoResize", "NoMove", "NoScrollbar",
                             "NoCollapse", "NoSavedSettings", "AlwaysAutoResize" }) do
            local okF = pcall(function () win[k] = true end)
            if not okF then clog("toast: flag refused:", k) end
        end
        local t = win:AddText(text)
        t:SetColor("Text", { 1.0, 0.82, 0.36, 1.0 })   -- warm gold, like combat log highlights
        -- top-center placement (approximate: ImGui can't auto-center).
        -- win.Position = {x,y} is REFUSED by this IMGUI build (logged for weeks);
        -- the supported call is win:SetPos(vec2) per ExtIdeHelpers ExtuiWindowBase.
        local okV, vp = pcall(Ext.IMGUI.GetViewportSize)
        if okV and type(vp) == "table" and vp[1] then
            local w = math.min(600, #text * 9)   -- crude width estimate, capped
            local okP = pcall(function () win:SetPos({ vp[1] / 2 - w / 2, vp[2] * 0.10 }) end)
            if not okP then
                clog("toast: SetPos refused")
            else
                -- after one rendered frame the window knows its real size; re-center
                pcall(Ext.Timer.WaitFor, 100, function ()
                    local okS, size = pcall(function () return win.Size end)
                    if okS and type(size) == "table" and size[1] and size[1] > 0 then
                        pcall(function () win:SetPos({ vp[1] / 2 - size[1] / 2, vp[2] * 0.10 }) end)
                        clog("toast recentered, real width", tostring(size[1]))
                    end
                end)
            end
        end
    end)
    if not ok then
        clog("toast FAILED:", tostring(err))
        return
    end
    clog("toast shown:", text)

    -- auto-hide; Ext.Timer.WaitFor client-side is assumed (server-proven) - pcall'd
    local okT = pcall(Ext.Timer.WaitFor, TOAST_MS, function ()
        if current then pcall(function () current:Destroy() end) current = nil end
    end)
    if not okT then clog("toast: client timer refused - window stays until closed manually") end
end

if Channels and Channels.Announce then
    Channels.Announce:SetHandler(function (text, user)
        toast(tostring(text))
    end)
    clog("AnnounceClient.lua loaded, listening on ChaoSAnnounce channel")
else
    clog("AnnounceClient.lua loaded but NO CHANNEL (Shared/Channels.lua required first?)")
end
