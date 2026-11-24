--[[ UI ROWS — baris lagu (nama, uploader, ID yang bisa disalin), filter, highlight, pagination ]]

return function(REN)
    local W = REN.Widgets
    local S = REN.State
    local U = REN.Utils
    local A = REN.Audio
    local R = REN.Ratings

    local ROW_H     = 34
    local RIGHT_W   = 60    -- area tombol like/dislike
    local ID_W      = 82    -- lebar chip ID
    local ID_COLOR  = Color3.fromRGB(140, 195, 255)
    local SUB_COLOR = Color3.fromRGB(130, 140, 165)
    local PAGE_SIZE = 20

    -- Factory: bangun manager untuk listFrame + searchBox
    REN.createRows = function(listFrame, searchBox)
        local rowsByIdx = {}
        local built = {}        -- set index playlist yang sudah dibangun
        local loadedCount = 0   -- jumlah entri cocok yang sudah dimuat
        local filterText = ""

        -- Rating bisa diubah dari tempat lain (tombol di Now Playing):
        -- sinkronkan baris lagu yang sama.
        if R.onChange then
            R.onChange(function(entry)
                for _, d in pairs(rowsByIdx) do
                    if d.entry == entry then d.refreshRating() end
                end
            end)
        end

        local function buildRow(idx, entry)
            if rowsByIdx[idx] then return end
            local isCur = (entry == S.currentEntry)
            local row = W.mk("Frame", {
                Size = UDim2.new(1, 0, 0, ROW_H), LayoutOrder = idx, BorderSizePixel = 0,
                BackgroundColor3 = isCur and Color3.fromRGB(45, 80, 65) or Color3.fromRGB(32, 38, 52),
            }, listFrame)

            -- Klik nama / area kiri = putar lagu
            local playRow = W.mk("TextButton", {
                Size = UDim2.new(1, -RIGHT_W, 1, 0), Position = UDim2.fromOffset(4, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0, TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Text = "", Font = Enum.Font.Gotham,
            }, row)
            W.pad(playRow, 0, 3)

            -- Baris 2: "by <uploader>"  +  chip ID (klik = salin)
            local assetId = U.extractAssetId(entry.id)
            W.label(row, {
                Size = UDim2.new(1, -(RIGHT_W + ID_W + 8), 0, 12),
                Position = UDim2.fromOffset(4, 19),
                Text = "by " .. U.uploaderOf(entry),
                TextColor3 = SUB_COLOR, TextSize = 8,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })

            local idBtn = W.button(row, {
                Size = UDim2.fromOffset(ID_W, 13),
                Position = UDim2.new(1, -(RIGHT_W + ID_W), 0, 19),
                BackgroundColor3 = Color3.fromRGB(40, 48, 68),
                Text = assetId, TextColor3 = ID_COLOR,
                TextSize = 8, Font = Enum.Font.Gotham,
            }, 3)

            local copyToken = 0
            idBtn.MouseButton1Click:Connect(function()
                local ok = U.copyText(assetId)
                copyToken = copyToken + 1
                local myToken = copyToken
                idBtn.Text       = ok and "Copied!" or "No clipboard"
                idBtn.TextColor3 = ok and W.GREEN or W.RED
                task.delay(1, function()
                    if copyToken == myToken and idBtn.Parent then
                        idBtn.Text       = assetId
                        idBtn.TextColor3 = ID_COLOR
                    end
                end)
            end)

            -- Like / dislike
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
            -- Di view "My Likes", baris yang di-unlike tetap tampil sampai
            -- list di-refresh (ganti mode), supaya tidak hilang mendadak.
            likeBtn.MouseButton1Click:Connect(function()
                R.toggle(entry, "likes"); updateRatingUI()
            end)
            dislikeBtn.MouseButton1Click:Connect(function()
                R.toggle(entry, "dislikes"); updateRatingUI()
            end)

            rowsByIdx[idx] = {
                row = row, playRow = playRow, entry = entry, assetId = assetId,
                refreshRating = updateRatingUI,
            }
            built[idx] = true
        end

        local function updateHighlights()
            for _, d in pairs(rowsByIdx) do
                local cur = (d.entry == S.currentEntry)
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

        local function isMatch(entry)
            local txt = (filterText or ""):lower()
            if txt == "" then return true end
            local assetId = U.extractAssetId(entry.id)
            return entry.name:lower():find(txt, 1, true) ~= nil
                or U.uploaderOf(entry):lower():find(txt, 1, true) ~= nil
                or (assetId and assetId:find(txt, 1, true) ~= nil)
        end

        local function countMatches()
            local n = 0
            for _, e in ipairs(S.playlist) do
                if isMatch(e) then n = n + 1 end
            end
            return n
        end

        local function loadMore()
            local target = loadedCount + PAGE_SIZE
            local count = 0
            for idx, entry in ipairs(S.playlist) do
                if isMatch(entry) then
                    count = count + 1
                    if count > loadedCount and count <= target then
                        if not built[idx] then
                            buildRow(idx, entry)
                        end
                    end
                end
            end
            loadedCount = math.min(target, countMatches())
        end

        local function clearList()
            for _, c in ipairs(listFrame:GetChildren()) do
                if c:IsA("GuiObject") then c:Destroy() end   -- UIListLayout/UIPadding tetap
            end
            rowsByIdx = {}
            built = {}
            loadedCount = 0
        end

        local function showEmpty(msg)
            W.label(listFrame, {
                Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 1,
                Text = msg, TextColor3 = SUB_COLOR, TextSize = 9,
                TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
            })
        end

        local function rebuildList()
            clearList()
            filterText = searchBox.Text or ""
            if #S.playlist == 0 then
                local msg = (S.viewMode == "mine")
                    and "Belum ada lagu yang kamu like.\nTekan 👍 di lagu mana pun,\nlalu buka lagi My Likes."
                    or "Playlist kosong."
                showEmpty(msg)
                return
            end
            if countMatches() == 0 then
                showEmpty("Tidak ada hasil.")
                return
            end
            loadMore()
            updateHighlights()
        end

        local function applyFilter()
            filterText = searchBox.Text or ""
            clearList()
            if #S.playlist == 0 then
                local msg = (S.viewMode == "mine")
                    and "Belum ada lagu yang kamu like.\nTekan 👍 di lagu mana pun,\nlalu buka lagi My Likes."
                    or "Playlist kosong."
                showEmpty(msg)
                return
            end
            if countMatches() == 0 then
                showEmpty("Tidak ada hasil.")
                return
            end
            loadMore()
            updateHighlights()
        end

        local function appendRowToUI(idx, entry)
            filterText = searchBox.Text or ""
            if isMatch(entry) then
                if not built[idx] then
                    buildRow(idx, entry)
                end
            end
            updateHighlights()
        end

        -- Load more saat scroll mendekati bawah
        listFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
            if loadedCount >= countMatches() then return end
            local canvasSize = listFrame.AbsoluteCanvasSize.Y
            local viewport = listFrame.AbsoluteSize.Y
            if canvasSize <= viewport then return end
            local pos = listFrame.CanvasPosition.Y
            if pos + viewport >= canvasSize - 40 then
                loadMore()
                updateHighlights()
            end
        end)

        return {
            rebuildList      = rebuildList,
            appendRowToUI    = appendRowToUI,
            applyFilter      = applyFilter,
            updateHighlights = updateHighlights,
        }
    end
end