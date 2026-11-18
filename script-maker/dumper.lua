--[[
  SCRIPT DUMPER — MODULAR LOADER
  Entry point. URL TIDAK berubah:
    loadstring(game:HttpGet("https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/script-maker/dumper.lua"))()

  Loader ini hanya mengunduh & menjalankan module di script-maker/modules/ sesuai MODULE_ORDER.
  v15: GUI baru (mode Simple/Advanced, English), remote spy (NetScope) digabung, HK2 tersambung.
  v15.1: LOADER LOG — panel log realtime langsung saat execute (lihat bagian LOADER LOG di bawah).
  Peta module + panduan debugging: lihat script-maker/ARCHITECTURE.md

  Opsi (set SEBELUM loadstring):
    getgenv().DUMPER_BRANCH     = "nama-branch"  -- tes dari branch lain (default "main")
    getgenv().DUMPER_LOADER_LOG = false          -- matikan panel log loader (error tetap lewat warn)
    getgenv().DUMPER_LOADER_KEEP = true          -- panel tidak hilang otomatis saat sukses
]]

local SCRIPT_VERSION = "15.2.0"

local _env = (getgenv and getgenv()) or _G
local BRANCH = (type(_env.DUMPER_BRANCH) == "string" and _env.DUMPER_BRANCH ~= "") and _env.DUMPER_BRANCH or "main"
local BASE_URLS = {
    "https://raw.githubusercontent.com/rendays666/New-loader/" .. BRANCH .. "/script-maker/modules/",
    "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/" .. BRANCH .. "/script-maker/modules/",
}

-- Urutan penting: module hanya boleh memakai D.* dari module di atasnya.
local MODULE_ORDER = {
    "config", "state", "logger", "util", "codegen", "output",
    "runtime/capture", "runtime/hook", "runtime/ui_watch", "runtime/passive", "runtime/spy",
    "scanner",
    "build/snapshot", "build/runtime_report", "build/reports", "build/mechanics", "build/brief_data", "build/brief",
    "actions",
    "ui/kit", "ui/frame", "ui/tooltip", "ui/logview",
    "ui/page_start", "ui/page_scan", "ui/page_capture", "ui/page_watch", "ui/page_export", "ui/page_settings",
    "bootstrap",
}

