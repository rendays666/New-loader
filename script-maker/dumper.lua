--[[
  SCRIPT DUMPER — MODULAR LOADER
  Entry point. URL TIDAK berubah:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/script-maker/dumper.lua"))()

  Loader ini hanya mengunduh & menjalankan module di script-maker/modules/ sesuai MODULE_ORDER.
  Peta module + panduan debugging: lihat script-maker/ARCHITECTURE.md
  Error load/compile/runtime module hanya lewat warn() di console + bagian DIAGNOSTICS di file SMART/FULL.
]]

local SCRIPT_VERSION = "14.0.0"

local BASE_URLS = {
    "https://raw.githubusercontent.com/rendays666/New-loader/main/script-maker/modules/",
    "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/script-maker/modules/",
}

-- Urutan penting: module hanya boleh memakai D.* dari module di atasnya.
local MODULE_ORDER = {
    "config", "state", "logger", "util", "output",
    "runtime/capture", "runtime/hook", "runtime/ui_watch", "runtime/passive",
    "scanner",
    "build/snapshot", "build/runtime_report", "build/reports", "build/mechanics",
    "ui/frame", "ui/logview", "ui/tooltip", "ui/widgets", "ui/list", "ui/chips", "ui/buttons",
    "bootstrap",
}

local function fail(msg)
    pcall(warn, "[Dumper] " .. tostring(msg))
end

-- ═══ HTTP FETCH ═══════════════════════════════════════════════════
local function validResponse(r)
    if type(r) ~= "string" or #r == 0 then return false end
    if r:match("^404:") or r:match("^<") then return false end
    return true
end

local function httpFetchOnce(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and validResponse(res) then return res end

    local bustUrl = url .. (url:find("?") and "&" or "?") .. "_t=" .. tostring(os.time())
    ok, res = pcall(function() return game:HttpGet(bustUrl, true) end)
    if ok and validResponse(res) then return res end

    ok, res = pcall(function() return game:GetService("HttpService"):GetAsync(url, true) end)
    if ok and validResponse(res) then return res end

    if syn and syn.request then
        ok, res = pcall(function()
            local r = syn.request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
    end

    for _, fnName in ipairs({ "http_request", "request" }) do
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
    for _, base in ipairs(BASE_URLS) do
        local source = httpFetchOnce(base .. name .. ".lua")
        if source then return source end
    end
    return nil
end

local function compileSource(name, source)
    local chunkName = "=dumper/" .. name -- nomor baris di error = nomor baris di file module
    if loadstring then
        local fn, err = loadstring(source, chunkName)
        if fn then return fn end
        return nil, err
    end
    if load then
        local fn, err = load(source, chunkName)
        if fn then return fn end
        return nil, err
    end
    return nil, "loadstring/load tidak tersedia"
end

-- ═══ MAIN ═════════════════════════════════════════════════════════
local function main()
    local Players = game:GetService("Players")
    local t0 = os.clock()
    while not Players.LocalPlayer and os.clock() - t0 < 30 do task.wait(0.2) end
    if not Players.LocalPlayer then
        fail("LocalPlayer tidak tersedia setelah 30 detik")
        return
    end

    local env = (getgenv and getgenv()) or _G

    -- Matikan instance lama (re-execute) supaya hook/koneksi/GUI tidak dobel
    local prev = env.__DUMPER_PREV
    if type(prev) == "table" and type(prev.Shutdown) == "function" then pcall(prev.Shutdown) end

    local D = {
        version      = SCRIPT_VERSION,
        loadOrder    = MODULE_ORDER,
        moduleStatus = {},
    }
    env.__DUMPER_PREV = D

    -- Source selalu diambil baru; cache hanya fallback kalau jaringan gagal.
    local CACHE = env.__DUMPER_MODULE_CACHE
    if type(CACHE) ~= "table" or env.__DUMPER_CACHE_VER ~= SCRIPT_VERSION then
        CACHE = {}
        env.__DUMPER_MODULE_CACHE = CACHE
        env.__DUMPER_CACHE_VER = SCRIPT_VERSION
    end

    for _, name in ipairs(MODULE_ORDER) do
        local status = { ok = false, bytes = 0 }
        D.moduleStatus[name] = status

        local source = fetchModule(name) or CACHE[name]
        if not source then
            status.err = "gagal download"
            fail(("Gagal ambil '%s.lua' dari semua URL"):format(name))
            return
        end
        CACHE[name] = source
        status.bytes = #source

        local fn, cerr = compileSource(name, source)
        if not fn then
            status.err = "compile: " .. tostring(cerr)
            fail(("Compile gagal '%s': %s"):format(name, tostring(cerr)))
            return
        end

        -- Setiap module berbentuk `return function(D) ... end`
        local ok, result = xpcall(fn, debug.traceback, D)
        if ok and type(result) == "function" then
            ok, result = xpcall(result, debug.traceback, D)
        end
        if not ok then
            status.err = "runtime: " .. tostring(result)
            fail(("Eksekusi gagal '%s': %s"):format(name, tostring(result)))
            return
        end

        status.ok = true
        task.wait(0.03)
    end
end

local ok, err = pcall(main)
if not ok then
    fail("FATAL: " .. tostring(err))
end
