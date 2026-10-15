# FYP Marketplace — Paket Siap Tanam (untuk server kamu)

Ini paket **model rekomendasi yang sudah dilatih** + server-nya. Kamu TIDAK
perlu melatih ulang. Cukup pasang, nyalakan, lalu arahkan aplikasi ke server
ini.

## Isi paket

```
backend/
├── 3_api.py            server rekomendasi (FastAPI)
├── requirements.txt    library yang perlu dipasang
└── data/
    ├── model.npz       otak model (hasil training)
    ├── maps.pkl        kamus id user & item
    └── interactions.npz riwayat (agar tak merekomendasikan barang yang sudah dilihat)
```

(Catatan: data mentah pengguna sengaja TIDAK disertakan.)

## Cara menyalakan (3 langkah)

Butuh **Python 3.9+**. Cek dulu: `py --version` (Windows) atau `python3 --version`.

### 1. Masuk folder & pasang library (sekali saja)

```bash
cd backend
py -m pip install -r requirements.txt
```
(Di macOS/Linux pakai `python3 -m pip` dan `python3` sebagai ganti `py`.)

### 2. Nyalakan server

```bash
py -m uvicorn 3_api:app --host 0.0.0.0 --port 8000
```

`--host 0.0.0.0` membuat server bisa diakses dari perangkat lain di jaringan
(mis. HP). Untuk dicoba sendiri dulu, buka http://127.0.0.1:8000/docs — ada
tombol untuk mencoba API langsung di browser.

### 3. Pakai dari aplikasi

Dua endpoint tersedia:

- **Minta rekomendasi**
  `GET /recommend?user_id=u0&n=10`
  → `{"user_id":"u0","tipe":"personal","items":["i6","i3", ...]}`

- **Catat aksi pengguna** (agar model makin pintar saat dilatih ulang nanti)
  `POST /event`  body JSON: `{"user_id":"u0","item_id":"i6","event":"view"}`
  nilai `event`: `view` | `addtocart` | `transaction`

Pengguna yang belum dikenal model otomatis dapat daftar **populer** (bukan error).

## PENTING — soal id produk

Model ini mengembalikan **id item** sesuai data saat dilatih (contoh: `i0`,
`i1`, ...). Agar rekomendasi nyambung, id item di aplikasimu HARUS sama dengan
id di model ini. Kalau produkmu punya id sendiri yang beda, kamu perlu melatih
ulang model dengan data perilaku yang memakai id produkmu (butuh file training
`1_download_data.py` dan `2_train.py` — minta ke pengirim paket ini).

## Melatih ulang (opsional, nanti)

Server menyimpan setiap `POST /event` ke sebuah file `events.csv`. Untuk
memperbarui model dari aksi-aksi baru, jalankan ulang skrip training (`2_train.py`,
minta ke pengirim) lalu nyalakan ulang server. Bagus dijadwalkan, mis. tiap malam.

## Menaruh di server sungguhan (produksi)

Untuk dipakai publik, taruh di server/cloud dan jalankan di belakang HTTPS,
mis.:
```bash
py -m uvicorn 3_api:app --host 0.0.0.0 --port 8000 --workers 2
```
lalu pasang reverse-proxy (Nginx/Caddy) untuk HTTPS. Jangan buka port mentah
ke internet tanpa HTTPS.
