--[[
  RENRENHUB UI KIT v1.0.0
  Satu file, siap loadstring. Semua GUI RENRENHUB WAJIB memakai kit ini
  supaya tampilan konsisten (lihat ../DESIGN.md dan ../INDEX.md).

  Pakai:
    local UI = loadstring(game:HttpGet(
      "https://raw.githubusercontent.com/rendays666/New-loader/main/renrenhub-ui/lib/renrenhub_ui.lua"))()

  Aturan singkat:
    - Jangan hardcode warna / ukuran / font di script. Ambil dari UI.T.
    - Komponen dibuat dengan UI.xxx(parent, ...) dan otomatis tersusun
      (LayoutOrder otomatis) di dalam page milik window.
    - Callback TIDAK dipanggil saat komponen dibuat; panggil sendiri kalau perlu.
    - UI.changed (opsional) dipanggil setiap ada perubahan nilai -> cocok untuk autosave.
]]

local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local UI = {}
UI.VERSION = "1.0.0"
UI.changed = nil   -- function() dipanggil setelah toggle/number/slider/dropdown/textbox berubah

-- ═══ TOKENS (satu-satunya sumber warna/ukuran/font) ═══════════════════
UI.T = {
    Color = {
        Accent    = Color3.fromRGB(0, 220, 160),   -- hijau khas RENRENHUB (stroke, judul, section)
        AccentBtn = Color3.fromRGB(0, 160, 120),   -- tombol/toggle ON, tab aktif
        Bg        = Color3.fromRGB(20, 24, 38),    -- panel utama
        BgHeader  = Color3.fromRGB(25, 25, 38),    -- title bar
        BgDeep    = Color3.fromRGB(10, 10, 15),    -- status bar, area gelap
        BgRow     = Color3.fromRGB(32, 38, 52),    -- baris list
        BgItem    = Color3.fromRGB(40, 40, 58),    -- tombol netral / toggle OFF / tab nonaktif
        BgInput   = Color3.fromRGB(35, 40, 55),    -- textbox, kotak nilai
        Text      = Color3.fromRGB(220, 220, 240),
        TextSub   = Color3.fromRGB(130, 140, 165), -- keterangan kecil
        TextDim   = Color3.fromRGB(160, 160, 180), -- non-aktif
        TextOn    = Color3.new(1, 1, 1),           -- teks di atas tombol berwarna
        Link      = Color3.fromRGB(140, 195, 255), -- ID, link
        Danger    = Color3.fromRGB(200, 60, 60),
        DangerDim = Color3.fromRGB(140, 40, 40),
        Success   = Color3.fromRGB(30, 140, 50),
        Info      = Color3.fromRGB(50, 80, 125),
        Warn      = Color3.fromRGB(200, 150, 50),
    },
    Font = {
        Regular  = Enum.Font.Gotham,
        Semibold = Enum.Font.GothamSemibold,
        Bold     = Enum.Font.GothamBold,
        Mono     = Enum.Font.Code,
    },
    Size = { Caption = 8, Small = 9, Body = 10, Label = 11, Title = 12, Big = 16 },
    Radius = { Panel = 8, Button = 4, Small = 3 },
    Dim = {
        Title = 24,    -- tinggi title bar
        Row = 28,      -- tinggi tombol/toggle (target sentuh minimum)
        RowTall = 32,  -- baris dengan stepper
        Tab = 20,      -- tinggi tombol tab
        Status = 36,   -- tinggi status bar
        Icon = 34,     -- logo bulat pembuka window
        Handle = 22,   -- handle resize
        Gap = 3,       -- jarak antar komponen
    },
}

local T = UI.T
local C, D, F, S = T.Color, T.Dim, T.Font, T.Size

-- ═══ HELPER DASAR ═════════════════════════════════════════════════════
function UI.mk(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end
local mk = UI.mk

function UI.corner(o, r)
    return mk("UICorner", { CornerRadius = UDim.new(0, r or T.Radius.Button) }, o)
end

function UI.stroke(o, color, thickness)
    return mk("UIStroke", { Color = color or C.Accent, Thickness = thickness or 1.5 }, o)
end

function UI.pad(o, l, t, r, b)
    return mk("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or 0), PaddingBottom = UDim.new(0, b or 0),
    }, o)
end

