--[[ CODEGEN — ubah satu panggilan remote yang tertangkap menjadi kode Lua siap pakai.
     (diadaptasi dari NetScope). Fungsi murni, dipanggil dari UI thread — BUKAN dari dalam hook.
     API: D.Codegen.generate(entry, templateName) | D.Codegen.templates | D.Codegen.pathOf(inst)
     entry = { inst = Instance, method = "FireServer"|"InvokeServer", raw = table.pack(args) } ]]

return function(D)
    local S = D.State
    local G = {}
    D.Codegen = G

    G.templates = { "simple", "advanced", "debug" }

    local KEYWORDS = {}
    for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while continue"):gmatch("%a+") do
        KEYWORDS[w] = true
    end

    local function isIdent(s)
        return type(s) == "string" and s:match("^[%a_][%w_]*$") ~= nil and not KEYWORDS[s]
    end

    local function fmtNum(n)
        if n ~= n then return "0/0" end
        if n == math.huge then return "math.huge" end
        if n == -math.huge then return "-math.huge" end
        if n % 1 == 0 and math.abs(n) < 1e15 then return ("%d"):format(n) end
        return ("%.14g"):format(n)
    end

    function G.pathOf(inst)
        if typeof(inst) ~= "Instance" then return "nil" end
        local chain, cur = {}, inst
        local lp = S.LocalPlayer
        while cur and cur ~= game and cur ~= lp do
            table.insert(chain, 1, cur)
            cur = cur.Parent
        end
        local out
        if cur == lp then
            out = 'game:GetService("Players").LocalPlayer'
        elseif cur == game then
            local first = table.remove(chain, 1)
            if not first then return "game" end
            local isService = pcall(game.GetService, game, first.ClassName)
            if isService then
                out = ("game:GetService(%q)"):format(first.ClassName)
            else
                out = ("game:WaitForChild(%q)"):format(first.Name)
            end
        else
            return "nil --[[ instance not in game ]]"
        end
        for _, c in ipairs(chain) do
            out = out .. (":WaitForChild(%q)"):format(c.Name)
        end
        return out
    end

    local function ser(v, depth, seen, ind)
        local t = typeof(v)
        if t == "string" then return ("%q"):format(v)
        elseif t == "number" then return fmtNum(v)
        elseif t == "boolean" or t == "nil" then return tostring(v)
        elseif t == "Instance" then return G.pathOf(v)
        elseif t == "table" then
            if seen[v] then return "nil --[[ cyclic ]]" end
            if depth > 6 then return "{}" end
            local n = 0
            for _ in pairs(v) do n = n + 1 end
            if n == 0 then return "{}" end
            seen[v] = true
            local pad, items = ind .. "\t", {}
            if n == #v then
                for i = 1, #v do items[#items + 1] = pad .. ser(v[i], depth + 1, seen, pad) end
            else
                for k, val in pairs(v) do
                    local ks = isIdent(k) and k or ("[" .. ser(k, depth + 1, seen, pad) .. "]")
                    items[#items + 1] = pad .. ks .. " = " .. ser(val, depth + 1, seen, pad)
                end
            end
            seen[v] = nil
            return "{\n" .. table.concat(items, ",\n") .. "\n" .. ind .. "}"
        elseif t == "Vector3" then
            return ("Vector3.new(%s, %s, %s)"):format(fmtNum(v.X), fmtNum(v.Y), fmtNum(v.Z))
        elseif t == "Vector2" then
            return ("Vector2.new(%s, %s)"):format(fmtNum(v.X), fmtNum(v.Y))
        elseif t == "CFrame" then
            local c = { v:GetComponents() }
            for i, n in ipairs(c) do c[i] = fmtNum(n) end
            return "CFrame.new(" .. table.concat(c, ", ") .. ")"
        elseif t == "Color3" then
            return ("Color3.new(%s, %s, %s)"):format(fmtNum(v.R), fmtNum(v.G), fmtNum(v.B))
        elseif t == "UDim2" then
            return ("UDim2.new(%s, %s, %s, %s)"):format(fmtNum(v.X.Scale), fmtNum(v.X.Offset),
                fmtNum(v.Y.Scale), fmtNum(v.Y.Offset))
        elseif t == "UDim" then
            return ("UDim.new(%s, %s)"):format(fmtNum(v.Scale), fmtNum(v.Offset))
        elseif t == "BrickColor" then
            return ("BrickColor.new(%q)"):format(v.Name)
        elseif t == "EnumItem" or t == "Enum" then
            return tostring(v)
        end
        return "nil --[[ " .. t .. " ]]"
    end
    G.serialize = function(v) return ser(v, 0, {}, "") end

    local function argsBlock(raw)
        if raw.n == 0 then return "local args = {}" end
        local seen, items = {}, {}
        for i = 1, raw.n do items[i] = "\t" .. ser(raw[i], 0, seen, "\t") end
        return "local args = {\n" .. table.concat(items, ",\n") .. "\n}"
    end

    local function callExpr(e)
        local a = e.raw.n == 0 and "" or ("unpack(args, 1, %d)"):format(e.raw.n)
        return ("remote:%s(%s)"):format(e.method, a)
    end

    function G.generate(e, tpl)
        local remotePath = G.pathOf(e.inst)
        local lines
        if tpl == "advanced" then
            lines = {
                "local remote = " .. remotePath,
                argsBlock(e.raw),
                "",
                "local ok, result = pcall(function()",
                "\treturn " .. callExpr(e),
                "end)",
                "if not ok then warn(result) end",
            }
        elseif tpl == "debug" then
            lines = { "local remote = " .. remotePath, argsBlock(e.raw) }
            if e.raw.n > 0 then
                lines[#lines + 1] = ("for i = 1, %d do print(i, typeof(args[i]), args[i]) end"):format(e.raw.n)
            end
            lines[#lines + 1] = 'print("Calling", remote:GetFullName())'
            lines[#lines + 1] = "local result = table.pack(" .. callExpr(e) .. ")"
            lines[#lines + 1] = 'print("Returned", result.n, unpack(result, 1, result.n))'
        else
            lines = { "local remote = " .. remotePath, argsBlock(e.raw), callExpr(e) }
        end
        return table.concat(lines, "\n")
    end
end
