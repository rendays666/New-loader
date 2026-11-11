--[[ BUILD/SNAPSHOT — D.Build.snapshot(): header "CONFIG SNAPSHOT" untuk AI pembaca file.
     Menjelaskan chip mana ON/OFF saat file dibuat dan data apa yang ada/tidak ada. ]]

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
        add("3. UI/HK/UC     → rekam data RUNTIME terpisah dari scan")
        add("4. Chip RS..TM  → pilih root mana yang di-scan")
        add("5. Chip DC/BC/RC→ opsi baca source (default OFF untuk anti-crash)")
        add("6. Chip UI/HK/HK2/UC → rekam aktivitas live (butuh diaktifkan user)")
        add("7. Bagian DIAGNOSTICS di akhir file = status hook, error, log terakhir")
        add("")
        add(line); add("ROOT SCAN (chip RS..TM):"); add(line)
        for _, r in ipairs(Cfg.SKIP_ROOTS) do
            local inf = Cfg.ROOT_INFO[r.abbr]
            add(("  [%s] %s  %-18s — %s"):format(onOff(S.rootEnabled[r.name]), r.abbr,
                inf and inf.name or r.name, inf and inf.desc or ""))
        end
        add("")
        add(line); add("OPSI SCAN (chip DC/BC/RC):"); add(line)
        add(("  [%s] DC  Decompile fallback (LAMBAT, crash-prone)"):format(onOff(S.scanOptions.decompile)))
        add(("  [%s] BC  Bytecode dump (SANGAT besar, tak terbaca)"):format(onOff(S.scanOptions.bytecode)))
        add(("  [%s] RC  Read Roblox core (PlayerModule/CameraModule dkk)"):format(onOff(S.scanOptions.readCore)))
        add("")
        add(line); add("RUNTIME CAPTURE (chip UI/HK/UC):"); add(line)
        add(("  [%s] UI  Watch PlayerGui (ImageButton/TextButton muncul)"):format(onOff(S.uiActive)))
        add(("  [%s] HK  Hook __namecall FireServer/InvokeServer (log argumen)"):format(onOff(S.hkActive)))
        add(("  [%s] HK2 Hook fungsi langsung (hookfunction), cara beda dari HK"):format(onOff(S.hk2Active)))
        add(("  [%s] UC  Alias HK2 (kompatibilitas)"):format(onOff(S.ucActive)))
        add("       (HK prioritas: kalau HK ON maka HK2/UC tidak mencatat)")
        add("")
        add(line); add("BUTTON LIST:"); add(line)
        for _, key in ipairs({ "SCAN", "SMART", "MECH", "INDEX", "FULL", "CLR",
                               "REM", "CFG", "PATH", "RUN", "TREE" }) do
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
            add("  ❌ Runtime UI      : kosong (chip UI belum diaktifkan / belum buka menu)")
        end
        if #rc.fireServer > 0 then
            add(("  ✅ Runtime FS      : %d call"):format(#rc.fireServer))
        else
            add("  ❌ Runtime FS      : kosong (HK/UC belum diaktifkan / belum ada aksi)")
        end
        add("")
        add(line); add("INSTRUKSI UNTUK AI LAIN:"); add(line)
        add("  - Cek daftar ON/OFF di atas sebelum analisis")
        add("  - Data yang ditandai ❌ = tidak ada di file ini")
        add("  - Kalau FS kosong padahal HK ON: coba HK2 (mekanisme beda), lalu lihat DIAGNOSTICS")
        add("  - Kalau butuh data yang OFF, minta user:")
        add("      • untuk PlayerModule → aktifkan chip RC + re-SCAN")
        add("      • untuk tombol runtime → aktifkan chip UI, buka menu/match, baru capture")
        add("      • untuk argumen remote → aktifkan chip HK (atau HK2), lakukan aksi sekali")
        add("  - Runtime capture TIDAK butuh SCAN ulang, cukup aktifkan chip")
        add("  - Saran 'penting saja': Script logic → RS + SP; Runtime UI → UI on; Argumen remote → HK on")
        add(sep)
        return table.concat(out, "\n")
    end
end
