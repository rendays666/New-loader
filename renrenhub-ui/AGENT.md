# AGENT.md — aturan untuk AI

Folder ini adalah **database UI RENRENHUB**. Tujuannya: semua GUI script Renren
punya tampilan, ukuran, dan perilaku yang **sama**. AI tidak boleh mengarang
gaya UI sendiri.

## Kata kunci pemicu

| Pesan user memuat | Lakukan |
|---|---|
| **`PAKAI RENRENHUB-UI`** | Buat/ubah GUI script memakai kit di sini. Ikuti bagian "Membuat script baru". |
| **`SORT RENRENHUB-UI`** | Proses isi `inbox/`. Ikuti bagian "Menambah UI baru". |

## Urutan baca (wajib, jangan lompat)

1. `INDEX.md` — daftar komponen + cara pakai (cheat sheet API).
2. `DESIGN.md` — token warna/ukuran/font, anatomi window, aturan layout.
3. `templates/new_script.lua` — kerangka script. **Mulai dari sini, jangan dari nol.**
4. `lib/renrenhub_ui.lua` — hanya dibaca bila perlu detail implementasi.

## Membuat script baru

1. Salin `templates/new_script.lua`.
2. Muat kit lewat `loadstring(game:HttpGet(<raw URL lib/renrenhub_ui.lua>))()`.
   Jangan menyalin isi kit ke dalam script user kecuali user minta file tunggal offline.
3. Buat window dengan `UI.createWindow{...}`, isi page dengan komponen `UI.toggle`,
   `UI.number`, `UI.slider`, dst. Urutan pembuatan = urutan tampil.
4. Logika fitur (loop, hook, remote) ditulis terpisah dari kode UI. UI hanya
   memanggil callback.
5. Hubungkan autosave lewat `UI.changed = function() ... end` bila script punya config.

## Larangan keras

- **Jangan hardcode** `Color3.fromRGB(...)`, ukuran piksel, atau `Enum.Font` di script.
  Pakai `UI.T.Color / UI.T.Dim / UI.T.Font / UI.T.Size`.
- **Jangan** membuat `Instance.new("ScreenGui")` / window sendiri. Pakai `UI.createWindow`.
- **Jangan** menulis ulang fitur drag, resize, tombol tutup, atau logo toggle.
  Semuanya sudah ada di window kit (termasuk resize pojok kanan bawah).
- **Jangan** membuat tombol lebih kecil dari `UI.T.Dim.Row` (28px) untuk aksi utama.
  Pengguna sering di layar sentuh.
- **Jangan** mengubah `lib/renrenhub_ui.lua`, `DESIGN.md`, atau `INDEX.md` saat
  hanya diminta membuat script. Perubahan kit hanya lewat "Menambah UI baru".
- Jangan memanggil callback saat komponen dibuat (kit memang tidak melakukannya).

## Menambah UI baru (`SORT RENRENHUB-UI`)

User menaruh potongan UI (file `.lua`, snippet, atau screenshot + kode) di `inbox/`.

1. Baca semua file di `inbox/`.
2. Cek `INDEX.md`: apakah komponen serupa sudah ada? Kalau ya, **perluas** yang ada
   (parameter/opsi baru), jangan buat duplikat.
3. Ubah jadi komponen kit:
   - Warna/ukuran/font diganti ke token `UI.T`. Token baru hanya boleh ditambah
     bila benar-benar belum ada padanannya, dan harus dicatat di `DESIGN.md`.
   - Fungsi bernama `UI.namaKomponen(parent, ...)`, memakai `nextOrder(parent)`,
     mengembalikan tabel `{ Frame=..., Get=..., Set=... }` jika punya nilai.
   - Koneksi global (`UIS.InputChanged`, dll.) harus dilepas saat selesai
     (lihat `UI.slider`) agar tidak bocor.
4. Tambahkan ke `lib/renrenhub_ui.lua`, ke tabel di `INDEX.md`, dan contoh pakainya
   ke `templates/new_script.lua`.
5. Catat di `CHANGELOG.md` (naikkan versi minor, ubah `UI.VERSION` di lib).
6. Pindahkan file asli dari `inbox/` ke `inbox/done/` (jangan dihapus).
7. Laporkan ke user: komponen apa yang ditambah, dan apa yang diubah dari aslinya.

## Checklist sebelum menyerahkan script

- [ ] Memakai `UI.createWindow`, tidak ada `ScreenGui` buatan sendiri
- [ ] Tidak ada `Color3.fromRGB` / angka ukuran / `Enum.Font` di kode script
- [ ] Setiap toggle/number/slider punya callback yang benar dan nilai awal dari config
- [ ] `Name` window unik per script (mencegah GUI dobel saat execute ulang)
- [ ] Teks UI satu bahasa (default: Inggris untuk label, Indonesia untuk pesan bantuan)
- [ ] Diuji / dinyatakan jujur belum diuji di executor
