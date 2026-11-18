--[[ BUILD/BRIEF_DATA — pengumpul + pengolah data untuk AI BRIEF (D.BriefData).
     Semua fungsi boleh yield (task.wait) → panggil dari task.spawn, bukan dari handler event langsung.

     dedupScripts()        → groups (nama+class+ukuran+hash isi), stats
     scanCalls(groups)     → isi group.calls + remoteSig (signature 1 contoh per remote)
     gather()              → { remotes, values, attrs } dari game tree (tanpa CoreGui dkk)
     remoteGroups(data)    → remote unik dikelompokkan per parent (path dinormalisasi)
     configEntries(data)   → entri config terdedup + terfilter kata kunci
     treeLines()           → pohon service 2-3 level, tanpa isi Backpack pemain
     uiGroups()            → tombol runtime dikelompokkan per menu
     normPath(path)        → "Players.<nama>.x" → "Players.*.x"
     matchKey(text, keys)  → true kalau salah satu kata kunci cocok (token pendek = harus sama persis) ]]

return function(D)
    local S, Cfg, U = D.State, D.Config, D.Util
    local B = Cfg.BRIEF
    local BD = {}
    D.BriefData = BD

    -- ── util kecil ──────────────────────────────────────────────────
    function BD.normPath(path)
        local rest = tostring(path):match("^Players%.[^%.]+(.*)$")
        if rest then return "Players.*" .. rest end
        return tostring(path)
    end

    local function split(path)
        local t = {}
        for seg in path:gmatch("[^%.]+") do t[#t + 1] = seg end
        return t
    end

    local function words(s)
        local spaced = s:gsub("(%l)(%u)", "%1 %2"):lower()
        local t = {}
        for w in spaced:gmatch("%a+") do t[#t + 1] = w end
        return t
    end

    -- Kata kunci <= 3 huruf harus cocok sebagai kata utuh ("cd", "hp", "xp"); lainnya boleh substring
    function BD.matchKey(text, keys)
        local lower = tostring(text):lower()
        local toks
        for _, k in ipairs(keys) do
            if #k <= 3 then
                toks = toks or words(tostring(text))
                for _, w in ipairs(toks) do if w == k then return k end end
            elseif lower:find(k, 1, true) then
                return k
            end
        end
        return nil
    end

    local function nameOf(rec)
        local ok, n = pcall(function() return rec.inst.Name end)
        if ok and type(n) == "string" then return n end
        return rec.path:match("([^%.]+)$") or rec.path
    end

    local function hashStr(s)
        local h1, h2 = 5381, 7919
        for i = 1, #s do
            local b = string.byte(s, i)
            h1 = (h1 * 33 + b) % 4294967291
            h2 = (h2 * 131 + b) % 4294967279
        end
        return h1 .. ":" .. h2
    end

    -- Pola path untuk grup identik: segmen yang beda antar anggota → "*"
    local function patternOf(paths)
        local segs = {}
        for i = 1, math.min(#paths, 300) do segs[i] = split(BD.normPath(paths[i])) end
        local base, out = segs[1], {}
        for k = 1, #base do
            local same = true
            for i = 2, #segs do
                if segs[i][k] ~= base[k] then same = false break end
            end
            out[k] = same and base[k] or "*"
        end
        return table.concat(out, ".")
    end

    -- ── 1. DEDUP SCRIPT ─────────────────────────────────────────────
    function BD.dedupScripts()
        local coarse, order = {}, {}
        for _, s in ipairs(S.allScripts) do
            local name = nameOf(s)
            local key = s.class .. "|" .. name .. "|" .. s.size
            local g = coarse[key]
            if not g then g = {}; coarse[key] = g; order[#order + 1] = key end
            g[#g + 1] = { rec = s, name = name }
        end

        local groups, hashed = {}, 0
        for _, key in ipairs(order) do
            local list = coarse[key]
            local buckets, border = {}, {}
            if #list == 1 then
                buckets.x, border[1] = list, "x"
            else
                for _, it in ipairs(list) do
                    local h = it.rec.src and hashStr(it.rec.src) or "-"
                    local b = buckets[h]
                    if not b then b = {}; buckets[h] = b; border[#border + 1] = h end
                    b[#b + 1] = it
                end
                hashed = hashed + 1
                if hashed % 8 == 0 then task.wait() end
            end
            for _, h in ipairs(border) do
                local items = buckets[h]
                local rep = items[1].rec
                for _, it in ipairs(items) do
                    if it.rec.src then rep = it.rec break end
                end
                local paths = {}
                for i, it in ipairs(items) do paths[i] = it.rec.path end
                groups[#groups + 1] = {
                    name = items[1].name, class = rep.class, size = rep.size, status = rep.status,
                    src = rep.src, count = #items, repPath = rep.path, paths = paths,
                    pattern = #items > 1 and patternOf(paths) or BD.normPath(rep.path),
                }
            end
        end
        table.sort(groups, function(a, b) return a.repPath < b.repPath end)

        -- "Gun 40->1, HATCHET 12->1": jumlah script asli → jumlah unik, per nama
        local byName, names = {}, {}
        for _, g in ipairs(groups) do
            local e = byName[g.name]
            if not e then e = { from = 0, to = 0 }; byName[g.name] = e; names[#names + 1] = g.name end
            e.from, e.to = e.from + g.count, e.to + 1
        end
        local saved = {}
        for _, n in ipairs(names) do
            local e = byName[n]
            if e.from > e.to then saved[#saved + 1] = { name = n, from = e.from, to = e.to } end
        end
        table.sort(saved, function(a, b)
            if (a.from - a.to) ~= (b.from - b.to) then return (a.from - a.to) > (b.from - b.to) end
            return a.name < b.name
        end)
        return groups, saved
    end

    -- ── 2. SIGNATURE REMOTE DARI SOURCE ─────────────────────────────
    local GENERIC = { remote = true, event = true, fn = true, func = true, r = true, self = true, v = true,
        obj = true, this = true, re = true, rf = true, e = true, f = true, x = true }

    local function captureArgs(line, from)
        local depth, args, cur, i, n, inStr = 0, {}, {}, from, #line, nil
        while i <= n do
            local c = line:sub(i, i)
            if inStr then
                cur[#cur + 1] = c
                if c == "\\" then
                    i = i + 1
                    cur[#cur + 1] = line:sub(i, i)
                elseif c == inStr then
                    inStr = nil
                end
            elseif c == '"' or c == "'" then
                inStr = c
                cur[#cur + 1] = c
            elseif c == "(" or c == "{" or c == "[" then
                depth = depth + 1
                cur[#cur + 1] = c
            elseif c == ")" or c == "}" or c == "]" then
                if depth == 0 and c == ")" then break end
                if depth > 0 then depth = depth - 1 end
                cur[#cur + 1] = c
            elseif c == "," and depth == 0 then
                args[#args + 1] = table.concat(cur)
                cur = {}
            else
                cur[#cur + 1] = c
            end
            i = i + 1
        end
        local last = table.concat(cur)
        if last:match("%S") then args[#args + 1] = last end
        for k, a in ipairs(args) do
            a = a:gsub("%s+", " "):match("^%s*(.-)%s*$")
            if #a > 22 then a = a:sub(1, 21) .. "…" end
            args[k] = a
        end
        return args
    end

    -- var → nama remote, dari "local x = ...:WaitForChild('Nama')" / "= a.b.Nama"
    local function buildAliases(src)
        local al = {}
        for line in src:gmatch("[^\n]+") do
            if line:find("=", 1, true) then
                local var, rhs = line:match("^%s*local%s+([%w_]+)%s*=%s*(.+)$")
                if not var then var, rhs = line:match("^%s*([%w_%.]+)%s*=%s*(.+)$") end
                if var and rhs then
                    local nm
                    for _, q in rhs:gmatch("()%a*Child%(%s*[\"']([^\"']+)[\"']") do nm = q end
                    if not nm and rhs:match("^[%w_%.]+%s*$") then nm = rhs:match("([%w_]+)%s*$") end
                    if nm and not al[var] then al[var] = nm end
                end
            end
        end
        return al
    end

    local function receiverName(rcv, aliases)
        local q = rcv:match("[\"']([^\"']+)[\"']%s*%)%s*$") or rcv:match("%[%s*[\"']([^\"']+)[\"']%s*%]%s*$")
        if q then return q, true end
        local chain = rcv:match("([%w_%.]+)%s*$")
        if not chain then return nil end
        local last = chain:match("([%w_]+)$")
        local a = aliases[chain] or aliases[last]
        if a then return a, true end
        return last, false
    end

    function BD.parseCalls(src)
        local aliases = buildAliases(src)
        local calls, n = {}, 0
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            n = n + 1
            if line:find("Server", 1, true) then
                local pos = 1
                while true do
                    local s, e, kind = line:find(":%s*([FI][a-z]+Server)%s*%(", pos)
                    if not s then break end
                    pos = e + 1
                    if kind == "FireServer" or kind == "InvokeServer" then
                        local name, resolved = receiverName(line:sub(1, s - 1), aliases)
                        if name then
                            calls[#calls + 1] = { name = name, resolved = resolved, kind = kind,
                                args = captureArgs(line, e + 1), line = n }
                        end
                    end
                end
            end
        end
        return calls
    end

    -- Isi group.calls (1 baris per remote per script) + remoteSig[nama] (1 contoh terbaik per remote)
    function BD.scanCalls(groups)
        local remoteSig, done = {}, 0
        for _, g in ipairs(groups) do
            g.calls = {}
            if g.src then
                local best, order = {}, {}
                for _, c in ipairs(BD.parseCalls(g.src)) do
                    local key = c.name
                    local cur = best[key]
                    if not cur then best[key] = c; order[#order + 1] = key
                    elseif #c.args > #cur.args then best[key] = c end
                end
                for _, key in ipairs(order) do
                    local c = best[key]
                    c.sig = table.concat(c.args, ", ")
                    g.calls[#g.calls + 1] = c
                    local rs = remoteSig[c.name]
                    if not rs or #c.args > rs.n then
                        remoteSig[c.name] = { sig = c.sig, n = #c.args, kind = c.kind, resolved = c.resolved }
                    end
                end
                table.sort(g.calls, function(a, b) return a.line < b.line end)
            end
            done = done + 1
            if done % 15 == 0 then task.wait() end
        end

        -- Fallback: argumen dari panggilan yang benar-benar terekam (Record game actions)
        for _, e in ipairs(S.runtimeCapture.fireServer) do
            if e.remote and not remoteSig[e.remote] and e.args then
                remoteSig[e.remote] = { sig = table.concat(e.args, ", "), n = #e.args, kind = e.method, runtime = true }
            end
        end
        return remoteSig
    end

    -- ── 3. GAME TREE: remote + value + attribute ───────────────────
    local SKIP_SERVICE = { CoreGui = true, CorePackages = true, RobloxReplicatedStorage = true,
        RobloxPluginGuiService = true, PluginGuiService = true }
    local VALUE_CLASSES = { StringValue = true, NumberValue = true, BoolValue = true, IntValue = true, ObjectValue = true }
    local VALUE_ROOTS = { ReplicatedStorage = true, Workspace = true, Lighting = true, StarterPlayer = true }
    local NO_ATTR = { Part = true, MeshPart = true, UnionOperation = true, Attachment = true, Decal = true,
        Texture = true, Weld = true, WeldConstraint = true, Motor6D = true, SpecialMesh = true, Sound = true,
        ParticleEmitter = true, Beam = true, Trail = true, Script = true, LocalScript = true, ModuleScript = true }

    function BD.gather()
        local d = { remotes = {}, values = {}, attrs = {}, instances = 0 }
        local n, attrN = 0, 0
        for _, svc in ipairs(game:GetChildren()) do
            local okName, svcName = pcall(function() return svc.Name end)
            if okName and not SKIP_SERVICE[svcName] then
                local ok, desc = pcall(svc.GetDescendants, svc)
                if ok and desc then
                    local valRoot = VALUE_ROOTS[svcName]
                    for _, o in ipairs(desc) do
                        n = n + 1
                        local cls = o.ClassName
                        if cls == "RemoteEvent" or cls == "RemoteFunction" or cls == "UnreliableRemoteEvent" then
                            d.remotes[#d.remotes + 1] = { class = cls, name = o.Name, path = U.safeFullName(o) }
                        elseif valRoot then
                            if VALUE_CLASSES[cls] then
                                local v
                                if cls == "StringValue" then v = '"' .. tostring(o.Value):sub(1, 40) .. '"'
                                elseif cls == "ObjectValue" then v = o.Value and U.safeFullName(o.Value) or "nil"
                                else v = tostring(o.Value) end
                                d.values[#d.values + 1] = { path = U.safeFullName(o), name = o.Name, type = cls, value = v }
                            end
                            if attrN < B.MAX_ATTR_SCAN and not NO_ATTR[cls] then
                                attrN = attrN + 1
                                local okA, attrs = pcall(o.GetAttributes, o)
                                if okA and attrs and next(attrs) then
                                    local path = U.safeFullName(o)
                                    for k, v in pairs(attrs) do
                                        local tv = typeof(v)
                                        local vs = tv == "string" and ('"' .. v:sub(1, 40) .. '"') or tostring(v)
                                        d.attrs[#d.attrs + 1] = { path = path .. "@" .. k, name = k, type = tv, value = vs }
                                    end
                                end
                            end
                        end
                        if n % 2000 == 0 then task.wait() end
                    end
                end
            end
        end
        d.instances = n
        return d
    end

    -- Remote unik: kunci = class + nama + parent ternormalisasi
    function BD.remoteGroups(data)
        local map, list = {}, {}
        for _, r in ipairs(data.remotes) do
            local parent = BD.normPath(r.path):match("^(.*)%.[^%.]+$") or "?"
            local key = r.class .. "|" .. r.name .. "|" .. parent
            local g = map[key]
            if g then g.count = g.count + 1
            else
                g = { class = r.class, name = r.name, parent = parent, count = 1 }
                map[key] = g
                list[#list + 1] = g
            end
        end
        table.sort(list, function(a, b)
            if a.parent ~= b.parent then return a.parent < b.parent end
            return a.name < b.name
        end)
        return list
    end

    -- Config: dedup path ternormalisasi+nilai, prioritas kata kunci (harga/cooldown/damage/rasio/limit)
    function BD.configEntries(data)
        local seen, key, other = {}, {}, {}
        local function add(e)
            local np = BD.normPath(e.path)
            local k = np .. "=" .. e.value
            local cur = seen[k]
            if cur then cur.count = cur.count + 1 return end
            cur = { path = np, value = e.value, type = e.type, count = 1 }
            seen[k] = cur
            if BD.matchKey(e.name, B.CONFIG_KEYS) or BD.matchKey(np, B.CONFIG_KEYS) then
                key[#key + 1] = cur
            else
                other[#other + 1] = cur
            end
        end
        for _, v in ipairs(data.values) do add(v) end
        for _, a in ipairs(data.attrs) do add(a) end
        table.sort(key, function(a, b) return a.path < b.path end)
        table.sort(other, function(a, b) return #a.path < #b.path end)
        return key, other
    end

    -- ── 4. TREE ─────────────────────────────────────────────────────
    local function tagOf(i)
        local c = i.ClassName
        if c == "LocalScript" or c == "ModuleScript" or c == "Script" then return " *" end
        if c == "RemoteEvent" or c == "RemoteFunction" or c == "UnreliableRemoteEvent" then return " !" end
        return ""
    end
    local CONTAINER = { Folder = true, Model = true, Configuration = true, ScreenGui = true, Frame = true,
        Tool = true, StarterGear = true, Backpack = false, PlayerScripts = true, StarterPlayerScripts = true,
        StarterCharacterScripts = true }

    local function walk(inst, depth, maxDepth, out, indent)
        local ok, kids = pcall(inst.GetChildren, inst)
        if not ok or not kids then return end
        local groups, order = {}, {}
        for _, c in ipairs(kids) do
            local key = c.Name .. "|" .. c.ClassName
            local g = groups[key]
            if g then g.count = g.count + 1
            else g = { first = c, count = 1 }; groups[key] = g; order[#order + 1] = g end
        end
        for i, g in ipairs(order) do
            if i > B.TREE_MAX_KIDS then
                out[#out + 1] = indent .. ("…+%d more"):format(#order - B.TREE_MAX_KIDS)
                break
            end
            local c = g.first
            out[#out + 1] = ("%s%s [%s]%s%s"):format(indent, c.Name, c.ClassName, tagOf(c),
                g.count > 1 and (" ×" .. g.count) or "")
            if depth < maxDepth and g.count == 1 and CONTAINER[c.ClassName] then
                walk(c, depth + 1, maxDepth, out, indent .. "  ")
            end
        end
    end

    function BD.treeLines()
        local out = {}
        local names = { "ReplicatedFirst", "ReplicatedStorage", "StarterPlayer", "StarterGui", "StarterPack",
            "Workspace", "Lighting", "Teams" }
        for _, name in ipairs(names) do
            local svc = game:FindFirstChild(name)
            if svc then
                out[#out + 1] = "[" .. name .. "]"
                walk(svc, 1, B.TREE_DEPTH[name] or 2, out, "  ")
            end
            task.wait()
        end
        local ok, plrs = pcall(function() return game:GetService("Players"):GetPlayers() end)
        if ok and plrs then out[#out + 1] = ("[Players] %d player(s) — isi Backpack/Character tidak ditampilkan"):format(#plrs) end
        return out
    end

    -- ── 5. RUNTIME UI → per menu ────────────────────────────────────
    function BD.uiGroups()
        local map, order = {}, {}
        local seenPath = {}
        for _, e in ipairs(S.runtimeCapture.ui) do
            if not seenPath[e.path] then
                seenPath[e.path] = true
                local rest = e.path:match("%.PlayerGui%.(.+)$") or e.path
                local segs = split(rest)
                local label = (e.text and e.text ~= "") and e.text:gsub("%s+", " ") or segs[#segs]
                local g = map[segs[1]]
                if not g then g = { key = segs[1], items = {}, seen = {}, segs = {} }; map[segs[1]] = g; order[#order + 1] = g end
                g.segs[#g.segs + 1] = { segs = segs, label = label }
            end
        end
        local out = {}
        for _, g in ipairs(order) do
            -- menu besar → pecah per anak langsung ScreenGui
            local uniq = {}
            for _, it in ipairs(g.segs) do uniq[it.label] = true end
            local nUniq = 0
            for _ in pairs(uniq) do nUniq = nUniq + 1 end
            local subs, subOrder = {}, {}
            if nUniq > 12 then
                for _, it in ipairs(g.segs) do
                    local sub = it.segs[2]
                    if sub and #it.segs > 2 then
                        if not subs[sub] then subs[sub] = {}; subOrder[#subOrder + 1] = sub end
                        table.insert(subs[sub], it.label)
                    end
                end
            end
            if #subOrder >= 2 then
                for _, sub in ipairs(subOrder) do
                    out[#out + 1] = { key = g.key .. "." .. sub, labels = subs[sub] }
                end
            else
                local labels = {}
                for _, it in ipairs(g.segs) do labels[#labels + 1] = it.label end
                out[#out + 1] = { key = g.key, labels = labels }
            end
        end
        -- label unik per grup (dedup nama), urutan kemunculan dipertahankan
        for _, g in ipairs(out) do
            local seen, uniqLabels = {}, {}
            for _, l in ipairs(g.labels) do
                if not seen[l] then seen[l] = true; uniqLabels[#uniqLabels + 1] = l end
            end
            g.labels = uniqLabels
        end
        return out
    end
end
