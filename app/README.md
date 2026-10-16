# PawonFood (mobile app)

Flutter app for PawonFood, the hyperlocal surplus-food sharing app ("Dari dapur ke komunitas"). This is the MVP.
The whole journey (upload → AI check → feed/map → negotiate → reserve → pay → walk → scan the provider's QR →
review) works on mock data. Every one of the 75 Figma hi-fi screens (A1–D22b) has a screen or state in the app.

UI copy is Indonesian and follows the Figma hi-fi screens word for word (the Beranda chips are English on purpose).
Code, comments and docs are English.

## Run

Flutter is installed at `~/flutter` but is not on PATH on this machine:

```bash
export PATH="$HOME/flutter/bin:$PATH"     # Git Bash; in PowerShell: $env:Path = "$env:USERPROFILE\flutter\bin;$env:Path"
cd app
flutter pub get
flutter emulators --launch testing   # or plug in a phone
flutter run
```

```bash
flutter analyze
flutter test
```

To use the cloud AI photo check instead of the simulation, start [`server/`](server/README.md) and add
`--dart-define=PAWON_VALIDATOR_URL=http://10.0.2.2:8787` (Android emulator) to `flutter run`.

Note: `flutter create` fails inside the OneDrive folder on this machine; the project was scaffolded in a temp folder and copied.

## Demo account and data

- Everything is mock data in `assets/mock/*.json` held in memory (restarting the app resets it). Times in the JSON are
  relative to "now", so the data doesn't go stale.
- **Onboarding (A0a-A0c):** three intro slides show once, on the first launch on a device, before Welcome. Lewati or
  Mulai marks them seen in `shared_preferences` (`onboarding_seen`), the only thing the app stores on the device. To
  see them again, clear the app data or reinstall. Widget tests leave the storage unset, so they start on Welcome.
- **Login:** any valid email or phone + any password signs in as the demo persona "Rafi Pratama" (150 poin, Pawon Friend).
  Register creates a new user with 0 points; the seeded chats stay available so the whole journey can be demoed.
- The other party in chats is simulated (`core/data/chat_repository.dart`):
  - an offer of at least 50% of the price is accepted after about 8 s (B10j "Menunggu jawaban" shows meanwhile, with "Batalkan tawaran");
    acceptance or "Ambil" reserves the portions until the pickup deadline;
  - a lower offer gets a counter offer (about 60% of the price); non-negotiable listings only take the full price;
  - **Saya berbagi** has an incoming offer from "Dina Ayu" on your own listing (Terima / Tolak, then "Buka QR ambil";
    Dina "scans" it after about 5 s and the screen moves on to "Makanan terselamatkan!").
- **Pickup is QR only** (no code to read out): the provider shows a QR per reservation, the receiver taps "Pindai QR".
  Decoding is simulated: the scanner finds the code after 2.5 s, or tap the preview. A scan after the deadline expires
  the reservation (B10c). After the scan the receiver goes straight to the review.
- **Payment:** "Pilih cara bayar" offers *Tunai di tempat* or *QRIS*, and the food-condition consent sits above the
  button. QRIS is simulated: the first "Cek status pembayaran" answers "belum masuk", the second succeeds.
- **Ads (post-MVP, built for the demo):** after "Kirim ulasan", one full-screen ad a day (image or video, picked at
  random; the video is a slowly zooming still with a 15 s progress bar). The sponsor "Wadahku" is fictional.
- **Empty-state demo:** Beranda → location → *Condongcatur, Sleman* (no listing within 1 km, one within 2 km).
- **Map** uses OpenStreetMap tiles and needs internet. Offline you still see the sand background with pins.
- **Route to the pickup point (B8b-B8d)** starts from the phone's GPS when it can be read (else the chosen area) and
  follows real streets from the OpenStreetMap foot router (`core/services/route_service.dart`, FOSSGIS
  `routing.openstreetmap.de`, no key). Turns are shown in Indonesian. Offline, or while it loads, an estimated path is
  shown with "Rute perkiraan · jalan belum termuat". OSM may miss small gangs, so a route can detour along main roads
  (Pogung → Warteg Bu Siti: about 1,2 km for 250 m in a straight line). While walking, "Kamu" follows live GPS and
  the screen moves to "Kamu sudah sampai" within 30 m; without GPS the walk is animated. The copy "Mencari rute
  jalan...", "Rute perkiraan" and the turn phrases is not in Figma yet.

