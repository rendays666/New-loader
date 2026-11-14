--[[
  RENRENHUB — MUSIC LOADER v3.9.2
  Entry point. URL TIDAK berubah.
  (Loading GUI & log panel sudah dihapus — error hanya di console via warn.)
]]

local SCRIPT_VERSION = "3.9.2"

local BASE_URLS = {
    "https://raw.githubusercontent.com/rendays666/New-loader/main/music_modules/",
    "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music_modules/",
}

local MODULE_ORDER = {
    "config", "state", "utils", "persist", "firebase", "playlist",
    "audio", "social", "submit", "ratings",
    "ui/widgets", "ui/dialogs", "ui/info", "ui/rows", "ui/panel",
    "bootstrap",
}

local NAME_ALIASES = {
    submit = { "submit", "sumbit" },
}

local function fail(msg)
    pcall(warn, "[Music] " .. tostring(msg))
end

-- ═══ WAIT FOR LOCALPLAYER & PLAYERGUI ═════════════════════════════
local function waitForPlayer(timeout)
    local Players = game:GetService("Players")
    local t0 = tick()
    repeat
        local plr = Players.LocalPlayer
        if plr then
            local pg = plr:FindFirstChild("PlayerGui")
            if pg then return plr, pg end
        end
        task.wait(0.2)
    until tick() - t0 > (timeout or 30)
    return nil, nil
end

-- ═══ HTTP FETCH ═══════════════════════════════════════════════════
local function validResponse(r)
    if type(r) ~= "string" or #r == 0 then return false end
    if r:match("^404:") or r:match("^<") then return false end
    return true
end

local function httpFetchOnce(url)
    -- 1. game:HttpGet
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and validResponse(res) then return res end

    -- 2. cache-bust
    local sep = url:find("?") and "&" or "?"
    local bustUrl = url .. sep .. "_t=" .. tostring(os.time())
    ok, res = pcall(function() return game:HttpGet(bustUrl, true) end)
    if ok and validResponse(res) then return res end

    -- 3. HttpService:GetAsync
    local HttpService = game:GetService("HttpService")
    ok, res = pcall(function() return HttpService:GetAsync(url, true) end)
    if ok and validResponse(res) then return res end

    -- 4. syn.request
    if syn and syn.request then
        ok, res = pcall(function()
            local r = syn.request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
    end

    -- 5. http_request / request
    for _, fnName in ipairs({"http_request", "request"}) do
        local fn = rawget(getfenv(), fnName) or rawget(_G, fnName)
        if type(fn) == "function" then
            ok, res = pcall(function()
                local r = fn({ Url = url, Method = "GET" })
                return r and r.Body
            end)
            if ok and validResponse(res) then return res end
        end
    end

    return nil
end

local function fetchModule(name)
    local names = NAME_ALIASES[name] or { name }
    for _, tryName in ipairs(names) do
        for _, base in ipairs(BASE_URLS) do
            local source = httpFetchOnce(base .. tryName .. ".lua")
            if source then return source end
        end
    end
    return nil
end

-- ═══ COMPILER ═════════════════════════════════════════════════════
local function compileSource(name, source)
    local chunkName = "=music_modules/" .. name
    if loadstring then
        local fn = loadstring(source, chunkName)
        if fn then return fn end
        fn = loadstring(source)
        if fn then return fn end
    end
    if load then
        local fn = load(source, chunkName)
        if fn then return fn end
        fn = load(source)
        if fn then return fn end
    end
    return nil, "loadstring/load tidak tersedia atau source invalid"
end

-- ═══ MAIN ═════════════════════════════════════════════════════════
local function main()
    -- Penanda: kalau baris ini tidak muncul di console, script ini tidak jalan sama sekali.
    pcall(print, "[Music] Loader v" .. SCRIPT_VERSION .. " mulai...")
    local player, pg = waitForPlayer(30)
    if not player or not pg then
        fail("LocalPlayer/PlayerGui tidak tersedia setelah 30 detik")
        return
    end

    local REN = { version = SCRIPT_VERSION }
    local env = (getgenv and getgenv()) or _G
    -- Cache modul hanya dipakai ulang kalau versinya sama; kalau SCRIPT_VERSION
    -- naik, semua modul diambil ulang (kalau tidak, re-execute masih pakai kode lama).
    if env.__REN_MUSIC_CACHE_VER ~= SCRIPT_VERSION then
        env.__REN_MUSIC_MODULES = {}
        env.__REN_MUSIC_CACHE_VER = SCRIPT_VERSION
    end
    local CACHE = env.__REN_MUSIC_MODULES or {}
    env.__REN_MUSIC_MODULES = CACHE

    for _, name in ipairs(MODULE_ORDER) do
        local source = CACHE[name]
        if not source then
            source = fetchModule(name)
            if not source then
                fail(string.format("Gagal ambil '%s.lua' dari semua URL", name))
                return
            end
            CACHE[name] = source
        end

        local fn, cerr = compileSource(name, source)
        if not fn then
            fail(string.format("Compile gagal '%s': %s", name, tostring(cerr)))
            return
        end

        -- Setiap modul berbentuk `return function(REN) ... end`,
        -- jadi function yang di-return harus dipanggil lagi.
        local success, result = pcall(fn, REN)
        if success and type(result) == "function" then
            success, result = pcall(result, REN)
        end
        if not success then
            fail(string.format("Eksekusi gagal '%s': %s", name, tostring(result)))
            return
        end

        task.wait(0.03)
    end
end

local ok, err = pcall(main)
if not ok then
    fail("FATAL: " .. tostring(err))
end
