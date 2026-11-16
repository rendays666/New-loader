--[[ PLAYLIST — fetch base + merge submissions + attach ratings + sort
     & dedup helpers (registerId / isDuplicate) ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C  = REN.Config
    local U  = REN.Utils
    local FB = REN.Firebase
    local S  = REN.State

    -- Pesan masuk ke panel log loader (REN.Log); kalau tidak ada, ke console.
    local function logLine(level, msg)
        if REN.Log then
            REN.Log.add(level, msg)
        else
            pcall(level == "warn" and warn or print, "[Music] " .. msg)
        end
    end

    -- Fallback tidak diam-diam: alasannya dicatat sebagai warning.
    local function useFallback(reason)
        logLine("warn", "Playlist FALLBACK (" .. reason .. ") | URL = " .. tostring(C.PlaylistURL))
        return REN.FallbackPlaylist
    end

    -- ── Urutan "By Update" (lagu yang baru ditambahkan di paling atas) ──────
    -- playlist.json tidak punya tanggal, jadi aturannya:
    --   1. Lagu yang punya waktu -> yang paling baru di atas. Waktu berasal dari:
    --        - lagu upload lewat GUI (waktu server Firebase dari push ID)
    --        - entri playlist.json yang diberi field "addedAt" (unix detik)
    --   2. Lagu playlist.json tanpa waktu -> mengikuti urutan baris di file.
    -- BASE_NEWEST_LAST = true  : baris PALING BAWAH di playlist.json = paling baru
    --                    false : baris PALING ATAS di playlist.json = paling baru
    local BASE_NEWEST_LAST = true

    -- Firebase push ID: 8 karakter pertama = waktu (milidetik) dalam basis-64.
    -- Dibaca dari ID, bukan dari field "submittedAt" yang dikirim klien, supaya
    -- tidak bisa dipalsukan.
    local PUSH_CHARS = "-0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"
    local function pushIdToTime(id)
        if type(id) ~= "string" or #id < 8 then return nil end
        local ms = 0
        for i = 1, 8 do
            local pos = PUSH_CHARS:find(id:sub(i, i), 1, true)
            if not pos then return nil end
            ms = ms * 64 + (pos - 1)
        end
        return math.floor(ms / 1000)
    end

    local function fetchBasePlaylist()
        if not C.PlaylistURL or C.PlaylistURL == "" then
            return useFallback("PlaylistURL kosong")
        end
        local res = U.fetchURL(C.PlaylistURL)
        if not res then return useFallback("HttpGet gagal / respons kosong") end
        local ok, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok or type(data) ~= "table" then
            return useFallback("JSON tidak valid: " .. tostring(data)
                .. " | awal respons: " .. tostring(res):sub(1, 60))
        end

        local list = data.songs or data
        local clean = {}
        for _, e in ipairs(list) do
            if type(e) == "table" and e.id and e.name then
                table.insert(clean, {
                    name = tostring(e.name), id = tostring(e.id),
                    addedAt = tonumber(e.addedAt),   -- opsional, unix detik
                })
            end
        end
        if #clean == 0 then return useFallback("0 entri valid di playlist.json") end
        logLine("ok", "Playlist OK: " .. #clean .. " lagu dari playlist.json")
        return clean
    end

    local function buildPlaylist()
        local base = fetchBasePlaylist()

        for i, e in ipairs(base) do
            e.baseIdx      = i      -- urutan baris di playlist.json (untuk "By Update")
            e.ratingsKey   = "a_" .. U.extractAssetId(e.id)
            e.isSubmission = false
            e.likes        = {}
            e.dislikes     = {}
            e.uploader     = C.DefaultUploader
        end

        local subs = FB.fetch("/submissions.json") or {}
        for pushId, sub in pairs(subs) do
            if type(sub) == "table" and sub.id and sub.name then
                table.insert(base, {
                    name = tostring(sub.name), id = tostring(sub.id),
                    ratingsKey = "s_" .. pushId, isSubmission = true,
                    submittedBy = sub.submittedBy, submittedByName = sub.submittedByName,
                    uploader = (type(sub.submittedByName) == "string" and sub.submittedByName ~= "")
                        and sub.submittedByName or "unknown",
                    addedAt = pushIdToTime(pushId) or tonumber(sub.submittedAt),
                    likes = {}, dislikes = {},
                })
            end
        end

        local seen, final = {}, {}
        for _, e in ipairs(base) do
            local key = U.extractAssetId(e.id)
            if not seen[key] then seen[key] = true; table.insert(final, e) end
        end
        base = final

        local ratings = FB.fetch("/ratings.json") or {}
        for _, e in ipairs(base) do
            local r = ratings[e.ratingsKey]
            e.likes    = (r and r.likes) or {}
            e.dislikes = (r and r.dislikes) or {}
        end

        U.sortByScore(base)
        return base
    end

    S.allSongs = buildPlaylist()

    local PL = {}

    -- Terbaru di atas. Comparator ini valid sebagai strict weak ordering:
    -- yang bertanggal selalu di atas yang tidak, lalu tie-break berurutan.
    local function sortByUpdate(list)
        table.sort(list, function(a, b)
            local ta, tb = a.addedAt, b.addedAt
            if ta and tb then
                if ta ~= tb then return ta > tb end
            elseif ta then
                return true
            elseif tb then
                return false
            end
            local ia, ib = a.baseIdx or 0, b.baseIdx or 0
            if ia ~= ib then
                if BASE_NEWEST_LAST then return ia > ib end
                return ia < ib
            end
            return a.name < b.name
        end)
    end
    PL.sortByUpdate = sortByUpdate
    PL.pushIdToTime = pushIdToTime

    -- ── View mode: top → mine → shuffle → update (By Update), lalu ulang ──
    local VIEW_ORDER = { "top", "mine", "shuffle", "update" }
    PL.VIEW_ORDER = VIEW_ORDER

    function PL.nextView(mode)
        mode = mode or S.viewMode
        for i, m in ipairs(VIEW_ORDER) do
            if m == mode then return VIEW_ORDER[(i % #VIEW_ORDER) + 1] end
        end
        return VIEW_ORDER[1]
    end

    -- Bangun ulang S.playlist sesuai mode. Return jumlah lagu di list.
    -- Entry sama persis dengan di S.allSongs, jadi like/dislike selalu sinkron.
    function PL.setView(mode)
        local list = {}
        if mode == "mine" then
            for _, e in ipairs(S.allSongs) do
                if e.likes[S.myUserId] then list[#list + 1] = e end
            end
            U.sortByScore(list)
        else
            for _, e in ipairs(S.allSongs) do list[#list + 1] = e end
            if mode == "shuffle" then
                U.shuffleList(list)
            elseif mode == "update" then
                sortByUpdate(list)
            else
                mode = "top"
                U.sortByScore(list)
            end
        end

        S.viewMode = mode
        S.playlist = list

        -- cari ulang posisi lagu yang sedang diputar (bisa tidak ada di list ini)
        S.currentIndex = 0
        local cur = S.currentEntry
        if cur then
            for i, e in ipairs(list) do
                if e == cur then S.currentIndex = i; break end
            end
        end
        return #list
    end

    PL.setView("top")
    function PL.registerId(assetId)
        local num = U.extractAssetId(assetId)
        if num ~= "0" and #num >= 5 then S.existingIds[num] = true end
    end
    function PL.isDuplicate(assetId)
        local num = U.extractAssetId(assetId)
        if num == "0" or #num < 5 then return false end
        return S.existingIds[num] == true
    end
    function PL.build() return buildPlaylist() end

    for _, e in ipairs(S.allSongs) do PL.registerId(e.id) end

    REN.Playlist = PL
end
