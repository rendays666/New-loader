--[[ BOOTSTRAP — titik akhir: init audio, build UI, banner ]]

return function(REN)
    REN.Audio.init()
    REN.createMusicUI()

    local msg = string.format(
        "READY v%s | Playlist: %d | Mode: %d | PlaceId: %d",
        REN.version, #REN.State.playlist, REN.State.musicState, game.PlaceId
    )
    if REN.Log then
        REN.Log.add("ok", msg)
    else
        print("[Music] " .. msg)
    end
end
