--[[ CONFIG — konstanta statis & fallback playlist ]]

return function(REN)
    REN.Config = {
        PlaylistURL     = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/playlist.json",
        FirebaseURL     = "https://music-ad0eb-default-rtdb.asia-southeast1.firebasedatabase.app",
        DiscordWebhook  = "68 74 74 70 73 3A 2F 2F 64 69 73 63 6F 72 64 2E 63 6F 6D 2F 61 70 69 2F 77 65 62 68 6F 6F 6B 73 2F 31 35 36 38 34 37 34 32 38 37 36 35 34 38 33 30 31 33 32 2F 5F 53 4D 76 6F 37 76 66 6D 48 54 45 68 4F 75 32 35 74 57 38 75 30 4B 33 79 54 38 41 75 42 55 74 65 75 34 78 6C 32 6F 6F 47 43 68 67 39 46 6F 34 2D 45 30 41 4A 61 4F 77 71 52 35 38 34 72 64 71 35 37 44 73",
        MusicVolume     = 0.5,
        DefaultIconPos  = UDim2.new(0, 12, 0.5, -20),
        DefaultPanelPos = UDim2.new(0, 60, 0.5, -140),
        DefaultSize     = Vector2.new(260, 290),
        MinPanelSize    = Vector2.new(240, 230),
        MaxPanelSize    = Vector2.new(450, 650),
        LoadTimeout     = 4,
        MaxFails        = 5,
        DefaultMode     = 2,
        PlaceModeConfig = {
            [8735521924] = 1,
        },
        LikeWeight    = 10,
        DislikeWeight = 5,

        -- Nama uploader untuk lagu yang berasal dari database (playlist.json),
        -- bukan hasil upload lewat GUI.
        DefaultUploader = "demonking6666667",

        -- Save state (lagu terakhir, posisi, volume, mode list)
        SaveFolder   = "RenrenHub",
        SaveFile     = "RenrenHub/music_state.json",
        SaveInterval = 3,   -- detik
    }

    REN.FallbackPlaylist = {
        { name = "Low Cortisol", id = "rbxassetid://110919391228823" },
    }
end
