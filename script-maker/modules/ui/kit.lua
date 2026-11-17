--[[ UI/KIT — komponen GUI kecil yang dipakai semua halaman (satu gaya untuk semuanya).
     Semua teks GUI = English. Urutan tampil = urutan pembuatan (LayoutOrder otomatis).

     K.new(class, props, children)         K.corner(r)            K.pad(l, t, r, b)
     K.label(parent, text, {size,color,bold,h,align,wrap})
     K.button(parent, text, cb, {color,h,ts,tip})        -- tip = key BTN_INFO/TOGGLE_INFO | tabel | function
     K.toggle(parent, text, get, set, {tip,h})            -- set(newValue); tampilan selalu dibaca ulang dari get()
     K.card(parent, title) → Frame      K.grid(parent, cols, cellHeight) → Frame
     K.stack(parent) → ScrollingFrame vertikal (halaman)   K.field(parent, placeholder)
     K.tip(button, info)    K.refreshAll()  (segarkan semua toggle) ]]

return function(D)
    local Cfg = D.Config
    local T = Cfg.THEME
    local UI = D.UI
    local K = {}
    UI.kit = K

    local seq = 0
    local toggles = {}

    function K.new(class, props, children)
        local o = Instance.new(class)
        local parent
        for k, v in pairs(props or {}) do
            if k == "Parent" then parent = v else o[k] = v end
        end
        if o:IsA("GuiObject") and not (props and props.LayoutOrder) then
            seq = seq + 1
            o.LayoutOrder = seq
        end
        for _, c in ipairs(children or {}) do c.Parent = o end
        if parent then o.Parent = parent end
        return o
    end

    function K.corner(r) return K.new("UICorner", { CornerRadius = UDim.new(0, r or 6) }) end

    function K.pad(l, t, r, b)
        return K.new("UIPadding", {
            PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
            PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
        })
    end

    function K.label(parent, text, o)
        o = o or {}
        local props = {
            BackgroundTransparency = 1,
            Text = text,
            Font = o.bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextSize = o.size or 12,
            TextColor3 = o.color or T.text,
            TextXAlignment = o.align or Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = o.wrap ~= false,
            Parent = parent,
        }
        if o.h then
            props.Size = UDim2.new(1, 0, 0, o.h)
        else
            props.Size = UDim2.new(1, 0, 0, 0)
            props.AutomaticSize = Enum.AutomaticSize.Y
        end
        return K.new("TextLabel", props)
    end

    -- ── Tooltip badge ───────────────────────────────────────────────
    function K.tip(btn, info)
        local function get()
            if type(info) == "function" then return info() end
            if type(info) == "table" then return info end
            return Cfg.BTN_INFO[info] or Cfg.TOGGLE_INFO[info]
        end
        local function show()
            local inf = get()
            if inf and UI.showTooltip then UI.showTooltip(inf) end
        end
        K.new("TextButton", {
            Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -20, 0.5, -8),
            BackgroundColor3 = T.line, Text = "?", Font = Enum.Font.GothamBold, TextSize = 11,
            TextColor3 = T.text, AutoButtonColor = false, ZIndex = 4, Parent = btn,
        }, { K.corner(8) }).MouseButton1Click:Connect(D.Log.wrap("ui:tip", show))
        btn.MouseButton2Click:Connect(D.Log.wrap("ui:tip2", show)) -- klik kanan (PC)
    end

    function K.button(parent, text, cb, o)
        o = o or {}
        local b = K.new("TextButton", {
            Size = UDim2.new(1, 0, 0, o.h or 30),
            BackgroundColor3 = o.color or T.btn,
            Text = text, Font = Enum.Font.GothamBold, TextSize = o.ts or 12, TextColor3 = T.text,
            TextTruncate = Enum.TextTruncate.AtEnd,
            AutoButtonColor = true, BorderSizePixel = 0, Parent = parent,
        }, { K.corner(6) })
        if o.tip then K.pad(0, 0, 22, 0).Parent = b; K.tip(b, o.tip) end
        if cb then b.MouseButton1Click:Connect(D.Log.wrap("btn:" .. tostring(text), cb)) end
        return b
    end

    function K.toggle(parent, text, get, set, o)
        o = o or {}
        local row = K.new("TextButton", {
            Size = UDim2.new(1, 0, 0, o.h or 30), BackgroundColor3 = T.field, Text = "",
            AutoButtonColor = false, BorderSizePixel = 0, Parent = parent,
        }, { K.corner(6) })
        K.new("TextLabel", {
            Size = UDim2.new(1, o.tip and -92 or -62, 1, 0), Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1, Text = text, Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
        })
        local track = K.new("Frame", {
            Size = UDim2.new(0, 36, 0, 18), Position = UDim2.new(1, o.tip and -64 or -44, 0.5, -9),
            BackgroundColor3 = T.line, BorderSizePixel = 0, Parent = row,
        }, { K.corner(9) })
        local knob = K.new("Frame", {
            Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 2, 0.5, -7),
            BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
        }, { K.corner(7) })

        local t = {}
        function t.refresh()
            local on = get() == true
            track.BackgroundColor3 = on and T.good or T.line
            knob.Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        end
        row.MouseButton1Click:Connect(D.Log.wrap("toggle:" .. tostring(text), function()
            set(not (get() == true))
            K.refreshAll()
        end))
        if o.tip then K.tip(row, o.tip) end
        t.row = row
        toggles[#toggles + 1] = t
        t.refresh()
        return t
    end

    function K.refreshAll()
        for _, t in ipairs(toggles) do pcall(t.refresh) end
    end
    UI.refreshAll = K.refreshAll

    function K.card(parent, title)
        local card = K.new("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = T.card, BorderSizePixel = 0, Parent = parent,
        }, {
            K.corner(8), K.pad(8, 8, 8, 8),
            K.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
        })
        if title then K.label(card, title, { bold = true, size = 13, color = T.accent }) end
        return card
    end

    function K.grid(parent, cols, h)
        local pad = 6
        local off = -math.floor(pad * (cols - 1) / cols)
        return K.new("Frame", {
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Parent = parent,
        }, {
            K.new("UIGridLayout", {
                CellSize = UDim2.new(1 / cols, off, 0, h or 30),
                CellPadding = UDim2.new(0, pad, 0, pad),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })
    end

    function K.stack(parent)
        return K.new("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, CanvasSize = UDim2.new(0, 0, 0, 0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
            Parent = parent,
        }, {
            K.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
            K.pad(0, 2, 6, 8),
        })
    end

    function K.field(parent, placeholder)
        return K.new("TextBox", {
            Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = T.field, BorderSizePixel = 0,
            PlaceholderText = placeholder or "", PlaceholderColor3 = T.dim, Text = "",
            ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = T.text,
            TextXAlignment = Enum.TextXAlignment.Left, Parent = parent,
        }, { K.corner(6), K.pad(8, 0, 8, 0) })
    end
end
