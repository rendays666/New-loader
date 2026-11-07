--[[ STATE — semua state runtime yang mutable & di-share antar modul ]]

return function(REN)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then error("[Music] No LocalPlayer") end

    local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    if not pg then error("[Music] No PlayerGui") end

    local function resolveInitialMode()
        local m = REN.Config.PlaceModeConfig[game.PlaceId]
        if type(m) == "number" and m >= 1 and m <= 3 then return m end
        return REN.Config.DefaultMode
    end

    REN.State = {
        -- Player
        player     = player,
        playerGui  = pg,
        myUserId   = tostring(player.UserId),

        -- Audio playback
        musicSound        = nil,
        musicState        = resolveInitialMode(),
        currentIndex      = 1,      -- posisi di S.playlist (0 = lagu aktif tidak ada di list)
        currentEntry      = nil,    -- entry lagu yang benar-benar sedang diputar
        positionReady     = false,  -- true setelah lagu loaded (aman untuk save posisi)
        musicVolume       = REN.Config.MusicVolume,
        musicPaused       = false,
        currentPlayToken  = 0,
        consecutiveFails  = 0,

        -- Mute / game-sound management
        savedVols    = {},
        mutedState   = { value = true },

        -- Playlist (diisi oleh modul playlist)
        allSongs     = {},     -- semua lagu (master)
        playlist     = {},     -- list aktif sesuai viewMode (top / mine / shuffle)
        viewMode     = "top",
        existingIds  = {},
        preloadCache = {},

        -- UI callbacks (diisi oleh modul ui/panel)
        refreshUI     = nil,
        appendRowToUI = nil,
    }
end
