--[[ UI/TOOLTIP — kotak info kecil di atas footer. API: D.UI.showTooltip({name, desc, use}) | D.UI.hideTooltip() ]]

return function(D)
    local UI, K = D.UI, D.UI.kit
    local T = D.Config.THEME

    local token = 0
    local box = K.new("Frame", {
        Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.new(0, 8, 1, -44), AnchorPoint = Vector2.new(0, 1),
        BackgroundColor3 = T.panel, BorderSizePixel = 0, Visible = false, ZIndex = 50, Parent = UI.main,
    }, {
        K.corner(8),
        K.new("UIStroke", { Color = T.accent, Thickness = 1 }),
    })
    -- Isi teks di dalam "inner" (punya UIListLayout); tombol close sibling-nya, bebas dari layout
    local inner = K.new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, ZIndex = 51, Parent = box,
    }, {
        K.pad(8, 6, 26, 8),
        K.new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
    })

    local function line(color, bold, size)
        local l = K.label(inner, "", { color = color, bold = bold, size = size })
        l.ZIndex = 51
        return l
    end
    local tTitle = line(T.accent, true, 12)
    local tDesc  = line(T.text, false, 11)
    local tUse   = line(Color3.fromRGB(130, 230, 170), false, 11)

    local close = K.new("TextButton", {
        Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(1, -22, 0, 4), BackgroundColor3 = T.bad,
        Text = "x", Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, ZIndex = 52, Parent = box,
    }, { K.corner(9) })

    function UI.hideTooltip()
        token = token + 1
        box.Visible = false
    end

    function UI.showTooltip(info)
        tTitle.Text = info.name or "?"
        tDesc.Text = info.desc or ""
        tUse.Text = info.use and ("💡 " .. info.use) or ""
        box.Visible = true
        token = token + 1
        local mine = token
        task.delay(10, function()
            if token == mine then box.Visible = false end
        end)
    end

    close.MouseButton1Click:Connect(D.Log.wrap("ui:tooltipClose", UI.hideTooltip))
end
