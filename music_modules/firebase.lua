--[[ FIREBASE — wrapper CRUD Firebase Realtime DB ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C = REN.Config
    local U = REN.Utils
    local F = {}

    function F.fetch(path)
        local r = U.httpReq(C.FirebaseURL .. path, "GET")
        if not r or not r.Body or r.Body == "null" then return nil end
        local ok, data = pcall(function() return HttpService:JSONDecode(r.Body) end)
        if ok then return data end
        return nil
    end

    function F.post(path, data)
        return U.httpReq(C.FirebaseURL .. path, "POST", HttpService:JSONEncode(data))
    end

    function F.put(path, v)
        return U.httpReq(C.FirebaseURL .. path, "PUT", HttpService:JSONEncode(v))
    end

    function F.remove(path)
        return U.httpReq(C.FirebaseURL .. path, "PUT", "null")
    end

    REN.Firebase = F
end
