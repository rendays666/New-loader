--[[ UI/WIDGETS — pembuat komponen kecil.
     D.UI.mkBtn(parent, text, x, w, y, color, textSize, height)
     D.UI.addInfoBadge(btn, key)          -- badge "?" memakai D.Config.BTN_INFO[key]
     D.UI.attachInfo(btn, getInfoFn)      -- klik kanan (PC) / tahan 0.5 dtk (mobile) ]]

return function(D)
    local UI = D.UI

    function UI.mkBtn(parent, text, x, w, y, color, ts, h)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(w, 0, 0, h or 18)
        b.Position = UDim2.new(x, 0, 0, y)
        b.BackgroundColor3 = color
        b.Text = text
        b.Font = Enum.Font.GothamBold
        b.TextSize = ts or 9
        b.TextColor3 = Color3.new(1, 1, 1)
        b.Parent = parent
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        return b
    end

    function UI.addInfoBadge(btn, key)
        local info = D.Config.BTN_INFO[key]
        if not info then return end
        local q = Instance.new("TextButton")
        q.Size = UDim2.new(0, 10, 0, 10)
        q.Position = UDim2.new(1, -11, 0, 1)
        q.BackgroundColor3 = Color3.fromRGB(55, 55, 85)
        q.Text = "?"
        q.Font = Enum.Font.GothamBold
        q.TextSize = 8
        q.TextColor3 = Color3.fromRGB(140, 190, 255)
        q.BorderSizePixel = 0
        q.ZIndex = 5
        q.AutoButtonColor = false
        q.Parent = btn
        Instance.new("UICorner", q).CornerRadius = UDim.new(1, 0)
        q.MouseButton1Click:Connect(D.Log.wrap("ui:badge", function() UI.showTooltip(info) end))
    end

    function UI.attachInfo(btn, getInfo)
        btn.MouseButton2Click:Connect(D.Log.wrap("ui:info", function()
            local inf = getInfo()
            if inf then UI.showTooltip(inf) end
        end))
        btn.InputBegan:Connect(D.Log.wrap("ui:infoHold", function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch then return end
            local held = true
            local c
            c = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    held = false
                    c:Disconnect()
                end
            end)
            task.delay(0.5, function()
                if held then
                    local inf = getInfo()
                    if inf then UI.showTooltip(inf) end
                end
            end)
        end))
    end
end
