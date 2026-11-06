--[[ RATINGS — toggle like / dislike dengan optimistic update ]]

return function(REN)
    local S  = REN.State
    local FB = REN.Firebase

    local function toggleRating(entry, kind)
        local opposite = (kind == "likes") and "dislikes" or "likes"
        local base = "/ratings/" .. entry.ratingsKey .. "/"

        if entry[kind][S.myUserId] then
            entry[kind][S.myUserId] = nil
            task.spawn(function()
                FB.remove(base .. kind .. "/" .. S.myUserId .. ".json")
            end)
        else
            entry[kind][S.myUserId] = true
            if entry[opposite][S.myUserId] then
                entry[opposite][S.myUserId] = nil
                task.spawn(function()
                    FB.remove(base .. opposite .. "/" .. S.myUserId .. ".json")
                end)
            end
            task.spawn(function()
                FB.put(base .. kind .. "/" .. S.myUserId .. ".json", true)
            end)
        end
    end

    REN.Ratings = { toggle = toggleRating }
end
