--[[ UI/PAGE_SETTINGS (Advanced) — mode, info executor, bantuan singkat, unload. ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME
    local env = (getgenv and getgenv()) or _G

    local page = UI.addPage("settings", "Settings", true)
    local stack = K.stack(page)

    local mode = K.card(stack, "Mode")
    K.label(mode, "Simple hides the technical tabs. Advanced shows everything. Your choice is remembered until you leave the game.",
        { size = 11, color = T.dim })
    K.button(mode, "Switch to Simple mode", function() UI.setMode("simple") end, { color = T.accent })

    local info = K.card(stack, "This executor")
    K.label(info, "Version: " .. D.version, { size = 11 })
    K.label(info, "Executor: " .. D.Util.executorName(), { size = 11 })
    local sup = D.Hook.supports()
    K.label(info, "Stealth recording (hookfunction): " .. (sup.hk2 and "supported" or "NOT supported"),
        { size = 11, color = sup.hk2 and T.good or T.bad })
    K.label(info, "Namecall recording (hookmetamethod): " .. (sup.hk1 and "supported" or "NOT supported"),
        { size = 11, color = sup.hk1 and T.good or T.bad })
    local readSrc = (type(decompile) == "function") and "yes" or "no"
    K.label(info, "decompile available: " .. readSrc, { size = 11, color = T.dim })

    local help = K.card(stack, "Quick help")
    K.label(help, "• Nothing recorded? Open Actions and try another Method (Stealth ↔ Namecall).", { size = 11, color = T.dim })
    K.label(help, "• Some games kick or crash on hooks. Use Scan only (no recording) in that case.", { size = 11, color = T.dim })
    K.label(help, "• Replay really sends the call to the server again. Use it carefully.", { size = 11, color = T.dim })
    K.label(help, "• Reports end with DIAGNOSTICS: send the whole file to an AI if something fails.", { size = 11, color = T.dim })
    K.label(help, "• Tap the ? on any button for what it does. PC: right-click works too.", { size = 11, color = T.dim })
    K.label(help, "• RightShift (PC) hides or shows this window.", { size = 11, color = T.dim })

    local ll = K.card(stack, "Loader log")
    K.label(ll, "The log that was shown while Script Dumper was loading (versions, module sizes, errors). Send it when something fails to load.",
        { size = 11, color = T.dim })
    K.button(ll, "Copy loader log", function()
        if D.LoaderLog then
            D.Output.copyText(D.LoaderLog.report(false), "loader log")
        else
            UI.setStatus("No loader log available.")
        end
    end, { color = T.accent })

    local unload = K.card(stack, "Unload")
    K.label(unload, "Stops recording and removes this window. Hooks already installed stay in memory but become inactive.",
        { size = 11, color = T.dim })
    K.button(unload, "Unload Script Dumper", function()
        env.__DUMPER_PREV = nil
        D.Shutdown()
    end, { color = T.bad })
end
