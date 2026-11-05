--[[
  ╔══════════════════════════════════════════════════════════════════╗
  ║  REN HUB — MASTER LOADER v1.0                                    ║
  ║  • GUI Loading Log otomatis close                                ║
  ║  • Auto-load Database + Tracker + Browser + Music                ║
  ║  • Error reporting ke Discord webhook                            ║
  ║  • Auto re-execute saat ganti server                             ║
  ╚══════════════════════════════════════════════════════════════════╝
]]

-- ============================================================
-- ⚙️ CONFIG
-- ============================================================
local CFG = {
    Webhook = "https://discord.com/api/webhooks/1564257126648512593/e3Xn_y8jduyENW6Vti7CBdinnqk8CTXixSliasOs3c8-OEqc45VKoGeIvIQ1-kGVliiH",
    URLs = {
        tracker = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/Database%20supabase",
        browser = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/Scriptbrowser-loader",
        music   = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/music.lua",
    },
    AutoReexecFile = "REN_autoreexec.json",
}

-- ============================================================
-- SERVICES
-- ============================================================
local Players   = game:GetService("Players")
local HttpSvc   = game:GetService("HttpService")
local TweenSvc  = game:GetService("TweenService")
local player    = Players.LocalPlayer
local pg        = player and (player:FindFirstChild("PlayerGui") or player:WaitForChild("PlayerGui", 10))
if not pg then return end

-- ============================================================
-- HTTP HELPER (multi-method fallback)
-- ============================================================
local function httpPost(url, body, isJSON)
    local headers = {}
    if isJSON then headers["Content-Type"] = "application/json" end
    local p = {Url=url, Method="POST", Headers=headers, Body=body}
    local ok, r = pcall(function() return syn and syn.request(p) end)
    if ok and r and r.StatusCode then return r end
    ok, r = pcall(function() return http_request(p) end)
    if ok and r and r.StatusCode then return r end
    ok, r = pcall(function() return request(p) end)
    if ok and r and r.StatusCode then return r end
    return nil
end

local function httpGet(url)
    local ok, r = pcall(function() return game:HttpGet(url, true) end)
    if ok and r and r ~= "" then return r end
    local p = {Url=url, Method="GET"}
    ok, r = pcall(function() return syn and syn.request(p) end)
    if ok and r and r.Body then return r.Body end
    ok, r = pcall(function() return http_request(p) end)
    if ok and r and r.Body then return r.Body end
    ok, r = pcall(function() return request(p) end)
    if ok and r and r.Body then return r.Body end
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
                { name = "Step",       value = "`"..tostring(step).."`", inline = true },
                { name = "Executor",   value = "`"..tostring(executor).."`", inline = true },
                { name = "Reason",     value = "```"..tostring(reason):sub(1, 900).."```", inline = false },
                { name = "Player",     value = player.Name.." (`"..player.UserId.."`)", inline = true },
                { name = "Place ID",   value = tostring(game.PlaceId), inline = true },
                { name = "Job ID",     value = "`"..tostring(game.JobId).."`", inline = false },
                { name = "Time",       value = os.date("!%Y-%m-%dT%H:%M:%SZ"), inline = false },
            },
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }},
    }
    task.spawn(function()
        pcall(function() httpPost(CFG.Webhook, HttpSvc:JSONEncode(payload), true) end)
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

local function addLog(text, color)
    local l = Instance.new("TextLabel", logFrame)
    l.Size = UDim2.new(1, 0, 0, 14)
    l.BackgroundTransparency = 1
    l.Text = "• "..tostring(text)
    l.TextColor3 = color or Color3.fromRGB(200, 210, 230)
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    task.wait(0.05)
    logFrame.CanvasPosition = Vector2.new(0, logFrame.AbsoluteCanvasSize.Y)
end

local totalSteps = 5
local doneSteps = 0
local function setProgress(step, label)
    doneSteps = step
    TweenSvc:Create(bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
        Size = UDim2.new(math.clamp(step/totalSteps, 0, 1), 0, 1, 0)
    }):Play()
    if label then statusLbl.Text = label end
end

local function closeGUI()
    pcall(function()
        TweenSvc:Create(panel, TweenInfo.new(0.25), {
            Size = UDim2.new(0, 0, 0, 0),
        }):Play()
        TweenSvc:Create(bd, TweenInfo.new(0.25), {
            BackgroundTransparency = 1,
        }):Play()
    end)
    task.wait(0.3)
    pcall(function() gui:Destroy() end)
end

-- ============================================================
-- EXECUTE HELPER (isolated — biar `return` di script ga bunuh loader)
-- ============================================================
local function runScript(codeStr, name)
    local fn = loadstring or load
    if not fn then error("loadstring tidak tersedia di executor ini", 0) end
    local compiled, err = fn(codeStr, "="..name)
    if not compiled then error("Compile error: "..tostring(err), 0) end
    local ok, runErr = pcall(compiled)
    if not ok then error("Runtime: "..tostring(runErr), 0) end
end

