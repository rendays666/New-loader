--[[ UI/TOOLTIP — kotak info. API: D.UI.showTooltip({name, desc, use}) | D.UI.hideTooltip() ]]

return function(D)
    local UI = D.UI
    local main = UI.main

    local token = 0
    local tooltip = Instance.new("Frame")
    tooltip.Size = UDim2.new(1, -16, 0, 90)
    tooltip.Position = UDim2.new(0, 8, 1, -100)
    tooltip.BackgroundColor3 = Color3.fromRGB(22, 22, 38)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.ZIndex = 50
    tooltip.Parent = main
    Instance.new("UICorner", tooltip).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", tooltip)
    stroke.Color = Color3.fromRGB(100, 150, 255)
    stroke.Thickness = 1

    local function mkLabel(y, h, font, size, color, zi)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -8, 0, h)
        l.Position = UDim2.new(0, 4, 0, y)
        l.BackgroundTransparency = 1
        l.Font = font
        l.TextSize = size
        l.TextColor3 = color
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.ZIndex = zi
        l.Parent = tooltip
        return l
    end

    local tTitle = mkLabel(2, 14, Enum.Font.GothamBold, 10, Color3.fromRGB(150, 200, 255), 51)
    tTitle.TextTruncate = Enum.TextTruncate.AtEnd
    local tDesc = mkLabel(17, 30, Enum.Font.Gotham, 9, Color3.fromRGB(220, 220, 220), 51)
    tDesc.TextYAlignment = Enum.TextYAlignment.Top
    tDesc.TextWrapped = true
    local tUse = mkLabel(48, 30, Enum.Font.Gotham, 9, Color3.fromRGB(150, 255, 180), 51)
    tUse.TextYAlignment = Enum.TextYAlignment.Top
    tUse.TextWrapped = true

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 12, 0, 12)
    close.Position = UDim2.new(1, -14, 0, 1)
    close.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    close.Text = "x"
    close.Font = Enum.Font.GothamBold
    close.TextSize = 9
    close.TextColor3 = Color3.new(1, 1, 1)
    close.BorderSizePixel = 0
    close.ZIndex = 52
    close.Parent = tooltip
    Instance.new("UICorner", close).CornerRadius = UDim.new(1, 0)

    function UI.hideTooltip()
        token = token + 1
        tooltip.Visible = false
    end

    function UI.showTooltip(info)
        tTitle.Text = info.name or "?"
        tDesc.Text = info.desc or ""
        tUse.Text = "💡 " .. (info.use or "")
        tooltip.Visible = true
        token = token + 1
        local t = token
        task.delay(8, function()
            if token == t then tooltip.Visible = false end
        end)
    end

    close.MouseButton1Click:Connect(D.Log.wrap("ui:tooltipClose", UI.hideTooltip))
end
