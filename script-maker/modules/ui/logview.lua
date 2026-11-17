--[[ UI/LOGVIEW — halaman "Log": daftar baris log, tombol Copy / Clear.
     Mengambil alih sink D.Log (baris yang ditahan sebelum UI siap ikut ditampilkan). ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("log", "Log", false)

    local bar = K.new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = page })
    local copyBtn = K.new("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0), BackgroundColor3 = T.btn, Text = "Copy log",
        Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.text, BorderSizePixel = 0, Parent = bar,
    }, { K.corner(6) })
    local clearBtn = K.new("TextButton", {
        Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0), BackgroundColor3 = T.bad,
        Text = "Clear log", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = T.text,
        BorderSizePixel = 0, Parent = bar,
    }, { K.corner(6) })

    local scroll = K.new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -34), Position = UDim2.new(0, 0, 0, 34), BackgroundColor3 = T.field,
        BorderSizePixel = 0, CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 3, Parent = page,
    }, {
        K.corner(6), K.pad(4, 2, 4, 2),
        K.new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
    })

    local ROW = 15
    local labels, head, order = {}, 1, 0
    local function count() return #labels - head + 1 end

    local function write(text, color)
        local lbl = K.new("TextLabel", {
            Size = UDim2.new(1, -4, 0, ROW - 1), BackgroundTransparency = 1,
            Text = tostring(text):sub(1, 180), Font = Enum.Font.Code, TextSize = 10,
            TextColor3 = color or T.dim, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = order + 1, Parent = scroll,
        })
        order = order + 1
        labels[#labels + 1] = lbl

        while count() > Cfg.MAX_LOG_LABELS do
            labels[head]:Destroy()
            labels[head] = nil
            head = head + 1
        end

        local n = count()
        scroll.CanvasSize = UDim2.new(0, 0, 0, n * ROW + 6)
        scroll.CanvasPosition = Vector2.new(0, math.max(0, n * ROW + 6 - scroll.AbsoluteWindowSize.Y))
    end

    local function clear()
        for i = head, #labels do
            if labels[i] then labels[i]:Destroy() end
        end
        labels, head = {}, 1
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    end

    copyBtn.MouseButton1Click:Connect(D.Log.wrap("ui:copyLog", function()
        local lines = {}
        for _, e in ipairs(D.Log.entries) do
            lines[#lines + 1] = ("%.1f [%s] %s"):format(e.t, e.tag, e.text)
        end
        D.Output.copyText(table.concat(lines, "\n"), "log")
    end))
    clearBtn.MouseButton1Click:Connect(D.Log.wrap("ui:clearLog", clear))

    D.Log.setSink(write)
end
