--[[ RUNTIME/SPY — aksi atas panggilan remote yang sudah tertangkap (gabungan fitur NetScope).
     Semua dijalankan dari UI thread, BUKAN dari dalam hook.

     API: Spy.generate(entry)            → kode Lua sesuai template aktif
          Spy.cycleTemplate()            → ganti template (simple → advanced → debug), return nama
          Spy.templateName()
          Spy.replay(entry)              → kirim ulang panggilan (async), return true
          Spy.isBlocked(inst) / Spy.toggleBlock(inst) → return status baru
          Spy.ignore(inst) / Spy.resetFilters()
          Spy.setPaused(bool)
     Catatan: Block hanya bekerja selama capture aktif (hook yang membacanya). ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local Spy = {}
    D.Spy = Spy

    local function log(text, color) D.Log.write(text, color or Cfg.COLOR.info, "spy") end

    function Spy.templateName()
        return D.Codegen.templates[S.spy.template] or D.Codegen.templates[1]
    end

    function Spy.cycleTemplate()
        S.spy.template = S.spy.template % #D.Codegen.templates + 1
        return Spy.templateName()
    end

    function Spy.generate(entry)
        if not entry then return "" end
        local ok, res = pcall(D.Codegen.generate, entry, Spy.templateName())
        if ok then return res end
        D.Log.err("spy:generate", res)
        return "-- could not generate code: " .. tostring(res)
    end

    function Spy.replay(entry)
        if not entry or typeof(entry.inst) ~= "Instance" then return false end
        task.spawn(function()
            local ok, err = pcall(function()
                local raw = entry.raw
                if entry.method == "InvokeServer" then
                    return entry.inst:InvokeServer(table.unpack(raw, 1, raw.n))
                end
                return entry.inst:FireServer(table.unpack(raw, 1, raw.n))
            end)
            if ok then
                log("[REPLAY] ✓ " .. entry.method .. " " .. entry.name, Cfg.COLOR.ok)
            else
                log("[REPLAY] ✗ " .. tostring(err):sub(1, 120), Cfg.COLOR.err)
            end
        end)
        return true
    end

    function Spy.isBlocked(inst)
        return S.spy.blocked[inst] == true
    end

    function Spy.toggleBlock(inst)
        if typeof(inst) ~= "Instance" then return false end
        local now = not (S.spy.blocked[inst] == true)
        S.spy.blocked[inst] = now or nil
        if now and not S.capturing then
            log("[BLOCK] set, but it only works while recording is ON", Cfg.COLOR.warn)
        end
        return now
    end

    function Spy.ignore(inst)
        if typeof(inst) == "Instance" then S.spy.ignored[inst] = true end
    end

    function Spy.resetFilters()
        for k in pairs(S.spy.ignored) do S.spy.ignored[k] = nil end
        for k in pairs(S.spy.blocked) do S.spy.blocked[k] = nil end
    end

    function Spy.setPaused(v) S.spy.paused = v == true end
end
