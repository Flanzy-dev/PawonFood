# Product Requirements Document

Source of truth for the product idea: [CONCEPT.md](reference/CONCEPT.md). This PRD turns it into requirements.

## Product Overview

Product: PawonFood
Tagline: "Hyperlocal Community Food Rescue Platform". Slogan: *Dari dapur ke dapur. Masak kebanyakan? Bagikan, jangan buang.*

PawonFood is a hyperlocal food-rescue platform. It connects households, F&B businesses and communities that have
edible surplus food with people nearby who need it, either for free or at an affordable price.

- Keywords: Surplus Food, Affordable, Community Base, Sustainability.
- Goal: turn surplus food into useful food before it becomes waste.
- One app, two sides: receivers (penerima) and providers (penyedia).
- Starts in Pogung (Sleman, near UGM), then all of Yogyakarta.
- Built for a sustainability hackathon at UGM. Supports **SDG 2 (Zero Hunger)** and **SDG 12 (Responsible Consumption)**.
- Sources: [CONCEPT.md](reference/CONCEPT.md), [Product.md](reference/Product.md),
  [Evaluasi Ide Aplikasi PawonFood.md](<reference/Evaluasi%20Ide%20Aplikasi%20PawonFood.md>),
  `PawonFood UI apps.pdf` (app screens), `PawonFood UI.pdf` (landing page).

**Positioning.** PawonFood is a food-rescue network that runs from the kitchen to the community. Price gets the food
picked up. Copy, marketing and UI must not present PawonFood as a cheap-food app or a discount marketplace.

**Final statement.** PawonFood is a location-based food-rescue platform that connects households, F&B businesses and
communities with people nearby, to rescue edible surplus food through free sharing or affordable prices.

## Background & Problem

- Bappenas estimates Indonesia's food loss and waste at roughly **23–48 million tonnes per year** (2000–2019).
  Consumption is the largest source of food waste, at roughly **5–19 million tonnes per year**, so PawonFood targets
  households first.
- Households, warung, catering and ibu kos regularly cook too much. Edible leftovers end up in the trash.
- Students living in kos (anak kos) need cheap meals and often have no motorbike.
- Existing players (Surplus, DamoGO) only take surplus from formal restaurants and bakeries at fixed prices.
  Garda Pangan relies on volunteers and manual logistics. None of them serves the household kitchen.
- **Core problem: food safety + trust.** Strangers share food only when they believe it is safe and the handover is
  reliable. The team judges every feature below against this.

## Stakeholders

| Actor                                                         | Problem / need                               | Side        |
| ------------------------------------------------------------- | -------------------------------------------- | ----------- |
| Households (incl. ibu kos)                                    | Cooked too much, hate throwing it away       | Provider    |
| Restaurants / F&B (warung, warteg, burjo, catering, bakeries) | Surplus is still good but will not be sold   | Provider    |
| Community groups                                              | Hold surplus from events and shared kitchens | Provider    |
| Students / anak kos                                           | Want decent food at a low price              | Receiver    |
| Orphanages and social communities (panti)                     | Need access to food                          | Receiver    |
| Environment                                                   | Edible food ends up as waste                 | Beneficiary |

Later, receivers extend to anyone with a limited food budget.

## Product Concept

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
| Free        | "Gratis" toggle, price shown as **GRATIS** | Price is 0. Earns the most points.                              |
| Fixed price | "Jual murah" with a price per porsi               | Price ≥ 0, with the original price struck through              |
| Make offer  | "Boleh ditawar" checkbox, "Tawar cepat" chips     | Receiver proposes a price in chat, provider accepts or declines |

No method carries a platform or admin fee: PawonFood takes Rp0 from both the provider and the receiver. The price is
the provider's own food price and goes entirely to the provider.

## User Flow

Each step links to the feature that implements it:

| #  | Step                                              | Feature                                             |
| -- | ------------------------------------------------- | --------------------------------------------------- |
| 1  | A household or F&B has surplus food               | Bagikan (Core Feature 2)                            |
| 2  | PawonFood checks eligibility and time information | AI photo check, pickup deadline, provider guarantee |
| 3  | The nearest people find the food                  | Beranda feed, Peta (1 km radius)                    |
| 4  | Free or very cheap                                | Transaction methods                                 |
| 5  | Reserve                                           | Reserve & pickup (Core Feature 6)                   |
| 6  | Safe pickup                                       | Pickup point from the profile, walking distance     |
| 7  | QR confirmation (receiver scans)                  | Reserve & pickup (Core Feature 6)                   |
| 8  | Food rescued                                      | Listing closes as`picked_up`                      |
| 9  | The provider earns impact points                  | Profil & gamification (Core Feature 8)              |
| 10 | Waste goes down and the food gets used            | Impact stats                                        |

## Key Challenges & Responses

