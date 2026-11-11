--[[ RUNTIME/HOOK — pemasangan hook pencatat FireServer/InvokeServer.

     Dua mekanisme berbeda (chip terpisah, jangan disamakan):
       HK  = hook metamethod __namecall (menangkap semua `remote:FireServer(...)`).
       HK2 = hookfunction langsung pada method C: RemoteEvent.FireServer,
             RemoteFunction.InvokeServer, UnreliableRemoteEvent.FireServer.
             Tidak menyentuh __namecall sama sekali.
       UC  = alias HK2 (memakai hook fungsi yang sama) — dipertahankan untuk kompatibilitas.
     Prioritas: kalau HK ON, HK2/UC diam (supaya satu panggilan tidak tercatat dua kali).

     Aturan keras di dalam closure hook (jangan dilanggar saat edit):
       1. dilarang memanggil method Instance (x:Foo()) — pakai pcall(push, ...) saja
       2. (HK) method asli di-set ulang dengan setnamecallmethod sebelum meneruskan panggilan
       3. error di kode kita tidak boleh sampai membatalkan panggilan asli game
     Hook dipasang SEKALI per sesi executor (disimpan di getgenv().__DUMPER_HOOKBOX);
     re-execute script hanya mengganti box.state / box.push, tidak menumpuk hook baru.
     Hook tidak bisa dilepas — "mati" artinya closure langsung meneruskan ke fungsi asli.

     API: D.Hook.installHK() | installHK2() | patchUC() | status() | lastError ]]

return function(D)
    local S = D.State
    local H = { lastError = nil, hk2Failed = {} }
    D.Hook = H

    local env = (getgenv and getgenv()) or _G
    local box = env.__DUMPER_HOOKBOX
    if type(box) ~= "table" then
        box = { namecall = false }
        env.__DUMPER_HOOKBOX = box
    end
    -- box.fn = hook fungsi (HK2/UC). Nama baru sengaja berbeda dari versi lama (box.uc) supaya
    -- hook lama dari sesi sebelumnya (logika lama) tidak ikut terpakai.
    box.fn = box.fn or {}
    box.state = S                    -- state run yang sedang aktif
    box.push  = D.Capture.enqueue    -- tujuan capture run yang sedang aktif

    local function safeClosure(fn)
        if type(newcclosure) == "function" then
            local ok, r = pcall(newcclosure, fn)
            if ok then return r end
        end
        return fn
    end

    -- ── HK: hook __namecall ──────────────────────────────────────────
    function H.installHK()
        if box.namecall then return true end
        H.lastError = nil
        if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
            H.lastError = "hookmetamethod/getnamecallmethod tidak tersedia di executor"
            return false
        end
        local setNC, checkC = setnamecallmethod, checkcaller

        local ok, err = pcall(function()
            local old
            old = hookmetamethod(game, "__namecall", safeClosure(function(self, ...)
                local st = box.state
                if st and st.hkActive then
                    local method = getnamecallmethod()
                    if method == "FireServer" or method == "InvokeServer" then
                        if typeof(self) == "Instance" and not (checkC and checkC()) then
                            local push = box.push
                            if push then pcall(push, self, method, table.pack(...), "HK") end
                        end
                    end
                    -- pulihkan method asli supaya old() memanggil method yang benar
                    if setNC and method then setNC(method) end
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

    -- ── HK2 / UC: hookfunction per class ─────────────────────────────
    local FN_TARGETS = {
        { cls = "RemoteEvent",           method = "FireServer"   },
        { cls = "RemoteFunction",        method = "InvokeServer" },
        { cls = "UnreliableRemoteEvent", method = "FireServer"   }, -- tidak ada di semua versi
    }

    -- Idempoten: hanya memasang class yang belum terpasang (class yang gagal dicoba lagi).
    -- Sukses = RemoteEvent.FireServer terpasang; class lain best-effort.
    local function installFnHooks()
        H.lastError = nil
        H.hk2Failed = {}
        if type(hookfunction) ~= "function" then
            H.lastError = "hookfunction tidak tersedia di executor"
            return false
        end
        local checkC = checkcaller

        for _, tgt in ipairs(FN_TARGETS) do
            if not box.fn[tgt.cls] then
                local ok, err = pcall(function()
                    local inst = Instance.new(tgt.cls)
                    local fn = inst[tgt.method]
                    inst:Destroy()
                    if type(fn) ~= "function" then
                        error(tgt.method .. " bukan function")
                    end

                    local method = tgt.method
                    local old
                    old = hookfunction(fn, safeClosure(function(self, ...)
                        local st = box.state
                        -- HK (namecall) punya prioritas; HK2/UC hanya mencatat kalau HK mati
                        if st and not st.hkActive and (st.hk2Active or st.ucActive) then
                            if typeof(self) == "Instance" and not (checkC and checkC()) then
                                local push = box.push
                                if push then
                                    pcall(push, self, method, table.pack(...),
                                        st.hk2Active and "HK2" or "UC")
                                end
                            end
                        end
                        return old(self, ...)
                    end))
                end)
                if ok then
                    box.fn[tgt.cls] = true
                else
                    H.hk2Failed[#H.hk2Failed + 1] = tgt.cls .. ": " .. tostring(err):sub(1, 100)
                end
            end
        end

        if not box.fn.RemoteEvent then
            H.lastError = "hook RemoteEvent.FireServer gagal — " .. table.concat(H.hk2Failed, "; ")
            return false
        end
        if #H.hk2Failed > 0 then
            H.lastError = "sebagian class gagal (tidak fatal): " .. table.concat(H.hk2Failed, "; ")
        end
        return true
    end

    function H.installHK2() return installFnHooks() end
    function H.patchUC()    return installFnHooks() end

    function H.status()
        local fnList = {}
        for cls in pairs(box.fn) do fnList[#fnList + 1] = cls end
        table.sort(fnList)
        return {
            namecallInstalled = box.namecall == true,
            fnClasses = fnList,          -- class yang sudah di-hook (HK2/UC)
            fnFailed = H.hk2Failed,
            lastError = H.lastError,
        }
    end
end
