--[[ UI DIALOGS — dialog Upload Song & Report Song ]]

return function(REN)
    local W = REN.Widgets
    local S = REN.State
    local So = REN.Social
    local Sub = REN.Submit

    -- ═══ Upload dialog ═════════════════════════════════════════════
    local function createUploadDialog(panel, onSuccess)
        local dialog = W.mk("Frame", {
            Size = UDim2.new(1, -16, 0, 140), Position = UDim2.fromOffset(8, 50),
            BackgroundColor3 = Color3.fromRGB(15, 18, 30),
            BorderSizePixel = 0, Visible = false, ZIndex = 20,
        }, panel)
        W.corner(dialog, 8)
        W.mk("UIStroke", {Color = W.GREEN, Thickness = 1.5}, dialog)

        W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4),
            Text = "➕ Upload Song", TextColor3 = W.GREEN,
            Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 21,
        })
        local nameInput = W.input(dialog, {
            Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 24),
            PlaceholderText = "Song name...", ZIndex = 21,
        })
        local idInput = W.input(dialog, {
            Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 50),
            PlaceholderText = "ID / //ID / rbxassetid:// / link", ZIndex = 21,
        })
        W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 12), Position = UDim2.fromOffset(8, 75),
            Text = "Example: 123456789 • //123456789 • Roblox link",
            TextColor3 = Color3.fromRGB(120, 130, 150), TextSize = 8, ZIndex = 21,
        })
        local statusLbl = W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 90),
            TextColor3 = W.INFO, TextSize = 9, TextWrapped = true, ZIndex = 21,
        })
        local cancelBtn = W.button(dialog, {
            Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0, 8, 1, -28),
            BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = "Cancel",
            TextSize = 10, ZIndex = 21,
        })
        local submitBtn = W.button(dialog, {
            Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0.5, 4, 1, -28),
            BackgroundColor3 = Color3.fromRGB(0, 180, 130), Text = "Submit",
            TextColor3 = Color3.new(1, 1, 1), TextSize = 10, ZIndex = 21,
        })

        cancelBtn.MouseButton1Click:Connect(function()
            dialog.Visible = false
            nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
        end)

        local submitting = false
        submitBtn.MouseButton1Click:Connect(function()
            if submitting then return end
            submitting = true
            submitBtn.Visible = false
            task.spawn(function()
                local entry, err = Sub.submit(nameInput.Text, idInput.Text, function(msg)
                    statusLbl.Text = msg
                    statusLbl.TextColor3 = W.INFO
                end)
                submitting = false
                submitBtn.Visible = true
                if entry then
                    statusLbl.Text = "✅ Success!"
                    statusLbl.TextColor3 = W.GREEN
                    task.wait(0.8)
                    dialog.Visible = false
                    nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
                    if onSuccess then onSuccess(entry) end
                else
                    statusLbl.Text = "❌ " .. tostring(err)
                    statusLbl.TextColor3 = W.RED
                end
            end)
        end)

        return {
            frame = dialog,
            show  = function() dialog.Visible = true; statusLbl.Text = "" end,
            hide  = function()
                dialog.Visible = false
                nameInput.Text = ""; idInput.Text = ""; statusLbl.Text = ""
            end,
        }
    end

    -- ═══ Report dialog ═════════════════════════════════════════════
    local function createReportDialog(panel, getCurrentEntry)
        local dialog = W.mk("Frame", {
            Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 50),
            BackgroundColor3 = Color3.fromRGB(25, 15, 15),
            BorderSizePixel = 0, Visible = false, ZIndex = 20,
        }, panel)
        W.corner(dialog, 8)
        W.mk("UIStroke", {Color = Color3.fromRGB(220, 80, 80), Thickness = 1.5}, dialog)

        W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 18), Position = UDim2.fromOffset(8, 4),
            Text = "🚩 Report Song", TextColor3 = Color3.fromRGB(255, 120, 120),
            Font = Enum.Font.GothamBold, TextSize = 11, ZIndex = 21,
        })
        local songLbl = W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 22),
            TextColor3 = Color3.fromRGB(230, 200, 200), TextSize = 9,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21,
        })
        local reasonInput = W.input(dialog, {
            Size = UDim2.new(1, -16, 0, 66), Position = UDim2.fromOffset(8, 40),
            BackgroundColor3 = Color3.fromRGB(35, 25, 30),
            PlaceholderText = "Report reason...",
            TextYAlignment = Enum.TextYAlignment.Top,
            MultiLine = true, TextWrapped = true, ZIndex = 21,
        })
        local statusLbl = W.label(dialog, {
            Size = UDim2.new(1, -16, 0, 14), Position = UDim2.fromOffset(8, 108),
            TextColor3 = W.INFO, TextSize = 9, ZIndex = 21,
        })
        local cancelBtn = W.button(dialog, {
            Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0, 8, 1, -28),
            BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = "Cancel",
            TextSize = 10, ZIndex = 21,
        })
        local sendBtn = W.button(dialog, {
            Size = UDim2.new(0.5, -12, 0, 22), Position = UDim2.new(0.5, 4, 1, -28),
            BackgroundColor3 = Color3.fromRGB(200, 60, 60), Text = "Send",
            TextColor3 = Color3.new(1, 1, 1), TextSize = 10, ZIndex = 21,
        })

        cancelBtn.MouseButton1Click:Connect(function()
            dialog.Visible = false
            reasonInput.Text = ""; statusLbl.Text = ""
        end)

        local sending = false
        sendBtn.MouseButton1Click:Connect(function()
            if sending then return end
            local entry = getCurrentEntry()
            if not entry then
                statusLbl.Text = "❌ No song"
                statusLbl.TextColor3 = W.RED
                return
            end
            local reason = reasonInput.Text
            if not reason or #reason < 5 then
                statusLbl.Text = "❌ Min 5 characters"
                statusLbl.TextColor3 = W.RED
                return
            end
            if #reason > 500 then reason = reason:sub(1, 500) end

            sending = true; sendBtn.Text = "..."
            statusLbl.Text = "📤 Sending..."; statusLbl.TextColor3 = W.INFO
            task.spawn(function()
                local ok, err = So.sendReport(entry, reason)
                sending = false; sendBtn.Text = "Send"
                if ok then
                    statusLbl.Text = "✅ Sent!"; statusLbl.TextColor3 = W.GREEN
                    task.wait(1.2)
                    dialog.Visible = false
                    reasonInput.Text = ""; statusLbl.Text = ""
                else
                    statusLbl.Text = "❌ " .. tostring(err); statusLbl.TextColor3 = W.RED
                end
            end)
        end)

        return {
            frame = dialog,
            show = function()
                local e = getCurrentEntry()
                songLbl.Text = e and e.name or "-"
                statusLbl.Text = ""; reasonInput.Text = ""
                dialog.Visible = true
            end,
            hide = function()
                dialog.Visible = false
                reasonInput.Text = ""; statusLbl.Text = ""
            end,
        }
    end

    REN.createUploadDialog = createUploadDialog
    REN.createReportDialog = createReportDialog
end
