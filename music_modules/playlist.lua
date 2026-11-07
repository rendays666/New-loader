--[[ PLAYLIST — fetch base + merge submissions + attach ratings + sort
     & dedup helpers (registerId / isDuplicate) ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C  = REN.Config
    local U  = REN.Utils
    local FB = REN.Firebase
    local S  = REN.State

    local function fetchBasePlaylist()
        if not C.PlaylistURL or C.PlaylistURL == "" then return REN.FallbackPlaylist end
        local res = U.fetchURL(C.PlaylistURL)
        if not res then return REN.FallbackPlaylist end
        local ok, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok or type(data) ~= "table" then return REN.FallbackPlaylist end

        local list = data.songs or data
        local clean = {}
        for _, e in ipairs(list) do
            if type(e) == "table" and e.id and e.name then
                table.insert(clean, { name = tostring(e.name), id = tostring(e.id) })
            end
        end
        if #clean == 0 then return REN.FallbackPlaylist end
        return clean
    end

    local function buildPlaylist()
        local base = fetchBasePlaylist()

        for _, e in ipairs(base) do
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

    -- ── View mode: top (urut skor like) → mine (lagu yang aku like) → shuffle ──
    local VIEW_ORDER = { "top", "mine", "shuffle" }
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
