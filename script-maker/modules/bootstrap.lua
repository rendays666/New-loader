--[[ BOOTSTRAP — titik akhir: nyalakan pemroses antrean capture, tampilkan banner boot. ]]

return function(D)
    local COLOR = D.Config.COLOR

    D.Capture.start() -- Heartbeat ringan; langsung return kalau antrean kosong

    local function boot(text, color) D.Log.write(text, color or Color3.fromRGB(150, 200, 255), "boot") end
    boot("[BOOT] v" .. D.version .. " — modular (" .. #D.loadOrder .. " module)", Color3.fromRGB(150, 180, 255))
    boot("[BOOT] Chip DC/BC/RC OFF = anti-crash")
    boot("[BOOT] Chip UI/HK/HK2/UC = rekam runtime (bukan scan)")
    boot("[BOOT] HK = hook __namecall, HK2 = hook fungsi langsung (cara beda)")
    boot("[BOOT] HK prioritas: HK ON → HK2/UC diam. Coba HK2 kalau HK bermasalah")
    boot("[BOOT] Tahan chip 0.5 dtk = info (mobile)")
    boot("[BOOT] SMART & FULL menyertakan snapshot + DIAGNOSTICS", Color3.fromRGB(200, 180, 120))

    D.UI.setStatus("Ready.")
    D.ready = true
    print(("[Dumper] READY v%s | PlaceId: %d | executor: %s"):format(
        D.version, game.PlaceId, D.Util.executorName()))
end
