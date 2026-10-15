# Product requirements document

This PRD turns the product idea in [CONCEPT.md](reference/CONCEPT.md) into requirements. It was revised on 2026-10-15
from [prdPawonFood.md](reference/prdPawonFood.md); where the two differ, this PRD follows prdPawonFood.md.

## Product overview

PawonFood's tagline is "Hyperlocal Social Cloud Kitchen & Community Food Marketplace", and its slogan is *Dari dapur
rumah tangga ke komunitas. Masak lebih? Jual dan bagikan tanpa ribet.*

PawonFood connects home kitchens, warung and communities that have extra food with residents within 1 km. The food can
be sold cheaply, negotiated or given away for free. The receiver picks it up on foot, or asks the provider to deliver it.

How it differs from GoFood and ShopeeFood: no MoU, no commission, and anyone can start selling from a home kitchen by
taking a photo of the food. How it differs from Surplus and DamoGO: providers are not only restaurants and bakeries, but
households too.

- Goal: let people sell food from home without bureaucracy, and keep edible food from ending up in the trash.
- One app, two sides: receivers (penerima) and providers (penyedia). One account can be both.
- Starts in Pogung (Sleman, near UGM), then all of Yogyakarta.
- Built for a sustainability hackathon at UGM. Supports SDG 2 (Zero Hunger), SDG 8 (Decent Work and Economic Growth)
  and SDG 12 (Responsible Consumption).
- Sources: [CONCEPT.md](reference/CONCEPT.md), [prdPawonFood.md](reference/prdPawonFood.md),
  [Product.md](reference/Product.md),
  [Evaluasi Ide Aplikasi PawonFood.md](<reference/Evaluasi%20Ide%20Aplikasi%20PawonFood.md>),
  `PawonFood UI apps.pdf` (app screens), `PawonFood UI.pdf` (landing page).

## Background & problem

- **Selling on delivery apps is too heavy for a home kitchen.** An ibu kos or student who cooks 5–10 extra portions a day
  must go through an MoU, a long verification, fixed opening hours and a 20–30% commission. For a buyer who lives 500 m
  away, the courier fee makes the final price unreasonable.
- **Household food waste is large.** Bappenas's food loss and waste study ([Laporan Kajian Food Loss and Waste di Indonesia](https://greeneconomy.bappenas.go.id/home/books/laporan-kajian-food-loss-and-waste-in-indonesia-dalam-rangka-mendukung-penerapan-ekonomi-sirkular-dan-pembangunan-rendah-karbon/),
  2021) puts Indonesia's food loss and waste at 23–48 million tonnes per year over 2000–2019, or 115–184 kg per person
  per year.
  - It costs Rp213–551 trillion per year (4–5% of GDP). Over the period it produced 1,702.9 Mt CO₂e, on average 7.29%
    of national greenhouse gas emissions. The wasted food could have fed 61–125 million people (29.47% of the
    population).
  - Consumption is the largest stage, at 5–19 million tonnes per year, and about 80% of it comes from households (the
    rest from restaurants and catering). So PawonFood targets households first.
- **Around campuses, supply and demand exist but do not meet.** Households, warung, catering and ibu kos regularly cook
  too much and throw away edible leftovers. Anak kos need cheap home-style meals, many have no vehicle, and they do not
  want to pay a delivery fee for a distance under 1 km.
- **Nobody serves home sellers.** Surplus and DamoGO only take restaurants and bakeries, at fixed prices, and the buyer
  must collect. Garda Pangan relies on volunteers and manual logistics. There is no C2C service for home kitchens that
  needs no MoU and offers delivery.
- **The core problem is trust.** Without a contract, buyer and seller are strangers. A transaction only happens when the
  buyer believes the food is real and safe and the handover is clear. Most features below exist to answer this, and the
  team judges every feature against it.

## Stakeholders

