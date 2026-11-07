--[[ SUBMIT — upload lagu baru (parse → validate → POST → notify) ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local U  = REN.Utils
    local S  = REN.State
    local FB = REN.Firebase
    local PL = REN.Playlist
    local A  = REN.Audio
    local So = REN.Social

    local function submitSong(rawName, rawId, statusCb)
        local name = tostring(rawName or ""):gsub("%c", ""):match("^%s*(.-)%s*$")
        if #name < 1 or #name > 80 then
            return nil, "Name must be 1-80 characters"
        end

        statusCb("🔍 Parsing ID...")
        local assetId = U.parseAssetId(rawId)
        if not assetId then
            return nil, "Invalid ID. Example: 123456789, //123456789, rbxassetid://123, Roblox link"
        end
        if PL.isDuplicate(assetId) then
            return nil, "Song (ID " .. U.extractAssetId(assetId) .. ") already in playlist"
        end

        statusCb("🔍 Validating audio...")
        local ok, loudnessOrErr = A.validate(assetId)
        if not ok then return nil, loudnessOrErr end

        statusCb("📤 Uploading...")
        local r = FB.post("/submissions.json", {
            name = name, id = assetId,
            submittedBy     = S.player.UserId,
            submittedByName = S.player.Name,
            submittedAt     = os.time(),
            loudness        = loudnessOrErr,
        })
        if not r or not r.Body then return nil, "Upload failed (check connection)" end

        local ok2, dec = pcall(function() return HttpService:JSONDecode(r.Body) end)
        if not ok2 or not dec or not dec.name then
            return nil, "Invalid Firebase response"
        end

        local entry = {
            name = name, id = assetId,
            ratingsKey      = "s_" .. dec.name,
            isSubmission    = true,
            submittedBy     = S.player.UserId,
            submittedByName = S.player.Name,
            uploader        = S.player.Name,
            likes = {}, dislikes = {},
        }
        table.insert(S.allSongs, entry)
        PL.registerId(assetId)
        -- Di mode "My Likes" lagu baru belum di-like, jadi tidak masuk list aktif.
        if S.viewMode ~= "mine" then
            table.insert(S.playlist, entry)
            if S.appendRowToUI then S.appendRowToUI(#S.playlist, entry) end
        end
        So.notifyDiscord(entry, loudnessOrErr)
        return entry, nil
    end

    REN.Submit = { submit = submitSong }
end