The product must handle these eight aspects. The product team wrote the items marked **Proposed** because the source
concept does not specify them. They are open for review (see Open Questions) and none is built yet.

| Aspect        | Challenge                                                                 | Response                                                                                                                                                                             |
| ------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Supply        | Providers must be able to list food in seconds, or they will not do it    | Camera-only listing in 3 taps or fewer; households, F&B and communities all supported                                                                                                |
| Demand        | Receivers need to find food they can actually reach                       | Walking-distance feed and map (radius < 1 km), category chips on Beranda and Peta, filters for warm and free food on the full list                                                   |
| Trust         | Strangers will not take food they cannot trust                            | AI photo check, provider guarantee line, ToS checkbox for receivers, ratings, suspension then block for poor providers                                                               |
| Logistics     | Handover must be simple and safe                                          | Reserve, then pickup at the provider's saved point within walking distance before the deadline, confirmed by QR                                                                      |
| Price         | Price must be low without making the app look like a discount marketplace | Free, fixed price or make offer; no transaction or admin fee for either side, revenue comes from ads                                                                                 |
| Privacy       | Providers share a home or kos address with strangers                      | **Proposed:** show only the area and distance on listings. Reveal the exact pickup point after the provider accepts a reservation                                              |
| Social stigma | Receivers may feel ashamed to ask for free food                           | **Proposed:** free listings look like any other listing. No "needy" or charity labels. Free food is framed as a rescue, and receivers earn points too                          |
| No-show       | Reserved food that nobody collects is wasted again                        | **Proposed:** a reservation lasts only until the pickup deadline, then it expires and the food reopens. Repeated no-shows lower the receiver's rating and reservation priority |

## Core Features

Each feature maps to a screen in `PawonFood UI apps.pdf`.

1. **Home / Beranda**

   - Header: location ("Lokasi kamu · Pogung, Sleman", tappable to change) and a points pill ("150 Poin").
   - Headline "Lapar? Masih ada yang hangat di dekatmu." plus a search field ("Cari lauk, nasi, roti...").
   - Category chips, intentionally in English: *All*, *Ready-to-Eat* (makanan matang), *Fresh Ingredient* (bahan
     mentah), *Sealed Food* (makanan kemasan; post-MVP, see Food categories). The same chips filter Peta. The walking-distance (< 1 km), warm and free filters live on the
     full list (Semua makanan).
   - Mini-map card showing a 1 km radius, the user pin and 3–5 nearby providers, plus a CTA "Lihat peta penuh".
   - Feed "Segera habis di sekitarmu" of food cards: photo, AI ✓ badge, "Sisa N porsi" badge, name,
     provider, tier tag, struck-through price or **GRATIS**, chat icon, distance.
2. **Share food / Bagikan** (center FAB). Must take 3 taps or fewer.

   - Step 1 of 3, camera: live preview with YOLO detection. Shows a bounding box labeled "Lauk matang" and the message
     "Makanan terdeteksi, siap difoto". **Camera only, no gallery upload.** Includes tips and a camera flip button.
   - Step 2 of 3, review: "Semua sudah diisi. Cek sebentar, lalu bagikan."
     - Category auto-filled by AI ("Lauk matang", editable via *Ubah*), with the line "Foto lolos validasi".
     - Food name, portions stepper ("Sisa berapa porsi?").
     - Gratis / Jual murah toggle, price per porsi, and the "Boleh ditawar" checkbox.
     - Pickup deadline chips (19.00 / 20.30 / 22.00); pickup point taken from the profile (e.g. "Kos Melati, Pogung").
       The provider can change it for this listing only (*Ubah*): pick a saved point, or choose a point on the map
       (address search, optional point name, optional "Simpan ke titik tersimpan"). The exact point stays hidden from
       receivers until a reservation is accepted (Proposed privacy rule).
     - Provider guarantee: "Dengan membagikan, kamu menjamin makanan ini masih layak makan."
     - CTA "Bagikan sekarang".
   - Step 3 of 3: confirmation / published.
3. **Food detail**

   - Hero photo with the "Sisa 2 porsi" and "Foto asli, dicek AI" badges.
   - Provider avatar, name, tier tag and rating.
   - Stat tiles: Jarak (300 m, jalan kaki), Ambil sebelum (20.30, hari ini), Kategori (Lauk matang).
   - Price box: ~~Rp15.000~~ **Rp5.000** with a "Bisa ditawar" pill.
   - Quick offer chips ("Tawar cepat": Rp3.000 / Rp4.000 / Tulis sendiri). *Tulis sendiri* opens a sheet over the
     detail screen: offer per porsi, number of portions (up to the remaining stock) and an optional message. The offer
     must be above Rp0 and below the listed price (validated while typing; the full price goes through *Ambil*). Sending
     posts the offer in the chat as "Menunggu jawaban"; the portions are reserved only once the provider accepts.
     The minimum offer is an open question.
   - "Deskripsi": a short description from the provider (e.g. what the food is, how it is stored). The share form
     (Step 2) has no description field yet, see Open Questions.
   - Sticky actions: *Chat* (outline) and *Ambil · Rp5.000* (primary). *Ambil* creates a reservation (Core Feature 6).
