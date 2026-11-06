--[[
  RENRENHUB — MUSIC STANDALONE v3.6
  - Like = Favorite
  - Score sorting: likes*10 - dislikes*5 (descending)
  - PlaceModeConfig: 8735521924 = music only
  - Retry-once on load failure + LoadTimeout 12s
]]

local HttpService     = game:GetService("HttpService")
local Players         = game:GetService("Players")
local SoundService    = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local UIS             = game:GetService("UserInputService")

-- ═══ CONFIG ══════════════════════════════════════════════════════════
local CONFIG = {
    PlaylistURL     = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/playlist.json",
    FirebaseURL     = "https://music-ad0eb-default-rtdb.asia-southeast1.firebasedatabase.app",
    DiscordWebhook  = "https://discord.com/api/webhooks/1564257126648512593/e3Xn_y8jduyENW6Vti7CBdinnqk8CTXixSliasOs3c8-OEqc45VKoGeIvIQ1-kGVliiH",
    MusicVolume     = 0.5,
    DefaultIconPos  = UDim2.new(0, 12, 0.5, -20),
    DefaultPanelPos = UDim2.new(0, 60, 0.5, -140),
    DefaultSize     = Vector2.new(210, 280),
    MinPanelSize    = Vector2.new(180, 230),
    MaxPanelSize    = Vector2.new(450, 650),
    LoadTimeout     = 12,
    MaxFails        = 5,

    DefaultMode = 2,
    PlaceModeConfig = {
        [8735521924] = 1,
    },

    LikeWeight    = 10,
    DislikeWeight = 5,
}

local FALLBACK_PLAYLIST = {
    { name = "Low Cortisol", id = "rbxassetid://110919391228823" },
}

-- ═══ HELPERS ═════════════════════════════════════════════════════════
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
local function postFB(path, data)   return httpReq(CONFIG.FirebaseURL .. path, "POST", HttpService:JSONEncode(data)) end
local function putFB(path, v)       return httpReq(CONFIG.FirebaseURL .. path, "PUT", HttpService:JSONEncode(v)) end
local function removeFB(path)       return httpReq(CONFIG.FirebaseURL .. path, "PUT", "null") end

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

local function extractAssetId(id) return tostring(id):match("%d+") or "0" end

