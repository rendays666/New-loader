--[[ STATE — semua state mutable yang di-share antar modul.
     ATURAN: jangan simpan referensi D.State.allScripts / runtimeCapture.* ke variabel
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

    local rootEnabled = {}
    for _, r in ipairs(D.Config.SKIP_ROOTS) do rootEnabled[r.name] = true end

    D.State = {
        LocalPlayer = LocalPlayer,
        PlayerGui   = PlayerGui,
        GUI_PARENT  = getGuiParent(),

        -- opsi scan (chip DC / BC / RC)
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

        -- flag runtime (chip UI / HK / UC / tombol RUN)
        uiActive      = false,
        hkActive      = false,
        ucActive      = false,
        passiveActive = false,

        -- koneksi umur panjang (diputus oleh D.Shutdown)
        conns = {},

        runtimeCapture = {
            fireServer = {},
            ui         = {},
            log        = {},
        },
    }

    -- Dipanggil loader saat script dijalankan ulang: matikan instance lama sepenuhnya
    -- (flag hook dimatikan, koneksi diputus, GUI dihapus) supaya tidak ada capture ganda.
    function D.Shutdown()
        local S = D.State
        S.hkActive, S.ucActive, S.uiActive, S.scanAbort = false, false, false, true
        for _, c in ipairs(S.conns) do pcall(function() c:Disconnect() end) end
        S.conns = {}
        if D.Passive then pcall(D.Passive.stop) end
        if D.UIWatch then pcall(D.UIWatch.stop) end
        if D.UI and D.UI.gui then pcall(function() D.UI.gui:Destroy() end) end
    end
end
