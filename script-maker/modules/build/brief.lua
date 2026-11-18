--[[ BUILD/BRIEF — D.Build.brief(): export ringkas untuk AI analyst (~15.000 karakter).
     Urutan: Header → 1 REMOTES → 2 CONFIG → 3 MECHANICS → 4 TREE → 5 API SURFACE → 6 RUNTIME UI → 9 DIAGNOSTICS
     (nomor 7-8 sengaja dilewati: tidak dipakai). Section 1,2,3 dan DIAGNOSTICS tidak pernah dipotong.
     Jika melebihi MAX_CHARS: API SURFACE dipotong dulu, lalu RUNTIME UI, lalu TREE.
     Harus dipanggil dari task.spawn (BD.* boleh yield). ]]

return function(D)
    local S, Cfg, U = D.State, D.Config, D.Util
    local B, BD = Cfg.BRIEF, D.BriefData
    D.Build = D.Build or {}

    local SEP = string.rep("=", 62)

    local function cut(s, n)
        if #s <= n then return s end
        return s:sub(1, n - 1) .. "…"
    end

    -- ── Header ──────────────────────────────────────────────────────
    local function header(groups, saved, nRemotes)
        local r, e, o, b, t = 0, 0, 0, 0, 0
        for _, s in ipairs(S.allScripts) do
            if s.status == "readable" then r = r + 1
            elseif s.status == "empty" then e = e + 1
            elseif s.status == "obf" then o = o + 1
            elseif s.status == "bcode" then b = b + 1
            elseif s.status == "truncated" then t = t + 1 end
        end
        local out = {
            SEP,
            "DUMPER v" .. D.version .. " — AI BRIEF",
            SEP,
            "Game: " .. U.getGameName() .. "  | PlaceId: " .. tostring(game.PlaceId) .. "  | JobId: " .. tostring(game.JobId),
            "Player: " .. S.LocalPlayer.Name .. "  | Executor: " .. U.executorName() .. "  | Generated: " .. os.date("%Y-%m-%d %H:%M:%S"),
            ("Scripts: total=%d unique=%d readable=%d empty=%d obf=%d bcode=%d trunc=%d | Remotes(unique)=%d"):format(
                #S.allScripts, #groups, r, e, o, b, t, nRemotes),
        }
        if #S.allScripts == 0 then
            out[#out + 1] = "NOTE: no scan results — REMOTES/CONFIG/TREE come from the live game tree, API SURFACE is empty."
        end
        local parts = {}
        for i = 1, math.min(#saved, 12) do
            parts[#parts + 1] = ("%s %d->%d"):format(saved[i].name, saved[i].from, saved[i].to)
        end
        out[#out + 1] = "Dedup: " .. (#parts > 0 and table.concat(parts, ", ") or "none")
        return out
    end

    -- ── 1. REMOTES ──────────────────────────────────────────────────
    local function remoteLine(g, sig)
        local isFn = g.class == "RemoteFunction"
        local tag = isFn and "[RemoteFunction]" or "[Remote]"
        local method = isFn and "InvokeServer" or "FireServer"
        local args
        if sig then
            method = sig.kind or method
            args = sig.sig ~= "" and sig.sig or ""
        else
            args = "?"
        end
        return ("%s %s:%s(%s)%s"):format(tag, g.name, method, args, g.count > 1 and (" ×" .. g.count) or "")
    end

    local function sectionRemotes(rgroups, remoteSig)
        local out = { SEP, "1. REMOTES — " .. #rgroups .. " unique (signature from 1 sample; ? = no call site found)", SEP }
        local lastParent
        local seenName = {}
        for _, g in ipairs(rgroups) do
            if g.parent ~= lastParent then
                out[#out + 1] = "@ " .. g.parent
                lastParent = g.parent
            end
            out[#out + 1] = "  " .. remoteLine(g, remoteSig[g.name])
            seenName[g.name] = true
        end
        -- remote yang terlihat di source/rekaman tapi tidak ada di tree (dibuat runtime)
        local extra = {}
        for name, sig in pairs(remoteSig) do
            if not seenName[name] and sig.resolved then extra[#extra + 1] = name end
        end
        table.sort(extra)
        if #extra > 0 then
            out[#out + 1] = "@ (referenced in code/recording, not found in tree)"
            for _, name in ipairs(extra) do
                local sig = remoteSig[name]
                out[#out + 1] = ("  [%s] %s:%s(%s)"):format(sig.kind == "InvokeServer" and "RemoteFunction" or "Remote",
                    name, sig.kind or "FireServer", sig.sig)
            end
        end
        return out
    end

    -- ── 2. CONFIG ───────────────────────────────────────────────────
    local function sectionConfig(data)
        local key, other = BD.configEntries(data)
        local out = { SEP, ("2. CONFIG — %d key values (+%d other)"):format(#key, #other), SEP }
        if #key == 0 and #other == 0 then
            out[#out + 1] = "(no Value objects / attributes found in ReplicatedStorage, Workspace, Lighting, StarterPlayer)"
            return out
        end
        for i, e in ipairs(key) do
            if i > B.MAX_CONFIG then
                out[#out + 1] = ("… +%d more key values omitted"):format(#key - B.MAX_CONFIG)
                break
            end
            out[#out + 1] = ("%s = %s (%s)%s"):format(e.path, e.value, e.type, e.count > 1 and (" ×" .. e.count) or "")
        end
        if #other > 0 then
            out[#out + 1] = "-- other (sample) --"
            for i = 1, math.min(#other, B.OTHER_CONFIG) do
                local e = other[i]
                out[#out + 1] = ("%s = %s (%s)"):format(e.path, e.value, e.type)
            end
            if #other > B.OTHER_CONFIG then
                out[#out + 1] = ("… +%d more"):format(#other - B.OTHER_CONFIG)
            end
        end
        return out
    end

    -- ── 3. MECHANICS SUMMARY ────────────────────────────────────────
    local function countHits(text, kws)
        local lower, n = text:lower(), 0
        for _, k in ipairs(kws) do
            local p = 1
            while true do
                local s, e = lower:find(k, p, true)
                if not s then break end
                n = n + 1
                p = e + 1
                if n > 400 then return n end
            end
        end
        return n
    end

    local function sectionMechanics(groups, rgroups, remoteSig, data)
        local out = { SEP, "3. MECHANICS SUMMARY (heuristic: keywords in remotes, script names/code, config)", SEP }
        local cfgKey = BD.configEntries(data)
        for _, sys in ipairs(B.SYSTEMS) do
            local rems, seen = {}, {}
            for _, g in ipairs(rgroups) do
                if not seen[g.name] and BD.matchKey(g.name, sys.kw) then
                    seen[g.name] = true
                    rems[#rems + 1] = g.name
                end
            end
            local best, bestScore = nil, 0
            for _, g in ipairs(groups) do
                local score = 0
                if BD.matchKey(g.name, sys.kw) then score = score + 30 end
                if g.src then score = score + countHits(g.src:sub(1, 60000), sys.kw) end
                if score > bestScore then best, bestScore = g, score end
            end
            local cfgN = 0
            for _, e in ipairs(cfgKey) do
                if BD.matchKey(e.path, sys.kw) then cfgN = cfgN + 1 end
            end
            local lines = {}
            if #rems > 0 then
                lines[#lines + 1] = "remotes: " .. table.concat(rems, ", ", 1, math.min(#rems, 8))
                    .. (#rems > 8 and (" (+" .. (#rems - 8) .. ")") or "")
            end
            if best and bestScore >= 8 then
                local info = ("main script: %s [%s%s]"):format(best.pattern, best.class, best.count > 1 and (" ×" .. best.count) or "")
                local callNames = {}
                for _, c in ipairs(best.calls or {}) do
                    if BD.matchKey(c.name, sys.kw) then callNames[#callNames + 1] = c.name end
                end
                if #callNames > 0 then info = info .. " → calls " .. table.concat(callNames, ", ", 1, math.min(#callNames, 4)) end
                lines[#lines + 1] = info
            end
            if cfgN > 0 then lines[#lines + 1] = ("config values: %d (see section 2)"):format(cfgN) end
            if #lines == 0 then
                out[#out + 1] = ("[%s] not detected"):format(sys.name)
            else
                out[#out + 1] = ("[%s] %s"):format(sys.name, lines[1])
                for i = 2, math.min(#lines, 3) do out[#out + 1] = "    " .. lines[i] end
            end
        end
        return out
    end

    -- ── 4. TREE ─────────────────────────────────────────────────────
    local function sectionTree(lines)
        local out = { SEP, "4. TREE (2-3 levels; * script, ! remote; per-player Backpack not listed)", SEP }
        for _, l in ipairs(lines) do out[#out + 1] = l end
        return out
    end

    -- ── 5. API SURFACE ──────────────────────────────────────────────
    local function sectionApi(groups, remoteSig)
        local out = { SEP, "5. API SURFACE (unique scripts only; one signature line per remote)", SEP }
        local any = false
        for _, g in ipairs(groups) do
            if g.calls and #g.calls > 0 then
                any = true
                out[#out + 1] = ("%s%s  [%s]"):format(g.pattern, g.count > 1 and ("  (×" .. g.count .. ")") or "", g.class)
                for _, c in ipairs(g.calls) do
                    out[#out + 1] = ("  %s:%s(%s)"):format(c.name, c.kind, c.sig)
                end
            end
        end
        if not any then
            out[#out + 1] = (#S.allScripts == 0) and "(no scan results — run Scan game first)" or "(no FireServer/InvokeServer call sites found in readable scripts)"
        end
        return out
    end

    -- ── 6. RUNTIME UI ───────────────────────────────────────────────
    local function sectionUI()
        local groups = BD.uiGroups()
        local total = #S.runtimeCapture.ui
        local out = { SEP, ("6. RUNTIME UI — %d buttons in %d menus"):format(total, #groups), SEP }
        if total == 0 then
            out[#out + 1] = "(not recorded — Watch → 'Record on-screen buttons' ON, then open the game's menus)"
            return out
        end
        for _, g in ipairs(groups) do
            local ex = {}
            for i = 1, math.min(#g.labels, 5) do ex[i] = cut(g.labels[i], 24) end
            out[#out + 1] = ("%s: %d items — e.g. %s%s"):format(g.key, #g.labels, table.concat(ex, ", "),
                #g.labels > 5 and ", …" or "")
        end
        return out
    end

    -- ── Rakit + budget + validasi ───────────────────────────────────
    local function size(parts)
        local n = 0
        for _, p in ipairs(parts) do
            if p then n = n + #table.concat(p, "\n") + 2 end
        end
        return n
    end

    -- Potong baris belakang section hingga muat; sisakan judul (3 baris) + catatan
    local function shrink(sec, keepLines, label)
        if not sec or #sec <= keepLines then return sec end
        local omitted = #sec - keepLines
        local out = {}
        for i = 1, keepLines do out[i] = sec[i] end
        out[#out + 1] = ("… (%d %s lines omitted to fit size budget)"):format(omitted, label)
        return out
    end

    function D.Build.brief()
        local groups, saved = BD.dedupScripts()
        local remoteSig = BD.scanCalls(groups)
        local data = BD.gather()
        local rgroups = BD.remoteGroups(data)
        local treeLines = BD.treeLines()

        local hdr = header(groups, saved, #rgroups)
        local secs = {
            remotes = sectionRemotes(rgroups, remoteSig),
            config = sectionConfig(data),
            mech = sectionMechanics(groups, rgroups, remoteSig, data),
            tree = sectionTree(treeLines),
            api = sectionApi(groups, remoteSig),
            ui = sectionUI(),
        }
        local diag = D.Build.diagnosticsBrief()
        local diagParts = {}
        for l in (diag .. "\n"):gmatch("([^\n]*)\n") do diagParts[#diagParts + 1] = l end

        local function parts()
            return { hdr, secs.remotes, secs.config, secs.mech, secs.tree, secs.api, secs.ui, diagParts }
        end

        local trimmed = {}
        local budget = B.MAX_CHARS
        -- potong berurutan: API SURFACE → RUNTIME UI → TREE (tidak pernah REMOTES/CONFIG/DIAGNOSTICS)
        for _, step in ipairs({ { "api", "API" }, { "ui", "UI" }, { "tree", "TREE" } }) do
            local over = size(parts()) - budget
            if over <= 0 then break end
            local sec = secs[step[1]]
            local have = 0
            for i = 4, #sec do have = have + #sec[i] + 1 end
            local keepChars = math.max(0, have - over - 80)
            local keep, acc = 3, 0
            for i = 4, #sec do
                acc = acc + #sec[i] + 1
                if acc > keepChars then break end
                keep = i
            end
            secs[step[1]] = shrink(sec, keep, step[2])
            if keep < #sec then trimmed[#trimmed + 1] = step[2] end
        end

        local function flatten(ps)
            local flat = {}
            for _, p in ipairs(ps) do flat[#flat + 1] = table.concat(p, "\n") end
            return table.concat(flat, "\n\n")
        end
        local text = flatten(parts())

        -- validasi
        local problems = {}
        local seenPath = {}
        for _, g in ipairs(groups) do
            if seenPath[g.pattern] and g.count == 1 then problems[#problems + 1] = "duplicate script path: " .. g.pattern end
            seenPath[g.pattern] = true
        end
        for _, g in ipairs(rgroups) do
            if not text:find(g.name, 1, true) then problems[#problems + 1] = "remote missing: " .. g.name end
        end
        for _, mark in ipairs({ "1. REMOTES", "2. CONFIG", "3. MECHANICS", "4. TREE", "9. DIAGNOSTICS" }) do
            if not text:find(mark, 1, true) then problems[#problems + 1] = "section missing: " .. mark end
        end

        hdr[#hdr + 1] = ("Size: %d chars (limit %d)%s | %s"):format(#text, budget,
            #trimmed > 0 and (" trimmed: " .. table.concat(trimmed, ", ")) or "",
            #problems > 0 and ("VALIDATION: " .. table.concat(problems, "; ", 1, math.min(#problems, 8))) or "validation OK")
        text = flatten(parts())
        D.Log.write(("[BRIEF] %d chars, %d unique scripts, %d unique remotes%s"):format(#text, #groups, #rgroups,
            #problems > 0 and (", " .. #problems .. " validation problem(s)") or ""), Cfg.COLOR.info, "brief")
        return text
    end
end
