--[[ UI/FRAME — kerangka GUI: ScreenGui, jendela utama, header, drag, minimize, tab SCAN/LOG.
     Mengekspor ke D.UI: gui, main, scanPanel, logPanel, setTab(which)
     Modul ui/* lain menempel ke scanPanel / logPanel / main. ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UIS = game:GetService("UserInputService")
    local UI = D.UI
    local COLOR = Cfg.COLOR

    -- Hapus GUI lama (re-execute)
    for _, p in ipairs({ S.PlayerGui, S.GUI_PARENT }) do
        local old = p:FindFirstChild(Cfg.GUI_NAME)
        if old then old:Destroy() end
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = Cfg.GUI_NAME
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 2147483647
    gui.Parent = S.GUI_PARENT
    UI.gui = gui

    local FULL_SIZE = UDim2.new(0, 240, 0, 350)
    local MINI_SIZE = UDim2.new(0, 150, 0, 20)

    local main = Instance.new("Frame")
    main.Size = FULL_SIZE
    main.Position = UDim2.new(0, 6, 0, 24)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    main.BorderSizePixel = 0
    main.Parent = gui
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(80, 140, 255)
    stroke.Thickness = 1
    UI.main = main

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -28, 0, 20)
    header.BackgroundTransparency = 1
    header.Text = "📜 Dumper v" .. D.version
    header.Font = Enum.Font.GothamBold
    header.TextSize = 11
    header.TextColor3 = Color3.new(1, 1, 1)
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = main
    Instance.new("UIPadding", header).PaddingLeft = UDim.new(0, 6)

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 20, 0, 18)
    minBtn.Position = UDim2.new(1, -22, 0, 1)
    minBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
    minBtn.Text = "–"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Color3.new(1, 1, 1)
    minBtn.Parent = main
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 4)

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

    -- ── Tab ─────────────────────────────────────────────────────────
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(1, -8, 0, 18)
    tabBar.Position = UDim2.new(0, 4, 0, 20)
    tabBar.BackgroundTransparency = 1
    tabBar.Parent = main

    local function mkTab(text, x)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.49, 0, 1, 0)
        b.Position = UDim2.new(x, 0, 0, 0)
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 9
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Parent = tabBar
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end
    local scanTabBtn = mkTab("SCAN", 0)
    local logTabBtn  = mkTab("LOG", 0.51)

    local function mkPanel(visible)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, 0, 1, -40)
        f.Position = UDim2.new(0, 0, 0, 40)
        f.BackgroundTransparency = 1
        f.Visible = visible
        f.Parent = main
        return f
    end
    local scanPanel = mkPanel(true)
    local logPanel  = mkPanel(false)
    UI.scanPanel, UI.logPanel = scanPanel, logPanel

    local currentTab = "scan"
    local function setTab(which)
        currentTab = which
        scanPanel.Visible = (which == "scan")
        logPanel.Visible  = (which == "log")
        scanTabBtn.BackgroundColor3 = (which == "scan") and COLOR.on or COLOR.tabOff
        logTabBtn.BackgroundColor3  = (which == "log") and COLOR.on or COLOR.tabOff
    end
    UI.setTab = setTab
    setTab("scan")
    scanTabBtn.MouseButton1Click:Connect(D.Log.wrap("ui:tabScan", function() setTab("scan") end))
    logTabBtn.MouseButton1Click:Connect(D.Log.wrap("ui:tabLog", function() setTab("log") end))

    -- ── Minimize ────────────────────────────────────────────────────
    local minimized = false
    minBtn.MouseButton1Click:Connect(D.Log.wrap("ui:minimize", function()
        minimized = not minimized
        if minimized then
            main.Size = MINI_SIZE
            tabBar.Visible, scanPanel.Visible, logPanel.Visible = false, false, false
            header.Text = "📜 D"
            minBtn.Text = "+"
        else
            main.Size = FULL_SIZE
            tabBar.Visible = true
            header.Text = "📜 Dumper v" .. D.version
            minBtn.Text = "–"
            setTab(currentTab)
        end
    end))
end
