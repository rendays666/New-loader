--[[ UTIL — fungsi bantu murni (tanpa GUI). Dipakai scanner, builder, capture.
     D.Util.* : fmtSize, hasCoreAncestor, readSource, getGameName, extractFunctions,
                countLines, findLines, isRemoteInstance, safeFullName, executorName, capabilities ]]

return function(D)
    local S = D.State
    local U = {}
    D.Util = U

    function U.fmtSize(n)
        n = n or 0
        if n >= 1024 then return ("%.1f KB"):format(n / 1024) end
        return n .. " B"
    end

    function U.safeFullName(inst)
        local ok, name = pcall(function() return inst:GetFullName() end)
        if ok and type(name) == "string" then return name end
        return tostring(inst)
    end

    -- Cek script itu sendiri + ancestor terhadap daftar core Roblox
    function U.hasCoreAncestor(inst, depth)
        depth = depth or 5
        local names = D.Config.CORE_NAMES
        if names[inst.Name] then return inst.Name end
        local p, i = inst.Parent, 0
        while p and i < depth do
            if names[p.Name] then return p.Name end
            p, i = p.Parent, i + 1
        end
        return nil
    end

    -- return: source, how ("src"|"truncated"|"bcode"), ukuran asli
    function U.readSource(inst, maxBytes)
        local opts = S.scanOptions
        local ok, raw = pcall(function() return inst.Source end)
        if ok and type(raw) == "string" and #raw > 0 then
            local size = #raw
            if size > maxBytes then
                raw = raw:sub(1, maxBytes) .. "\n-- [TRUNC " .. (size - maxBytes) .. "b]"
                return raw, "truncated", size
            end
            return raw, "src", size
        end
        if opts.decompile and type(decompile) == "function" then
            local ok2, dec = pcall(decompile, inst)
            if ok2 and type(dec) == "string" and #dec > 0 then
                local size = #dec
                if size > maxBytes then
                    dec = dec:sub(1, maxBytes) .. "\n-- [TRUNC " .. (size - maxBytes) .. "b]"
                    return dec, "truncated", size
                end
                return dec, "src", size
            end
        end
        if opts.bytecode and type(getscriptbytecode) == "function" then
            local ok3, bc = pcall(getscriptbytecode, inst)
            if ok3 and type(bc) == "string" and #bc > 0 then
                return "-- [BYTECODE " .. #bc .. "b]\n" .. bc:sub(1, 500), "bcode", #bc
            end
        end
        return nil, nil, 0
    end

    local cachedGameName
    function U.getGameName()
        if cachedGameName then return cachedGameName end
        local ok, info = pcall(function()
            return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        end)
        if ok and type(info) == "table" and info.Name then
            cachedGameName = info.Name
            return cachedGameName
        end
        return "Unknown"
    end

    function U.extractFunctions(src, maxBlock)
        maxBlock = maxBlock or 200
        local lines = {}
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do table.insert(lines, line) end
        local funcs, i = {}, 1
        while i <= #lines do
            local line = lines[i]
            local fnName =
                line:match("^%s*local%s+function%s+([%w_%.]+)") or
                line:match("^%s*function%s+([%w_%.:]+)") or
                line:match("^%s*local%s+([%w_]+)%s*=%s*function")
            if fnName then
                local body, j = { line }, i + 1
                while j <= #lines and #body < maxBlock do
                    local nl = lines[j]
                    if nl:match("^%s*local%s+function%s+") or
                       nl:match("^%s*function%s+") or
                       nl:match("^%s*local%s+[%w_]+%s*=%s*function") then break end
                    table.insert(body, nl); j = j + 1
                end
                table.insert(funcs, { name = fnName, body = table.concat(body, "\n") })
                i = j
            else
                i = i + 1
            end
        end
        return funcs
    end

    function U.countLines(s)
        local n = 1
        for _ in s:gmatch("\n") do n = n + 1 end
        return n
    end

    -- Nomor baris akurat (baris kosong ikut dihitung)
    function U.findLines(src, matcher, maxLen)
        local hits, n = {}, 0
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            if matcher(line) then
                table.insert(hits, ("    L%d: %s"):format(n, line:sub(1, maxLen or 120)))
            end
        end
        return hits
    end

    function U.isRemoteInstance(d)
        if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then return true end
        local ok, res = pcall(function() return d:IsA("UnreliableRemoteEvent") end)
        return ok and res == true
    end

    function U.executorName()
        if type(identifyexecutor) == "function" then
            local ok, name, ver = pcall(identifyexecutor)
            if ok and name then return tostring(name) .. (ver and (" " .. tostring(ver)) or "") end
        end
        return "unknown"
    end

    -- Fitur executor yang dibutuhkan dumper (untuk bagian DIAGNOSTICS)
    function U.capabilities()
        local names = {
            "hookmetamethod", "getnamecallmethod", "setnamecallmethod", "hookfunction",
            "newcclosure", "checkcaller", "writefile", "setclipboard", "gethui",
            "decompile", "getscriptbytecode", "getgenv",
        }
        local out = {}
        for _, n in ipairs(names) do
            local ok, v = pcall(function()
                local g = (type(getgenv) == "function" and getgenv()) or nil
                local val = g and g[n]
                if val == nil then val = getfenv()[n] end
                return val
            end)
            out[#out + 1] = { name = n, ok = ok and type(v) == "function" }
        end
        return out
    end
end
