--[[ LOGGER — satu-satunya jalur log. Semua modul menulis lewat D.Log.write(text, color, tag).
     - Buffer di memori (dipakai D.Build.diagnostics supaya AI bisa baca log terakhir)
     - Sink ke panel LOG di-set belakangan oleh ui/logview (baris awal ditahan di pending)
     - D.Log.safe / D.Log.wrap: jalankan fungsi dengan xpcall + traceback, error masuk
       D.Log.errors (muncul di bagian DIAGNOSTICS file SMART/FULL) ]]

return function(D)
    local MAX_KEEP, MAX_PENDING, MAX_ERR = 400, 120, 50

    local Log = { entries = {}, errors = {}, pending = {}, sink = nil }
    D.Log = Log

    -- Stub UI: modul non-UI boleh memanggil ini sebelum UI selesai dibuat.
    -- Modul ui/* menimpa field-field ini dengan implementasi asli.
    D.UI = D.UI or {}
    local noop = function() end
    D.UI.setStatus   = D.UI.setStatus   or noop
    D.UI.setRtStatus = D.UI.setRtStatus or noop
    D.UI.rebuildList = D.UI.rebuildList or noop
    D.UI.clearList   = D.UI.clearList   or noop

    local function keep(tag, text)
        local e = Log.entries
        e[#e + 1] = { t = os.clock(), tag = tag or "-", text = text }
        if #e > MAX_KEEP then table.remove(e, 1) end
    end

    function Log.write(text, color, tag)
        text = tostring(text)
        keep(tag, text)
        local sink = Log.sink
        if sink then
            pcall(sink, text, color)
        else
            local p = Log.pending
            p[#p + 1] = { text, color }
            if #p > MAX_PENDING then table.remove(p, 1) end
        end
    end

    function Log.setSink(fn)
        Log.sink = fn
        local p = Log.pending
        Log.pending = {}
        for _, item in ipairs(p) do pcall(fn, item[1], item[2]) end
    end

    function Log.err(tag, e)
        local msg = tostring(e)
        local list = Log.errors
        list[#list + 1] = { t = os.clock(), tag = tag, msg = msg }
        if #list > MAX_ERR then table.remove(list, 1) end
        local firstLine = msg:match("^[^\n]*") or msg
        Log.write(("[ERR:%s] %s"):format(tag, firstLine:sub(1, 140)),
            Color3.fromRGB(255, 100, 100), tag)
    end

    -- Jalankan fn(...) dengan xpcall. Return ok, hasil.
    function Log.safe(tag, fn, ...)
        local args = table.pack(...)
        local ok, res = xpcall(function()
            return fn(table.unpack(args, 1, args.n))
        end, function(e)
            return debug.traceback(tostring(e), 2)
        end)
        if not ok then Log.err(tag, res) end
        return ok, res
    end

    -- Bungkus handler (mis. MouseButton1Click) supaya error-nya tercatat.
    function Log.wrap(tag, fn)
        return function(...)
            local ok, res = Log.safe(tag, fn, ...)
            if ok then return res end
        end
    end
end