local function shuffleList(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end

local function entryScore(e)
    return countKeys(e.likes) * CONFIG.LikeWeight - countKeys(e.dislikes) * CONFIG.DislikeWeight
end

local function sortByScore(list)
    table.sort(list, function(a, b)
        local sa, sb = entryScore(a), entryScore(b)
        if sa ~= sb then return sa > sb end
        local la, lb = countKeys(a.likes), countKeys(b.likes)
        if la ~= lb then return la > lb end
        return a.name < b.name
    end)
end

local function parseAssetId(input)
    if type(input) ~= "string" then return nil end
    input = input:match("^%s*(.-)%s*$")
    if input == "" then return nil end
    local m = input:match("[Rr][Bb][Xx][Aa][Ss][Ss][Ee][Tt][Ii][Dd]://(%d+)")
    if m then return "rbxassetid://" .. m end
    m = input:match("/[Ll][Ii][Bb][Rr][Aa][Rr][Yy]/(%d+)")
        or input:match("/[Aa][Uu][Dd][Ii][Oo]/(%d+)")
        or input:match("/[Aa][Ss][Ss][Ee][Tt]/(%d+)")
    if m then return "rbxassetid://" .. m end
    m = input:match("[?&][Ii][Dd]=(%d+)")
    if m then return "rbxassetid://" .. m end
    if input:match("^%d+$") and #input >= 5 then return "rbxassetid://" .. input end
    local longest = ""
    for num in input:gmatch("%d+") do
        if #num > #longest then longest = num end
    end
    if #longest >= 6 then return "rbxassetid://" .. longest end
    return nil
end

-- ═══ PLAYLIST ════════════════════════════════════════════════════════
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
    local base = fetchBasePlaylist()
    for _, e in ipairs(base) do
        e.ratingsKey = "a_" .. extractAssetId(e.id)
        e.isSubmission = false
        e.likes = {}; e.dislikes = {}
    end

    local subs = fetchFB("/submissions.json") or {}
    for pushId, sub in pairs(subs) do
        if type(sub) == "table" and sub.id and sub.name then
            table.insert(base, {
                name = tostring(sub.name), id = tostring(sub.id),
                ratingsKey = "s_" .. pushId, isSubmission = true,
                submittedBy = sub.submittedBy, submittedByName = sub.submittedByName,
                likes = {}, dislikes = {},
            })
        end
    end

    local seen, final = {}, {}
    for _, e in ipairs(base) do
        local key = extractAssetId(e.id)
        if not seen[key] then seen[key] = true; table.insert(final, e) end
    end
    base = final

    local ratings = fetchFB("/ratings.json") or {}
    for _, e in ipairs(base) do
        local r = ratings[e.ratingsKey]
        e.likes = (r and r.likes) or {}
        e.dislikes = (r and r.dislikes) or {}
    end

    sortByScore(base)
    return base
end

local Playlist = buildPlaylist()

local player = Players.LocalPlayer
if not player then return end
local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not pg then return end

local myUserId = tostring(player.UserId)
local preloadCache = {}

local existingIds = {}
local function registerId(assetId)
    local num = extractAssetId(assetId)
    if num ~= "0" and #num >= 5 then existingIds[num] = true end
end
local function isDuplicate(assetId)
    local num = extractAssetId(assetId)
    if num == "0" or #num < 5 then return false end
    return existingIds[num] == true
end
for _, e in ipairs(Playlist) do registerId(e.id) end

-- ═══ SOUND MODE RESOLVER ═════════════════════════════════════════════
local function resolveInitialMode()
    local m = CONFIG.PlaceModeConfig[game.PlaceId]
    if type(m) == "number" and m >= 1 and m <= 3 then return m end
    return CONFIG.DefaultMode
end

-- ═══ STATE ═══════════════════════════════════════════════════════════
local musicSound, musicState = nil, resolveInitialMode()
local currentIndex, musicVolume, musicPaused = 1, CONFIG.MusicVolume, false
local savedVols, mutedState = {}, { value = true }
local refreshUI, appendRowToUI
local currentPlayToken, consecutiveFails = 0, 0

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

-- ═══ AUDIO VALIDATION ════════════════════════════════════════════════
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
            if sound.PlaybackLoudness > maxLoud then maxLoud = sound.PlaybackLoudness end
        end
        pcall(function() sound:Stop() end)
    end
    sound:Destroy()
    if maxLoud < 3 then return false, "Audio is silent" end
    return true, math.floor(maxLoud)
end

-- ═══ DISCORD ═════════════════════════════════════════════════════════
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
        pcall(function() httpReq(CONFIG.DiscordWebhook, "POST", HttpService:JSONEncode(payload)) end)
    end)
end

