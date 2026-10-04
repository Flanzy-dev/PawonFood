# PawonFood (mobile app)

Flutter app for PawonFood, the hyperlocal surplus-food sharing app ("Dari dapur ke dapur"). This is the MVP:
the whole journey **upload → AI check → feed/map → negotiate → pickup with code → review** works on mock data.

UI copy is Indonesian and follows the Figma hi-fi screens. Code, comments and docs are English.

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
- **Login:** any valid email or phone + any password signs in as the demo persona "Rafi Pratama" (150 poin, Sobat Pawon).
  **Register** creates a new user with 0 points; the seeded chats stay available so the whole journey can be demoed.
- The other party in chats is simulated (`core/data/chat_repository.dart`):
  - an offer of at least 50% of the price is accepted after about 1.5 s, which creates the `PWN-XXXX` pickup code;
  - a lower offer gets a counter offer (about 60% of the price); non-negotiable listings only take the full price;
  - **Saya berbagi** has an incoming offer from "Dina Ayu" on your own listing (Terima / Tolak, then "Tandai diambil").
- **Empty-state demo:** Beranda → location → *Condongcatur, Sleman* (no listing within 1 km, one within 2 km).
- **Map** uses OpenStreetMap tiles and needs internet. Offline you still see the sand background with pins.

## AI photo check (simulated)

`core/services/food_validator.dart` implements the decision rule from `ARCHITECTURE.md` (no detection → rejected;
`bukan_makanan` > 0.70 → rejected; food class > 0.60 → approved; otherwise manual review). The MVP uses
`SimulatedFoodValidator` behind the `FoodValidator` interface, so the real YOLO/TFLite model (`/ml`) can replace it
without UI changes.

**Demo mode:** long-press "Langkah 1 dari 3" on the camera screen to force *Normal*, *Bahan mentah*,
*Bukan makanan* (rejected) or *Ragu-ragu* (manual review).
The camera is live only: there is no gallery picker anywhere (listing photos must come from the camera).

## Assumptions (open questions in PRD.md)

| Topic | Value |
| --- | --- |
| Tiers | Sobat Pawon 0, Food Savior 500, Pahlawan Pangan 1.500 points |
| Provider points per pickup | +10 per portion, ×2 for free food, +5 for a rating of 4+ |
| Impact | 0,5 kg of food per portion saved |
| Walking speed | 80 m/min (`300 m` → `± 4 mnt jalan kaki`) |
| Food labels | one label per card: **Hampir habis** (1 portion left), else **Populer** (Pahlawan Pangan provider), else **Terbaru** (cooked within 60 min) |
| Redeeming points | works on mock data: claiming deducts the points and creates a `PWN-V-XXXX` code valid 30 days (in memory, no payment). The monthly certificate is not claimable ("Segera hadir") |
| Settings, password reset, social login | not in the MVP ("Segera hadir") |

## Routes

Tabs: `/` Beranda, `/map` Peta (draggable bottom sheet: collapsed, half, full), `/messages`, `/profile`. Pushed screens: `/semua` (full food list), `/listing/:id`, `/chat/:id`, `/review/:id`, `/share/camera`, `/share/form`, `/share/done/:id`, `/rewards` (Tukar poin catalog), `/reward/:id` (detail, confirm sheet), `/reward/claimed` (voucher code).

## Structure

```text
lib/
  core/theme/      colors, typography, spacing/radius tokens from DESIGN_SYSTEM.md
  core/widgets/    shared widgets (FoodCard, MiniFoodCard, RewardCard, pills, chips, form controls, brand icons, bottom nav, PawonMap, ...)
  core/models/     Listing, Conversation, Offer, Pickup, Review, AppUser, Reward, ClaimedVoucher, ...
  core/services/   food_validator, food_label, negotiation, points, rewards, formatters, validators, geo, camera_service
  core/data/       Riverpod notifiers: session, listings/feed, chat/offers/pickups, rewards
  core/mock/       MockData loader
  features/        auth, home, map, listing, chat, review, share, profile, shell
assets/            fonts (Bricolage Grotesque, Inter), food photos, brand images, mock JSON
test/              unit, repository, widget and full-journey tests
```

Credits for photos, fonts and map data: `assets/CREDITS.md`.
