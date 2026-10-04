---
title: Evaluasi Ide Aplikasi PawonFood
type: transkrip konsultasi (user ↔ AI assistant), dirapikan
language: id
project: PawonFood — aplikasi pengurangan food waste
context: Hackathon bertema sustainability di UGM (Yogyakarta)
user: Rava (ketua tim)
related: Product.md
source: "Evaluasi Ide Aplikasi PawonFood (raw).md" — ekspor PDF yang sebagian teksnya rusak (font encoding)
---

# Evaluasi Ide Aplikasi PawonFood

> **Catatan untuk pembaca (AI/manusia):**
> Dokumen ini adalah versi rapi dari transkrip percakapan antara Rava dan sebuah AI assistant. Sumber aslinya adalah ekspor PDF yang sebagian teksnya rusak.
> - Teks yang rusak sudah didekode ulang jika memungkinkan.
> - `[tidak terbaca]` = bagian yang tidak bisa dipulihkan.
> - `[rekonstruksi]` = bagian yang disusun ulang dari konteks, bukan kutipan persis.
> - Deskripsi produk lengkap ada di [Product.md](Product.md).

## Ringkasan Cepat (TL;DR)

| Topik | Kesimpulan / Rekomendasi |
| --- | --- |
| Penilaian ide | Sangat relevan: mendukung SDGs 2 (Zero Hunger) & 12 (Responsible Consumption), cocok dengan demografi mahasiswa perantau di sekitar UGM. Mirip Too Good To Go, tetapi dengan pembeda C2C (dapur rumah tangga) + negosiasi harga. |
| Risiko terbesar | **Food safety** (makanan basi/beracun) dan fraud foto. |
| Inovasi teknis utama | **YOLO Food Validator** (YOLOv8 Nano, on-device via TFLite di Flutter) untuk memvalidasi foto makanan secara real-time. |
| Gamifikasi | Ganti title "Borjuis" → "Pahlawan Pangan" / "Food Savior" / "Sobat Pawon". Poin harus bisa ditukar reward nyata. |
| Model bisnis | Komisi 5–10% dari transaksi berbayar (free food bebas biaya), promoted listing, iklan brand eco-friendly. |
| Kompetitor | Surplus (B2C, resto/bakery, harga fixed), Garda Pangan (food bank, manual, donasi), DamoGO (mirip Surplus). |
| USP PawonFood | 1) C2C / dapur rumah tangga, 2) harga fleksibel + slot gratis, 3) validasi berbasis AI (YOLO). |
| Prioritas MVP | Core journey: Upload makanan → Validasi YOLO → Muncul di Maps → Diambil penerima. Pakai mock data, siapkan video backup demo. |

## Daftar Isi

