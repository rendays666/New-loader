--[[ UI/CHIPS — baris chip: root (RS..TM), opsi scan (DC/BC/RC), runtime (UI/HK/UC/RT).
     Logika HK/UC ada di runtime/hook.lua — chip hanya memanggilnya. ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI = D.UI
    local COLOR = Cfg.COLOR

    local skipBar = Instance.new("ScrollingFrame")
    skipBar.Size = UDim2.new(1, -8, 0, 16)
    skipBar.Position = UDim2.new(0, 4, 0, 82)
    skipBar.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    skipBar.BorderSizePixel = 0
    skipBar.CanvasSize = UDim2.new(0, 0, 0, 0)
    skipBar.ScrollBarThickness = 2
    skipBar.ScrollingDirection = Enum.ScrollingDirection.X
    skipBar.Parent = UI.scanPanel
    Instance.new("UICorner", skipBar).CornerRadius = UDim.new(0, 3)

    local skipLayout = Instance.new("UIListLayout", skipBar)
    skipLayout.FillDirection = Enum.FillDirection.Horizontal
    skipLayout.Padding = UDim.new(0, 2)
    skipLayout.SortOrder = Enum.SortOrder.LayoutOrder
    skipLayout.VerticalAlignment = Enum.VerticalAlignment.Center

    skipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        skipBar.CanvasSize = UDim2.new(0, skipLayout.AbsoluteContentSize.X + 8, 0, 0)
    end)

    local function mkChip(abbr, width, order, isOn)
        local chip = Instance.new("TextButton")
        chip.Size = UDim2.new(0, width, 0, 12)
        chip.BackgroundColor3 = isOn() and COLOR.on or COLOR.off
        chip.Text = abbr
        chip.Font = Enum.Font.GothamBold
        chip.TextSize = 8
        chip.TextColor3 = Color3.new(1, 1, 1)
        chip.BorderSizePixel = 0
        chip.LayoutOrder = order
        chip.Parent = skipBar
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 3)
        return chip
    end

    -- ── Root chips ──────────────────────────────────────────────────
    for i, r in ipairs(Cfg.SKIP_ROOTS) do
        local chip = mkChip(r.abbr, 26, i, function() return S.rootEnabled[r.name] end)
        chip.MouseButton1Click:Connect(D.Log.wrap("ui:chip:" .. r.abbr, function()
            S.rootEnabled[r.name] = not S.rootEnabled[r.name]
            chip.BackgroundColor3 = S.rootEnabled[r.name] and COLOR.on or COLOR.off
        end))
        UI.attachInfo(chip, function()
            local inf = Cfg.ROOT_INFO[r.abbr]
            if not inf then return nil end
            return { name = r.abbr .. " = " .. inf.name, desc = inf.desc, use = inf.use }
        end)
    end

    -- ── Toggle chips ────────────────────────────────────────────────
    local function mkToggle(abbr, order, isOn, onToggle)
        local chip = mkChip(abbr, 22, order, isOn)
        chip.MouseButton1Click:Connect(D.Log.wrap("ui:chip:" .. abbr, function()
            onToggle()
            chip.BackgroundColor3 = isOn() and COLOR.on or COLOR.off
        end))
        UI.attachInfo(chip, function() return Cfg.TOGGLE_INFO[abbr] end)
        return chip
    end

    local function opt(key)
        return function() return S.scanOptions[key] end,
               function() S.scanOptions[key] = not S.scanOptions[key] end
    end
    mkToggle("DC", 100, opt("decompile"))
    mkToggle("BC", 101, opt("bytecode"))
    mkToggle("RC", 102, opt("readCore"))

    mkToggle("UI", 200, function() return S.uiActive end,
        function() D.UIWatch.set(not S.uiActive) end)

    mkToggle("HK", 201, function() return S.hkActive end, function()
        if not S.hkActive then
            if not D.Hook.installHK() then
                D.Log.write("[HK] ✗ " .. tostring(D.Hook.lastError), COLOR.err, "hk")
                return
            end
            D.Capture.start()
        end
        S.hkActive = not S.hkActive
        if not S.hkActive then D.Capture.flush() end
        D.Log.write("[HK] " .. (S.hkActive and "✓ aktif" or "✗ mati"), Color3.fromRGB(200, 200, 255), "hk")
    end)

    mkToggle("UC", 202, function() return S.ucActive end, function()
        S.ucActive = not S.ucActive
        if S.ucActive then
            D.Capture.start()
            local ok = D.Hook.patchUC()
            if not ok then
                S.ucActive = false
                D.Log.write("[UC] ✗ patch gagal: " .. tostring(D.Hook.lastError), COLOR.err, "uc")
            else
                D.Log.write("[UC] ✓ aktif (hanya mencatat kalau HK mati)", Color3.fromRGB(200, 200, 255), "uc")
            end
        else
            D.Log.write("[UC] ✗ mati", COLOR.dim, "uc")
        end
    end)

    mkToggle("RT", 203, function() return false end, function()
        S.runtimeCapture.fireServer = {}
        S.runtimeCapture.ui = {}
        S.runtimeCapture.log = {}
        D.Capture.flush()
        D.Log.write("[RT] runtime cleared", COLOR.dim, "rt")
    end)
end
