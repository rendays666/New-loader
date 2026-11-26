# renrenhub-ui — database UI RENRENHUB

Satu tempat untuk semua tampilan GUI. Tujuannya: setiap script baru yang dibuat AI
**memakai UI yang sama** — warna, ukuran, tombol, window, resize — tanpa dikarang ulang.

## Cara pakai

**Membuat script baru:** kirim ke AI

> `PAKAI RENRENHUB-UI` + link folder ini + apa yang mau dibuat

AI akan membaca `AGENT.md`, `INDEX.md`, `DESIGN.md`, lalu mulai dari `templates/new_script.lua`.

**Menambah UI baru ke database:** taruh filenya di `inbox/`, lalu kirim ke AI

> `SORT RENRENHUB-UI` + link repo

## Isi folder

| Path | Isi |
|---|---|
| `AGENT.md` | aturan untuk AI (urutan baca, larangan, prosedur tambah UI, checklist) |
| `INDEX.md` | katalog komponen + cheat sheet API |
| `DESIGN.md` | token warna/ukuran/font, anatomi window, aturan layout |
| `lib/renrenhub_ui.lua` | kit-nya (satu file, siap `loadstring`) |
| `templates/new_script.lua` | kerangka script baru, contoh semua komponen |
| `inbox/` | tempat menaruh UI baru yang mau dimasukkan |
| `CHANGELOG.md` | riwayat versi |

## Muat kit di script

```lua
local UI = loadstring(game:HttpGet(
  "https://raw.githubusercontent.com/rendays666/New-loader/main/renrenhub-ui/lib/renrenhub_ui.lua"))()
```

## Fitur window bawaan

Drag lewat title bar · resize lewat ◢ pojok kanan bawah · tab · status bar ·
logo bulat tampil/sembunyi · tombol ✕ dengan konfirmasi · execute ulang tidak membuat GUI dobel.
