--[[ BUILD/SNAPSHOT — D.Build.snapshot(): header "CONFIG SNAPSHOT" untuk AI pembaca file.
     Menjelaskan opsi mana ON/OFF saat file dibuat dan data apa yang ada/tidak ada. ]]

return function(D)
    local S, Cfg, U = D.State, D.Config, D.Util
    D.Build = D.Build or {}

    local function countStatus()
        local r, e, o, b, t = 0, 0, 0, 0, 0
        for _, s in ipairs(S.allScripts) do
            if s.status == "readable" then r = r + 1
            elseif s.status == "empty" then e = e + 1
            elseif s.status == "obf" then o = o + 1
            elseif s.status == "bcode" then b = b + 1
            elseif s.status == "truncated" then t = t + 1 end
        end
        return r, e, o, b, t
    end

    local function onOff(v) return v and "ON " or "OFF" end

    function D.Build.snapshot()
        local out, sep = {}, string.rep("=", 62)
        local function add(s) out[#out + 1] = s end
        local line = "──────────────────────────────────────────"
        local rc = S.runtimeCapture

        add(sep)
        add("DUMPER v" .. D.version .. " — CONFIG SNAPSHOT (untuk AI analyst)")
        add(sep)
        add("Game      : " .. U.getGameName())
        add("PlaceId   : " .. tostring(game.PlaceId))
        add("JobId     : " .. tostring(game.JobId))
        add("Player    : " .. S.LocalPlayer.Name)
        add("Executor  : " .. U.executorName())
        add("Generated : " .. os.date("%Y-%m-%d %H:%M:%S"))
        add("")
        add(line); add("MEKANISME DUMPER (baca dulu):"); add(line)
        add("1. SCAN         → baca .Source semua script dari root yang ON")
        add("                  (bukan runtime, hanya snapshot statis dari kode)")
        add("2. SMART/FULL   → build analisis pakai hasil scan")
        add("3. Record game actions / on-screen buttons → rekam data RUNTIME terpisah dari scan")
        add("4. Scan places  → pilih root mana yang di-scan (Scan tab)")
        add("5. Scan options → decompile/bytecode/core (default OFF untuk anti-crash)")
        add("6. Bagian DIAGNOSTICS di akhir file = status hook, error, log terakhir")
        add("")
        add(line); add("ROOT SCAN (Scan places):"); add(line)
        for _, r in ipairs(Cfg.SKIP_ROOTS) do
            local inf = Cfg.ROOT_INFO[r.abbr]
            add(("  [%s] %s  %-18s — %s"):format(onOff(S.rootEnabled[r.name]), r.abbr,
                inf and inf.name or r.name, inf and inf.desc or ""))
        end
        add("")
        add(line); add("OPSI SCAN:"); add(line)
        add(("  [%s] DC  Decompile fallback (LAMBAT, crash-prone)"):format(onOff(S.scanOptions.decompile)))
        add(("  [%s] BC  Bytecode dump (SANGAT besar, tak terbaca)"):format(onOff(S.scanOptions.bytecode)))
        add(("  [%s] RC  Read Roblox core (PlayerModule/CameraModule dkk)"):format(onOff(S.scanOptions.readCore)))
        add("")
        add(line); add("RUNTIME CAPTURE:"); add(line)
        add(("  [%s] UI  Record on-screen buttons (PlayerGui)"):format(onOff(S.uiActive)))
        add(("  [%s] REC Record game actions FireServer/InvokeServer (method: %s)"):format(
            onOff(S.capturing), tostring(S.captureUsing or S.captureMethod)))
        add(("  [%s] RUN Listen to server messages (LogService + OnClientEvent)"):format(onOff(S.passiveActive)))
        add("")
        add(line); add("BUTTON LIST:"); add(line)
        for _, key in ipairs({ "SCAN", "SMART", "FULL", "MECH", "INDEX", "PATHS",
                               "REMOTES", "CONFIG", "TREE" }) do
            add(("  %-5s — %s"):format(key, Cfg.BTN_INFO[key].desc))
        end
        add("")
        add(line); add("STATISTIK DATA:"); add(line)
        local r, e, o, b, t = countStatus()
        add(("  Scripts total      : %d (readable=%d empty=%d obf=%d bcode=%d trunc=%d)")
            :format(#S.allScripts, r, e, o, b, t))
        add(("  Runtime UI         : %d tombol tercatat"):format(#rc.ui))
        add(("  Runtime FireServer : %d call tercatat"):format(#rc.fireServer))
        add(("  Runtime LogService : %d pesan"):format(#rc.log))
        add("")
        add(line); add("DATA APA YANG TERSEDIA DI FILE INI:"); add(line)
        add(("  ✅ Script source   : %d readable script"):format(r))
        add("  ✅ Mechanics pack  : API/Handlers/Modules/Constants")
        add("  ✅ Remotes         : RemoteEvent/RemoteFunction list")
        if #rc.ui > 0 then
            add(("  ✅ Runtime UI      : %d tombol"):format(#rc.ui))
        else
            add("  ❌ Runtime UI      : kosong ('Record on-screen buttons' belum diaktifkan / belum buka menu)")
        end
        if #rc.fireServer > 0 then
            add(("  ✅ Runtime FS      : %d call"):format(#rc.fireServer))
        else
            add("  ❌ Runtime FS      : kosong ('Record game actions' belum diaktifkan / belum ada aksi)")
        end
        add("")
        add(line); add("INSTRUKSI UNTUK AI LAIN:"); add(line)
        add("  - Cek daftar ON/OFF di atas sebelum analisis")
        add("  - Data yang ditandai ❌ = tidak ada di file ini")
        add("  - Kalau FS kosong padahal recording ON: lihat DIAGNOSTICS (hook terpasang? queue? error?)")
        add("  - Kalau butuh data yang OFF, minta user:")
        add("      • untuk PlayerModule → aktifkan 'Include Roblox core scripts' + re-SCAN")
        add("      • untuk tombol runtime → aktifkan 'Record on-screen buttons', buka menu/match, baru capture")
        add("      • untuk argumen remote → aktifkan 'Record game actions' (coba metode Stealth/Namecall), lakukan aksi sekali")
        add("  - Runtime capture TIDAK butuh SCAN ulang, cukup aktifkan perekamannya")
        add("  - Saran 'penting saja': Script logic → RS + SP; Runtime UI → Record buttons on; Argumen remote → Record actions on")
        add(sep)
        return table.concat(out, "\n")
    end
end
