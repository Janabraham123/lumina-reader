# Lumina Reader (Aplikasi Pembaca PDF ala Google Play Books)

Lumina Reader adalah aplikasi mobile pembaca PDF modern yang dibangun dengan Flutter. Aplikasi ini dirancang khusus untuk menghadirkan pengalaman membaca layaknya buku fisik dengan animasi 3D Page Curl realistis, pelacakan progres otomatis, dan rak buku interaktif.

---

## Fitur Utama

1. **Animasi 3D Page Curl Realistis**:
   - Lembaran halaman melengkung dinamis mengikuti geseran jari pengguna.
   - Dilengkapi bayangan lipatan silinder dan kilauan cahaya realistis.
   - Dukungan gestur drag bebas serta tap cepat di tepi kiri/kanan.

2. **Penyimpanan Posisi Baca Terakhir Otomatis**:
   - Aplikasi otomatis mengingat halaman terakhir yang Anda baca.
   - Banner **"Lanjutkan Membaca"** di bagian atas rak buku memungkinkan Anda melanjutkan membaca hanya dengan satu sentuhan.

3. **Indikator Progres Membaca Visual**:
   - Menampilkan persentase baca (misal: `45%`) dan jumlah halaman (`Hal 42 dari 280`).
   - Progress bar elegan di setiap kartu buku dan di dalam layar baca.

4. **Pengalaman Sensorik (Sound & Haptic)**:
   - Efek suara gesekan lembaran kertas (*paper rustle sound*).
   - Getaran lembut (*haptic feedback*) saat membalik halaman.

5. **Kustomisasi Tema Baca**:
   - **Sepia (Kertas Hangat)**: Nyaman di mata untuk sesi membaca panjang.
   - **Terang (Light)**: Bersih dan kontras tinggi.
   - **Gelap (Dark/OLED)**: Hemat baterai dan nyaman di malam hari.

6. **Navigasi & Kontrol Lengkap**:
   - Scrubber slider di bagian bawah untuk lompat ke halaman mana pun secara instan.
   - Daftar Isi (TOC / Outline Bab).
   - Penanda Halaman (Bookmarks) untuk menyimpan halaman favorit.

---

## Struktur Folder

```
play_reader/
├── lib/
│   ├── main.dart                 # Titik masuk aplikasi & konfigurasi tema
│   ├── models/
│   │   ├── book_model.dart       # Model data buku & kalkulasi progres
│   │   └── bookmark_model.dart   # Model data penanda halaman
│   ├── services/
│   │   ├── storage_service.dart  # Penyimpanan lokal & status buku
│   │   └── audio_haptic_service.dart # Efek suara dan getaran
│   ├── widgets/
│   │   ├── page_curl_view.dart   # Widget animasi 3D Page Curl
│   │   ├── book_card.dart        # Kartu buku di rak
│   │   ├── continue_reading_card.dart # Banner lanjutkan membaca
│   │   └── toc_sheet.dart        # Modal daftar isi & bookmark
│   └── screens/
│       ├── library_screen.dart   # Halaman rak buku utama
│       └── reader_screen.dart    # Halaman baca PDF
└── pubspec.yaml
```

---

## Cara Menjalankan Project

### Prasyarat
- Pastikan Flutter SDK (versi >= 3.0.0) sudah terpasang di sistem Anda.
- Android Studio / VS Code dengan ekstensi Flutter & Dart.

### Langkah Menjalankan
1. Masuk ke direktori project:
   ```bash
   cd /home/janabraham/.gemini/antigravity/scratch/play_reader
   ```
2. Unduh dependensi:
   ```bash
   flutter pub get
   ```
3. Hubungkan HP Android atau nyalakan emulator, lalu jalankan:
   ```bash
   flutter run
   ```
4. Untuk membuat file APK rilis:
   ```bash
   flutter build apk --release
   ```
