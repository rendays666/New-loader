--[[ UI/PAGE_EXPORT (Advanced) — semua laporan (simpan .txt / salin) dan potongan data. ]]

return function(D)
    local S, Cfg, A = D.State, D.Config, D.Actions
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("export", "Export", true)
    local stack = K.stack(page)

    local reports = K.card(stack, "Reports")
    K.label(reports, "Smart = most useful, medium size. Full = everything, can be large. Both include diagnostics. Missing a scan? It runs automatically.",
        { size = 11, color = T.dim })
    local g = K.grid(reports, 2, 32)
    K.button(g, "Save smart", function() A.report("smart", "save") end, { color = T.accent, tip = "SMART" })
    K.button(g, "Copy smart", function() A.report("smart", "copy") end, { tip = "SMART" })
    K.button(g, "Save full", function() A.report("full", "save") end, { color = T.accent, tip = "FULL" })
    K.button(g, "Copy full", function() A.report("full", "copy") end, { tip = "FULL" })

    local pieces = K.card(stack, "Copy a single part")
    K.label(pieces, "* needs scan results first.", { size = 11, color = T.dim })
    local gp = K.grid(pieces, 2, 30)
    local items = {
        { "MECH", "Mechanics *" }, { "INDEX", "Script index *" }, { "PATHS", "All paths *" },
        { "REMOTES", "Remotes list" }, { "TREE", "Game tree" }, { "CONFIG", "Config values" },
    }
    for _, it in ipairs(items) do
        K.button(gp, it[2], function() A.copy(it[1]) end, { tip = it[1], ts = 11 })
    end
end