function UI.button(parent, props, radius)
    props = props or {}
    props.BackgroundColor3 = props.BackgroundColor3 or C.BgItem
    props.TextColor3       = props.TextColor3 or C.Text
    props.Font             = props.Font or F.Semibold
    props.TextSize         = props.TextSize or S.Label
    props.BorderSizePixel  = 0
    props.AutoButtonColor  = false
    local b = mk("TextButton", props, parent)
    UI.corner(b, radius or T.Radius.Button)
    return b
end

function UI.label(parent, props)
    props = props or {}
    if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
    props.Font           = props.Font or F.Regular
    props.TextSize       = props.TextSize or S.Body
    props.TextColor3     = props.TextColor3 or C.Text
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    return mk("TextLabel", props, parent)
end

function UI.input(parent, props)
    props = props or {}
    props.BorderSizePixel   = 0
    props.BackgroundColor3  = props.BackgroundColor3 or C.BgInput
    props.PlaceholderColor3 = Color3.fromRGB(140, 145, 165)
    props.TextColor3        = C.Text
    props.Font              = F.Regular
    props.TextSize          = props.TextSize or S.Body
    props.TextXAlignment    = Enum.TextXAlignment.Left
    props.ClearTextOnFocus  = false
    props.Text              = props.Text or ""
    local b = mk("TextBox", props, parent)
    UI.corner(b, T.Radius.Button)
    UI.pad(b, 6, 0)
    return b
end

-- LayoutOrder otomatis per parent (komponen tersusun sesuai urutan dibuat)
local orders = setmetatable({}, { __mode = "k" })
local function nextOrder(parent)
    orders[parent] = (orders[parent] or 0) + 1
    return orders[parent]
end
UI.nextOrder = nextOrder

local function fire()
    if UI.changed then pcall(UI.changed) end
end

local function isPress(i)
    return i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch
end
local function isMove(i)
    return i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch
end

local function rowFrame(parent, h)
    return mk("Frame", {
        Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1,
        LayoutOrder = nextOrder(parent),
    }, parent)
end

local function fmtNumber(v, decimals)
    if decimals and decimals > 0 then return string.format("%." .. decimals .. "f", v) end
    return tostring(math.floor(v + 0.5))
end

-- ═══ KOMPONEN ═════════════════════════════════════════════════════════

-- Judul bagian (teks hijau kecil)
function UI.section(parent, text)
    return UI.label(parent, {
        Size = UDim2.new(1, 0, 0, 16), Text = text,
        TextColor3 = C.Accent, Font = F.Bold, LayoutOrder = nextOrder(parent),
    })
end

-- Teks keterangan (otomatis tinggi sesuai isi)
function UI.info(parent, text, color)
    return UI.label(parent, {
        Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y,
        Text = text, TextColor3 = color or C.TextSub, TextSize = S.Small,
        TextWrapped = true, LayoutOrder = nextOrder(parent),
    })
end

-- Tombol aksi satu baris penuh. color opsional (default netral).
function UI.action(parent, text, callback, color)
    local b = UI.button(parent, {
        Size = UDim2.new(1, 0, 0, D.Row), Text = text,
        BackgroundColor3 = color or C.BgItem, LayoutOrder = nextOrder(parent),
    })
    if callback then b.Activated:Connect(callback) end
    return b
end

-- Dua tombol sebaris. a/b = { Text=, Fn=, Color= }
function UI.actionRow(parent, a, b)
    local row = rowFrame(parent, D.Row)
    local function make(spec, xScale, xOff)
        local btn = UI.button(row, {
            Size = UDim2.new(0.5, -2, 1, 0), Position = UDim2.new(xScale, xOff, 0, 0),
            Text = spec.Text, BackgroundColor3 = spec.Color or C.BgItem,
        })
        if spec.Fn then btn.Activated:Connect(spec.Fn) end
        return btn
    end
    return { Frame = row, A = make(a, 0, 0), B = make(b, 0.5, 2) }
end

-- Toggle ON/OFF. Return { Frame, Get(), Set(v) }  (Set hanya mengubah tampilan, tanpa callback)
function UI.toggle(parent, text, initial, callback)
    local state = initial and true or false
    local b = UI.button(parent, {
        Size = UDim2.new(1, 0, 0, D.Row), LayoutOrder = nextOrder(parent),
    })
    local obj = { Frame = b }
    local function paint()
        b.BackgroundColor3 = state and C.AccentBtn or C.BgItem
        b.Text = text .. "  [" .. (state and "ON" or "OFF") .. "]"
    end
    function obj.Get() return state end
    function obj.Set(v) state = v and true or false; paint() end
    b.Activated:Connect(function()
        state = not state
        paint()
        if callback then callback(state) end
        fire()
    end)
    paint()
    return obj
