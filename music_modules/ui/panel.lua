--[[ UI PANEL — perakitan UI utama: header, kontrol, drag/resize, event ]]

return function(REN)
    local W = REN.Widgets
    local S = REN.State
    local C = REN.Config
    local A = REN.Audio

    REN.createMusicUI = function()
        local pg = S.playerGui

        if pg:FindFirstChild("REN_MusicUI") then
            pg.REN_MusicUI:Destroy()
        end

        local gui = W.mk("ScreenGui", {
            Name = "REN_MusicUI", ResetOnSpawn = false, DisplayOrder = 250,
        }, pg)

        -- ═══ ICON ═══════════════════════════════════════════════════
        local icon = W.mk("TextButton", {
            Size = UDim2.fromOffset(40, 40), Position = C.DefaultIconPos,
            BackgroundColor3 = Color3.fromRGB(22, 26, 40), Text = "🎵", TextSize = 18,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 10,
        }, gui)
        W.corner(icon, 20)
        W.mk("UIStroke", {Color = W.GREEN, Thickness = 2}, icon)

        -- ═══ PANEL ══════════════════════════════════════════════════
        local panel = W.mk("Frame", {
            Size = UDim2.fromOffset(C.DefaultSize.X, C.DefaultSize.Y),
            Position = C.DefaultPanelPos,
            BackgroundColor3 = Color3.fromRGB(20, 24, 38),
            BorderSizePixel = 0, Visible = false,
        }, gui)
        W.corner(panel, 10)
        W.mk("UIStroke", {Color = W.GREEN, Thickness = 1.5}, panel)

        -- ═══ HEADER ═════════════════════════════════════════════════
        local header = W.mk("Frame", {
            Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Active = true,
        }, panel)

        local uploadBtn = W.button(header, {
            Size = UDim2.fromOffset(60, 16), Position = UDim2.fromOffset(4, 4),
            BackgroundColor3 = Color3.fromRGB(0, 180, 130), Text = "Upload Song",
            TextSize = 8,
        })

        local hTitle = W.label(header, {
            Size = UDim2.new(1, -108, 1, 0), Position = UDim2.fromOffset(66, 0),
            TextColor3 = W.GREEN, Font = Enum.Font.GothamBold, TextSize = 10,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        local modeBtn = W.button(header, {
            Size = UDim2.fromOffset(36, 16), Position = UDim2.new(1, -40, 0, 4),
            BackgroundColor3 = A.getModeColor(), Text = A.getModeText(), TextSize = 10,
        })

        -- ═══ SEARCH + SMALL BUTTONS ═════════════════════════════════
        local searchBox = W.input(panel, {
            Size = UDim2.new(1, -60, 0, 20), Position = UDim2.fromOffset(8, 26),
            PlaceholderText = "Search songs...",
        })

        local function smallBtn(x, text, bg)
            return W.button(panel, {
                Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, x, 0, 26),
                BackgroundColor3 = bg or Color3.fromRGB(35, 40, 55),
                Text = text, TextSize = 11,
            })
        end
        local sortLikesBtn = smallBtn(-48, "📊", Color3.fromRGB(60, 90, 60))
        local shuffleBtn   = smallBtn(-24, "🔀")

        -- ═══ LIST FRAME ═════════════════════════════════════════════
        local listFrame = W.mk("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -118), Position = UDim2.fromOffset(8, 50),
            BackgroundColor3 = Color3.fromRGB(25, 30, 42), BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(0, 200, 140),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, panel)
        W.corner(listFrame, 6)
        W.mk("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}, listFrame)
        W.mk("UIPadding", {
            PaddingTop = UDim.new(0, 3), PaddingLeft = UDim.new(0, 3),
            PaddingRight = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
        }, listFrame)

        -- ═══ NOW PLAYING + REPORT ═══════════════════════════════════
        local nowPlaying = W.label(panel, {
            Size = UDim2.new(1, -44, 0, 16), Position = UDim2.new(0, 8, 1, -64),
            TextColor3 = Color3.fromRGB(240, 240, 250),
            Font = Enum.Font.GothamBold, TextSize = 10,
            TextTruncate = Enum.TextTruncate.AtEnd,
        })
        local reportBtn = W.button(panel, {
            Size = UDim2.fromOffset(24, 16), Position = UDim2.new(1, -32, 1, -64),
            BackgroundColor3 = Color3.fromRGB(90, 40, 40), Text = "🚩", TextSize = 9,
        }, 4)

        -- ═══ CONTROLS ═══════════════════════════════════════════════
        local controls = W.mk("Frame", {
            Size = UDim2.new(1, -16, 0, 24), Position = UDim2.new(0, 8, 1, -44),
            BackgroundTransparency = 1,
        }, panel)
        W.mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, controls)

        local function ctl(order, text, bg, size)
            return W.button(controls, {
                Size = UDim2.new(0.25, -4, 1, 0), LayoutOrder = order,
                BackgroundColor3 = bg, Text = text, TextSize = size or 13,
            }, 6)
        end
        local prevBtn = ctl(1, "⏮", Color3.fromRGB(40, 46, 66))
        local playBtn = ctl(2, "⏸", Color3.fromRGB(0, 200, 140))
        local nextBtn = ctl(3, "⏭", Color3.fromRGB(40, 46, 66))
        local volBtn  = ctl(4, "", Color3.fromRGB(40, 46, 66), 9)

        -- ═══ RESIZE HANDLE ══════════════════════════════════════════
        local resizeHandle = W.mk("TextButton", {
            Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -18, 1, -18),
            BackgroundTransparency = 1, Text = "◢", TextColor3 = W.GREEN, TextSize = 14,
            BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 30,
        }, panel)

        -- ═══ DIALOGS ════════════════════════════════════════════════
        local uploadDialog = REN.createUploadDialog(panel, function(entry)
            for i, e in ipairs(S.playlist) do
                if e == entry then A.playSongAt(i); break end
            end
        end)
        local reportDialog = REN.createReportDialog(panel, function()
            return S.playlist[S.currentIndex]
        end)

        -- ═══ ROWS MANAGER ═══════════════════════════════════════════
        local rows = REN.createRows(listFrame, searchBox)

        -- ═══ UPDATE UI ══════════════════════════════════════════════
        local function updateUI()
            local entry = S.playlist[S.currentIndex]
            hTitle.Text = "🎵 Music (" .. #S.playlist .. ")"
            nowPlaying.Text = entry and entry.name or "-"
            playBtn.Text = S.musicPaused and "▶" or "⏸"
            playBtn.BackgroundColor3 = S.musicPaused
                and Color3.fromRGB(200, 150, 50)
                or  Color3.fromRGB(0, 200, 140)
            modeBtn.Text = A.getModeText()
            modeBtn.BackgroundColor3 = A.getModeColor()
            volBtn.Text = "🔉" .. math.floor(S.musicVolume * 100) .. "%"
        end

        S.refreshUI = function()
            updateUI(); rows.updateHighlights()
        end
        S.appendRowToUI = rows.appendRowToUI

        -- ═══ SEARCH FILTER EVENT ════════════════════════════════════
        searchBox:GetPropertyChangedSignal("Text"):Connect(rows.applyFilter)

        -- ═══ SORT / SHUFFLE ═════════════════════════════════════════
        local function markSort(likes)
            sortLikesBtn.BackgroundColor3 = likes
                and Color3.fromRGB(60, 90, 60) or Color3.fromRGB(35, 40, 55)
            shuffleBtn.BackgroundColor3 = likes
                and Color3.fromRGB(35, 40, 55) or Color3.fromRGB(60, 90, 60)
        end
        sortLikesBtn.MouseButton1Click:Connect(function()
            markSort(true); rows.applySort("likes"); updateUI()
        end)
        shuffleBtn.MouseButton1Click:Connect(function()
            markSort(false); rows.applySort("shuffle"); updateUI()
        end)

        -- ═══ DIALOG TRIGGERS ════════════════════════════════════════
        uploadBtn.MouseButton1Click:Connect(function()
            uploadDialog.show(); reportDialog.hide()
        end)
        reportBtn.MouseButton1Click:Connect(function()
            reportDialog.show(); uploadDialog.hide()
        end)

        -- ═══ CONTROLS EVENTS ════════════════════════════════════════
        prevBtn.MouseButton1Click:Connect(function()
            A.playSongAt(S.currentIndex - 1)
        end)
        nextBtn.MouseButton1Click:Connect(function()
            A.playSongAt(S.currentIndex + 1)
        end)
        playBtn.MouseButton1Click:Connect(function()
            if S.musicPaused then
                S.musicPaused = false
                pcall(function() S.musicSound:Resume() end)
            else
                S.musicPaused = true
                pcall(function() S.musicSound:Pause() end)
            end
            S.currentPlayToken = S.currentPlayToken + 1
            updateUI()
        end)
        modeBtn.MouseButton1Click:Connect(function()
            S.musicState = (S.musicState % 3) + 1
            A.applyMusicState(); updateUI()
        end)
        volBtn.MouseButton1Click:Connect(function()
            S.musicVolume = S.musicVolume + 0.1
            if S.musicVolume > 1.05 then S.musicVolume = 0 end
            S.musicVolume = math.clamp(S.musicVolume, 0, 1)
            if S.musicSound and S.musicState ~= 3 then
                S.musicSound.Volume = S.musicVolume
            end
            updateUI()
        end)

        -- ═══ DRAG / RESIZE ══════════════════════════════════════════
        local UIS = game:GetService("UserInputService")
        local function isPress(i)
            return i.UserInputType == Enum.UserInputType.MouseButton1
                or i.UserInputType == Enum.UserInputType.Touch
        end
        local function isMove(i)
            return i.UserInputType == Enum.UserInputType.MouseMovement
                or i.UserInputType == Enum.UserInputType.Touch
        end

        local drag, dragStart, startPos, startSize, iconMoved = nil, nil, nil, nil, false

        header.InputBegan:Connect(function(i)
            if isPress(i) then
                drag = "panel"; dragStart = i.Position; startPos = panel.Position
            end
        end)
        resizeHandle.InputBegan:Connect(function(i)
            if isPress(i) then
                drag = "resize"; dragStart = i.Position; startSize = panel.AbsoluteSize
            end
        end)
        icon.InputBegan:Connect(function(i)
            if isPress(i) then
                drag = "icon"; dragStart = i.Position
                startPos = icon.Position; iconMoved = false
            end
        end)

        UIS.InputChanged:Connect(function(i)
            if not drag or not isMove(i) then return end
            local d = i.Position - dragStart
            if drag == "panel" then
                panel.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + d.X,
                    startPos.Y.Scale, startPos.Y.Offset + d.Y
                )
            elseif drag == "resize" then
                local w = math.clamp(startSize.X + d.X, C.MinPanelSize.X, C.MaxPanelSize.X)
                local h = math.clamp(startSize.Y + d.Y, C.MinPanelSize.Y, C.MaxPanelSize.Y)
                panel.Size = UDim2.fromOffset(w, h)
            elseif drag == "icon" then
                if math.abs(d.X) > 5 or math.abs(d.Y) > 5 then iconMoved = true end
                if iconMoved then
                    icon.Position = UDim2.new(
                        startPos.X.Scale, startPos.X.Offset + d.X,
                        startPos.Y.Scale, startPos.Y.Offset + d.Y
                    )
                end
            end
        end)

        UIS.InputEnded:Connect(function(i)
            if not isPress(i) or not drag then return end
            if drag == "icon" and not iconMoved then
                panel.Visible = not panel.Visible
                if panel.Visible then
                    uploadDialog.hide(); reportDialog.hide()
                    updateUI()
                end
                icon.BackgroundColor3 = panel.Visible
                    and Color3.fromRGB(0, 180, 130)
                    or  Color3.fromRGB(22, 26, 40)
            end
            drag = nil
        end)

        -- ═══ INITIAL BUILD ══════════════════════════════════════════
        rows.rebuildList()
        updateUI()
    end
end