| Actor                                                         | Problem / need                               | Side        |
| ------------------------------------------------------------- | -------------------------------------------- | ----------- |
| Households (incl. ibu kos)                                    | Cooked too much, hate throwing it away       | Provider    |
| Restaurants / F&B (warung, warteg, burjo, catering, bakeries) | Surplus is still good but will not be sold   | Provider    |
| Community groups                                              | Hold surplus from events and shared kitchens | Provider    |
| Students / anak kos                                           | Want cheap food they can collect on foot or have delivered for a small fee | Receiver    |
| Orphanages and social communities (panti)                     | Need free or cheap food                      | Receiver    |
| Environment                                                   | Edible food ends up as waste                 | Beneficiary |

Later, receivers extend to anyone with a limited food budget.

## Product concept

### Food categories

| Key                | Label (UI)                   | Meaning                                                             | MVP   |
| ------------------ | ---------------------------- | ------------------------------------------------------------------- | ----- |
| `sealed_food`    | Makanan kemasan              | Sealed, packaged food                                               | Later |
| `bahan_mentah`   | Bahan mentah                 | Fresh ingredients: uncut vegetables, raw ingredients                | Yes   |
| `makanan_matang` | Lauk matang / Makanan matang | Ready-to-eat and homemade food: cooked dishes, leftover side dishes | Yes   |
| `bukan_makanan`  | none                         | Rejected by the AI validator                                        | Yes   |

### Transaction methods

| Method      | In the UI                                         | Rule                                                            |
| ----------- | ------------------------------------------------- | --------------------------------------------------------------- |
| Free        | "Gratis" toggle, price shown as "GRATIS" | Price is 0. Earns the most points.                              |
| Fixed price | "Jual murah" with a price per porsi               | Price ≥ 0, with the original price struck through              |
| Make offer  | "Boleh ditawar" checkbox, "Tawar cepat" chips     | Receiver proposes a price in chat, provider accepts or declines |

### Handover methods

| Method           | In the UI                                                                | Rule                                                                                                                                                              |
| ---------------- | ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pickup           | "Ambil sendiri" pill (default)                                           | The receiver goes to the meeting point before the deadline. No delivery fee.                                                                                      |
| Delivered by the provider | "Bisa diantar" (provider), "Minta diantar" (receiver)           | Only shown when the provider turns it on. The provider delivers to the receiver's address within 1 km. The provider picks the fee (Rp0, Rp2.000 or Rp3.000) and keeps all of it. |

No method carries a platform or admin fee: PawonFood takes Rp0 from both the provider and the receiver. The food price
and the delivery fee are the provider's own and go entirely to the provider.

## User flow

Each step links to the feature that implements it:

| #  | Step                                                         | Feature                                                              |
| --- | ------------------------------------------------------------ | -------------------------------------------------------------------- |
| 1  | A provider has extra food to sell or give away               | Bagikan (Core Feature 2)                                             |
| 2  | The app checks the photo, then the provider sets the deadline and the delivery option | AI photo check, pickup deadline, delivery option, provider guarantee |
| 3  | Nearby residents find the food on Beranda or Peta            | Beranda feed, Peta (1 km radius)                                     |
| 4  | The receiver takes it free, buys it or makes an offer        | Transaction methods                                                  |
| 5  | The receiver chooses pickup or delivery, then reserves       | Reserve & pickup (Core Feature 6)                                    |
| 6  | Handover at the meeting point, or in front of the receiver's kos | Pickup point or delivery address                                 |
| 7  | The receiver scans the provider's QR                         | Reserve & pickup (Core Feature 6)                                    |
| 8  | The listing closes as `picked_up`                            | n/a                                                                  |
| 9  | The provider receives the money and impact points            | Profil & gamification (Core Feature 8)                               |
| 10 | The rescued portions are counted in the impact stats         | Impact stats                                                         |

## Key challenges & responses

The product must handle these eight aspects. The product team wrote the items marked Proposed because the source
concept does not specify them. They are open for review (see Open questions) and none is built yet.

