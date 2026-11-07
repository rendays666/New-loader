--[[ AUDIO — validasi audio, preload, mute management, playback, mode ]]

return function(REN)
    local SoundService      = game:GetService("SoundService")
    local ContentProvider   = game:GetService("ContentProvider")
    local C = REN.Config
    local S = REN.State
    local U = REN.Utils

    -- ── Validasi ────────────────────────────────────────────────────
    local function validateAudio(assetId)
        if type(assetId) ~= "string" or not assetId:match("^rbxassetid://%d+$") then
            return false, "Invalid internal format"
        end
        local sound = Instance.new("Sound")
        sound.SoundId = assetId; sound.Volume = 0.01
        sound.Parent = SoundService

        local ok = pcall(function() ContentProvider:PreloadAsync({sound}) end)
        if not ok or not sound.IsLoaded or sound.TimeLength <= 0 then
            sound:Destroy()
            return false, "Audio cannot be loaded (private/region-locked/wrong ID)"
        end

        local maxLoud = 0
        for _, pos in ipairs({0, sound.TimeLength * 0.3, sound.TimeLength * 0.6}) do
            sound.TimePosition = pos
            pcall(function() sound:Play() end)
            for _ = 1, 5 do
                task.wait(0.1)
                if sound.PlaybackLoudness > maxLoud then
                    maxLoud = sound.PlaybackLoudness
                end
            end
            pcall(function() sound:Stop() end)
        end
        sound:Destroy()

        if maxLoud < 3 then return false, "Audio is silent" end
        return true, math.floor(maxLoud)
    end

    -- ── Preload ─────────────────────────────────────────────────────
    local function preloadAsset(assetId)
        if not assetId or S.preloadCache[assetId] then return end
        task.spawn(function()
            local s = Instance.new("Sound")
            s.SoundId = assetId; s.Volume = 0; s.Parent = SoundService
            local ok = pcall(function() ContentProvider:PreloadAsync({s}) end)
            s:Destroy()
            if ok then S.preloadCache[assetId] = true end
        end)
    end

    -- ── Mute management ─────────────────────────────────────────────
    local function saveGameSounds(except)
        S.savedVols = {}
        for _, root in ipairs({SoundService, workspace, game:GetService("Lighting")}) do
            pcall(function()
                for _, s in ipairs(root:GetDescendants()) do
                    if s:IsA("Sound") and s ~= except and s.Name ~= "__REN_Music" then
                        S.savedVols[s] = s.Volume
                    end
                end
            end)
        end
        local env = (getgenv and getgenv()) or _G
        env.REN_MusicSavedVols = S.savedVols
    end

    local function setSoundsVol(mute, except)
        for s, v in pairs(S.savedVols) do
            if s ~= except and s and s.Parent then
                pcall(function() s.Volume = mute and 0 or v end)
            end
        end
    end

    local function tryWatch(o)
        if o:IsA("Sound") and o ~= S.musicSound and o.Name ~= "__REN_Music"
           and not S.savedVols[o] then
            S.savedVols[o] = o.Volume
            if S.mutedState.value then
                pcall(function() o.Volume = 0 end)
            end
        end
    end

    local function applyMusicState()
        if S.musicState == 3 then
            setSoundsVol(false, S.musicSound)
            S.mutedState.value = false
            if S.musicSound then S.musicSound.Volume = 0 end
            return
        end
        local muteGame = (S.musicState == 1)
        setSoundsVol(muteGame, S.musicSound)
        S.mutedState.value = muteGame
        if S.musicSound then
            S.musicSound.Volume = S.musicVolume
            if S.musicSound.SoundId ~= "" and not S.musicPaused and not S.musicSound.Playing then
                pcall(function() S.musicSound:Play() end)
            end
        end
    end

    -- ── Save state ──────────────────────────────────────────────────
    -- Snapshot lagu yang sedang diputar -> file (lewat REN.Persist).
    -- Hanya menyimpan kalau lagu sudah loaded (positionReady), supaya posisi
    -- 0 dari lagu yang baru dimuat tidak menimpa posisi yang tersimpan.
    local function saveState()
        local entry = S.currentEntry
        if not entry or not REN.Persist then return end
        if not S.positionReady or not S.musicSound or not S.musicSound.Parent then return end
        local pos = S.musicSound.TimePosition
        REN.Persist.save({
            songId   = U.extractAssetId(entry.id),
            songName = entry.name,
            position = math.floor(pos * 10) / 10,
            volume   = S.musicVolume,
            viewMode = S.viewMode,
        })
    end

    -- ── Playback ────────────────────────────────────────────────────
    -- startPos (opsional): posisi detik untuk resume lagu terakhir.
    local function playSongAt(idx, isAutoSkip, startPos)
        if not S.musicSound or not S.musicSound.Parent then return end
        if #S.playlist == 0 then return end
        if not isAutoSkip then S.consecutiveFails = 0 end
        S.currentIndex = ((idx - 1) % #S.playlist) + 1
        local entry = S.playlist[S.currentIndex]
        if not entry then return end

        local resuming = type(startPos) == "number" and startPos > 1

        S.currentEntry  = entry
        S.positionReady = false
        S.musicPaused   = false
        pcall(function() S.musicSound:Stop() end)
        S.musicSound.SoundId = entry.id
        -- saat resume: mute dulu sampai posisi di-seek, biar tidak ada "blip" awal lagu
        S.musicSound.Volume  = (resuming or S.musicState == 3) and 0 or S.musicVolume

        preloadAsset(entry.id)
        local nxt = S.playlist[(S.currentIndex % #S.playlist) + 1]
        if nxt then preloadAsset(nxt.id) end

        S.currentPlayToken = S.currentPlayToken + 1
        local myToken = S.currentPlayToken

        if S.refreshUI then S.refreshUI() end

        task.spawn(function()
            task.wait(0.1)
            pcall(function() S.musicSound:Play() end)

            local t0, loaded = tick(), false
            while (tick() - t0) < C.LoadTimeout do
                if S.currentPlayToken ~= myToken then return end
                if S.musicSound.IsLoaded or S.musicSound.TimeLength > 0 then
                    loaded = true; break
                end
                task.wait(0.3)
            end
            if S.currentPlayToken ~= myToken then return end

            if loaded then
                S.consecutiveFails = 0

                if resuming then
                    local len = S.musicSound.TimeLength
                    -- kalau tersimpan hampir di akhir lagu, mulai dari awal saja
                    if len > 0 and startPos < len - 3 then
                        pcall(function() S.musicSound.TimePosition = startPos end)
                    end
                    if S.musicState ~= 3 then S.musicSound.Volume = S.musicVolume end
                end

                S.positionReady = true
                saveState()

                if not S.musicPaused and not S.musicSound.IsPlaying then
                    pcall(function() S.musicSound:Play() end)
                end
            else
                if resuming and S.musicState ~= 3 then
                    S.musicSound.Volume = S.musicVolume
                end
                S.consecutiveFails = S.consecutiveFails + 1
                if S.consecutiveFails >= C.MaxFails then
                    S.consecutiveFails = 0; return
                end
                task.wait(0.2)
                if S.currentPlayToken == myToken then
                    playSongAt(S.currentIndex + 1, true)
                end
            end
        end)
    end

    -- ── Resume lagu terakhir ────────────────────────────────────────
    -- Return: index lagu di S.playlist + posisi (detik) untuk dilanjutkan.
    local function resolveResume()
        local saved = REN.Persist and REN.Persist.load()
        if type(saved) ~= "table" then return 1, nil end
        local PL = REN.Playlist

        if type(saved.volume) == "number" then
            S.musicVolume = math.clamp(saved.volume, 0, 1)
        end

        local mode = saved.viewMode
        if mode == "mine" or mode == "shuffle" then
            local n = PL.setView(mode)
            if n == 0 then PL.setView("top") end   -- belum ada lagu yang di-like
        end

        local want = saved.songId and tostring(saved.songId)
        if not want then return 1, nil end

        local function find()
            for i, e in ipairs(S.playlist) do
                if U.extractAssetId(e.id) == want then return i end
            end
        end

        local idx = find()
        if not idx and S.viewMode ~= "top" then
            -- lagu tidak ada di list ini (mis. sudah di-unlike) -> balik ke Top Likes
            PL.setView("top")
            idx = find()
        end
        if idx then return idx, tonumber(saved.position) end
        return 1, nil   -- lagu sudah dihapus dari database
    end

    -- ── Init ────────────────────────────────────────────────────────
    local function initMusic()
        if SoundService:FindFirstChild("__REN_Music") then
            local env = (getgenv and getgenv()) or _G
            if env.REN_MusicSavedVols then
                for s, v in pairs(env.REN_MusicSavedVols) do
                    if s and s.Parent then pcall(function() s.Volume = v end) end
                end
                env.REN_MusicSavedVols = nil
            end
            SoundService.__REN_Music:Destroy()
        end

        -- harus sebelum sound dibuat: bisa mengubah volume & list aktif
        local startIdx, startPos = resolveResume()

        S.musicSound = Instance.new("Sound")
        S.musicSound.Name   = "__REN_Music"
        S.musicSound.Volume = S.musicVolume
        S.musicSound.Looped = false
        S.musicSound.Parent = SoundService
        S.musicSound.Ended:Connect(function()
            if not S.musicPaused then playSongAt(S.currentIndex + 1) end
        end)

        saveGameSounds(S.musicSound)
        applyMusicState()
        SoundService.DescendantAdded:Connect(tryWatch)
        workspace.DescendantAdded:Connect(tryWatch)

        -- auto-save posisi lagu berkala (berhenti sendiri kalau sound di-destroy)
        local mySound = S.musicSound
        task.spawn(function()
            while mySound.Parent do
                task.wait(C.SaveInterval)
                if S.musicSound == mySound then saveState() end
            end
        end)

        playSongAt(startIdx, false, startPos)
    end

    REN.Audio = {
        validate        = validateAudio,
        preload         = preloadAsset,
        playSongAt      = playSongAt,
        saveState       = saveState,
        init            = initMusic,
        applyMusicState = applyMusicState,
        getModeText = function()
            if S.musicState == 1 then return "🎵"
            elseif S.musicState == 2 then return "🎵🔊"
            else return "🔊" end
        end,
        getModeColor = function()
            if S.musicState == 1 then return Color3.fromRGB(40, 42, 55)
            elseif S.musicState == 2 then return Color3.fromRGB(60, 90, 60)
            else return Color3.fromRGB(90, 60, 60) end
        end,
    }
end
