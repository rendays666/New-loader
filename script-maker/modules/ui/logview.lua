--[[ UI/LOGVIEW — panel LOG: daftar baris log, status runtime, tombol CLR LOG.
     Mengambil alih sink D.Log (baris yang ditahan sebelum UI siap ikut ditampilkan).
     Mengekspor: D.UI.setRtStatus(text, color) ]]

return function(D)
    local Cfg = D.Config
    local UI = D.UI
    local logPanel = UI.logPanel

    local logScroll = Instance.new("ScrollingFrame")
    logScroll.Size = UDim2.new(1, -8, 1, -32)
    logScroll.Position = UDim2.new(0, 4, 0, 0)
    logScroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    logScroll.BorderSizePixel = 0
    logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    logScroll.ScrollBarThickness = 3
    logScroll.Parent = logPanel
    Instance.new("UICorner", logScroll).CornerRadius = UDim.new(0, 5)

    local layout = Instance.new("UIListLayout", logScroll)
    layout.Padding = UDim.new(0, 1)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local rtStatus = Instance.new("TextLabel")
    rtStatus.Size = UDim2.new(1, -8, 0, 12)
    rtStatus.Position = UDim2.new(0, 4, 1, -28)
    rtStatus.BackgroundTransparency = 1
    rtStatus.Text = "⏸ idle"
    rtStatus.Font = Enum.Font.Code
    rtStatus.TextSize = 8
    rtStatus.TextColor3 = Color3.fromRGB(150, 200, 255)
    rtStatus.TextXAlignment = Enum.TextXAlignment.Left
    rtStatus.TextTruncate = Enum.TextTruncate.AtEnd
    rtStatus.Parent = logPanel

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0.5, 0, 0, 12)
    clearBtn.Position = UDim2.new(0.5, 0, 1, -14)
    clearBtn.BackgroundColor3 = Color3.fromRGB(90, 40, 40)
    clearBtn.Text = "CLR LOG"
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.TextSize = 8
    clearBtn.TextColor3 = Color3.new(1, 1, 1)
    clearBtn.Parent = logPanel
    Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 3)

    -- Baris disimpan di antrean supaya pembuangan baris tertua O(1)
    local labels, head, nextOrder = {}, 1, 0

    local function count() return #labels - head + 1 end

    local function write(text, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -4, 0, 12)
        lbl.BackgroundTransparency = 1
        lbl.Text = tostring(text):sub(1, 160)
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 8
        lbl.TextColor3 = color or Color3.fromRGB(180, 180, 180)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        nextOrder = nextOrder + 1
        lbl.LayoutOrder = nextOrder
        lbl.Parent = logScroll
        labels[#labels + 1] = lbl

        while count() > Cfg.MAX_LOG_LABELS do
            labels[head]:Destroy()
            labels[head] = nil
            head = head + 1
        end

        local n = count()
        logScroll.CanvasSize = UDim2.new(0, 0, 0, n * 13 + 4)
        logScroll.CanvasPosition = Vector2.new(0, math.max(0, n * 13 - 200))
    end

    local function clear()
        for i = head, #labels do
            if labels[i] then labels[i]:Destroy() end
        end
        labels, head = {}, 1
        logScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    end

    function UI.setRtStatus(text, color)
        rtStatus.Text = tostring(text)
        rtStatus.TextColor3 = color or Color3.fromRGB(150, 200, 255)
    end

    clearBtn.MouseButton1Click:Connect(D.Log.wrap("ui:clearLog", clear))

    D.Log.setSink(write)
end