| Aspect        | Challenge                                                                 | Response                                                                                                                                                                             |
| ------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Supply        | Providers must be able to list food in seconds, or they will not do it    | Camera-only listing in 3 taps or fewer; households, F&B and communities all supported                                                                                                |
| Demand        | Receivers need to find food they can actually reach                       | Feed and map limited to 1 km, feed ranked by click history, dwell time, category and the kitchens a user opens often; category chips on Beranda and Peta; filters for walking distance, warm, free and "Bisa diantar" on the full list |
| Trust         | Strangers will not take food they cannot trust                            | AI photo check, provider guarantee line, ToS checkbox for receivers, ratings, suspension then block for poor providers                                                               |
| Logistics     | Handover must be simple and safe                                          | Reserve with a deadline, then pickup at the provider's saved point or delivery by the provider, always confirmed by QR before the deadline                                           |
| Price         | Selling must stay affordable for both sides                               | Free, fixed price or make offer; no transaction or admin fee for either side, revenue comes from ads                                                                                 |
| Privacy       | Providers share a home or kos address with strangers                      | **Proposed:** show only the area and distance on listings. Reveal the exact pickup point after the provider accepts a reservation                                              |
| Social stigma | Receivers may feel ashamed to ask for free food                           | **Proposed:** free listings look like any other listing. No "needy" or charity labels. Free food is framed as a rescue, and receivers earn points too                          |
| No-show       | Reserved food that nobody collects is wasted again                        | **Proposed:** a reservation lasts only until the pickup deadline, then it expires and the food reopens. Repeated no-shows lower the receiver's rating and reservation priority |

## Core features

Each feature maps to a screen in `PawonFood UI apps.pdf`.

1. **Home / Beranda**

   - Header: location ("Lokasi kamu · Pogung, Sleman", tappable to change) and a points pill ("150 Poin").
   - Headline "Lapar? Masih ada yang hangat di dekatmu." plus a search field ("Cari lauk, nasi, roti...").
   - Category chips, intentionally in English: *All*, *Ready-to-Eat* (makanan matang), *Fresh Ingredient* (bahan
     mentah), *Sealed Food* (makanan kemasan; post-MVP, see Food categories). The same chips filter Peta. The
     walking-distance (< 1 km), warm, free and "Bisa diantar" filters live on the full list (Semua makanan).
   - Mini-map card showing a 1 km radius, the user pin and 3–5 nearby providers, plus a round icon-only button (fluent:full-screen-maximize-16-filled, accessible label "Lihat peta penuh") that opens Peta.
   - Feed "Pilihan untukmu di sekitar" of food cards (ranked per user, see Feed ranking): photo, AI ✓ badge, "Sisa N porsi" badge, "Bisa diantar" (when
     the provider turned it on), name, provider, tier tag, struck-through price or **GRATIS**, chat icon, distance.
   - **Feed ranking.** The app records card clicks, detail views longer than 3 seconds, chat opens and completed
     transactions. Each interaction raises the weight of that category, price range and provider. Cards are ordered by
     `score = user affinity × distance proximity × deadline urgency`, and the provider's rating counts too (Core
     Feature 7). Semua makanan sorts by *Rekomendasi* (this score) by default, with *Terdekat* and *Segera habis* as
     alternatives.
   - **Card labels (Proposed):** a card gets one label: *Hampir habis*, *Segar* (fresh raw ingredients), *Sehat*
     (health tags), *Populer* or *Terbaru*. The labels describe composition, never food safety, and they do not
     change the order.
