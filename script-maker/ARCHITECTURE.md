# Script Dumper v14 — Arsitektur Module

Dokumen ini untuk **AI (dan manusia) yang men-debug dumper**. Baca ini dulu, lalu buka HANYA module yang relevan — tiap file < 250 baris.

## Cara kerja

`dumper.lua` (loader, URL tidak berubah) mengunduh tiap file di `modules/` sesuai `MODULE_ORDER`, meng-compile dengan nama chunk `=dumper/<module>` (jadi nomor baris di pesan error = nomor baris di file module itu), lalu menjalankannya.
Setiap module berbentuk:

```lua
return function(D)   -- D = tabel bersama (namespace)
    ...              -- menaruh API-nya di D.<Nama>
end
```

Module hanya boleh memakai `D.*` dari module yang **di atasnya** di urutan load.

## Peta module (urutan load)

| Module | Menyediakan | Tanggung jawab |
|---|---|---|
| `config` | `D.Config` | Semua konstanta: limit scan, daftar root, warna, teks tooltip, `FS.*` (limit capture) |
| `state` | `D.State`, `D.Shutdown` | Semua state mutable (flag chip, hasil scan, `runtimeCapture`, koneksi) |
| `logger` | `D.Log`, stub `D.UI.*` | Satu-satunya jalur log; `Log.safe`/`Log.wrap` mencatat error + traceback |
| `util` | `D.Util` | Fungsi murni: baca source, parsing baris, nama game, capability executor |
| `output` | `D.Output` | `copyText`, `saveToFile` |
| `runtime/capture` | `D.Capture` | Antrean + pencatat FireServer/InvokeServer (kerja berat di Heartbeat) |
| `runtime/hook` | `D.Hook` | Pasang hook HK (`__namecall`) dan HK2/UC (`hookfunction`; UC = alias HK2) |
| `runtime/ui_watch` | `D.UIWatch` | Chip UI: rekam tombol di PlayerGui |
| `runtime/passive` | `D.Passive` | Tombol RUN: LogService + OnClientEvent |
| `scanner` | `D.Scanner` | Tombol SCAN: baca `.Source` |
| `build/snapshot` | `D.Build.snapshot` | Header CONFIG SNAPSHOT |
| `build/runtime_report` | `D.Build.runtime`, `D.Build.diagnostics` | Bagian RUNTIME + DIAGNOSTICS |
| `build/reports` | `D.Build.index/remotes/tree/config` | Laporan berbasis game tree |
| `build/mechanics` | `D.Build.mechanics` | Analisis dari hasil SCAN |
| `ui/frame` | `D.UI.gui/main/scanPanel/logPanel/setTab` | Window, drag, tab, minimize |
| `ui/logview` | `D.UI.setRtStatus`, sink log | Panel LOG |
| `ui/tooltip` | `D.UI.showTooltip/hideTooltip` | Kotak info |
| `ui/widgets` | `D.UI.mkBtn/addInfoBadge/attachInfo` | Komponen kecil |
| `ui/list` | `D.UI.setStatus/clearList/rebuildList` | Daftar hasil scan + filter |
| `ui/chips` | — | Chip root / opsi / runtime (HK, UC, UI, RT) |
| `ui/buttons` | — | 11 tombol aksi + handler |
| `bootstrap` | — | Start capture, banner boot |

## Mencari bug: gejala → module

| Gejala | Buka |
|---|---|
| GUI **game** tidak bisa diklik / remote game rusak saat HK ON | `runtime/hook` (aturan hook) lalu `runtime/capture` |
| HK ON tapi `Runtime FS` kosong | Coba chip HK2 (mekanisme beda); `DIAGNOSTICS` → `enqueued`/`logged`/`logged per sumber`; lalu `runtime/hook` |
| HK2 ON tapi tidak mencatat | Pastikan HK OFF (HK prioritas); `DIAGNOSTICS` → `HK2/UC class terpasang`, `lastError` |
| Tombol UI dumper tidak merespons | `ui/buttons` (handler), `ui/frame` |
| Scan macet / "Scan running..." | `scanner` (flag direset di `Scanner.run`) |
| Hasil scan salah status (obf/readable) | `scanner` (`looksObfuscated`), `util.readSource` |
| Isi file SMART/FULL salah / ada bagian "GAGAL DIBUAT" | `build/*` bagian yang disebut + `DIAGNOSTICS → Error tercatat` |
| Nomor baris di API SURFACE salah | `util.findLines` |
| Daftar script ganda / berkedip saat filter | `ui/list` (`renderToken`) |
| Tombol tidak tersimpan / clipboard gagal | `output` |
| Executor tidak mendukung fitur | `DIAGNOSTICS → Executor capability` |

## Bagian DIAGNOSTICS di file SMART/FULL

Selalu ada di akhir file. Isi: versi, executor, capability (hookmetamethod, setnamecallmethod, hookfunction, …), status hook, counter capture (`enqueued/logged/deduped/dropped/errors`), status tiap module, error + traceback, 40 log terakhir. **Mulai debugging dari sini.**

Cara membaca counter capture:
- `enqueued = 0` padahal sudah beraksi → hook tidak menangkap (executor tidak mendukung / remote lewat jalur lain; coba chip UC).
- `enqueued > 0`, `logged = 0` → bug di `D.Capture` (`process` / dedup).
- `dropped > 0` → remote dipanggil sangat cepat; naikkan `Config.FS.MAX_PENDING` / `DRAIN_PER_FRAME`.

## Aturan keras (jangan dilanggar saat edit)

0. **HK vs HK2:** HK = `__namecall`; HK2 = `hookfunction` pada method C. Keduanya hanya mencatat lewat `box.push`. Kalau HK ON maka HK2/UC diam (cegah catatan ganda). HK2 dan UC memakai hook fungsi yang SAMA (`box.fn`) — jangan memasang `hookfunction` kedua pada fungsi yang sama.
1. **Hook `__namecall` (`runtime/hook`) dilarang memanggil method Instance** (`x:GetFullName()`, `x:IsA()`, dst.) — itu me-reset namecall method dan merusak panggilan asli game (akar bug lama: GUI game mati saat HK ON). Di hook hanya boleh: `getnamecallmethod`, `table.pack`, `typeof`, `pcall(push, ...)`, lalu `setnamecallmethod(method)` sebelum `old(self, ...)`. Semua kerja berat → `runtime/capture` (Heartbeat).
2. **Jangan simpan referensi** `D.State.allScripts` / `D.State.runtimeCapture.*` di variabel lokal level module — tabelnya diganti ulang oleh SCAN/CLR/RT. Akses lewat `D.State.<nama>` saat dipakai.
3. Semua handler event GUI dibungkus `D.Log.wrap(tag, fn)`; kode async memakai `D.Log.safe(tag, fn)`. Jangan `pcall` kosong yang menelan error.
4. Log hanya lewat `D.Log.write(text, color, tag)`.
5. Satu file < 500 baris. Kalau mendekati, pecah.

## Menambah fitur baru

1. Buat `modules/<grup>/<nama>.lua` dengan pola `return function(D) ... end`.
2. Tambahkan ke `MODULE_ORDER` di `dumper.lua` (setelah dependensinya).
3. Naikkan `SCRIPT_VERSION`.
4. Jalankan pemeriksa sintaks/referensi sebelum upload.