end

-- Stepper angka [-] nilai [+] dengan tahan-untuk-ulang. Return { Frame, Get(), Set(v) }
function UI.number(parent, label, initial, minV, maxV, stepV, decimals, callback)
    decimals = decimals or 0
    stepV = stepV or 1
    local row = rowFrame(parent, D.RowTall)
    UI.label(row, {
        Size = UDim2.new(1, -148, 0, 28), Position = UDim2.fromOffset(0, 2),
        Text = label, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local minus = UI.button(row, {
        Size = UDim2.fromOffset(30, 28), Position = UDim2.new(1, -142, 0, 2),
        BackgroundColor3 = C.DangerDim, Text = "−", TextSize = 20, Font = F.Bold,
        TextColor3 = C.TextOn,
    })
    local valLbl = UI.label(row, {
        Size = UDim2.fromOffset(74, 28), Position = UDim2.new(1, -108, 0, 2),
        BackgroundTransparency = 0, BackgroundColor3 = C.BgInput,
        TextXAlignment = Enum.TextXAlignment.Center, Font = F.Bold, TextSize = 13,
        TextColor3 = C.TextOn,
    })
    UI.corner(valLbl, T.Radius.Button)
    local plus = UI.button(row, {
        Size = UDim2.fromOffset(30, 28), Position = UDim2.new(1, -30, 0, 2),
        BackgroundColor3 = C.Success, Text = "+", TextSize = 18, Font = F.Bold,
        TextColor3 = C.TextOn,
    })

    local cur = math.clamp(initial or minV, minV, maxV)
    valLbl.Text = fmtNumber(cur, decimals)
    local function setVal(v, silent)
        v = math.clamp(v, minV, maxV)
        v = math.floor(v / stepV + 0.5) * stepV
        v = math.clamp(v, minV, maxV)
        cur = v
        valLbl.Text = fmtNumber(cur, decimals)
        if not silent then
            if callback then callback(cur) end
            fire()
        end
    end

    local holdToken = 0
    local function bindHold(btn, dir)
        btn.InputBegan:Connect(function(i)
            if not isPress(i) then return end
            setVal(cur + dir * stepV)
            holdToken = holdToken + 1
            local my = holdToken
            task.spawn(function()
                task.wait(0.4)
                while holdToken == my do
                    setVal(cur + dir * stepV)
                    task.wait(0.06)
                end
            end)
        end)
        btn.InputEnded:Connect(function(i)
            if isPress(i) then holdToken = holdToken + 1 end
        end)
    end
    bindHold(minus, -1)
    bindHold(plus, 1)

    return {
        Frame = row,
        Get = function() return cur end,
        Set = function(v) setVal(v, true) end,
    }
end

-- Slider geser. Return { Frame, Get(), Set(v) }
function UI.slider(parent, label, minV, maxV, initial, callback, decimals, stepV)
    decimals = decimals or 0
    stepV = stepV or (decimals > 0 and 10 ^ -decimals or 1)
    local row = rowFrame(parent, 38)
    UI.label(row, {
        Size = UDim2.new(1, -60, 0, 16), Text = label, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local valLbl = UI.label(row, {
        Size = UDim2.fromOffset(56, 16), Position = UDim2.new(1, -56, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Font = F.Bold, TextColor3 = C.Accent,
    })
    local hit = mk("TextButton", {   -- area sentuh besar, track tipis di tengah
        Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 17),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, row)
    local track = mk("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3),
        BackgroundColor3 = C.BgInput, BorderSizePixel = 0,
    }, hit)
    UI.corner(track, 3)
    local fill = mk("Frame", {
        Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = C.AccentBtn, BorderSizePixel = 0,
    }, track)
    UI.corner(fill, 3)
    local thumb = mk("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.Accent, BorderSizePixel = 0,
    }, track)
    UI.corner(thumb, 7)

    local cur = math.clamp(initial or minV, minV, maxV)
    local function paint()
        local a = (maxV > minV) and (cur - minV) / (maxV - minV) or 0
        fill.Size = UDim2.new(a, 0, 1, 0)
        thumb.Position = UDim2.new(a, 0, 0.5, 0)
        valLbl.Text = fmtNumber(cur, decimals)
    end
    local function setVal(v, silent)
        v = math.clamp(v, minV, maxV)
        v = math.floor((v - minV) / stepV + 0.5) * stepV + minV
        v = math.clamp(v, minV, maxV)
        if v == cur and not silent then return end
        cur = v
        paint()
        if not silent then
            if callback then callback(cur) end
            fire()
        end
    end
    local function fromInput(i)
        local w = track.AbsoluteSize.X
        if w <= 0 then return end
        setVal(minV + math.clamp((i.Position.X - track.AbsolutePosition.X) / w, 0, 1) * (maxV - minV))
    end

    hit.InputBegan:Connect(function(i)
        if not isPress(i) then return end
        local scroller = parent:IsA("ScrollingFrame") and parent or nil
        if scroller then scroller.ScrollingEnabled = false end   -- cegah scroll saat geser
        fromInput(i)
        local c1, c2
        c1 = UIS.InputChanged:Connect(function(m)
            if isMove(m) then fromInput(m) end
        end)
        c2 = UIS.InputEnded:Connect(function(e)
            if isPress(e) then
                c1:Disconnect(); c2:Disconnect()
                if scroller then scroller.ScrollingEnabled = true end
            end
        end)
    end)

    paint()
    return {
        Frame = row,
        Get = function() return cur end,
        Set = function(v) setVal(v, true) end,
    }
end

-- Dropdown siklus: ketuk = pilihan berikutnya. Return { Frame, Get(), Set(v) }
function UI.dropdown(parent, label, options, initial, callback)
    local row = rowFrame(parent, 30)
    UI.label(row, {
        Size = UDim2.new(0.42, 0, 1, 0), Text = label, TextSize = S.Label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local btn = UI.button(row, {
        Size = UDim2.new(0.56, 0, 0, 26), Position = UDim2.new(0.44, 0, 0, 2),
        BackgroundColor3 = C.Info, Text = tostring(initial), Font = F.Bold,
        TextColor3 = C.TextOn,
    })
    local idx = 1
    for i, v in ipairs(options) do
        if v == initial then idx = i; break end
    end
    btn.Text = tostring(options[idx])
    btn.Activated:Connect(function()
        idx = idx % #options + 1
        btn.Text = tostring(options[idx])
        if callback then callback(options[idx]) end
        fire()
    end)
    return {
        Frame = row,
        Get = function() return options[idx] end,
        Set = function(v)
            for i, o in ipairs(options) do
                if o == v then idx = i; btn.Text = tostring(o); return end
            end
        end,
    }
end

-- Kotak teks. callback(text) dipanggil saat Enter / fokus hilang.
function UI.textbox(parent, label, placeholder, callback, initial)
    local row = rowFrame(parent, 30)
    UI.label(row, {
        Size = UDim2.new(0.42, 0, 1, 0), Text = label, TextSize = S.Label,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local box = UI.input(row, {
        Size = UDim2.new(0.56, 0, 0, 26), Position = UDim2.new(0.44, 0, 0, 2),
        PlaceholderText = placeholder or "", Text = initial or "",
    })
    box.FocusLost:Connect(function()
        if callback then callback(box.Text) end
        fire()
    end)
    return { Frame = row, Box = box, Get = function() return box.Text end,
             Set = function(v) box.Text = tostring(v) end }
end

-- Dialog konfirmasi di tengah layar. opts: Title, Message, YesText, NoText, YesColor, OnYes, OnNo
function UI.confirm(gui, opts)
    opts = opts or {}
    local dlg = mk("Frame", {
        Size = UDim2.fromOffset(250, 108), Position = UDim2.new(0.5, -125, 0.5, -54),
        BackgroundColor3 = C.Bg, BorderSizePixel = 0, ZIndex = 400,
    }, gui)
    UI.corner(dlg, 10)
    UI.stroke(dlg, C.Danger, 1.5)
    UI.label(dlg, {
        Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 6),
        Text = opts.Title or "Konfirmasi", Font = F.Bold, TextSize = S.Title, ZIndex = 401,
    })
    UI.label(dlg, {
        Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 30),
        Text = opts.Message or "", TextColor3 = C.TextSub, TextSize = S.Small,
        TextWrapped = true, ZIndex = 401,
    })
    local yes = UI.button(dlg, {
        Size = UDim2.fromOffset(96, 24), Position = UDim2.new(0, 12, 1, -32),
        BackgroundColor3 = opts.YesColor or C.Danger, Text = opts.YesText or "Ya",
        TextColor3 = C.TextOn, TextSize = S.Small, ZIndex = 401,
    }, 6)
    local no = UI.button(dlg, {
        Size = UDim2.fromOffset(96, 24), Position = UDim2.new(1, -108, 1, -32),
        BackgroundColor3 = Color3.fromRGB(60, 65, 80), Text = opts.NoText or "Batal",
        TextSize = S.Small, ZIndex = 401,
    }, 6)
    yes.Activated:Connect(function()
        dlg:Destroy()
        if opts.OnYes then opts.OnYes() end
    end)
    no.Activated:Connect(function()
        dlg:Destroy()
        if opts.OnNo then opts.OnNo() end
    end)
    return dlg
end

-- Notifikasi singkat di bawah tengah layar
function UI.toast(gui, text, color, seconds)
    local t = UI.label(gui, {
        Size = UDim2.fromOffset(220, 24), AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -24), BackgroundTransparency = 0,
        BackgroundColor3 = C.BgHeader, Text = tostring(text), TextColor3 = color or C.Accent,
        TextXAlignment = Enum.TextXAlignment.Center, Font = F.Bold, TextSize = S.Body,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 500,
    })
    UI.corner(t, 12)
    UI.stroke(t, color or C.Accent, 1)
    task.delay(seconds or 2, function()
        if not t.Parent then return end
        local tw = TweenService:Create(t, TweenInfo.new(0.25), { BackgroundTransparency = 1, TextTransparency = 1 })
        tw:Play()
        tw.Completed:Wait()
        t:Destroy()
    end)
    return t
end

-- ═══ WINDOW ═══════════════════════════════════════════════════════════
--[[
  UI.createWindow{
    Name        = "RENRENHUB_X"      -- nama ScreenGui (unik per script)
    Title       = "RENRENHUB • X"
    Tabs        = {"Combat","Aim"}   -- opsional; tanpa Tabs -> satu page "Main"
    TabColumns  = 3                  -- tab per baris
    Size        = Vector2.new(240,320), MinSize = Vector2.new(200,220)
    Position    = UDim2 (default kanan atas)
    Icon        = "R"                -- teks logo bulat; IconPos = UDim2
    Status      = true               -- tampilkan status bar bawah
    CloseConfirm= true, CloseMessage = "..."
    DisplayOrder= 999
    OnClose     = function() end     -- dipanggil sebelum window dihancurkan
  }
  Return: { Gui, Main, Header, Content, Pages, TabButtons, SwitchTab(name),
            SetStatus(text), SetVisible(bool), Toggle(), Destroy(), Icon, Handle }
]]
function UI.createWindow(opts)
    opts = opts or {}
    local name = opts.Name or "RENRENHUB_UI"
    local lp = Players.LocalPlayer
    local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 10)

    -- bersihkan instance lama (execute ulang) termasuk koneksi global-nya
    local env = (getgenv and getgenv()) or _G
    env.__RENREN_UI_CLEANUP = env.__RENREN_UI_CLEANUP or {}
    if env.__RENREN_UI_CLEANUP[name] then pcall(env.__RENREN_UI_CLEANUP[name]) end
    local old = pg:FindFirstChild(name)
    if old then old:Destroy() end

    local size    = opts.Size or Vector2.new(240, 320)
    local minSize = opts.MinSize or Vector2.new(200, 220)
    local conns = {}
    local function track(c) conns[#conns + 1] = c; return c end
    local function viewport()
        local cam = workspace.CurrentCamera
        return cam and cam.ViewportSize or Vector2.new(800, 600)
    end

    local gui = mk("ScreenGui", {
        Name = name, ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = opts.DisplayOrder or 999,
    }, pg)

    local main = mk("Frame", {
        Size = UDim2.fromOffset(size.X, size.Y),
        Position = opts.Position or UDim2.new(1, -size.X - 5, 0, 60),
        BackgroundColor3 = C.Bg, BackgroundTransparency = 0.05,
        BorderSizePixel = 0, Active = true,
    }, gui)
    UI.corner(main, T.Radius.Panel)
    UI.stroke(main, C.Accent, 1.5)

    -- header
    local header = mk("Frame", {
        Size = UDim2.new(1, 0, 0, D.Title), BackgroundColor3 = C.BgHeader,
        BorderSizePixel = 0, Active = true,
    }, main)
    UI.corner(header, T.Radius.Panel)
    UI.label(header, {
        Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(8, 0),
        Text = opts.Title or "RENRENHUB", TextColor3 = C.Accent, Font = F.Bold,
        TextSize = S.Title, TextTruncate = Enum.TextTruncate.AtEnd,
    })
    local closeBtn = UI.button(header, {
        Size = UDim2.fromOffset(20, 16), Position = UDim2.new(1, -24, 0, 4),
        BackgroundColor3 = C.Danger, Text = "✕", TextColor3 = C.TextOn, TextSize = S.Body,
    })

    -- tab bar
    local tabNames = opts.Tabs
    local hasTabs = type(tabNames) == "table" and #tabNames > 0
    if not hasTabs then tabNames = { "Main" } end
    local cols = opts.TabColumns or 3
    local tabH = 0
    local tabButtons = {}
    local tabBar
    if hasTabs then
        local rows = math.ceil(#tabNames / cols)
        tabH = rows * (D.Tab + 2)
        tabBar = mk("Frame", {
            Size = UDim2.new(1, -6, 0, tabH), Position = UDim2.new(0, 3, 0, D.Title),
            BackgroundTransparency = 1,
        }, main)
        mk("UIGridLayout", {
            CellSize = UDim2.new(1 / cols, -2, 0, D.Tab), CellPadding = UDim2.fromOffset(2, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, tabBar)
    end

    -- status bar
    local statusH = opts.Status and D.Status or 0
    local statusLbl
    if opts.Status then
        local bar = mk("Frame", {
            Size = UDim2.new(1, -6, 0, D.Status), Position = UDim2.new(0, 3, 1, -D.Status - 2),
            BackgroundColor3 = C.BgDeep, BorderSizePixel = 0,
        }, main)
        UI.corner(bar, T.Radius.Button)
        statusLbl = UI.label(bar, {
            Size = UDim2.new(1, -8, 1, -4), Position = UDim2.fromOffset(4, 2),
            Text = "Ready", TextColor3 = Color3.fromRGB(140, 220, 190), TextSize = S.Small,
            Font = F.Mono, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
        })
    end

    -- content + pages (tinggi mengikuti window -> aman untuk resize)
    local contentY = D.Title + tabH + 2
    local bottom = (statusH > 0) and (statusH + 4) or 4
    local content = mk("Frame", {
        Size = UDim2.new(1, -6, 1, -(contentY + bottom)), Position = UDim2.new(0, 3, 0, contentY),
        BackgroundTransparency = 1, ClipsDescendants = true,
    }, main)

    local pages = {}
    for i, n in ipairs(tabNames) do
        local sf = mk("ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(0, 180, 140),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, Visible = false,
        }, content)
        mk("UIListLayout", { Padding = UDim.new(0, D.Gap), SortOrder = Enum.SortOrder.LayoutOrder }, sf)
        UI.pad(sf, 0, 2, 0, 6)
        pages[n] = sf
        if hasTabs then
            tabButtons[n] = UI.button(tabBar, { Text = n, TextSize = S.Label, Font = F.Bold, LayoutOrder = i }, 3)
        end
    end

    local function switchTab(n)
        for k, p in pairs(pages) do p.Visible = (k == n) end
        for k, b in pairs(tabButtons) do
            b.BackgroundColor3 = (k == n) and C.AccentBtn or C.BgItem
        end
    end
    for n, b in pairs(tabButtons) do
        b.Activated:Connect(function() switchTab(n) end)
    end
    switchTab(tabNames[1])

    -- resize handle (pojok kanan bawah)
    local handle = mk("TextButton", {
        Size = UDim2.fromOffset(D.Handle, D.Handle), Position = UDim2.new(1, -D.Handle, 1, -D.Handle),
        BackgroundTransparency = 1, Text = "◢", TextColor3 = C.Accent, TextSize = 16,
        Font = F.Bold, BorderSizePixel = 0, AutoButtonColor = false, ZIndex = 50,
    }, main)
    handle.Visible = opts.Resizable ~= false

    -- logo bulat (buka/tutup window, bisa digeser)
    local icon = mk("TextButton", {
        Size = UDim2.fromOffset(D.Icon, D.Icon), Position = opts.IconPos or UDim2.new(0, 12, 0.5, -D.Icon / 2),
        BackgroundColor3 = C.AccentBtn, Text = opts.Icon or "R", TextColor3 = C.TextOn,
        TextSize = S.Big, Font = Enum.Font.GothamBlack, BorderSizePixel = 0, AutoButtonColor = false,
    }, gui)
    UI.corner(icon, 1000)
    UI.stroke(icon, Color3.fromRGB(0, 255, 200), 1.5)

    -- satu pasang koneksi global untuk semua drag (move / resize / icon)
    local drag
    track(header.InputBegan:Connect(function(i)
        if isPress(i) then
            drag = { mode = "move", start = i.Position, abs = main.AbsolutePosition }
        end
    end))
    track(handle.InputBegan:Connect(function(i)
        if isPress(i) then
            drag = { mode = "resize", start = i.Position, size = main.AbsoluteSize }
        end
    end))
    track(icon.InputBegan:Connect(function(i)
        if isPress(i) then
            drag = { mode = "icon", start = i.Position, abs = icon.AbsolutePosition, moved = false }
        end
    end))

    track(UIS.InputChanged:Connect(function(i)
        if not drag or not isMove(i) then return end
        local dd = i.Position - drag.start
        local vp = viewport()
        if drag.mode == "move" then
            local w = main.AbsoluteSize.X
            local x = math.clamp(drag.abs.X + dd.X, 60 - w, vp.X - 60)   -- header selalu tersisa di layar
            local y = math.clamp(drag.abs.Y + dd.Y, 0, vp.Y - D.Title)
            main.Position = UDim2.fromOffset(x, y)
        elseif drag.mode == "resize" then
            local ap = main.AbsolutePosition
            local maxW = math.max(minSize.X, vp.X - ap.X - 2)
            local maxH = math.max(minSize.Y, vp.Y - ap.Y - 2)
            main.Size = UDim2.fromOffset(
                math.clamp(drag.size.X + dd.X, minSize.X, maxW),
                math.clamp(drag.size.Y + dd.Y, minSize.Y, maxH)
            )
        elseif drag.mode == "icon" then
            if math.abs(dd.X) > 6 or math.abs(dd.Y) > 6 then drag.moved = true end
            if drag.moved then
                local x = math.clamp(drag.abs.X + dd.X, 0, math.max(0, vp.X - D.Icon))
                local y = math.clamp(drag.abs.Y + dd.Y, 0, math.max(0, vp.Y - D.Icon))
                icon.Position = UDim2.fromOffset(x, y)
            end
        end
    end))

    local win = {}
    local function setVisible(v)
        main.Visible = v and true or false
        icon.BackgroundColor3 = main.Visible and C.AccentBtn or Color3.fromRGB(120, 120, 130)
    end

    track(UIS.InputEnded:Connect(function(i)
        if not drag or not isPress(i) then return end
        if drag.mode == "icon" and not drag.moved then setVisible(not main.Visible) end
        drag = nil
    end))

    function win.Destroy()
        if env.__RENREN_UI_CLEANUP[name] == win.Destroy then env.__RENREN_UI_CLEANUP[name] = nil end
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        conns = {}
        if gui and gui.Parent then gui:Destroy() end
    end
    env.__RENREN_UI_CLEANUP[name] = win.Destroy

    closeBtn.Activated:Connect(function()
        local function close()
            if opts.OnClose then pcall(opts.OnClose) end
            win.Destroy()
        end
        if opts.CloseConfirm == false then close() return end
        UI.confirm(gui, {
            Title = "Tutup " .. (opts.Title or "RENRENHUB") .. "?",
            Message = opts.CloseMessage or "Window akan ditutup. Jalankan ulang script untuk membukanya lagi.",
            YesText = "Ya, tutup", OnYes = close,
        })
    end)

    win.Gui, win.Main, win.Header, win.Content = gui, main, header, content
    win.Pages, win.TabButtons, win.Icon, win.Handle = pages, tabButtons, icon, handle
    win.SwitchTab = switchTab
    win.SetVisible = setVisible
    win.Toggle = function() setVisible(not main.Visible) end
    win.SetStatus = function(text)
        if statusLbl then statusLbl.Text = tostring(text) end
    end
    return win
end

return UI
