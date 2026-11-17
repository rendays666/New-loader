--[[ RUNTIME/CAPTURE — antrean + pencatat FireServer/InvokeServer.

     KENAPA ADA ANTREAN (akar bug "GUI game tidak bisa diklik saat HK ON"):
     Hook __namecall berjalan di dalam SETIAP panggilan method Instance di game.
     Versi lama memanggil remote:GetFullName(), v.Name, tostring() dkk langsung di dalam
     hook. Itu method call juga → me-reset "namecall method" → panggilan asli game
     (:FireServer dari tombol GUI) jadi salah target / error → GUI game mati.
     Hook hanya memanggil D.Capture.enqueue (push ke tabel, tanpa method call Instance).
     Semua kerja berat (GetFullName, format argumen, log GUI) dilakukan di Heartbeat.

     Dedup (v15): panggilan dianggap duplikat HANYA kalau remote + method + argumen sama
     dalam DEDUP_SEC. (v14 membuang panggilan beda-argumen yang cepat beruntun.)

     Entri tersimpan di S.runtimeCapture.fireServer:
       { id, time, remote(string path), inst(Instance), class, method, args(string[]), raw(table.pack) }
     Listener UI: D.Capture.addListener(fn) → fn(entry) tiap entri baru, fn(nil) kalau data dihapus.

     API: enqueue(remote, method, args) | start() | flush() | pending() | clearCalls()
          addListener(fn) | stats ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local RunService = game:GetService("RunService")

    local C = {}
    D.Capture = C
    C.stats = { enqueued = 0, dropped = 0, logged = 0, deduped = 0, ignored = 0, errors = 0 }

    local queue, qHead, qTail = {}, 1, 0
    local last = { remote = nil, method = nil, sig = nil, time = 0 }
    local listeners = {}
    local seq = 0

    function C.pending() return qTail - qHead + 1 end

    function C.flush()
        queue, qHead, qTail = {}, 1, 0
        last.remote, last.method, last.sig, last.time = nil, nil, nil, 0
    end

    function C.addListener(fn) listeners[#listeners + 1] = fn end

    local function notify(entry)
        for _, fn in ipairs(listeners) do
            local ok, err = pcall(fn, entry)
            if not ok then D.Log.err("capture:listener", err) end
        end
    end

    -- Hapus semua panggilan tertangkap (dipakai tombol Clear / RT)
    function C.clearCalls()
        S.runtimeCapture.fireServer = {}
        C.flush()
        notify(nil)
    end

    -- DIPANGGIL DARI DALAM HOOK — jaga tetap minimal, jangan panggil method Instance di sini.
    function C.enqueue(remote, method, args)
        if qTail - qHead + 1 >= Cfg.FS.MAX_PENDING then
            C.stats.dropped = C.stats.dropped + 1
            return
        end
        qTail = qTail + 1
        queue[qTail] = { remote, method, args, os.clock() }
        C.stats.enqueued = C.stats.enqueued + 1
    end

    local function fmtArg(v)
        local tp = typeof(v)
        if tp == "Vector3" then
            return ("V3(%0.1f,%0.1f,%0.1f)"):format(v.X, v.Y, v.Z)
        elseif tp == "CFrame" then
            local p = v.Position
            return ("CF(%0.1f,%0.1f,%0.1f)"):format(p.X, p.Y, p.Z)
        elseif tp == "Instance" then
            local ok, name = pcall(function() return v.Name end)
            return "Inst:" .. (ok and tostring(name):sub(1, 20) or "?")
        elseif tp == "string" then
            return string.format("%q", v:sub(1, 30))
        elseif tp == "number" or tp == "boolean" or tp == "nil" then
            return tostring(v)
        elseif tp == "table" then
            local n = 0
            pcall(function()
                for _ in pairs(v) do
                    n = n + 1
                    if n >= 999 then break end
                end
            end)
            return "table[" .. n .. "]"
        end
        local ok, s = pcall(tostring, v)
        return tp .. ":" .. (ok and tostring(s):sub(1, 20) or "?")
    end

    local function process(item)
        local remote, method, args, t = item[1], item[2], item[3], item[4]
        if typeof(remote) ~= "Instance" then return end

        local spy = S.spy
        if spy.paused then return end
        if spy.ignored[remote] then
            C.stats.ignored = C.stats.ignored + 1
            return
        end

        local parts, maxArgs = {}, Cfg.FS.MAX_ARGS
        for i = 1, math.min(args.n, maxArgs) do parts[i] = fmtArg(args[i]) end
        if args.n > maxArgs then parts[#parts + 1] = "…+" .. (args.n - maxArgs) end
        local sig = table.concat(parts, "|")

        if last.remote == remote and last.method == method and last.sig == sig
            and (t - last.time) < Cfg.FS.DEDUP_SEC then
            C.stats.deduped = C.stats.deduped + 1
            return
        end
        last.remote, last.method, last.sig, last.time = remote, method, sig, t

        local okC, class = pcall(function() return remote.ClassName end)
        local okN, rname = pcall(function() return remote.Name end)
        seq = seq + 1
        local entry = {
            id     = seq,
            time   = t,
            remote = D.Util.safeFullName(remote),
            inst   = remote,
            name   = okN and tostring(rname) or "?",
            class  = okC and class or "?",
            method = method,
            args   = parts,
            raw    = args,
        }
        local list = S.runtimeCapture.fireServer
        list[#list + 1] = entry
        if #list > Cfg.FS.MAX_ENTRIES then table.remove(list, 1) end
        C.stats.logged = C.stats.logged + 1

        D.Log.write(("🔥 %s %s(%s)"):format(method, entry.name, table.concat(parts, ", ")),
            Cfg.COLOR.busy, "fs")
        notify(entry)
    end

    -- Sambungkan pemroses antrean ke Heartbeat (idempoten)
    function C.start()
        if C.conn then return end
        C.conn = RunService.Heartbeat:Connect(function()
            if qHead > qTail then return end
            local n, cap = 0, Cfg.FS.DRAIN_PER_FRAME
            while qHead <= qTail and n < cap do
                local item = queue[qHead]
                queue[qHead] = nil
                qHead = qHead + 1
                n = n + 1
                local ok, err = pcall(process, item)
                if not ok then
                    C.stats.errors = C.stats.errors + 1
                    D.Log.err("capture", err)
                end
            end
            if qHead > qTail then qHead, qTail = 1, 0 end
        end)
        table.insert(S.conns, C.conn)
    end
end
