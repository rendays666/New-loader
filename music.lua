--[[
  RENRENHUB — MUSIC LOADER v3.6
  Entry point. URL ini TIDAK berubah (kompatibel dengan script lain).
  
  Fitur:
  - Loading GUI dengan log realtime per modul
  - Auto-hide bila semua berhasil
  - Tetap tampil bila ada error, dengan tombol Copy Logs
  - Fallback sumbit.lua -> submit.lua
  - Multi-URL & multi-HTTP fallback
  - Cache-busting untuk raw.githubusercontent
]]

-- ═══════════════════════════════════════════════════════════════════
-- CONSTANTS
-- ═══════════════════════════════════════════════════════════════════
local SCRIPT_VERSION = "3.6"

local BASE_URLS = {
    "https://raw.githubusercontent.com/rendays666/New-loader/main/music_modules/",
    "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music_modules/",
}

local MODULE_ORDER = {
    "config", "state", "utils", "firebase", "playlist",
    "audio", "social", "submit", "ratings",
    "ui/widgets", "ui/dialogs", "ui/rows", "ui/panel",
    "bootstrap",
}

-- Alias untuk file yang mungkin salah nama
local NAME_ALIASES = {
    submit = { "submit", "sumbit" },
}

-- ═══════════════════════════════════════════════════════════════════
-- LOG SYSTEM
-- ═══════════════════════════════════════════════════════════════════
local Logs = {}
local LogSink = nil

local function log(level, msg)
    local entry = { level = level, msg = tostring(msg), ts = os.date("%H:%M:%S") }
    table.insert(Logs, entry)
    pcall(print, string.format("[Music:%s] %s", level, entry.msg))
    if LogSink and LogSink.append then
        pcall(LogSink.append, level, entry.msg)
    end
end

-- ═══════════════════════════════════════════════════════════════════
-- CLIPBOARD HELPER
-- ═══════════════════════════════════════════════════════════════════
local function copyToClipboard(text)
    if setclipboard then
        local ok = pcall(setclipboard, text); if ok then return true end
    end
    if toclipboard then
        local ok = pcall(toclipboard, text); if ok then return true end
    end
    if writeclipboard then
        local ok = pcall(writeclipboard, text); if ok then return true end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════
