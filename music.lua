--[[
  RENRENHUB — MUSIC LOADER v3.10.0
  Entry point. URL TIDAK berubah.

  LOG LOADER: atur lewat CONFIG di bawah. Panel log (modul `logger`) dimuat
  PERTAMA, jadi progres & error loading langsung kelihatan di layar dan bisa
  di-copy. Kalau semua sukses, panel hilang sendiri (bisa dimatikan).
]]

local SCRIPT_VERSION = "3.10.0"

-- ═══ CONFIG LOG (EDIT DI SINI) ═════════════════════════════════════
local CONFIG = {
    LOG_REALTIME      = false,  -- true  = panel log tampil selama loading
                               -- false = panel tidak tampil (console tetap jalan)
    LOG_AUTOHIDE      = true,  -- true  = panel hilang sendiri kalau semua modul sukses
                               --         tanpa warning/error
    LOG_HIDE_DELAY    = 2,     -- detik jeda sebelum panel hilang
    LOG_SHOW_ON_ISSUE = true,  -- true  = walau LOG_REALTIME=false, panel tetap muncul
                               --         saat ada warning/error (supaya bisa di-copy)
}
-- ═══════════════════════════════════════════════════════════════════

local BASE_URLS = {
    "https://raw.githubusercontent.com/rendays666/New-loader/main/music_modules/",
    "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music_modules/",
}

-- "logger" HARUS paling depan: modul ini mandiri (tidak butuh config/widgets).
local MODULE_ORDER = {
    "logger",
    "config", "state", "utils", "persist", "firebase", "playlist",
    "audio", "social", "submit", "ratings",
    "ui/widgets", "ui/dialogs", "ui/info", "ui/rows", "ui/panel",
    "bootstrap",
}

local NAME_ALIASES = {
    submit = { "submit", "sumbit" },
}

-- Modul yang boleh gagal tanpa menghentikan loader (musik tetap jalan).
local OPTIONAL = { logger = true }

-- ═══ LOG CORE ═════════════════════════════════════════════════════
-- Hidup dari baris pertama script, sebelum modul apa pun dimuat. Semua pesan
-- ditampung di LOG.lines; modul `logger` menampilkannya sebagai panel.
local T0 = tick()
local ICON = { info = "•", ok = "✔", warn = "⚠", error = "✖" }

local LOG = {
    lines = {}, hasError = false, hasWarn = false,
    done = 0, total = 0,
    sink = nil,     -- diisi modul logger
    finish = nil,   -- diisi modul logger
}