1. [Evaluasi Ide Awal & Peningkatan Fitur](#1-evaluasi-ide-awal--peningkatan-fitur)
2. [Business Model Canvas](#2-business-model-canvas-bmc)
3. [YOLO Food Validator (Training & Backend)](#3-yolo-food-validator-training--backend)
4. [Integrasi YOLO ke Flutter](#4-integrasi-yolo-ke-flutter)
5. [Persiapan Hackathon (Non-Coding & Eksekusi)](#5-persiapan-hackathon-non-coding--eksekusi)
6. [Layout Home Screen](#6-layout-home-screen)
7. [Analisis Kompetitor di Indonesia](#7-analisis-kompetitor-di-indonesia)
8. [Slide Competitive Landscape](#8-slide-competitive-landscape)

---

## 1. Evaluasi Ide Awal & Peningkatan Fitur

**Prompt user:** Rava akan mengikuti hackathon bertema sustainability di UGM dan meminta evaluasi atas ide PawonFood (isi idenya sama dengan [Product.md](Product.md)).

### Penilaian Umum

- Ide sangat brilian dan relevan dengan tema sustainability: mendukung **SDGs nomor 2 (Zero Hunger)** dan **12 (Responsible Consumption)**.
- Sangat cocok dengan demografi sekitar UGM (Yogyakarta), yang didominasi mahasiswa perantau dan anak kos.
- Mirip dengan **Too Good To Go** (populer di Eropa), tetapi punya sentuhan lokal yang kuat: melibatkan dapur rumah tangga (**C2C**) dan sistem **negosiasi**.

### Evaluasi per Fitur

#### Fitur 1 — Kualitas & Foto Makanan
- **Tantangan:** Isu terbesar aplikasi food sharing adalah **food safety**. Juri pasti akan bertanya: *"Bagaimana menjamin makanan rumah tangga ini tidak basi atau beracun?"*
- **Peningkatan (Tech Add-on):**
  - Tambahkan Machine Learning (deteksi objek seperti YOLO atau CNN) untuk memvalidasi foto yang diunggah. AI bisa mendeteksi apakah foto diambil real-time (bukan dari Google) dan mengategorikan jenis makanan secara otomatis.
  - Wajib ada fitur **Disclaimer** dan **Terms of Service**. `[sisa kalimat tidak terbaca]`

#### Fitur 2 — Katalog Makanan
- **Peningkatan:** Buat kategorisasi yang jelas, misalnya:
  - **"Bahan Mentah"**: sayur sisa masak yang belum dipotong.
  - **"Makanan Matang"**: lauk pauk berlebih.
- Ini memudahkan anak kos atau pengurus panti mencari makanan sesuai kebutuhan mereka.

#### Fitur 3 — Harga & Gamifikasi
- **Tantangan:** Gelar "Borjuis" untuk pemberi makanan gratis berkonotasi kelas sosial yang kurang pas dengan semangat charity dan sustainability.
- **Peningkatan:** Ganti dengan title yang lebih heroik dan berpusat pada komunitas, misalnya **"Pahlawan Pangan"**, **"Food Savior"**, atau **"Sobat Pawon"**. Sistem level (gamifikasi) sangat bagus untuk retensi agar user terus berdonasi.

#### Fitur 4 — Transaksi & Sistem Poin
- **Tantangan:** Untuk apa provider (pemberi) mengumpulkan poin? Harus ada reward yang jelas.
- **Peningkatan:**
  - Poin bisa ditukar dengan voucher belanja di minimarket, diskon layanan antar, atau **sertifikat digital bulanan "Restoran Peduli Lingkungan"** (bagus untuk branding tempat makan/resto).
  - Tambahkan sistem **Rating & Review** dari penerima untuk menilai kualitas makanan dari provider, demi menjaga ekosistem tetap sehat.

#### Fitur 5 — Navigasi Maps
- **Peningkatan:** Fitur radius lokasi sangat krusial. Buat filter **"Bisa Jalan Kaki" (radius < 1 km)** karena banyak anak kos yang tidak punya kendaraan bermotor.

### Strategi Menghadapi Juri

Ide bagus saja tidak cukup. Tunjukkan bahwa ini produk yang **feasible**. Siapkan jawaban untuk tiga hal:

1. **Revenue Stream:** Bagaimana PawonFood membiayai servernya? Contoh: komisi 5% dari makanan berbayar, biaya subscription agar resto tampil di rekomendasi atas, atau donasi/subsidi silang.
2. **Target Akuisisi Awal:** Bagaimana meyakinkan ibu rumah tangga atau pemilik warung untuk mau memotret sisa makanan di akhir hari? UI/UX untuk provider harus super simpel, **maksimal 3 kali klik** untuk upload. `[rekonstruksi: akhir kalimat terpotong]`
3. **Impact Metrics:** Buat estimasi kasar, misalnya: *"Jika 50 warung makan bergabung, kita bisa menyelamatkan X kg makanan dari tempat sampah setiap bulan dan mengurangi Y kg emisi gas metana."*

---

## 2. Business Model Canvas (BMC)

**Prompt user:** Buatkan Business Model Canvas (BMC) lengkap untuk PawonFood agar siap dipresentasikan.

PawonFood adalah **multi-sided platform** (dua sisi: pemberi dan penerima), jadi BMC harus mencerminkan keuntungan bagi kedua belah pihak.

| # | Komponen | Isi untuk PawonFood |
| --- | --- | --- |
| 1 | Customer Segments | `[tidak terbaca di sumber]` `[rekonstruksi dari konteks]`: **Penerima**: mahasiswa/pelajar perantau (anak kos), panti asuhan, masyarakat berdana terbatas. **Penyedia**: rumah tangga (ibu kos), warung/warteg, rumah makan, restoran, toko roti. |
| 2 | Value Propositions | `[tidak terbaca di sumber]` `[rekonstruksi dari konteks]`: **Penerima**: makanan layak dengan harga murah/gratis di dekat kos. **Penyedia**: mengurangi kerugian & limbah, mendapat poin/badge, dan branding peduli lingkungan. |
| 3 | Channels | Kepraktisan mencari makanan terdekat lewat Maps (bisa dijangkau jalan kaki); aplikasi mobile (Android & iOS); media sosial (Instagram, TikTok) dengan kampanye anti-foodwaste dan gaya hidup hemat anak kos; kerja sama dengan BEM/Himpunan Mahasiswa untuk promosi grassroots di kampus; door-to-door ke restoran lokal di sekitar kampus. |
| 4 | Customer Relationships | **Gamifikasi & Reward**: poin dan title/badge (mis. "Sobat Pawon", "Resto Hijau") untuk user aktif. **Trust**: rating & review transparan pasca-transaksi. **Interaksi langsung**: chat in-app untuk negosiasi harga dan waktu pengambilan. |
| 5 | Revenue Streams | **Platform fee**: komisi 5–10% dari transaksi berbayar; free food dibebaskan dari biaya. **Promoted listing**: resto/toko roti membayar agar listing muncul paling atas di peta. **In-app ads**: iklan tertarget dari brand FMCG yang eco-friendly. |
| 6 | Key Activities | **Platform development & maintenance** (server, UI/UX). **Quality control**: memantau laporan untuk memastikan tidak ada penyedia yang memberikan makanan basi. **Marketing & akuisisi**: edukasi resto dan mahasiswa agar berhenti membuang makanan. |
| 7 | Key Resources | Infrastruktur teknologi (server, database, API Maps); tim inti (developer, desainer, marketing); komunitas pengguna (makin banyak user di satu area, makin hidup ekosistemnya). |
| 8 | Key Partnerships | Organisasi/NGO lingkungan (mis. Zero Waste Indonesia) untuk kredibilitas; payment gateway (Midtrans, Xendit); penyedia cloud & Maps (Google Maps API); kampus dan panti asuhan sebagai mitra penyalur. |
| 9 | Cost Structure | Biaya infrastruktur IT (server, hosting, API berbayar); biaya pemasaran & akuisisi (promo awal, cetak stiker/QR code di depan resto mitra); biaya operasional tim. |

> **Tips pitching:** Saat presentasi, soroti **Value Propositions** dan **Revenue Streams**. Juri hackathon sering menanyakan keberlanjutan bisnis `[rekonstruksi]`, jadi buktikan bahwa PawonFood bisa mandiri secara finansial (**financially sustainable**).

---

## 3. YOLO Food Validator (Training & Backend)

**Prompt user:** `[tidak terbaca]` (intinya: meminta rancangan teknis dan kode untuk memakai YOLO sebagai validator foto makanan).

Rava sudah berpengalaman memakai YOLO untuk mendeteksi bounding box pada gestur yang kompleks, jadi logika di PawonFood akan sangat mirip.

**Tujuan AI:**
- Mencegah **fraud**: foto kosong, foto barang, atau foto yang diambil dari Google.
- Mengategorikan jenis makanan secara otomatis (sayur, lauk, roti, dll.).
- Model yang disarankan: **YOLOv8 Nano**, agar ringan di mobile/edge.

### 3.1 Skenario Dataset (Food vs Non-Food)
- Tidak perlu melatih dari nol: pakai **pre-trained model + transfer learning**.
- **Kelas** `[rekonstruksi dari labels.txt di bagian 4]`: `makanan_matang`, `bahan_mentah`, `bukan_makanan`.
- **Sumber data:** Food-101 (Kaggle), atau dataset makanan Indonesia di **Roboflow Universe** agar model mengenali nasi rames, gorengan, dan lauk pauk lokal.

### 3.2 Skrip Training
Pakai library `ultralytics`. Untuk demo hackathon, **30–50 epoch** sudah cukup untuk prototipe (MVP).

```python
# Install library: pip install ultralytics
from ultralytics import YOLO

# 1. Load model pre-trained YOLOv8 Nano (paling cepat dan ringan)
model = YOLO('yolov8n.pt')

# 2. Proses training
# Pastikan ada file dataset.yaml berisi path folder train/val dan nama kelas
results = model.train(
    data='dataset.yaml',  # [rekonstruksi]
    epochs=50,            # Sesuaikan dengan kemampuan GPU
    imgsz=416,            # Resolusi standar yang cukup untuk deteksi makanan
)

# 3. Uji coba inferensi dengan gambar sisa makanan dari dapur
test_results = model('path/to/test_image.jpg')
test_results[0].show()
```

### 3.3 Logika Validasi di Sisi Server
Saat penyedia mengunggah foto makanan, foto dikirim ke model YOLO. Contoh logikanya:

```python
# [rekonstruksi]: nama fungsi, nilai "status", dan cara membaca box diisi ulang dari konteks
def validate_food_image(image_path):
    results = model(image_path)
    detections = results[0].boxes

    if len(detections) == 0:
        return {"status": "rejected", "message": "Tidak ada objek yang terdeteksi."}

    # Cek kelas apa yang terdeteksi
    for box in detections:
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        class_name = model.names[class_id]

        if class_name == 'bukan_makanan' and confidence > 0.70:
            return {"status": "rejected", "message": "Gambar terdeteksi bukan makanan. Mohon foto ulang."}

        if confidence > 0.60:
            return {
                "status": "approved",
                "category": class_name,
                "message": f"Validasi berhasil. Kategori: {class_name}",
            }

    return {"status": "pending_review", "message": "Gambar kurang jelas, butuh review manual."}
```

### 3.4 Ekspor Model ke Mobile (Edge AI)
Karena target pengguna adalah anak kos, inferensi AI paling ideal dilakukan **langsung di perangkat** (hemat biaya server/cloud). Konversi model ke **TensorFlow Lite** agar bisa ditanam di Flutter atau Kotlin.

```python
# Ekspor model terlatih ke TFLite (INT8 quantization agar ukurannya kecil)
model.export(format='tflite', int8=True, imgsz=416)
```

File `.tflite` hasil ekspor inilah yang dimasukkan ke folder `assets` aplikasi Flutter PawonFood.

---

## 4. Integrasi YOLO ke Flutter

**Prompt user:** `[tidak terbaca]` (intinya: cara mengintegrasikan model TFLite YOLO ke Flutter).

- Tantangan terbesar YOLO bukan melatih model, melainkan **memproses output tensor** (mis. Non-Maximum Suppression / **NMS**) di sisi Flutter/Dart.
- Dengan package TFLite standar, logika NMS harus ditulis ulang di Dart, dan itu terlalu lama untuk ukuran hackathon.
- **Rekomendasi MVP:** gunakan package **`flutter_vision`**, yang sudah punya wrapper khusus YOLOv8 sehingga tidak perlu memilah matriks tensor secara manual.

### 4.1 Siapkan Assets
Buat folder `assets/` di root project Flutter, lalu masukkan:
- `assets/yolov8n_pawonfood.tflite`
- `assets/labels.txt`: nama kelas berurutan sesuai index:

```text
makanan_matang
bahan_mentah
bukan_makanan
```

Daftarkan di `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/yolov8n_pawonfood.tflite
    - assets/labels.txt
```

### 4.2 Tambahkan Dependensi (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_vision: ^x.x.x   # package andalan untuk YOLOv8  [versi tidak terbaca]
  image_picker: ^x.x.x     # untuk mengambil foto dari galeri/kamera  [versi tidak terbaca]
```

### 4.3 Inisialisasi Model di Dart

```dart
import 'package:flutter_vision/flutter_vision.dart';

class FoodValidator {
  late FlutterVision vision;

  Future<void> initModel() async {
    vision = FlutterVision();
    // Memuat model YOLOv8 TFLite
    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov8n_pawonfood.tflite',
      modelVersion: "yolov8",
      quantization: true, // Set true jika model diekspor dengan INT8
      numThreads: 2,      // [nilai rekonstruksi]
      useGpu: true,
    );
  }

  // Jangan lupa di-dispose untuk mencegah memory leak
  Future<void> closeModel() async {
    await vision.closeYoloModel();
  }
}
```

### 4.4 Jalankan Validasi Saat Upload

```dart
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

Future<void> validateFoodUpload() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.camera);
  if (image == null) return; // [rekonstruksi]

  Uint8List imageBytes = await image.readAsBytes();
  // Decode ukuran gambar asli (diperlukan oleh flutter_vision)
  var decodedImage = await decodeImageFromList(imageBytes);

  // Proses deteksi
  final result = await vision.yoloOnImage(
    bytesList: imageBytes,
    imageHeight: decodedImage.height,
    imageWidth: decodedImage.width,
    iouThreshold: 0.4,  // Ambang batas overlapping box
    confThreshold: 0.5, // Hanya ambil prediksi dengan confidence > 50%
    classThreshold: 0.5, // [rekonstruksi]
  );

  // Evaluasi hasil
  if (result.isNotEmpty) {
    // Contoh output: [{box: [x1, y1, x2, y2, conf], tag: 'makanan_matang'}]
    String tag = result[0]['tag'];
    double conf = result[0]['box'][4];

    if (tag == 'bukan_makanan') {
      print("Sistem mendeteksi ini bukan makanan! Mohon foto ulang.");
    } else {
      print("Validasi sukses: $tag dengan akurasi ${conf * 100}%");
    }
  } else {
    print("Tidak ada makanan yang terdeteksi di foto.");
  }
}
```

### 4.5 Tips Tambahan untuk Demo
1. **Sederhanakan kelas jika perlu:** Jika training lama dan model belum akurat membedakan lauk pauk, latih dengan **2 kelas saja: `food` dan `non-food`**. Ini sudah cukup membuktikan ke juri bahwa validasi anti-fraud PawonFood benar-benar berjalan real-time.
2. **Feedback visual:** Tampilkan animasi loading atau efek *"AI sedang memindai..."* (mis. garis scanner hijau yang bergerak naik-turun di atas foto) saat model dieksekusi. Juri suka detail visual yang menunjukkan machine learning sedang bekerja di background.

---

## 5. Persiapan Hackathon (Non-Coding & Eksekusi)

**Prompt user:** "Apalagi yang harus kusiapkan? Berikan semua ide dan saran."

Rava sudah punya pengalaman dari proyek sebelumnya (Ojokumunan), jadi ritme kerja cepat khas hackathon sudah biasa. Agar PawonFood bisa menang di UGM, berikut taktik untuk fase eksekusi dan presentasi:

### 5.1 Strategi Anti-Gagal saat Demo `[judul rekonstruksi]`
Aplikasi yang tiba-tiba crash di depan juri adalah mimpi buruk klasik. Jangan bergantung pada Wi-Fi venue.
- **Siapkan video backup:** Rekam layar aplikasi berjalan mulus dari awal (login) sampai akhir (validasi YOLO berhasil dan transaksi selesai). Jika aplikasi ngadat saat presentasi, langsung putar video ini.
- **Fokus pada core flow:** Saat membuat MVP, jangan habiskan waktu untuk fitur reset password atau edit profile. Fokus 100% pada core journey:
  **Upload Makanan → Validasi YOLO → Muncul di Maps → Diambil penerima.** `[rekonstruksi sebagian]`
- **Hardcode data:** Gunakan mock data untuk lokasi peta dan daftar makanan. Juri ingin melihat pengalaman pengguna, bukan arsitektur database relasional yang kompleks.

### 5.2 Validasi Pasar dengan Data Nyata `[judul rekonstruksi]`
Ide yang didukung data lapangan tidak bisa dibantah juri.
- **Lakukan mini-survei:** Bagi tugas dengan tim (Nico, Nathan, Joshua, Alyaa, Carlos) untuk menyebar kuesioner singkat atau wawancara langsung ke 5–10 anak kos dan beberapa pemilik warung makan di sekitar UGM. `[jumlah rekonstruksi]`
- **Ubah jadi angka untuk presentasi:** Contoh: *"Dari 10 warung di Jalan Kaliurang, 8 di antaranya membuang sisa lauk rata-rata 3 kg per hari, dan 90% mahasiswa kos setuju membeli lauk tersebut jika harganya didiskon 50%."* (angka hanya contoh)

### 5.3 Mitigasi Risiko Keamanan Pangan
Juri yang kritis pasti akan menyerang kelemahan terbesar aplikasi food sharing: **keracunan makanan**.
- **Jawaban tegas:** PawonFood memosisikan diri sebagai **perantara / bulletin board**, bukan produsen makanan.
- **Terms of Service (ToS):** Tambahkan checkbox di UI saat user memesan, misalnya: *"Saya telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan."* Ini menunjukkan ke juri bahwa tim sudah memikirkan mitigasi risiko hukum.
- **Rating:** Jelaskan bahwa sistem rating akan otomatis memblokir penyedia (warung/rumah tangga) yang mendapat review buruk soal kualitas makanan.

### 5.4 Eksekusi UI (Kesan Pertama)
YOLO berjalan di background, jadi juri akan menilai seberapa intuitif aplikasinya.
- **Heatmap/cluster di Maps:** Daripada menumpuk banyak pin merah, tampilkan cluster (mis. angka "5" di area Pogung = ada 5 makanan tersedia). Terlihat lebih rapi dan profesional.
- **Warna psikologis:** Gunakan palet hijau dan earth-tone yang identik dengan keberlanjutan dan kesehatan.

---

## 6. Layout Home Screen

**Prompt user:** "Bantu aku merancang tata letak dan fitur apa saja yang harus ada di layar beranda (home screen) aplikasi PawonFood agar terlihat sangat intuitif."

Home screen menentukan apakah juri dan pengguna paham cara kerja PawonFood dalam **5 detik pertama**. Karena target utamanya mahasiswa yang butuh makanan cepat dan murah, desain harus fokus pada **lokasi, urgensi, dan harga**.

- Gunakan konsep **single app interface**: satu aplikasi untuk penerima sekaligus penyedia.
- Halaman depan difokuskan untuk **penerima**; fitur **penyedia** diletakkan di tombol utama (tengah).

Hierarki tata letak (atas → bawah):

### 6.1 Header (Lokasi & Poin)
- **Lokasi (kiri atas):** mis. "Pogung, Sleman" (bisa diklik untuk mengubah lokasi).
- **Saldo/Poin (kanan atas):** ikon koin emas + "150 Poin" (elemen gamifikasi aktif sejak awal).

### 6.2 Hero Section (Pencarian & Filter Cepat)
- **Search bar** dengan placeholder: *"Cari lauk malam ini..."*
- **Category chips** (swipe horizontal):
  - "Sedang Hangat"
  - "Makan Gratis"
  - `[tidak terbaca]`
  - "Bahan Mentah"
  - `[tidak terbaca]`

### 6.3 Mini Maps / Radar Area
Juri suka fitur berbasis lokasi. Daripada memaksa user masuk ke menu terpisah, tampilkan cuplikan peta di beranda.
- **Tampilan:** kotak peta interaktif kecil berisi pin lokasi user dan 3–5 titik penyedia terdekat dalam radius 1 km.
- **CTA:** tombol "Lihat Peta Penuh" di pojok kanan bawah peta.

### 6.4 Feed Daftar Makanan Terdekat `[judul rekonstruksi]`
Jantung aplikasi. Tampilkan makanan dalam bentuk **card** yang padat informasi:
- **Foto makanan:** thumbnail besar (hasil validasi YOLO; pastikan fotonya bersih).
- **Label urgensi & jarak:** badge merah "Sisa 2 Porsi" dan badge abu-abu jarak (mis. "500 m"). `[contoh jarak rekonstruksi]`
- **Detail teks:**
  - Nama makanan (mis. "Ayam Goreng Sisa Katering").
  - Nama penyedia + label (mis. "Warteg Bu Siti · Pahlawan Pangan").
- **Harga coret:** tampilkan harga asli dicoret (~~Rp15.000~~ **Rp5.000**) atau tulisan tebal **GRATIS**, plus ikon chat kecil untuk menegaskan harga bisa dinegosiasikan.

### 6.5 Bottom Navigation Bar
Lima menu, dengan tombol tengah menonjol (Floating Action Button):
1. **Beranda:** ikon rumah (aktif).
2. **Peta:** ikon pin lokasi.
3. **Tombol tengah (Bagikan Makanan):** ikon kamera atau logo PawonFood besar. Ini pintu masuk ke fitur YOLO, tempat penyedia (ibu kos/warung) memotret sisa makanan. Diletakkan di tengah agar paling cepat diakses.
4. **Pesan:** ikon chat (negosiasi dengan penyedia).
5. **Profil:** ikon orang (riwayat, title/badge, pengaturan).

Desain ini langsung menjawab tiga objektif untuk juri: **kemudahan akses** (Maps), **kejelasan nilai** (harga coret/gratis), dan **kemudahan konversi penyuplai** (tombol upload di tengah).

---

## 7. Analisis Kompetitor di Indonesia

**Prompt user:** `[tidak terbaca]` (intinya: apakah aplikasi serupa sudah ada di Indonesia?)

**Jawaban:** Sudah ada. Isu food waste mulai banyak dilirik startup dan NGO. Ini bukan alasan untuk pesimis: dalam dunia startup dan hackathon, adanya kompetitor justru membuktikan pasar sudah **tervalidasi** (ada permintaan nyata). Tugas di depan juri bukan mengklaim sebagai yang pertama, melainkan menunjukkan **apa bedanya** dan bagaimana PawonFood lebih unggul. `[kalimat pembuka sebagian rekonstruksi]`

### 7.1 Pemain yang Sudah Ada

| Pemain | Cara Kerja | Kelemahan |
| --- | --- | --- |
| **Surplus Indonesia** (kompetitor terbesar) | Sangat mirip Too Good To Go. Bermitra dengan toko roti, hotel, dan restoran besar (mis. The Harvest, hotel bintang 4) untuk menjual makanan yang belum terjual di akhir hari dengan diskon minimal 50%. | Murni B2C, harga fixed, segmen menengah ke atas. Tidak ada ruang untuk ibu rumah tangga atau warung kecil. |
| **Garda Pangan** (food bank) | Organisasi sosial, bukan sekadar aplikasi. Menyelamatkan makanan sisa dari acara besar (pernikahan, katering hotel) lalu menyalurkannya dengan mobil ke panti asuhan/masyarakat prasejahtera. | Sangat bergantung pada relawan, logistik mahal, dan donasi. Sulit diskalakan secara teknologi karena prosesnya manual. |
| **DamoGO** | Mirip Surplus: menghubungkan bisnis F&B dengan konsumen untuk menjual makanan berlebih. | `[tidak disebutkan]` |

### 7.2 USP PawonFood (untuk Pitch Deck)
Buat satu slide khusus **"Competitive Landscape"**. Juri suka peserta yang sadar akan kompetitornya dan tahu cara mencari celah.

1. **Pendekatan C2C (dapur rumah tangga):** Surplus dan DamoGO hanya mengambil dari restoran formal. PawonFood turun ke akar rumput (anak kos, warung burjo, ibu kos, rumah tangga), pasar hiperlokal yang sangat besar di sekitar kampus.
2. **Sistem fleksibel (negosiasi & gratis):** Aplikasi lain memakai harga mati. PawonFood punya chat untuk negosiasi harga dan slot **Free Food** bagi yang ingin bersedekah tanpa harus menjadi gerakan berskala besar seperti Garda Pangan.
3. **Keamanan berbasis AI (YOLO Validator):** C2C lebih rawan fraud atau makanan basi, jadi validasi foto dengan YOLO adalah inovasi yang tidak dipakai kompetitor saat ini. Ini menunjukkan kemampuan teknis, bukan sekadar ide bisnis.

### 7.3 Kalimat Pamungkas untuk Juri
> *"Surplus fokus menyelamatkan croissant dari bakery mewah. PawonFood fokus menyelamatkan sayur lodeh sisa masak ibu kos dan lauk warteg untuk anak kos di akhir bulan. Kami membangun ekosistem hiperlokal dengan pengamanan AI yang tidak dimiliki Surplus."*

---

## 8. Slide Competitive Landscape

**Prompt user:** "Bantu aku buatkan draf visual untuk slide 'Competitive Landscape' (tabel perbandingan) antara PawonFood vs Surplus vs Garda Pangan untuk dimasukkan ke pitch deck."

Tabel perbandingan dengan tanda centang adalah senjata visual yang paling mematikan dalam pitching, karena dominasi inovasi langsung terlihat dalam beberapa detik. Struktur ini bisa disalin ke Canva, PowerPoint, atau Figma.

### Struktur Slide

- **Judul:** `[tidak terbaca]`, mis. "Peta Kompetisi: Posisi PawonFood" `[rekonstruksi]`
- **Sub-header / pesan utama:** *PawonFood menggabungkan efisiensi komersial startup B2C dengan nilai kepedulian sosial, dilengkapi keamanan berbasis kecerdasan buatan.*
- **Tabel perbandingan** `[rekonstruksi: baris & tanda centang disusun ulang dari teks yang rusak dan USP di bagian 7]`

| Fitur | Surplus | Garda Pangan | PawonFood |
| --- | :---: | :---: | :---: |
| Sumber dapur rumah tangga (C2C) | ✗ | ✗ | ✓ |
| Penyaluran makanan gratis (charity) | ✗ | ✓ | ✓ |
| Harga fleksibel / negosiasi via chat | ✗ | ✗ | ✓ |
| Validasi keamanan berbasis AI (YOLO) | ✗ | ✗ | ✓ |

- **Footer / penjelasan di bawah tabel:**
  - **Surplus:** terbatas pada restoran besar & bakery dengan harga fixed.
  - **Garda Pangan:** skala besar, butuh relawan, logistik manual, murni donasi.
  - **PawonFood:** menggerakkan komunitas akar rumput (mahasiswa & ibu kos) dengan teknologi otomatis.
- **Tips visual:** Pakai warna hijau (warna utama aplikasi) untuk kolom PawonFood agar paling menonjol di layar, dan abu-abu pucat untuk kolom kompetitor.

### Naskah Narasi saat Slide Muncul
Jangan membacakan isi tabel satu per satu (juri bisa membacanya sendiri). Gunakan narasi ini:

> *"Bapak/Ibu Juri, kami tahu di luar sana sudah ada raksasa seperti Surplus dan pahlawan sosial seperti Garda Pangan. Namun, coba perhatikan matriks ini. Pemain yang ada saat ini hanya fokus pada sisa katering besar atau roti dari etalase mal.*
>
> *Tidak ada satu pun yang melirik lauk pauk berlebih dari ibu-ibu kos, warteg pinggir jalan, atau anak kos yang masak terlalu banyak. PawonFood masuk ke celah hiperlokal tersebut.*
>
> *Kami adalah satu-satunya platform yang memadukan transaksi jual-beli diskon dengan opsi sedekah gratis, dan mengamankan seluruh ekosistem C2C ini menggunakan AI YOLO. Kami tidak bersaing dengan Surplus; kami menjangkau pasar grassroots yang tidak bisa mereka jangkau."*
