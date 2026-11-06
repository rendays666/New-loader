--[[ UTILS — helper murni, HTTP, parsing ID, scoring, sorting ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C = REN.Config
    local U = {}

    function U.httpReq(url, method, body)
        local p = {Url=url, Method=method, Headers={["Content-Type"]="application/json"}, Body=body}
        local ok, r = pcall(function() return syn and syn.request(p) end)
        if ok and r then return r end
        ok, r = pcall(function() return http_request(p) end)
        if ok and r then return r end
        ok, r = pcall(function() return request(p) end)
        if ok and r then return r end
        return nil
    end

    function U.fetchURL(url)
        local ok, r = pcall(function() return game:HttpGet(url, true) end)
        if ok and r and r ~= "" then return r end
        return nil
    end

    function U.countKeys(t)
        local n = 0
        if type(t) ~= "table" then return 0 end
        for _ in pairs(t) do n = n + 1 end
        return n
    end

    function U.extractAssetId(id)
        return tostring(id):match("%d+") or "0"
    end

    function U.shuffleList(list)
        for i = #list, 2, -1 do
            local j = math.random(i)
            list[i], list[j] = list[j], list[i]
        end
    end

    function U.entryScore(e)
        return U.countKeys(e.likes) * C.LikeWeight
             - U.countKeys(e.dislikes) * C.DislikeWeight
    end

    function U.sortByScore(list)
        table.sort(list, function(a, b)
            local sa, sb = U.entryScore(a), U.entryScore(b)
            if sa ~= sb then return sa > sb end
            local la, lb = U.countKeys(a.likes), U.countKeys(b.likes)
            if la ~= lb then return la > lb end
            return a.name < b.name
        end)
    end

    function U.parseAssetId(input)
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

        if input:match("^%d+$") and #input >= 5 then
            return "rbxassetid://" .. input
        end

        local longest = ""
        for num in input:gmatch("%d+") do
            if #num > #longest then longest = num end
        end
        if #longest >= 6 then return "rbxassetid://" .. longest end
        return nil
    end

    REN.Utils = U
end
