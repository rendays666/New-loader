--[[ ACTIONS — semua aksi tombol (tanpa GUI). Halaman UI hanya memanggil D.Actions.*.
     Satu tempat untuk logika "klik tombol", jadi mode Simple dan Advanced memakai kode yang sama.

     Scan : scan() stopScan() clearResults()
     Report: report("smart"|"full"|"brief", "save"|"copy")  exportAll()  — auto-scan dulu kalau belum pernah SCAN
     Copy : copy("MECH"|"INDEX"|"PATHS"|"REMOTES"|"TREE"|"CONFIG")
     Runtime: setCapture(bool) setUIWatch(bool) setPassive(bool) clearRuntime()
     counts() → { scripts, calls, buttons, logs } ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local B, O = D.Build, D.Output
    local COLOR = Cfg.COLOR
    local A = {}
    D.Actions = A

    local function say(text) D.UI.setStatus(text) end
    local function log(text, color, tag) D.Log.write(text, color or COLOR.info, tag or "act") end

    -- Jalankan builder terisolasi; kalau error, sisipkan penanda (bukan batalkan semuanya)
    local function section(name, fn)
        local ok, res = D.Log.safe("build:" .. name, fn)
        if ok and type(res) == "string" then return res end
        return ("=== %s: FAILED TO BUILD — see DIAGNOSTICS ===\n%s"):format(name, tostring(res))
    end

    function A.counts()
        local rc = S.runtimeCapture
        return { scripts = #S.allScripts, calls = #rc.fireServer, buttons = #rc.ui, logs = #rc.log }
    end

    -- ── Scan ────────────────────────────────────────────────────────
    function A.scan()
        if S.scanRunning then say("Scan is already running…") return end
        D.Scanner.run()
    end

    function A.stopScan()
        if not S.scanRunning then say("No scan is running.") return end
        S.scanAbort = true
        log("[SCAN] ⏹ stop requested", Color3.fromRGB(255, 180, 100), "scan")
        D.UI.setRtStatus("⏹ stopping…", Color3.fromRGB(255, 140, 100))
    end

    function A.clearResults()
        if S.scanRunning then A.stopScan() return end
        S.renderToken = S.renderToken + 1
        D.UI.clearList()
        S.allScripts, S.bigScripts = {}, {}
        say("Results cleared.")
        log("[CLEAR] scan results cleared (recorded data is kept)", COLOR.dim, "scan")
    end

    local function needScan(label)
        if #S.allScripts > 0 then return false end
        say("Scan the game first (" .. label .. " needs scan results).")
        return true
    end

    -- Scan otomatis kalau belum pernah; return true kalau ada hasil scan
    local function ensureScan()
        if #S.allScripts > 0 then return true end
        if not S.scanRunning then
            say("Scanning the game first…")
            D.Scanner.run()
        end
        local t0 = os.clock()
        while S.scanRunning and os.clock() - t0 < 240 and not S.dead do task.wait(0.25) end
        return #S.allScripts > 0
    end

    -- ── Reports ─────────────────────────────────────────────────────
    local function buildText(kind)
        local parts
        if kind == "full" then
            parts = {
                section("SNAPSHOT", B.snapshot), section("RUNTIME", B.runtime),
                section("INDEX", B.index), section("MECHANICS", B.mechanics),
                section("REMOTES", B.remotes), section("TREE", B.tree),
                section("CONFIG", B.config), section("DIAGNOSTICS", B.diagnostics),
            }
        elseif kind == "brief" then
            return section("BRIEF", B.brief)
        else
            parts = {
                section("SNAPSHOT", B.snapshot), section("RUNTIME", B.runtime),
                section("MECHANICS", B.mechanics), section("DIAGNOSTICS", B.diagnostics),
            }
        end
        return table.concat(parts, "\n\n")
    end

    local PREFIX = { full = "full", brief = "ai_brief", smart = "smart" }

    -- kind: "smart" | "full" ; how: "save" (file .txt) | "copy" (clipboard)
    function A.report(kind, how)
        if S.reportBusy then say("A report is already being built…") return end
        S.reportBusy = true
        task.spawn(function()
            D.Log.safe("report", function()
                if not ensureScan() then
                    log("[REPORT] no scan results — building with runtime data only", COLOR.warn, "report")
                end
                say("Building " .. kind .. " report…")
                local text = buildText(kind)
                log(("[REPORT] %s size: %s"):format(kind, D.Util.fmtSize(#text)), COLOR.info, "report")
                if how == "copy" then
                    O.copyText(text, kind .. " report")
                else
                    O.saveToFile(text, PREFIX[kind] or "smart")
                end
            end)
            S.reportBusy = false
        end)
    end

    -- ── Copy-to-clipboard items ─────────────────────────────────────
    local function pathsText()
        local out, sorted = { "=== ALL PATHS ===" }, {}
        for _, s in ipairs(S.allScripts) do table.insert(sorted, s) end
        table.sort(sorted, function(a, b) return a.path < b.path end)
        for _, s in ipairs(sorted) do
            table.insert(out, ("[%s | %s | %dB] %s"):format(s.class, s.status, s.size, s.path))
        end
        return table.concat(out, "\n")
    end

    local COPY = {
        MECH    = { need = true,  label = "mechanics", build = function() return section("MECHANICS", B.mechanics) end },
        INDEX   = { need = true,  label = "index",     build = function() return section("INDEX", B.index) end },
        PATHS   = { need = true,  label = "paths",     build = pathsText },
        REMOTES = { need = false, label = "remotes",   build = function() return section("REMOTES", B.remotes) end },
        TREE    = { need = false, label = "tree",      build = function() return section("TREE", B.tree) end },
        CONFIG  = { need = false, label = "config",    build = function() return section("CONFIG", B.config) end },
    }

    function A.copy(key)
        local item = COPY[key]
        if not item then return end
        if item.need and needScan(item.label) then return end
        local text = item.build()
        O.copyText(text, item.label)
        log(("[COPY] %s: %d chars"):format(item.label, #text), COLOR.info, "copy")
    end

    -- ── Export ALL: banyak file terpisah, satu timestamp ────────────
    function A.exportAll()
        if S.reportBusy then say("A report is already being built…") return end
        if type(writefile) ~= "function" then
            say("Export ALL needs writefile (not available in this executor). Use Copy instead.")
            return
        end
        S.reportBusy = true
        task.spawn(function()
            D.Log.safe("exportAll", function()
                if not ensureScan() then
                    log("[EXPORT] no scan results — scan-based files will be thin", COLOR.warn, "report")
                end
                local stamp = os.date("%Y%m%d_%H%M%S")
                local jobs = {
                    { "ai_brief", function() return buildText("brief") end },
                    { "smart",    function() return buildText("smart") end },
                    { "full",     function() return buildText("full") end },
                    { "mechanics", function() return section("MECHANICS", B.mechanics) end },
                    { "index",    function() return section("INDEX", B.index) end },
                    { "paths",    pathsText },
                    { "remotes",  function() return section("REMOTES", B.remotes) end },
                    { "tree",     function() return section("TREE", B.tree) end },
                    { "config",   function() return section("CONFIG", B.config) end },
                }
                local saved, failed = {}, {}
                for i, job in ipairs(jobs) do
                    say(("Export ALL… %d/%d %s"):format(i, #jobs, job[1]))
                    local okB, text = D.Log.safe("export:" .. job[1], job[2])
                    if okB and type(text) == "string" then
                        local ok, fname = O.saveToFile(text, job[1], { stamp = stamp, quiet = true })
                        if ok then saved[#saved + 1] = fname else failed[#failed + 1] = job[1] end
                    else
                        failed[#failed + 1] = job[1]
                    end
                    task.wait()
                end
                log(("[EXPORT] saved %d/%d files (stamp %s)"):format(#saved, #jobs, stamp), COLOR.ok, "report")
                if #failed > 0 then log("[EXPORT] failed: " .. table.concat(failed, ", "), COLOR.err, "report") end
                local cb = setclipboard or writeclipboard or toclipboard
                if cb and #saved > 0 then pcall(cb, table.concat(saved, "\n")) end
                say(("Export ALL done: %d files%s. Names copied."):format(#saved,
                    #failed > 0 and (", " .. #failed .. " failed (see Log)") or ""))
            end)
            S.reportBusy = false
        end)
    end

    -- ── Runtime recording ───────────────────────────────────────────
    function A.setCapture(on)
        if on then
            local ok, res = D.Hook.start(S.captureMethod)
            if not ok then
                say("Recording failed: " .. tostring(res))
                log("[CAPTURE] ✗ " .. tostring(res), COLOR.err, "hook")
                return false
            end
            say("Recording game actions (" .. tostring(res) .. ")")
            return true
        end
        D.Hook.stop()
        log("[CAPTURE] ✗ stopped", COLOR.dim, "hook")
        say("Recording stopped.")
        return false
    end

    function A.setUIWatch(on) D.UIWatch.set(on) end

    function A.setPassive(on)
        if on then D.Passive.start() else D.Passive.stop() end
    end

    function A.clearRuntime()
        S.runtimeCapture.ui = {}
        S.runtimeCapture.log = {}
        D.Capture.clearCalls()
        log("[CLEAR] recorded data cleared", COLOR.dim, "rt")
        say("Recorded data cleared.")
    end
end