function LOG.add(level, msg)
    if not ICON[level] then level = "info" end
    msg = tostring(msg)
    if level == "error" then LOG.hasError = true
    elseif level == "warn" then LOG.hasWarn = true end

    local entry = {
        level = level,
        text = string.format("%s %5.1fs  %s", ICON[level], tick() - T0, msg),
    }
    LOG.lines[#LOG.lines + 1] = entry

    local out = (level == "warn" or level == "error") and warn or print
    pcall(out, "[Music] " .. msg)
    if LOG.sink then pcall(LOG.sink, entry) end
end

function LOG.text()
    local t = {}
    for i, e in ipairs(LOG.lines) do t[i] = e.text end
    return table.concat(t, "\n")
end

-- Panel darurat: dipakai kalau modul `logger` sendiri gagal dimuat tapi ada
-- warning/error, supaya pesannya tetap kelihatan.
local PG = nil
local function emergencyPanel()
    if LOG.sink then return end
    pcall(function()
        local target = PG
        if not target then
            local lp = game:GetService("Players").LocalPlayer
            target = lp and lp:FindFirstChildOfClass("PlayerGui")
        end
        if not target and gethui then target = gethui() end
        if not target then return end

        local old = target:FindFirstChild("REN_MusicLog")
        if old then old:Destroy() end

        local gui = Instance.new("ScreenGui")
        gui.Name = "REN_MusicLog"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999

        local box = Instance.new("TextBox")
        box.Size = UDim2.fromOffset(360, 180)
        box.Position = UDim2.fromOffset(10, 10)
        box.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
        box.TextColor3 = Color3.fromRGB(235, 235, 245)
        box.Font = Enum.Font.Code
        box.TextSize = 11
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextYAlignment = Enum.TextYAlignment.Top
        box.TextWrapped = true
        box.MultiLine = true
        box.ClearTextOnFocus = false
        box.TextEditable = false
        box.Text = LOG.text()
        box.Parent = gui

        gui.Parent = target
    end)
end

local function finishLog()
    if LOG.finish then
        pcall(LOG.finish)
    elseif LOG.hasError or LOG.hasWarn then
        emergencyPanel()
    end
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
    local okE, fenv = pcall(function() return getfenv and getfenv() end)
    for _, fnName in ipairs({"http_request", "request"}) do
        local fn = (okE and type(fenv) == "table" and rawget(fenv, fnName)) or rawget(_G, fnName)
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

-- Return source, atau nil + daftar URL yang sudah dicoba.
local function fetchModule(name)
    local names = NAME_ALIASES[name] or { name }
    local tried = {}
    for _, tryName in ipairs(names) do
        for _, base in ipairs(BASE_URLS) do
            local url = base .. tryName .. ".lua"
            local source = httpFetchOnce(url)
            if source then return source end
            tried[#tried + 1] = url
        end
    end
    return nil, table.concat(tried, " , ")
end

-- ═══ COMPILER ═════════════════════════════════════════════════════
-- Return fn, atau nil + pesan error ASLI dari compiler (nomor baris sintaks).
local function compileSource(name, source)
    local chunkName = "=music_modules/" .. name
    local firstErr = nil

    if loadstring then
        local fn, e = loadstring(source, chunkName)
        if fn then return fn end
        firstErr = firstErr or tostring(e)
        fn = loadstring(source)
        if fn then return fn end
    end
    if load then
        local fn, e = load(source, chunkName)
        if fn then return fn end
        firstErr = firstErr or tostring(e)
        fn = load(source)
        if fn then return fn end
    end
    return nil, firstErr or "loadstring/load tidak tersedia"
end

-- ═══ LOAD SATU MODUL ══════════════════════════════════════════════
-- Return true, atau false + pesan error.
local function loadModule(name, REN, CACHE)
    local source = CACHE[name]
    if not source then
        local fetched, tried = fetchModule(name)
        if not fetched then
            return false, string.format("Gagal ambil '%s.lua'. Dicoba: %s", name, tostring(tried))
        end
        source = fetched
        CACHE[name] = source
    end

    local fn, cerr = compileSource(name, source)
    if not fn then
        CACHE[name] = nil   -- jangan simpan source yang tidak bisa dikompilasi
        return false, string.format("Compile gagal '%s': %s", name, tostring(cerr))
    end

    -- Setiap modul berbentuk `return function(REN) ... end`,
    -- jadi function yang di-return harus dipanggil lagi.
    local success, result = pcall(fn, REN)
    if success and type(result) == "function" then
        success, result = pcall(result, REN)
    end
    if not success then
        return false, string.format("Eksekusi gagal '%s': %s", name, tostring(result))
    end
    return true
end

-- ═══ MAIN ═════════════════════════════════════════════════════════
local function yn(v) return v and "ya" or "tidak" end

local function executorName()
    local ok, a, b = pcall(function()
        if identifyexecutor then return identifyexecutor() end
    end)
    if ok and a then return tostring(a) .. (b and (" " .. tostring(b)) or "") end
    return "unknown"
end

local function main()
    LOG.add("info", string.format("Loader v%s mulai | Executor: %s | PlaceId: %s",
        SCRIPT_VERSION, executorName(), tostring(game.PlaceId)))
    LOG.add("info", string.format("loadstring: %s | setclipboard: %s",
        yn(loadstring or load), yn(setclipboard or toclipboard or set_clipboard)))

    if not (loadstring or load) then
        LOG.add("error", "Executor tidak punya loadstring/load — script tidak bisa berjalan")
        return
    end

    local player, pg = waitForPlayer(30)
    if not player or not pg then
        LOG.add("error", "LocalPlayer/PlayerGui tidak tersedia setelah 30 detik")
        return
    end
    PG = pg

    local REN = { version = SCRIPT_VERSION, Log = LOG, LogConfig = CONFIG, PlayerGui = pg }
    local env = (getgenv and getgenv()) or _G
    -- Cache modul hanya dipakai ulang kalau versinya sama; kalau SCRIPT_VERSION
    -- naik, semua modul diambil ulang (kalau tidak, re-execute masih pakai kode lama).
    if env.__REN_MUSIC_CACHE_VER ~= SCRIPT_VERSION then
        env.__REN_MUSIC_MODULES = {}
        env.__REN_MUSIC_CACHE_VER = SCRIPT_VERSION
    end
    local CACHE = env.__REN_MUSIC_MODULES or {}
    env.__REN_MUSIC_MODULES = CACHE

    local total = #MODULE_ORDER
    LOG.total = total

    for idx, name in ipairs(MODULE_ORDER) do
        LOG.done = idx - 1
        LOG.add("info", string.format("[%d/%d] %s%s", idx, total, name,
            CACHE[name] and " (cache)" or ""))

        local ok, err = loadModule(name, REN, CACHE)
        if not ok then
            if OPTIONAL[name] then
                LOG.add("warn", tostring(err) .. " (opsional, dilewati)")
            else
                LOG.add("error", err)
                return
            end
        end

        task.wait(0.03)
    end

    LOG.done = total
    LOG.add("ok", string.format("Semua modul termuat (%d)", total))
end

local ok, err = pcall(main)
if not ok then
    LOG.add("error", "FATAL: " .. tostring(err))
end
finishLog()
