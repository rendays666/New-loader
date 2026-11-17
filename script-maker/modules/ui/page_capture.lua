--[[ UI/PAGE_CAPTURE (Advanced, tab "Actions") — remote spy: rekam, daftar panggilan, kode siap salin,
     Replay / Block / Ignore. Data masuk lewat D.Capture.addListener (dari Heartbeat, bukan dari hook). ]]

return function(D)
    local S, Cfg, A = D.State, D.Config, D.Actions
    local UI, K = D.UI, D.UI.kit
    local T = Cfg.THEME

    local page = UI.addPage("actions", "Actions", true)
    local stack = K.stack(page)

    K.label(stack, "Shows what the game sends to the server. Turn Record on, do the action in the game, then tap a call to get code you can copy.",
        { size = 11, color = T.dim })

    local selected, rows = nil, {}
    local showEvents, showFuncs, needle = true, true, ""
    local blockBtn, tplBtn, methodBtn, pauseBtn, codeBox

    -- ── Recording ───────────────────────────────────────────────────
    local rec = K.card(stack, "Recording")
    K.toggle(rec, "Record game actions",
        function() return S.capturing end,
        function(v) A.setCapture(v) end,
        { tip = "capture" })

    local function methodInfo()
        for _, m in ipairs(Cfg.CAPTURE_METHODS) do
            if m.id == S.captureMethod then
                return { name = "Method: " .. m.text, desc = m.desc,
                    use = "Tap the button to switch. If nothing is recorded, try another method." }
            end
        end
    end
    local function methodText()
        for _, m in ipairs(Cfg.CAPTURE_METHODS) do
            if m.id == S.captureMethod then
                local used = (S.capturing and S.captureUsing) and (" → " .. S.captureUsing) or ""
                return "Method: " .. m.text .. used
            end
        end
        return "Method: ?"
    end
    methodBtn = K.button(rec, methodText(), function()
        local ms = Cfg.CAPTURE_METHODS
        local idx = 1
        for i, m in ipairs(ms) do if m.id == S.captureMethod then idx = i end end
        S.captureMethod = ms[idx % #ms + 1].id
        if S.capturing then A.setCapture(true) end -- mulai ulang dengan metode baru
        methodBtn.Text = methodText()
        UI.refreshAll()
    end, { tip = methodInfo })

    local g = K.grid(rec, 3, 28)
    pauseBtn = K.button(g, "Pause", function()
        D.Spy.setPaused(not S.spy.paused)
        pauseBtn.Text = S.spy.paused and "Resume" or "Pause"
    end, { h = 28 })
    K.button(g, "Clear list", function() D.Capture.clearCalls() end, { h = 28 })
    K.button(g, "Reset filters", function()
        D.Spy.resetFilters()
        for _, r in ipairs(rows) do r.refresh() end
        if selected then blockBtn.Text = "Block" end
    end, { h = 28 })

    -- ── Calls list ──────────────────────────────────────────────────
    local calls = K.card(stack, "Recorded calls")
    local filter = K.field(calls, "Filter by remote name…")
    local gt = K.grid(calls, 2, 28)
    K.toggle(gt, "Events", function() return showEvents end, function(v) showEvents = v end, { h = 28 })
    K.toggle(gt, "Functions", function() return showFuncs end, function(v) showFuncs = v end, { h = 28 })

    local list = K.new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 140), BackgroundColor3 = T.field, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4, Parent = calls,
    }, {
        K.corner(6),
        K.new("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
    })

    -- ── Detail ──────────────────────────────────────────────────────
    local detail = K.card(stack, "Selected call")
    local codeScroll = K.new("ScrollingFrame", {
        Size = UDim2.new(1, 0, 0, 120), BackgroundColor3 = T.field, BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.XY,
        ScrollingDirection = Enum.ScrollingDirection.XY, ScrollBarThickness = 4, Parent = detail,
    }, { K.corner(6) })
    codeBox = K.new("TextBox", {
        Size = UDim2.new(0, 100, 0, 20), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
        Text = "Tap a call above.", TextColor3 = T.text, Font = Enum.Font.Code, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        MultiLine = true, TextEditable = false, ClearTextOnFocus = false, TextWrapped = false,
        Parent = codeScroll,
    }, { K.pad(6, 4, 6, 4) })

    local function needSelected()
        if selected then return true end
        UI.setStatus("Tap a recorded call first.")
        return false
    end

    local function refreshButtons()
        if blockBtn then
            blockBtn.Text = (selected and D.Spy.isBlocked(selected.inst)) and "Unblock" or "Block"
        end
        if tplBtn then tplBtn.Text = "Style: " .. D.Spy.templateName() end
    end

    local function showSelected()
        codeBox.Text = selected and D.Spy.generate(selected) or "Tap a call above."
        refreshButtons()
    end

    local ga = K.grid(detail, 3, 30)
    K.button(ga, "Copy code", function()
        if needSelected() then D.Output.copyText(D.Spy.generate(selected), "call code") end
    end, { color = T.accent })
    tplBtn = K.button(ga, "Style: simple", function()
        D.Spy.cycleTemplate()
        showSelected()
    end, { ts = 11, tip = "TEMPLATE" })
    K.button(ga, "Replay", function()
        if needSelected() then D.Spy.replay(selected) end
    end, { color = T.warn, tip = "REPLAY" })
    blockBtn = K.button(ga, "Block", function()
        if not needSelected() then return end
        D.Spy.toggleBlock(selected.inst)
        for _, r in ipairs(rows) do r.refresh() end
        refreshButtons()
    end, { color = T.bad, tip = "BLOCK" })
    K.button(ga, "Ignore", function()
        if not needSelected() then return end
        D.Spy.ignore(selected.inst)
        for _, r in ipairs(rows) do r.refresh() end
    end, { tip = "IGNORE" })
    refreshButtons()

    -- ── Baris daftar ────────────────────────────────────────────────
    local function matches(e)
        if S.spy.ignored[e.inst] then return false end
        if e.method == "FireServer" and not showEvents then return false end
        if e.method == "InvokeServer" and not showFuncs then return false end
        if needle ~= "" and not e.name:lower():find(needle, 1, true) then return false end
        return true
    end

    local function addRow(e)
        local isEvent = e.method == "FireServer"
        local btn = K.new("TextButton", {
            Size = UDim2.new(1, -4, 0, 22), BackgroundColor3 = T.panel, BorderSizePixel = 0,
            Text = ("#%d %s %s  (%s)"):format(e.id, isEvent and "[E]" or "[F]", e.name, table.concat(e.args, ", ")),
            Font = Enum.Font.Code, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, AutoButtonColor = true, LayoutOrder = e.id,
            Parent = list,
        }, { K.pad(6, 0, 4, 0) })

        local row = { entry = e, btn = btn }
        function row.refresh()
            btn.Visible = matches(e)
            btn.TextColor3 = D.Spy.isBlocked(e.inst) and T.bad or (isEvent and T.event or T.func)
            btn.BackgroundColor3 = (selected == e) and Color3.fromRGB(60, 70, 120) or T.panel
        end
        btn.MouseButton1Click:Connect(D.Log.wrap("ui:selectCall", function()
            selected = e
            for _, r in ipairs(rows) do r.refresh() end
            showSelected()
        end))
        row.refresh()
        rows[#rows + 1] = row

        while #rows > 300 do
            local old = table.remove(rows, 1)
            old.btn:Destroy()
            if selected == old.entry then selected = nil; showSelected() end
        end
    end

    local function clearRows()
        for _, r in ipairs(rows) do r.btn:Destroy() end
        rows, selected = {}, nil
        showSelected()
    end

    D.Capture.addListener(function(e)
        if S.dead then return end
        if e == nil then clearRows() return end
        local atBottom = list.CanvasPosition.Y + list.AbsoluteWindowSize.Y >= list.AbsoluteCanvasSize.Y - 30
        addRow(e)
        if atBottom then
            task.defer(function() list.CanvasPosition = Vector2.new(0, 1e6) end)
        end
    end)

    local function refilter()
        for _, r in ipairs(rows) do r.refresh() end
    end
    filter:GetPropertyChangedSignal("Text"):Connect(function()
        needle = filter.Text:lower()
        refilter()
    end)
    -- toggle Events/Functions memanggil refresh lewat K.refreshAll; filter ikut dengan polling ringan
    local lastE, lastF = showEvents, showFuncs
    task.spawn(function()
        while not S.dead do
            if lastE ~= showEvents or lastF ~= showFuncs then
                lastE, lastF = showEvents, showFuncs
                refilter()
            end
            methodBtn.Text = methodText()
            task.wait(0.5)
        end
    end)
end
