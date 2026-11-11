--[[ OUTPUT — copy ke clipboard & simpan ke file workspace.
     D.Output.copyText(text, label) | D.Output.saveToFile(text, prefix) ]]

return function(D)
    local Out = {}
    D.Output = Out

    local COLOR = D.Config.COLOR

    local function clipboardFn()
        return setclipboard or writeclipboard or toclipboard
    end

    local function workspacePath()
        if type(getworkspace) == "function" then
            local ok, p = pcall(getworkspace)
            if ok and type(p) == "string" then return p end
        end
        return "workspace (folder executor)"
    end

    function Out.copyText(text, label)
        local fn = clipboardFn()
        if not fn then
            D.UI.setStatus("✗ No clipboard")
            return false
        end
        local ok = pcall(fn, text)
        D.UI.setStatus(ok and ("✓ %s (%d char)"):format(label, #text) or "✗ Copy failed")
        return ok
    end

    function Out.saveToFile(text, prefix)
        local sizeStr = D.Util.fmtSize(#text)
        if type(writefile) == "function" then
            local fname = prefix .. "_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
            local ok, err = pcall(writefile, fname, text)
            if ok then
                D.Log.write("[SAVE] ✓ " .. fname .. " (" .. sizeStr .. ")", COLOR.ok, "save")
                D.Log.write("[SAVE] folder: " .. workspacePath(), COLOR.info, "save")
                local cb = clipboardFn()
                if cb then pcall(cb, fname) end
                D.UI.setStatus("Saved " .. fname)
                return true
            end
            D.Log.write("[SAVE] ✗ writefile: " .. tostring(err), COLOR.err, "save")
        end
        local cb = clipboardFn()
        if cb and pcall(cb, text) then
            D.Log.write("[SAVE] ✓ copied (" .. sizeStr .. ")", COLOR.ok, "save")
            D.UI.setStatus("Copied (" .. sizeStr .. ")")
            return true
        end
        D.Log.write("[SAVE] ✗ all failed", COLOR.err, "save")
        return false
    end
end