2. **Share food / Bagikan** (center FAB). Must take 3 taps or fewer.

   - Step 1 of 3, camera: live preview with YOLO detection. Shows a bounding box labeled "Lauk matang" and the message
     "Makanan terdeteksi, siap difoto". **Camera only, no gallery upload.** Includes tips and a camera flip button.
   - Step 2 of 3, review: "Semua sudah diisi. Cek sebentar, lalu bagikan."
     - Category auto-filled by AI ("Lauk matang", editable via *Ubah*), with the line "Foto lolos validasi".
     - Food name, portions stepper ("Sisa berapa porsi?").
     - **Pilihan sehat (Proposed):** chips *Sayur/buah*, *Protein*, *Tidak digoreng*, *Rendah gula*. The AI pre-selects
       what it can see in the photo (never *Rendah gula*); the provider confirms. They show on the listing detail and
       drive the *Sehat* card label.
     - **Ide resep (Proposed, Bahan mentah only):** up to 3 recipes from the local library that use the typed
       ingredients, plus "Minta ide dari AI" when the server is configured. The recipe the provider picks counts as
       **verified by the provider** ("Diverifikasi pemberi"). The idea is for buyers only: receivers see it on the listing
       detail as "Ide resep" with ingredients and steps, and the provider does not get the card on their own listing. If the
       provider picked none, the buyer still gets the best match from the library, labelled "Belum diverifikasi pemberi"
       ("Saran otomatis, belum dicek pemberi" in the sheet). A recipe is only an idea: the sheet says "Resep hanya ide. Cek
       kondisi bahan sebelum dimasak."
     - Gratis / Jual murah toggle, price per porsi, and the "Boleh ditawar" checkbox.
     - Handover: *Ambil di tempat* (on by default) and *Bisa diantar (< 1 km)*; at least one stays on. When delivery is
       on, the provider picks the delivery fee: Rp0, Rp2.000 or Rp3.000. The fee goes entirely to the provider.
     - Pickup deadline chips (19.00 / 20.30 / 22.00) plus an "Atur jam" chip: the provider can set any latest pickup
       time with a time picker (5-minute steps). **Proposed:** at least 30 minutes and at most 6 hours from now; outside
       that range the picker explains the limit and "Pakai jam ini" stays disabled. This deadline is also the end of the
       QR pickup window (Core Feature 6). Pickup point taken from the profile (e.g. "Kos Melati, Pogung").
       The provider can change it for this listing only (*Ubah*): pick a saved point, or choose a point on the map
       (address search, optional point name, optional "Simpan ke titik tersimpan"). The exact point stays hidden from
       receivers until a reservation is accepted (Proposed privacy rule).
     - Provider guarantee: "Dengan membagikan, kamu menjamin makanan ini masih layak makan."
     - CTA "Bagikan sekarang".
   - Step 3 of 3: confirmation / published.
3. **Food detail**

   - Opening this screen counts as a click, and how long the user stays is recorded, both for the feed ranking.
   - Hero photo with the "Sisa 2 porsi" and "Foto asli, dicek AI" badges.
   - Provider avatar, name, tier tag and rating.
   - Stat tiles: Jarak (300 m, jalan kaki), Ambil sebelum (20.30, hari ini), Kategori (Lauk matang).
   - Price box: ~~Rp15.000~~ **Rp5.000** with a "Bisa ditawar" pill.
   - Handover choice: *Ambil sendiri (Rp0)* or *Minta diantar (+ongkir)*, shown only when the provider turned delivery
     on.
   - Quick offer chips ("Tawar cepat": Rp3.000 / Rp4.000 / Tulis sendiri). *Tulis sendiri* opens a sheet over the
     detail screen: offer per porsi, number of portions (up to the remaining stock), pickup or delivery, and an optional message. The offer
     must be above Rp0 and below the listed price (validated while typing; the full price goes through *Ambil*). Sending
     posts the offer in the chat as "Menunggu jawaban"; the portions are reserved only once the provider accepts.
     The minimum offer is an open question.
   - "Deskripsi": a short description from the provider (e.g. what the food is, how it is stored). The share form
     (Step 2) has no description field yet, see Open questions.
   - Sticky actions: *Chat* (outline) and *Ambil · Rp5.000* (primary). The total changes when delivery is chosen.
     *Ambil* creates a reservation (Core Feature 6).
4. **Map / Peta**

   - Header showing "Radius 1 km dari Pogung, Sleman" and a recenter button.
   - The same category chips as Beranda (*All*, *Ready-to-Eat*, *Fresh Ingredient*, *Sealed Food*), sharing one
     selection with Beranda.
   - Food-photo pins (price shown on the preview card), a dashed radius circle and a bottom preview card
     ("300 m · ± 4 mnt jalan kaki"). Tapping the card opens the detail.
   - Dense areas show clusters (e.g. "5" over Pogung) instead of stacked pins.
