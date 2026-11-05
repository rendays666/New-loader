--[[
  RENRENHUB — MUSIC STANDALONE v3.1
  ────────────────────────────────────────────
  ✅ Firebase: user submissions + like/dislike
  ✅ Discord: notif upload + report lagu
  ✅ Audio validation (load + PlaybackLoudness check)
  ✅ Default sort: likes terbanyak
  ✅ Manual shuffle button (tidak auto-mix)
  ✅ Search, favorites, preload, auto-skip
  ✅ Draggable icon, resizable panel, no exit
]]

local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")
local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UIS             = game:GetService("UserInputService")

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  🎛️ CONFIG                                                        ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local CONFIG = {
    PlaylistURL     = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/playlist.json",
    FirebaseURL     = "https://music-ad0eb-default-rtdb.asia-southeast1.firebasedatabase.app",
    DiscordWebhook  = "https://discord.com/api/webhooks/1564257126648512593/e3Xn_y8jduyENW6Vti7CBdinnqk8CTXixSliasOs3c8-OEqc45VKoGeIvIQ1-kGVliiH",
    MusicVolume     = 0.5,
    StartState      = 1,
    DefaultIconPos  = UDim2.new(0, 16, 0.5, -27),
    DefaultPanelPos = UDim2.new(0, 16, 0.5, -200),
    DefaultPanelSize= UDim2.new(0, 300, 0, 420),
    MinPanelSize    = Vector2.new(260, 340),
    FavFile         = "REN_MusicFavs.json",
    LoadTimeout     = 4,
    MaxFails        = 5,
}

local FALLBACK_PLAYLIST = {
    { name = "Low Cortisol",  id = "rbxassetid://110919391228823" },
}

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  HTTP HELPERS                                                      ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function httpReq(url, method, body)
    local p = {Url=url, Method=method, Headers={["Content-Type"]="application/json"}, Body=body}
    local ok, r = pcall(function() return syn and syn.request(p) end)
    if ok and r then return r end
    ok, r = pcall(function() return http_request(p) end)
    if ok and r then return r end
    ok, r = pcall(function() return request(p) end)
    if ok and r then return r end
    return nil
end

local function fetchFB(path)
    local r = httpReq(CONFIG.FirebaseURL .. path, "GET")
    if not r or not r.Body or r.Body == "null" then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(r.Body) end)
    if ok then return data end
    return nil
end

local function postFB(path, data)
    return httpReq(CONFIG.FirebaseURL .. path, "POST", HttpService:JSONEncode(data))
end
local function putFB(path, value)
    return httpReq(CONFIG.FirebaseURL .. path, "PUT", HttpService:JSONEncode(value))
end
local function deleteFB(path)
    return httpReq(CONFIG.FirebaseURL .. path, "DELETE", nil)
end

local function fetchURL(url)
    local ok, r = pcall(function() return game:HttpGet(url, true) end)
    if ok and r and r ~= "" then return r end
    return nil
end

local function countKeys(t)
    local n = 0
    if type(t) ~= "table" then return 0 end
    for _ in pairs(t) do n = n + 1 end
    return n
end

local function extractAssetId(id)
    return tostring(id):match("%d+") or "0"
end

