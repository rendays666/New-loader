--[[
  RENRENHUB — MUSIC LOADER v3.5
  Entry point. URL ini TIDAK berubah agar kompatibel dengan script lain.
  Modul dimuat dari folder music_modules/ di repo yang sama.
]]

local BASE = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music_modules/"

local env = (getgenv and getgenv()) or _G
local CACHE = env.__REN_MUSIC_MODULES or {}
env.__REN_MUSIC_MODULES = CACHE

local function fetchModule(name)
    if CACHE[name] then return CACHE[name] end
    local url = BASE .. name .. ".lua"
    local ok, code = pcall(function() return game:HttpGet(url, true) end)
    if not ok or not code or code == "" then
        error("[Music] Failed to fetch module: " .. name)
    end
    local fn, err = loadstring(code, "=music_modules/" .. name)
    if not fn then
        error("[Music] Compile failed '" .. name .. "': " .. tostring(err))
    end
    CACHE[name] = fn
    return fn
end

local REN = { version = "3.5" }

local ORDER = {
    "config",
    "state",
    "utils",
    "firebase",
    "playlist",
    "audio",
    "social",
    "submit",
    "ratings",
    "ui/widgets",
    "ui/dialogs",
    "ui/rows",
    "ui/panel",
    "bootstrap",
}

for _, name in ipairs(ORDER) do
    local fn = fetchModule(name)
    local ok, err = pcall(fn, REN)
    if not ok then
        warn("[Music] Error in module '" .. name .. "': " .. tostring(err))
        return
    end
end
