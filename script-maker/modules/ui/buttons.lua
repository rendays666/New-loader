--[[ UI/BUTTONS — 11 tombol aksi + handler.
     Setiap handler dibungkus D.Log.wrap → error tercatat di DIAGNOSTICS, tidak diam-diam hilang.
     SMART/FULL: tiap builder dijalankan terpisah (section()), jadi satu builder error tidak
     menggagalkan seluruh file; DIAGNOSTICS selalu ditambahkan di akhir. ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI, B, O = D.UI, D.Build, D.Output
    local COLOR = Cfg.COLOR
    local panel = UI.scanPanel

    local function mk(text, x, w, y, r, g, b, h)
        return UI.mkBtn(panel, text, x, w, y, Color3.fromRGB(r, g, b), 9, h)
    end

    local scanBtn  = mk("SCAN",  0.01, 0.32, 0,  0, 140, 80, 20)
    local smartBtn = mk("SMART", 0.34, 0.32, 0,  0, 160, 120, 20)
    local mechBtn  = mk("MECH",  0.67, 0.32, 0,  40, 140, 200, 20)
    local idxBtn   = mk("INDEX", 0.01, 0.32, 22, 60, 100, 160)
    local fullBtn  = mk("FULL",  0.34, 0.32, 22, 80, 80, 80)
    local clrBtn   = mk("CLR",   0.67, 0.32, 22, 120, 50, 50)
    local remBtn   = mk("REM",   0.01, 0.32, 42, 140, 60, 140)
    local cfgBtn   = mk("CFG",   0.34, 0.32, 42, 100, 80, 140)
    local pathBtn  = mk("PATH",  0.67, 0.32, 42, 150, 90, 50)
    local runBtn   = mk("RUN",   0.01, 0.49, 62, 200, 120, 40)
    local treeBtn  = mk("TREE",  0.51, 0.49, 62, 60, 80, 140)

    for key, btn in pairs({
        SCAN = scanBtn, SMART = smartBtn, MECH = mechBtn, INDEX = idxBtn, FULL = fullBtn,
        CLR = clrBtn, REM = remBtn, CFG = cfgBtn, PATH = pathBtn, RUN = runBtn, TREE = treeBtn,
    }) do
        UI.addInfoBadge(btn, key)
    end

    local function log(text, color, tag) D.Log.write(text, color, tag) end
    local function onClick(btn, tag, fn) btn.MouseButton1Click:Connect(D.Log.wrap("btn:" .. tag, fn)) end

    -- Jalankan builder terisolasi; kalau error, sisipkan penanda (bukan batalkan semuanya)
    local function section(name, fn)
        local ok, res = D.Log.safe("build:" .. name, fn)
        if ok and type(res) == "string" then return res end
        return ("=== %s: GAGAL DIBUAT — lihat DIAGNOSTICS ===\n%s"):format(name, tostring(res))
    end

    local function needScan(tag)
        if #S.allScripts == 0 then
            log("[" .. tag .. "] scan dulu", COLOR.warn, tag:lower())
            return true
        end
        return false
    end

    onClick(scanBtn, "scan", D.Scanner.run)

    onClick(smartBtn, "smart", function()
        if S.scanRunning then log("[SMART] tunggu scan selesai", COLOR.warn, "smart") return end
        if #S.allScripts == 0 then log("[SMART] ⚠ belum SCAN — hanya config+runtime", COLOR.warn, "smart") end
        log("[SMART] building pack + snapshot…", Color3.fromRGB(100, 220, 180), "smart")
        local text = table.concat({
            section("SNAPSHOT", B.snapshot),
            section("RUNTIME", B.runtime),
            section("MECHANICS", B.mechanics),
            section("DIAGNOSTICS", B.diagnostics),
        }, "\n\n")
        log("[SMART] size: " .. D.Util.fmtSize(#text), Color3.fromRGB(100, 220, 180), "smart")
        O.saveToFile(text, "mechanics")
    end)

    onClick(mechBtn, "mech", function()
        if needScan("MECH") then return end
        local text = section("MECHANICS", B.mechanics)
        O.copyText(text, "mechanics")
        log(("[MECH] %d char copied"):format(#text), Color3.fromRGB(100, 200, 255), "mech")
    end)

    onClick(fullBtn, "full", function()
        if S.scanRunning then log("[FULL] tunggu scan selesai", COLOR.warn, "full") return end
        if #S.allScripts == 0 then log("[FULL] ⚠ belum SCAN — script source kosong", COLOR.warn, "full") end
        log("[FULL] building full pack…", Color3.fromRGB(180, 180, 220), "full")
        local text = table.concat({
            section("SNAPSHOT", B.snapshot),
            section("RUNTIME", B.runtime),
            section("INDEX", B.index),
            section("MECHANICS", B.mechanics),
            section("REMOTES", B.remotes),
            section("TREE", B.tree),
            section("CONFIG", B.config),
            section("DIAGNOSTICS", B.diagnostics),
        }, "\n\n")
        log("[FULL] size: " .. D.Util.fmtSize(#text), Color3.fromRGB(180, 180, 220), "full")
        O.saveToFile(text, "full")
    end)

    onClick(idxBtn, "index", function()
        if needScan("IDX") then return end
        O.copyText(section("INDEX", B.index), ("index (%d)"):format(#S.allScripts))
        log(("[IDX] %d entries"):format(#S.allScripts), COLOR.info, "index")
    end)

    onClick(pathBtn, "path", function()
        if needScan("PATH") then return end
        local out, sorted = { "=== ALL PATHS ===" }, {}
        for _, s in ipairs(S.allScripts) do table.insert(sorted, s) end
        table.sort(sorted, function(a, b) return a.path < b.path end)
        for _, s in ipairs(sorted) do
            table.insert(out, ("[%s | %s | %dB] %s"):format(s.class, s.status, s.size, s.path))
        end
        O.copyText(table.concat(out, "\n"), ("paths (%d)"):format(#S.allScripts))
        log(("[PATH] %d paths"):format(#S.allScripts), COLOR.info, "path")
    end)

    onClick(remBtn, "rem", function()
        O.copyText(section("REMOTES", B.remotes), "remotes")
        log("[REM] copied", COLOR.info, "rem")
    end)
    onClick(treeBtn, "tree", function()
        O.copyText(section("TREE", B.tree), "tree")
        log("[TREE] copied", COLOR.info, "tree")
    end)
    onClick(cfgBtn, "cfg", function()
        O.copyText(section("CONFIG", B.config), "config")
        log("[CFG] copied", COLOR.info, "cfg")
    end)

    onClick(runBtn, "run", function()
        if D.Passive.isActive() then
            D.Passive.stop()
            runBtn.Text = "RUN"
            runBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
        else
            D.Passive.start()
            runBtn.Text = "STOP"
            runBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        end
    end)

    onClick(clrBtn, "clr", function()
        if S.scanRunning then
            S.scanAbort = true
            log("[CLR] ⏹ abort requested", Color3.fromRGB(255, 180, 100), "clr")
            UI.setRtStatus("⏹ aborting…", Color3.fromRGB(255, 140, 100))
            return
        end
        S.renderToken = S.renderToken + 1
        UI.clearList()
        S.allScripts, S.bigScripts = {}, {}
        UI.setStatus("Cleared.")
        log("[CLR] list cleared (runtime tetap)", Color3.fromRGB(200, 140, 140), "clr")
    end)
end