## AI photo check (simulated or cloud Qwen)

Everything goes through the `FoodValidator` interface (`core/services/food_validator.dart`), so the UI doesn't care
which implementation runs:

- **Simulated (default):** `SimulatedFoodValidator` follows the YOLO decision rule from `ARCHITECTURE.md` (no
  detection → rejected; `bukan_makanan` > 0.70 → rejected; food class > 0.60 → approved; otherwise manual review).
- **Cloud:** run with `--dart-define=PAWON_VALIDATOR_URL=<server>` and `CloudFoodValidator`
  (`core/services/cloud_food_validator.dart`) posts the photo to [`server/`](server/README.md). The server asks a Qwen
  vision model and returns `approved`, `pending_review`, `retake` or `rejected`, plus what the AI saw. The app holds no
  model key. It parses the answer strictly: a network error, a timeout or a malformed answer throws
  `ValidationUnavailable`, which is never treated as passed.
- The real YOLO/TFLite model (`/ml`) can still replace the simulation later without UI changes.

The camera is a plain camera: no scan line, detection box or "memindai" label, in either mode. The shutter takes the
photo and opens the form straight away. The AI check runs in the background (`ShareCaptureNotifier` in
`features/share/share_state.dart`) and fills in the food name, category, description (`Deskripsi`) and "Pilihan sehat"
tags when it arrives. A field the provider already edited by hand is never overwritten.

What the form shows for each result:

| Result | Form (step 2) |
| --- | --- |
| checking | "AI sedang mengenali makanan..." with a spinner (a static icon under reduced motion); "Bagikan sekarang" is switched off |
| approved | "Foto lolos validasi"; name, category, description and tags filled in |
| pending_review | "Menunggu tinjauan manual"; an unknown category shows "Pilih kategori" and must be picked before publishing; the AI notes show in "Catatan AI" |
| retake | "Foto belum lolos" + "Foto kurang jelas" box + *Foto ulang* (back to the camera); "Bagikan sekarang" is switched off |
| rejected | "Foto belum lolos" + "Foto tidak bisa dipakai" box (with what was seen) + *Foto ulang*; "Bagikan sekarang" is switched off |
| check failed | "Pemeriksaan AI gagal" + *Coba lagi* (re-checks the same photo) / *Foto ulang*; "Bagikan sekarang" is switched off |

The form refuses to publish without a passed photo, and the repository refuses `AiStatus.rejected`. Category
correction ("Ubah") stays open. The listing keeps the AI's category in `aiCategory`, so `categoryCorrected` shows
when the provider changed it. The description is saved to `Listing.description`.

The copy for the new states (checking, retake, check failed, "Pilih kategori", "Catatan AI", "Deskripsi")
is not in the Figma file yet. It was written to match the existing tone.

**Demo switches:**

- long-press "Langkah 1 dari 3" on the camera screen (simulated mode only) to force *Normal*, *Bahan mentah*,
  *Bukan makanan* (rejected), *Ragu-ragu* (manual review), *Foto buram* (retake) or *Server AI gagal* (check failed, *Coba lagi*);
- long-press "Bayar dengan QRIS" to make the payment fail (B10h);
- long-press the "Iklan" pill to swap the image and video ad;
- tap the scanner preview (B10b) or the provider's QR (C17) to scan right away;
- long-press "Mulai jalan" on the route (B8b) to run the animated walk even when GPS is available.

Listing photos come from the live camera only. There is no gallery picker anywhere.

## Assumptions (open questions in PRD_PawonFood.md)

