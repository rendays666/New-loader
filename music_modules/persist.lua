--[[ PERSIST — simpan & baca state musik (lagu terakhir, posisi, volume, mode list)
     Disimpan ke file executor (writefile/readfile). Kalau executor tidak
     mendukung file, fallback ke getgenv() (bertahan selama sesi/re-execute). ]]

return function(REN)
    local HttpService = game:GetService("HttpService")
    local C = REN.Config
    local env = (getgenv and getgenv()) or _G
    local P = {}

    local lastEncoded = nil

    local function hasFS()
        return type(writefile) == "function" and type(readfile) == "function"
    end

    function P.load()
        local data

        if hasFS() then
            local okExists, exists = pcall(function()
                return type(isfile) ~= "function" or isfile(C.SaveFile)
            end)
            if okExists and exists then
                local okRead, raw = pcall(readfile, C.SaveFile)
                if okRead and type(raw) == "string" and raw ~= "" then
                    local okDec, dec = pcall(function()
                        return HttpService:JSONDecode(raw)
                    end)
                    if okDec and type(dec) == "table" then data = dec end
                end
            end
        end

        if not data and type(env.__REN_MUSIC_SAVE) == "table" then
            data = env.__REN_MUSIC_SAVE
        end
        return data
    end

    function P.save(data)
        if type(data) ~= "table" then return end

        local okEnc, encoded = pcall(function()
            return HttpService:JSONEncode(data)
        end)
        if not okEnc then return end
        if encoded == lastEncoded then return end   -- tidak ada perubahan
        lastEncoded = encoded

        env.__REN_MUSIC_SAVE = data

        if hasFS() then
            pcall(function()
                if type(makefolder) == "function" and type(isfolder) == "function"
                   and not isfolder(C.SaveFolder) then
                    makefolder(C.SaveFolder)
                end
            end)
            pcall(writefile, C.SaveFile, encoded)
        end
    end

    REN.Persist = P
end
