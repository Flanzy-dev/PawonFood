
# Product Requirements Document

## Product Overview

Product: PawonFood
Tagline: "Dari dapur ke dapur" — *Masak kebanyakan? Bagikan, jangan buang.*
Goal: Stop edible surplus food from being thrown away by connecting home kitchens,
warung and ibu kos with nearby students, within walking distance.

- Hyperlocal surplus-food sharing app, starting in Pogung (Sleman, near UGM), then all of Yogyakarta.
- One app, two sides: receivers (penerima) and providers (penyedia).
- Built for a sustainability hackathon at UGM. Supports **SDG 2 (Zero Hunger)** and **SDG 12 (Responsible Consumption)**.
- Sources: [Product.md](Product.md), [Evaluasi Ide Aplikasi PawonFood.md](Evaluasi%20Ide%20Aplikasi%20PawonFood.md), `PawonFood UI apps.pdf` (8 app screens), `PawonFood UI.pdf` (landing page).

## Problem

- Households, warung, catering and ibu kos regularly cook too much. Edible leftovers end up in the trash.
- Students living in kos (anak kos) need cheap meals and often have no motorbike.
- Existing players (Surplus, DamoGO) only take surplus from formal restaurants and bakeries at fixed prices.
  Garda Pangan relies on volunteers and manual logistics. Nobody serves the grassroots household kitchen.

## Target Users

#### Receivers (penerima)

- Students living away from home (anak kos / mahasiswa perantau)
- Orphanages and care homes (panti asuhan)
- Later: anyone with a limited food budget

#### Providers (penyedia)

- Households and ibu kos
- Warung, warteg, burjo, warmindo
- Catering, restaurants, bakeries

## Core Features

Each feature maps to a screen in `PawonFood UI apps.pdf`.

1. **Home / Beranda** (page 1)
   - Header: location ("Lokasi kamu · Pogung, Sleman", tappable to change) and a points pill ("150 Poin").
   - Headline "Lapar? Masih ada yang hangat di dekatmu." plus a search field ("Cari lauk, nasi, roti...").
   - Filter chips: *Bisa jalan kaki* (radius < 1 km), *Sedang hangat*, *Makan gratis*, *Bahan mentah*.
   - Mini-map card showing a 1 km radius, the user pin and 3–5 nearby providers, plus a CTA "Lihat peta penuh".
   - Feed "Segera habis di sekitarmu" of food cards: photo, AI ✓ badge, "Sisa N porsi" badge, name,
     provider, tier tag, struck-through price or **GRATIS**, chat icon, distance.

2. **Share food / Bagikan** (center FAB, pages 2–3). Must take 3 taps or fewer.
   - Step 1 of 3, camera: live preview with YOLO detection. Shows a bounding box labeled "Lauk matang" and the message
     "Makanan terdeteksi, siap difoto". **Camera only, no gallery upload.** Includes tips and a camera flip button.
   - Step 2 of 3, review: "Semua sudah diisi. Cek sebentar, lalu bagikan."
     - Category auto-filled by AI ("Lauk matang", editable via *Ubah*), with the line "Foto lolos validasi".
     - Food name, portions stepper ("Sisa berapa porsi?").
     - Gratis / Jual murah toggle, price per porsi, and the "Boleh ditawar" checkbox.
     - Pickup deadline chips (19.00 / 20.30 / 22.00); pickup point taken from the profile (e.g. "Kos Melati, Pogung").
     - Provider guarantee: "Dengan membagikan, kamu menjamin makanan ini masih layak makan."
     - CTA "Bagikan sekarang".
   - Step 3 of 3: confirmation / published.

3. **Food detail** (page 4)
   - Hero photo with the "Sisa 2 porsi" and "Foto asli, dicek AI" badges.
   - Provider avatar, name, tier tag and rating.
   - Stat tiles: Jarak (300 m, jalan kaki), Ambil sebelum (20.30, hari ini), Kategori (Lauk matang).
   - Price box: ~~Rp15.000~~ **Rp5.000** with a "Bisa ditawar" pill.
   - Quick offer chips ("Tawar cepat": Rp3.000 / Rp4.000 / Tulis sendiri).
   - Sticky actions: *Chat* (outline) and *Ambil · Rp5.000* (primary).

4. **Map / Peta** (page 5)
   - Header showing "Radius 1 km dari Pogung, Sleman" and a recenter button.
   - Filter chips: Semua / Gratis / Sedang hangat.
   - Price-label pins ("Rp5.000", "Gratis"), a dashed radius circle and a bottom preview card
     ("300 m · ± 4 mnt jalan kaki"). Tapping the card opens the detail.
   - Dense areas show clusters (e.g. "5" over Pogung) instead of stacked pins.

5. **Messages / Pesan** (page 6)
   - Tabs: *Saya menerima* / *Saya berbagi*, each with an unread count.
   - Each thread shows provider, item, agreed price and last message, plus a status label:
     *Tawaran diterima*, *Siap diambil* or *Habis*.
   - Safety banner: "Tawar dan atur waktu ambil di sini saja. Jangan transfer uang di luar aplikasi sebelum makanan kamu terima."

