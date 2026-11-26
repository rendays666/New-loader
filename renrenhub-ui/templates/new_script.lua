--[[
  TEMPLATE SCRIPT RENRENHUB
  Salin file ini sebagai awal setiap script baru. Jangan ubah gaya UI;
  tambah/hapus komponen saja. Aturan lengkap: ../AGENT.md, katalog: ../INDEX.md
]]

local UI = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/rendays666/New-loader/main/renrenhub-ui/lib/renrenhub_ui.lua"))()

-- ═══ CONFIG / STATE (nilai awal; ganti dengan hasil load config kalau ada) ═══
local opts = {
    AutoFarm  = false,
    Range     = 50,
    Speed     = 1.0,
    Mode      = "Normal",
    TargetName = "",
}

-- ═══ LOGIKA FITUR (tulis di sini / modul lain; UI hanya memanggil callback) ═══
local function onAutoFarm(on)
    -- start/stop loop di sini
end

-- ═══ UI ═══
local win = UI.createWindow({
    Name   = "RENRENHUB_Template",          -- unik per script
    Title  = "RENRENHUB • Template",
    Tabs   = { "Main", "Settings" },
    Icon   = "R",
    Status = true,
})

-- autosave: dipanggil setiap ada perubahan nilai
UI.changed = function()
    -- writefile("namaScript.json", game:GetService("HttpService"):JSONEncode(opts))
end

-- Tab Main
local main = win.Pages.Main
UI.section(main, "AUTOMATION")
UI.toggle(main, "Auto Farm", opts.AutoFarm, function(v)
    opts.AutoFarm = v
    onAutoFarm(v)
    win.SetStatus("Auto Farm " .. (v and "ON" or "OFF"))
end)
UI.number(main, "Range", opts.Range, 10, 200, 5, 0, function(v) opts.Range = v end)
UI.slider(main, "Speed", 0.5, 3, opts.Speed, function(v) opts.Speed = v end, 1)

UI.section(main, "ACTIONS")
UI.actionRow(main,
    { Text = "Start", Fn = function() win.SetStatus("Started") end },
    { Text = "Stop",  Fn = function() win.SetStatus("Stopped") end, Color = UI.T.Color.DangerDim })

-- Tab Settings
local set = win.Pages.Settings
UI.section(set, "OPTIONS")
UI.dropdown(set, "Mode", { "Normal", "Fast", "Safe" }, opts.Mode, function(v) opts.Mode = v end)
UI.textbox(set, "Target", "player name...", function(t) opts.TargetName = t end, opts.TargetName)
UI.info(set, "Geser ◢ di pojok kanan bawah untuk mengubah ukuran window.")
UI.action(set, "Test Toast", function() UI.toast(win.Gui, "Hello RENRENHUB") end)
