loadstring(game:HttpGet("https://raw.githubusercontent.com/rendays666/New-loader/refs/heads/main/script-maker/dumper.lua"))()

# Script Dumper v15 (Roblox)

Tool untuk membaca isi game Roblox di executor: scan script, rekam aksi game ke server (remote spy), lalu buat laporan `.txt` yang bisa dikirim ke AI. GUI berbahasa Inggris dengan dua mode.

Peta module dan panduan debugging: [ARCHITECTURE.md](ARCHITECTURE.md).

## Cara pakai (mode Simple, default)

Tab **Start** punya tiga langkah:

1. **Scan game** — membaca script game.
2. **Record game actions** (opsional) — nyalakan, lalu lakukan aksinya di game sekali (misalnya tekan Buy). Panggilan remote beserta argumennya ikut masuk laporan.
3. **Save report / Copy report** — hasilnya file `.txt` di folder workspace executor, atau di clipboard. Kalau belum scan, scan jalan otomatis dulu.

Tab **Log** menampilkan semua aktivitas dan error.

## Mode Advanced

Tekan tombol **Mode** di header. Tab tambahan:

| Tab | Isi |
|---|---|
| Scan | Pilih tempat yang di-scan (preset *Recommended*), opsi decompile/bytecode/core, daftar hasil + filter |
| Actions | Remote spy: daftar panggilan, kode siap salin (3 gaya), **Replay**, **Block**, **Ignore**, pilih metode rekam |
| Watch | Rekam tombol layar yang muncul + pesan server → client |
| Export | Smart/Full report (simpan atau salin) dan potongan data (mechanics, index, paths, remotes, tree, config) |
| Settings | Ganti mode, info executor, bantuan, unload |

Tombol **?** di tiap fitur menjelaskan fungsinya. PC: klik kanan juga bisa. RightShift menyembunyikan window.

## Metode rekam

| Metode | Cara kerja | Catatan |
|---|---|---|
| Auto | Coba Stealth dulu, lalu Namecall | Pilihan terbaik untuk kebanyakan game |
| Stealth | `hookfunction` pada `FireServer` / `InvokeServer` | Tidak menyentuh `__namecall`, lolos dari detector `namecallInstance` |
| Namecall | `hookmetamethod(__namecall)` | Cepat, tapi sebagian game mendeteksinya |

Kalau tidak ada yang terekam padahal sudah beraksi, ganti metode di tab Actions. Kalau game tetap menendang atau crash saat hook aktif, pakai Scan saja tanpa recording.

## Yang berubah di v15

- GUI dibangun ulang: grup per tab, mode Simple/Advanced, semua teks English.
- Remote spy (dari NetScope) digabung: kode siap salin, Replay, Block, Ignore, pause, filter.
- Stealth (HK2) sekarang tersambung ke GUI. Chip UC lama dihapus karena memakai `hookfunction` yang sama.
- Dedup capture sekarang membandingkan argumen, jadi panggilan beruntun dengan argumen berbeda tidak hilang lagi.
- Deteksi obfuscated mengecek marker (Luraph/Prometheus/IronBrew) sebelum gerbang ukuran.
- Loader memakai cache-bust di percobaan pertama, mencegah campuran module lama dan baru setelah push.
- Perbaikan loop scan remote ganda di Watch (start → stop → start cepat).

## Untuk AI yang menerima file laporan

File SMART/FULL diawali **CONFIG SNAPSHOT** (opsi apa yang aktif, data apa yang ada) dan diakhiri **DIAGNOSTICS** (executor, status hook, counter capture, error + traceback, log terakhir). Baca dua bagian itu dulu. Data yang ditandai ❌ tidak ada di file; minta pengguna menyalakan fitur yang sesuai dan membuat laporan baru.