local function shuffleList(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  FAVS PERSIST                                                      ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function loadFavs()
    if writefile and readfile and isfile then
        if isfile(CONFIG.FavFile) then
            local ok, data = pcall(function() return readfile(CONFIG.FavFile) end)
            if ok and data and data ~= "" then
                local ok2, dec = pcall(function() return HttpService:JSONDecode(data) end)
                if ok2 and type(dec) == "table" then return dec end
            end
        end
        return {}
    end
    local env = (getgenv and getgenv()) or _G
    return env.REN_MusicFavs or {}
end

local function saveFavs(favs)
    if writefile then
        local ok, enc = pcall(function() return HttpService:JSONEncode(favs) end)
        if ok then pcall(function() writefile(CONFIG.FavFile, enc) end) end
        return
    end
    local env = (getgenv and getgenv()) or _G
    env.REN_MusicFavs = favs
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  PLAYLIST BUILDER (default: sort by likes)                         ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function fetchBasePlaylist()
    if not CONFIG.PlaylistURL or CONFIG.PlaylistURL == "" then return FALLBACK_PLAYLIST end
    local res = fetchURL(CONFIG.PlaylistURL)
    if not res then return FALLBACK_PLAYLIST end
    local ok, data = pcall(function() return HttpService:JSONDecode(res) end)
    if not ok or type(data) ~= "table" then return FALLBACK_PLAYLIST end
    local list = data.songs or data
    local clean = {}
    for _, e in ipairs(list) do
        if type(e) == "table" and e.id and e.name then
            table.insert(clean, { name = tostring(e.name), id = tostring(e.id) })
        end
    end
    if #clean == 0 then return FALLBACK_PLAYLIST end
    return clean
end

local function buildPlaylist()
    print("[Music] 🔄 Loading playlist...")
    local base = fetchBasePlaylist()
    for _, e in ipairs(base) do
        e.ratingsKey = "a_" .. extractAssetId(e.id)
        e.isSubmission = false
        e.likes = {}
        e.dislikes = {}
    end

    local subs = fetchFB("/submissions.json") or {}
    local subCount = 0
    for pushId, sub in pairs(subs) do
        if type(sub) == "table" and sub.id and sub.name then
            table.insert(base, {
                name = tostring(sub.name),
                id = tostring(sub.id),
                ratingsKey = "s_" .. pushId,
                isSubmission = true,
                submittedBy = sub.submittedBy,
                submittedByName = sub.submittedByName,
                likes = {},
                dislikes = {},
            })
            subCount = subCount + 1
        end
    end
    print("[Music] 📥 Submissions:", subCount)

    -- dedupe by assetId (base dulu yang menang)
    local seen, final = {}, {}
    for _, e in ipairs(base) do
        local key = extractAssetId(e.id)
        if not seen[key] then
            seen[key] = true
            table.insert(final, e)
        end
    end
    base = final

    local ratings = fetchFB("/ratings.json") or {}
    for _, e in ipairs(base) do
        local r = ratings[e.ratingsKey]
        e.likes = (r and r.likes) or {}
        e.dislikes = (r and r.dislikes) or {}
    end
    print("[Music] ⭐ Ratings loaded for", #base, "songs")

    -- DEFAULT: sort by likes DESC
    table.sort(base, function(a, b)
        local la = countKeys(a.likes)
        local lb = countKeys(b.likes)
        if la ~= lb then return la > lb end
        return a.name < b.name
    end)
    print("[Music] 📊 Sorted by likes")
    return base
end

local Playlist = buildPlaylist()

local player = Players.LocalPlayer
if not player then return end
local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not pg then return end

local myUserId = tostring(player.UserId)
local favorites = loadFavs()
local preloadCache = {}

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  STATE                                                             ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local musicSound    = nil
local musicState    = CONFIG.StartState
local currentIndex  = 1
local musicVolume   = CONFIG.MusicVolume
local musicPaused   = false
local savedVols     = {}
local mutedState    = { value = true }
local refreshUI     = nil
local currentPlayToken  = 0
local consecutiveFails  = 0

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
if pg:FindFirstChild("REN_MusicUI") then pg.REN_MusicUI:Destroy() end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  AUDIO VALIDATION                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function validateAudio(assetId)
    if type(assetId) ~= "string" or not assetId:match("^rbxassetid://%d+$") then
        return false, "Format harus rbxassetid://123456789"
    end
    local sound = Instance.new("Sound")
    sound.SoundId = assetId
    sound.Volume = 0.01
    sound.Parent = SoundService
    local ok = pcall(function() ContentProvider:PreloadAsync({sound}) end)
    if not ok or not sound.IsLoaded or sound.TimeLength <= 0 then
        sound:Destroy()
        return false, "Audio tidak bisa dimuat (private/region-locked)"
    end
    local maxLoud = 0
    for _, pos in ipairs({0, sound.TimeLength * 0.3, sound.TimeLength * 0.6}) do
        sound.TimePosition = pos
        pcall(function() sound:Play() end)
        for _ = 1, 5 do
            task.wait(0.1)
            if sound.PlaybackLoudness > maxLoud then maxLoud = sound.PlaybackLoudness end
        end
        pcall(function() sound:Stop() end)
    end
    sound:Destroy()
    if maxLoud < 3 then return false, "Audio tidak ada suara (silent)" end
    return true, math.floor(maxLoud)
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  DISCORD: UPLOAD NOTIF                                             ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function notifyDiscord(entry, loudness)
    if not CONFIG.DiscordWebhook or CONFIG.DiscordWebhook == "" then return end
    local payload = {
        username = "REN Music Hub",
        embeds = {{
            title = "🎵 New Song Uploaded",
            description = "**" .. entry.name .. "**\n`" .. entry.id .. "`",
            color = 3066993,
            fields = {
                { name = "Uploader", value = entry.submittedByName .. " (`" .. entry.submittedBy .. "`)", inline = true },
                { name = "Validation", value = "✅ Loaded (loud: " .. tostring(loudness) .. ")", inline = true },
                { name = "Game", value = tostring(game.PlaceId), inline = true },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }
    task.spawn(function()
        pcall(function()
            httpReq(CONFIG.DiscordWebhook, "POST", HttpService:JSONEncode(payload))
        end)
    end)
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  DISCORD: REPORT                                                   ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function sendReport(entry, reason)
    if not CONFIG.DiscordWebhook or CONFIG.DiscordWebhook == "" then
        return false, "Webhook belum diset"
    end
    local payload = {
        username = "REN Music Reports",
        embeds = {{
            title = "🚩 Song Report",
            color = 15158332,
            fields = {
                { name = "Song", value = "**" .. entry.name .. "**\n`" .. entry.id .. "`", inline = false },
                { name = "Reason", value = reason, inline = false },
                { name = "Reported by", value = player.Name .. " (`" .. player.UserId .. "`)", inline = true },
                { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                { name = "Is Submission", value = tostring(entry.isSubmission), inline = true },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }
    local r = httpReq(CONFIG.DiscordWebhook, "POST", HttpService:JSONEncode(payload))
    if r then return true end
    return false, "Gagal kirim report"
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  SUBMIT SONG                                                       ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local appendRowToUI

local function submitSong(name, assetId, statusCb)
    if not name or #name < 1 or #name > 80 then
        return nil, "Nama harus 1-80 karakter"
    end
    statusCb("🔍 Validating audio...")
    local ok, loudnessOrErr = validateAudio(assetId)
    if not ok then return nil, loudnessOrErr end
    statusCb("📤 Uploading to database...")
    local payload = {
        name = name, id = assetId,
        submittedBy = player.UserId,
        submittedByName = player.Name,
        submittedAt = os.time(),
        loudness = loudnessOrErr,
    }
    local r = postFB("/submissions.json", payload)
    if not r or not r.Body then return nil, "Gagal upload (cek koneksi)" end
    local ok2, dec = pcall(function() return HttpService:JSONDecode(r.Body) end)
    if not ok2 or not dec or not dec.name then return nil, "Response Firebase invalid" end
    local entry = {
        name = name, id = assetId,
        ratingsKey = "s_" .. dec.name,
        isSubmission = true,
        submittedBy = player.UserId,
        submittedByName = player.Name,
        likes = {}, dislikes = {},
    }
    table.insert(Playlist, entry)
    if appendRowToUI then appendRowToUI(#Playlist, entry) end
    notifyDiscord(entry, loudnessOrErr)
    return entry, nil
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  RATE                                                              ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function toggleRating(entry, kind)
    local opposite = (kind == "likes") and "dislikes" or "likes"
    if entry[kind][myUserId] then
        entry[kind][myUserId] = nil
        task.spawn(function() deleteFB("/ratings/" .. entry.ratingsKey .. "/" .. kind .. "/" .. myUserId .. ".json") end)
    else
        entry[kind][myUserId] = true
        if entry[opposite][myUserId] then
            entry[opposite][myUserId] = nil
            task.spawn(function() deleteFB("/ratings/" .. entry.ratingsKey .. "/" .. opposite .. "/" .. myUserId .. ".json") end)
        end
        task.spawn(function() putFB("/ratings/" .. entry.ratingsKey .. "/" .. kind .. "/" .. myUserId .. ".json", true) end)
    end
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  PRELOAD                                                           ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function preloadAsset(assetId)
    if not assetId or preloadCache[assetId] then return end
    task.spawn(function()
        local tempSound = Instance.new("Sound")
        tempSound.SoundId = assetId; tempSound.Volume = 0
        tempSound.Parent = SoundService
        local ok = pcall(function() ContentProvider:PreloadAsync({tempSound}) end)
        tempSound:Destroy()
        if ok then preloadCache[assetId] = true end
    end)
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  SOUND MUTE LOGIC                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function saveGameSounds(except)
    savedVols = {}
    for _, root in ipairs({SoundService, workspace, game:GetService("Lighting")}) do
        if root then
            pcall(function()
                for _, s in ipairs(root:GetDescendants()) do
                    if s:IsA("Sound") and s ~= except and s.Name ~= "__REN_Music" then
                        savedVols[s] = s.Volume
                    end
                end
            end)
        end
    end
    local env = (getgenv and getgenv()) or _G
    env.REN_MusicSavedVols = savedVols
end

local function setSoundsVol(mute, except)
    for s, v in pairs(savedVols) do
        if s ~= except and s and s.Parent then
            pcall(function() s.Volume = mute and 0 or v end)
        end
    end
end

local function tryWatch(o)
    if o:IsA("Sound") and o ~= musicSound and o.Name ~= "__REN_Music" and not savedVols[o] then
        savedVols[o] = o.Volume
        if mutedState.value then pcall(function() o.Volume = 0 end) end
    end
end

local function applyMusicState()
    if musicState == 1 then
        setSoundsVol(true, musicSound); mutedState.value = true
        if musicSound then musicSound.Volume = musicVolume end
        if musicSound and musicSound.SoundId ~= "" and not musicPaused and not musicSound.Playing then
            pcall(function() musicSound:Play() end)
        end
    elseif musicState == 2 then
        setSoundsVol(false, musicSound); mutedState.value = false
        if musicSound then musicSound.Volume = musicVolume end
        if musicSound and musicSound.SoundId ~= "" and not musicPaused and not musicSound.Playing then
            pcall(function() musicSound:Play() end)
        end
    else
        setSoundsVol(false, musicSound); mutedState.value = false
        if musicSound then musicSound.Volume = 0 end
    end
end

local function getModeText()
    if musicState == 1 then return "🎵 Music Only"
    elseif musicState == 2 then return "🎵🔊 Music + Game"
    else return "🔊 Game Only" end
end
local function getModeColor()
    if musicState == 1 then return Color3.fromRGB(40, 42, 55)
    elseif musicState == 2 then return Color3.fromRGB(60, 90, 60)
    else return Color3.fromRGB(90, 60, 60) end
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  PLAY + AUTO-SKIP                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function playSongAt(idx, isAutoSkip)
    if not musicSound or not musicSound.Parent then return end
    if not isAutoSkip then consecutiveFails = 0 end
    currentIndex = ((idx - 1) % #Playlist) + 1
    local entry = Playlist[currentIndex]
    if not entry then return end
    musicPaused = false
    pcall(function() musicSound:Stop() end)
    musicSound.SoundId = entry.id
    musicSound.Volume = (musicState == 3) and 0 or musicVolume
    preloadAsset(entry.id)
    local nextIdx = (currentIndex % #Playlist) + 1
    if Playlist[nextIdx] then preloadAsset(Playlist[nextIdx].id) end
    currentPlayToken = currentPlayToken + 1
    local myToken = currentPlayToken
    if refreshUI then refreshUI() end
    task.spawn(function()
        task.wait(0.1)
        pcall(function() musicSound:Play() end)
        local startTime = tick()
        local loaded = false
        while (tick() - startTime) < CONFIG.LoadTimeout do
            if currentPlayToken ~= myToken then return end
            if musicSound.IsLoaded or musicSound.TimeLength > 0 then loaded = true; break end
            task.wait(0.3)
        end
        if currentPlayToken ~= myToken then return end
        if loaded then
            consecutiveFails = 0
            if not musicPaused and not musicSound.IsPlaying then
                pcall(function() musicSound:Play() end)
            end
        else
            consecutiveFails = consecutiveFails + 1
            if consecutiveFails >= CONFIG.MaxFails then consecutiveFails = 0; return end
            task.wait(0.2)
            if currentPlayToken == myToken then playSongAt(currentIndex + 1, true) end
        end
    end)
end

local function initMusic()
    musicSound = Instance.new("Sound")
    musicSound.Name = "__REN_Music"
    musicSound.Volume = musicVolume
    musicSound.Looped = false
    musicSound.Parent = SoundService
    musicSound.Ended:Connect(function()
        if not musicPaused then playSongAt(currentIndex + 1) end
    end)
    saveGameSounds(musicSound)
    applyMusicState()
    SoundService.DescendantAdded:Connect(tryWatch)
    workspace.DescendantAdded:Connect(tryWatch)
    playSongAt(1)
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  UI                                                                ║
-- ╚═══════════════════════════════════════════════════════════════════╝
local function createMusicUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "REN_MusicUI"; gui.ResetOnSpawn = false
    gui.DisplayOrder = 250; gui.Parent = pg

    -- icon
    local icon = Instance.new("TextButton", gui)
    icon.Size = UDim2.new(0, 50, 0, 50)
    icon.Position = CONFIG.DefaultIconPos
    icon.BackgroundColor3 = Color3.fromRGB(22, 26, 40)
    icon.Text = "🎵"; icon.TextSize = 22
    icon.BorderSizePixel = 0; icon.AutoButtonColor = false
    icon.ZIndex = 10
    Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)
    local is = Instance.new("UIStroke", icon)
    is.Color = Color3.fromRGB(0, 220, 160); is.Thickness = 2

    -- panel
    local panel = Instance.new("Frame", gui)
    panel.Size = CONFIG.DefaultPanelSize
    panel.Position = CONFIG.DefaultPanelPos
    panel.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
    panel.BorderSizePixel = 0
    panel.Visible = false
    panel.ZIndex = 1
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
    local ps = Instance.new("UIStroke", panel)
    ps.Color = Color3.fromRGB(0, 220, 160); ps.Thickness = 2

    -- header
    local header = Instance.new("Frame", panel)
    header.Size = UDim2.new(1, 0, 0, 32)
    header.BackgroundTransparency = 1; header.Active = true

    local hTitle = Instance.new("TextLabel", header)
    hTitle.Size = UDim2.new(1, -80, 1, 0)
    hTitle.Position = UDim2.new(0, 12, 0, 0)
    hTitle.BackgroundTransparency = 1
    hTitle.Text = "🎵 Music (" .. #Playlist .. ")"
    hTitle.TextColor3 = Color3.fromRGB(0, 220, 160)
    hTitle.Font = Enum.Font.GothamBold; hTitle.TextSize = 12
    hTitle.TextXAlignment = Enum.TextXAlignment.Left

    local uploadBtn = Instance.new("TextButton", header)
    uploadBtn.Size = UDim2.new(0, 60, 0, 24)
    uploadBtn.Position = UDim2.new(1, -66, 0, 4)
    uploadBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 130)
    uploadBtn.Text = "➕ Upload"
    uploadBtn.TextColor3 = Color3.new(1, 1, 1)
    uploadBtn.Font = Enum.Font.GothamBold; uploadBtn.TextSize = 10
    uploadBtn.BorderSizePixel = 0
    Instance.new("UICorner", uploadBtn).CornerRadius = UDim.new(0, 5)

    -- search row: [search] [♡ fav] [📊 likes] [🔀 shuffle]
    local searchBox = Instance.new("TextBox", panel)
    searchBox.Size = UDim2.new(1, -110, 0, 26)
    searchBox.Position = UDim2.new(0, 12, 0, 36)
    searchBox.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    searchBox.BorderSizePixel = 0
    searchBox.Text = ""; searchBox.PlaceholderText = "Search songs..."
    searchBox.PlaceholderColor3 = Color3.fromRGB(140, 145, 165)
    searchBox.TextColor3 = Color3.fromRGB(230, 230, 240)
    searchBox.Font = Enum.Font.Gotham; searchBox.TextSize = 12
    searchBox.ClearTextOnFocus = false
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 6)
    local sp = Instance.new("UIPadding", searchBox)
    sp.PaddingLeft = UDim.new(0, 10)

    local favFilterBtn = Instance.new("TextButton", panel)
    favFilterBtn.Size = UDim2.new(0, 26, 0, 26)
    favFilterBtn.Position = UDim2.new(1, -98, 0, 36)
    favFilterBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    favFilterBtn.Text = "♡"
    favFilterBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
    favFilterBtn.TextSize = 15
    favFilterBtn.Font = Enum.Font.GothamBold; favFilterBtn.BorderSizePixel = 0
    Instance.new("UICorner", favFilterBtn).CornerRadius = UDim.new(0, 6)

    local sortLikesBtn = Instance.new("TextButton", panel)
    sortLikesBtn.Size = UDim2.new(0, 26, 0, 26)
    sortLikesBtn.Position = UDim2.new(1, -68, 0, 36)
    sortLikesBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
    sortLikesBtn.Text = "📊"
    sortLikesBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    sortLikesBtn.TextSize = 13
    sortLikesBtn.Font = Enum.Font.GothamBold; sortLikesBtn.BorderSizePixel = 0
    Instance.new("UICorner", sortLikesBtn).CornerRadius = UDim.new(0, 6)

    local shuffleBtn = Instance.new("TextButton", panel)
    shuffleBtn.Size = UDim2.new(0, 26, 0, 26)
    shuffleBtn.Position = UDim2.new(1, -38, 0, 36)
    shuffleBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    shuffleBtn.Text = "🔀"
    shuffleBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    shuffleBtn.TextSize = 13
    shuffleBtn.Font = Enum.Font.GothamBold; shuffleBtn.BorderSizePixel = 0
    Instance.new("UICorner", shuffleBtn).CornerRadius = UDim.new(0, 6)

    -- list
    local listFrame = Instance.new("ScrollingFrame", panel)
    listFrame.Size = UDim2.new(1, -24, 1, -212)
    listFrame.Position = UDim2.new(0, 12, 0, 68)
    listFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 42)
    listFrame.BorderSizePixel = 0
    listFrame.ScrollBarThickness = 5
    listFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 200, 140)
    listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    listFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)
    local listLayout = Instance.new("UIListLayout", listFrame)
    listLayout.Padding = UDim.new(0, 2)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    local listPad = Instance.new("UIPadding", listFrame)
    listPad.PaddingTop = UDim.new(0, 4)
    listPad.PaddingLeft = UDim.new(0, 4)
    listPad.PaddingRight = UDim.new(0, 4)
    listPad.PaddingBottom = UDim.new(0, 4)

    -- now playing + report
    local nowPlaying = Instance.new("TextLabel", panel)
    nowPlaying.Size = UDim2.new(1, -52, 0, 20)
    nowPlaying.Position = UDim2.new(0, 12, 1, -132)
    nowPlaying.BackgroundTransparency = 1
    nowPlaying.Text = Playlist[currentIndex] and Playlist[currentIndex].name or "-"
    nowPlaying.TextColor3 = Color3.fromRGB(240, 240, 250)
    nowPlaying.Font = Enum.Font.GothamBold; nowPlaying.TextSize = 12
    nowPlaying.TextXAlignment = Enum.TextXAlignment.Left
    nowPlaying.TextTruncate = Enum.TextTruncate.AtEnd

    local reportBtn = Instance.new("TextButton", panel)
    reportBtn.Size = UDim2.new(0, 28, 0, 20)
    reportBtn.Position = UDim2.new(1, -40, 1, -132)
    reportBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
    reportBtn.Text = "🚩"
    reportBtn.TextColor3 = Color3.fromRGB(255, 200, 200)
    reportBtn.TextSize = 11
    reportBtn.BorderSizePixel = 0
    Instance.new("UICorner", reportBtn).CornerRadius = UDim.new(0, 5)

    -- controls
    local btnHolder = Instance.new("Frame", panel)
    btnHolder.Size = UDim2.new(1, -24, 0, 38)
    btnHolder.Position = UDim2.new(0, 12, 1, -106)
    btnHolder.BackgroundTransparency = 1
    local btnLayout = Instance.new("UIListLayout", btnHolder)
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 6)
    btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    btnLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local prevBtn = Instance.new("TextButton", btnHolder)
    prevBtn.Size = UDim2.new(0.3, -4, 1, 0); prevBtn.LayoutOrder = 1
    prevBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
    prevBtn.Text = "⏮"; prevBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    prevBtn.TextSize = 18; prevBtn.BorderSizePixel = 0
    Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 8)

    local playBtn = Instance.new("TextButton", btnHolder)
    playBtn.Size = UDim2.new(0.4, -4, 1, 0); playBtn.LayoutOrder = 2
    playBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 140)
    playBtn.Text = "⏸"; playBtn.TextColor3 = Color3.new(1, 1, 1)
    playBtn.TextSize = 18; playBtn.BorderSizePixel = 0
    Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0, 8)

    local nextBtn = Instance.new("TextButton", btnHolder)
    nextBtn.Size = UDim2.new(0.3, -4, 1, 0); nextBtn.LayoutOrder = 3
    nextBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
    nextBtn.Text = "⏭"; nextBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    nextBtn.TextSize = 18; nextBtn.BorderSizePixel = 0
    Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0, 8)

    -- bottom row
    local bottomHolder = Instance.new("Frame", panel)
    bottomHolder.Size = UDim2.new(1, -24, 0, 26)
    bottomHolder.Position = UDim2.new(0, 12, 1, -40)
    bottomHolder.BackgroundTransparency = 1
    local bottomLayout = Instance.new("UIListLayout", bottomHolder)
    bottomLayout.FillDirection = Enum.FillDirection.Horizontal
    bottomLayout.Padding = UDim.new(0, 8)
    bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local modeBtn = Instance.new("TextButton", bottomHolder)
    modeBtn.Size = UDim2.new(0.5, -4, 1, 0); modeBtn.LayoutOrder = 1
    modeBtn.BackgroundColor3 = getModeColor()
    modeBtn.Text = getModeText()
    modeBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    modeBtn.Font = Enum.Font.Gotham; modeBtn.TextSize = 10
    modeBtn.BorderSizePixel = 0
    Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 6)

    local volBtn = Instance.new("TextButton", bottomHolder)
    volBtn.Size = UDim2.new(0.5, -4, 1, 0); volBtn.LayoutOrder = 2
    volBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
    volBtn.Text = "🔊 " .. math.floor(musicVolume * 100) .. "%"
    volBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    volBtn.Font = Enum.Font.Gotham; volBtn.TextSize = 10
    volBtn.BorderSizePixel = 0
    Instance.new("UICorner", volBtn).CornerRadius = UDim.new(0, 6)

    -- resize handle
    local resizeHandle = Instance.new("TextButton", panel)
    resizeHandle.Size = UDim2.new(0, 16, 0, 16)
    resizeHandle.Position = UDim2.new(1, -14, 1, -14)
    resizeHandle.BackgroundColor3 = Color3.fromRGB(0, 200, 140)
    resizeHandle.BackgroundTransparency = 0.7
    resizeHandle.Text = "◢"
    resizeHandle.TextColor3 = Color3.fromRGB(0, 220, 160)
    resizeHandle.TextSize = 11
    resizeHandle.BorderSizePixel = 0
    resizeHandle.ZIndex = 10
    Instance.new("UICorner", resizeHandle).CornerRadius = UDim.new(0, 4)

    -- ══ UPLOAD DIALOG ═════════════════════════════════════════════
    local dialog = Instance.new("Frame", panel)
    dialog.Size = UDim2.new(1, -24, 0, 180)
    dialog.Position = UDim2.new(0, 12, 0, 68)
    dialog.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
    dialog.BorderSizePixel = 0; dialog.Visible = false; dialog.ZIndex = 20
    Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 10)
    local dStroke = Instance.new("UIStroke", dialog)
    dStroke.Color = Color3.fromRGB(0, 220, 160); dStroke.Thickness = 2

    local dTitle = Instance.new("TextLabel", dialog)
    dTitle.Size = UDim2.new(1, -20, 0, 24)
    dTitle.Position = UDim2.new(0, 10, 0, 8)
    dTitle.BackgroundTransparency = 1
    dTitle.Text = "➕ Upload Lagu"
    dTitle.TextColor3 = Color3.fromRGB(0, 220, 160)
    dTitle.Font = Enum.Font.GothamBold; dTitle.TextSize = 13
    dTitle.TextXAlignment = Enum.TextXAlignment.Left; dTitle.ZIndex = 21

    local nameInput = Instance.new("TextBox", dialog)
    nameInput.Size = UDim2.new(1, -20, 0, 28)
    nameInput.Position = UDim2.new(0, 10, 0, 40)
    nameInput.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    nameInput.PlaceholderText = "Nama lagu..."
    nameInput.PlaceholderColor3 = Color3.fromRGB(140, 145, 165)
    nameInput.Text = ""; nameInput.TextColor3 = Color3.fromRGB(230, 230, 240)
    nameInput.Font = Enum.Font.Gotham; nameInput.TextSize = 12
    nameInput.TextXAlignment = Enum.TextXAlignment.Left
    nameInput.ClearTextOnFocus = false; nameInput.BorderSizePixel = 0; nameInput.ZIndex = 21
    Instance.new("UICorner", nameInput).CornerRadius = UDim.new(0, 6)
    local npad = Instance.new("UIPadding", nameInput)
    npad.PaddingLeft = UDim.new(0, 8)

    local idInput = Instance.new("TextBox", dialog)
    idInput.Size = UDim2.new(1, -20, 0, 28)
    idInput.Position = UDim2.new(0, 10, 0, 74)
    idInput.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    idInput.PlaceholderText = "rbxassetid://123456789"
    idInput.PlaceholderColor3 = Color3.fromRGB(140, 145, 165)
    idInput.Text = ""; idInput.TextColor3 = Color3.fromRGB(230, 230, 240)
    idInput.Font = Enum.Font.Gotham; idInput.TextSize = 12
    idInput.TextXAlignment = Enum.TextXAlignment.Left
    idInput.ClearTextOnFocus = false; idInput.BorderSizePixel = 0; idInput.ZIndex = 21
    Instance.new("UICorner", idInput).CornerRadius = UDim.new(0, 6)
    local ipad = Instance.new("UIPadding", idInput)
    ipad.PaddingLeft = UDim.new(0, 8)

    local statusLbl = Instance.new("TextLabel", dialog)
    statusLbl.Size = UDim2.new(1, -20, 0, 20)
    statusLbl.Position = UDim2.new(0, 10, 0, 106)
    statusLbl.BackgroundTransparency = 1
    statusLbl.Text = ""; statusLbl.TextColor3 = Color3.fromRGB(180, 200, 220)
    statusLbl.Font = Enum.Font.Gotham; statusLbl.TextSize = 11
    statusLbl.TextXAlignment = Enum.TextXAlignment.Left; statusLbl.ZIndex = 21

    local cancelBtn = Instance.new("TextButton", dialog)
    cancelBtn.Size = UDim2.new(0.45, -5, 0, 30)
    cancelBtn.Position = UDim2.new(0, 10, 1, -40)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
    cancelBtn.Text = "Cancel"; cancelBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    cancelBtn.Font = Enum.Font.GothamBold; cancelBtn.TextSize = 11
    cancelBtn.BorderSizePixel = 0; cancelBtn.ZIndex = 21
    Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 6)

    local submitBtn = Instance.new("TextButton", dialog)
    submitBtn.Size = UDim2.new(0.45, -5, 0, 30)
    submitBtn.Position = UDim2.new(0.55, 0, 1, -40)
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 130)
    submitBtn.Text = "Submit"; submitBtn.TextColor3 = Color3.new(1, 1, 1)
    submitBtn.Font = Enum.Font.GothamBold; submitBtn.TextSize = 11
    submitBtn.BorderSizePixel = 0; submitBtn.ZIndex = 21
    Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0, 6)

    -- ══ REPORT DIALOG ═════════════════════════════════════════════
    local reportDialog = Instance.new("Frame", panel)
    reportDialog.Size = UDim2.new(1, -24, 0, 200)
    reportDialog.Position = UDim2.new(0, 12, 0, 68)
    reportDialog.BackgroundColor3 = Color3.fromRGB(25, 15, 15)
    reportDialog.BorderSizePixel = 0; reportDialog.Visible = false; reportDialog.ZIndex = 20
    Instance.new("UICorner", reportDialog).CornerRadius = UDim.new(0, 10)
    local rStroke = Instance.new("UIStroke", reportDialog)
    rStroke.Color = Color3.fromRGB(220, 80, 80); rStroke.Thickness = 2

    local rTitle = Instance.new("TextLabel", reportDialog)
    rTitle.Size = UDim2.new(1, -20, 0, 24)
    rTitle.Position = UDim2.new(0, 10, 0, 8)
    rTitle.BackgroundTransparency = 1
    rTitle.Text = "🚩 Report Lagu"
    rTitle.TextColor3 = Color3.fromRGB(255, 120, 120)
    rTitle.Font = Enum.Font.GothamBold; rTitle.TextSize = 13
    rTitle.TextXAlignment = Enum.TextXAlignment.Left; rTitle.ZIndex = 21

    local rSongLbl = Instance.new("TextLabel", reportDialog)
    rSongLbl.Size = UDim2.new(1, -20, 0, 18)
    rSongLbl.Position = UDim2.new(0, 10, 0, 34)
    rSongLbl.BackgroundTransparency = 1
    rSongLbl.Text = Playlist[currentIndex] and Playlist[currentIndex].name or "-"
    rSongLbl.TextColor3 = Color3.fromRGB(230, 200, 200)
    rSongLbl.Font = Enum.Font.Gotham; rSongLbl.TextSize = 11
    rSongLbl.TextXAlignment = Enum.TextXAlignment.Left
    rSongLbl.TextTruncate = Enum.TextTruncate.AtEnd
    rSongLbl.ZIndex = 21

    local reasonInput = Instance.new("TextBox", reportDialog)
    reasonInput.Size = UDim2.new(1, -20, 0, 82)
    reasonInput.Position = UDim2.new(0, 10, 0, 56)
    reasonInput.BackgroundColor3 = Color3.fromRGB(35, 25, 30)
    reasonInput.PlaceholderText = "Tulis alasan report (misal: audio rusak, lagu tidak pantas, dll)..."
    reasonInput.PlaceholderColor3 = Color3.fromRGB(160, 130, 140)
    reasonInput.Text = ""; reasonInput.TextColor3 = Color3.fromRGB(230, 230, 240)
    reasonInput.Font = Enum.Font.Gotham; reasonInput.TextSize = 11
    reasonInput.TextXAlignment = Enum.TextXAlignment.Left
    reasonInput.TextYAlignment = Enum.TextYAlignment.Top
    reasonInput.MultiLine = true
    reasonInput.TextWrapped = true
    reasonInput.ClearTextOnFocus = false; reasonInput.BorderSizePixel = 0; reasonInput.ZIndex = 21
    Instance.new("UICorner", reasonInput).CornerRadius = UDim.new(0, 6)
    local rpad = Instance.new("UIPadding", reasonInput)
    rpad.PaddingLeft = UDim.new(0, 8)
    rpad.PaddingTop = UDim.new(0, 6)

    local rStatus = Instance.new("TextLabel", reportDialog)
    rStatus.Size = UDim2.new(1, -20, 0, 18)
    rStatus.Position = UDim2.new(0, 10, 0, 142)
    rStatus.BackgroundTransparency = 1
    rStatus.Text = ""; rStatus.TextColor3 = Color3.fromRGB(180, 200, 220)
    rStatus.Font = Enum.Font.Gotham; rStatus.TextSize = 10
    rStatus.TextXAlignment = Enum.TextXAlignment.Left; rStatus.ZIndex = 21

    local rCancelBtn = Instance.new("TextButton", reportDialog)
    rCancelBtn.Size = UDim2.new(0.45, -5, 0, 30)
    rCancelBtn.Position = UDim2.new(0, 10, 1, -40)
    rCancelBtn.BackgroundColor3 = Color3.fromRGB(60, 65, 80)
    rCancelBtn.Text = "Cancel"; rCancelBtn.TextColor3 = Color3.fromRGB(220, 220, 240)
    rCancelBtn.Font = Enum.Font.GothamBold; rCancelBtn.TextSize = 11
    rCancelBtn.BorderSizePixel = 0; rCancelBtn.ZIndex = 21
    Instance.new("UICorner", rCancelBtn).CornerRadius = UDim.new(0, 6)

    local rSendBtn = Instance.new("TextButton", reportDialog)
    rSendBtn.Size = UDim2.new(0.45, -5, 0, 30)
    rSendBtn.Position = UDim2.new(0.55, 0, 1, -40)
    rSendBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    rSendBtn.Text = "Send Report"; rSendBtn.TextColor3 = Color3.new(1, 1, 1)
    rSendBtn.Font = Enum.Font.GothamBold; rSendBtn.TextSize = 11
    rSendBtn.BorderSizePixel = 0; rSendBtn.ZIndex = 21
    Instance.new("UICorner", rSendBtn).CornerRadius = UDim.new(0, 6)

    -- ══ ROWS ══════════════════════════════════════════════════════
    local updateUI, applyFilter, updateHighlights, rebuildList, applySort
    local rowsByIdx = {}
    local showFavOnly = false
    local sortMode = "likes"

    local function buildRow(idx, entry)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = (idx == currentIndex) and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52)
        row.BorderSizePixel = 0
        row.LayoutOrder = idx
        row.Parent = listFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local favBtn = Instance.new("TextButton", row)
        favBtn.Size = UDim2.new(0, 22, 1, 0)
        favBtn.Position = UDim2.new(0, 0, 0, 0)
        favBtn.BackgroundTransparency = 1
        favBtn.Text = favorites[entry.id] and "❤" or "♡"
        favBtn.TextColor3 = favorites[entry.id] and Color3.fromRGB(255, 80, 100) or Color3.fromRGB(180, 180, 200)
        favBtn.TextSize = 14; favBtn.Font = Enum.Font.GothamBold; favBtn.BorderSizePixel = 0

        local playRow = Instance.new("TextButton", row)
        playRow.Size = UDim2.new(1, -22 - 64, 1, 0)
        playRow.Position = UDim2.new(0, 22, 0, 0)
        playRow.BackgroundTransparency = 1
        local prefix = (entry.isSubmission and "📤 ") or ""
        playRow.Text = (idx == currentIndex and "▶ " or "") .. prefix .. entry.name
        playRow.TextColor3 = (idx == currentIndex) and Color3.fromRGB(0, 220, 160) or Color3.fromRGB(220, 220, 235)
        playRow.TextXAlignment = Enum.TextXAlignment.Left
        playRow.TextSize = 11
        playRow.Font = (idx == currentIndex) and Enum.Font.GothamBold or Enum.Font.Gotham
        playRow.BorderSizePixel = 0; playRow.TextTruncate = Enum.TextTruncate.AtEnd

        local likeBtn = Instance.new("TextButton", row)
        likeBtn.Size = UDim2.new(0, 32, 1, 0)
        likeBtn.Position = UDim2.new(1, -64, 0, 0)
        likeBtn.BackgroundTransparency = 1
        likeBtn.TextSize = 10; likeBtn.Font = Enum.Font.GothamBold; likeBtn.BorderSizePixel = 0

        local dislikeBtn = Instance.new("TextButton", row)
        dislikeBtn.Size = UDim2.new(0, 32, 1, 0)
        dislikeBtn.Position = UDim2.new(1, -32, 0, 0)
        dislikeBtn.BackgroundTransparency = 1
        dislikeBtn.TextSize = 10; dislikeBtn.Font = Enum.Font.GothamBold; dislikeBtn.BorderSizePixel = 0

        local function updateRatingUI()
            likeBtn.Text = "👍" .. countKeys(entry.likes)
            dislikeBtn.Text = "👎" .. countKeys(entry.dislikes)
            likeBtn.TextColor3 = entry.likes[myUserId] and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(160, 160, 180)
            dislikeBtn.TextColor3 = entry.dislikes[myUserId] and Color3.fromRGB(90, 140, 255) or Color3.fromRGB(160, 160, 180)
        end
        updateRatingUI()

        favBtn.MouseButton1Click:Connect(function()
            if favorites[entry.id] then
                favorites[entry.id] = nil
                favBtn.Text = "♡"; favBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
            else
                favorites[entry.id] = true
                favBtn.Text = "❤"; favBtn.TextColor3 = Color3.fromRGB(255, 80, 100)
            end
            saveFavs(favorites); applyFilter()
        end)
        playRow.MouseButton1Click:Connect(function()
            -- find index of this entry (since sort may have changed)
            for i, e in ipairs(Playlist) do
                if e == entry then playSongAt(i); break end
            end
            task.wait(0.05)
            updateUI(); updateHighlights()
        end)
        likeBtn.MouseButton1Click:Connect(function()
            toggleRating(entry, "likes"); updateRatingUI()
        end)
        dislikeBtn.MouseButton1Click:Connect(function()
            toggleRating(entry, "dislikes"); updateRatingUI()
        end)

        rowsByIdx[idx] = {row=row, favBtn=favBtn, playRow=playRow, likeBtn=likeBtn, dislikeBtn=dislikeBtn, updateRatingUI=updateRatingUI, entry=entry}
    end

    rebuildList = function()
        -- destroy existing frames
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end
        rowsByIdx = {}
        for idx, entry in ipairs(Playlist) do buildRow(idx, entry) end
        applyFilter()
        updateHighlights()
    end

    -- expose for dynamic append (upload)
    appendRowToUI = function(idx, entry)
        buildRow(idx, entry)
        applyFilter()
    end

    applySort = function(mode)
        local currentEntry = Playlist[currentIndex]
        if mode == "likes" then
            table.sort(Playlist, function(a, b)
                local la = countKeys(a.likes)
                local lb = countKeys(b.likes)
                if la ~= lb then return la > lb end
                return a.name < b.name
            end)
        elseif mode == "shuffle" then
            shuffleList(Playlist)
        end
        if currentEntry then
            for i, e in ipairs(Playlist) do
                if e == currentEntry then currentIndex = i; break end
            end
        end
        rebuildList()
        updateUI()
    end

    updateHighlights = function()
        for idx, data in pairs(rowsByIdx) do
            local isCurrent = (idx == currentIndex)
            local e = data.entry
            data.row.BackgroundColor3 = isCurrent and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52)
            data.playRow.TextColor3 = isCurrent and Color3.fromRGB(0, 220, 160) or Color3.fromRGB(220, 220, 235)
            data.playRow.Font = isCurrent and Enum.Font.GothamBold or Enum.Font.Gotham
            local prefix = (e.isSubmission and "📤 ") or ""
            data.playRow.Text = (isCurrent and "▶ " or "") .. prefix .. e.name
        end
    end

    applyFilter = function()
        local txt = (searchBox.Text or ""):lower()
        for idx, data in pairs(rowsByIdx) do
            local entry = data.entry
            local textMatch = txt == "" or entry.name:lower():find(txt, 1, true) ~= nil
            local favMatch  = (not showFavOnly) or favorites[entry.id]
            data.row.Visible = textMatch and favMatch
        end
    end

    updateUI = function()
        local entry = Playlist[currentIndex]
        nowPlaying.Text = entry and entry.name or "-"
        rSongLbl.Text = entry and entry.name or "-"
        playBtn.Text = musicPaused and "▶" or "⏸"
        playBtn.BackgroundColor3 = musicPaused and Color3.fromRGB(200, 150, 50) or Color3.fromRGB(0, 200, 140)
        modeBtn.Text = getModeText(); modeBtn.BackgroundColor3 = getModeColor()
        volBtn.Text = "🔊 " .. math.floor(musicVolume * 100) .. "%"
    end

    refreshUI = function() updateUI(); updateHighlights() end

    -- ══ EVENTS ════════════════════════════════════════════════════
    searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    favFilterBtn.MouseButton1Click:Connect(function()
        showFavOnly = not showFavOnly
        if showFavOnly then
            favFilterBtn.Text = "❤"; favFilterBtn.TextColor3 = Color3.fromRGB(255, 80, 100)
            favFilterBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 40)
        else
            favFilterBtn.Text = "♡"; favFilterBtn.TextColor3 = Color3.fromRGB(180, 180, 200)
            favFilterBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        end
        applyFilter()
    end)

    sortLikesBtn.MouseButton1Click:Connect(function()
        sortMode = "likes"
        sortLikesBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
        shuffleBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        applySort("likes")
    end)

    shuffleBtn.MouseButton1Click:Connect(function()
        sortMode = "shuffle"
        sortLikesBtn.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
        shuffleBtn.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
        applySort("shuffle")
    end)

    -- upload
    uploadBtn.MouseButton1Click:Connect(function()
        dialog.Visible = true; statusLbl.Text = ""; submitBtn.Visible = true
        reportDialog.Visible = false
    end)
    cancelBtn.MouseButton1Click:Connect(function()
        dialog.Visible = false
        nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
    end)

    local submitting = false
    submitBtn.MouseButton1Click:Connect(function()
        if submitting then return end
        submitting = true; submitBtn.Visible = false
        statusLbl.TextColor3 = Color3.fromRGB(180, 200, 220)
        task.spawn(function()
            local entry, err = submitSong(nameInput.Text, idInput.Text, function(msg)
                statusLbl.Text = msg
                statusLbl.TextColor3 = Color3.fromRGB(180, 200, 220)
            end)
            submitting = false; submitBtn.Visible = true
            if entry then
                statusLbl.Text = "✅ Berhasil! Memutar lagu baru..."
                statusLbl.TextColor3 = Color3.fromRGB(0, 220, 160)
                task.wait(0.8)
                dialog.Visible = false
                nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
                -- switch to shuffle-ish so user sees their submission at bottom
                for i, e in ipairs(Playlist) do
                    if e == entry then playSongAt(i); break end
                end
                task.wait(0.1)
                updateUI(); updateHighlights()
            else
                statusLbl.Text = "❌ " .. tostring(err)
                statusLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        end)
    end)

    -- report
    reportBtn.MouseButton1Click:Connect(function()
        reportDialog.Visible = true
        dialog.Visible = false
        rStatus.Text = ""; reasonInput.Text = ""
        local entry = Playlist[currentIndex]
        rSongLbl.Text = entry and entry.name or "-"
    end)
    rCancelBtn.MouseButton1Click:Connect(function()
        reportDialog.Visible = false
        reasonInput.Text = ""; rStatus.Text = ""
    end)

    local sendingReport = false
    rSendBtn.MouseButton1Click:Connect(function()
        if sendingReport then return end
        local entry = Playlist[currentIndex]
        if not entry then
            rStatus.Text = "❌ Tidak ada lagu yang sedang diputar"
            rStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        local reason = reasonInput.Text
        if not reason or #reason < 5 then
            rStatus.Text = "❌ Alasan minimal 5 karakter"
            rStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        if #reason > 500 then reason = reason:sub(1, 500) end

        sendingReport = true
        rSendBtn.Text = "..."
        rStatus.Text = "📤 Mengirim report..."
        rStatus.TextColor3 = Color3.fromRGB(180, 200, 220)

        task.spawn(function()
            local ok, err = sendReport(entry, reason)
            sendingReport = false; rSendBtn.Text = "Send Report"
            if ok then
                rStatus.Text = "✅ Report terkirim. Terima kasih!"
                rStatus.TextColor3 = Color3.fromRGB(0, 220, 160)
                task.wait(1.2)
                reportDialog.Visible = false
                reasonInput.Text = ""; rStatus.Text = ""
            else
                rStatus.Text = "❌ " .. tostring(err)
                rStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
            end
        end)
    end)

    -- controls
    prevBtn.MouseButton1Click:Connect(function() playSongAt(currentIndex - 1); task.wait(0.1); updateUI(); updateHighlights() end)
    playBtn.MouseButton1Click:Connect(function()
        if musicPaused then musicPaused = false; pcall(function() musicSound:Resume() end)
        else musicPaused = true; pcall(function() musicSound:Pause() end) end
        currentPlayToken = currentPlayToken + 1
        updateUI()
    end)
    nextBtn.MouseButton1Click:Connect(function() playSongAt(currentIndex + 1); task.wait(0.1); updateUI(); updateHighlights() end)

    modeBtn.MouseButton1Click:Connect(function()
        musicState = (musicState % 3) + 1
        applyMusicState()
        if musicSound and musicSound.SoundId ~= "" then
            if musicState == 3 then musicSound.Volume = 0
            else
                musicSound.Volume = musicVolume
                if not musicPaused and not musicSound.Playing then pcall(function() musicSound:Play() end) end
            end
        end
        updateUI()
    end)

    volBtn.MouseButton1Click:Connect(function()
        musicVolume = musicVolume + 0.1
        if musicVolume > 1.05 then musicVolume = 0 end
        musicVolume = math.clamp(musicVolume, 0, 1)
        if musicSound and musicState ~= 3 then musicSound.Volume = musicVolume end
        updateUI()
    end)

    -- drag panel
    local dragPanel, dragPanelStart, dragPanelPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragPanel = true; dragPanelStart = input.Position; dragPanelPos = panel.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragPanel = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragPanel and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragPanelStart
            panel.Position = UDim2.new(dragPanelPos.X.Scale, dragPanelPos.X.Offset + d.X, dragPanelPos.Y.Scale, dragPanelPos.Y.Offset + d.Y)
        end
    end)

    -- resize
    local resizing, resizeStart, resizeStartSize
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = true; resizeStart = input.Position; resizeStartSize = panel.AbsoluteSize
        end
    end)
    resizeHandle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            resizing = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - resizeStart
            local newW = math.max(CONFIG.MinPanelSize.X, resizeStartSize.X + d.X)
            local newH = math.max(CONFIG.MinPanelSize.Y, resizeStartSize.Y + d.Y)
            panel.Size = UDim2.new(0, newW, 0, newH)
        end
    end)

    -- icon toggle
    local iconDragging, iconDragStart, iconStartPos, iconMoved = false, nil, nil, false
    local function updateIconColor()
        icon.BackgroundColor3 = panel.Visible and Color3.fromRGB(0, 180, 130) or Color3.fromRGB(22, 26, 40)
    end
    icon.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            iconDragging = true; iconDragStart = input.Position; iconStartPos = icon.Position; iconMoved = false
        end
    end)
    icon.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            iconDragging = false
            if not iconMoved then
                panel.Visible = not panel.Visible
                if panel.Visible then
                    updateUI(); applyFilter()
                    -- hide dialogs when reopening
                    dialog.Visible = false
                    reportDialog.Visible = false
                end
                updateIconColor()
            end
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if iconDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - iconDragStart
            if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then iconMoved = true end
            if iconMoved then
                icon.Position = UDim2.new(iconStartPos.X.Scale, iconStartPos.X.Offset + d.X, iconStartPos.Y.Scale, iconStartPos.Y.Offset + d.Y)
            end
        end
    end)

    task.spawn(function()
        while gui.Parent do task.wait(1); if panel.Visible then updateUI() end end
    end)

    applyFilter(); updateUI(); updateHighlights(); updateIconColor()
end

-- ╔═══════════════════════════════════════════════════════════════════╗
-- ║  BOOT                                                              ║
-- ╚═══════════════════════════════════════════════════════════════════╝
initMusic()
createMusicUI()

print("[Music] ════════ READY v3.1 ════════")
print("[Music] Playlist:", #Playlist)
print("[Music] Sort: likes (default)")
print("[Music] UserId:", myUserId)
