--[[ SCANNER — tombol SCAN: baca .Source semua script dari root yang ON.
     Hasil ke D.State.allScripts: {inst, path, class, size, status, src, how}
     status: readable | empty | obf | bcode | truncated
     API: D.Scanner.run()   (abort lewat D.State.scanAbort = true, dipicu tombol CLR) ]]

return function(D)
    local S, Cfg, U = D.State, D.Config, D.Util
    local SC, COLOR = Cfg.SCAN, Cfg.COLOR
    local Scanner = {}
    D.Scanner = Scanner

    local ROOT_NAMES = {
        "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui",
        "Workspace", "Players", "Lighting", "SoundService", "Chat", "Teams",
    }

    local function log(text, color) D.Log.write(text, color, "scan") end

    local function looksObfuscated(src, size)
        if size >= 10000 or size <= 200 then return false end
        if src:find("LPH_", 1, true) or src:find("__prometheus", 1, true) then return true end
        local sample = src:sub(1, math.min(#src, 500))
        local bs = 0
        for k = 1, #sample do
            if sample:byte(k) == 92 then bs = bs + 1 end
        end
        return bs > 20
    end

    local function scanBody()
        local t0 = os.clock()
        local roots = {}
        for _, name in ipairs(ROOT_NAMES) do
            local ok, svc = pcall(function() return game:GetService(name) end)
            if ok and svc then table.insert(roots, svc) end
        end

        local c = { read = 0, empty = 0, obf = 0, bc = 0, trunc = 0, skip = 0 }
        local totalSrcBytes, totalRoots, rootIdx = 0, #roots, 0

        for _, root in ipairs(roots) do
            rootIdx = rootIdx + 1
            if S.scanAbort then break end

            if not S.rootEnabled[root.Name] then
                log(("[SKIP] %s (disabled)"):format(root.Name), Color3.fromRGB(255, 140, 100))
                task.wait(0.05)
                continue
            end

            D.UI.setRtStatus(("⏳ %s | collecting… (%d/%d)"):format(root.Name, rootIdx, totalRoots), COLOR.busy)
            task.wait()

            local desc
            local ok = pcall(function() desc = root:GetDescendants() end)
            if not ok or not desc then
                log(("[ERR] %s GetDescendants fail"):format(root.Name), COLOR.err)
                continue
            end

            D.UI.setRtStatus(("⏳ %s | filtering %d inst…"):format(root.Name, #desc), COLOR.busy)
            task.wait()

            local scriptsOnly, rootSkip = {}, 0
            for i = 1, #desc do
                local d = desc[i]
                local cls = d.ClassName
                if cls == "LocalScript" or cls == "ModuleScript" or cls == "Script" then
                    if not S.scanOptions.readCore and U.hasCoreAncestor(d, 5) then
                        rootSkip = rootSkip + 1
                    else
                        table.insert(scriptsOnly, d)
                    end
                end
                if i % 500 == 0 then task.wait() end
            end
            c.skip = c.skip + rootSkip
            local totalDesc = #desc
            desc = nil

            local nScripts, capped = #scriptsOnly, false
            if nScripts > SC.MAX_SCRIPTS_ROOT then
                capped = true
                local trimmed = {}
                for i = 1, SC.MAX_SCRIPTS_ROOT do trimmed[i] = scriptsOnly[i] end
                scriptsOnly, nScripts = trimmed, SC.MAX_SCRIPTS_ROOT
            end

            log(("[ROOT] ▶ %s — %d inst, %d script%s%s"):format(
                root.Name, totalDesc, nScripts, capped and " (CAPPED)" or "",
                rootSkip > 0 and (" (+" .. rootSkip .. " core skipped)") or ""),
                Color3.fromRGB(150, 180, 220))

            local rootStart, rootScripts, rootAborted = os.clock(), 0, false

            for i = 1, nScripts do
                if S.scanAbort then rootAborted = true break end
                if totalSrcBytes > SC.MAX_TOTAL_MEM then
                    log("[ABORT] memory limit " .. math.floor(SC.MAX_TOTAL_MEM / 1024 / 1024) .. "MB reached", COLOR.err)
                    rootAborted, S.scanAbort = true, true
                    break
                end

                local d = scriptsOnly[i]
                local path = U.safeFullName(d)
                local src, how, origSize = U.readSource(d, SC.MAX_SCRIPT_SIZE)
                local size = origSize or 0
                local st = "empty"

                if src then
                    if how == "truncated" then
                        st = "truncated"; c.trunc = c.trunc + 1
                    elseif how == "bcode" then
                        st = "bcode"; c.bc = c.bc + 1
                    elseif looksObfuscated(src, size) then
                        st = "obf"; c.obf = c.obf + 1
                    else
                        st = "readable"; c.read = c.read + 1
                    end
                    totalSrcBytes = totalSrcBytes + #src

                    if size >= SC.BIG_LOG_THRESH then
                        table.insert(S.bigScripts, { path = path, size = size })
                        log(("[BIG] %.1fKB %s%s"):format(size / 1024, path,
                            size > SC.MAX_SCRIPT_SIZE and " (TRUNCATED)" or ""), COLOR.warn)
                    end
                else
                    c.empty = c.empty + 1
                end

                rootScripts = rootScripts + 1
                table.insert(S.allScripts, {
                    inst = d, path = path, class = d.ClassName,
                    size = size, status = st, src = src, how = how,
                })

                D.UI.setRtStatus(("⏳ %s > %s > %s [%d/%d] %.1fKB | r=%d e=%d o=%d t=%d mem=%.1fMB"):format(
                    root.Name, (d.Parent and d.Parent.Name or "?"):sub(1, 12), d.Name:sub(1, 12),
                    i, nScripts, size / 1024, c.read, c.empty, c.obf, c.trunc,
                    totalSrcBytes / 1024 / 1024), COLOR.busy)
                D.UI.setStatus(("Scan… r=%d e=%d o=%d t=%d mem=%.1fMB"):format(
                    c.read, c.empty, c.obf, c.trunc, totalSrcBytes / 1024 / 1024))

                -- adaptive yield: makin banyak script, makin sering menyerah ke scheduler
                if nScripts > 500 then task.wait()
                elseif nScripts > 200 and i % 2 == 0 then task.wait()
                elseif nScripts > 50 and i % 5 == 0 then task.wait()
                elseif i % 20 == 0 then task.wait() end

                if os.clock() - rootStart > SC.ROOT_TIMEOUT then
                    log(("[TIMEOUT] %s >%ds"):format(root.Name, SC.ROOT_TIMEOUT), Color3.fromRGB(255, 140, 100))
                    break
                end
            end

            if not rootAborted then
                log(("[ROOT] ✓ %s — %d scripts (%.1fs)"):format(root.Name, rootScripts, os.clock() - rootStart),
                    Color3.fromRGB(100, 200, 150))
            end
            task.wait()
        end

        local el = os.clock() - t0
        log(("[DONE] r=%d e=%d o=%d bc=%d t=%d skip=%d (%.1fs) mem=%.1fMB"):format(
            c.read, c.empty, c.obf, c.bc, c.trunc, c.skip, el, totalSrcBytes / 1024 / 1024),
            Color3.fromRGB(100, 255, 180))

        if #S.bigScripts > 0 then
            table.sort(S.bigScripts, function(a, b) return a.size > b.size end)
            log("[SUMMARY] Top big scripts:", COLOR.busy)
            for i = 1, math.min(5, #S.bigScripts) do
                log(("  %d. %.0fKB  %s"):format(i, S.bigScripts[i].size / 1024, S.bigScripts[i].path), COLOR.warn)
            end
        end
        if S.scanAbort then log("[DONE] aborted — hasil sebagian", COLOR.busy) end

        D.UI.setStatus(("R=%d E=%d O=%d T=%d"):format(c.read, c.empty, c.obf, c.trunc))
        D.UI.setRtStatus(("✓ done r=%d e=%d o=%d t=%d (%.1fs, %.1fMB)"):format(
            c.read, c.empty, c.obf, c.trunc, el, totalSrcBytes / 1024 / 1024), Color3.fromRGB(100, 255, 180))
    end

    function Scanner.run()
        if S.scanRunning then
            D.UI.setStatus("Scan running...")
            return
        end
        S.scanRunning, S.scanAbort = true, false
        S.renderToken = S.renderToken + 1
        D.UI.clearList()
        S.allScripts, S.bigScripts = {}, {}
        D.UI.setStatus("Scanning…")
        log("───────────────────────", Color3.fromRGB(80, 140, 255))
        log("[SCAN] ▶ START (safe mode)", Color3.fromRGB(100, 180, 255))
        D.UI.setRtStatus("⏳ starting…", COLOR.busy)

        task.spawn(function()
            D.Log.safe("scanner", scanBody)
            -- selalu reset flag, bahkan kalau scanBody error (versi lama bisa macet "Scan running...")
            S.scanRunning, S.scanAbort = false, false
            D.UI.rebuildList()
        end)
    end
end
