# Script Dumper v15 — Arsitektur Module

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
| `config` | `D.Config` | Konstanta: limit scan, root, warna, `THEME`, teks info (English), `CAPTURE_METHODS`, `FS.*` |
| `state` | `D.State`, `D.Shutdown` | State mutable (mode GUI, flag capture `hkActive/hk2Active/capturing`, `spy`, hasil scan, `runtimeCapture`) |
| `logger` | `D.Log`, stub `D.UI.*` | Satu-satunya jalur log; `Log.safe`/`Log.wrap` mencatat error + traceback |
| `util` | `D.Util` | Fungsi murni: baca source, parsing baris, nama game, capability executor |
| `codegen` | `D.Codegen` | Panggilan remote → kode Lua (template simple / advanced / debug) |
| `output` | `D.Output` | `copyText`, `saveToFile` |
| `runtime/capture` | `D.Capture` | Antrean + pencatat FireServer/InvokeServer (kerja berat di Heartbeat), dedup remote+method+argumen, listener UI |
| `runtime/hook` | `D.Hook` | HK1 (`__namecall`) dan HK2 "Stealth" (`hookfunction`); `Hook.start("auto"/"hk2"/"hk1")`, block per remote |
| `runtime/ui_watch` | `D.UIWatch` | Rekam tombol di PlayerGui |
| `runtime/passive` | `D.Passive` | LogService + OnClientEvent (server → client) |
| `runtime/spy` | `D.Spy` | Replay / Block / Ignore / template (dipanggil dari UI thread, bukan dari hook) |
| `scanner` | `D.Scanner` | Scan: baca `.Source` |
| `build/snapshot` | `D.Build.snapshot` | Header CONFIG SNAPSHOT |
| `build/runtime_report` | `D.Build.runtime`, `D.Build.diagnostics` | Bagian RUNTIME + DIAGNOSTICS |
| `build/reports` | `D.Build.index/remotes/tree/config` | Laporan berbasis game tree |
| `build/mechanics` | `D.Build.mechanics` | Analisis dari hasil scan |
| `actions` | `D.Actions` | Semua logika tombol (scan, report, copy, setCapture, ...) — GUI hanya memanggil ini |
| `ui/kit` | `D.UI.kit` | Komponen: button, toggle, card, grid, stack, tip |
| `ui/frame` | `D.UI.gui/main/addPage/setTab/setMode/onMode/setStatus/setRtStatus` | Window, drag, tab bar, mode Simple/Advanced, footer status |
| `ui/tooltip` | `D.UI.showTooltip` | Kotak info (badge `?`) |
| `ui/logview` | sink log | Halaman Log |
| `ui/page_start` | — | Halaman Start: 3 langkah (Scan → Record → Report) — Simple + Advanced |
| `ui/page_scan` | `D.UI.clearList/rebuildList` | (Advanced) tempat/opsi scan + hasil |
| `ui/page_capture` | — | (Advanced, tab "Actions") remote spy: daftar panggilan, kode, Replay/Block/Ignore |
| `ui/page_watch` | — | (Advanced) rekam tombol layar + pesan server |
| `ui/page_export` | — | (Advanced) semua laporan dan potongan data |
| `ui/page_settings` | — | (Advanced) mode, info executor, bantuan, unload |
| `bootstrap` | — | Start capture, pilih tab awal, banner boot |

## Mode GUI

- **Simple** (default): hanya tab Start + Log. Tiga langkah besar, tanpa istilah teknis.
- **Advanced**: semua tab. Halaman didaftarkan dengan `UI.addPage(id, title, advancedOnly)`.
- Pilihan mode disimpan di `getgenv().__DUMPER_MODE` (bertahan antar re-execute).
- Semua teks GUI = English; isi file laporan (SNAPSHOT/DIAGNOSTICS) tetap Indonesia untuk debugging.

## Mencari bug: gejala → module

