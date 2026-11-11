--[[ BUILD/REPORTS — laporan sederhana berbasis game tree (bukan source script).
     D.Build.index() | remotes() | tree() | config() ]]

return function(D)
    local S, U = D.State, D.Util
    D.Build = D.Build or {}

    function D.Build.index()
        local all = S.allScripts
        local out = { string.rep("=", 60), "SCRIPT INDEX", string.rep("=", 60),
            "Game    : " .. U.getGameName(),
            "PlaceId : " .. tostring(game.PlaceId),
            "JobId   : " .. tostring(game.JobId),
            "Total   : " .. #all, "" }
        local sorted = {}
        for _, s in ipairs(all) do table.insert(sorted, s) end
        table.sort(sorted, function(a, b) return a.path < b.path end)
        for i, s in ipairs(sorted) do
            table.insert(out, ("[%d/%d] %s | %s | %dB | %s"):format(i, #sorted, s.class, s.status, s.size, s.path))
        end
        return table.concat(out, "\n")
    end

    function D.Build.remotes()
        local out = { "=== REMOTES ===" }
        local n = 0
        for _, d in ipairs(game:GetDescendants()) do
            if U.isRemoteInstance(d) then
                table.insert(out, ("[%s] %s"):format(d.ClassName, d:GetFullName()))
            end
            n = n + 1
            if n % 2000 == 0 then task.wait() end
        end
        return table.concat(out, "\n")
    end

    function D.Build.tree()
        local out = { "=== STRUCTURE TREE ===" }
        local services = { "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer",
            "StarterGui", "Workspace", "Players", "Lighting" }
        local function tagOf(i)
            if i:IsA("LocalScript") or i:IsA("ModuleScript") or i:IsA("Script") then return " *" end
            if i:IsA("RemoteEvent") or i:IsA("RemoteFunction") then return " !" end
            return ""
        end
        for _, name in ipairs(services) do
            local svc = game:FindFirstChild(name)
            if svc then
                table.insert(out, "")
                table.insert(out, "[" .. name .. "]")
                local ok, lvl1 = pcall(function() return svc:GetChildren() end)
                if ok and lvl1 then
                    for _, c1 in ipairs(lvl1) do
                        table.insert(out, ("  %s [%s]%s"):format(c1.Name, c1.ClassName, tagOf(c1)))
                        if c1:IsA("Folder") or c1:IsA("Model") then
                            local ok2, lvl2 = pcall(function() return c1:GetChildren() end)
                            if ok2 and lvl2 then
                                for _, c2 in ipairs(lvl2) do
                                    table.insert(out, ("    %s [%s]%s"):format(c2.Name, c2.ClassName, tagOf(c2)))
                                end
                            end
                        end
                    end
                end
            end
        end
        table.insert(out, "\nLegend: * = script, ! = remote")
        return table.concat(out, "\n")
    end

    local VALUE_CLASSES = {
        StringValue = true, NumberValue = true, BoolValue = true,
        IntValue = true, ObjectValue = true,
    }

    function D.Build.config()
        local out = { "=== VALUES ===" }
        local roots = {}
        for _, n in ipairs({ "ReplicatedStorage", "Workspace", "Lighting", "StarterPlayer" }) do
            local ok, svc = pcall(function() return game:GetService(n) end)
            if ok and svc then table.insert(roots, svc) end
        end

        local n = 0
        for _, root in ipairs(roots) do
            for _, d in ipairs(root:GetDescendants()) do
                local cls = d.ClassName
                if VALUE_CLASSES[cls] then
                    local v
                    if cls == "StringValue" then v = '"' .. tostring(d.Value):sub(1, 80) .. '"'
                    elseif cls == "ObjectValue" then v = d.Value and d.Value:GetFullName() or "nil"
                    else v = tostring(d.Value) end
                    table.insert(out, ("[%s] %s = %s"):format(cls, d:GetFullName(), v))
                end
                n = n + 1
                if n % 2000 == 0 then task.wait() end
            end
        end

        table.insert(out, "\n=== ATTRIBUTES ===")
        for i = 1, math.min(3, #roots) do
            for _, d in ipairs(roots[i]:GetDescendants()) do
                local ok, attrs = pcall(function() return d:GetAttributes() end)
                if ok and attrs and next(attrs) then
                    local p = {}
                    for k, v in pairs(attrs) do table.insert(p, k .. "=" .. tostring(v)) end
                    table.insert(out, ("[Attr] %s: {%s}"):format(d:GetFullName(), table.concat(p, ", ")))
                end
                n = n + 1
                if n % 2000 == 0 then task.wait() end
            end
        end
        return table.concat(out, "\n")
    end
end
