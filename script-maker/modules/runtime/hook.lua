--[[ RUNTIME/HOOK — pemasangan hook HK (namecall) dan UC (hookfunction).
     Hook TIDAK melakukan kerja berat: hanya D.Capture.enqueue. Lihat catatan di capture.lua.

     Aturan keras di dalam closure hook (jangan dilanggar saat edit):
       1. dilarang memanggil method Instance (x:Foo()) — pakai pcall(push, ...) saja
       2. method asli di-set ulang dengan setnamecallmethod sebelum meneruskan panggilan
       3. error di kode kita tidak boleh sampai membatalkan panggilan asli game
     Hook dipasang SEKALI per sesi executor (disimpan di getgenv().__DUMPER_HOOKBOX);
     re-execute script hanya mengganti box.state / box.push, tidak menumpuk hook baru.

     API: D.Hook.installHK() | D.Hook.patchUC() | D.Hook.status() | D.Hook.lastError ]]

return function(D)
    local S = D.State
    local H = { lastError = nil }
    D.Hook = H

    local env = (getgenv and getgenv()) or _G
    local box = env.__DUMPER_HOOKBOX
    if type(box) ~= "table" then
        box = { namecall = false, uc = {} }
        env.__DUMPER_HOOKBOX = box
    end
    box.uc = box.uc or {}
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
                            if push then pcall(push, self, method, table.pack(...)) end
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

    -- ── UC: hookfunction per class (fallback untuk Unreliable) ───────
    -- Aktif hanya kalau chip UC ON dan HK OFF (supaya tidak dobel).
    function H.patchUC()
        if type(hookfunction) ~= "function" then
            H.lastError = "hookfunction tidak tersedia di executor"
            return false
        end
        local checkC = checkcaller
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
                        if st and st.ucActive and not st.hkActive
                            and typeof(self) == "Instance" and not (checkC and checkC()) then
                            local push = box.push
                            if push then pcall(push, self, method, table.pack(...)) end
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

    function H.status()
        local ucList = {}
        for cls in pairs(box.uc) do ucList[#ucList + 1] = cls end
        table.sort(ucList)
        return {
            namecallInstalled = box.namecall == true,
            ucClasses = ucList,
            lastError = H.lastError,
        }
    end
end
