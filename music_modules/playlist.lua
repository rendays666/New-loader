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
        end

        local subs = FB.fetch("/submissions.json") or {}
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

    S.playlist = buildPlaylist()

    local PL = {}
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

    for _, e in ipairs(S.playlist) do PL.registerId(e.id) end

    REN.Playlist = PL
end
