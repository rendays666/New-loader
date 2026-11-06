--[[ BOOTSTRAP — titik akhir: init audio, build UI, banner ]]

return function(REN)
    REN.Audio.init()
    REN.createMusicUI()

    print(string.format(
        "[Music] READY v%s | Playlist: %d | Mode: %d | PlaceId: %d",
        REN.version, #REN.State.playlist, REN.State.musicState, game.PlaceId
    ))
end