5. **Messages / Pesan and negotiation chat**

   - Tabs: *Saya menerima* / *Saya berbagi*, each with an unread count.
   - Each thread shows provider, item, agreed price and last message, plus a status label:
     *Tawaran diterima*, *Siap diambil* or *Habis*.
   - Safety banner: "Tawar dan atur waktu ambil di sini saja. Jangan transfer uang di luar aplikasi sebelum makanan kamu terima."
   - Chat: listing summary card pinned at the top; offer bubble ("Tawaran kamu · Rp4.000 · 1 porsi · ambil jalan kaki
     ±4 mnt") followed by normal chat bubbles; accepted card "Tawaran Rp4.000 diterima" with "Bayar Rp4.000 di tempat" and a "Pindai QR" button for the receiver
     (the provider opens the QR from the same thread, Core Feature 6).
   - Quick replies: *Saya OTW*, *Bisa diantar?*, *Masih ada?*, *Tawar lagi*.
6. **Reserve & pickup**

   - **Reserve.** Taking a listing, or having an offer accepted, reserves the portions for that receiver. The receiver
     picks pickup or delivery as part of this step (delivery only when the provider turned it on). The reservation
     is held until the provider's pickup deadline, then it expires and the portions reopen. The app removes reserved
     portions from "Sisa N porsi".
   - **QR confirmation, no manual code.** The provider opens a QR code for the reservation in the app. The receiver
     scans it with the app ("Pindai QR"), at the meeting point for a pickup or when the food is delivered to the kos.
     Each QR works for one reservation and one scan. The scan is
     only accepted **within the pickup time window** (up to the provider's deadline). A scan outside the window is
     rejected and the reservation expires. There is no pickup code to type or read out.
   - A successful scan marks the listing `picked_up`, counts the portions as rescued, notifies the provider ("diambil
     [nama]") and awards the provider impact points (Core Feature 8). The receiver goes straight to the review screen
     (Core Feature 7), with no extra confirmation step. The provider does not need to tap anything.
   - Payment is cash at handover (pickup or delivery) in the MVP. No flow may ask users to transfer money outside the
     app.
   - **Choosing how to pay** (Figma lo-fi B10d-B10i, C17d). Right after an offer is accepted, or after *Ambil* at full
     price, the receiver picks a payment method ("Pilih cara bayar"). Free listings skip this step.
     - *Tunai di tempat* (MVP default): back to the chat; the receiver pays the provider in cash at handover, after
       scanning the QR.
     - *Bayar di aplikasi* (**post-MVP, Proposed**): QRIS only, through a payment gateway (Midtrans or Xendit). No
       e-wallet or virtual-account options. The QRIS belongs to PawonFood, never to the provider's own account. PawonFood holds the money until the QR is scanned, then releases it in full (food price + delivery fee) to the provider's balance.
       If the reservation expires or is cancelled, the receiver gets a full refund. A failed or expired payment keeps
       the reservation until the pickup deadline and offers "Coba lagi" or switching to cash.
     - The receiver pays the agreed price plus the delivery fee, if any, with no extra fee, and the provider receives
       all of it: no platform fee is deducted. PawonFood covers the QRIS gateway cost from ad revenue (**Proposed**). Provider balance and
       withdrawal to a bank account are not designed yet. The Figma mockups still show a 5% fee and e-wallet
       options, and need an update.
7. **Rating & review**

   - Receivers rate food quality after pickup. The review screen opens right after the QR scan, so the receiver rates
     while still at the pickup point. Receivers can skip it with the back button.
   - **Post-MVP:** after the receiver taps "Kirim ulasan", a full-screen ad opens (see Ads), then the app returns to
     Beranda. Skipping the review shows no ad (**Proposed**).
   - The provider's rating is also an input of the feed ranking (Core Feature 1).
   - Providers with repeated bad reviews are suspended first: their listings are hidden and they cannot share food.
     If bad reviews continue after the suspension ends, they are blocked.
8. **Profile / Profil & gamification**

   - Role "Penerima dan penyedia · Pogung, Sleman".
   - Level card with tier progress: Pawon Friend → Pawon Elite → Pawon Hero ("[X] poin lagi untuk naik ke Pawon Elite").
   - Impact stats: porsi dibagikan, porsi diselamatkan, kg batal jadi sampah.
   - **Impact points** go to the provider when a pickup is confirmed by QR scan. Free food earns more points.
     Receivers also earn points when they pick up food and rate it well.
   - Tukar poin (redeem points): voucher belanja minimarket, diskon layanan antar (ojek), Sertifikat Resto Peduli
     Lingkungan (monthly, for warung and restaurants).
   - **Potongan makanan (Proposed):** food vouchers (Rp3.000 / Rp5.000) bought with points and used on Pembayaran ("Pakai voucher":
     pick one from Voucher saya or type the code). One voucher per payment, the payment never goes below Rp1.000, paid food only,
     the voucher counts as used once the payment is confirmed. The provider still receives the full agreed price (PawonFood covers the voucher).
   - Links: riwayat berbagi dan mengambil, titik ambil tersimpan, keamanan pangan dan persetujuan, pengaturan.
9. **Landing page** (`PawonFood UI.pdf`)

   - Marketing site that explains the product, recruits providers and links to the app stores.
   - Section structure is in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md#landing-page).
   - Must carry the tagline and slogan from the Product overview.

## Ads (post-MVP)

Ads are the main revenue stream (see Business Model) and stay out of the MVP. The screen is designed now so the flow is
ready (Figma lo-fi B11b).

- **Format:** one full-screen ad right after the receiver submits a review. It carries an "Iklan" label, a 5-second
  countdown, then a close (X) button, and a "Pelajari" button that opens the sponsor link.
- **Video variant (Proposed, Figma lo-fi B11c):** the ad can also be a full-screen 9:16 video of at most 15 seconds. It
  autoplays muted with a progress bar, a sound toggle and "Lewati dalam 5" that turns into "Lewati" after 5 seconds.
  When the video ends, the app returns to Beranda.
- **Content:** eco-friendly FMCG sponsors only, matching the revenue stream. No health claims about food, and no
  alcohol or tobacco (**Proposed**).
- **Rules (Proposed):** at most one ad per receiver per day, no ads for providers, no ads inside the QR flow, and saving
  the review does not wait for the ad.

## Trust & food safety

These rules address the core problem, food safety and trust.

- PawonFood is an intermediary (a bulletin board), not a food producer.
- Photos are taken with the camera only and validated by AI. Photos from the internet or non-food objects are rejected.
- Providers confirm the guarantee line before publishing.
- Receivers accept a ToS checkbox on the payment screen (cash or in-app), right above the confirm button, e.g. "Saya
  telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan." The button stays disabled until
  it is checked.
- Every listing carries an explicit pickup or delivery deadline, so food is not left to sit for long.
- Every handover, pickup or delivery, must be closed by scanning the provider's QR inside the time window. The scan
  proves the receiver got the food on time and releases impact points. A QR works once and only for its reservation.
- Payment is cash at handover in the MVP.
- Rating-based enforcement for providers with poor quality: suspension first, then a block if it repeats.
- Never call providers "Borjuis". The tier names above replace it.

## Business model (Business Model Canvas)

| Component              | PawonFood                                                                                                                                                                           |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Customer segments      | Receivers: anak kos, panti asuhan, low-budget people. Providers: households/ibu kos, warung, restaurants, bakeries, communities.                                                    |
| Value proposition      | Receivers: cheap or free home-style food nearby, collected on foot or delivered for a small fee. Providers: sell without an MoU or commission, less food wasted, impact points and badges. |
| Channels               | Mobile app (Android & iOS), Instagram and TikTok, BEM/HIMA partnerships, door-to-door to kos and warung near campus.                                                                |
| Customer relationships | A feed that adapts to each user's habits, points and rewards, open ratings, in-app chat for negotiating and arranging the handover.                                                 |
| Revenue streams        | Main: targeted eco-friendly FMCG ads (incl. a full-screen ad after the review, post-MVP). Optional: promoted listings (top of map). No fee on transactions: providers and receivers pay Rp0 to PawonFood. |
| Key activities         | Platform development, quality control of reports, marketing and education.                                                                                                          |
| Key resources          | Tech infrastructure (server, DB, Maps API), the on-device YOLO model, core team, a dense local user community.                                                                      |
| Key partners           | Environmental NGOs (e.g. Zero Waste Indonesia), payment gateways for QRIS (Midtrans, Xendit), Google Maps, campuses and panti asuhan.                                                        |
| Cost structure         | Hosting and paid APIs, marketing (promos, QR stickers at partner warung), team operations.                                                                                          |

## Competitors & USP

| Feature                                    | GoFood / ShopeeFood | Surplus | Garda Pangan | PawonFood |
| ------------------------------------------ | :-----------------: | :-----: | :----------: | :-------: |
| Household kitchens can be sellers          |         ✗          |   ✗    |      ✗      |    ✓    |
| No MoU, live in 3 taps                     |         ✗          |   ✗    |      ✗      |    ✓    |
| No commission                              |         ✗          |   ✗    |      ✓      |    ✓    |
| Feed adapts to click history               |         ✓          |   ✗    |      ✗      |    ✓    |
| Pickup or delivery                         |  ✓ (costly courier) | ✗ (pickup only) |  ✗   |    ✓    |
| Free food / donation                       |         ✗          |   ✗    |      ✓      |    ✓    |
| Negotiable price                           |         ✗          |   ✗    |      ✗      |    ✓    |
| Camera-only photo, checked automatically   |         ✗          |   ✗    |      ✗      |    ✓    |
| QR-confirmed handover                      |         ✗          |   ✗    |      ✗      |    ✓    |

Pitch line: *GoFood dan ShopeeFood melayani restoran yang sanggup menandatangani MoU dan membayar komisi 20–30%.
Surplus menyelamatkan roti dari bakery. PawonFood melayani ibu kos, mahasiswa, dan warung yang ingin menjual atau
membagikan sayur lodeh dan lauk sisa hari itu ke tetangga, tanpa MoU dan tanpa komisi, diambil sendiri atau diantar.*

## MVP scope

**In scope (core journey):** Upload food → YOLO validation → set price and handover method → listing appears on
map/feed → negotiate or buy → reserve → QR scan.

- Mock / hardcoded data for map locations and listings.
- Click history and viewing time are kept in app state, enough to show the feed order changing during the demo.
- On-device YOLO validation with a visible "AI sedang memindai..." scan animation.
- Record a backup demo video of the full flow, from login to a completed pickup.

**Out of scope for MVP:** password reset, profile editing, in-app payments, real point redemption, promoted listings, ads.

**Where the built app stands against this PRD** (updated 2026-10-15; the app was brought to all 75 Figma hi-fi screens
on 2026-10-07):

- Delivery by the provider is built on mock data but has no Figma screens yet. The provider ticks "Bisa diantar
  (< 1 km)" in the share form and picks the fee chip (Rp0 / Rp2.000 / Rp3.000). The receiver chooses on the detail,
  before *Ambil*: "Cara ambil" with *Ambil sendiri* or *Minta diantar*. The same choice is in "Tulis sendiri" and goes
  with the "Tawar cepat" chips. The address is the receiver's primary saved point, which *Ubah alamat antar* can
  change; one more than 1 km from the food is refused. The total on *Ambil*, the reservation card, Pembayaran
  ("Ongkir") and the provider's QR and balance include the fee. Cards show a bike icon (no text tag: it does not fit
  at 360 dp), Semua makanan has a "Bisa diantar" filter, and the chat has the *Bisa diantar?* quick reply. The provider
  can also untick *Ambil di tempat* for delivery-only food (at least one of the two must stay on). The receiver then
  sees *Ambil sendiri* switched off ("Penyedia hanya mengantar"), and can not take the food while their address is
  over 1 km away. The provider who delivers gets "Lihat rute antar": the same route screen ("Rute antar", "Mulai
  antar"), from their GPS or the pickup point to the delivery address. On arrival it shows "Buka QR ambil". It uses
  the foot router, which within 1 km also follows the gangs a motorbike takes.
- Feed ranking: the app orders by affinity × proximity × urgency. Affinity comes from a trained recommender (`ml/fyp/`,
  received ready to use) when its server runs. The app sends `view` (detail open 3 s), `addtocart` (Ambil or offer) and
  `transaction` (QR scan) events to that server. Gaps: the model was trained on another dataset, so the demo maps the
  account and listings onto its ids, and the order only learns from the events after retraining (the training scripts
  are not in the package). Card clicks and chat opens are not sent as separate events. Without the server the feed is
  proximity × urgency.
- Built beyond the MVP scope, as simulated flows on mock data (no backend, no gateway): QRIS payment, password
  reset, the post-review ad (image and video variants, at most one a day), settings and help screens.
- Categories: all three exist (chips *All · Ready-to-Eat · Fresh Ingredient · Sealed Food*, and "Ubah kategori" with
  "Baik digunakan sebelum"). The AI validator still knows only two classes, so sealed food is picked by hand.
- Pickup: reservation until the deadline, "Pilih cara bayar", walking route, provider QR and receiver scan are built.
  Decoding is simulated (the in-memory demo cannot link two phones), and so is the other side scanning.
- Proposed rules: listings show only the area until a reservation exists; reservations expire at the deadline and
  reopen the portions. The rating penalty for repeated no-shows is not built.

## Success metrics

- Portions saved (porsi diselamatkan) and kg of food kept out of the trash
- Active providers per area, listings per day
- Pickup completion rate (reservations that end in `picked_up`)
- No-show rate (reservations that expire without a scan)
- Median time from publish to handover
- Total money providers receive (food price + delivery fee)
- Share of clicks from the top feed positions that turn into a reservation
- Split between pickup and delivery orders
- Average provider rating; share of photos rejected by AI
- Impact estimate for the pitch: "Jika 50 warung bergabung, X kg makanan terselamatkan per bulan, Y kg emisi metana berkurang."

## Open questions

- Mockup placeholders to fill: `[RATING]` format, `[X] poin` tier thresholds and reward costs, `[X] kg` impact formula,
  `[Nama kamu]`, `[EMAIL TIM]`.
- Point rules (per portion? bonus for free food?) and the review threshold for a suspension, how long it lasts, and the threshold for a block.
- Confirm the proposed Privacy, Social stigma and No-show rules with the team.
- Delivery fee cap. Proposal: at most Rp3.000, far below ride-hailing rates.
- How to stop delivery orders paid in cash from being refused at the door. **Proposed:** after the MVP, delivery
  requires QRIS, or delivery is only open to receivers with a good record.
- **Proposed:** when the provider sees the receiver's delivery address (only after accepting the reservation, like the
  pickup point).
- QR details: whether the window is the provider's pickup deadline or a shorter fixed time after reserving.
- **Proposed** anti-fraud: require the receiver to be near the pickup point when scanning (GPS radius), because someone
  could photograph the QR and scan it from far away.
- **Proposed** offline case: cache the provider's QR in the app so it still shows without signal.
- Ads: frequency cap and countdown length, ad network or manual sponsors, whether free-food pickups also show the ad
  (**Proposed**: yes, same rules), and how the sponsor is disclosed next to the "Iklan" label.
- How to validate `sealed_food` photos (packaging, expiry date) with the YOLO model.
- Food description: add an optional "Deskripsi" field to the share form (Step 2) without breaking the 3-tap target,
  or let the AI suggest one.
- Field survey data (5–10 anak kos and warung near UGM) to replace example numbers in the pitch.
- Ad revenue per active user needed to cover QRIS gateway costs, hosting and paid APIs, now that transactions are free.
