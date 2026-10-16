# PRD PawonFood

Dokumen ini menurunkan konsep di [CONCEPT.md](reference/CONCEPT.md) menjadi kebutuhan produk dan spesifikasi yang bisa langsung dikerjakan tim.

Sumber lain: [Product.md](reference/Product.md), [Evaluasi Ide Aplikasi PawonFood.md](<reference/Evaluasi%20Ide%20Aplikasi%20PawonFood.md>), `PawonFood UI apps.pdf` (layar aplikasi), dan `PawonFood UI.pdf` (landing page).

## Ringkasan

PawonFood mempertemukan dapur rumah tangga, warung, dan komunitas yang punya makanan lebih dengan warga dalam radius 1 km. Makanan bisa dijual murah, ditawar, atau diberikan gratis. Pembeli mengambil sendiri dengan jalan kaki atau minta diantar oleh penjualnya.

Bedanya dengan GoFood dan ShopeeFood: tidak ada MoU, tidak ada komisi, dan siapa pun bisa mulai jualan dari dapur rumah dengan memotret makanannya. Bedanya dengan Surplus atau DamoGO: penjualnya bukan hanya restoran dan toko roti, tapi juga rumah tangga.

- Tagline: "Hyperlocal Social Cloud Kitchen & Community Food Marketplace"
- Slogan: *Dari dapur rumah tangga ke komunitas. Masak lebih? Jual dan bagikan tanpa ribet.*
- Peran pengguna: satu akun bisa menjadi penerima (pembeli) dan penyedia (penjual).
- Lokasi uji coba: Pogung, Sleman (dekat UGM), lalu Yogyakarta.
- Konteks: dibuat untuk hackathon keberlanjutan UGM, terkait SDG 2, SDG 8, dan SDG 12.

Tujuan produk ada dua: membuat orang bisa jualan makanan dari rumah tanpa birokrasi, dan mengurangi makanan layak yang berakhir di tempat sampah.

## Masalah

**Jualan di aplikasi pesan-antar terlalu berat untuk dapur rumahan.** Ibu kos atau mahasiswa yang masak 5–10 porsi lebih per hari harus melewati MoU, verifikasi yang lama, jam buka tetap, dan komisi 20–30%. Untuk pembeli yang tinggal 500 meter dari dapur, ongkir kurir membuat harga akhirnya tidak masuk akal.

