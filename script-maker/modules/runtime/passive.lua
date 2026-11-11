--[[ RUNTIME/PASSIVE — tombol RUN: log LogService + OnClientEvent (server → client).
     Pasif, tidak menyentuh metatable. Untuk client → server pakai chip HK.
     API: D.Passive.start() | D.Passive.stop() | D.Passive.isActive() ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local P = {}
    D.Passive = P

    local conns = {}

    function P.isActive() return S.passiveActive end

    function P.stop()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if S.passiveActive then
            S.passiveActive = false
            D.Log.write("[RUN] stopped", Cfg.COLOR.dim, "run")
        end
    end

    local function fmtArgs(args)
        local parts = {}
        for i = 1, math.min(args.n, 5) do
            local v = args[i]
            if typeof(v) == "Instance" then
                local ok, name = pcall(function() return v.Name end)
                parts[i] = ok and tostring(name) or "?"
            else
                parts[i] = tostring(v):sub(1, 30)
            end
        end
        return table.concat(parts, ", ")
    end

    function P.start()
        if S.passiveActive then return end
        S.passiveActive = true

        local ok, conn = pcall(function()
            return game:GetService("LogService").MessageOut:Connect(function(msg, typ)
                local prefix = typ == Enum.MessageType.MessageError and "[ERR] "
                    or typ == Enum.MessageType.MessageWarning and "[WRN] " or "[OUT] "
                D.Log.write(prefix .. tostring(msg):sub(1, 120),
                    typ == Enum.MessageType.MessageError and Color3.fromRGB(255, 120, 120)
                        or Color3.fromRGB(200, 200, 150), "run")
                local list = S.runtimeCapture.log
                list[#list + 1] = { time = os.clock(), type = prefix:sub(2, 4), msg = tostring(msg):sub(1, 120) }
                if #list > Cfg.LOG_MAX_ENTRIES then table.remove(list, 1) end
            end)
        end)
        if ok and conn then table.insert(conns, conn) end

        task.spawn(function()
            local hooked, n = 0, 0
            for _, d in ipairs(game:GetDescendants()) do
                if not S.passiveActive then return end
                local isRemote = d:IsA("RemoteEvent")
                if not isRemote then
                    local okU, res = pcall(function() return d:IsA("UnreliableRemoteEvent") end)
                    isRemote = okU and res == true
                end
                if isRemote then
                    local ok2, c2 = pcall(function()
                        return d.OnClientEvent:Connect(function(...)
                            D.Log.write(("← %s(%s)"):format(d.Name, fmtArgs(table.pack(...))),
                                Color3.fromRGB(100, 200, 255), "run")
                        end)
                    end)
                    if ok2 and c2 then
                        table.insert(conns, c2)
                        hooked = hooked + 1
                    end
                end
                n = n + 1
                if n % 300 == 0 then task.wait() end
            end
            D.Log.write(("[RUN] %d remotes hooked + LogService"):format(hooked), Cfg.COLOR.ok, "run")
        end)
    end
end
