# Infinite Yield - Refactor untuk Belajar

Folder ini berisi hasil refactor file `source` dari
[EdgeIY/infiniteyield](https://github.com/EdgeIY/infiniteyield) menjadi
modul kecil per command. Tujuannya **belajar membaca kode**, bukan
menjual atau mendistribusikan ulang karya orang lain.

**Refactored from EdgeIY/infiniteyield (MIT License).**

## Tujuan

- Memecah satu file Lua/Luau raksasa menjadi file per command supaya
  lebih mudah dibaca dan dipelajari.
- Melatih parsing Lua: string, long string, komentar, bracket bersarang,
  dan blok `function ... end`.
- Menyediakan loader sederhana dengan pola `registerCommand(name, aliases, fn)`.

## Struktur folder

```
Infiniteyield/
├── original/          # source asli; `source.txt` ikut repo, `source` diabaikan
│   └── .gitkeep
├── splitter/
│   ├── split.py       # program splitter (Python 3, tanpa dependency)
│   └── report.txt     # laporan hasil split (dibuat otomatis)
├── commands/          # hasil split: satu file per command + index.lua
├── core/
│   ├── index.lua      # require semua helper, urutan dependensi
│   ├── globals.lua    # service, GUI, fungsi umum
│   ├── args.lua       # parser argumen/player
│   ├── notify.lua     # notifikasi
│   ├── waypoint.lua   # helper waypoint
│   └── loader.lua     # loader/registry untuk Roblox
├── README.md
├── LICENSE            # MIT License dari upstream
└── .gitignore
```

## Cara pakai

1. Unduh file `source` dari repo upstream:
   <https://github.com/EdgeIY/infiniteyield/blob/master/source>
   (atau langsung: <https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source>),
   lalu taruh di:

   ```
   original/source
   ```

   Nama `original/source.txt` juga diterima; splitter mendeteksinya otomatis
   kalau `original/source` tidak ada.

2. Jalankan splitter dari folder `script-maker/Infiniteyield/`:

   ```bash
   python3 splitter/split.py
   ```

3. Lihat hasilnya:

   - `commands/<nama>.lua` - satu command per file
   - `commands/index.lua` - me-require semua modul
   - `splitter/report.txt` - jumlah command, daftar file, peringatan

4. Validasi sintaks (opsional):

   ```bash
   python3 splitter/split.py --check
   ```

   `--check` menjalankan `luac -p` untuk setiap file hasil. Kalau `luac`
   tidak tersedia, pengecekan dilewati.

Opsi lain:

```bash
python3 splitter/split.py --source /path/ke/source --out /path/ke/output --core /path/ke/core
```

## Catatan tentang Luau dan `luac -p`

File `source` upstream adalah **Luau** (Lua versi Roblox), bukan Lua 5.4.
Beberapa command memakai sintaks yang tidak dikenal `luac`, terutama:

- `continue`
- compound assignment seperti `+=` dan `-=`

Splitter **tidak mengubah** isi fungsi, jadi file yang memakai sintaks
tersebut akan dilaporkan sebagai `Luau-only` oleh `--check`, bukan
sebagai kegagalan splitter. File lain tetap lolos `luac -p`. Untuk
menjalankan hasilnya, gunakan Roblox/Luau, bukan `lua` biasa.

## Cara kerja singkat splitter

1. Tokenizer membaca source dan membuang komentar, tetapi menyimpan
   string pendek (`'...'`, `"..."`) dan long string (`[[...]]`,
   `[==[...]==]`) sebagai satu token. Jadi teks `addcmd` di dalam
   komentar/string tidak ikut diproses.
2. Parser mencari token `addcmd`, lalu mencocokkan kurung secara
   berimbang (bukan regex).
3. Blok fungsi dihitung dengan keyword: `function`, `if`, `do`, `repeat`
   menambah kedalaman; `end`, `until` mengurangi.
4. Setiap command ditulis sebagai modul:

   ```lua
   return {
       name = "fly",
       aliases = {"fly"},
       fn = function(args, speaker)
           -- isi asli dari source
       end,
   }
   ```
5. Deklarasi global top-level (`function nama(...)`, `nama = function(...)`,
   `nama = { ... }`, `nama = Instance.new(...)`) dikumpulkan, lalu hanya
   yang dipakai command (dan dependensinya) yang ditulis ke `core/`.
   Deklarasi di dalam `addcmd`/fungsi lain dan `local` tidak diekstrak.
6. Dependency scan mencatat global yang dipakai tiap command, daftar
   `UNRESOLVED`, top-level local yang tidak diekstrak, dan blok yang gagal
   di-parse ke `splitter/report.txt`.

## Struktur `core/`

Splitter memindahkan deklarasi global top-level yang dipakai command
(beserta dependensinya) ke `core/`, supaya isi command bisa dibaca utuh
tanpa bolak-balik ke `original/source`.

| File | Isi |
|------|-----|
| `core/index.lua` | `require` semua file core dengan urutan aman: `globals` → `args` → `notify` → `waypoint`. |
| `core/globals.lua` | Service Roblox, variabel GUI, dan fungsi umum (`getRoot`, `execCmd`, `updatesaves`, `Services`, `Players`, ...). |
| `core/args.lua` | Helper argumen/player: `getstring`, `getPlayer`, `splitString`, `parseBoolean`, `SpecialPlayerCases`, ... |
| `core/notify.lua` | `notify` dan variabel GUI notifikasi (`Notification`, `Title_2`, `PinButton`, ...). |
| `core/waypoint.lua` | `waypointmover`, `stopwpping`, `wprm`, `refreshwaypoints`, state `WayPoints`/`pWayPoints`, ... |

Urutan file mengikuti sumber aslinya. `core/index.lua` sengaja
me-require `globals` lebih dulu karena file lain memakai `Players`,
`Services`, dan variabel global lain saat fungsi dipanggil.

Dependency scan menulis dua daftar penting di `splitter/report.txt`:

- **Dependencies per command** — global yang dipakai tiap command.
  Tanda `?` berarti tidak ditemukan deklarasinya; tanda `(local)` berarti
  namanya top-level `local` dan tidak diekstrak.
- **UNRESOLVED** — global yang dipakai command/helper tetapi tidak punya
  deklarasi top-level, misalnya karena dibuat dinamis lewat `loadstring`
  atau `getgenv()`.

Top-level `local` (misalnya `notifyCount` atau `waypointwalkto`) tidak
diekstrak karena scope-nya hanya file asli. Kalau sebuah helper memakai
local itu, namanya muncul di bagian **Top-level local** pada report,
bukan di UNRESOLVED. Untuk memakainya di luar `original/source`, deklarasinya
perlu dipindahkan manual atau diubah menjadi global.

## Memakai loader di Roblox

Letakkan folder `commands/` dan seluruh isi `core/` di dalam game, lalu:

```lua
local Loader = require(script.Parent.core.loader)
Loader.loadAll(script.Parent.commands)

local command = Loader.get("fly") -- nama atau alias
if command then
    command.fn({"1"}, game.Players.LocalPlayer)
end
```

`Loader.loadAll` me-require `core/index.lua` lebih dulu, baru
`commands/index.lua`. Kalau folder core berada di tempat lain, lewatkan
sebagai argumen kedua:

```lua
Loader.loadAll(script.Parent.commands, script.Parent.core)
```

Catatan: fungsi command hasil ekstraksi masih memakai global/helper dari
program Infinite Yield asli (misalnya `notify`, `Players`, `cmds`).
Loader hanya mendaftarkan fungsi; menjalankannya tetap butuh lingkungan
yang sesuai. Helper yang sudah diekstrak ada di `core/`, sedangkan
top-level local yang tidak diekstrak tercatat di `splitter/report.txt`.

## Atribusi dan lisensi

Kode asli: <https://github.com/EdgeIY/infiniteyield>

**Refactored from EdgeIY/infiniteyield (MIT License).**

Copyright (c) 2026 EdgeIY

Isi `LICENSE` adalah salinan MIT License dari repo upstream. Semua kode
hasil refactor tetap tunduk pada lisensi tersebut. Jangan menghapus
atribusi ini dan jangan mengklaim kode upstream sebagai milik sendiri.

## Batasan

- Splitter hanya menangani pemanggilan `addcmd` dengan nama string
  literal. Pendaftaran dinamis (misalnya dari plugin) dilewati dan
  dicatat di `splitter/report.txt`.
- Yang diekstrak hanya deklarasi global top-level yang dipakai command
  (langsung atau lewat helper lain). Global yang tidak dipakai tetap
  tinggal di `original/source`.
- Top-level `local` tidak diekstrak karena scope-nya hanya file asli.
  Nama yang dipakai helper/command dicatat di bagian **Top-level local**
  pada report.
- Global yang dibuat dinamis (`loadstring`, `getgenv`, dan sejenisnya)
  tidak punya deklarasi top-level, jadi muncul sebagai `UNRESOLVED`.
- Urutan deklarasi di `core/` mengikuti nomor baris source, sehingga
  output splitter deterministik dan diff Git stabil.
- Hasil split bukan program mandiri. Ini bahan belajar dan potongan
  kode, bukan pengganti Infinite Yield.
- File `original/source` diabaikan oleh `.gitignore`. Di repo ini file
  yang di-upload bernama `original/source.txt`, jadi file tersebut ikut
  ter-commit; ganti namanya menjadi `source` kalau ingin diabaikan.