local function sendReport(entry, reason)
    if not CONFIG.DiscordWebhook or CONFIG.DiscordWebhook == "" then return false, "Webhook not set" end
    local payload = {
        username = "REN Music Reports",
        embeds = {{
            title = "🚩 Song Report", color = 15158332,
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
    return false, "Failed to send report"
end

-- ═══ SUBMIT ══════════════════════════════════════════════════════════
local function submitSong(rawName, rawId, statusCb)
    local name = tostring(rawName or ""):gsub("%c", ""):match("^%s*(.-)%s*$")
    if #name < 1 or #name > 80 then return nil, "Name must be 1-80 characters" end

    statusCb("🔍 Parsing ID...")
    local assetId = parseAssetId(rawId)
    if not assetId then
        return nil, "Invalid ID. Example: 123456789, //123456789, rbxassetid://123, Roblox link"
    end
    if isDuplicate(assetId) then
        return nil, "Song (ID " .. extractAssetId(assetId) .. ") already in playlist"
    end

    statusCb("🔍 Validating audio...")
    local ok, loudnessOrErr = validateAudio(assetId)
    if not ok then return nil, loudnessOrErr end

    statusCb("📤 Uploading...")
    local r = postFB("/submissions.json", {
        name = name, id = assetId,
        submittedBy = player.UserId, submittedByName = player.Name,
        submittedAt = os.time(), loudness = loudnessOrErr,
    })
    if not r or not r.Body then return nil, "Upload failed (check connection)" end
    local ok2, dec = pcall(function() return HttpService:JSONDecode(r.Body) end)
    if not ok2 or not dec or not dec.name then return nil, "Invalid Firebase response" end

    local entry = {
        name = name, id = assetId,
        ratingsKey = "s_" .. dec.name, isSubmission = true,
        submittedBy = player.UserId, submittedByName = player.Name,
        likes = {}, dislikes = {},
    }
    table.insert(Playlist, entry)
    registerId(assetId)
    if appendRowToUI then appendRowToUI(#Playlist, entry) end
    notifyDiscord(entry, loudnessOrErr)
    return entry, nil
end

-- ═══ RATE ════════════════════════════════════════════════════════════
local function toggleRating(entry, kind)
    local opposite = (kind == "likes") and "dislikes" or "likes"
    local base = "/ratings/" .. entry.ratingsKey .. "/"
    if entry[kind][myUserId] then
        entry[kind][myUserId] = nil
        task.spawn(function() removeFB(base .. kind .. "/" .. myUserId .. ".json") end)
    else
        entry[kind][myUserId] = true
        if entry[opposite][myUserId] then
            entry[opposite][myUserId] = nil
            task.spawn(function() removeFB(base .. opposite .. "/" .. myUserId .. ".json") end)
        end
        task.spawn(function() putFB(base .. kind .. "/" .. myUserId .. ".json", true) end)
    end
end

-- ═══ PRELOAD ═════════════════════════════════════════════════════════
local function preloadAsset(assetId)
    if not assetId or preloadCache[assetId] then return end
    task.spawn(function()
        local s = Instance.new("Sound")
        s.SoundId = assetId; s.Volume = 0; s.Parent = SoundService
        local ok = pcall(function() ContentProvider:PreloadAsync({s}) end)
        s:Destroy()
        if ok then preloadCache[assetId] = true end
    end)
end

-- ═══ MUTE LOGIC ══════════════════════════════════════════════════════
local function saveGameSounds(except)
    savedVols = {}
    for _, root in ipairs({SoundService, workspace, game:GetService("Lighting")}) do
        pcall(function()
            for _, s in ipairs(root:GetDescendants()) do
                if s:IsA("Sound") and s ~= except and s.Name ~= "__REN_Music" then
                    savedVols[s] = s.Volume
                end
            end
        end)
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
    if musicState == 3 then
        setSoundsVol(false, musicSound); mutedState.value = false
        if musicSound then musicSound.Volume = 0 end
        return
    end
    local muteGame = (musicState == 1)
    setSoundsVol(muteGame, musicSound); mutedState.value = muteGame
    if musicSound then
        musicSound.Volume = musicVolume
        if musicSound.SoundId ~= "" and not musicPaused and not musicSound.Playing then
            pcall(function() musicSound:Play() end)
        end
    end
end

local function getModeText()
    if musicState == 1 then return "🎵"
    elseif musicState == 2 then return "🎵🔊"
    else return "🔊" end
end
local function getModeColor()
    if musicState == 1 then return Color3.fromRGB(40, 42, 55)
    elseif musicState == 2 then return Color3.fromRGB(60, 90, 60)
    else return Color3.fromRGB(90, 60, 60) end
end

-- ═══ PLAY + AUTO-SKIP (with retry-once) ══════════════════════════════
local function playSongAt(idx, isAutoSkip)
    if not musicSound or not musicSound.Parent then return end
    if not isAutoSkip then consecutiveFails = 0 end
    currentIndex = ((idx - 1) % #Playlist) + 1
    local entry = Playlist[currentIndex]
    if not entry then return end

    -- Reset retry flag when manually playing (not from auto-skip / retry)
    if not isAutoSkip then entry._retried = nil end

    musicPaused = false
    pcall(function() musicSound:Stop() end)
    musicSound.SoundId = entry.id
    musicSound.Volume = (musicState == 3) and 0 or musicVolume
    preloadAsset(entry.id)
    local nxt = Playlist[(currentIndex % #Playlist) + 1]
    if nxt then preloadAsset(nxt.id) end
    currentPlayToken = currentPlayToken + 1
    local myToken = currentPlayToken
    if refreshUI then refreshUI() end
    task.spawn(function()
        task.wait(0.1)
        pcall(function() musicSound:Play() end)
        local t0, loaded = tick(), false
        while (tick() - t0) < CONFIG.LoadTimeout do
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
            -- Retry once before skipping
            if not entry._retried then
                entry._retried = true
                task.wait(0.5)
                if currentPlayToken == myToken then playSongAt(currentIndex, true) end
                return
            end
            entry._retried = nil
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

-- ═══ UI ══════════════════════════════════════════════════════════════
local GREEN = Color3.fromRGB(0, 220, 160)
local TXT   = Color3.fromRGB(220, 220, 240)
local RED   = Color3.fromRGB(255, 100, 100)
local INFO  = Color3.fromRGB(180, 200, 220)

local function mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r) mk("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function pad(o, l, t)
    mk("UIPadding", {PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0)}, o)
end
local function button(parent, props, r)
    props.BorderSizePixel = 0
    props.AutoButtonColor = false
    props.Font = props.Font or Enum.Font.GothamBold
    props.TextColor3 = props.TextColor3 or TXT
    local b = mk("TextButton", props, parent)
    corner(b, r or 5)
    return b
end
local function label(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.Gotham
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return mk("TextLabel", props, parent)
end
local function input(parent, props)
    props.BorderSizePixel = 0
    props.BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(35, 40, 55)
    props.PlaceholderColor3 = Color3.fromRGB(140, 145, 165)
    props.TextColor3 = Color3.fromRGB(230, 230, 240)
    props.Font = Enum.Font.Gotham
    props.TextSize = 10
    props.TextXAlignment = Enum.TextXAlignment.Left
    props.ClearTextOnFocus = false
    props.Text = ""
    local b = mk("TextBox", props, parent)
    corner(b, 5); pad(b, 6, props.MultiLine and 4 or 0)
    return b
end

local function createMusicUI()
    local gui = mk("ScreenGui", {Name = "REN_MusicUI", ResetOnSpawn = false, DisplayOrder = 250}, pg)

    local icon = mk("TextButton", {
        Size = UDim2.fromOffset(40, 40), Position = CONFIG.DefaultIconPos,
        BackgroundColor3 = Color3.fromRGB(22, 26, 40), Text = "🎵", TextSize = 18,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 10,
    }, gui)
    corner(icon, 20)
    mk("UIStroke", {Color = GREEN, Thickness = 2}, icon)

    local panel = mk("Frame", {
        Size = UDim2.fromOffset(CONFIG.DefaultSize.X, CONFIG.DefaultSize.Y),
        Position = CONFIG.DefaultPanelPos,
        BackgroundColor3 = Color3.fromRGB(20, 24, 38),
        BorderSizePixel = 0, Visible = false,
    }, gui)
    corner(panel, 10)
    mk("UIStroke", {Color = GREEN, Thickness = 1.5}, panel)

    local header = mk("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Active = true}, panel)

    local uploadBtn = button(header, {
        Size = UDim2.fromOffset(60, 16), Position = UDim2.fromOffset(4, 4),
        BackgroundColor3 = Color3.fromRGB(0, 180, 130), Text = "Upload Song", TextSize = 8,
    })

    local hTitle = label(header, {
        Size = UDim2.new(1, -108, 1, 0), Position = UDim2.fromOffset(66, 0),
        TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd, TextXAlignment = Enum.TextXAlignment.Center,
    })

    local modeBtn = button(header, {
        Size = UDim2.fromOffset(36, 16), Position = UDim2.new(1, -40, 0, 4),
        BackgroundColor3 = getModeColor(), Text = getModeText(), TextSize = 10,
    })

    local searchBox = input(panel, {
        Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(8, 26),
        PlaceholderText = "Search songs...",
    })
    local function smallBtn(x, text, bg)
        return button(panel, {
            Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, x, 0, 26),
            BackgroundColor3 = bg or Color3.fromRGB(35, 40, 55), Text = text, TextSize = 11,
        })
    end
    local sortLikesBtn = smallBtn(-48, "📊", Color3.fromRGB(60, 90, 60))
    local shuffleBtn   = smallBtn(-24, "🔀")

    local listFrame = mk("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -118), Position = UDim2.fromOffset(8, 50),
        BackgroundColor3 = Color3.fromRGB(25, 30, 42), BorderSizePixel = 0,
        ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(0, 200, 140),
        CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, panel)
    corner(listFrame, 6)
    mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
        PaddingRight = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
    }, listFrame)

    local nowPlaying = label(panel, {
        Size = UDim2.new(1, -44, 0, 16), Position = UDim2.new(0, 8, 1, -64),
        TextColor3 = Color3.fromRGB(240, 240, 250), Font = Enum.Font.GothamBold, TextSize = 10,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local reportBtn = button(panel, {
        Size = UDim2.fromOffset(24, 16), Position = UDim2.new(1, -32, 1, -64),
        BackgroundColor3 = Color3.fromRGB(90, 40, 40), Text = "🚩", TextSize = 9,
    }, 4)

    local controls = mk("Frame", {
        Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 1, -44), BackgroundTransparency = 1,
    }, panel)
    mk("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, controls)
    local function ctl(order, text, bg, size)
        return button(controls, {
            Size = UDim2.new(0.25, -4, 1, 0), LayoutOrder = order,
            BackgroundColor3 = bg, Text = text, TextSize = size or 13,
        }, 6)
    end
    local prevBtn = ctl(1, "⏮", Color3.fromRGB(40, 46, 66))
    local playBtn = ctl(2, "⏸", Color3.fromRGB(0, 200, 140))
    local nextBtn = ctl(3, "⏭", Color3.fromRGB(40, 46, 66))
    local volBtn  = ctl(4, "", Color3.fromRGB(40, 46, 66), 9)

    local resizeHandle = mk("TextButton", {
        Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -18, 1, -18),
        BackgroundTransparency = 1, Text = "◢", TextColor3 = GREEN, TextSize = 14,
        BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 30,
    }, panel)

    local dialog = mk("Frame", {
        Size = UDim2.new(1, -16, 0, 140), Position = UDim2.fromOffset(8, 50),
        BackgroundColor3 = Color3.fromRGB(15, 18, 30), BorderSizePixel = 0, Visible = false, ZIndex = 20,
    }, panel)
    corner(dialog, 8)
    mk("UIStroke", {Color = GREEN, Thickness = 1.5}, dialog)
    label(dialog, {
        Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4), Text = "➕ Upload Song",
        TextColor3 = GREEN, Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 21,
    })
    local nameInput = input(dialog, {
        Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 24),
        PlaceholderText = "Song name...", ZIndex = 21,
    })
    local idInput = input(dialog, {
        Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 50),
        PlaceholderText = "ID / //ID / rbxassetid:// / link", ZIndex = 21,
    })
    label(dialog, {
        Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 75),
        Text = "Example: 123456789 • //123456789 • Roblox link",
        TextColor3 = Color3.fromRGB(120, 130, 150), TextSize = 8, ZIndex = 21,
    })
    local statusLbl = label(dialog, {
        Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 90),
        TextColor3 = INFO, TextSize = 9, TextWrapped = true, ZIndex = 21,
    })
    local cancelBtn = button(dialog, {
        Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0, 8, 1, -28),
        BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = "Cancel", TextSize = 10, ZIndex = 21,
    })
    local submitBtn = button(dialog, {
        Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0.5, 4, 1, -28),
        BackgroundColor3 = Color3.fromRGB(0, 180, 130), Text = "Submit", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 10, ZIndex = 21,
    })

    local reportDialog = mk("Frame", {
        Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 50),
        BackgroundColor3 = Color3.fromRGB(25, 15, 15), BorderSizePixel = 0, Visible = false, ZIndex = 20,
    }, panel)
    corner(reportDialog, 8)
    mk("UIStroke", {Color = Color3.fromRGB(220, 80, 80), Thickness = 1.5}, reportDialog)
    label(reportDialog, {
        Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4), Text = "🚩 Report Song",
        TextColor3 = Color3.fromRGB(255, 120, 120), Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 21,
    })
    local rSongLbl = label(reportDialog, {
        Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 22),
        TextColor3 = Color3.fromRGB(230, 200, 200), TextSize = 9,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21,
    })
    local reasonInput = input(reportDialog, {
        Size = UDim2.new(1, -16, 0, 66), Position = UDim2.fromOffset(8, 40),
        BackgroundColor3 = Color3.fromRGB(35, 25, 30), PlaceholderText = "Report reason...",
        TextYAlignment = Enum.TextYAlignment.Top, MultiLine = true, TextWrapped = true, ZIndex = 21,
    })
    local rStatus = label(reportDialog, {
        Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 108),
        TextColor3 = INFO, TextSize = 9, ZIndex = 21,
    })
    local rCancelBtn = button(reportDialog, {
        Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0, 8, 1, -28),
        BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = "Cancel", TextSize = 10, ZIndex = 21,
    })
    local rSendBtn = button(reportDialog, {
        Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0.5, 4, 1, -28),
        BackgroundColor3 = Color3.fromRGB(200, 60, 60), Text = "Send", TextColor3 = Color3.new(1, 1, 1),
        TextSize = 10, ZIndex = 21,
    })

    -- ══ LIST ROWS ═══════════════════════════════════════════════════
    local updateUI, applyFilter, updateHighlights, rebuildList, applySort
    local rowsByIdx = {}

    local function buildRow(idx, entry)
        local isCur = (idx == currentIndex)
        local row = mk("Frame", {
            Size = UDim2.new(1, 0, 0, 24), LayoutOrder = idx, BorderSizePixel = 0,
            BackgroundColor3 = isCur and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52),
        }, listFrame)

        local playRow = mk("TextButton", {
            Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(4, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
            Text = "", Font = Enum.Font.Gotham,
        }, row)

        local likeBtn = mk("TextButton", {
            Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -56, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 9, Font = Enum.Font.GothamBold,
        }, row)
        local dislikeBtn = mk("TextButton", {
            Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -28, 0, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 9, Font = Enum.Font.GothamBold,
        }, row)

        local function updateRatingUI()
            likeBtn.Text = "👍" .. countKeys(entry.likes)
            dislikeBtn.Text = "👎" .. countKeys(entry.dislikes)
            likeBtn.TextColor3 = entry.likes[myUserId] and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(160, 160, 180)
            dislikeBtn.TextColor3 = entry.dislikes[myUserId] and Color3.fromRGB(90, 140, 255) or Color3.fromRGB(160, 160, 180)
        end
        updateRatingUI()

        playRow.MouseButton1Click:Connect(function()
            for i, e in ipairs(Playlist) do
                if e == entry then playSongAt(i); break end
            end
        end)
        likeBtn.MouseButton1Click:Connect(function()
            toggleRating(entry, "likes"); updateRatingUI()
        end)
        dislikeBtn.MouseButton1Click:Connect(function()
            toggleRating(entry, "dislikes"); updateRatingUI()
        end)

        rowsByIdx[idx] = {row = row, playRow = playRow, entry = entry}
    end

    updateHighlights = function()
        for idx, d in pairs(rowsByIdx) do
            local cur = (idx == currentIndex)
            d.row.BackgroundColor3 = cur and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52)
            d.playRow.TextColor3 = cur and GREEN or Color3.fromRGB(220, 220, 235)
            d.playRow.Font = cur and Enum.Font.GothamBold or Enum.Font.Gotham
            d.playRow.Text = (cur and "▶ " or "") .. (d.entry.isSubmission and "📤 " or "") .. d.entry.name
        end
    end

    applyFilter = function()
        local txt = (searchBox.Text or ""):lower()
        for _, d in pairs(rowsByIdx) do
            local textMatch = txt == "" or d.entry.name:lower():find(txt, 1, true) ~= nil
            d.row.Visible = textMatch
        end
    end

    rebuildList = function()
        for _, c in ipairs(listFrame:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        rowsByIdx = {}
        for idx, entry in ipairs(Playlist) do buildRow(idx, entry) end
        applyFilter(); updateHighlights()
    end

    appendRowToUI = function(idx, entry)
        buildRow(idx, entry)
        applyFilter(); updateHighlights()
    end

    applySort = function(mode)
        local cur = Playlist[currentIndex]
        if mode == "likes" then
            sortByScore(Playlist)
        else
            shuffleList(Playlist)
        end
        if cur then
            for i, e in ipairs(Playlist) do
                if e == cur then currentIndex = i; break end
            end
        end
        rebuildList(); updateUI()
    end

    updateUI = function()
        local entry = Playlist[currentIndex]
        hTitle.Text = "🎵 Music (" .. #Playlist .. ")"
        nowPlaying.Text = entry and entry.name or "-"
        rSongLbl.Text = entry and entry.name or "-"
        playBtn.Text = musicPaused and "▶" or "⏸"
        playBtn.BackgroundColor3 = musicPaused and Color3.fromRGB(200, 150, 50) or Color3.fromRGB(0, 200, 140)
        modeBtn.Text = getModeText(); modeBtn.BackgroundColor3 = getModeColor()
        volBtn.Text = "🔉" .. math.floor(musicVolume * 100) .. "%"
    end

    refreshUI = function() updateUI(); updateHighlights() end

    -- ══ EVENTS ══════════════════════════════════════════════════════
    searchBox:GetPropertyChangedSignal("Text"):Connect(applyFilter)

    local function markSort(likes)
        sortLikesBtn.BackgroundColor3 = likes and Color3.fromRGB(60, 90, 60) or Color3.fromRGB(35, 40, 55)
        shuffleBtn.BackgroundColor3 = likes and Color3.fromRGB(35, 40, 55) or Color3.fromRGB(60, 90, 60)
    end
    sortLikesBtn.MouseButton1Click:Connect(function() markSort(true); applySort("likes") end)
    shuffleBtn.MouseButton1Click:Connect(function() markSort(false); applySort("shuffle") end)

    uploadBtn.MouseButton1Click:Connect(function()
        dialog.Visible = true; statusLbl.Text = ""; reportDialog.Visible = false
    end)
    cancelBtn.MouseButton1Click:Connect(function()
        dialog.Visible = false
        nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
    end)

    local submitting = false
    submitBtn.MouseButton1Click:Connect(function()
        if submitting then return end
        submitting = true; submitBtn.Visible = false
        task.spawn(function()
            local entry, err = submitSong(nameInput.Text, idInput.Text, function(msg)
                statusLbl.Text = msg; statusLbl.TextColor3 = INFO
            end)
            submitting = false; submitBtn.Visible = true
            if entry then
                statusLbl.Text = "✅ Success!"; statusLbl.TextColor3 = GREEN
                task.wait(0.8)
                dialog.Visible = false
                nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
                for i, e in ipairs(Playlist) do
                    if e == entry then playSongAt(i); break end
                end
            else
                statusLbl.Text = "❌ " .. tostring(err); statusLbl.TextColor3 = RED
            end
        end)
    end)

    reportBtn.MouseButton1Click:Connect(function()
        reportDialog.Visible = true; dialog.Visible = false
        rStatus.Text = ""; reasonInput.Text = ""
        local entry = Playlist[currentIndex]
        rSongLbl.Text = entry and entry.name or "-"
    end)
    rCancelBtn.MouseButton1Click:Connect(function()
        reportDialog.Visible = false; reasonInput.Text = ""; rStatus.Text = ""
    end)

    local sendingReport = false
    rSendBtn.MouseButton1Click:Connect(function()
        if sendingReport then return end
        local entry = Playlist[currentIndex]
        if not entry then rStatus.Text = "❌ No song"; rStatus.TextColor3 = RED; return end
        local reason = reasonInput.Text
        if not reason or #reason < 5 then
            rStatus.Text = "❌ Min 5 characters"; rStatus.TextColor3 = RED; return
        end
        if #reason > 500 then reason = reason:sub(1, 500) end
        sendingReport = true; rSendBtn.Text = "..."
        rStatus.Text = "📤 Sending..."; rStatus.TextColor3 = INFO
        task.spawn(function()
            local ok, err = sendReport(entry, reason)
            sendingReport = false; rSendBtn.Text = "Send"
            if ok then
                rStatus.Text = "✅ Sent!"; rStatus.TextColor3 = GREEN
                task.wait(1.2); reportDialog.Visible = false
                reasonInput.Text = ""; rStatus.Text = ""
            else
                rStatus.Text = "❌ " .. tostring(err); rStatus.TextColor3 = RED
            end
        end)
    end)

    prevBtn.MouseButton1Click:Connect(function() playSongAt(currentIndex - 1) end)
    nextBtn.MouseButton1Click:Connect(function() playSongAt(currentIndex + 1) end)
    playBtn.MouseButton1Click:Connect(function()
        if musicPaused then musicPaused = false; pcall(function() musicSound:Resume() end)
        else musicPaused = true; pcall(function() musicSound:Pause() end) end
        currentPlayToken = currentPlayToken + 1; updateUI()
    end)
    modeBtn.MouseButton1Click:Connect(function()
        musicState = (musicState % 3) + 1
        applyMusicState(); updateUI()
    end)
    volBtn.MouseButton1Click:Connect(function()
        musicVolume = musicVolume + 0.1
        if musicVolume > 1.05 then musicVolume = 0 end
        musicVolume = math.clamp(musicVolume, 0, 1)
        if musicSound and musicState ~= 3 then musicSound.Volume = musicVolume end
        updateUI()
    end)

    -- ══ DRAG / RESIZE ═══════════════════════════════════════════════
    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    local function isMove(i)
        return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch
    end

    local drag, dragStart, startPos, startSize, iconMoved = nil, nil, nil, nil, false

    header.InputBegan:Connect(function(i)
        if isPress(i) then drag = "panel"; dragStart = i.Position; startPos = panel.Position end
    end)
    resizeHandle.InputBegan:Connect(function(i)
        if isPress(i) then drag = "resize"; dragStart = i.Position; startSize = panel.AbsoluteSize end
    end)
    icon.InputBegan:Connect(function(i)
        if isPress(i) then drag = "icon"; dragStart = i.Position; startPos = icon.Position; iconMoved = false end
    end)

    UIS.InputChanged:Connect(function(i)
        if not drag or not isMove(i) then return end
        local d = i.Position - dragStart
        if drag == "panel" then
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        elseif drag == "resize" then
            local w = math.clamp(startSize.X + d.X, CONFIG.MinPanelSize.X, CONFIG.MaxPanelSize.X)
            local h = math.clamp(startSize.Y + d.Y, CONFIG.MinPanelSize.Y, CONFIG.MaxPanelSize.Y)
            panel.Size = UDim2.fromOffset(w, h)
        elseif drag == "icon" then
            if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then iconMoved = true end
            if iconMoved then
                icon.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if not isPress(i) or not drag then return end
        if drag == "icon" and not iconMoved then
            panel.Visible = not panel.Visible
            if panel.Visible then
                dialog.Visible = false; reportDialog.Visible = false
                updateUI()
            end
            icon.BackgroundColor3 = panel.Visible and Color3.fromRGB(0, 180, 130) or Color3.fromRGB(22, 26, 40)
        end
        drag = nil
    end)

    rebuildList()
    updateUI()
end

-- ═══ BOOT ════════════════════════════════════════════════════════════
initMusic()
createMusicUI()

print("[Music] READY v3.6 | Playlist:", #Playlist, "| Mode:", musicState, "| PlaceId:", game.PlaceId)