| Topic | Value |
| --- | --- |
| Tiers | Pawon Friend 0, Pawon Elite 500, Pawon Hero 1.500 points |
| Provider points per pickup | +10 per portion, ×2 for free food, +5 for a rating of 4+ |
| Impact | 0,5 kg of food per portion saved |
| Walking speed | 80 m/min (`300 m` → `± 4 mnt jalan kaki`) |
| Food labels | one label per card: "Hampir habis" (1 portion left), else "Segar" (fresh raw ingredients), else "Sehat" (health score ≥ 0.5), else "Populer" (Pawon Hero provider), else "Terbaru" (cooked within 60 min) |
| Feed ranking | score = affinity × proximity × urgency (`core/services/food_score.dart`; ARCHITECTURE.md → Feed ranking). Affinity comes from the FYP recommender in `ml/fyp/` with `--dart-define=PAWON_FYP_URL=...` (demo mapping: account = model user `u0`, listings carry `fypItem`); without it the feed is proximity × urgency. The app logs `view` (detail open 3 s), `addtocart` (Ambil or offer) and `transaction` (QR scan) to the server. Semua makanan sorts by "Rekomendasi" by default |
| Pilihan sehat | provider tags Sayur/buah, Protein, Tidak digoreng, Rendah gula, pre-selected from the AI (simulated: Ayam goreng → Protein, Bahan mentah → Sayur/buah + Tidak digoreng). Describes composition, not safety |
| Ide resep | Bahan mentah only: 8 local recipes (`assets/mock/recipes.json`) matched by ingredient keywords; the provider attaches one ("Diverifikasi pemberi"); buyers see it on the detail, and when none is attached they still see the best library match labelled "Belum diverifikasi pemberi". The seller's own listing shows no recipe card. "Minta ide dari AI" appears only with `PAWON_VALIDATOR_URL` |
| Redeeming points | works on mock data: claiming deducts the points and creates a `PWN-V-XXXX` code valid 30 days (in memory, no payment). "Voucher saya" (ticket icon on Tukar poin) lists them, with 4 seeded vouchers |
| Food vouchers | "Potongan makanan Rp3.000 / Rp5.000" (120 / 200 poin, chip Makanan on Tukar poin) are used on Pembayaran via "Pakai voucher": pick one from Voucher saya or type the code (`PWN-V-3001` and `PWN-V-3002` are seeded). Once applied, the voucher card stays and shows that voucher (tap to change it, ✕ on the right removes it), and Rincian lists only the code and the discount. The payment has a Rp1.000 minimum, the voucher turns "Terpakai" only when the payment is confirmed, and partner vouchers (minimarket, ojek) are refused there. The provider's saldo keeps the full price |
| Certificate (D19b) | issued monthly, not claimable: 30 portions a month and an average rating ≥ 4,5 (the Figma shows `[X]`) |
| Settings, password reset | simulated: settings live in memory, any 6-digit code passes, "Hapus akun" signs out. Google/Apple sign-in stays "Segera hadir" |
| Support email, legal date | `supportEmail` is still the Figma placeholder `[EMAIL TIM]` (`features/settings/help_screens.dart`); the legal pages say "Terakhir diperbarui 7 Oktober 2026" |
| Delivery | mock listings Nasi Telur (Rp2.000), Nasi Campur Lengkap (Rp3.000), Sayur Campur dari Pasar (free food, Rp0) and your own Nasi Campur Kos Melati (Rp2.000) can be delivered; Roti Manis Kotakan (Rp2.000) is delivery only. The receiver chooses on the detail before Ambil; the address is the primary saved point (Kos Melati), changeable with "Ubah alamat antar" and refused beyond 1 km. The fee chips are Rp0 / Rp2.000 / Rp3.000, and the share form needs at least one of "Ambil di tempat" and "Bisa diantar". Cards show a bike icon only. **Saya berbagi** has a seeded delivery (Dito, cash, to Kos Mawar): "Lihat rute antar" opens the route screen as "Rute antar" (foot router, long-press "Mulai antar" for the demo walk) and ends on "Buka QR ambil" |
| Pencarian | Tapping the Beranda search bar opens `/search` (`features/home/search_screen.dart`): the bar flies to the top of a white page (`Hero`, off under reduced motion). Empty bar: "Pencarian terakhir" (last 8 words, kept in `shared_preferences`, removable one by one or all at once) and "Populer di sekitarmu" (words from a fixed list that match a visible listing in the radius, top 6). Typing shows `Cari "..."` plus matching nearby foods. Picking or submitting a term closes the page and filters the Beranda feed (`searchQueryProvider`); the ✕ on Beranda clears it |
| Pickup points | saved points live in memory (Kos Melati "Utama", Warteg Bu Siti); map search knows 5 places around Pogung. "Pilih lokasi di peta" opens at the phone's GPS position when it can be read (else the demo point Jl. Pogung Baru No. 14), and a point away from the known places gets its address from the platform geocoder |
| Location | Pogung stays the default because the mock listings are there. Real GPS is used only on request: "Gunakan lokasi saat ini" in Ganti lokasi (Beranda, Peta, distances and the route follow it) and the pickup map. A position far from Pogung shows the empty state. The copy for this ("Gunakan lokasi saat ini", "Lokasi saat ini", "Titik di peta", the GPS error snacks) is not in Figma yet |

