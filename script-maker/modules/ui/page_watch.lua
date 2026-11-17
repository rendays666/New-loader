--[[ UI/PAGE_WATCH (Advanced) — rekam pasif: tombol layar yang muncul + pesan server/error game. ]]

return function(D)
    local S, Cfg, A = D.State, D.Config, D.Actions
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("watch", "Watch", true)
    local stack = K.stack(page)

    K.label(stack, "Passive recording: nothing is hooked here. Turn things on, play the game, then create a report from Start or Export.",
        { size = 11, color = T.dim })

    local c1 = K.card(stack, "On-screen buttons")
    K.label(c1, "Records buttons that appear in your PlayerGui (shops, menus, popups). Open the menu in the game after turning this on.",
        { size = 11, color = T.dim })
    K.toggle(c1, "Record on-screen buttons",
        function() return S.uiActive end,
        function(v) A.setUIWatch(v) end,
        { tip = "uiwatch" })
    local btnCount = K.label(c1, "Buttons recorded: 0", { size = 11, color = T.dim })

    local c2 = K.card(stack, "Server messages")
    K.label(c2, "Logs game errors/warnings and the RemoteEvents the server sends to you (server → client).",
        { size = 11, color = T.dim })
    K.toggle(c2, "Listen to server messages",
        function() return S.passiveActive end,
        function(v) A.setPassive(v) end,
        { tip = "passive" })
    local msgCount = K.label(c2, "Messages recorded: 0", { size = 11, color = T.dim })

    local c3 = K.card(stack, "Recorded data")
    K.label(c3, "Clears recorded buttons, messages and game actions. Scan results are kept.",
        { size = 11, color = T.dim })
    K.button(c3, "Clear recorded data", A.clearRuntime, { color = T.bad })

    task.spawn(function()
        while not S.dead do
            local c = A.counts()
            btnCount.Text = ("Buttons recorded: %d"):format(c.buttons)
            msgCount.Text = ("Messages recorded: %d"):format(c.logs)
            task.wait(1)
        end
    end)
end
