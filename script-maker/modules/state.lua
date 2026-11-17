--[[ STATE — semua state mutable yang di-share antar modul.
     ATURAN: jangan simpan referensi D.State.allScripts / runtimeCapture.* / spy.* ke variabel
     lokal di level modul, karena tabelnya bisa diganti ulang (CLR / SCAN ulang / RT).
     Selalu akses lewat D.State.<nama> pada saat dipakai. ]]

return function(D)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    if not LocalPlayer then error("[Dumper] No LocalPlayer") end

    local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
        or LocalPlayer:WaitForChild("PlayerGui", 10)
    if not PlayerGui then error("[Dumper] No PlayerGui") end

    local function getGuiParent()
        if type(gethui) == "function" then
            local ok, h = pcall(gethui)
            if ok and typeof(h) == "Instance" then return h end
        end
        return PlayerGui
    end

    local env = (getgenv and getgenv()) or _G

    local rootEnabled = {}
    for _, r in ipairs(D.Config.SKIP_ROOTS) do rootEnabled[r.name] = true end

    -- Mode GUI diingat antar re-execute (simple untuk pemula, advanced untuk semua tool)
    local mode = env.__DUMPER_MODE
    if mode ~= "simple" and mode ~= "advanced" then mode = "simple" end

    D.State = {
        LocalPlayer = LocalPlayer,
        PlayerGui   = PlayerGui,
        GUI_PARENT  = getGuiParent(),

        mode = mode, -- "simple" | "advanced"
        dead = false, -- true setelah D.Shutdown (loop UI berhenti)

        -- opsi scan
        scanOptions = { decompile = false, bytecode = false, readCore = false },
        rootEnabled = rootEnabled,

        -- hasil scan
        allScripts = {},
        bigScripts = {},

        -- kontrol scan / render
        scanRunning = false,
        scanAbort   = false,
        filterToken = 0,
        renderToken = 0,

        -- flag runtime
        uiActive      = false,
        hkActive      = false, -- HK1: hook __namecall
        hk2Active     = false, -- HK2: hookfunction FireServer/InvokeServer
        passiveActive = false,
        capturing     = false, -- true selama salah satu dari HK1/HK2 aktif
        captureMethod = "auto", -- pilihan user: auto | hk2 | hk1
        captureUsing  = nil,    -- metode yang benar-benar dipakai (hk1 / hk2)

        -- remote spy (diisi/diubah oleh runtime/spy + ui/page_capture)
        spy = {
            blocked  = setmetatable({}, { __mode = "k" }), -- remote -> true (dibaca langsung oleh hook)
            ignored  = setmetatable({}, { __mode = "k" }), -- remote -> true
            paused   = false,
            template = 1,
        },

        -- koneksi umur panjang (diputus oleh D.Shutdown)
        conns = {},

        runtimeCapture = {
            fireServer = {},
            ui         = {},
            log        = {},
        },
    }

    -- Dipanggil loader saat script dijalankan ulang (atau tombol Unload): matikan instance lama
    -- sepenuhnya (flag hook dimatikan, koneksi diputus, GUI dihapus) supaya tidak ada capture ganda.
    function D.Shutdown()
        local S = D.State
        S.dead = true
        S.hkActive, S.hk2Active, S.capturing, S.uiActive, S.scanAbort = false, false, false, false, true
        for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
        S.conns = {}
        if D.Passive then pcall(D.Passive.stop) end
        if D.UIWatch then pcall(D.UIWatch.stop) end
        if D.UI and D.UI.gui then pcall(function() D.UI.gui:Destroy() end) end
    end
end
