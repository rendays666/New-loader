--[[ UI/FRAME — kerangka GUI: window, header (drag, mode, minimize), bar tab, area konten, footer status.
     Halaman mendaftar lewat D.UI.addPage(id, title, advancedOnly) → Frame kosong penuh.
     Mode "simple" hanya menampilkan halaman non-advanced (Start, Log). "advanced" menampilkan semua.

     Mengekspor: UI.gui, UI.main, UI.addPage, UI.setTab, UI.setMode, UI.onMode(fn),
                 UI.setStatus(text), UI.setRtStatus(text, color) ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME
    local UIS = game:GetService("UserInputService")
    local env = (getgenv and getgenv()) or _G

    -- Hapus GUI lama (re-execute)
    for _, p in ipairs({ S.PlayerGui, S.GUI_PARENT }) do
        local old = p:FindFirstChild(Cfg.GUI_NAME)
        if old then old:Destroy() end
    end

    local gui = K.new("ScreenGui", {
        Name = Cfg.GUI_NAME, ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 2147483647, Parent = S.GUI_PARENT,
    })
    UI.gui = gui

    -- Ukuran menyesuaikan layar (HP landscape pendek)
    local vp = Vector2.new(800, 600)
    local cam = workspace.CurrentCamera
    if cam then vp = cam.ViewportSize end
    local W = math.max(260, math.min(340, vp.X - 16))
    local H = math.max(280, math.min(420, vp.Y - 44))
    local FULL_SIZE = UDim2.new(0, W, 0, H)
    local MINI_SIZE = UDim2.new(0, 170, 0, 28)

    local main = K.new("Frame", {
        Size = FULL_SIZE, Position = UDim2.new(0, 8, 0, 30),
        BackgroundColor3 = T.bg, BorderSizePixel = 0, Parent = gui,
    }, {
        K.corner(10),
        K.new("UIStroke", { Color = T.line, Thickness = 1 }),
    })
    UI.main = main

    -- ── Header ──────────────────────────────────────────────────────
    local header = K.new("Frame", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = main,
    })
    local title = K.new("TextLabel", {
        Size = UDim2.new(1, -150, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1,
        Text = "Script Dumper  v" .. D.version, Font = Enum.Font.GothamBold, TextSize = 12,
        TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = header,
    })

    local modeBtn = K.new("TextButton", {
        Size = UDim2.new(0, 90, 0, 20), Position = UDim2.new(1, -124, 0, 4),
        BackgroundColor3 = T.accent, Text = "", Font = Enum.Font.GothamBold, TextSize = 10,
        TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = header,
    }, { K.corner(5) })

    local minBtn = K.new("TextButton", {
        Size = UDim2.new(0, 24, 0, 20), Position = UDim2.new(1, -30, 0, 4),
        BackgroundColor3 = T.btn, Text = "–", Font = Enum.Font.GothamBold, TextSize = 14,
        TextColor3 = T.text, BorderSizePixel = 0, Parent = header,
    }, { K.corner(5) })

    -- ── Drag ────────────────────────────────────────────────────────
    local dragging, dragStart, startPos = false, nil, nil
    header.InputBegan:Connect(D.Log.wrap("ui:dragBegin", function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging, dragStart, startPos = true, input.Position, main.Position
        local c
        c = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                c:Disconnect()
            end
        end)
    end))
    table.insert(S.conns, UIS.InputChanged:Connect(D.Log.wrap("ui:dragMove", function(input)
        if not dragging then return end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end)))

    -- Tampilkan/sembunyikan GUI dengan RightShift (PC)
    table.insert(S.conns, UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.KeyCode == Enum.KeyCode.RightShift then
            main.Visible = not main.Visible
        end
    end))

    -- ── Tab bar + konten + footer ───────────────────────────────────
    local tabBar = K.new("ScrollingFrame", {
        Size = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0, 4, 0, 30),
        BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X, Parent = main,
    }, {
        K.new("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    local content = K.new("Frame", {
        Size = UDim2.new(1, -8, 1, -92), Position = UDim2.new(0, 4, 0, 58),
        BackgroundTransparency = 1, ClipsDescendants = true, Parent = main,
    })

    local footer = K.new("Frame", {
        Size = UDim2.new(1, -8, 0, 32), Position = UDim2.new(0, 4, 1, -34),
        BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = main,
    }, { K.corner(6) })
    local statusLbl = K.new("TextLabel", {
        Size = UDim2.new(1, -12, 0, 16), Position = UDim2.new(0, 6, 0, 2), BackgroundTransparency = 1,
        Text = "Ready.", Font = Enum.Font.GothamMedium, TextSize = 11, TextColor3 = T.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = footer,
    })
    local detailLbl = K.new("TextLabel", {
        Size = UDim2.new(1, -12, 0, 12), Position = UDim2.new(0, 6, 0, 18), BackgroundTransparency = 1,
        Text = "", Font = Enum.Font.Code, TextSize = 9, TextColor3 = T.dim,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = footer,
    })

    function UI.setStatus(text) statusLbl.Text = tostring(text) end
    function UI.setRtStatus(text, color)
        detailLbl.Text = tostring(text)
        detailLbl.TextColor3 = color or T.dim
    end

    -- ── Halaman & tab ───────────────────────────────────────────────
    local pages, current, minimized = {}, "start", false
    local modeListeners = {}

    function UI.addPage(id, titleText, advancedOnly)
        local tab = K.new("TextButton", {
            Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = T.btn, Text = titleText, Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = T.text, BorderSizePixel = 0, Parent = tabBar,
        }, { K.corner(5), K.pad(10, 0, 10, 0) })
        local frame = K.new("Frame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = content,
        })
        pages[id] = { tab = tab, frame = frame, adv = advancedOnly == true }
        tab.Visible = (S.mode == "advanced") or not pages[id].adv
        tab.MouseButton1Click:Connect(D.Log.wrap("ui:tab:" .. id, function() UI.setTab(id) end))
        return frame
    end

    function UI.setTab(id)
        if not pages[id] then return end
        current = id
        for pid, p in pairs(pages) do
            p.frame.Visible = (pid == id) and not minimized
            p.tab.BackgroundColor3 = (pid == id) and T.accent or T.btn
        end
    end

    function UI.onMode(fn) modeListeners[#modeListeners + 1] = fn end

    function UI.setMode(mode)
        if mode ~= "simple" and mode ~= "advanced" then mode = "simple" end
        S.mode = mode
        env.__DUMPER_MODE = mode
        modeBtn.Text = (mode == "simple") and "Mode: Simple" or "Mode: Advanced"
        for _, p in pairs(pages) do p.tab.Visible = (mode == "advanced") or not p.adv end
        if pages[current] and pages[current].adv and mode == "simple" then UI.setTab("start") end
        for _, fn in ipairs(modeListeners) do pcall(fn, mode) end
    end

    modeBtn.MouseButton1Click:Connect(D.Log.wrap("ui:mode", function()
        UI.setMode(S.mode == "simple" and "advanced" or "simple")
    end))
    -- Info mode: klik kanan (PC). Badge "?" tidak dipakai di sini karena tombolnya kecil.
    modeBtn.MouseButton2Click:Connect(D.Log.wrap("ui:modeTip", function()
        UI.showTooltip({
            name = "Simple / Advanced mode",
            desc = "Simple: just Start and Log, with big guided steps. Advanced: adds Scan, Actions (remote spy), Watch, Export and Settings.",
            use = "Start in Simple. Switch to Advanced when you want full control.",
        })
    end))
    UI.setMode(S.mode) -- teks awal tombol

    -- ── Minimize ────────────────────────────────────────────────────
    minBtn.MouseButton1Click:Connect(D.Log.wrap("ui:minimize", function()
        minimized = not minimized
        if minimized then
            main.Size = MINI_SIZE
            tabBar.Visible, content.Visible, footer.Visible = false, false, false
            modeBtn.Visible = false
            title.Text = "Script Dumper"
            minBtn.Text = "+"
        else
            main.Size = FULL_SIZE
            tabBar.Visible, content.Visible, footer.Visible = true, true, true
            modeBtn.Visible = true
            title.Text = "Script Dumper  v" .. D.version
            minBtn.Text = "–"
        end
        UI.setTab(current)
    end))
end