-- LOADING GUI
-- ═══════════════════════════════════════════════════════════════════
local function buildLoadingUI()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    if not player then return nil end
    local pg = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
    if not pg then return nil end

    if pg:FindFirstChild("REN_MusicLoaderUI") then
        pg.REN_MusicLoaderUI:Destroy()
    end

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end
    local function corner(o, r) mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end

    local gui = mk("ScreenGui", {
        Name = "REN_MusicLoaderUI",
        ResetOnSpawn = false,
        DisplayOrder = 999999,
        IgnoreGuiInset = true,
    }, pg)

    local frame = mk("Frame", {
        Size = UDim2.fromOffset(440, 340),
        Position = UDim2.new(0.5, -220, 0.5, -170),
        BackgroundColor3 = Color3.fromRGB(18, 22, 34),
        BorderSizePixel = 0,
        Active = true,
    }, gui)
    corner(frame, 10)
    mk("UIStroke", { Color = Color3.fromRGB(0, 220, 160), Thickness = 2 }, frame)

    mk("TextLabel", {
        Size = UDim2.new(1, -16, 0, 22),
        Position = UDim2.fromOffset(8, 6),
        BackgroundTransparency = 1,
        Text = "🎵 REN Music Loader v" .. SCRIPT_VERSION,
        TextColor3 = Color3.fromRGB(0, 220, 160),
        Font = Enum.Font.GothamBold,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local statusLbl = mk("TextLabel", {
        Size = UDim2.new(1, -16, 0, 14),
        Position = UDim2.fromOffset(8, 30),
        BackgroundTransparency = 1,
        Text = "Initializing...",
        TextColor3 = Color3.fromRGB(180, 200, 220),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, frame)

    local logFrame = mk("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -110),
        Position = UDim2.fromOffset(8, 48),
        BackgroundColor3 = Color3.fromRGB(10, 14, 22),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(0, 180, 130),
    }, frame)
    corner(logFrame, 6)
    mk("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, logFrame)
    mk("UIPadding", {
        PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6),
        PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 4),
    }, logFrame)

    local copyBtn = mk("TextButton", {
        Size = UDim2.new(0.5, -12, 0, 26),
        Position = UDim2.new(0, 8, 1, -34),
        BackgroundColor3 = Color3.fromRGB(40, 46, 66),
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "📋 Copy Logs",
        TextColor3 = Color3.fromRGB(220, 220, 240),
        Font = Enum.Font.GothamBold, TextSize = 11,
    }, frame)
    corner(copyBtn, 6)

    local closeBtn = mk("TextButton", {
        Size = UDim2.new(0.5, -12, 0, 26),
        Position = UDim2.new(0.5, 4, 1, -34),
        BackgroundColor3 = Color3.fromRGB(0, 180, 130),
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "✕ Close",
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.GothamBold, TextSize = 11,
        Visible = false,
    }, frame)
    corner(closeBtn, 6)

    local order = 0
    local function append(level, msg)
        order = order + 1
        local color, prefix = Color3.fromRGB(180, 200, 220), "•"
        if level == "OK" then color = Color3.fromRGB(0, 220, 160); prefix = "✓"
        elseif level == "ERR" then color = Color3.fromRGB(255, 100, 100); prefix = "✗"
        elseif level == "WARN" then color = Color3.fromRGB(255, 200, 80); prefix = "⚠"
        elseif level == "INFO" then color = Color3.fromRGB(150, 180, 220); prefix = "ℹ"
        end
        mk("TextLabel", {
            Size = UDim2.new(1, -12, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Text = prefix .. " " .. tostring(msg),
            TextColor3 = color,
            Font = Enum.Font.Code, TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            LayoutOrder = order,
        }, logFrame)
        task.defer(function()
            pcall(function() logFrame.CanvasPosition = Vector2.new(0, math.huge) end)
        end)
    end

    copyBtn.MouseButton1Click:Connect(function()
        local lines = {}
        for _, e in ipairs(Logs) do
            table.insert(lines, string.format("[%s][%s] %s", e.ts, e.level, e.msg))
        end
        local text = table.concat(lines, "\n")
        local ok = copyToClipboard(text)
        if ok then
            copyBtn.Text = "✓ Copied!"
            copyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 130)
        else
            copyBtn.Text = "✗ Copy gagal — cek console"
            copyBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
        end
        task.delay(2, function()
            if copyBtn and copyBtn.Parent then
                copyBtn.Text = "📋 Copy Logs"
                copyBtn.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
            end
        end)
    end)

    closeBtn.MouseButton1Click:Connect(function()
        gui:Destroy()
    end)

    return {
        gui = gui,
        frame = frame,
        append = append,
        setStatus = function(text, color)
            if not statusLbl or not statusLbl.Parent then return end
            statusLbl.Text = tostring(text)
            if color then statusLbl.TextColor3 = color end
        end,
        showClose = function()
            if closeBtn and closeBtn.Parent then closeBtn.Visible = true end
        end,
        markSuccess = function()
            if not statusLbl or not statusLbl.Parent then return end
            statusLbl.Text = "✓ Semua modul berhasil dimuat — UI sebentar lagi terbuka"
            statusLbl.TextColor3 = Color3.fromRGB(0, 220, 160)
        end,
        markFailure = function()
            if not statusLbl or not statusLbl.Parent then return end
            statusLbl.Text = "✗ Gagal memuat — lihat log di atas / klik Copy Logs"
            statusLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
        end,
        destroy = function()
            if gui and gui.Parent then gui:Destroy() end
        end,
    }
end

-- ═══════════════════════════════════════════════════════════════════
-- HTTP FETCH (multi-strategy)
-- ═══════════════════════════════════════════════════════════════════
local function validResponse(r)
    return type(r) == "string" and #r > 0
        and not r:match("^404:")
        and not r:match("^<")
        and r:find("function", 1, true) ~= nil
end

local function httpFetchOnce(url)
    -- Attempt 1: game:HttpGet with cache-bypass flag
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and validResponse(res) then return res end

    -- Attempt 2: cache-bust query string
    local sep = url:find("?") and "&" or "?"
    local bustUrl = url .. sep .. "_t=" .. tostring(os.time())
    ok, res = pcall(function() return game:HttpGet(bustUrl, true) end)
    if ok and validResponse(res) then return res end

    -- Attempt 3: syn.request
    if syn and syn.request then
        ok, res = pcall(function()
            local r = syn.request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
    end

    -- Attempt 4: http_request
    if http_request then
        ok, res = pcall(function()
            local r = http_request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
    end

    -- Attempt 5: request
    if request then
        ok, res = pcall(function()
            local r = request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
    end

    return nil
end

local function fetchModule(name)
    local names = NAME_ALIASES[name] or { name }
    for _, tryName in ipairs(names) do
        for _, base in ipairs(BASE_URLS) do
            local url = base .. tryName .. ".lua"
            local source = httpFetchOnce(url)
            if source then
                if tryName ~= name then
                    log("WARN", string.format("Modul '%s' pakai alias '%s.lua'", name, tryName))
                end
                return source, url
            end
        end
    end
    return nil, nil
end

-- ═══════════════════════════════════════════════════════════════════
-- COMPILER
-- ═══════════════════════════════════════════════════════════════════
local function compileSource(name, source)
    local chunkName = "=music_modules/" .. name

    if loadstring then
        local fn, err = loadstring(source, chunkName)
        if fn then return fn, nil end
        if err then
            local fn2 = loadstring(source)
            if fn2 then return fn2, nil end
        end
    end

    if load then
        local fn, err = load(source, chunkName)
        if fn then return fn, nil end
        local fn2 = load(source)
        if fn2 then return fn2, nil end
    end

    return nil, "loadstring/load tidak tersedia atau source invalid"
end

-- ═══════════════════════════════════════════════════════════════════
-- MAIN LOADER
-- ═══════════════════════════════════════════════════════════════════
local function main()
    log("INFO", "Memulai loader v" .. SCRIPT_VERSION)

    local ui = buildLoadingUI()
    if ui then
        LogSink = ui
        for _, e in ipairs(Logs) do
            pcall(ui.append, e.level, e.msg)
        end
    else
        log("WARN", "Loading GUI gagal dibuat — log hanya di console")
    end

    local function setStatus(t, c) if LogSink then pcall(LogSink.setStatus, t, c) end end
    local function fail() if LogSink then pcall(LogSink.markFailure); pcall(LogSink.showClose) end end
    local function ok() if LogSink then pcall(LogSink.markSuccess) end end

    local REN = { version = SCRIPT_VERSION }
    local env = (getgenv and getgenv()) or _G
    local CACHE = env.__REN_MUSIC_MODULES or {}
    env.__REN_MUSIC_MODULES = CACHE

    local total = #MODULE_ORDER

    for i, name in ipairs(MODULE_ORDER) do
        setStatus(string.format("Memuat %d/%d — %s", i, total, name))
        log("INFO", string.format("[%d/%d] %s", i, total, name))

        local source = CACHE[name]
        if source then
            log("INFO", "  (dari cache)")
        else
            source = fetchModule(name)
            if not source then
                log("ERR", string.format("Gagal ambil '%s.lua' dari semua URL", name))
                fail()
                return
            end
            CACHE[name] = source
        end

        local fn, cerr = compileSource(name, source)
        if not fn then
            log("ERR", string.format("Compile gagal '%s': %s", name, tostring(cerr)))
            fail()
            return
        end

        local success, rerr = pcall(fn, REN)
        if not success then
            log("ERR", string.format("Eksekusi gagal '%s': %s", name, tostring(rerr)))
            fail()
            return
        end

        log("OK", string.format("  '%s' sukses", name))
        task.wait(0.03)
    end

    log("OK", string.format("Semua %d modul berhasil dimuat", total))
    ok()

    local stats = "?"
    if REN.State and REN.State.playlist then
        stats = string.format(
            "Playlist: %d | Mode: %s | PlaceId: %d",
            #REN.State.playlist,
            tostring(REN.State.musicState),
            game.PlaceId
        )
    end
    log("OK", "READY — " .. stats)

    -- Auto-hide setelah 1 detik
    task.delay(1, function()
        if LogSink then pcall(LogSink.destroy) end
    end)
end

-- ═══════════════════════════════════════════════════════════════════
-- RUN
-- ═══════════════════════════════════════════════════════════════════
local ok, err = pcall(main)
if not ok then
    log("ERR", "FATAL: " .. tostring(err))
    if LogSink then
        pcall(LogSink.markFailure)
        pcall(LogSink.showClose)
    end
end
