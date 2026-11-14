--[[ UI INFO — tombol (i) di header + dialog Informasi

  KUSTOMISASI: edit blok CONFIG di bawah saja, file lain tidak perlu disentuh.
    - Icon / IconColor / IconBg  : tampilan tombol (i) di header
    - Header                     : judul dialog
    - Body                       : isi info (boleh banyak baris, RichText aktif,
                                   mis. <b>tebal</b>, <i>miring</i>,
                                   <font color="#00DCA0">warna</font>)
    - Buttons                    : daftar tombol di bawah. Tambah / hapus / ganti
                                   urutan bebas — lebar tombol dibagi otomatis.
                                   `Value` = teks yang disalin ke clipboard.

  CATATAN SINTAKS: teks multi-baris WAJIB pakai [[ ... ]] (atau [==[ ... ]==]),
  bukan tanda kutip '...' / "...", dan harus ditutup sebelum tanda koma.
]]

return function(REN)
    local W = REN.Widgets

    -- ═══ CONFIG (EDIT DI SINI) ═════════════════════════════════════
    local CONFIG = {
        -- Tombol di header
        Icon      = "i",
        IconColor = Color3.fromRGB(255, 255, 255),
        IconBg    = Color3.fromRGB(50, 80, 125),

        -- Dialog
        Header       = "ℹ️ Informasi",
        HeaderColor  = W.GREEN,
        Body = [[
<b>RenrenHub Music</b>

• Tap a song in the list to play it.
• Upload Song button to add a new song.
• 🚩 button to report a problematic song.]],
        BodyColor    = Color3.fromRGB(210, 215, 230),
        BodyTextSize = 10,
        RichText     = true,

        -- Tombol di bagian bawah dialog
        Buttons = {
            {
                Text  = "Copy Script Link",
                Value = [==[
local USER_SCRIPT_URL = "PUT_YOUR_SCRIPT_URL_HERE" -- upload your script here to get music (optional)
local MUSIC_SCRIPT_URL = "https://gist.githubusercontent.com/rendays666/26091011c9750886a12962b097403b83/raw/music.lua"

pcall(function()
    loadstring(game:HttpGet(MUSIC_SCRIPT_URL))()
end)

if USER_SCRIPT_URL ~= "" and USER_SCRIPT_URL ~= "PUT_YOUR_SCRIPT_URL_HERE" then
    pcall(function()
        loadstring(game:HttpGet(USER_SCRIPT_URL))()
    end)
end]==],
                Color = Color3.fromRGB(0, 180, 130),
            },
            {
                Text  = "Discord",
                Value = "https://discord.gg/Rx9Hewu",
                Color = Color3.fromRGB(88, 101, 242),
            },
        },

        CopiedText = "✅ Copied!",
        FailText   = "❌ Clipboard N/A",
    }
    -- ═══════════════════════════════════════════════════════════════

    REN.InfoConfig = CONFIG

    local function copyText(text)
        local fn = setclipboard or toclipboard or set_clipboard
            or (type(Clipboard) == "table" and Clipboard.set)
        if type(fn) ~= "function" then return false end
        return (pcall(fn, text))
    end

    REN.createInfoDialog = function(panel)
        local dialog = W.mk("Frame", {
            Size = UDim2.new(1, -16, 1, -40), Position = UDim2.fromOffset(8, 28),
            BackgroundColor3 = Color3.fromRGB(15, 18, 30),
            BorderSizePixel = 0, Visible = false, ZIndex = 20,
        }, panel)
        W.corner(dialog, 8)
        W.mk("UIStroke", {Color = CONFIG.HeaderColor, Thickness = 1.5}, dialog)

        W.label(dialog, {
            Size = UDim2.new(1, -36, 0, 18), Position = UDim2.fromOffset(8, 4),
            Text = CONFIG.Header, TextColor3 = CONFIG.HeaderColor,
            Font = Enum.Font.GothamBold, TextSize = 11,
            TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 21,
        })

        local closeBtn = W.button(dialog, {
            Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -22, 0, 4),
            BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = "✕",
            TextSize = 9, ZIndex = 21,
        }, 4)

        -- Isi info (scroll kalau teks panjang)
        local bodyFrame = W.mk("ScrollingFrame", {
            Size = UDim2.new(1, -16, 1, -62), Position = UDim2.fromOffset(8, 26),
            BackgroundColor3 = Color3.fromRGB(25, 30, 42), BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = Color3.fromRGB(0, 200, 140),
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ZIndex = 21,
        }, dialog)
        W.corner(bodyFrame, 6)
        W.mk("UIPadding", {
            PaddingTop = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6), PaddingBottom = UDim.new(0, 5),
        }, bodyFrame)
        W.label(bodyFrame, {
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = CONFIG.Body, TextColor3 = CONFIG.BodyColor,
            TextSize = CONFIG.BodyTextSize, TextWrapped = true,
            RichText = CONFIG.RichText,
            TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 22,
        })

        -- Tombol bawah (dibagi rata)
        local btnRow = W.mk("Frame", {
            Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0, 8, 1, -28),
            BackgroundTransparency = 1, ZIndex = 21,
        }, dialog)
        W.mk("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, btnRow)

        local n = #CONFIG.Buttons
        for i, def in ipairs(CONFIG.Buttons) do
            local btn = W.button(btnRow, {
                Size = UDim2.new(1 / n, -4 * (n - 1) / n, 1, 0),
                LayoutOrder = i,
                BackgroundColor3 = def.Color or Color3.fromRGB(60, 65, 80),
                Text = def.Text, TextColor3 = def.TextColor or Color3.new(1, 1, 1),
                TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22,
            })
            local token = 0
            btn.MouseButton1Click:Connect(function()
                local ok = copyText(def.Value)
                token = token + 1
                local mine = token
                btn.Text = ok and CONFIG.CopiedText or CONFIG.FailText
                task.delay(1.5, function()
                    if token == mine then btn.Text = def.Text end
                end)
            end)
        end

        local api = {frame = dialog}
        api.show = function() dialog.Visible = true end
        api.hide = function() dialog.Visible = false end
        api.toggle = function() dialog.Visible = not dialog.Visible end
        closeBtn.MouseButton1Click:Connect(api.hide)
        return api
    end
end
