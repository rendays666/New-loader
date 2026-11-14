--[[ LOGGER — panel log loader realtime (modul PERTAMA yang dimuat)

  Mandiri: sengaja TIDAK memakai REN.Widgets / REN.Config, karena keduanya
  belum dimuat saat modul ini jalan.

  Pengaturan ada di CONFIG bagian atas music.lua:
    LOG_REALTIME / LOG_AUTOHIDE / LOG_HIDE_DELAY / LOG_SHOW_ON_ISSUE
  Panel: tombol "Copy" menyalin seluruh log, "✕" menutup panel, header bisa digeser.
]]

return function(REN)
    local LOG = REN.Log
    local CFG = REN.LogConfig
    if not LOG or not CFG then return end

    local UIS = game:GetService("UserInputService")

    local GREEN = Color3.fromRGB(0, 220, 160)
    local AMBER = Color3.fromRGB(240, 190, 70)
    local RED   = Color3.fromRGB(255, 100, 100)

    local gui, scroll, box, statusLbl, copyBtn
    local conns = {}
    local finished = false
    local closedByUser = false

    local function mk(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o.Parent = parent
        return o
    end

    local function hasIssue()
        return LOG.hasError or LOG.hasWarn
    end

    local function destroyGui()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if gui then pcall(function() gui:Destroy() end) end
        gui, scroll, box, statusLbl, copyBtn = nil, nil, nil, nil, nil
    end

    local function statusText()
        if finished then
            if LOG.hasError then return "✖ Error" end
            if LOG.hasWarn then return "⚠ Selesai (ada warning)" end
            return "✔ Selesai"
        end
        if LOG.total > 0 then
            return string.format("Memuat %d/%d", LOG.done, LOG.total)
        end
        return "Memulai..."
    end

    local function refresh()
        if not gui then return end
        pcall(function()
            box.Text = LOG.text()
            statusLbl.Text = "🎵 Loader Log · " .. statusText()
            statusLbl.TextColor3 = LOG.hasError and RED or (LOG.hasWarn and AMBER or GREEN)
            task.defer(function()
                if scroll and scroll.Parent then
                    scroll.CanvasPosition = Vector2.new(
                        0, math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteSize.Y))
                end
            end)
        end)
    end

    local function ensureGui()
        if gui then return true end
        local ok, perr = pcall(function()
            local pg = REN.PlayerGui
            local old = pg:FindFirstChild("REN_MusicLog")
            if old then old:Destroy() end

            gui = mk("ScreenGui", {
                Name = "REN_MusicLog", ResetOnSpawn = false, DisplayOrder = 999,
            }, pg)

            local main = mk("Frame", {
                Size = UDim2.fromOffset(340, 190), Position = UDim2.fromOffset(10, 10),
                BackgroundColor3 = Color3.fromRGB(15, 18, 30), BorderSizePixel = 0,
            }, gui)
            mk("UICorner", {CornerRadius = UDim.new(0, 8)}, main)
            mk("UIStroke", {Color = GREEN, Thickness = 1.5}, main)

            local header = mk("Frame", {
                Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Active = true,
            }, main)

            statusLbl = mk("TextLabel", {
                Size = UDim2.new(1, -78, 1, 0), Position = UDim2.fromOffset(8, 0),
                BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10,
                TextColor3 = GREEN, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
            }, header)

            copyBtn = mk("TextButton", {
                Size = UDim2.fromOffset(44, 16), Position = UDim2.new(1, -70, 0, 3),
                BackgroundColor3 = Color3.fromRGB(0, 180, 130), BorderSizePixel = 0,
                AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 9,
                TextColor3 = Color3.new(1, 1, 1), Text = "Copy",
            }, header)
            mk("UICorner", {CornerRadius = UDim.new(0, 4)}, copyBtn)

            local closeBtn = mk("TextButton", {
                Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -22, 0, 3),
                BackgroundColor3 = Color3.fromRGB(60, 65, 80), BorderSizePixel = 0,
                AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 9,
                TextColor3 = Color3.new(1, 1, 1), Text = "✕",
            }, header)
            mk("UICorner", {CornerRadius = UDim.new(0, 4)}, closeBtn)

            scroll = mk("ScrollingFrame", {
                Size = UDim2.new(1, -12, 1, -30), Position = UDim2.fromOffset(6, 24),
                BackgroundColor3 = Color3.fromRGB(25, 30, 42), BorderSizePixel = 0,
                ScrollBarThickness = 3, ScrollBarImageColor3 = GREEN,
                CanvasSize = UDim2.new(),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
            }, main)
            mk("UICorner", {CornerRadius = UDim.new(0, 6)}, scroll)
            mk("UIPadding", {
                PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 4),
            }, scroll)

            box = mk("TextBox", {
                Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 10,
                TextColor3 = Color3.fromRGB(225, 230, 240),
                TextWrapped = true, MultiLine = true, ClearTextOnFocus = false,
                TextEditable = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top, Text = "",
            }, scroll)

            -- Copy seluruh log ke clipboard
            table.insert(conns, copyBtn.MouseButton1Click:Connect(function()
                local fn = setclipboard or toclipboard or set_clipboard
                    or (type(Clipboard) == "table" and Clipboard.set)
                local copied = type(fn) == "function" and (pcall(fn, LOG.text()))
                copyBtn.Text = copied and "✔" or "N/A"
                task.delay(1.5, function()
                    if copyBtn and copyBtn.Parent then copyBtn.Text = "Copy" end
                end)
            end))

            table.insert(conns, closeBtn.MouseButton1Click:Connect(function()
                closedByUser = true
                destroyGui()
            end))

            -- Geser panel lewat header
            local function isPress(i)
                return i.UserInputType == Enum.UserInputType.MouseButton1
                    or i.UserInputType == Enum.UserInputType.Touch
            end
            local function isMove(i)
                return i.UserInputType == Enum.UserInputType.MouseMovement
                    or i.UserInputType == Enum.UserInputType.Touch
            end
            local dragging, dStart, sPos = false, nil, nil
            table.insert(conns, header.InputBegan:Connect(function(i)
                if isPress(i) then
                    dragging = true; dStart = i.Position; sPos = main.Position
                end
            end))
            table.insert(conns, UIS.InputChanged:Connect(function(i)
                if dragging and isMove(i) then
                    local d = i.Position - dStart
                    main.Position = UDim2.new(
                        sPos.X.Scale, sPos.X.Offset + d.X,
                        sPos.Y.Scale, sPos.Y.Offset + d.Y)
                end
            end))
            table.insert(conns, UIS.InputEnded:Connect(function(i)
                if isPress(i) then dragging = false end
            end))
        end)

        if not ok then
            -- jangan LOG.add di sini (akan memanggil sink lagi); cukup console
            pcall(warn, "[Music] Panel log gagal dibuat: " .. tostring(perr))
            destroyGui()
            return false
        end
        return true
    end

    local function wantsPanel()
        if closedByUser then return false end
        return CFG.LOG_REALTIME or (CFG.LOG_SHOW_ON_ISSUE and hasIssue())
    end

    LOG.sink = function()
        if wantsPanel() and ensureGui() then refresh() end
    end

    LOG.finish = function()
        finished = true
        if gui then refresh() end
        if gui and CFG.LOG_AUTOHIDE and not hasIssue() then
            task.delay(CFG.LOG_HIDE_DELAY or 2, function()
                -- cek ulang: kalau ada warning/error baru, panel dibiarkan terbuka
                if not hasIssue() then destroyGui() end
            end)
        end
    end

    -- Tampilkan baris yang sudah terkumpul sebelum modul ini aktif
    if #LOG.lines > 0 then LOG.sink() end
end
