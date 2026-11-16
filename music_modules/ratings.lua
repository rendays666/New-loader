--[[ RATINGS — toggle like / dislike dengan optimistic update ]]

return function(REN)
    local S  = REN.State
    local FB = REN.Firebase

    -- Listener dipanggil setiap rating sebuah lagu berubah, dari tombol mana pun
    -- (baris list atau Now Playing), supaya semua tampilan lagu itu tetap sinkron.
    local listeners = {}
    local function notify(entry)
        for _, fn in ipairs(listeners) do pcall(fn, entry) end
    end

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
        notify(entry)
    end

    REN.Ratings = {
        toggle   = toggleRating,
        onChange = function(fn) listeners[#listeners + 1] = fn end,
    }
end