-- ═══ LOADER LOG ═══════════════════════════════════════════════════
-- Panel kecil yang dibuat SEBELUM apa pun diunduh, jadi kelihatan walau loader gagal di tengah jalan.
--   • realtime: tiap module → "→ nama" lalu berubah jadi "✓ nama 4.1KB 0.2s" atau "✗ ..." + detail error
--   • toggle ON/OFF: OFF = panel mengecil jadi pill (tetap menghitung error); tap pill = buka lagi
--   • sukses  → judul hijau, hilang otomatis 3 detik (bisa dimatikan lewat "Auto-hide")
--   • gagal   → tetap terbuka (merah); Copy all / Copy errors; log juga disimpan ke Dumper_loader_log.txt
-- Pilihan ON/OFF dan Auto-hide diingat antar execute lewat getgenv().
local LL = {}
do
    local LEVEL_COLOR = {
        info = Color3.fromRGB(170, 180, 205),
        ok   = Color3.fromRGB(110, 225, 150),
        warn = Color3.fromRGB(240, 190, 90),
        err  = Color3.fromRGB(255, 120, 120),
    }
    local C = {
        bg = Color3.fromRGB(16, 17, 23), panel = Color3.fromRGB(26, 27, 36), field = Color3.fromRGB(20, 21, 29),
        btn = Color3.fromRGB(52, 55, 72), text = Color3.fromRGB(235, 236, 242), line = Color3.fromRGB(64, 68, 92),
        good = Color3.fromRGB(32, 160, 96), bad = Color3.fromRGB(190, 70, 70), accent = Color3.fromRGB(78, 128, 255),
    }

    local lines = {}
    local startClock = os.clock()
    local failed, finished = false, false
    local moduleStatus = nil
    local ui = nil          -- tabel referensi GUI (nil kalau GUI tidak bisa dibuat / dimatikan)
    local conns = {}
    local countdownToken = 0

    local function isOn() return _env.__DUMPER_LL_ON ~= false end
    local function isAutoHide() return _env.__DUMPER_LL_AUTOHIDE ~= false end

    local function counts()
        local e, w = 0, 0
        for _, l in ipairs(lines) do
            if l.level == "err" then e = e + 1 elseif l.level == "warn" then w = w + 1 end
        end
        return e, w
    end

    local function stamp(l) return ("[%5.2f]"):format(l.t) end

    local function refreshPill()
        if not ui then return end
        local e = counts()
        if failed or e > 0 then
            ui.pill.Text = ("Loader log  ✗ %d error%s"):format(e, e == 1 and "" or "s")
            ui.pill.BackgroundColor3 = C.bad
        elseif finished then
            ui.pill.Text = "Loader log  ✓ OK"
            ui.pill.BackgroundColor3 = C.good
        else
            ui.pill.Text = "Loader log  …"
            ui.pill.BackgroundColor3 = C.btn
        end
    end

    local function paintLabel(l)
        if l.label then
            l.label.Text = stamp(l) .. " " .. l.text
            l.label.TextColor3 = LEVEL_COLOR[l.level] or LEVEL_COLOR.info
        end
    end

    local function scrollDown()
        if not ui then return end
        task.defer(function()
            pcall(function() ui.list.CanvasPosition = Vector2.new(0, 1e6) end)
        end)
    end

    -- Tambah satu baris. Return handle: h.set(text, level) mengubah baris yang sama (realtime).
    function LL.add(text, level)
        local l = { t = os.clock() - startClock, text = tostring(text), level = level or "info" }
        lines[#lines + 1] = l
        if ui then
            pcall(function()
                l.label = Instance.new("TextLabel")
                l.label.Size = UDim2.new(1, -6, 0, 0)
                l.label.AutomaticSize = Enum.AutomaticSize.Y
                l.label.BackgroundTransparency = 1
                l.label.Font = Enum.Font.Code
                l.label.TextSize = 10
                l.label.TextWrapped = true
                l.label.TextXAlignment = Enum.TextXAlignment.Left
                l.label.TextYAlignment = Enum.TextYAlignment.Top
                l.label.LayoutOrder = #lines
                l.label.Parent = ui.list
                paintLabel(l)
            end)
            refreshPill()
            scrollDown()
        end
        return {
            set = function(newText, newLevel)
                l.text = tostring(newText)
                if newLevel then l.level = newLevel end
                paintLabel(l)
                refreshPill()
            end,
        }
    end

    function LL.setModules(ms) moduleStatus = ms end

    local function executorName()
        local ok, a, b = pcall(function()
            if identifyexecutor then return identifyexecutor() end
            if getexecutorname then return getexecutorname() end
        end)
        if ok and a then return tostring(a) .. (b and (" " .. tostring(b)) or "") end
        return "unknown"
    end

    -- Teks lengkap untuk di-copy / dikirim ke AI
    function LL.report(onlyErrors)
        local out = {}
        local e, w = counts()
        out[#out + 1] = "=== DUMPER LOADER LOG ==="
        out[#out + 1] = ("version=%s  branch=%s  executor=%s  placeId=%s"):format(
            SCRIPT_VERSION, BRANCH, executorName(), tostring(game.PlaceId))
        out[#out + 1] = ("status=%s  errors=%d  warnings=%d  elapsed=%.2fs"):format(
            failed and "FAILED" or (finished and "OK" or "RUNNING"), e, w, os.clock() - startClock)
        if moduleStatus and not onlyErrors then
            out[#out + 1] = "--- modules ---"
            for _, name in ipairs(MODULE_ORDER) do
                local st = moduleStatus[name]
                if st then
                    out[#out + 1] = ("%-24s %s  %dB%s"):format(name, st.ok and "ok " or "ERR", st.bytes or 0,
                        st.err and ("  " .. tostring(st.err):sub(1, 400)) or "")
                end
            end
        end
        out[#out + 1] = "--- log ---"
        for _, l in ipairs(lines) do
            if not onlyErrors or l.level == "err" or l.level == "warn" then
                out[#out + 1] = ("%s [%s] %s"):format(stamp(l), l.level:upper(), l.text)
            end
        end
        return table.concat(out, "\n")
    end

    local function copyToClipboard(s)
        local fn = setclipboard or toclipboard or (syn and syn.write_clipboard) or (Clipboard and Clipboard.set)
        if type(fn) ~= "function" then return false, "no clipboard function in this executor" end
        local ok, err = pcall(fn, s)
        return ok, err
    end

    local function saveFile(s)
        if type(writefile) ~= "function" then return false end
        return (pcall(writefile, "Dumper_loader_log.txt", s))
    end

    local function copy(onlyErrors)
        local e = counts()
        if onlyErrors and e == 0 then
            LL.add("No errors to copy.", "info")
            return
        end
        local text = LL.report(onlyErrors)
        local ok, err = copyToClipboard(text)
        if ok then
            LL.add(("Copied %s (%d chars)."):format(onlyErrors and "errors" or "full log", #text), "ok")
        elseif saveFile(text) then
            LL.add("Clipboard unavailable (" .. tostring(err) .. "). Saved to workspace/Dumper_loader_log.txt", "warn")
        else
            LL.add("Could not copy or save: " .. tostring(err), "err")
        end
    end

    function LL.destroy()
        countdownToken = countdownToken + 1
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if ui and ui.gui then pcall(function() ui.gui:Destroy() end) end
        ui = nil
    end

    local function applyVisibility()
        if not ui then return end
        local on = isOn()
        ui.panel.Visible = on
        ui.pill.Visible = not on
        ui.toggle.Text = on and "Log: ON" or "Log: OFF"
        ui.toggle.BackgroundColor3 = on and C.good or C.btn
        ui.autoBtn.Text = isAutoHide() and "Auto-hide: ON" or "Auto-hide: OFF"
        ui.autoBtn.BackgroundColor3 = isAutoHide() and C.good or C.btn
        refreshPill()
    end

    local function setTitle(text, color)
        if ui then
            ui.title.Text = text
            ui.title.TextColor3 = color or C.text
        end
    end

    local function build()
        if _env.DUMPER_LOADER_LOG == false then return end

        -- Buang panel lama (re-execute)
        if type(_env.__DUMPER_LL_DESTROY) == "function" then pcall(_env.__DUMPER_LL_DESTROY) end

        local ok, err = pcall(function()
            local function mk(class, props, kids)
                local o = Instance.new(class)
                for k, v in pairs(props or {}) do if k ~= "Parent" then o[k] = v end end
                for _, c in ipairs(kids or {}) do c.Parent = o end
                if props and props.Parent then o.Parent = props.Parent end
                return o
            end
            local function corner(r) return mk("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end
            local function button(parent, text, pos, size, color, cb)
                local b = mk("TextButton", {
                    Position = pos, Size = size, BackgroundColor3 = color, Text = text,
                    Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = C.text, BorderSizePixel = 0,
                    TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
                }, { corner(5) })
                b.MouseButton1Click:Connect(function()
                    local okc, e = pcall(cb)
                    if not okc then pcall(warn, "[Dumper] loader log button: " .. tostring(e)) end
                end)
                return b
            end

            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
            local W = math.max(240, math.min(340, vp.X - 16))
            local H = math.max(170, math.min(270, vp.Y - 44))

            local gui = mk("ScreenGui", {
                Name = "DumperLoaderLog", ResetOnSpawn = false, IgnoreGuiInset = true,
                DisplayOrder = 2147483646,
            })

            -- Cari parent yang bisa ditulis: gethui → CoreGui → PlayerGui
            local cands = {}
            if type(gethui) == "function" then
                local okh, h = pcall(gethui)
                if okh and typeof(h) == "Instance" then cands[#cands + 1] = h end
            end
            pcall(function() cands[#cands + 1] = game:GetService("CoreGui") end)
            pcall(function()
                local lp = game:GetService("Players").LocalPlayer
                local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
                if pg then cands[#cands + 1] = pg end
            end)
            local parented = false
            for _, p in ipairs(cands) do
                pcall(function()
                    local old = p:FindFirstChild("DumperLoaderLog")
                    if old then old:Destroy() end
                    gui.Parent = p
                end)
                if gui.Parent == p then parented = true break end
            end
            if not parented then error("no writable GUI parent") end

            local panel = mk("Frame", {
                Size = UDim2.new(0, W, 0, H), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 30),
                BackgroundColor3 = C.bg, BorderSizePixel = 0, Parent = gui,
            }, { corner(10), mk("UIStroke", { Color = C.line, Thickness = 1 }) })

            local header = mk("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Parent = panel })
            local title = mk("TextLabel", {
                Size = UDim2.new(1, -80, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
                Text = "Loader: starting…", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
            })
            local toggle = button(header, "Log: ON", UDim2.new(1, -70, 0, 4), UDim2.new(0, 62, 0, 18), C.good, function()
                _env.__DUMPER_LL_ON = not isOn()
                applyVisibility()
            end)

            local half = UDim2.new(0.333, -4, 0, 22)
            button(panel, "Copy all", UDim2.new(0, 6, 0, 28), half, C.accent, function() copy(false) end)
            button(panel, "Copy errors", UDim2.new(0.333, 2, 0, 28), half, C.bad, function() copy(true) end)
            local autoBtn = button(panel, "Auto-hide: ON", UDim2.new(0.666, -2, 0, 28), half, C.good, function()
                _env.__DUMPER_LL_AUTOHIDE = not isAutoHide()
                countdownToken = countdownToken + 1 -- batalkan hitung mundur yang sedang jalan
                if finished and not failed then
                    setTitle("✓ Loaded — panel kept open", C.text)
                end
                applyVisibility()
            end)

            local list = mk("ScrollingFrame", {
                Size = UDim2.new(1, -12, 1, -58), Position = UDim2.new(0, 6, 0, 54), BackgroundColor3 = C.field,
                BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollBarThickness = 4, Parent = panel,
            }, {
                corner(6),
                mk("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingRight = UDim.new(0, 4) }),
                mk("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
            })

            local pill = mk("TextButton", {
                Size = UDim2.new(0, 170, 0, 24), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 30),
                BackgroundColor3 = C.btn, Text = "Loader log  …", Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = C.text, BorderSizePixel = 0, Visible = false, Parent = gui,
            }, { corner(12) })
            pill.MouseButton1Click:Connect(function()
                _env.__DUMPER_LL_ON = true
                applyVisibility()
            end)

            -- Drag lewat header
            local UIS = game:GetService("UserInputService")
            local dragging, dragStart, startPos = false, nil, nil
            header.InputBegan:Connect(function(input)
                if input.UserInputType ~= Enum.UserInputType.MouseButton1
                    and input.UserInputType ~= Enum.UserInputType.Touch then return end
                dragging, dragStart, startPos = true, input.Position, panel.Position
                local c
                c = input.Changed:Connect(function()
                    if input.UserInputState == Enum.UserInputState.End then
                        dragging = false
                        c:Disconnect()
                    end
                end)
            end)
            conns[#conns + 1] = UIS.InputChanged:Connect(function(input)
                if not dragging then return end
                if input.UserInputType ~= Enum.UserInputType.MouseMovement
                    and input.UserInputType ~= Enum.UserInputType.Touch then return end
                local d = input.Position - dragStart
                panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end)

            ui = { gui = gui, panel = panel, pill = pill, list = list, title = title, toggle = toggle, autoBtn = autoBtn }
        end)

        if not ok then
            ui = nil
            pcall(warn, "[Dumper] loader log GUI unavailable (" .. tostring(err) .. ") — console only")
        else
            _env.__DUMPER_LL_DESTROY = LL.destroy
            applyVisibility()
        end
    end

    -- Dipanggil di akhir main(): ok=true → hijau + hilang otomatis; ok=false → merah + tetap terbuka
    function LL.finish(ok, secs)
        finished, failed = true, not ok
        if ok then
            LL.add(("All %d modules loaded in %.2fs."):format(#MODULE_ORDER, secs or 0), "ok")
            if _env.DUMPER_LOADER_KEEP == true or not isAutoHide() then
                setTitle("✓ Loaded — panel kept open", C.text)
            else
                countdownToken = countdownToken + 1
                local mine = countdownToken
                task.spawn(function()
                    for i = 3, 1, -1 do
                        if mine ~= countdownToken or not ui then return end
                        setTitle(("✓ Loaded in %.1fs — closing in %d"):format(secs or 0, i), LEVEL_COLOR.ok)
                        task.wait(1)
                    end
                    if mine == countdownToken then LL.destroy() end
                end)
            end
        else
            setTitle("✗ Load FAILED — tap Copy errors", LEVEL_COLOR.err)
            if saveFile(LL.report(false)) then
                LL.add("Log also saved to workspace/Dumper_loader_log.txt", "info")
            end
        end
        applyVisibility()
    end

    LL.setTitle = setTitle
    function LL.failed() return failed end

    pcall(build)
    LL.add(("Dumper v%s  ·  branch: %s  ·  %s"):format(SCRIPT_VERSION, BRANCH, executorName()), "info")
end

local function fail(msg)
    pcall(warn, "[Dumper] " .. tostring(msg))
    LL.add(msg, "err")
end

-- ═══ HTTP FETCH ═══════════════════════════════════════════════════
local function validResponse(r)
    if type(r) ~= "string" or #r == 0 then return false end
    if r:match("^404:") or r:match("^<") then return false end
    return true
end

-- Coba beberapa jalur HTTP. Alasan gagal tiap jalur dicatat di `reasons` supaya kelihatan di log.
local function tryUrl(url, reasons)
    local function note(tag, ok, res)
        local detail
        if not ok then
            detail = tostring(res)
        elseif type(res) ~= "string" then
            detail = "response is " .. type(res)
        else
            local preview = res:sub(1, 50):gsub("%s+", " ")
            detail = ("bad response (%dB): %s"):format(#res, preview)
        end
        reasons[#reasons + 1] = ("%s → %s"):format(tag, detail:sub(1, 120))
    end

    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    if ok and validResponse(res) then return res end
    note("HttpGet", ok, res)

    ok, res = pcall(function() return game:GetService("HttpService"):GetAsync(url, true) end)
    if ok and validResponse(res) then return res end
    note("HttpService", ok, res)

    if syn and syn.request then
        ok, res = pcall(function()
            local r = syn.request({ Url = url, Method = "GET" })
            return r and r.Body
        end)
        if ok and validResponse(res) then return res end
        note("syn.request", ok, res)
    end

    for _, fnName in ipairs({ "http_request", "request" }) do
        local fn = rawget(getfenv(), fnName) or rawget(_G, fnName)
        if type(fn) == "function" then
            ok, res = pcall(function()
                local r = fn({ Url = url, Method = "GET" })
                return r and r.Body
            end)
            if ok and validResponse(res) then return res end
            note(fnName, ok, res)
        end
    end
    return nil
end

-- Cache-bust di percobaan PERTAMA: raw.githubusercontent di-cache ~5 menit, jadi tanpa ini
-- setelah push bisa termuat campuran module lama + baru (version skew). Fallback: URL polos.
local bustStamp = tostring(os.time())
local function httpFetchOnce(url, reasons)
    return tryUrl(url .. "?cb=" .. bustStamp, reasons) or tryUrl(url, reasons)
end

-- return source | nil, reasons[]
local function fetchModule(name)
    local reasons = {}
    for _, base in ipairs(BASE_URLS) do
        local source = httpFetchOnce(base .. name .. ".lua", reasons)
        if source then return source, reasons end
        reasons[#reasons + 1] = "↑ failed: " .. base .. name .. ".lua"
    end
    return nil, reasons
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
    local waitLine
    while not Players.LocalPlayer and os.clock() - t0 < 30 do
        waitLine = waitLine or LL.add("Waiting for LocalPlayer…", "info")
        task.wait(0.2)
    end
    if not Players.LocalPlayer then
        fail("LocalPlayer tidak tersedia setelah 30 detik")
        LL.finish(false)
        return
    end
    if waitLine then waitLine.set("LocalPlayer ready.", "ok") end

    local env = (getgenv and getgenv()) or _G

    -- Matikan instance lama (re-execute) supaya hook/koneksi/GUI tidak dobel
    local prev = env.__DUMPER_PREV
    if type(prev) == "table" and type(prev.Shutdown) == "function" then
        pcall(prev.Shutdown)
        LL.add("Previous instance shut down.", "info")
    end

    local D = {
        version      = SCRIPT_VERSION,
        loadOrder    = MODULE_ORDER,
        moduleStatus = {},
        LoaderLog    = LL, -- dipakai Settings → "Copy loader log"
    }
    env.__DUMPER_PREV = D
    LL.setModules(D.moduleStatus)

    -- Source selalu diambil baru; cache hanya fallback kalau jaringan gagal.
    local CACHE = env.__DUMPER_MODULE_CACHE
    if type(CACHE) ~= "table" or env.__DUMPER_CACHE_VER ~= SCRIPT_VERSION then
        CACHE = {}
        env.__DUMPER_MODULE_CACHE = CACHE
        env.__DUMPER_CACHE_VER = SCRIPT_VERSION
    end

    local loadStart = os.clock()
    local total = #MODULE_ORDER

    for i, name in ipairs(MODULE_ORDER) do
        local status = { ok = false, bytes = 0 }
        D.moduleStatus[name] = status
        local label = ("[%d/%d] %s"):format(i, total, name)
        local line = LL.add("→ " .. label .. " …", "info")
        local tm = os.clock()
        if LL.setTitle then LL.setTitle(("Loading %d/%d"):format(i, total)) end

        local source, reasons = fetchModule(name)
        if not source and CACHE[name] then
            source = CACHE[name]
            LL.add("   network failed, using cached copy", "warn")
        end
        if not source then
            status.err = "gagal download"
            line.set("✗ " .. label .. ": download failed", "err")
            for _, r in ipairs(reasons) do LL.add("   " .. r, "err") end
            fail(("Gagal ambil '%s.lua' dari semua URL"):format(name))
            LL.finish(false)
            return
        end
        CACHE[name] = source
        status.bytes = #source

        local fn, cerr = compileSource(name, source)
        if not fn then
            status.err = "compile: " .. tostring(cerr)
            line.set("✗ " .. label .. ": compile error", "err")
            fail(("Compile gagal '%s': %s"):format(name, tostring(cerr)))
            LL.finish(false)
            return
        end

        -- Setiap module berbentuk `return function(D) ... end`
        local ok, result = xpcall(fn, debug.traceback, D)
        if ok and type(result) == "function" then
            ok, result = xpcall(result, debug.traceback, D)
        end
        if not ok then
            status.err = "runtime: " .. tostring(result)
            line.set("✗ " .. label .. ": runtime error", "err")
            fail(("Eksekusi gagal '%s': %s"):format(name, tostring(result)))
            LL.finish(false)
            return
        end

        status.ok = true
        line.set(("✓ %s  %.1fKB  %.2fs"):format(label, #source / 1024, os.clock() - tm), "ok")
        task.wait(0.03)
    end

    LL.finish(true, os.clock() - loadStart)
end

local ok, err = pcall(main)
if not ok then
    fail("FATAL: " .. tostring(err))
    LL.finish(false)
end
