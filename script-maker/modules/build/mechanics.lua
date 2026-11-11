--[[ BUILD/MECHANICS — D.Build.mechanics(): analisis dari hasil SCAN.
     Bagian: 1 API SURFACE, 2 CLIENT HANDLERS, 3 MODULES, 4 CONSTANTS, 5 TOP 15 BIG, 6 MECHANIC HITS
     Butuh D.State.allScripts terisi (tombol SCAN). ]]

return function(D)
    local S, Cfg, U = D.State, D.Config, D.Util
    D.Build = D.Build or {}

    local function section(parts, sep, title)
        table.insert(parts, "")
        table.insert(parts, sep)
        table.insert(parts, title)
        table.insert(parts, sep)
        table.insert(parts, "")
    end

    function D.Build.mechanics()
        local all = S.allScripts
        local parts, sep = {}, string.rep("=", 60)

        table.insert(parts, sep)
        table.insert(parts, "GAME MECHANICS ANALYSIS")
        table.insert(parts, sep)
        table.insert(parts, "Game      : " .. U.getGameName())
        table.insert(parts, "PlaceId   : " .. tostring(game.PlaceId))
        table.insert(parts, "JobId     : " .. tostring(game.JobId))
        table.insert(parts, "Player    : " .. S.LocalPlayer.Name)
        table.insert(parts, "UserId    : " .. tostring(S.LocalPlayer.UserId))
        table.insert(parts, "Generated : " .. os.date("%Y-%m-%d %H:%M:%S"))

        local n = { readable = 0, empty = 0, obf = 0, bcode = 0, truncated = 0 }
        for _, s in ipairs(all) do
            if n[s.status] then n[s.status] = n[s.status] + 1 end
        end
        table.insert(parts, ("Scripts   : %d (readable=%d empty=%d obf=%d bcode=%d trunc=%d)")
            :format(#all, n.readable, n.empty, n.obf, n.bcode, n.truncated))

        -- 1. API SURFACE
        section(parts, sep, "## 1. API SURFACE")
        local apiCount = 0
        for _, s in ipairs(all) do
            if s.src then
                local calls = U.findLines(s.src, function(line)
                    return line:find(":FireServer", 1, true) or line:find(":InvokeServer", 1, true)
                end)
                if #calls > 0 then
                    apiCount = apiCount + #calls
                    table.insert(parts, "")
                    table.insert(parts, ("[%s] %s"):format(s.class, s.path))
                    for _, c in ipairs(calls) do table.insert(parts, c) end
                end
            end
        end
        table.insert(parts, "")
        table.insert(parts, ("─── Total: %d remote calls ───"):format(apiCount))

        -- 2. CLIENT HANDLERS
        section(parts, sep, "## 2. CLIENT HANDLERS")
        local hCount = 0
        for _, s in ipairs(all) do
            if s.src then
                local handlers = U.findLines(s.src, function(line)
                    return line:find("OnClientEvent", 1, true)
                        or line:find("GetPropertyChangedSignal", 1, true)
                end)
                if #handlers > 0 then
                    hCount = hCount + #handlers
                    table.insert(parts, "")
                    table.insert(parts, ("[%s] %s"):format(s.class, s.path))
                    for _, h in ipairs(handlers) do table.insert(parts, h) end
                end
            end
        end
        table.insert(parts, "")
        table.insert(parts, ("─── Total: %d handler ───"):format(hCount))

        -- 3. MODULES
        section(parts, sep, "## 3. MODULES")
        local modCount = 0
        for _, s in ipairs(all) do
            if s.class == "ModuleScript" and s.src then
                modCount = modCount + 1
                local funcs = U.extractFunctions(s.src, 999)
                local names = {}
                for _, f in ipairs(funcs) do table.insert(names, f.name) end
                table.insert(parts, ("[Module] %s"):format(s.path))
                table.insert(parts, ("  size=%dB  lines=%d  method=%s"):format(s.size, U.countLines(s.src), s.how or "?"))
                if #names > 0 then
                    table.insert(parts, "  funcs: " .. table.concat(names, ", ", 1, math.min(25, #names)))
                end
                table.insert(parts, "")
            end
        end
        table.insert(parts, ("─── Total: %d modules ───"):format(modCount))

        -- 4. CONSTANTS
        section(parts, sep, "## 4. CONSTANTS")
        table.insert(parts, D.Build.config())

        -- 5. TOP 15 BIG
        section(parts, sep, "## 5. TOP 15 BIG SCRIPT")
        local top = {}
        for _, s in ipairs(all) do if s.src then table.insert(top, s) end end
        table.sort(top, function(a, b) return a.size > b.size end)
        for i = 1, math.min(15, #top) do
            local s = top[i]
            table.insert(parts, ("[%d] [%s] %s — %dB / %d lines"):format(i, s.class, s.path, s.size, U.countLines(s.src)))
        end

        -- 6. MECHANIC HITS
        section(parts, sep, "## 6. MECHANIC HITS")
        local groups = {}
        for _, s in ipairs(all) do
            if s.src then
                local lower = s.path:lower()
                for _, kw in ipairs(Cfg.MECHANIC_KW) do
                    if lower:find(kw, 1, true) then
                        groups[kw] = groups[kw] or {}
                        table.insert(groups[kw], s)
                        break
                    end
                end
            end
        end
        local kws = {}
        for k in pairs(groups) do table.insert(kws, k) end
        table.sort(kws)
        for _, kw in ipairs(kws) do
            table.insert(parts, "")
            table.insert(parts, "### " .. kw:upper() .. " (" .. #groups[kw] .. ")")
            for _, s in ipairs(groups[kw]) do
                table.insert(parts, ("  [%s] %s (%dB)"):format(s.status, s.path, s.size))
            end
        end

        table.insert(parts, "")
        table.insert(parts, sep)
        table.insert(parts, "END OF MECHANICS")
        table.insert(parts, sep)
        return table.concat(parts, "\n")
    end
end
