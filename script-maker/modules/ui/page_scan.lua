--[[ UI/PAGE_SCAN (Advanced) — pilih tempat & opsi scan, jalankan scan, lihat hasil.
     Mengekspor: D.UI.clearList() | D.UI.rebuildList() (dipanggil scanner) ]]

return function(D)
    local S, Cfg, A = D.State, D.Config, D.Actions
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("scan", "Scan", true)
    local stack = K.stack(page)

    -- Run
    local run = K.card(stack, "Run")
    local g = K.grid(run, 3, 30)
    K.button(g, "Scan", A.scan, { color = T.good, tip = "SCAN" })
    K.button(g, "Stop", A.stopScan, { color = T.bad, tip = "STOP" })
    K.button(g, "Clear", A.clearResults, { tip = "CLEAR" })

    -- Places
    local places = K.card(stack, "Places to scan")
    K.label(places, "Fewer places = faster and safer. Tap ? for what each place contains.",
        { size = 11, color = T.dim })
    local presets = K.grid(places, 2, 26)
    K.button(presets, "Recommended", function()
        local rec = { RS = true, SP = true, PL = true, SG = true }
        for _, r in ipairs(Cfg.SKIP_ROOTS) do S.rootEnabled[r.name] = rec[r.abbr] == true end
        UI.refreshAll()
    end, { h = 26 })
    K.button(presets, "All on", function()
        for _, r in ipairs(Cfg.SKIP_ROOTS) do S.rootEnabled[r.name] = true end
        UI.refreshAll()
    end, { h = 26 })
    for _, r in ipairs(Cfg.SKIP_ROOTS) do
        local info = Cfg.ROOT_INFO[r.abbr]
        K.toggle(places, r.name,
            function() return S.rootEnabled[r.name] == true end,
            function(v) S.rootEnabled[r.name] = v end,
            { tip = info })
    end

    -- Options
    local opts = K.card(stack, "Options (safe defaults: all off)")
    for _, key in ipairs({ "decompile", "bytecode", "readCore" }) do
        K.toggle(opts, Cfg.TOGGLE_INFO[key].name,
            function() return S.scanOptions[key] == true end,
            function(v) S.scanOptions[key] = v end,
            { tip = key })
    end

    -- Results
    local res = K.card(stack, "Results (tap a row to copy its path)")
    local filter = K.field(res, "Filter path…")
    local list = K.new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 200), BackgroundColor3 = T.field, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollBarThickness = 4, Parent = res,
    }, {
        K.corner(6),
        K.new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
    })
    local layout = list:FindFirstChildOfClass("UIListLayout")

    function UI.clearList()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
    end

    local function makeRow(s)
        local tc = Cfg.TYPE_COLOR[s.class] or T.dim
        local sc = Cfg.STATUS_COLOR[s.status] or T.text
        local row = K.new("TextButton", {
            Size = UDim2.new(1, -4, 0, 22), BackgroundColor3 = T.panel, BorderSizePixel = 0,
            Text = "", AutoButtonColor = false, Parent = list,
        })
        K.new("TextLabel", {
            Size = UDim2.new(0, 38, 1, 0), BackgroundColor3 = tc, BackgroundTransparency = 0.75,
            BorderSizePixel = 0, Text = s.class:sub(1, 5), Font = Enum.Font.GothamBold, TextSize = 9,
            TextColor3 = tc, Parent = row,
        })
        K.new("TextLabel", {
            Size = UDim2.new(1, -100, 1, 0), Position = UDim2.new(0, 42, 0, 0), BackgroundTransparency = 1,
            Text = s.path, Font = Enum.Font.Code, TextSize = 10, TextColor3 = sc,
            TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
        K.new("TextLabel", {
            Size = UDim2.new(0, 56, 1, 0), Position = UDim2.new(1, -58, 0, 0), BackgroundTransparency = 1,
            Text = s.status:sub(1, 4) .. "/" .. D.Util.fmtSize(s.size), Font = Enum.Font.Code, TextSize = 9,
            TextColor3 = sc, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
        })
        row.MouseButton1Click:Connect(D.Log.wrap("ui:rowCopy", function()
            D.Output.copyText(s.path, "path")
        end))
    end

    function UI.rebuildList()
        UI.clearList()
        S.renderToken = S.renderToken + 1
        local myToken = S.renderToken
        local needle = filter.Text:lower()

        task.spawn(function()
            D.Log.safe("ui:rebuildList", function()
                local shown, batch, capped = 0, 0, false
                local all = S.allScripts
                for _, s in ipairs(all) do
                    if myToken ~= S.renderToken or S.dead then return end
                    if shown >= Cfg.SCAN.RENDER_CAP then capped = true break end
                    if needle == "" or s.path:lower():find(needle, 1, true) then
                        shown = shown + 1
                        makeRow(s)
                        batch = batch + 1
                        if batch % 50 == 0 then
                            list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
                            task.wait()
                        end
                    end
                end
                if myToken ~= S.renderToken then return end
                list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
                UI.setStatus(capped
                    and ("Showing %d of %d scripts — use the filter to narrow down"):format(shown, #all)
                    or ("Showing %d of %d scripts"):format(shown, #all))
            end)
        end)
    end

    filter:GetPropertyChangedSignal("Text"):Connect(function()
        S.filterToken = S.filterToken + 1
        local t = S.filterToken
        task.delay(0.3, function()
            if t == S.filterToken and #S.allScripts > 0 and not S.dead then UI.rebuildList() end
        end)
    end)
end
