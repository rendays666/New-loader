--[[ UI/PAGE_START — halaman pertama (Simple + Advanced). Tiga langkah: Scan → Record (opsional) → Report. ]]

return function(D)
    local S, Cfg, A = D.State, D.Config, D.Actions
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("start", "Start", false)
    local stack = K.stack(page)

    K.label(stack, "Three easy steps: scan the game, optionally record what you do in it, then create a report.",
        { size = 11, color = T.dim })

    -- Step 1
    local c1 = K.card(stack, "1 · Scan the game")
    K.label(c1, "Reads the scripts of the game. Most reports need this. Big games can take up to a minute.",
        { size = 11, color = T.dim })
    local g1 = K.grid(c1, 2, 30)
    K.button(g1, "Scan game", A.scan, { color = T.good, tip = "SCAN" })
    K.button(g1, "Stop", A.stopScan, { color = T.bad, tip = "STOP" })
    local scanned = K.label(c1, "Scripts scanned: 0", { size = 11, color = T.dim })

    -- Step 2
    local c2 = K.card(stack, "2 · Record game actions (optional)")
    K.label(c2, "Turn it on, then do the action in the game once (for example press Buy). The report will include the exact calls the game sent.",
        { size = 11, color = T.dim })
    K.toggle(c2, "Record game actions",
        function() return S.capturing end,
        function(v) A.setCapture(v) end,
        { tip = "capture" })
    local recorded = K.label(c2, "Recorded calls: 0", { size = 11, color = T.dim })

    -- Step 3
    local c3 = K.card(stack, "3 · Create report")
    K.label(c3, "Save writes a .txt file to your executor's workspace folder. Copy puts it on the clipboard. If you have not scanned yet, the scan runs first.",
        { size = 11, color = T.dim })
    local g3 = K.grid(c3, 2, 32)
    K.button(g3, "Save report", function() A.report("smart", "save") end, { color = T.accent, tip = "SMART" })
    K.button(g3, "Copy report", function() A.report("smart", "copy") end, { tip = "SMART" })

    -- Petunjuk mode
    local hint = K.card(stack, nil)
    local hintLbl = K.label(hint, "", { size = 11, color = T.dim })
    UI.onMode(function(mode)
        hintLbl.Text = (mode == "simple")
            and "Want more control? Tap \"Mode: Simple\" at the top to switch to Advanced (choose scan places, remote spy with replay/block, full reports)."
            or "Advanced mode is on. Tabs: Scan (places and options), Actions (remote spy), Watch (buttons and server messages), Export (all reports), Settings."
    end)
    hintLbl.Text = (S.mode == "simple")
        and "Want more control? Tap \"Mode: Simple\" at the top to switch to Advanced (choose scan places, remote spy with replay/block, full reports)."
        or "Advanced mode is on. Tabs: Scan (places and options), Actions (remote spy), Watch (buttons and server messages), Export (all reports), Settings."

    -- Penghitung live
    task.spawn(function()
        while not S.dead do
            local c = A.counts()
            scanned.Text = ("Scripts scanned: %d"):format(c.scripts)
            recorded.Text = ("Recorded calls: %d   ·   Buttons: %d"):format(c.calls, c.buttons)
            task.wait(1)
        end
    end)
end
