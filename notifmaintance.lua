-- ============================================================
-- ✏️ EDIT DI SINI SAJA
-- ============================================================
local NOTIF = {
    header   = "RENREN Hub info",                          -- judul (header)
    text     = "music gui is under construction, update to new version!!! please wait until update done",            -- isi notifikasi
    color    = Color3.fromRGB(0, 220, 160),        -- warna aksen (hijau)
    duration = 10,                                  -- detik tampil
}
-- ============================================================
-- ⛔ JANGAN EDIT DI BAWAH INI
-- ============================================================

local genv = (getgenv and getgenv()) or _G

local function safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[REN Notif] " .. tostring(err)) end
    return ok
end

local Players  = game:GetService("Players")
local TweenSvc = game:GetService("TweenService")

local function getGui()
    local player = Players.LocalPlayer
    if not player then return nil end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local existing = pg:FindFirstChild("REN_NotifGui")
    if existing then return existing end
    local gui = Instance.new("ScreenGui")
    gui.Name = "REN_NotifGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 99998
    gui.IgnoreGuiInset = true
    gui.Parent = pg
    return gui
end

local function notify(opts)
    opts = opts or {}
    local title    = tostring(opts.header or opts.title or "REN Hub")
    local text     = tostring(opts.text or "")
    local color    = opts.color or Color3.fromRGB(0, 220, 160)
    local duration = tonumber(opts.duration) or 3
    if duration < 0.5 then duration = 0.5 end

    safe(function()
        local gui = getGui()
        if not gui then return end

        local container = gui:FindFirstChild("Container")
        if not container then
            container = Instance.new("Frame")
            container.Name = "Container"
            container.BackgroundTransparency = 1
            container.AnchorPoint = Vector2.new(0, 0.5)
            container.Position = UDim2.new(0, 12, 0.5, 0)
            container.Size = UDim2.new(0, 260, 1, 0)
            container.Parent = gui

            local list = Instance.new("UIListLayout")
            list.Padding = UDim.new(0, 8)
            list.VerticalAlignment = Enum.VerticalAlignment.Center
            list.SortOrder = Enum.SortOrder.LayoutOrder
            list.Parent = container
        end

        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 0)
        card.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
        card.BorderSizePixel = 0
        card.ClipsDescendants = true
        card.LayoutOrder = math.floor(os.clock() * 1000)
        card.Parent = container

        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)

        local stroke = Instance.new("UIStroke", card)
        stroke.Color = color
        stroke.Thickness = 1.5
        stroke.Transparency = 0.2

        local pad = Instance.new("UIPadding", card)
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)

        local titleLbl = Instance.new("TextLabel", card)
        titleLbl.Size = UDim2.new(1, 0, 0, 14)
        titleLbl.BackgroundTransparency = 1
        titleLbl.Text = title
        titleLbl.TextColor3 = color
        titleLbl.Font = Enum.Font.GothamBold
        titleLbl.TextSize = 12
        titleLbl.TextXAlignment = Enum.TextXAlignment.Left
        titleLbl.TextTruncate = Enum.TextTruncate.AtEnd

        local textLbl = Instance.new("TextLabel", card)
        textLbl.Size = UDim2.new(1, 0, 0, 0)
        textLbl.Position = UDim2.new(0, 0, 0, 16)
        textLbl.BackgroundTransparency = 1
        textLbl.Text = text
        textLbl.TextColor3 = Color3.fromRGB(210, 218, 230)
        textLbl.Font = Enum.Font.Gotham
        textLbl.TextSize = 11
        textLbl.TextXAlignment = Enum.TextXAlignment.Left
        textLbl.TextWrapped = true
        textLbl.TextYAlignment = Enum.TextYAlignment.Top
        textLbl.AutomaticSize = Enum.AutomaticSize.Y

        task.wait()
        local textHeight = textLbl.AbsoluteSize.Y
        if textHeight < 14 then textHeight = 14 end
        local targetHeight = 16 + textHeight + 4
        if targetHeight < 34 then targetHeight = 34 end
        textLbl.Size = UDim2.new(1, 0, 0, textHeight)
        textLbl.AutomaticSize = Enum.AutomaticSize.None

        card.BackgroundTransparency = 1
        stroke.Transparency = 1
        titleLbl.TextTransparency = 1
        textLbl.TextTransparency = 1

        TweenSvc:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(1, 0, 0, targetHeight),
            BackgroundTransparency = 0,
        }):Play()
        TweenSvc:Create(stroke, TweenInfo.new(0.25), { Transparency = 0.2 }):Play()
        TweenSvc:Create(titleLbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
        TweenSvc:Create(textLbl, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

        task.delay(duration, function()
            safe(function()
                if not card or not card.Parent then return end
                TweenSvc:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1,
                }):Play()
                TweenSvc:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
                TweenSvc:Create(titleLbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
                TweenSvc:Create(textLbl, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
                task.wait(0.3)
                safe(function() card:Destroy() end)
            end)
        end)
    end)
end

genv.REN_notify = notify

-- Jalankan notifikasi dengan isi dari NOTIF di atas
notify(NOTIF)
