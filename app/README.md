# PawonFood (mobile app)

Flutter app for PawonFood, the hyperlocal surplus-food sharing app ("Dari dapur ke dapur"). This is the MVP:
the whole journey **upload → AI check → feed/map → negotiate → reserve → pay → walk → scan the provider's QR →
review** works on mock data. Every one of the 75 Figma hi-fi screens (A1–D22b) has a screen or state in the app.

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

Note: `flutter create` fails inside the OneDrive folder on this machine; the project was scaffolded in a temp folder and copied.

## Demo account and data

- Everything is mock data in `assets/mock/*.json` held in memory (restarting the app resets it). Times in the JSON are
  relative to "now", so the data never goes stale.
- **Onboarding (A0a-A0c):** three intro slides show once, on the first launch on a device, before Welcome. Lewati or
  Mulai marks them seen in `shared_preferences` (`onboarding_seen`), the only thing the app stores on the device. To
  see them again, clear the app data or reinstall. Widget tests leave the storage unset, so they start on Welcome.
- **Login:** any valid email or phone + any password signs in as the demo persona "Rafi Pratama" (150 poin, Pawon Friend).
  **Register** creates a new user with 0 points; the seeded chats stay available so the whole journey can be demoed.
- The other party in chats is simulated (`core/data/chat_repository.dart`):
  - an offer of at least 50% of the price is accepted after about 1.5 s (B10j "Menunggu jawaban" shows meanwhile);
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

## AI photo check (simulated)

`core/services/food_validator.dart` implements the decision rule from `ARCHITECTURE.md` (no detection → rejected;
`bukan_makanan` > 0.70 → rejected; food class > 0.60 → approved; otherwise manual review). The MVP uses
`SimulatedFoodValidator` behind the `FoodValidator` interface, so the real YOLO/TFLite model (`/ml`) can replace it
without UI changes.

**Demo switches:**

- long-press "Langkah 1 dari 3" on the camera screen to force *Normal*, *Bahan mentah*, *Bukan makanan* (rejected) or
  *Ragu-ragu* (manual review);
- long-press "Bayar dengan QRIS" to make the payment fail (B10h);
- long-press the "Iklan" pill to swap the image and video ad;
- tap the scanner preview (B10b) or the provider's QR (C17) to scan right away.
The camera is live only: there is no gallery picker anywhere (listing photos must come from the camera).

## Assumptions (open questions in PRD.md)

| Topic | Value |
| --- | --- |
| Tiers | Pawon Friend 0, Pawon Elite 500, Pawon Hero 1.500 points |
| Provider points per pickup | +10 per portion, ×2 for free food, +5 for a rating of 4+ |
| Impact | 0,5 kg of food per portion saved |
| Walking speed | 80 m/min (`300 m` → `± 4 mnt jalan kaki`) |
| Food labels | one label per card: **Hampir habis** (1 portion left), else **Populer** (Pawon Hero provider), else **Terbaru** (cooked within 60 min) |
| Redeeming points | works on mock data: claiming deducts the points and creates a `PWN-V-XXXX` code valid 30 days (in memory, no payment). "Voucher saya" (ticket icon on Tukar poin) lists them, with 4 seeded vouchers |
| Food vouchers | "Potongan makanan Rp3.000 / Rp5.000" (120 / 200 poin, chip Makanan on Tukar poin) are used on Pembayaran via "Pakai voucher": pick one from Voucher saya or type the code (`PWN-V-3001` and `PWN-V-3002` are seeded). Once applied, the voucher card stays and shows that voucher (tap to change it, ✕ on the right removes it), and Rincian lists only the code and the discount. The payment never goes below Rp1.000, the voucher turns "Terpakai" only when the payment is confirmed, and partner vouchers (minimarket, ojek) are refused there. The provider's saldo keeps the full price |
| Certificate (D19b) | issued monthly, not claimable: 30 portions a month and an average rating ≥ 4,5 (the Figma shows `[X]`) |
| Settings, password reset | simulated: settings live in memory, any 6-digit code passes, "Hapus akun" signs out. Google/Apple sign-in stays "Segera hadir" |
| Support email, legal date | `supportEmail` is still the Figma placeholder `[EMAIL TIM]` (`features/settings/help_screens.dart`); the legal pages say "Terakhir diperbarui 7 Oktober 2026" |
| Pickup points | saved points live in memory (Kos Melati "Utama", Warteg Bu Siti); map search knows 5 places around Pogung; GPS is fixed at Jl. Pogung Baru No. 14 |

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
```

Credits for photos, fonts and map data: `assets/CREDITS.md`.