## Routes

- Tabs: `/` Beranda, `/map` Peta (draggable bottom sheet: collapsed, half, full), `/messages`, `/profile`.
- Food and chat: `/semua` (full list), `/listing/:id`, `/chat/:id`, `/review/:id`, `/ad`.
- Reserve and pick up (keyed by conversation id): `/pay/:id`, `/pay/:id/qris`, `/pay/:id/done`, `/pay/:id/failed`,
  `/route/:id`, `/scan/:id`, `/expired/:id`, `/qr/:id` (provider), `/qr/:id/done`.
- Share: `/share/camera`, `/share/form`, `/share/pick-point` (map picker), `/share/done/:id`.
- Profil: `/rewards`, `/reward/:id`, `/reward/claimed`, `/certificate`, `/vouchers`, `/profile/history`,
  `/profile/points`, `/settings`, `/settings/notifications`, `/settings/password`, `/settings/help`, `/settings/terms`,
  `/settings/privacy`.
- Auth: `/onboarding` (first launch only), `/welcome`, `/login`, `/register`, and `/forgot`, `/forgot/code`, `/forgot/new` (open signed in or out).

## Motion

All motion comes from `lib/core/motion/` (tokens in `motion.dart`, rules in DESIGN_SYSTEM.md → Motion): `Pressable`
press feedback (built into `AppButton`, `AppChip`, cards and icon buttons), `FadeSlideIn` + `EntranceScope` staggered
entrances, `FadeSwitch` cross-fades, `motionPage` route transitions and `FadeIndexedStack` tab fades, plus
`CheckBurst` (with `flood: true` it starts `playSuccessFlood`, the green screen cover on success), `AnimatedCount`, `ScanLine`, `ScanFrame`, `TypingDots` and `Pulse`. Everything turns off when the OS
"remove animations" setting is on (`Motion.reduced`); `test/support.dart` sets that for widget tests so looping
animations do not block `pumpAndSettle`. Every bottom sheet goes through `showAppSheet` for the shared sheet motion.

## Structure

```text
lib/
  core/theme/      colors, typography, spacing/radius tokens from DESIGN_SYSTEM.md
  core/motion/     motion tokens, press feedback, entrances, page transitions, animated marks
  core/widgets/    shared widgets (FoodCard, OptionRow, SettingsGroup, StatusLayout, InfoBox, QrBox, TopBar, app sheet, PawonMap, ...)
  core/models/     Listing, Conversation, Offer, Pickup (reservation + QR), Review, AppUser, Reward, ClaimedVoucher, ...
  core/services/   food_validator, food_label, negotiation, points, rewards, formatters, validators, geo, camera_service
  core/data/       Riverpod notifiers: session, listings/feed, chat/offers/pickups/payment, rewards/vouchers,
                   pickup points, settings, history
  core/mock/       MockData loader
  features/        auth, home, map, listing, chat, payment, pickup, review, ads, share, profile, settings, shell
assets/            fonts (Bricolage Grotesque, Inter), food photos, brand images, mock JSON
test/              unit, repository, widget and full-journey tests
server/            photo validation endpoint (Node, no dependencies): Qwen vision model + rules layer, see server/README.md
```

Credits for photos, fonts and map data: `assets/CREDITS.md`.
