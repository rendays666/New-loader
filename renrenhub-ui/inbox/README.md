# inbox — tempat menaruh UI baru

Taruh di sini potongan UI yang mau dimasukkan ke database (file `.lua`, snippet,
atau catatan + kode). Lalu kirim ke AI:

> `SORT RENRENHUB-UI` + link repo

AI akan membaca `../AGENT.md` bagian "Menambah UI baru", mengubah UI-nya menjadi
komponen kit (pakai token `UI.T`), mendaftarkannya di `../INDEX.md`, lalu memindahkan
file asli ke `done/`.

Tips:
- Satu file per komponen, beri nama jelas (`searchlist.lua`, `slider_dual.lua`).
- Tulis di komentar paling atas: komponen ini untuk apa dan bagaimana maunya tampil.
- Kandidat pertama yang sudah ada di repo: daftar lagu dengan pencarian di
  `../../music_modules/ui/rows.lua` (lihat tabel "Belum ada di kit" di `../INDEX.md`).