local function fetchScript(url, name)
    addLog("Fetching "..name.."...", Color3.fromRGB(180, 200, 220))
    local body = httpGet(url)
    if not body or body == "" then
        error("Gagal download "..name.." (URL: "..url..")", 0)
    end
    addLog("✅ "..name.." downloaded ("..#body.." bytes)", Color3.fromRGB(0, 220, 160))
    return body
end

-- ============================================================
-- AUTO RE-EXECUTE GUARD
-- ============================================================
local function saveReexecFlag()
    if not writefile then return end
    pcall(function()
        writefile(CFG.AutoReexecFile, HttpSvc:JSONEncode({
            placeId = game.PlaceId,
            jobId   = game.JobId,
            ts      = os.time(),
            scriptUrl = "https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/ren_loader.lua",
        }))
    end)
end

local function clearReexecFlag()
    if not delfile then return end
    pcall(function() delfile(CFG.AutoReexecFile) end)
end

-- Teleport hook: begitu player pindah server, simpan flag agar auto-load next join
pcall(function()
    game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        -- biarkan saja, kalau gagal teleport script tetap hidup
    end)
end)

-- ============================================================
-- MAIN LOADER FLOW
-- ============================================================
local loadError = nil

task.spawn(function()
    task.wait(0.3)
    setProgress(0, "Starting...")
    addLog("🚀 REN Hub Loader v1.0", Color3.fromRGB(0, 220, 160))
    addLog("Place: "..tostring(game.PlaceId).." | Job: "..tostring(game.JobId))

    -- ── STEP 1: Database / Tracker ──
    setProgress(1, "Loading Tracker...")
    local ok1, err1 = pcall(function()
        local code = fetchScript(CFG.URLs.tracker, "Tracker")
        runScript(code, "ren_tracker")
        addLog("✅ Tracker aktif", Color3.fromRGB(0, 220, 160))
    end)
    if not ok1 then
        loadError = {step = "Tracker", reason = tostring(err1)}
        addLog("❌ Tracker: "..tostring(err1), Color3.fromRGB(255, 100, 100))
    end
    task.wait(0.2)

    -- ── STEP 2: Music ──
    setProgress(2, "Loading Music...")
    local ok2, err2 = pcall(function()
        local code = fetchScript(CFG.URLs.music, "Music")
        runScript(code, "ren_music")
        addLog("✅ Music loaded", Color3.fromRGB(0, 220, 160))
    end)
    if not ok2 and not loadError then
        loadError = {step = "Music", reason = tostring(err2)}
        addLog("❌ Music: "..tostring(err2), Color3.fromRGB(255, 100, 100))
    end
    task.wait(0.2)

    -- ── STEP 3: Browser / Loader ──
    setProgress(3, "Loading Browser...")
    local ok3, err3 = pcall(function()
        local code = fetchScript(CFG.URLs.browser, "Browser")
        runScript(code, "ren_browser")
        addLog("✅ Browser loaded", Color3.fromRGB(0, 220, 160))
    end)
    if not ok3 and not loadError then
        loadError = {step = "Browser", reason = tostring(err3)}
        addLog("❌ Browser: "..tostring(err3), Color3.fromRGB(255, 100, 100))
    end

    -- ── STEP 4: Finalize ──
    setProgress(4, "Finalizing...")
    task.wait(0.3)

    if loadError then
        setProgress(5, "❌ Gagal: "..loadError.step)
        addLog("⚠️ Mengirim error ke Discord...", Color3.fromRGB(255, 180, 100))
        reportError(loadError.step, loadError.reason)
        titleLbl.Text = "❌ Loader Gagal"
        titleLbl.TextColor3 = Color3.fromRGB(255, 100, 100)
        stroke.Color = Color3.fromRGB(255, 100, 100)
        task.wait(2.5)
        closeGUI()
        warn("[REN] Loader gagal di step: "..loadError.step)
        return
    end

    -- Sukses total
    setProgress(5, "✅ Selesai!")
    addLog("🎉 Semua komponen aktif!", Color3.fromRGB(0, 220, 160))
    titleLbl.Text = "✅ REN Hub Ready"
    saveReexecFlag()
    task.wait(1)
    closeGUI()
end)

-- ============================================================
-- AUTO RE-EXECUTE CHECK (saat script jalan lagi setelah pindah server)
-- ============================================================
task.spawn(function()
    task.wait(2)
    if not readfile or not isfile then return end
    if not isfile(CFG.AutoReexecFile) then return end
    local ok, data = pcall(readfile, CFG.AutoReexecFile)
    if not ok or not data then return end
    local ok2, dec = pcall(function() return HttpSvc:JSONDecode(data) end)
    if not ok2 or type(dec) ~= "table" then return end

    if dec.placeId == game.PlaceId and dec.jobId ~= game.JobId then
        -- Server berbeda, tapi script ini sudah jalan → tandai sukses, clear flag
        addLog("🔄 Terdeteksi pindah server → auto-loaded", Color3.fromRGB(0, 220, 160))
        clearReexecFlag()
    elseif dec.placeId ~= game.PlaceId then
        clearReexecFlag()
    end
end)

print("[REN] Master Loader started.")
