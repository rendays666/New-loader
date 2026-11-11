--[[ UI/LIST — daftar hasil scan: kotak filter, scroll, label status, render baris.
     Mengekspor: D.UI.setStatus(text) | D.UI.clearList() | D.UI.rebuildList() ]]

return function(D)
    local S, Cfg = D.State, D.Config
    local UI = D.UI
    local scanPanel = UI.scanPanel

    local filterBox = Instance.new("TextBox")
    filterBox.Size = UDim2.new(0.96, 0, 0, 16)
    filterBox.Position = UDim2.new(0.02, 0, 0, 100)
    filterBox.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    filterBox.BorderSizePixel = 0
    filterBox.PlaceholderText = "Filter path…"
    filterBox.Text = ""
    filterBox.ClearTextOnFocus = false
    filterBox.Font = Enum.Font.Gotham
    filterBox.TextSize = 9
    filterBox.TextColor3 = Color3.new(1, 1, 1)
    filterBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    filterBox.Parent = scanPanel
    Instance.new("UICorner", filterBox).CornerRadius = UDim.new(0, 4)

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -8, 0, 178)
    scroll.Position = UDim2.new(0, 4, 0, 118)
    scroll.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    scroll.BorderSizePixel = 0
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.ScrollBarThickness = 4
    scroll.Parent = scanPanel
    Instance.new("UICorner", scroll).CornerRadius = UDim.new(0, 5)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 1)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -8, 0, 12)
    status.Position = UDim2.new(0, 4, 1, -14)
    status.BackgroundTransparency = 1
    status.Text = "Ready."
    status.Font = Enum.Font.Gotham
    status.TextSize = 9
    status.TextColor3 = Color3.fromRGB(180, 180, 180)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = scanPanel

    function UI.setStatus(text) status.Text = tostring(text) end

    function UI.clearList()
        for _, c in ipairs(scroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
    end

    local function makeRow(s)
        local tc = Cfg.TYPE_COLOR[s.class] or Color3.fromRGB(100, 100, 100)
        local sc = Cfg.STATUS_COLOR[s.status]

        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -4, 0, 18)
        row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
        row.BorderSizePixel = 0
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = scroll

        local tag = Instance.new("TextLabel")
        tag.Size = UDim2.new(0, 34, 1, 0)
        tag.BackgroundColor3 = tc
        tag.BackgroundTransparency = 0.75
        tag.BorderSizePixel = 0
        tag.Text = s.class:sub(1, 5)
        tag.Font = Enum.Font.GothamBold
        tag.TextSize = 7
        tag.TextColor3 = Cfg.TYPE_COLOR[s.class] or Color3.new(1, 1, 1)
        tag.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -90, 1, 0)
        lbl.Position = UDim2.new(0, 36, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = s.path
        lbl.Font = Enum.Font.Code
        lbl.TextSize = 8
        lbl.TextColor3 = sc or Color3.fromRGB(200, 200, 200)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = row

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(0, 50, 1, 0)
        info.Position = UDim2.new(1, -50, 0, 0)
        info.BackgroundTransparency = 1
        info.Text = s.status:sub(1, 4) .. "/" ..
            (s.size >= 1024 and ("%.1fK"):format(s.size / 1024) or (s.size .. "B"))
        info.Font = Enum.Font.Code
        info.TextSize = 7
        info.TextColor3 = sc or Color3.fromRGB(180, 180, 180)
        info.TextXAlignment = Enum.TextXAlignment.Right
        info.Parent = row

        row.MouseButton1Click:Connect(D.Log.wrap("ui:rowCopy", function()
            D.Output.copyText(s.path, "path")
        end))
    end

    function UI.rebuildList()
        UI.clearList()
        S.renderToken = S.renderToken + 1     -- batalkan render lama yang masih jalan
        local myToken = S.renderToken
        local filter = filterBox.Text:lower()

        task.spawn(function()
            D.Log.safe("ui:rebuildList", function()
                local shown, batch, capped = 0, 0, false
                local all = S.allScripts
                for _, s in ipairs(all) do
                    if myToken ~= S.renderToken then return end
                    if shown >= Cfg.SCAN.RENDER_CAP then capped = true break end
                    if filter == "" or s.path:lower():find(filter, 1, true) then
                        shown = shown + 1
                        makeRow(s)
                        batch = batch + 1
                        if batch % 50 == 0 then
                            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
                            task.wait()
                        end
                    end
                end
                if myToken ~= S.renderToken then return end
                scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
                status.Text = capped
                    and ("Showing %d / %d — FILTER"):format(shown, #all)
                    or ("Shown %d / %d"):format(shown, #all)
            end)
        end)
    end

    filterBox:GetPropertyChangedSignal("Text"):Connect(function()
        S.filterToken = S.filterToken + 1
        local t = S.filterToken
        task.delay(0.3, function()
            if t == S.filterToken and #S.allScripts > 0 then UI.rebuildList() end
        end)
    end)
end
