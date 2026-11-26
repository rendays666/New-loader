# INDEX — katalog komponen RENRENHUB UI

Kit: `lib/renrenhub_ui.lua` (v1.0.0). Semua fungsi di bawah dipanggil lewat `UI.xxx`.
`parent` = page milik window (mis. `win.Pages.Combat`).

## Memuat kit

```lua
local UI = loadstring(game:HttpGet(
  "https://raw.githubusercontent.com/rendays666/New-loader/main/renrenhub-ui/lib/renrenhub_ui.lua"))()
```

## Window

| Fungsi | Keterangan |
|---|---|
| `UI.createWindow(opts)` | Window lengkap: title bar (drag), tab, status bar, **handle resize ◢ kanan bawah**, tombol ✕ + konfirmasi, logo bulat untuk buka/tutup. Return `win`. |

`opts`: `Name`, `Title`, `Tabs` (list nama), `TabColumns` (default 3), `Size` (Vector2),
`MinSize`, `Position` (UDim2), `Icon` (teks logo), `IconPos`, `Status` (bool),
`Resizable` (default true), `CloseConfirm` (default true), `CloseMessage`,
`DisplayOrder`, `OnClose`.

`win`: `Gui`, `Main`, `Header`, `Content`, `Pages[nama]`, `TabButtons`, `Icon`, `Handle`,
`SwitchTab(nama)`, `SetStatus(teks)`, `SetVisible(bool)`, `Toggle()`, `Destroy()`.

## Komponen (isi page)

| Fungsi | Tampilan | Return |
|---|---|---|
| `UI.section(parent, text)` | judul bagian, teks hijau | Label |
| `UI.info(parent, text, color?)` | teks keterangan, wrap otomatis | Label |
| `UI.action(parent, text, fn, color?)` | tombol satu baris penuh | Button |
| `UI.actionRow(parent, {Text,Fn,Color?}, {Text,Fn,Color?})` | dua tombol sebaris | `{Frame,A,B}` |
| `UI.toggle(parent, text, initial, cb(bool))` | tombol `Nama  [ON/OFF]` | `{Frame,Get,Set}` |
| `UI.number(parent, label, initial, min, max, step, decimals, cb(v))` | stepper `[−] nilai [+]`, tahan untuk ulang | `{Frame,Get,Set}` |
| `UI.slider(parent, label, min, max, initial, cb(v), decimals?, step?)` | slider geser | `{Frame,Get,Set}` |
| `UI.dropdown(parent, label, options, initial, cb(opt))` | ketuk = opsi berikutnya | `{Frame,Get,Set}` |
| `UI.textbox(parent, label, placeholder, cb(text), initial?)` | kotak input teks | `{Frame,Box,Get,Set}` |

`Set(v)` hanya mengubah tampilan, **tidak** memanggil callback (aman untuk memuat config).

## Overlay

| Fungsi | Keterangan |
|---|---|
| `UI.confirm(gui, {Title,Message,YesText,NoText,YesColor,OnYes,OnNo})` | dialog konfirmasi tengah layar |
| `UI.toast(gui, text, color?, seconds?)` | notifikasi singkat bawah-tengah |

`gui` = `win.Gui`.

## Helper dasar (untuk komponen baru)

`UI.mk(class, props, parent)`, `UI.corner(o, r)`, `UI.stroke(o, color, th)`,
`UI.pad(o, l, t, r, b)`, `UI.button(parent, props, radius)`, `UI.label(parent, props)`,
`UI.input(parent, props)`, `UI.nextOrder(parent)`.

## Hook global

`UI.changed = function() ... end` — dipanggil setiap toggle/number/slider/dropdown/textbox
berubah. Pakai untuk autosave config.

## Belum ada di kit (kandidat, taruh contohnya di `inbox/`)

| Komponen | Referensi yang sudah ada |
|---|---|
| Daftar dengan pencarian + paging + baris klik | `music_modules/ui/rows.lua` (GUI music) |
| Dialog input + status (upload/report) | `music_modules/ui/dialogs.lua` |
| Dialog informasi dengan tombol salin | `music_modules/ui/info.lua` |
| Chip ID yang bisa disalin | `music_modules/ui/rows.lua` |
| Panel log yang bisa disalin | `music_modules/logger.lua` |

## Riwayat sumber

Palet dan ukuran diambil dari dua GUI yang sudah ada: **GUI music** (`music_modules/ui/`)
dan **GUI Centaura** (`rendays666/centaura`, `ui_window.lua`, `ui_widgets*.lua`, `ui_number.lua`).
