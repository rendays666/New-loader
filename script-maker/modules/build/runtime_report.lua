--[[ BUILD/RUNTIME_REPORT
     D.Build.runtime()      → bagian "RUNTIME CAPTURE" (UI, FireServer, LogService)
     D.Build.diagnostics()  → bagian "DIAGNOSTICS" untuk debugging oleh AI:
                              executor capability, status hook, status module, error + traceback,
                              40 baris log terakhir. SELALU ikut di SMART dan FULL. ]]

return function(D)
    local S, U = D.State, D.Util
    D.Build = D.Build or {}

    function D.Build.runtime()
        local sep = string.rep("=", 62)
        local rc = S.runtimeCapture
        local out = { sep, "RUNTIME CAPTURE", sep }

        if #rc.ui == 0 and #rc.fireServer == 0 then
            out[#out + 1] = ""
            out[#out + 1] = "⚠ Tidak ada runtime capture."
            out[#out + 1] = "  Untuk UI  : aktifkan chip UI → buka menu"
            out[#out + 1] = "  Untuk FS  : aktifkan chip HK → lakukan aksi sekali"
        end

        if #rc.ui > 0 then
            out[#out + 1] = ""
            out[#out + 1] = ("## UI — %d tombol (ImageButton/TextButton)"):format(#rc.ui)
            for i, e in ipairs(rc.ui) do
                out[#out + 1] = ("[%d] %s [%s]"):format(i, e.path, e.class)
                out[#out + 1] = ("     pos=%s size=%s visible=%s"):format(e.pos, e.size, tostring(e.visible))
                if e.text ~= "" then out[#out + 1] = ("     text=%q"):format(e.text:sub(1, 40)) end
                if e.image ~= "" then out[#out + 1] = ("     image=%s"):format(e.image:sub(1, 80)) end
            end
        end

        if #rc.fireServer > 0 then
            out[#out + 1] = ""
            out[#out + 1] = ("## FireServer/InvokeServer — %d call"):format(#rc.fireServer)
            out[#out + 1] = "  Format: [n] Method Remote(args) — arg tipe+isi"
            for i, e in ipairs(rc.fireServer) do
                out[#out + 1] = ("[%d] %s %s(%s)"):format(i, e.method, e.remote, table.concat(e.args, ", "))
            end
            out[#out + 1] = ""
            out[#out + 1] = "  💡 Analisis: argumen Vector3/CFrame = posisi/arah, string = nama aksi/item."
        end

        if #rc.log > 0 then
            out[#out + 1] = ""
            out[#out + 1] = ("## LogService — %d pesan"):format(#rc.log)
            for i, e in ipairs(rc.log) do
                out[#out + 1] = ("[%d] [%s] %s"):format(i, e.type, e.msg)
            end
        end

        out[#out + 1] = sep
        return table.concat(out, "\n")
    end

    function D.Build.diagnostics()
        local sep = string.rep("=", 62)
        local out = { sep, "DIAGNOSTICS (untuk AI yang men-debug dumper ini)", sep, "" }
        local function add(s) out[#out + 1] = s end

        add("Version   : " .. D.version)
        add("Executor  : " .. U.executorName())
        add("")
        add("## Executor capability")
        for _, c in ipairs(U.capabilities()) do
            add(("  %-18s %s"):format(c.name, c.ok and "OK" or "TIDAK ADA"))
        end

        add("")
        add("## Hook / capture")
        add(("  chip HK=%s UC=%s UI=%s RUN=%s"):format(
            tostring(S.hkActive), tostring(S.ucActive), tostring(S.uiActive), tostring(S.passiveActive)))
        local hs = D.Hook and D.Hook.status() or {}
        add(("  namecall hook terpasang : %s"):format(tostring(hs.namecallInstalled)))
        add(("  UC hookfunction class   : %s"):format(
            (hs.ucClasses and #hs.ucClasses > 0) and table.concat(hs.ucClasses, ", ") or "-"))
        add(("  hook lastError          : %s"):format(tostring(hs.lastError)))
        if D.Capture then
            local st = D.Capture.stats
            add(("  antrean pending         : %d"):format(D.Capture.pending()))
            add(("  enqueued=%d logged=%d deduped=%d dropped=%d errors=%d"):format(
                st.enqueued, st.logged, st.deduped, st.dropped, st.errors))
            add("  (enqueued>0 tapi logged=0 → bug di D.Capture / drain. enqueued=0 → hook tidak menangkap.)")
        end

        add("")
        add("## Status module (urutan load)")
        for _, name in ipairs(D.loadOrder or {}) do
            local m = D.moduleStatus and D.moduleStatus[name]
            if m then
                add(("  %-22s %s %s"):format(name, m.ok and "OK " or "GAGAL",
                    m.ok and (m.bytes .. "B") or tostring(m.err):sub(1, 160)))
            else
                add(("  %-22s (belum di-load)"):format(name))
            end
        end

        add("")
        add(("## Error tercatat (%d)"):format(#D.Log.errors))
        for i = math.max(1, #D.Log.errors - 19), #D.Log.errors do
            local e = D.Log.errors[i]
            add(("[%d] t=%.1f tag=%s"):format(i, e.t, e.tag))
            add(e.msg:sub(1, 700))
        end

        add("")
        add("## Log terakhir (maks 40)")
        for i = math.max(1, #D.Log.entries - 39), #D.Log.entries do
            local e = D.Log.entries[i]
            add(("  %.1f [%s] %s"):format(e.t, e.tag, e.text:sub(1, 160)))
        end
        add(sep)
        return table.concat(out, "\n")
    end
end
