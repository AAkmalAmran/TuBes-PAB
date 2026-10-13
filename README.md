**Prasyarat Sistem**

* Flutter SDK terpasang di komputer
* Git terpasang
* Editor kode (VS Code atau Android Studio)
* Emulator aktif atau ponsel fisik dengan mode *USB Debugging* menyala

---

**Langkah Menjalankan Proyek**

**1. Kloning Repositori**
Unduh proyek dari GitHub dan masuk ke direktori utama:

```bash
git clone https://github.com/AAkmalAmran/TuBes-PAB.git
cd TuBes-PAB

```

**2. Unduh Seluruh Dependensi**
Sinkronkan paket yang terdaftar pada `pubspec.yaml` (termasuk pustaka `http` dan `intl`):

```bash
flutter pub get

```

<!-- **3. Konfigurasi Kunci API (NewsAPI)**
Buka file `lib/core/constants/api_endpoints.dart`, lalu masukkan API Key masing-masing yang didapatkan dari situs NewsAPI:

```dart
const String newsApiKey = 'MASUKKAN_API_KEY_DI_SINI';

``` -->

**4. Periksa Kesiapan Perangkat**
Pastikan emulator atau perangkat fisik terdeteksi oleh Flutter:

```bash
flutter devices

```

**5. Jalankan Aplikasi**
Mulai aplikasi dalam mode pengembangan (*debug*):

```bash
flutter run

```

---

**Panduan Mengatasi Kendala (Troubleshooting)**

Jika rekan tim mengalami masalah *build error* atau pustaka tidak terbaca setelah menarik (*pull*) pembaruan kode terbaru:

```bash
flutter clean
flutter pub get
flutter run

```