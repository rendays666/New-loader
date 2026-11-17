--[[ BOOTSTRAP — titik akhir: nyalakan pemroses antrean capture, pilih tab awal, tampilkan banner boot. ]]

return function(D)
    local S = D.State

    D.Capture.start() -- Heartbeat ringan; langsung return kalau antrean kosong

    D.UI.setMode(S.mode)
    D.UI.setTab("start")

    local function boot(text, color) D.Log.write(text, color or Color3.fromRGB(150, 200, 255), "boot") end
    boot("[BOOT] v" .. D.version .. " (" .. #D.loadOrder .. " modules)", Color3.fromRGB(150, 180, 255))
    boot("[BOOT] Start tab: 1) Scan  2) Record (optional)  3) Report")
    boot("[BOOT] Recording uses a light hook + queue, so game buttons keep working")
    boot("[BOOT] Tap ? on any button for help")
    boot("[BOOT] Reports include DIAGNOSTICS for debugging", Color3.fromRGB(200, 180, 120))

    D.UI.setStatus("Ready. Press Scan game to begin.")
    D.ready = true
    print(("[Dumper] READY v%s | PlaceId: %d | executor: %s"):format(
        D.version, game.PlaceId, D.Util.executorName()))
end
