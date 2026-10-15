# Naskah video pitch PawonFood (2 menit)

Sumber: [reference/VIDEO.md](reference/VIDEO.md), [PRD_PawonFood.md](PRD_PawonFood.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [reference/Evaluasi Ide Aplikasi PawonFood.md](<reference/Evaluasi Ide Aplikasi PawonFood.md>).

## Ringkasan

| Item | Isi |
| --- | --- |
| Durasi | Tepat 120 detik |
| Format | 16:9, 1920×1080, 30 fps |
| Penonton | Juri hackathon, komunitas kampus, praktisi teknologi, pegiat keberlanjutan |
| Pesan inti | PawonFood menghubungkan dapur yang kelebihan masak dengan orang di sekitarnya, supaya makanan layak tidak jadi sampah. |
| Pembicara | Pembicara 1, 2, 3 (nama diisi tim) |
| Posisi produk | Hyperlocal Community Food Rescue Platform. Bukan aplikasi makanan diskon. |

## Peta waktu

| Bagian | Waktu | Durasi | Isi |
| --- | --- | --- | --- |
| A1 | 00:00–00:04 | 4 s | Masalah: masakan sisa hampir dibuang |
| A2 | 00:04–00:08 | 4 s | Peluang: anak kos mencari makan malam |
| A3 | 00:08–00:13 | 5 s | Perkenalan PawonFood: foto, cek AI, tayang, ditemukan |
| A4 | 00:13–00:17 | 4 s | Penyelamatan: pesan, pindai QR, terselamatkan |
| A5 | 00:17–00:20 | 3 s | Logo, positioning, slogan |
| B1 | 00:20–00:46 | 26 s | Pembicara 1: masalah |
| B2 | 00:46–01:22 | 36 s | Pembicara 2: solusi dan demo |
| B3 | 01:22–01:48 | 26 s | Pembicara 3: pembeda, model bisnis, tujuan |
| C1 | 01:48–01:54 | 6 s | Penutup bersama, slogan dibagi tiga |
| C2 | 01:54–02:00 | 6 s | End card logo |
| | | **120 s** | A 20 + B 88 + C 12 |

Musik memakai 120 BPM, jadi satu ketukan = 0,5 detik dan setiap pergantian shot jatuh tepat di ketukan: 00:00, 00:04, 00:08, 00:13, 00:17.

---

# BAGIAN A: Iklan animasi (00:00–00:20)

Tanpa pembicara. Hanya visual, teks pendek, efek suara, dan musik. Alurnya: **makanan sisa → orang di dekatnya → PawonFood menghubungkan → makanan diambil, bukan dibuang.**

> **Bedakan dua hal ini.**
> - **Iklan pembuka (bagian ini)** adalah video promosi PawonFood sendiri. Hanya ada di video pitch, tidak pernah tampil di dalam aplikasi.
> - **Fitur iklan dalam aplikasi** (pasca-MVP) adalah iklan layar penuh dari sponsor FMCG ramah lingkungan yang muncul setelah penerima mengirim ulasan, berlabel "Iklan", dengan hitung mundur 5 detik. Itu sumber pendapatan PawonFood. Jangan campur keduanya di video: jangan menyebut iklan pembuka sebagai "fitur iklan kami".

**Aturan visual untuk semua shot** (dari DESIGN_SYSTEM.md)

- Warna: hijau #2F5D39, hijau tua #203D27, krem #FAF6ED, terakota #B15732 (hanya untuk urgensi), latar kamera #111A15.
- Huruf: Bricolage Grotesque untuk judul, Inter untuk teks kecil. Keduanya ada di `app/assets/fonts/`.
- Gerak: tenang dan menjelaskan perubahan. Teks muncul naik 12 px sambil fade, 220–320 ms, kurva easeOutCubic. Tanpa confetti, tanpa efek dekoratif. Elemen kecil yang "pop" mulai dari 50–60% ukuran, bukan dari nol.
- Teks di layar maksimal 6 kata per baris, tampil minimal 1,5 detik.

## Shot A1: Masalah (00:00–00:04)

- **Komposisi:** dapur kos malam hari. Panci sayur lodeh, piring ayam goreng, dan nasi di atas meja, sebagian ditutup plastik. Cahaya hangat dari satu lampu, sekelilingnya gelap. Di kanan bawah ada ilustrasi tempat sampah.
- **Animasi dan kamera:** dorong masuk pelan (zoom 100% → 112% selama 4 detik). Pada 00:02,0 makanan miring 12° ke arah tempat sampah yang masuk dari kanan.
- **Teks di layar:**
  - 00:00,5–00:02,0: `Masih enak.`
  - 00:02,0–00:04,0: `Hampir dibuang.` ("Hampir dibuang." berwarna terakota)
- **Transisi:** match cut. Piring bulat menyusut ke tengah dan berubah jadi mangkuk kosong di A2.
- **Suara:** musik masuk di 00:00 hanya dengan satu instrumen (kalimba atau marimba, nada jarang). Efek suara: dengung dapur pelan, lalu bunyi plastik berkerut di 00:02,0.
- **Aset:** `app/assets/images/food/lodeh.jpg`, `ayam.jpg`, `campur.jpg`. Ilustrasi tempat sampah (buat dengan generator gambar atau ikon vektor).
- **Cara membuat:** minta Claude menulis prompt gambar untuk "dapur kos malam, panci lodeh, cahaya hangat, gaya ilustrasi datar, palet krem dan hijau tua", atau pakai foto makanan di atas langsung. Di editor (CapCut/Canva/DaVinci), susun foto di satu layer, beri keyframe skala 100→112%, tambahkan ilustrasi tempat sampah sebagai layer terpisah yang di-slide dari kanan.

## Shot A2: Peluang (00:04–00:08)

- **Komposisi:** kamar kos di sebelah. Anak kos duduk di meja belajar, laptop terbuka, mangkuk kosong di samping. Orang itu melihat ponsel, lalu jam dinding menunjukkan malam. Warna dingin dan redup, kontras dengan A1.
- **Animasi dan kamera:** geser pelan dari kiri ke kanan (pan 3%). Lampu ponsel menyala di wajah pada 00:06,0.
- **Teks di layar:**
  - 00:04,5–00:06,0: `Di kos sebelah,`
  - 00:06,0–00:08,0: `ada yang cari makan malam.`
- **Transisi:** latar bergeser dari gelap ke krem #FAF6ED lewat wipe naik dari bawah, bersamaan dengan layar ponsel yang naik ke tengah (jadi A3).
- **Suara:** musik menambah satu lapis (bass lembut) di 00:04. Efek: ketukan jari di meja 00:05, notifikasi ponsel "ting" di 00:06,0.
- **Aset:** ilustrasi atau foto anak kos. Kalau memakai foto anggota tim, wajib ada izin tertulis. Tanpa foto orang, ilustrasi vektor sederhana sudah cukup.
- **Cara membuat:** minta Claude menyusun prompt ilustrasi "anak kos di meja belajar, malam, melihat ponsel, gaya datar, palet dingin". Di editor, pisahkan orang, meja, dan jam jadi layer. Animasi jam dan sinar ponsel cukup dengan fade.

## Shot A3: Memperkenalkan PawonFood (00:08–00:13)

- **Komposisi:** latar krem. Satu ponsel di tengah. Di kiri ada label kecil `Penyedia`, di kanan `Penerima`. Layar ponsel diambil dari rekaman aplikasi asli.
- **Animasi dan kamera:**
  - 00:08,0–00:10,0: layar kamera (latar #111A15). Kotak hijau muda berlabel `Lauk matang`, status `Makanan terdeteksi, siap difoto`. Kilatan rana di 00:09,0.
  - 00:10,0–00:11,5: layar isian `Semua sudah diisi. Cek sebentar, lalu bagikan.` Tombol `Bagikan sekarang` ditekan (mengecil ke 0,97).
  - 00:11,5–00:13,0: layar Peta. Pin `Rp5.000` dan `Gratis`, lingkaran putus-putus radius 1 km, kartu bawah `300 m · ± 4 mnt jalan kaki`.
- **Teks di layar:**
  - 00:08,5: `PawonFood` (judul besar, hijau)
  - 00:09,5–00:11,5: `Foto. Dicek AI. Tayang.`
  - 00:11,5–00:13,0: `Ditemukan dalam 1 km.`
- **Transisi:** layar ponsel di-cross-fade ke layar chat di A4, ponsel tetap di tempat.
- **Suara:** musik penuh masuk di 00:08 (drum ringan, 120 BPM). Efek: rana kamera di 00:09,0, klik tombol di 00:11,0, "pop" kecil saat pin muncul.
- **Aset:** rekaman layar aplikasi Flutter (layar kamera, isi form, peta). Bingkai ponsel dari Figma atau mockup gratis.
- **Cara membuat:** jalankan aplikasi (lihat `app/README.md`), rekam layar 1080×2340 untuk tiga layar itu, lalu tempel ke bingkai ponsel di editor. Minta Claude menyusun daftar keyframe (waktu, posisi, skala) dari blueprint ini untuk ditempel ke editor.

## Shot A4: Penyelamatan (00:13–00:17)

- **Komposisi:** ponsel tetap di tengah, layar chat. Kartu hijau muda `Tawaran Rp4.000 diterima`, tombol `Pindai QR`. Setelah tombol ditekan, layar pemindai (corner viewfinder diam).
- **Animasi dan kamera:**
  - 00:13,0–00:14,5: kartu muncul, `Pindai QR` ditekan.
  - 00:14,5–00:15,0: pemindai, garis hijau menyapu sekali.
  - 00:15,0–00:17,0: hijau #2F5D39 memenuhi layar dari ikon centang (±0,4 detik), centang krem tergambar, lalu teks `Makanan terselamatkan!`. Sesuai aturan gerak aplikasi, ini satu-satunya gerakan layar-penuh.
- **Teks di layar:**
  - 00:13,5: `Pesan. Ambil. Pindai QR.`
  - 00:15,5: `Makanan terselamatkan!` (teks aplikasi)
  - Sepanjang shot, kecil di kiri bawah: `Simulasi prototipe`
- **Transisi:** warna hijau penuh bertahan, tanpa jeda, jadi latar logo di A5.
- **Suara:** bunyi pemindaian "bip" pendek di 00:14,6, lalu satu dentang lembut (ring) di 00:15,2 saat centang tergambar. Musik naik satu lapis.
- **Aset:** rekaman layar chat, pemindai, dan layar sukses dari aplikasi.
- **Cara membuat:** rekam alurnya di aplikasi (QR dan pemindaian disimulasikan di versi demo, jadi tetap beri keterangan `Simulasi prototipe`). Jangan menampilkan layar QRIS atau kata "Lunas": pembayaran di MVP adalah tunai saat ambil.

## Shot A5: Merek (00:17–00:20)

- **Komposisi:** latar hijau tua #203D27. Logo tungku di tengah, wordmark `PawonFood` di bawahnya, lalu tagline dan slogan.
- **Animasi dan kamera:**
  - 00:17,0–00:17,8: logo membesar dari 60% ke 100% sambil fade.
  - 00:17,8–00:18,5: tagline `Hyperlocal Community Food Rescue Platform` (kecil, Inter).
  - 00:18,5–00:19,7: slogan dua baris, muncul berurutan.
  - 00:19,7–00:20,0: hijau menyapu turun, menyingkap Pembicara 1.
- **Teks di layar:**
  - `PawonFood`
  - `Hyperlocal Community Food Rescue Platform`
  - `Dari dapur ke komunitas.`
  - `Masak kebanyakan? Bagikan, jangan buang.`
- **Transisi ke pitch:** sapuan hijau turun di 00:19,7 menyingkap kamera Pembicara 1 di latar krem, tepat di ketukan terakhir.
- **Suara:** swell naik 00:17–00:19, satu nada penutup di 00:19,7, lalu musik turun ke -18 dB di bawah suara Pembicara 1.
- **Aset:** `app/assets/images/brand/logo_tungku.svg`, `wordmark.png`.
- **Cara membuat:** tempatkan SVG logo di layer vektor, animasikan skala dan opasitas. Teks slogan persis seperti di atas, jangan diubah.

---

# BAGIAN B: Pitch langsung (00:20–01:48)

Tiga pembicara menghadap kamera di latar polos (krem atau hijau tua). Gaya bicara tegas dan hangat, bukan membaca. Target 2,0–2,6 kata per detik. Rekaman layar aplikasi dipakai sebagai B-roll dengan wajah pembicara di sudut kanan bawah (±25% layar).

## B1. Pembicara 1: Masalah (00:20–00:46, 26 detik)

Lower third di 00:21: `[Nama Pembicara 1] · [Peran]`.

| Waktu | Naskah ucapan | Visual dan overlay | Arahan |
| --- | --- | --- | --- |
| 00:20–00:27 | Menurut kajian Bappenas, Indonesia kehilangan dan membuang 23 sampai 48 juta ton pangan setiap tahun. | Angka `23–48 juta ton / tahun` muncul besar. Sumber kecil: `Bappenas, 2021 (periode 2000–2019)` | Mulai langsung, jangan menunggu. Tekankan "setiap tahun". |
| 00:27–00:33 | Di tahap konsumsi, sekitar 80 persennya datang dari rumah tangga. Dapur kos, dapur rumah, warung. | Foto `lodeh.jpg`, `campur.jpg` bergantian, tiga kata terakhir muncul satu per satu | Tiga kata terakhir pelan, satu-satu. |
| 00:33–00:40 | Padahal anak kos di dekat kampus sedang mencari makan malam yang terjangkau. Mereka bertetangga, tapi tidak bertemu. | Dua ilustrasi (dapur dan kamar kos) berdampingan, garis putus-putus belum tersambung | Jeda sebentar sebelum "tapi tidak bertemu". |
| 00:40–00:46 | Masalah terbesarnya: orang asing hanya mau berbagi makanan kalau saling percaya. | Kata `Percaya` muncul di tengah layar | Lambatkan. Ini jembatan ke solusi, tahan satu ketukan setelah kalimat. |

## B2. Pembicara 2: Solusi dan demo (00:46–01:22, 36 detik)

Lower third di 00:47: `[Nama Pembicara 2] · [Peran]`. Selama demo (00:52–01:15) ada caption kecil `Prototipe · data contoh`.

| Waktu | Naskah ucapan | Visual dan overlay | Arahan |
| --- | --- | --- | --- |
| 00:46–00:52 | PawonFood menghubungkan keduanya, dalam jarak jalan kaki. Satu aplikasi, dua sisi dapur. | Garis putus-putus dari B1 tersambung, muncul logo kecil di tengah | Senyum, nada naik. |
| 00:52–01:00 | Penyedia memotret makanannya lewat kamera aplikasi. YOLO di ponsel memeriksa fotonya, jadi foto dari internet atau benda bukan makanan ditolak. | Rekaman layar kamera dengan kotak `Lauk matang` dan `Makanan terdeteksi, siap difoto` | Sebut "kamera aplikasi" jelas: tidak ada unggah dari galeri. |
| 01:00–01:07 | Makanan tampil di beranda dan peta, dalam radius satu kilometer. Gratis, harga terjangkau, atau bisa ditawar lewat chat. | Rekaman Beranda dan Peta (pin `Rp5.000`, `Gratis`), lalu chip penawaran `Rp3.000 / Rp4.000` | Tunjuk ke layar bila bisa. |
| 01:07–01:15 | Penerima memesan, lalu mengambil sebelum batas waktu dan memindai QR penyedia untuk konfirmasi. Makanan terselamatkan! | Rekaman `Pindai QR`, lalu layar sukses `Makanan terselamatkan!` | Tekanan di kata "terselamatkan". Beri jeda pada animasi hijau. |
| 01:15–01:22 | Ini prototipe dengan data contoh, pemeriksaan fotonya masih simulasi. AI membantu memeriksa foto, bukan menjamin makanan aman. | Caption `Prototipe · data contoh`, wajah pembicara kembali ke tengah layar | Jujur dan tenang. Kalimat ini menjawab pertanyaan keamanan pangan sebelum juri bertanya. |

## B3. Pembicara 3: Pembeda, model, tujuan (01:22–01:48, 26 detik)

Lower third di 01:23: `[Nama Pembicara 3] · [Peran]`.

| Waktu | Naskah ucapan | Visual dan overlay | Arahan |
| --- | --- | --- | --- |
| 01:22–01:32 | Surplus fokus menyelamatkan croissant dari bakery mewah. PawonFood fokus menyelamatkan sayur lodeh sisa masak ibu kos dan lauk warteg untuk anak kos di akhir bulan. | Dua gambar berdampingan: croissant (abu-abu) dan `lodeh.jpg` (berwarna). Kata `Dapur rumah` disorot hijau | Ini kalimat terkuat. Pelan, dengan senyum di "sayur lodeh". |
| 01:32–01:39 | PawonFood tidak memungut biaya dari penyedia maupun penerima. Rencana pendapatan kami: iklan merek ramah lingkungan. | Teks `Biaya platform: Rp0` dan `Iklan merek ramah lingkungan (rencana)` | Jelas dan datar, seperti fakta. |
| 01:39–01:48 | Kami mulai dari Pogung, Sleman, lalu Yogyakarta, untuk ikut menjawab dua tujuan: nol kelaparan dan konsumsi yang bertanggung jawab. | Peta Pogung dengan radius 1 km yang melebar ke Yogyakarta. Ikon SDG 2 dan SDG 12 | Nada naik, hubungkan ke penutup bersama. |

---

# BAGIAN C: Penutup tim dan end card (01:48–02:00)

## C1. Penutup bersama (01:48–01:54, 6 detik)

Ketiga pembicara berdiri dalam satu bingkai. Masing-masing mengucapkan satu bagian slogan, tanpa jeda antar-baris.

| Waktu | Naskah ucapan | Visual dan overlay | Arahan |
| --- | --- | --- | --- |
| 01:48–01:50 | Pembicara 1: "Dari dapur ke komunitas." | Bingkai tiga orang, teks slogan muncul baris 1 | Mantap, menoleh ke kamera. |
| 01:50–01:52 | Pembicara 2: "Masak kebanyakan?" | Baris 2 | Alis naik, seperti bertanya. |
| 01:52–01:54 | Pembicara 3: "Bagikan, jangan buang." | Baris 3 | Menutup dengan senyum. |

## C2. End card (01:54–02:00, 6 detik)

- **Visual:** latar hijau tua #203D27. Logo tungku, wordmark `PawonFood`, slogan lengkap `Dari dapur ke komunitas. Masak kebanyakan? Bagikan, jangan buang.`, di bawahnya `[Nama tim] · [Universitas]` dan `[Email tim]`.
- **Gerak:** sama dengan A5, logo muncul dari 60% sambil fade. Tahan diam selama 3 detik terakhir.
- **Suara:** musik naik singkat di 01:54, fade out ke senyap di 02:00. Tanpa suara bicara.

---

# Catatan produksi

- **Musik:** instrumental hangat (akustik atau lo-fi), 120 BPM, bebas royalti. Cek lisensinya sebelum dipakai di lomba. Volume musik -18 dB selama pembicara bicara, naik di A dan C.
- **Pembicara:** latar polos krem atau hijau tua. Cahaya depan dari samping (jendela atau lampu), hindari backlight. Mikrofon klip atau mikrofon terpisah, jangan mikrofon kamera.
- **Rekam suara dulu:** baca naskah dengan stopwatch. Jika satu bagian melebihi waktunya lebih dari 1 detik, pangkas kata, jangan dipercepat.
- **Pergantian pembicara:** potong di jeda napas, hindari transisi bergaya. Tiga pembicara, tiga potongan tegas.
- **Rekaman layar aplikasi:** gunakan demo bawaan (akun demo ada di `app/README.md`). Rekam di perangkat atau emulator 1080×2340.
- **Subtitle:** pasang subtitle Indonesia. Banyak juri menonton tanpa suara.

# Yang perlu dikonfirmasi tim sebelum rekaman

1. **Status YOLO.** Naskah B2 menyebut "YOLO di ponsel memeriksa fotonya" lalu mengakui "pemeriksaan fotonya masih simulasi". Menurut CLAUDE.md, pemeriksaan foto di aplikasi saat ini simulasi (model sebenarnya dari `/ml`). Kalau model sudah terpasang saat rekaman, ubah kalimat jadi "sudah berjalan dengan dua kelas".
2. **Nama pembicara, peran, nama tim, universitas, email.** Semua masih placeholder.
3. **Kutipan Bappenas.** Angka 23–48 juta ton dan 80% (tahap konsumsi) dari PRD_PawonFood.md, laporan Bappenas 2021. Cek ulang angka di sumber sebelum dibacakan.
4. **Foto orang.** Kalau A2 memakai foto, wajib ada izin. Alternatifnya, pakai ilustrasi.
5. **Lisensi musik dan efek suara.**

# Daftar cek akurasi

Jangan sampai terucap atau tertulis:

- [ ] "sudah diluncurkan", "sudah dipakai ribuan orang", atau klaim produk jadi. Yang ada: prototipe dengan data contoh.
- [ ] "aman dimakan", "terjamin aman", atau "AI menjamin keamanan pangan". Yang benar: AI membantu memeriksa foto.
- [ ] Angka dampak tanpa data (kg terselamatkan, emisi berkurang). SDG 2 dan 12 disebut sebagai tujuan, bukan hasil.
- [ ] "aplikasi makanan murah", "diskon", "marketplace". PawonFood adalah jaringan penyelamatan makanan.
- [ ] Label "orang miskin", "kurang mampu", atau "yang membutuhkan" untuk penerima. Penerima adalah tetangga yang mencari makan.
- [ ] Pembayaran dalam aplikasi atau QRIS sebagai fitur aktif. MVP: tunai saat ambil. QRIS hanya simulasi pasca-MVP.
- [ ] QR yang tampak seperti layanan produksi. Selalu beri caption `Simulasi prototipe`.
- [ ] "Borjuis". Tingkat pengguna: Pawon Friend, Pawon Elite, Pawon Hero.
- [ ] Teks di layar yang berbeda dari aplikasi. Teks UI harus sama persis dengan aplikasi.
