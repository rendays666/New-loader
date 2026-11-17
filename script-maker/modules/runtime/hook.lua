--[[
    D.Hook — v15 (HK1 + HK2)

    HK1  : hookmetamethod(__namecall)          — cepat, tapi sebagian game mendeteksinya
            (detector namecallInstance / Error 267)
    HK2  : hookfunction(C method) per class    — "Stealth"
            Hanya menyentuh FireServer/InvokeServer. __namecall tetap original.
    (UC versi lama DIHAPUS: ia meng-hookfunction fungsi C yang sama persis dengan HK2.)

    Hanya SATU metode aktif pada satu waktu (flag S.hkActive / S.hk2Active).
    Hook tetap terpasang setelah dimatikan (tidak bisa di-unhook dengan aman); flag mati = lewat langsung.

    ATURAN KERAS di dalam hook: jangan panggil method Instance (GetFullName/IsA/...) — itu me-reset
    namecall method dan merusak panggilan asli game. Hanya: getnamecallmethod, typeof, table.pack,
    pcall(push), setnamecallmethod. Semua kerja berat ada di D.Capture (Heartbeat).

    Block: kalau S.spy.blocked[remote] = true, hook mengembalikan nil dan panggilan TIDAK sampai ke server
    (hanya selama capture aktif).

    API: Hook.start(method) -> ok, usedOrError | Hook.stop() | Hook.supports() | Hook.status()
         Hook.installHK1() | Hook.installHK2()
]]

return function(D)
    local S = D.State
    local H = { lastError = nil }
    D.Hook = H

    -- Kotak hook per-versi: hook lama (v14) memegang box lama yang statenya sudah mati → tidak aktif.
    local env = (getgenv and getgenv()) or _G
    local box = env.__DUMPER_HOOKBOX15
    if type(box) ~= "table" then
        box = { namecall = false, namecall2 = false, hk2 = {} }
        env.__DUMPER_HOOKBOX15 = box
    end
    box.hk2   = box.hk2 or {}
    box.state = S               -- hook yang sudah terpasang selalu membaca state instance terbaru
    box.push  = D.Capture.enqueue

    local function safeClosure(fn)
        if type(newcclosure) == "function" then
            local ok, r = pcall(newcclosure, fn)
            if ok then return r end
        end
        return fn
    end

    local function pushCall(self, method, args)
        local push = box.push
        if push then push(self, method, args) end
    end

    function H.supports()
        return {
            hk1 = type(hookmetamethod) == "function" and type(getnamecallmethod) == "function",
            hk2 = type(hookfunction) == "function",
        }
    end

    -- ── HK1: __namecall ─────────────────────────────────────────────
    function H.installHK1()
        if box.namecall then return true end
        if not H.supports().hk1 then
            H.lastError = "hookmetamethod/getnamecallmethod not available in this executor"
            return false
        end

        local setNC, checkC = setnamecallmethod, checkcaller
        local ok, err = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", safeClosure(function(self, ...)
                local st = box.state
                if st and st.hkActive then
                    local method = getnamecallmethod()
                    if (method == "FireServer" or method == "InvokeServer")
                        and typeof(self) == "Instance"
                        and not (checkC and checkC()) then
                        local spy = st.spy
                        if spy and spy.blocked[self] then return nil end
                        pcall(pushCall, self, method, table.pack(...))
                        if setNC then pcall(setNC, method) end
                    end
                end
                return old(self, ...)
            end))
        end)

        if ok then
            box.namecall = true
            return true
        end
        H.lastError = "hookmetamethod failed: " .. tostring(err)
        return false
    end

    -- ── HK2: hookfunction pada method C FireServer/InvokeServer ─────
    local HK2_TARGETS = {
        { cls = "RemoteEvent",           method = "FireServer"   },
        { cls = "RemoteFunction",        method = "InvokeServer" },
        { cls = "UnreliableRemoteEvent", method = "FireServer"   },
    }

    function H.installHK2()
        if box.namecall2 then return true end
        if not H.supports().hk2 then
            H.lastError = "hookfunction not available in this executor"
            return false
        end

        local checkC = checkcaller
        local hooked = 0

        for _, tgt in ipairs(HK2_TARGETS) do
            if box.hk2[tgt.cls] then
                hooked = hooked + 1
            else
                local ok, err = pcall(function()
                    local inst = Instance.new(tgt.cls)
                    local fn = inst[tgt.method]
                    inst:Destroy()
                    if type(fn) ~= "function" then error(tgt.method .. " is not a function") end

                    local method = tgt.method
                    local old
                    old = hookfunction(fn, safeClosure(function(self, ...)
                        local st = box.state
                        if st and st.hk2Active
                            and typeof(self) == "Instance"
                            and not (checkC and checkC()) then
                            local spy = st.spy
                            if spy and spy.blocked[self] then return nil end
                            pcall(pushCall, self, method, table.pack(...))
                        end
                        return old(self, ...)
                    end))
                end)

                if ok then
                    box.hk2[tgt.cls] = true
                    hooked = hooked + 1
                elseif tgt.cls ~= "UnreliableRemoteEvent" then
                    -- UnreliableRemoteEvent tidak ada di semua game/executor; bukan error
                    H.lastError = ("HK2 %s failed: %s"):format(tgt.cls, tostring(err))
                end
            end
        end

        if hooked > 0 then
            box.namecall2 = true
            return true
        end
        H.lastError = H.lastError or "HK2 could not hook any class"
        return false
    end

    -- ── Start / stop (dipakai GUI) ──────────────────────────────────
    function H.stop()
        S.hkActive, S.hk2Active, S.capturing = false, false, false
        S.captureUsing = nil
    end

    -- method: "auto" | "hk2" | "hk1". Return ok, metodeDipakai | pesanError
    function H.start(method)
        method = method or S.captureMethod or "auto"
        S.captureMethod = method
        H.stop()

        local using
        if method == "hk1" then
            if H.installHK1() then using = "hk1" end
        elseif method == "hk2" then
            if H.installHK2() then using = "hk2" end
        else
            if H.installHK2() then using = "hk2"
            elseif H.installHK1() then using = "hk1" end
        end
        if not using then
            return false, H.lastError or "no capture method available"
        end

        S.hkActive, S.hk2Active = (using == "hk1"), (using == "hk2")
        S.capturing, S.captureUsing = true, using
        D.Capture.start()
        D.Log.write("[CAPTURE] ✓ recording (" .. using .. ")", D.Config.COLOR.ok, "hook")
        return true, using
    end

    function H.status()
        local hk2List = {}
        for cls in pairs(box.hk2) do hk2List[#hk2List + 1] = cls end
        table.sort(hk2List)
        return {
            namecallInstalled = box.namecall  == true,
            hk2Installed      = box.namecall2 == true,
            hk2Classes        = hk2List,
            active            = S.captureUsing,
            lastError         = H.lastError,
        }
    end
end