**Sampah makanan rumah tangga besar.** Menurut [kajian Bappenas (2021)](https://greeneconomy.bappenas.go.id/home/books/laporan-kajian-food-loss-and-waste-in-indonesia-dalam-rangka-mendukung-penerapan-ekonomi-sirkular-dan-pembangunan-rendah-karbon/), Indonesia menghasilkan 23–48 juta ton *food loss and waste* per tahun pada 2000–2019, atau 115–184 kg per orang. Kerugiannya Rp213–551 triliun per tahun (4–5% PDB) dengan emisi 1.702,9 Mt CO₂e, sekitar 7,29% emisi gas rumah kaca nasional. Jumlah itu cukup untuk memberi makan 61–125 juta orang. Tahap konsumsi menyumbang 5–19 juta ton per tahun, dan 80% di antaranya berasal dari rumah tangga. Karena itu dapur rumah tangga jadi sasaran pertama PawonFood.

**Di sekitar kampus, pasokan dan permintaan sudah ada tapi tidak bertemu.** Rumah tangga, warung, katering, dan ibu kos sering membuang sisa masakan yang masih layak. Di sisi lain, anak kos butuh makanan rumahan murah, banyak yang tidak punya kendaraan, dan enggan membayar ongkir untuk jarak di bawah 1 km.

**Belum ada yang melayani penjual rumahan.** Surplus dan DamoGO hanya menerima restoran dan toko roti, dengan harga tetap dan wajib ambil sendiri. Garda Pangan mengandalkan relawan dan logistik manual. Belum ada layanan C2C untuk dapur rumah tangga yang tanpa MoU dan menyediakan opsi antar.

**Masalah utamanya adalah kepercayaan.** Tanpa kontrak, pembeli dan penjual adalah orang asing. Transaksi hanya terjadi kalau pembeli yakin makanannya asli dan aman, dan serah terimanya jelas. Sebagian besar fitur di dokumen ini ada untuk menjawab masalah itu.

## Pengguna

| Pengguna | Kebutuhan | Peran |
| :--- | :--- | :--- |
| Rumah tangga, ibu kos, mahasiswa yang memasak | Masak kebanyakan atau ingin jualan dari rumah tanpa MoU dan komisi | Penyedia |
| Warung, warteg, burjo, katering, toko roti | Punya stok harian yang masih layak tapi belum laku | Penyedia |
| Komunitas | Punya sisa konsumsi acara atau dapur umum | Penyedia |
| Anak kos dan warga sekitar | Makanan murah yang bisa diambil jalan kaki atau diantar dengan ongkir kecil | Penerima |
| Panti asuhan dan komunitas sosial | Makanan gratis atau murah | Penerima |

Setelah uji coba, segmen penerima dibuka untuk siapa saja dengan anggaran makan terbatas.

## Konsep Produk

### Kategori makanan

| Key | Label di UI | Isi | Di MVP |
| :--- | :--- | :--- | :--- |
| `makanan_matang` | Lauk matang | Makanan siap santap: nasi goreng, lauk harian, sisa masakan yang masih layak | Ya |
| `bahan_mentah` | Bahan mentah | Sayur yang belum dipotong, bahan masakan mentah | Ya |
| `sealed_food` | Makanan kemasan | Makanan dalam kemasan tersegel | Belum |
| `bukan_makanan` | – | Ditolak otomatis oleh validator foto | Ya |

### Kemasan

Satu pilihan per listing, terpisah dari kategori: lauk matang pun bisa diambil dengan wadah sendiri. Penyedia memilihnya di form Bagikan.

| Key | Label di UI | Artinya | Antar |
| :--- | :--- | :--- | :--- |
| `dibungkus` (default) | Sudah dibungkus | Makanan sudah dibungkus, penerima tinggal membawa pulang | Boleh |
| `wadah_sendiri` | Bawa wadah sendiri | Penerima membawa wadah bersih sendiri. Mengurangi kemasan sekali pakai. | Tidak. Antar hanya untuk makanan yang sudah dibungkus. |

- Makanan kemasan selalu *Sudah dibungkus*, jadi pilihan ini tidak muncul untuknya.
- Memilih *Bawa wadah sendiri* mematikan *Bisa diantar* di form (dengan keterangan alasannya), dan listing yang sudah tayang tidak bisa memuat keduanya.
- Penerima dilihatkan pilihan ini di kartu makanan, detail, sheet tawaran, kartu reservasi di chat, dan rute ke titik ambil.

### Harga

| Metode | Di UI | Aturan |
| :--- | :--- | :--- |
| Gratis | Toggle "Gratis", harga tampil "GRATIS" | Harga Rp0. Poin dampak untuk penyedia paling besar. |
| Harga tetap | "Jual murah", harga per porsi | Harga > Rp0. Harga normal ditampilkan dicoret sebagai pembanding. |
| Nego | Checkbox "Boleh ditawar", chip "Tawar cepat" | Penerima mengajukan harga lewat chat, penyedia menerima atau menolak. |

### Serah terima

| Metode | Di UI | Aturan |
| :--- | :--- | :--- |
| Ambil sendiri | Pill "Ambil sendiri" (default) | Penerima datang ke titik temu sebelum batas waktu. Tanpa ongkir. |
| Diantar penjual | "Bisa diantar" (penyedia), "Minta diantar" (penerima) | Hanya muncul kalau penyedia mengaktifkannya. Penyedia mengantar sendiri ke alamat penerima dalam radius 1 km. Ongkir dipilih penyedia (Rp0, Rp2.000, atau Rp3.000) dan seluruhnya untuk penyedia. |

PawonFood tidak memungut biaya apa pun dari kedua pihak. Harga makanan dan ongkir sepenuhnya milik penyedia.

## Alur Utama

| # | Langkah | Fitur |
| :--- | :--- | :--- |
| 1 | Penyedia punya makanan lebih untuk dijual atau dibagikan | Bagikan (fitur 2) |
| 2 | Aplikasi memeriksa foto, lalu penyedia mengisi batas waktu dan opsi antar | Validasi foto, batas waktu, opsi antar, pernyataan penyedia |
| 3 | Warga sekitar melihat makanan di Beranda atau Peta | Feed Beranda, Peta radius 1 km |
| 4 | Penerima mengambil gratis, membeli, atau menawar | Metode harga |
| 5 | Penerima memilih ambil sendiri atau diantar, lalu reservasi | Reservasi (fitur 6) |
| 6 | Serah terima di titik temu atau di depan kos penerima | Titik temu / alamat antar |
| 7 | Penerima memindai QR milik penyedia | Reservasi (fitur 6) |
| 8 | Listing ditutup dengan status `picked_up` | – |
| 9 | Penyedia menerima uang dan poin dampak | Profil (fitur 8) |
| 10 | Porsi terselamatkan tercatat di statistik | Statistik dampak |

## Risiko dan Cara Menanganinya

Baris bertanda **Usulan** belum diatur di dokumen konsep dan masih perlu disetujui.

| Aspek | Risiko | Penanganan |
| :--- | :--- | :--- |
| Pasokan | Penyedia malas mengunggah kalau prosesnya lama | Tanpa MoU. Unggah lewat kamera, paling banyak 3 ketukan. Terbuka untuk rumah tangga, usaha kuliner, dan komunitas. |
| Penemuan | Penerima tidak mau menggulir lama untuk menemukan yang cocok | Feed Beranda diurutkan berdasarkan riwayat klik, lama melihat, kategori, dan dapur yang sering dibuka. |
| Jarak | Makanan yang tampil ternyata terlalu jauh | Feed dan peta dibatasi 1 km. Filter kategori, hangat, gratis, dan "Bisa diantar". |
| Kepercayaan | Orang tidak mau mengambil makanan dari orang asing | Foto wajib dari kamera dan dicek otomatis, pernyataan kelayakan dari penyedia, persetujuan ToS dari penerima, rating, suspensi, dan blokir akun. |
| Serah terima | Proses ambil/antar membingungkan atau rawan | Reservasi dengan batas waktu, pilihan ambil atau antar, dan konfirmasi wajib lewat pindai QR. |
| Harga | Aplikasi terasa seperti pasar diskon | Pilihan gratis, harga tetap, atau tawar. Tanpa komisi. Biaya operasional ditutup iklan. |
| Privasi | Alamat rumah atau kos terlihat orang asing | **Usulan:** listing hanya menampilkan nama area dan jarak. Titik temu atau alamat kos baru terlihat setelah reservasi diterima. |
| Rasa malu | Penerima sungkan mengambil makanan gratis | **Usulan:** listing gratis tampil sama seperti listing berbayar, tanpa label "bantuan" atau "amal". Penerima juga mendapat poin. |
| Tidak diambil | Makanan yang sudah dipesan tidak diambil dan akhirnya terbuang | **Usulan:** reservasi batal otomatis setelah batas waktu dan porsinya dibuka lagi. Pelanggaran berulang menurunkan rating dan prioritas penerima. |

## Fitur

Setiap fitur di bawah mengacu ke layar di `PawonFood UI apps.pdf`.

### 1. Beranda

- Header: lokasi ("Lokasi kamu · Pogung, Sleman", bisa diketuk untuk mengganti, termasuk "Gunakan lokasi saat ini" lewat GPS) dan jumlah poin ("150 Poin").
- Judul "Lapar? Masih ada yang hangat di dekatmu." dan kolom cari ("Cari lauk, nasi, roti..."). Mengetuk kolom cari membuka halaman **Pencarian**: "Pencarian terakhir" (8 kata terakhir, bisa dihapus satu per satu) dan "Populer di sekitarmu" (kata yang cocok dengan listing yang terlihat di radius). Memilih kata menyaring feed Beranda; tombol ✕ di kolom cari menghapus saringan.
- Chip kategori (berbahasa Inggris): *All*, *Ready-to-Eat*, *Fresh Ingredient*, *Sealed Food* (setelah MVP). Pilihan chip ikut berlaku di Peta. Setelah chip kategori ada pemisah tipis dan chip *Sudah dibungkus* (juga di Peta, satu pilihan bersama): hanya listing yang sudah dibungkus. Filter jarak, hangat, gratis, bisa diantar, dan sudah dibungkus ada di halaman Semua Makanan.
- Mini-map: radius 1 km, posisi pengguna, 3–5 penyedia terdekat, dan tombol "Lihat peta penuh".
- Feed "Pilihan untukmu di sekitar", dengan tautan *Semua* ke halaman Semua Makanan (judul "Segera habis di sekitarmu"; filter *Bisa jalan kaki*, *Sedang hangat*, *Makan gratis*; urutan *Rekomendasi* atau *Segera habis*). Tiap kartu berisi foto, "Sisa N porsi", **satu label** di foto, ikon antar (jika aktif), ikon wadah (jika *Bawa wadah sendiri*), nama makanan, nama dan level penyedia, harga coret atau GRATIS, dan jarak.
- Label kartu, dipilih dengan urutan ini: *Hampir habis* (sisa 1 porsi), *Segar* (bahan mentah segar), *Sehat* (skor pilihan sehat ≥ 0,5), *Populer* (penyedia Pawon Hero), *Terbaru* (dimasak kurang dari 60 menit lalu).

**Urutan feed.** Aplikasi mencatat klik kartu, membuka detail lebih dari 3 detik, menekan *Ambil* atau menawar, dan transaksi selesai. Urutan kartu dihitung dengan:

```
skor = afinitas pengguna × kedekatan jarak × urgensi batas waktu
```

Afinitas berasal dari model rekomendasi ALS yang dijalankan di server FastAPI (`ml/fyp/`). Aplikasi mengirim tiga sinyal ke server: `view` (detail dibuka 3 detik), `addtocart` (*Ambil* atau tawaran), dan `transaction` (QR berhasil dipindai). Listing yang tidak dikenal model, misalnya makanan yang baru dibagikan, mendapat afinitas netral. Tanpa server rekomendasi, feed hanya memakai kedekatan jarak dan urgensi batas waktu.

### 2. Bagikan makanan (tombol tengah)

Paling banyak 3 ketukan dari membuka kamera sampai listing tayang.

**Langkah 1 – Kamera.** Pratinjau kamera polos, tanpa kotak deteksi atau garis pindai. Foto hanya bisa diambil dari kamera, tidak dari galeri. Ada tips foto dan tombol balik kamera. Tombol rana mengambil foto dan langsung membuka form; pengecekan AI berjalan di latar belakang.

**Langkah 2 – Cek sebelum tayang.** Teks: "Semua sudah diisi. Cek sebentar, lalu bagikan."
- Kategori, nama makanan, deskripsi, dan tag *Pilihan sehat* (Sayur/buah, Protein, Tidak digoreng, Rendah gula) terisi otomatis dari hasil cek AI begitu hasilnya datang. Kategori bisa diganti lewat *Ubah*. Isian yang sudah diubah penyedia tidak pernah ditimpa. Tag Pilihan sehat menggambarkan komposisi, bukan keamanan.
- Hasil cek AI menentukan apakah listing boleh tayang:

  | Hasil | Tampilan di form | Boleh tayang? |
  | :--- | :--- | :--- |
  | Lolos | "Foto lolos validasi", isian terisi | Ya |
  | Perlu tinjauan | "Menunggu tinjauan manual" dan "Catatan AI"; kategori yang tidak dikenal dipilih penyedia | Ya, setelah kategori dipilih |
  | Foto kurang jelas | "Foto belum lolos", kotak "Foto kurang jelas", tombol *Foto ulang* | Tidak |
  | Ditolak | Bukan makanan (orang, benda, layar, foto dari foto) | Tidak |
  | Pemeriksaan gagal | "Pemeriksaan AI gagal", tombol *Coba lagi* dan *Foto ulang* | Tidak. Kegagalan tidak pernah dianggap lolos. |

- Nama makanan dan jumlah porsi ("Sisa berapa porsi?").
- *Kemasan*: *Sudah dibungkus* (default) atau *Bawa wadah sendiri*, dengan satu baris keterangan. Tidak muncul untuk makanan kemasan. Memilih *Bawa wadah sendiri* mematikan *Bisa diantar* ("Antar hanya untuk makanan yang sudah dibungkus.").
- Pilihan Gratis atau Jual murah, harga per porsi, dan checkbox "Boleh ditawar".
- Serah terima: *Ambil di tempat* (aktif secara default) dan *Bisa diantar (< 1 km)*. Kalau antar diaktifkan, penyedia memilih ongkir Rp0, Rp2.000, atau Rp3.000. Minimal salah satu dari keduanya harus aktif.
- Batas waktu: tiga pilihan jam, atau *Atur jam* untuk jam sendiri (paling cepat 30 menit dan paling lambat 6 jam dari sekarang).
- Untuk bahan mentah, penyedia bisa melampirkan **ide resep** dari pustaka resep aplikasi. Resep ini tampil di detail sebagai "Diverifikasi pemberi".
- Titik temu diambil dari profil (misal "Kos Melati, Pogung") dan bisa diganti khusus untuk listing ini. Penerima baru melihat titik ini setelah reservasi disetujui.
- Pernyataan: "Dengan membagikan, kamu menjamin makanan ini masih layak makan."
- Tombol "Bagikan sekarang".

**Langkah 3 – Selesai.** Konfirmasi bahwa listing sudah tayang.

### 3. Detail makanan

- Membuka halaman ini dicatat sebagai klik, beserta lama melihatnya, untuk urutan feed.
- Foto dengan label "Sisa 2 porsi" dan "Foto asli, dicek AI".
- Foto profil, nama, level, dan rating penyedia.
- Info singkat: jarak (300 m, jalan kaki), batas ambil (20.30 hari ini), kategori, baris **Kemasan** ("Sudah dibungkus · Bisa langsung dibawa pulang" atau "Bawa wadah sendiri · Siapkan wadah bersih untuk makanan ini"), dan tag *Pilihan sehat* ("Diisi oleh pemberi, dibantu AI.").
- Harga: ~~Rp15.000~~ Rp5.000, dengan label "Bisa ditawar".
- Pilihan *Ambil sendiri (Rp0)* atau *Minta diantar (+ongkir)*, kalau penyedia membuka opsi antar.
- Chip "Tawar cepat": Rp3.000, Rp4.000, atau *Tulis sendiri*. *Tulis sendiri* membuka bottom sheet berisi harga tawaran per porsi, jumlah porsi (maksimal sisa stok), pilihan ambil/antar, *Tawar ongkir* (kalau minta diantar: chip dari ongkir penyedia turun per Rp1.000 sampai *Gratis*), dan pesan opsional. Tawaran harus di atas Rp0 dan di bawah harga jual; kalau ongkirnya ikut ditawar, harga makanan boleh sama dengan harga jual. Ongkir tawaran tidak boleh di atas ongkir penyedia. Tawaran masuk ke chat dengan status "Menunggu jawaban". Porsi baru dikunci setelah penyedia menerima.
- Deskripsi singkat dari penyedia tentang kondisi atau cara simpan makanan.
- **Ide resep** (hanya bahan mentah, dan tidak tampil di listing milik sendiri). Resep yang dilampirkan penyedia berlabel "Diverifikasi pemberi". Kalau penyedia tidak melampirkan, penerima tetap melihat resep pustaka yang paling cocok, berlabel "Belum diverifikasi pemberi".
- Tombol bawah: *Chat* dan *Ambil · Rp5.000*. Total berubah kalau memilih diantar.

### 4. Peta

- Header "Radius 1 km dari Pogung, Sleman" dan tombol kembali ke lokasi saya.
- Chip kategori yang sama dengan Beranda, ditambah chip *Sudah dibungkus*.
- Pin berlabel harga ("Rp5.000", "Gratis"), garis radius putus-putus, dan kartu di bawah ("300 m · ± 4 mnt jalan kaki"). Mengetuk kartu membuka detail makanan.
- Pin yang berdekatan digabung menjadi satu angka (misal "5" di Pogung).
- Mengetuk pin menggeser peta ke pin itu dan membuka **kartu pin** (foto, nama, penyedia, sisa porsi, batas ambil, harga, jarak jalan kaki) yang menggantikan daftar di bawah. Tombol ✕ atau mengetuk peta kosong menutup kartu.
- Indikator "1 km" di pojok peta membuka pilihan **Jangkauan pencarian**. Radius yang dipilih juga berlaku di Beranda; pengaturan "Radius default" ada di Pengaturan. Kalau tidak ada makanan di radius, peta menampilkan "Belum ada makanan di radius X".
- Peta dan rute memakai ubin dan router jalan kaki OpenStreetMap. Perlu internet; tanpa internet aplikasi menampilkan rute perkiraan.

### 5. Chat dan tawar-menawar

- Dua tab: *Saya menerima* dan *Saya berbagi*, masing-masing dengan jumlah pesan belum dibaca.
- Tiap percakapan menampilkan nama penyedia, makanan, harga sepakat, cara serah terima, pesan terakhir, dan status (*Tawaran diterima*, *Siap diambil*, *Habis*).
- Banner: "Tawar dan atur waktu ambil di sini saja. Jangan transfer uang di luar aplikasi sebelum makanan kamu terima."
- Di dalam chat: ringkasan makanan di atas, gelembung tawaran ("Tawaran kamu · Rp4.000 · 1 porsi · ambil jalan kaki ±4 mnt"), lalu chat biasa. Setelah diterima muncul kartu "Tawaran Rp4.000 diterima", keterangan "Bayar Rp4.000 di tempat", dan tombol "Pindai QR" untuk penerima.
- Untuk makanan *Bawa wadah sendiri*, kartu reservasi, sheet tawaran, dan rute ke titik ambil menampilkan pengingat "Bawa wadah sendiri · Siapkan wadah bersih untuk makanan ini".
- Balasan cepat: *Saya OTW*, *Masih ada?*, *Bisa diantar?*.
- Tombol *+* di kiri kolom pesan (hanya selama masih bisa menawar) membuka sheet *Tawar* dengan dua pilihan: *Tawar harga makanan* (form *Tulis tawaranmu*) dan *Tawar ongkir* (sheet kecil: chip ongkir dari ongkir penyedia turun per Rp1.000 sampai *Gratis*, harga makanan tetap). *Tawar ongkir* nonaktif dengan alasannya bila penyedia tidak mengantar, ongkirnya sudah gratis, atau alamat lebih dari 1 km. Kalau harga makanan tetap penuh dan hanya ongkir yang turun, kartu kesepakatan berjudul "Ongkir Rp2.000 disetujui".
- Kalau tawaran ditolak atau dibatalkan, chat menampilkan kartu "Tawaranmu belum diterima" dengan harga terendah dari penyedia (makanan dan ongkir), tombol sekali tap "Tawar Rp4.500 · ongkir Rp2.000", dan tombol *Tawar lagi*.

### 6. Reservasi dan serah terima

**Reservasi.** Membeli dengan harga penuh atau tawaran yang diterima akan mengunci jumlah porsi dan cara serah terima sampai batas waktu. Lewat batas waktu, reservasi batal dan porsi tersedia lagi.

**Rute.** Setelah reservasi, penerima bisa membuka rute jalan kaki ke titik ambil dari posisi GPS (atau area yang dipilih kalau GPS tidak terbaca), dengan jarak, perkiraan waktu, dan petunjuk belokan berbahasa Indonesia. Layar berpindah ke "Kamu sudah sampai" dalam jarak 30 m. Untuk pesanan antar, penyedia mendapat "Rute antar" ke alamat penerima.

**Konfirmasi QR.** Penyedia membuka QR reservasi di aplikasinya. Penerima memindainya lewat tombol "Pindai QR", baik saat mengambil di titik temu maupun saat makanan diantar ke kos. Tidak ada kode manual. Satu QR untuk satu reservasi, hanya bisa dipindai sekali, dan hanya berlaku sebelum batas waktu.

Setelah QR berhasil dipindai:
- status listing menjadi `picked_up`,
- porsi terselamatkan tercatat,
- penyedia mendapat notifikasi "diambil [nama]" dan poin dampak,
- penerima langsung masuk ke halaman ulasan.

**Cara bayar** (Figma lo-fi B10d–B10i, C17d). Muncul setelah tawaran diterima atau setelah menekan *Ambil*. Listing gratis tanpa ongkir melewati langkah ini.
- *Tunai* (default MVP): penerima kembali ke chat dan membayar tunai ke penyedia setelah memindai QR.
- *Bayar di aplikasi* (**setelah MVP, usulan**): QRIS lewat Midtrans atau Xendit. Uang ditahan PawonFood dan diteruskan utuh (harga + ongkir) ke saldo penyedia setelah QR dipindai. Kalau reservasi batal, uang kembali penuh ke penerima. Biaya QRIS ditanggung PawonFood dari pendapatan iklan. Layar dan alurnya sudah ada di aplikasi, tapi QRIS disimulasikan (cek status pertama menjawab "belum masuk", yang kedua berhasil) dan belum terhubung ke payment gateway.
- Penerima harus mencentang persetujuan kondisi makanan (lihat Keamanan Pangan) sebelum tombol bayar aktif.

### 7. Rating dan ulasan

- Penerima memberi rating setelah memindai QR. Boleh dilewati dengan tombol kembali.
- Rating penyedia ikut dihitung dalam urutan feed.
- Setelah MVP: iklan layar penuh tampil setelah penerima menekan "Kirim ulasan". Melewati ulasan tidak memunculkan iklan.
- Penyedia yang berulang kali mendapat ulasan buruk disuspensi (listing disembunyikan, tidak bisa mengunggah). Kalau berlanjut setelah suspensi, akun diblokir permanen.

### 8. Profil dan poin

- Peran dan lokasi: "Penerima dan penyedia · Pogung, Sleman".
- Level: Pawon Friend → Pawon Elite → Pawon Hero, dengan progres "340 poin lagi untuk naik ke Pawon Elite" dan langkah *Sekarang / Berikutnya / Top Impact*. Jangan memakai istilah "Borjuis" untuk level apa pun.
- Statistik "Dampak kamu": porsi dibagikan, porsi diselamatkan, kg makanan yang tidak jadi sampah.
- Poin dampak: penyedia mendapat poin saat QR dipindai (lebih banyak untuk makanan gratis). Penerima mendapat poin saat pengambilan selesai dan saat memberi ulasan.
- **Asumsi di aplikasi** (belum diputuskan tim, daftar lengkap di [app/README.md](app/README.md)): batas level 0 / 500 / 1.500 poin; penyedia +10 poin per porsi, dikali dua untuk makanan gratis, ditambah +5 untuk rating 4 ke atas; 0,5 kg makanan per porsi terselamatkan.
- Tukar poin (kategori *Belanja*, *Antar*, *Makanan*, *Sertifikat*): voucher minimarket, diskon layanan antar, voucher pulsa, potongan makanan, dan sertifikat Dapur/Resto Peduli Lingkungan. Menukar mengurangi poin dan menghasilkan kode `PWN-V-XXXX` yang berlaku 30 hari. Kode tersimpan di *Voucher saya*. Penukaran masih disimulasikan di memori.
- Sertifikat Resto Peduli Lingkungan tidak dibeli dengan poin: terbit bulanan untuk penyedia dengan minimal 30 porsi dan rata-rata rating 4,5 (asumsi aplikasi).
- Voucher *Potongan makanan* Rp3.000 atau Rp5.000 (120 dan 200 poin) dipakai di halaman bayar lewat "Pakai voucher": pilih dari *Voucher saya* atau ketik kodenya. Maksimal 1 voucher per transaksi, pembayaran minimal Rp1.000, dan voucher partner (minimarket, ojek) ditolak di sini. Voucher baru berstatus "Terpakai" saat pembayaran dikonfirmasi. Selisihnya ditanggung PawonFood, jadi penyedia tetap menerima harga penuh.
- Menu: riwayat berbagi dan mengambil, riwayat poin, titik ambil tersimpan, keamanan pangan dan persetujuan, pengaturan (notifikasi, radius default, ubah kata sandi), bantuan, syarat dan ketentuan, kebijakan privasi.
- Onboarding tiga layar tampil sekali pada peluncuran pertama di sebuah perangkat, sebelum Welcome.

### 9. Landing page (`PawonFood UI.pdf`)

Halaman web untuk menjelaskan produk, mengajak dapur bergabung sebagai penyedia, dan mengarahkan ke unduhan aplikasi. Susunan bagiannya ada di [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md#landing-page).

## Iklan (setelah MVP)

Iklan adalah sumber pendapatan utama dan yang memungkinkan PawonFood tidak mengambil komisi. Iklan belum aktif di MVP. Desain layarnya sudah ada di Figma lo-fi B11b dan B11c.

- Gambar: satu layar penuh setelah penerima mengirim ulasan, berlabel "Iklan". Tombol tutup muncul setelah 5 detik. Tombol "Pelajari" membuka tautan sponsor.
- Video (**usulan**): vertikal 9:16, maksimal 15 detik, otomatis diputar tanpa suara. Ada tombol suara dan "Lewati dalam 5".
- Aturan (**usulan**): hanya sponsor FMCG ramah lingkungan. Tidak boleh ada klaim kesehatan, alkohol, atau rokok. Maksimal 1 iklan per penerima per hari. Penyedia tidak melihat iklan. Iklan tidak pernah muncul di tengah proses pindai QR.

## Keamanan Pangan

- PawonFood adalah tempat bertemunya penjual dan pembeli, bukan produsen makanan.
- Foto harus diambil dari kamera aplikasi dan lolos cek AI. Foto dari internet atau objek yang bukan makanan ditolak.
- Cek AI hanya memastikan foto menunjukkan makanan. Cek ini tidak menilai kesegaran atau basi, dan bukan sertifikat keamanan pangan. Karena itu pernyataan kelayakan dari penyedia tetap wajib.
- Penyedia harus menyetujui pernyataan kelayakan makanan sebelum listing tayang.
- Penerima harus mencentang "Saya telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan" di halaman bayar sebelum tombol konfirmasi aktif.
- Setiap listing punya batas waktu ambil/antar supaya makanan tidak disimpan terlalu lama.
- Setiap serah terima, ambil sendiri maupun diantar, harus ditutup dengan pindai QR sebelum batas waktu.

## Model Bisnis

| Komponen | Isi |
| :--- | :--- |
| Segmen pelanggan | Penerima: anak kos, panti asuhan, warga dengan anggaran terbatas. Penyedia: rumah tangga, ibu kos, mahasiswa, warung, restoran, toko roti, komunitas. |
| Nilai yang ditawarkan | Penerima: makanan rumahan murah atau gratis di sekitar, bisa diambil jalan kaki atau diantar dengan ongkir kecil. Penyedia: bisa jualan tanpa MoU dan tanpa komisi, mengurangi makanan terbuang, dan mendapat poin serta lencana. |
| Kanal | Aplikasi Android dan iOS, Instagram dan TikTok, kerja sama BEM/HIMA, datang langsung ke kos dan warung sekitar kampus. |
| Hubungan pelanggan | Feed yang menyesuaikan kebiasaan pengguna, poin dan hadiah, rating terbuka, chat untuk tawar-menawar dan janjian. |
| Pendapatan | Utama: iklan dari brand FMCG ramah lingkungan (setelah MVP). Tambahan: *promoted listing* di posisi atas feed dan peta. Tidak ada komisi transaksi. |
| Aktivitas utama | Pengembangan aplikasi dan sistem rekomendasi, moderasi laporan pengguna, pemasaran dan edukasi komunitas. |
| Sumber daya utama | Server dan database, model AI (cek foto dan rekomendasi feed), peta OpenStreetMap, tim inti, dan basis pengguna yang padat di satu area. |
| Mitra | NGO lingkungan (misal Zero Waste Indonesia), Midtrans/Xendit, komunitas OpenStreetMap, kampus, panti asuhan. |
| Biaya | Hosting, layanan model AI untuk cek foto, biaya QRIS, pemasaran (termasuk stiker QR di warung dan kos mitra), operasional tim. |

## Pembanding

| | GoFood / ShopeeFood | Surplus | Garda Pangan | PawonFood |
| :--- | :---: | :---: | :---: | :---: |
| Rumah tangga bisa jadi penjual | ✗ | ✗ | ✗ | ✓ |
| Tanpa MoU, tayang dalam 3 ketukan | ✗ | ✗ | ✗ | ✓ |
| Tanpa komisi | ✗ | ✗ | ✓ | ✓ |
| Feed menyesuaikan riwayat klik | ✓ | ✗ | ✗ | ✓ |
| Bisa ambil sendiri atau diantar | ✓ (ongkir mahal) | ✗ (wajib ambil) | ✗ | ✓ |
| Makanan gratis / donasi | ✗ | ✗ | ✓ | ✓ |
| Harga bisa ditawar | ✗ | ✗ | ✗ | ✓ |
| Foto wajib dari kamera, dicek otomatis | ✗ | ✗ | ✗ | ✓ |
| Serah terima dikonfirmasi QR | ✗ | ✗ | ✗ | ✓ |

Versi singkat untuk pitching: GoFood dan ShopeeFood melayani restoran yang sanggup menandatangani MoU dan membayar komisi 20–30%. Surplus menyelamatkan roti dari bakery. PawonFood melayani ibu kos, mahasiswa, dan warung yang ingin menjual atau membagikan sayur lodeh dan lauk sisa hari itu ke tetangga, tanpa MoU dan tanpa komisi, diambil sendiri atau diantar.

## Cakupan MVP

Alur yang harus jalan dari awal sampai akhir:

```
foto dari kamera → cek foto AI → atur harga & cara serah terima → tayang di feed & peta
→ tawar/beli → reservasi → pindai QR
```

Yang termasuk MVP:
- Data lokasi dan daftar makanan awal masih *hardcoded*.
- Riwayat klik dan lama melihat disimpan di state aplikasi, cukup untuk menunjukkan urutan feed berubah saat demo.
- Kamera tampil polos tanpa efek pemindaian. Pengecekan AI berjalan di background setelah foto diambil dan mengisi nama, kategori, dan deskripsi di form. Model YOLO di perangkat menyusul.
- Video cadangan seluruh alur, dari login sampai pindai QR, kalau demo langsung gagal.

Tidak termasuk MVP: reset kata sandi, edit profil, pembayaran QRIS sungguhan, penukaran poin sungguhan, *promoted listing*, dan iklan aktif.

### Status saat ini

Per implementasi 75 layar hi-fi dari Figma:
- Sudah ada tapi masih memakai data mock (belum ada backend atau payment gateway): pembayaran QRIS, reset kata sandi, iklan setelah ulasan (gambar dan video), halaman pengaturan dan bantuan.
- Ketiga kategori sudah ada di UI, tapi model baru mengenali dua kelas. Makanan kemasan masih dipilih manual.
- Reservasi dengan batas waktu, halaman "Pilih cara bayar", rute jalan kaki, QR penyedia, dan pemindai penerima sudah dibuat. Pemindaian antar-perangkat masih disimulasikan di memori.
- Cek foto AI berjalan lewat satu antarmuka (`FoodValidator`) dengan tiga mesin: (1) simulasi aturan YOLO, yang menjadi default; (2) server `app/server/` yang meminta model vision Qwen mendeskripsikan foto, lalu aturan di server memutuskan hasilnya (kunci model hanya di server; aplikasi memakainya kalau dijalankan dengan `PAWON_VALIDATOR_URL`); (3) YOLOv8 Nano → TFLite di perangkat, yang belum dilatih.
- Rekomendasi feed: model ALS dari anggota tim berjalan di `ml/fyp/` dan sudah tersambung ke Beranda lewat `PAWON_FYP_URL`. Datanya berasal dari dataset lain, jadi akun demo dipetakan ke satu pengguna model dan listing mock membawa id item model.
- Landing page: kode Next.js 16 (TypeScript) ada di `web/` dan memakai salinan dari susunan di `DESIGN_SYSTEM.md`. Tautan toko aplikasi dan email kontak belum diisi.
- Tes: 249 tes otomatis Flutter lulus dan `flutter analyze` bersih; 50 tes lulus di `app/server` (dijalankan 16 Oktober 2026).

## Metrik

- Porsi terjual/terselamatkan dan total kg makanan yang tidak jadi sampah.
- Total uang (harga makanan + ongkir) yang diterima penyedia.
- Persentase klik dari posisi teratas feed yang berlanjut ke reservasi.
- Perbandingan pesanan ambil sendiri dan diantar.
- Jumlah penyedia aktif per area dan jumlah listing per hari.
- Persentase reservasi yang selesai dengan status `picked_up`.
- Persentase reservasi yang tidak diambil.
- Median waktu dari listing tayang sampai makanan diterima.
- Rata-rata rating penyedia dan persentase foto yang ditolak.

Untuk presentasi, gunakan format: "Jika 50 dapur dan warung bergabung, X kg makanan terselamatkan per bulan, emisi metana berkurang Y kg, dan ada tambahan penghasilan Rp Z di komunitas." Angka X, Y, dan Z harus dihitung dulu.

## Pertanyaan Terbuka

**Angka dan aturan yang belum ditentukan**
- Placeholder di mockup: format `[RATING]`, ambang `[X] poin` tiap level, harga tukar voucher, rumus `[X] kg`, `[Nama kamu]`, dan `[EMAIL TIM]`. Aplikasi sementara memakai angka asumsi (lihat Profil dan poin); `[EMAIL TIM]` masih berupa placeholder.
- Cara menghitung poin: per porsi atau per transaksi, dan seberapa besar selisih poin makanan gratis dibanding berbayar. Asumsi aplikasi: per porsi, makanan gratis dikali dua.
- Berapa ulasan buruk yang memicu suspensi, dan berapa yang memicu blokir.
- Batas ongkir antar. Usulan: maksimal Rp3.000 supaya tetap jauh di bawah tarif ojek online.

**Serah terima dan QR**
- Apakah QR berlaku sampai batas waktu listing, atau punya durasi sendiri sejak reservasi dibuat.
- Cara mencegah pesanan antar yang dibayar tunai lalu tidak diterima. **Usulan:** setelah MVP, pesanan antar wajib QRIS, atau opsi antar hanya untuk penerima dengan reputasi baik.
- **Usulan:** cocokkan lokasi GPS saat pindai supaya QR tidak bisa dipindai dari foto yang dikirim jarak jauh.
- **Usulan:** simpan QR penyedia di cache agar tetap bisa dibuka saat sinyal lemah.

**Produk dan model**
- Cara melatih YOLO untuk `sealed_food`, termasuk membaca kemasan dan tanggal kedaluwarsa.
- Kolom deskripsi: jadi input opsional di Langkah 2 (risiko melebihi 3 ketukan) atau dibuat otomatis.

**Data dan bisnis**
- Survei 5–10 anak kos dan warung di sekitar UGM untuk mengganti angka asumsi di materi presentasi.
- Pendapatan iklan per pengguna aktif yang dibutuhkan untuk menutup biaya QRIS, hosting, dan API.