6. **Negotiation chat** (page 7)
   - Listing summary card pinned at the top.
   - Offer bubble ("Tawaran kamu · Rp4.000 · 1 porsi · ambil jalan kaki ±4 mnt") followed by normal chat bubbles.
   - Accepted card "Tawaran Rp4.000 diterima" with a pickup code (**PWN-4821**), "Bayar Rp4.000 di tempat" and a
     "Sudah saya ambil" button.
   - Quick replies: *Saya OTW*, *Masih ada?*, *Tawar lagi*.

7. **Profile / Profil & gamification** (page 8)
   - Role "Penerima dan penyedia · Pogung, Sleman".
   - Level card with tier progress: **Sobat Pawon → Food Savior → Pahlawan Pangan** ("[X] poin lagi untuk naik ke Food Savior").
   - Impact stats: porsi dibagikan, porsi diselamatkan, kg batal jadi sampah.
   - Tukar poin (redeem points): voucher belanja minimarket, diskon layanan antar (ojek), Sertifikat Resto Peduli
     Lingkungan (monthly, for warung and restaurants).
   - Rule: points are earned each time food is picked up and rated well. Free food earns more points.
   - Links: riwayat berbagi dan mengambil, titik ambil tersimpan, keamanan pangan dan persetujuan, pengaturan.

8. **Rating & review**
   - Receivers rate food quality after pickup.
   - Providers with repeated bad reviews are automatically blocked.

9. **Landing page** (`PawonFood UI.pdf`)
   - Marketing site that explains the product, recruits providers and links to the app stores.
   - Section structure is in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md#landing-page).

## Categories

| Key | Label (UI) | Meaning |
| --- | --- | --- |
| `makanan_matang` | Lauk matang / Makanan matang | Cooked dishes, leftover side dishes |
| `bahan_mentah` | Bahan mentah | Uncut vegetables and raw ingredients |
| `bukan_makanan` | — | Rejected by the AI validator |

## Trust & Food Safety

- PawonFood is an **intermediary / bulletin board**, not a food producer.
- Photos are taken with the camera only and validated by AI. Photos from the internet or non-food objects are rejected.
- Providers confirm the guarantee line before publishing.
- Receivers accept a ToS checkbox when ordering, e.g. "Saya telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan."
- Payment is cash on pickup in the MVP. The pickup code (PWN-XXXX) confirms the right person collected the food.
- Rating-based auto-blocking for providers with poor quality.
- **Never call providers "Borjuis".** The tier names above replace it.

## Business Model

| Component | PawonFood |
| --- | --- |
| Customer segments | Receivers: anak kos, panti asuhan, low-budget people. Providers: households/ibu kos, warung, restaurants, bakeries. |
| Value proposition | Receivers: cheap or free food within walking distance. Providers: less waste and loss, points/badges, green branding. |
| Channels | Mobile app (Android & iOS), Instagram/TikTok anti-food-waste campaigns, BEM/HIMA partnerships, door-to-door to warung near campus. |
| Customer relationships | Gamification & rewards, transparent ratings, in-app chat for price and pickup time. |
| Revenue streams | 5–10% platform fee on paid transactions (free food is exempt), promoted listings (top of map), targeted eco-friendly FMCG ads. |
| Key activities | Platform development, quality control of reports, marketing and education. |
| Key resources | Tech infrastructure (server, DB, Maps API), core team, a dense local user community. |
| Key partners | Environmental NGOs (e.g. Zero Waste Indonesia), payment gateways (Midtrans, Xendit), Google Maps, campuses and panti asuhan. |
| Cost structure | Hosting and paid APIs, marketing (promos, QR stickers at partner warung), team operations. |

## Competitors & USP

| Feature | Surplus | Garda Pangan | DamoGO | PawonFood |
| --- | :---: | :---: | :---: | :---: |
| Household kitchens as providers (C2C) | ✗ | ✗ | ✗ | ✓ |
| Free food / charity | ✗ | ✓ | ✗ | ✓ |
| Flexible price / negotiation via chat | ✗ | ✗ | ✗ | ✓ |
| AI photo validation (YOLO) | ✗ | ✗ | ✗ | ✓ |

Pitch line: *"Surplus fokus menyelamatkan croissant dari bakery mewah. PawonFood fokus menyelamatkan sayur lodeh sisa
masak ibu kos dan lauk warteg untuk anak kos di akhir bulan."*

## MVP Scope

**In scope (core journey):** Upload food → YOLO validation → listing appears on map/feed → negotiate → picked up with code.

- Mock / hardcoded data for map locations and listings.
- On-device YOLO validation with a visible "AI sedang memindai..." scan animation.
- Record a backup demo video of the full flow, from login to a completed pickup.

**Out of scope for MVP:** password reset, profile editing, in-app payments, real point redemption, promoted listings, ads.

## Success Metrics

- Portions saved (porsi diselamatkan) and kg of food kept out of the trash
- Active providers per area, listings per day
- Pickup completion rate (listings that end in `picked_up`)
- Median time from publish to pickup
- Average provider rating; share of photos rejected by AI
- Impact estimate for the pitch: "Jika 50 warung bergabung, X kg makanan terselamatkan per bulan, Y kg emisi metana berkurang."

## Open Questions

- Mockup placeholders to fill: `[RATING]` format, `[X] poin` tier thresholds and reward costs, `[X] kg` impact formula,
  `[Nama kamu]`, `[EMAIL TIM]`.
- Point rules (per portion? bonus for free food?) and the review threshold for auto-blocking.
- Field survey data (5–10 anak kos and warung near UGM) to replace example numbers in the pitch.
