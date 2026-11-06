--[[ UI ROWS — baris lagu, filter, sort, highlight ]]

return function(REN)
    local W = REN.Widgets
    local S = REN.State
    local U = REN.Utils
    local A = REN.Audio
    local R = REN.Ratings

    -- Factory: bangun manager untuk listFrame + searchBox
    REN.createRows = function(listFrame, searchBox)
        local rowsByIdx = {}

        local function buildRow(idx, entry)
            local isCur = (idx == S.currentIndex)
            local row = W.mk("Frame", {
                Size = UDim2.new(1, 0, 0, 24), LayoutOrder = idx, BorderSizePixel = 0,
                BackgroundColor3 = isCur and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52),
            }, listFrame)

            local playRow = W.mk("TextButton", {
                Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(4, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "", Font = Enum.Font.Gotham,
            }, row)

            local likeBtn = W.mk("TextButton", {
                Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -56, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                TextSize = 9, Font = Enum.Font.GothamBold,
            }, row)
            local dislikeBtn = W.mk("TextButton", {
                Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(1, -28, 0, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                TextSize = 9, Font = Enum.Font.GothamBold,
            }, row)

            local function updateRatingUI()
                likeBtn.Text = "👍" .. U.countKeys(entry.likes)
                dislikeBtn.Text = "👎" .. U.countKeys(entry.dislikes)
                likeBtn.TextColor3 = entry.likes[S.myUserId]
                    and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(160, 160, 180)
                dislikeBtn.TextColor3 = entry.dislikes[S.myUserId]
                    and Color3.fromRGB(90, 140, 255) or Color3.fromRGB(160, 160, 180)
            end
            updateRatingUI()

            playRow.MouseButton1Click:Connect(function()
                for i, e in ipairs(S.playlist) do
                    if e == entry then A.playSongAt(i); break end
                end
            end)
            likeBtn.MouseButton1Click:Connect(function()
                R.toggle(entry, "likes"); updateRatingUI()
            end)
            dislikeBtn.MouseButton1Click:Connect(function()
                R.toggle(entry, "dislikes"); updateRatingUI()
            end)

            rowsByIdx[idx] = {row = row, playRow = playRow, entry = entry}
        end

        local function updateHighlights()
            for idx, d in pairs(rowsByIdx) do
                local cur = (idx == S.currentIndex)
                d.row.BackgroundColor3 = cur
                    and Color3.fromRGB(45, 80, 65)
                    or  Color3.fromRGB(32, 38, 52)
                d.playRow.TextColor3 = cur and W.GREEN or Color3.fromRGB(220, 220, 235)
                d.playRow.Font = cur and Enum.Font.GothamBold or Enum.Font.Gotham
                d.playRow.Text = (cur and "▶ " or "")
                    .. (d.entry.isSubmission and "📤 " or "")
                    .. d.entry.name
            end
        end

        local function applyFilter()
            local txt = (searchBox.Text or ""):lower()
            for _, d in pairs(rowsByIdx) do
                local textMatch = txt == "" or d.entry.name:lower():find(txt, 1, true) ~= nil
                d.row.Visible = textMatch
            end
        end

        local function rebuildList()
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("Frame") then c:Destroy() end
            end
            rowsByIdx = {}
            for idx, entry in ipairs(S.playlist) do buildRow(idx, entry) end
            applyFilter()
            updateHighlights()
        end

        local function appendRowToUI(idx, entry)
            buildRow(idx, entry)
            applyFilter()
            updateHighlights()
        end

        local function applySort(mode)
            local cur = S.playlist[S.currentIndex]
            if mode == "likes" then
                U.sortByScore(S.playlist)
            else
                U.shuffleList(S.playlist)
            end
            if cur then
                for i, e in ipairs(S.playlist) do
                    if e == cur then S.currentIndex = i; break end
                end
            end
            rebuildList()
        end

        return {
            rebuildList    = rebuildList,
            appendRowToUI  = appendRowToUI,
            applyFilter    = applyFilter,
            applySort      = applySort,
            updateHighlights = updateHighlights,
        }
    end
end