4. **Map / Peta**

   - Header showing "Radius 1 km dari Pogung, Sleman" and a recenter button.
   - The same category chips as Beranda (*All*, *Ready-to-Eat*, *Fresh Ingredient*, *Sealed Food*), sharing one
     selection with Beranda.
   - Price-label pins ("Rp5.000", "Gratis"), a dashed radius circle and a bottom preview card
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
   - Quick replies: *Saya OTW*, *Masih ada?*, *Tawar lagi*.
6. **Reserve & pickup**

   - **Reserve.** Taking a listing, or having an offer accepted, reserves the portions for that receiver. The reservation
     is held until the provider's pickup deadline, then it expires and the portions reopen. The app removes reserved
     portions from "Sisa N porsi".
   - **QR confirmation, no manual code.** The provider opens a QR code for the reservation in the app. At the pickup
     point the receiver scans it with the app ("Pindai QR"). Each QR works for one reservation and one scan. The scan is
     only accepted **within the pickup time window** (up to the provider's deadline). A scan outside the window is
     rejected and the reservation expires. There is no pickup code to type or read out.
   - A successful scan marks the listing `picked_up`, counts the portions as rescued, notifies the provider ("diambil
     [nama]") and awards the provider impact points (Core Feature 8). The receiver goes straight to the review screen
     (Core Feature 7), with no extra confirmation step. The provider does not need to tap anything.
   - Payment is cash on pickup in the MVP. No flow may ask users to transfer money outside the app.
   - **Choosing how to pay** (Figma lo-fi B10d-B10i, C17d). Right after an offer is accepted, or after *Ambil* at full
     price, the receiver picks a payment method ("Pilih cara bayar"). Free listings skip this step.
     - *Tunai di tempat* (MVP default): back to the chat; the receiver pays the provider in cash at pickup, after
       scanning the QR.
     - *Bayar di aplikasi* (**post-MVP, Proposed**): QRIS only, through a payment gateway (Midtrans or Xendit). No
       e-wallet or virtual-account options. The QRIS belongs to PawonFood, never to the provider's own account. PawonFood holds the money until the pickup QR is scanned, then releases it to the provider's balance.
       If the reservation expires or is cancelled, the receiver gets a full refund. A failed or expired payment keeps
       the reservation until the pickup deadline and offers "Coba lagi" or switching to cash.
     - The receiver pays the agreed price with no extra fee, and the provider receives the full price: no platform
       fee is deducted. PawonFood covers the QRIS gateway cost from ad revenue (**Proposed**). Provider balance and
       withdrawal to a bank account are not designed yet. The Figma mockups still show a 5% fee and e-wallet
       options, and need an update.
7. **Rating & review**

   - Receivers rate food quality after pickup. The review screen opens right after the QR scan, so the receiver rates
     while still at the pickup point. Receivers can skip it with the back button.
   - **Post-MVP:** after the receiver taps "Kirim ulasan", a full-screen ad opens (see Ads), then the app returns to
     Beranda. Skipping the review shows no ad (**Proposed**).
   - Providers with repeated bad reviews are suspended first: their listings are hidden and they cannot share food.
     If bad reviews continue after the suspension ends, they are blocked.
8. **Profile / Profil & gamification**

   - Role "Penerima dan penyedia · Pogung, Sleman".
   - Level card with tier progress: **Pawon Friend → Pawon Elite → Pawon Hero** ("[X] poin lagi untuk naik ke Pawon Elite").
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
   - Must carry the positioning: a food-rescue network, not a cheap-food app.

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
- **Rules (Proposed):** at most one ad per receiver per day, no ads for providers, no ads inside the QR flow, and the
  ad never delays saving the review.

## Trust & Food Safety

These rules address the core problem, food safety + trust.

- PawonFood is an **intermediary / bulletin board**, not a food producer.
- Photos are taken with the camera only and validated by AI. Photos from the internet or non-food objects are rejected.
- Providers confirm the guarantee line before publishing.
- Receivers accept a ToS checkbox on the payment screen (cash or in-app), right above the confirm button, e.g. "Saya
  telah memeriksa kondisi makanan dan membebaskan PawonFood dari tuntutan kesehatan." The button stays disabled until
  it is checked.
- Every listing carries an explicit pickup deadline, so food is not left to sit for long.
- The receiver confirms pickup by scanning the provider's QR inside the pickup time window. The scan proves the
  receiver was at the pickup point on time and releases impact points. A QR works once and only for its reservation.
- Payment is cash on pickup in the MVP.
- Rating-based enforcement for providers with poor quality: suspension first, then a block if it repeats.
- **Never call providers "Borjuis".** The tier names above replace it.

## Business Model (Business Model Canvas)

| Component              | PawonFood                                                                                                                                                                           |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Customer segments      | Receivers: anak kos, panti asuhan, low-budget people. Providers: households/ibu kos, warung, restaurants, bakeries, communities.                                                    |
| Value proposition      | Receivers: cheap or free food within walking distance. Providers: less waste and loss, impact points/badges, green branding.                                                        |
| Channels               | Mobile app (Android & iOS), Instagram/TikTok anti-food-waste campaigns, BEM/HIMA partnerships, door-to-door to warung near campus.                                                  |
| Customer relationships | Gamification & rewards, transparent ratings, in-app chat for price and pickup time.                                                                                                 |
| Revenue streams        | Main: targeted eco-friendly FMCG ads (incl. a full-screen ad after the review, post-MVP). Optional: promoted listings (top of map). No fee on transactions: providers and receivers pay Rp0 to PawonFood. |
| Key activities         | Platform development, quality control of reports, marketing and education.                                                                                                          |
| Key resources          | Tech infrastructure (server, DB, Maps API), core team, a dense local user community.                                                                                                |
| Key partners           | Environmental NGOs (e.g. Zero Waste Indonesia), payment gateways for QRIS (Midtrans, Xendit), Google Maps, campuses and panti asuhan.                                                        |
| Cost structure         | Hosting and paid APIs, marketing (promos, QR stickers at partner warung), team operations.                                                                                          |

## Competitors & USP

| Feature                               | Surplus | Garda Pangan | DamoGO | PawonFood |
| ------------------------------------- | :-----: | :----------: | :----: | :-------: |
| Household kitchens as providers (C2C) |   ✗   |      ✗      |   ✗   |    ✓    |
| Free food / charity                   |   ✗   |      ✓      |   ✗   |    ✓    |
| Flexible price / negotiation via chat |   ✗   |      ✗      |   ✗   |    ✓    |
| AI photo validation (YOLO)            |   ✗   |      ✗      |   ✗   |    ✓    |
| QR-confirmed pickup                   |   ✗   |      ✗      |   ✗   |    ✓    |

Pitch line: *"Surplus fokus menyelamatkan croissant dari bakery mewah. PawonFood fokus menyelamatkan sayur lodeh sisa
masak ibu kos dan lauk warteg untuk anak kos di akhir bulan."*

## MVP Scope

**In scope (core journey):** Upload food → YOLO validation → listing appears on map/feed → negotiate → reserve →
QR-confirmed pickup.

- Mock / hardcoded data for map locations and listings.
- On-device YOLO validation with a visible "AI sedang memindai..." scan animation.
- Record a backup demo video of the full flow, from login to a completed pickup.

**Out of scope for MVP:** password reset, profile editing, in-app payments, real point redemption, promoted listings, ads.

**Where the built app stands against this PRD** (updated 2026-10-07, when the app was brought to all 75 Figma hi-fi
screens):

- Built beyond the MVP scope, as **simulated** flows on mock data (no backend, no gateway): QRIS payment, password
  reset, the post-review ad (image and video variants, at most one a day), settings and help screens.
- Categories: all three exist (chips *All · Ready-to-Eat · Fresh Ingredient · Sealed Food*, and "Ubah kategori" with
  "Baik digunakan sebelum"). The AI validator still knows only two classes, so sealed food is picked by hand.
- Pickup: reservation until the deadline, "Pilih cara bayar", walking route, provider QR and receiver scan are built.
  Decoding is simulated (the in-memory demo cannot link two phones), and so is the other side scanning.
- Proposed rules: listings show only the area until a reservation exists; reservations expire at the deadline and
  reopen the portions. The rating penalty for repeated no-shows is not built.

## Success Metrics

- Portions saved (porsi diselamatkan) and kg of food kept out of the trash
- Active providers per area, listings per day
- Pickup completion rate (reservations that end in `picked_up`)
- No-show rate (reservations that expire without a scan)
- Median time from publish to pickup
- Average provider rating; share of photos rejected by AI
- Impact estimate for the pitch: "Jika 50 warung bergabung, X kg makanan terselamatkan per bulan, Y kg emisi metana berkurang."

## Open Questions

- Mockup placeholders to fill: `[RATING]` format, `[X] poin` tier thresholds and reward costs, `[X] kg` impact formula,
  `[Nama kamu]`, `[EMAIL TIM]`.
- Point rules (per portion? bonus for free food?) and the review threshold for a suspension, how long it lasts, and the threshold for a block.
- Confirm the **Proposed** Privacy, Social stigma and No-show rules with the team.
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
