--[[
  ╔══════════════════════════════════════════════════════════════════╗
  ║  REN HUB — MASTER LOADER v1.2                                    ║
  ║  • Guard anti-eksekusi ganda                                     ║
  ║  • Tiap script jalan di thread sendiri (loader tidak ketahan)    ║
  ║  • Auto re-execute saat ganti server (queue_on_teleport)         ║
  ║  • Error reporting ke Discord webhook (opsional)                 ║
  ╚══════════════════════════════════════════════════════════════════╝
]]

local genv = (getgenv and getgenv()) or _G

-- Tunggu game siap dulu supaya JobId sudah terisi (JobId kosong di awal bisa bikin
-- server baru dikira server lama).
if not game:IsLoaded() then game.Loaded:Wait() end

local jobKey = (game.JobId ~= "" and game.JobId) or "studio"
-- Guard per SERVER (JobId), bukan boolean. Di sebagian executor getgenv() tidak ke-reset
-- saat pindah server, jadi flag boolean akan memblokir auto re-execute di server baru.
-- Mau paksa load ulang di server yang sama? Jalankan dulu: getgenv().REN_LOADED = nil
if genv.REN_LOADED == jobKey then return end
genv.REN_LOADED = jobKey

-- ============================================================
-- ⚙️ CONFIG
-- ============================================================
local CFG = {
    -- Webhook lama sudah bocor (repo GitHub publik). Hapus di Discord, buat baru, isi di sini.
    -- Kosong = error report ke Discord dimatikan.
    Webhook   = "https://discord.com/api/webhooks/1564257126648512593/e3Xn_y8jduyENW6Vti7CBdinnqk8CTXixSliasOs3c8-OEqc45VKoGeIvIQ1-kGVliiH",
    -- Link yang dijalankan otomatis di server berikutnya (gist kamu, yang mengarah ke Pusat.lua).
    -- Pusat.lua di GitHub HARUS berisi file loader ini (v1.2), kalau tidak yang jalan versi lama.
    LoaderURL = "https://gist.githubusercontent.com/rendays666/777a76b2701737e6692ed88631aa4768/raw/renrenhub-loader.lua",
    Steps = {
        { name = "Tracker", url = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/Database%20supabase" },
        { name = "Music",   url = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music.lua" },
        { name = "Browser", url = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/Scriptbrowser-loader" },
    },
}

-- ============================================================
-- SERVICES
-- ============================================================
local Players  = game:GetService("Players")
local HttpSvc  = game:GetService("HttpService")
local TweenSvc = game:GetService("TweenService")
local player   = Players.LocalPlayer
local pg       = player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not pg then genv.REN_LOADED = nil; return end

-- ============================================================
-- HTTP HELPER
-- ============================================================
local rawRequest = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)

local function httpPost(url, body)
    if not rawRequest then return nil end
    local ok, r = pcall(rawRequest, {
        Url = url, Method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        Body = body,
    })
    if ok then return r end
    return nil
end

local function httpGet(url)
    for _ = 1, 3 do
        local ok, r = pcall(function() return game:HttpGet(url, true) end)
        if ok and type(r) == "string" and r ~= "" then return r end
        if rawRequest then
            local ok2, res = pcall(rawRequest, { Url = url, Method = "GET" })
            if ok2 and type(res) == "table" and type(res.Body) == "string" and res.Body ~= ""
               and (res.StatusCode or 200) == 200 then
                return res.Body
            end
        end
        task.wait(1)
    end
    return nil
end

-- ============================================================
-- DISCORD ERROR REPORT
-- ============================================================
local function reportError(step, reason)
    if not CFG.Webhook or CFG.Webhook == "" then return end
    local executor = "Unknown"
    pcall(function() executor = identifyexecutor and identifyexecutor() or "Unknown" end)
    local payload = {
        username = "REN Loader Error",
        embeds = {{
            title = "❌ Loader Error",
            color = 15158332,
            fields = {
                { name = "Step",     value = "`" .. tostring(step) .. "`", inline = true },
                { name = "Executor", value = "`" .. tostring(executor) .. "`", inline = true },
                { name = "Reason",   value = "```" .. tostring(reason):sub(1, 900) .. "```", inline = false },
                { name = "Player",   value = player.Name .. " (`" .. player.UserId .. "`)", inline = true },
                { name = "Place ID", value = tostring(game.PlaceId), inline = true },
                { name = "Job ID",   value = "`" .. tostring(game.JobId) .. "`", inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }
    task.spawn(function()
        pcall(function() httpPost(CFG.Webhook, HttpSvc:JSONEncode(payload)) end)
    end)
end

-- ============================================================
-- LOADING GUI
-- ============================================================
local oldGui = pg:FindFirstChild("REN_LoaderGUI")
if oldGui then oldGui:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "REN_LoaderGUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 99999
gui.IgnoreGuiInset = true
gui.Parent = pg

local bd = Instance.new("Frame", gui)
bd.Size = UDim2.new(1, 0, 1, 0)
bd.BackgroundColor3 = Color3.new(0, 0, 0)
bd.BackgroundTransparency = 0.4
bd.BorderSizePixel = 0

local panel = Instance.new("Frame", gui)
panel.Size = UDim2.new(0, 420, 0, 260)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
panel.BorderSizePixel = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(0, 220, 160)
stroke.Thickness = 2

local titleLbl = Instance.new("TextLabel", panel)
titleLbl.Size = UDim2.new(1, -24, 0, 30)
titleLbl.Position = UDim2.new(0, 12, 0, 8)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "REN HUB — Loading..."
titleLbl.TextColor3 = Color3.fromRGB(0, 220, 160)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 16
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local statusLbl = Instance.new("TextLabel", panel)
statusLbl.Size = UDim2.new(1, -24, 0, 16)
statusLbl.Position = UDim2.new(0, 12, 0, 36)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Initializing..."
statusLbl.TextColor3 = Color3.fromRGB(140, 150, 170)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 11
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local barBg = Instance.new("Frame", panel)
barBg.Size = UDim2.new(1, -24, 0, 6)
barBg.Position = UDim2.new(0, 12, 0, 58)
barBg.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
barBg.BorderSizePixel = 0
Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 3)

local bar = Instance.new("Frame", barBg)
bar.Size = UDim2.new(0, 0, 1, 0)
bar.BackgroundColor3 = Color3.fromRGB(0, 220, 160)
bar.BorderSizePixel = 0
Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)

local logFrame = Instance.new("ScrollingFrame", panel)
logFrame.Size = UDim2.new(1, -24, 1, -110)
logFrame.Position = UDim2.new(0, 12, 0, 72)
logFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
logFrame.BorderSizePixel = 0
logFrame.ScrollBarThickness = 4
logFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 220, 160)
logFrame.CanvasSize = UDim2.new()
logFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0, 8)
local logPad = Instance.new("UIPadding", logFrame)
logPad.PaddingTop = UDim.new(0, 4)
logPad.PaddingLeft = UDim.new(0, 6)
logPad.PaddingRight = UDim.new(0, 6)
logPad.PaddingBottom = UDim.new(0, 4)
Instance.new("UIListLayout", logFrame).Padding = UDim.new(0, 2)

local GREEN  = Color3.fromRGB(0, 220, 160)
local RED    = Color3.fromRGB(255, 100, 100)
local ORANGE = Color3.fromRGB(255, 180, 100)

-- Dibungkus pcall: aman dipanggil walau GUI sudah di-destroy
local function addLog(text, color)
    pcall(function()
        local l = Instance.new("TextLabel", logFrame)
        l.Size = UDim2.new(1, 0, 0, 14)
        l.BackgroundTransparency = 1
        l.Text = "• " .. tostring(text)
        l.TextColor3 = color or Color3.fromRGB(200, 210, 230)
        l.Font = Enum.Font.Code
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextTruncate = Enum.TextTruncate.AtEnd
        task.wait()
        logFrame.CanvasPosition = Vector2.new(0, logFrame.AbsoluteCanvasSize.Y)
    end)
end

local totalSteps = #CFG.Steps + 1
local function setProgress(step, label)
    pcall(function()
        TweenSvc:Create(bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
            Size = UDim2.new(math.clamp(step / totalSteps, 0, 1), 0, 1, 0)
        }):Play()
        if label then statusLbl.Text = label end
    end)
end

local function closeGUI()
    pcall(function()
        TweenSvc:Create(panel, TweenInfo.new(0.25), { Size = UDim2.new(0, 0, 0, 0) }):Play()
        TweenSvc:Create(bd, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
    end)
    task.wait(0.3)
    pcall(function() gui:Destroy() end)
end

-- ============================================================
-- EXECUTE HELPER
-- Script dijalankan di thread sendiri: loop/yield di dalam tracker, music,
-- atau browser tidak akan menahan loader (dan tidak menahan script lain).
-- ============================================================
local function runScript(codeStr, name)
    local fn = loadstring or load
    if not fn then error("loadstring tidak tersedia di executor ini", 0) end
    local compiled, err = fn(codeStr, "=" .. name)
    if not compiled then error("Compile error: " .. tostring(err), 0) end
    task.spawn(function()
        local ok, runErr = pcall(compiled)
        if not ok then
            warn("[REN] " .. name .. " runtime error: " .. tostring(runErr))
            reportError(name .. " (runtime)", runErr)
        end
    end)
end

local function fetchScript(url, name)
    addLog("Fetching " .. name .. "...", Color3.fromRGB(180, 200, 220))
    local body = httpGet(url)
    if not body then
        error("Gagal download " .. name .. " (3x percobaan)", 0)
    end
    -- GitHub raw balas teks "404: Not Found" (bukan error HTTP) kalau nama file/branch salah
    if body:sub(1, 4) == "404:" then
        error(name .. ": URL 404, cek nama file / branch di GitHub", 0)
    end
    addLog("✅ " .. name .. " downloaded (" .. #body .. " bytes)", GREEN)
    return body
end

-- ============================================================
-- AUTO RE-EXECUTE (ganti server / server hop)
-- queue_on_teleport menyimpan kode yang otomatis jalan di server berikutnya.
-- Kalau executor kamu tidak punya fungsi ini, taruh loader di folder autoexec.
-- ============================================================
local function queueReexec(force)
    -- Flag per server (JobId), bukan boolean, supaya tidak "nyangkut" antar server
    if not force and genv.REN_QUEUED == jobKey then return true end
    local q = queue_on_teleport
        or (syn and syn.queue_on_teleport)
        or (fluxus and fluxus.queue_on_teleport)
    if not q then
        addLog("⚠️ executor tidak punya queue_on_teleport", ORANGE)
        return false
    end
    local src = ([[
        local g = (getgenv and getgenv()) or _G
        g.REN_VIA_QUEUE = true
        repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer
        task.wait(1)
        local ok, err = pcall(function()
            loadstring(game:HttpGet("%s", true))()
        end)
        if not ok then warn("[REN] auto re-execute gagal: " .. tostring(err)) end
    ]]):format(CFG.LoaderURL)
    local ok = pcall(q, src)
    if ok then genv.REN_QUEUED = jobKey end
    return ok
end

-- Teleport gagal → antrean mungkin sudah terpakai/terhapus, antrekan lagi.
-- (Kalau terantre dobel, guard JobId di atas membuat salah satunya langsung berhenti.)
pcall(function()
    game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        queueReexec(true)
    end)
end)

-- Pasang antrean LAGI tepat saat teleport mulai (pindah manual, server hop, atau dipindah server).
-- Sebagian executor mengabaikan/menghapus antrean yang dipasang jauh sebelum teleport; pola ini
-- (dipakai Infinite Yield juga) yang paling andal. Kalau terantre dobel, guard JobId menahan duplikat.
local teleportQueued = false
pcall(function()
    player.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Failed then
            teleportQueued = false
        elseif not teleportQueued then
            teleportQueued = true
            queueReexec(true)
        end
    end)
end)

-- ============================================================
-- MAIN LOADER FLOW
-- ============================================================
task.spawn(function()
    task.wait(0.3)
    setProgress(0, "Starting...")
    addLog("🚀 REN Hub Loader v1.2", GREEN)
    addLog("Place: " .. tostring(game.PlaceId))
    if genv.REN_VIA_QUEUE then
        genv.REN_VIA_QUEUE = nil
        addLog("🔄 Auto re-execute berhasil (setelah pindah server)", GREEN)
    end

    -- Antrekan auto re-execute DI AWAL (bukan di akhir): kalau ada step yang macet atau
    -- kamu pindah server saat masih loading, antrean tetap sudah terpasang.
    local queued = queueReexec()
    addLog(queued and "🔄 Auto re-execute siap" or "⚠️ Auto re-execute tidak aktif", queued and GREEN or ORANGE)

    local errors = {}

    for i, step in ipairs(CFG.Steps) do
        setProgress(i - 1, "Loading " .. step.name .. "...")
        local ok, err = pcall(function()
            local code = fetchScript(step.url, step.name)
            runScript(code, "ren_" .. step.name:lower())
            addLog("✅ " .. step.name .. " aktif", GREEN)
        end)
        if not ok then
            errors[#errors + 1] = { step = step.name, reason = tostring(err) }
            addLog("❌ " .. step.name .. ": " .. tostring(err), RED)
        end
        task.wait(0.1)
    end

    setProgress(#CFG.Steps, "Finalizing...")
    task.wait(0.3)

    if #errors > 0 then
        local names, reasons = {}, {}
        for _, e in ipairs(errors) do
            names[#names + 1] = e.step
            reasons[#reasons + 1] = e.step .. ": " .. e.reason
        end
        setProgress(totalSteps, "❌ Gagal: " .. table.concat(names, ", "))
        addLog("⚠️ Mengirim error ke Discord...", ORANGE)
        reportError(table.concat(names, ", "), table.concat(reasons, "\n"))
        pcall(function()
            titleLbl.Text = "❌ Loader Gagal"
            titleLbl.TextColor3 = RED
            stroke.Color = RED
        end)
        genv.REN_LOADED = nil -- biar bisa dicoba lagi tanpa reset manual
        task.wait(2.5)
        closeGUI()
        warn("[REN] Loader gagal di step: " .. table.concat(names, ", "))
        return
    end

    setProgress(totalSteps, "✅ Selesai!")
    addLog("🎉 Semua komponen aktif!", GREEN)
    pcall(function() titleLbl.Text = "✅ REN Hub Ready" end)
    task.wait(1)
    closeGUI()
end)

print("[REN] Master Loader v1.2 started.")
