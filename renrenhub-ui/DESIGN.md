# DESIGN — spesifikasi tampilan RENRENHUB

Sumber kebenaran ada di `UI.T` pada `lib/renrenhub_ui.lua`. Dokumen ini menjelaskan
maksud tiap token supaya AI tidak salah pakai.

## Warna (`UI.T.Color`)

| Token | RGB | Dipakai untuk |
|---|---|---|
| `Accent` | 0, 220, 160 | garis tepi (stroke), judul, judul section, thumb slider |
| `AccentBtn` | 0, 160, 120 | toggle ON, tab aktif, logo, isi slider |
| `Bg` | 20, 24, 38 | panel utama |
| `BgHeader` | 25, 25, 38 | title bar, toast |
| `BgDeep` | 10, 10, 15 | status bar, area paling gelap |
| `BgRow` | 32, 38, 52 | baris list |
| `BgItem` | 40, 40, 58 | tombol netral, toggle OFF, tab nonaktif |
| `BgInput` | 35, 40, 55 | textbox, kotak nilai |
| `Text` / `TextSub` / `TextDim` | 220,220,240 / 130,140,165 / 160,160,180 | teks utama / keterangan / nonaktif |
| `TextOn` | putih | teks di atas tombol berwarna |
| `Link` | 140, 195, 255 | ID, tautan |
| `Danger` / `DangerDim` | 200,60,60 / 140,40,40 | tutup, hapus, tombol minus |
| `Success` | 30, 140, 50 | tombol plus |
| `Info` / `Warn` | 50,80,125 / 200,150,50 | dropdown, peringatan |

Aturan: **satu warna aksen** (hijau). Merah hanya untuk aksi destruktif. Jangan
menambah warna baru di script.

## Ukuran (`UI.T.Dim`) dan font

| Token | Nilai | Catatan |
|---|---|---|
| `Title` | 24 | tinggi title bar |
| `Row` | 28 | tinggi tombol/toggle. **Minimum untuk aksi utama** (layar sentuh) |
| `RowTall` | 32 | baris stepper |
| `Tab` | 20 | tinggi tombol tab |
| `Status` | 36 | tinggi status bar |
| `Icon` | 34 | logo bulat |
| `Handle` | 22 | handle resize |
| `Gap` | 3 | jarak antar komponen |

Font: `Gotham` (teks biasa), `GothamSemibold` (tombol), `GothamBold` (judul, nilai),
`Code` (status/log). Ukuran teks: Caption 8, Small 9, Body 10, Label 11, Title 12, Big 16.
Sudut: panel 8, tombol 4, kecil 3, logo bulat penuh.

## Anatomi window

```
┌──────────────────────────────┐
│ RENRENHUB • Judul          ✕ │  Title bar 24px — drag untuk memindah
├──────────────────────────────┤
│ [Tab1] [Tab2] [Tab3]         │  Tab bar (grid, 3 kolom default)
│ [Tab4] [Tab5] [Tab6]         │
├──────────────────────────────┤
│ SECTION                      │
│ Fitur A            [ON]      │  Content = ScrollingFrame per tab
│ Nilai         [−] 10 [+]     │  tinggi mengikuti window
│ Slider ─────●───────  50     │
│                              │
├──────────────────────────────┤
│ status teks…                 │  Status bar 36px (opsional)
│                           ◢  │  ◢ = handle resize (kanan bawah)
└──────────────────────────────┘
        (T)  logo bulat: tap = tampil/sembunyi, drag = pindah
```

## Perilaku standar (sudah ditangani kit, jangan ditulis ulang)

- Window bisa digeser lewat title bar; header selalu tersisa di layar.
- Window bisa diubah ukuran lewat ◢. Minimum 200×220, maksimum sampai tepi layar.
- Logo bulat bisa digeser; ketuk tanpa geser = tampil/sembunyi window.
- ✕ meminta konfirmasi, lalu melepas semua koneksi dan menghancurkan GUI.
- Execute ulang script dengan `Name` yang sama membersihkan instance lama.
- Konten tab memakai ScrollingFrame, komponen tersusun otomatis (LayoutOrder).

## Aturan layout

1. Komponen selalu lebar penuh page (`Size = UDim2.new(1, 0, 0, tinggi)`).
2. Posisi di dalam baris memakai skala/anchor kanan, bukan piksel absolut dari kiri,
   supaya tetap rapi saat window di-resize.
3. Satu page = satu topik. Mulai dengan `UI.section`, lalu komponennya.
4. Label ≤ 20 karakter. Penjelasan panjang pakai `UI.info`.
5. Window default 240×320, diletakkan di kanan atas. Window besar (daftar lagu, log)
   boleh `Size` lebih besar, tapi tetap memakai `UI.createWindow`.
