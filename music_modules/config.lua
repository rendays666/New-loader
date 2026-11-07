--[[ CONFIG — konstanta statis & fallback playlist ]]

return function(REN)
    REN.Config = {
        PlaylistURL     = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/playlist.json",
        FirebaseURL     = "https://music-ad0eb-default-rtdb.asia-southeast1.firebasedatabase.app",
        DiscordWebhook  = "https://discord.com/api/webhooks/1567772015421685772/iADRBntZYDHML7AO5wEUo_kI-uJN4Tz8UU1i8r7FGuqGQF1z4JqxhwbOhAw7ZjZ_Xbrk",
        MusicVolume     = 0.5,
        DefaultIconPos  = UDim2.new(0, 12, 0.5, -20),
        DefaultPanelPos = UDim2.new(0, 60, 0.5, -140),
        DefaultSize     = Vector2.new(210, 280),
        MinPanelSize    = Vector2.new(180, 230),
        MaxPanelSize    = Vector2.new(450, 650),
        LoadTimeout     = 4,
        MaxFails        = 5,
        DefaultMode     = 2,
        PlaceModeConfig = {
            [8735521924] = 1,
        },
        LikeWeight    = 10,
        DislikeWeight = 5,
    }

    REN.FallbackPlaylist = {
        { name = "Low Cortisol", id = "rbxassetid://110919391228823" },
    }
end
