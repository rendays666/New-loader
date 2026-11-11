--[[
    D.Hook — v14.1 (HK1 + HK2 + UC)

    HK1  : hookmetamethod(__namecall)         — CEPAT, MUDAH DIDETEKSI
            → JANGAN dipakai kalau game punya detector namecallInstance (Error 267)
    HK2  : hookfunction(C method) per class    — STEALTH
            → Hanya sentuh FireServer/InvokeServer C method.
            → __namecall tetap original → bypass detector namecallInstance.
    UC   : hookfunction per class              — fallback (Unreliable / executor tanpa metamethod)

    Mutual exclusion (di-capture otomatis):
      HK1 ON  → HK2 & UC idle (skip capture)
      HK2 ON  → UC idle
      UC ON   → jalan hanya kalau HK1 & HK2 OFF

    API: D.Hook.installHK() | D.Hook.installHK2() | D.Hook.patchUC() | D.Hook.status()

    Recursion guard: kalau D.Capture.enqueue memicu namecall/FireServer lagi,
    hook akan fast-path ke fungsi asli tanpa rekursi.
]]

return function(D)
    local S = D.State
    local H = { lastError = nil }
    D.Hook = H

    local env = (getgenv and getgenv()) or _G
    local box = env.__DUMPER_HOOKBOX
    if type(box) ~= "table" then
        box = { namecall = false, namecall2 = false, uc = {}, hk2 = {} }
        env.__DUMPER_HOOKBOX = box
    end
    box.uc   = box.uc   or {}
    box.hk2  = box.hk2  or {}
    box.state = S
    box.push  = D.Capture.enqueue

    local function safeClosure(fn)
        if type(newcclosure) == "function" then
            local ok, r = pcall(newcclosure, fn)
            if ok then return r end
        end
        return fn
    end

    -- ────────────────────────────────────────────────────────────────
    -- HK1: hook __namecall (metamethod) — TERDETEKSI namecallInstance
    -- ────────────────────────────────────────────────────────────────
    function H.installHK()
        if box.namecall then return true end
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
            H.lastError = "hookmetamethod/getnamecallmethod tidak tersedia di executor"
            return false
        end

        local setNC, checkC = setnamecallmethod, checkcaller
        local inHook = false

        local ok, err = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", safeClosure(function(self, ...)
                if inHook then
                    return old(self, ...)
                end

                local st = box.state
                if st and st.hkActive then
                    local method
                    pcall(function() method = getnamecallmethod() end)

                    if method == "FireServer" or method == "InvokeServer" then
                        if typeof(self) == "Instance"
                            and not (checkC and checkC()) then
                            inHook = true
                            local args = table.pack(...)
                            if box.push then
                                pcall(box.push, self, method, args)
                            end
                            inHook = false
                        end
                    end

                    if setNC and method then
                        pcall(setNC, method)
                    end
                end

                return old(self, ...)
            end))
        end)

        if ok then
            box.namecall = true
            return true
        end
        H.lastError = "hookmetamethod gagal: " .. tostring(err)
        return false
    end

    -- ────────────────────────────────────────────────────────────────
    -- HK2: STEALTH hook — hookfunction C method FireServer/InvokeServer
    -- Tidak menyentuh __namecall → bypass namecallInstance detector
    -- ────────────────────────────────────────────────────────────────
    function H.installHK2()
        if box.namecall2 then return true end
        if type(hookfunction) ~= "function" then
            H.lastError = "hookfunction tidak tersedia di executor"
            return false
        end

        local checkC = checkcaller
        local inHook = false
        local hooked = 0

        local targets = {
            { cls = "RemoteEvent",           method = "FireServer"   },
            { cls = "RemoteFunction",        method = "InvokeServer" },
            { cls = "UnreliableRemoteEvent", method = "FireServer"   },
        }

        for _, tgt in ipairs(targets) do
            if not box.hk2[tgt.cls] then
                local ok, err = pcall(function()
                    local okNew, inst = pcall(Instance.new, tgt.cls)
                    if not okNew then
                        error("Instance.new(" .. tgt.cls .. "): " .. tostring(inst))
                    end

                    local fn = inst[tgt.method]
                    inst:Destroy()

                    if type(fn) ~= "function" then
                        error(tgt.method .. " bukan function")
                    end

                    local old
                    old = hookfunction(fn, safeClosure(function(self, ...)
                        local st = box.state
                        if st and st.hk2Active and not st.hkActive
                            and not inHook
                            and typeof(self) == "Instance"
                            and not (checkC and checkC()) then
                            inHook = true
                            local args = table.pack(...)
                            if box.push then
                                pcall(box.push, self, tgt.method, args)
                            end
                            inHook = false
                        end
                        return old(self, ...)
                    end))
                end)

                if ok then
                    box.hk2[tgt.cls] = true
                    hooked = hooked + 1
                elseif tgt.cls ~= "UnreliableRemoteEvent" then
                    -- UnreliableRemoteEvent tidak selalu ada; jangan dianggap error
                    H.lastError = ("HK2 %s gagal: %s"):format(tgt.cls, tostring(err))
                end
            else
                hooked = hooked + 1
            end
        end

        if hooked > 0 then
            box.namecall2 = true
            return true
        end
        H.lastError = H.lastError or "HK2 tidak bisa hook satu class pun"
        return false
    end

    -- ────────────────────────────────────────────────────────────────
    -- UC: hookfunction per class — fallback (Unreliable / executor lain)
    -- ────────────────────────────────────────────────────────────────
    function H.patchUC()
        if type(hookfunction) ~= "function" then
            H.lastError = "hookfunction tidak tersedia di executor"
            return false
        end

        local checkC = checkcaller
        local inHook = false
        local classes = { "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent" }
        local usable = 0

        for _, cls in ipairs(classes) do
            if box.uc[cls] then
                usable = usable + 1
            else
                local ok, err = pcall(function()
                    local method = (cls == "RemoteFunction") and "InvokeServer" or "FireServer"
                    local inst = Instance.new(cls)
                    local fn = inst[method]
                    inst:Destroy()

                    local old
                    old = hookfunction(fn, safeClosure(function(self, ...)
                        local st = box.state
                        if st and st.ucActive and not st.hkActive and not st.hk2Active
                            and not inHook
                            and typeof(self) == "Instance"
                            and not (checkC and checkC()) then
                            inHook = true
                            local args = table.pack(...)
                            if box.push then
                                pcall(box.push, self, method, args)
                            end
                            inHook = false
                        end
                        return old(self, ...)
                    end))
                end)

                if ok then
                    box.uc[cls] = true
                    usable = usable + 1
                else
                    H.lastError = ("UC %s gagal: %s"):format(cls, tostring(err))
                end
            end
        end
        return usable > 0
    end

    -- ────────────────────────────────────────────────────────────────
    -- Status
    -- ────────────────────────────────────────────────────────────────
    function H.status()
        local ucList, hk2List = {}, {}
        for cls in pairs(box.uc)  do ucList[#ucList + 1]   = cls end
        for cls in pairs(box.hk2) do hk2List[#hk2List + 1] = cls end
        table.sort(ucList)
        table.sort(hk2List)

        return {
            namecallInstalled = box.namecall  == true,
            hk2Installed      = box.namecall2 == true,
            hk2Classes        = hk2List,
            ucClasses         = ucList,
            lastError         = H.lastError,
        }
    end
end