| Gejala | Buka |
|---|---|
| GUI **game** tidak bisa diklik / remote game rusak saat recording ON | `runtime/hook` (aturan hook) lalu `runtime/capture` |
| Recording ON tapi `Runtime FS` kosong | `DIAGNOSTICS` → `enqueued`/`logged`; coba metode lain (Stealth ↔ Namecall) di tab Actions; lalu `runtime/hook` |
| Tombol UI dumper tidak merespons | `actions` (logika), halaman `ui/page_*` terkait, `ui/frame` |
| Scan macet / "Scan running..." | `scanner` (flag direset di `Scanner.run`) |
| Hasil scan salah status (obf/readable) | `scanner` (`looksObfuscated`), `util.readSource` |
| Isi file SMART/FULL salah / ada bagian "GAGAL DIBUAT" | `build/*` bagian yang disebut + `DIAGNOSTICS → Error tercatat` |
| Nomor baris di API SURFACE salah | `util.findLines` |
| Daftar script ganda / berkedip saat filter | `ui/page_scan` (`renderToken`) |
| Tombol tidak tersimpan / clipboard gagal | `output` |
| Replay / Block / kode remote salah | `runtime/spy`, `codegen`, `ui/page_capture` |
| Capture berhenti setelah ganti metode | `runtime/hook` (`Hook.start`), `ui/page_capture` (tombol Method) |
| Executor tidak mendukung fitur | `DIAGNOSTICS → Executor capability` |

## Bagian DIAGNOSTICS di file SMART/FULL

Selalu ada di akhir file. Isi: versi, executor, capability (hookmetamethod, setnamecallmethod, hookfunction, …), status hook (HK1/HK2, class yang di-hook, lastError), counter capture (`enqueued/logged/deduped/ignored/dropped/errors`), status tiap module, error + traceback, 40 log terakhir. **Mulai debugging dari sini.**

Cara membaca counter capture:
- `enqueued = 0` padahal sudah beraksi → hook tidak menangkap (executor tidak mendukung / game mendeteksi hook / remote lewat jalur lain; coba metode lain di tab Actions).
- `enqueued > 0`, `logged = 0` → bug di `D.Capture` (`process` / dedup), atau Pause/Ignore sedang aktif.
- `dropped > 0` → remote dipanggil sangat cepat; naikkan `Config.FS.MAX_PENDING` / `DRAIN_PER_FRAME`.

## Aturan keras (jangan dilanggar saat edit)

1. **Hook (HK1 `__namecall` dan HK2 `hookfunction`) dilarang memanggil method Instance** (`x:GetFullName()`, `x:IsA()`, dst.) — itu me-reset namecall method dan merusak panggilan asli game (akar bug lama: GUI game mati saat HK ON). Di hook hanya boleh: `getnamecallmethod`, `table.pack`, `typeof`, `pcall(push, ...)`, lalu (khusus HK1) `setnamecallmethod(method)` sebelum `old(self, ...)`. Satu-satunya pengecualian: membaca `S.spy.blocked[self]` (tabel biasa). Semua kerja berat → `runtime/capture` (Heartbeat); Replay/Block/Ignore/codegen → `runtime/spy`, `codegen` (UI thread).
2. **Jangan simpan referensi** `D.State.allScripts` / `D.State.runtimeCapture.*` di variabel lokal level module — tabelnya diganti ulang oleh SCAN/CLR/RT. Akses lewat `D.State.<nama>` saat dipakai.
3. Semua handler event GUI dibungkus `D.Log.wrap(tag, fn)`; kode async memakai `D.Log.safe(tag, fn)`. Jangan `pcall` kosong yang menelan error.
4. Log hanya lewat `D.Log.write(text, color, tag)`.
5. Logika tombol hanya di `actions`; halaman `ui/page_*` hanya menyusun komponen dan memanggil `D.Actions.*`.
6. Satu file < 500 baris. Kalau mendekati, pecah.

## Menambah fitur baru

1. Buat `modules/<grup>/<nama>.lua` dengan pola `return function(D) ... end`.
2. Tambahkan ke `MODULE_ORDER` di `dumper.lua` (setelah dependensinya).
3. Naikkan `SCRIPT_VERSION`.
4. Jalankan pemeriksa sintaks/referensi sebelum upload.
