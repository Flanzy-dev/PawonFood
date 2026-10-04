# PawonFood

**Dari dapur ke dapur.** *Masak kebanyakan? Bagikan, jangan buang.*

PawonFood is a hyperlocal surplus-food sharing app. It connects home kitchens, warung and ibu kos with nearby
students, within walking distance, so edible leftovers get eaten instead of thrown away. It starts in Pogung
(Sleman, near UGM) and is meant to grow to all of Yogyakarta.

Built for a UGM sustainability hackathon. It supports **SDG 2 (Zero Hunger)** and **SDG 12 (Responsible Consumption)**.

## The problem

- Households, warung, catering and ibu kos regularly cook too much, and the leftovers end up in the trash.
- Students living in kos need cheap meals and often have no motorbike.
- Existing apps only take surplus from formal restaurants and bakeries at fixed prices. Nobody serves the grassroots
  household kitchen.

## How it works

One app, two sides:

- **Receivers (penerima):** open the map or the feed, find food within walking distance, take it for free or
  negotiate the price in chat, show the pickup code, then leave a review.
- **Providers (penyedia):** photograph the leftovers, let the AI check the photo, share in three taps or fewer,
  accept offers, and collect points that unlock tiers (Sobat Pawon → Food Savior → Pahlawan Pangan) and vouchers.

Food photos come from the camera only. There is no gallery picker, so photos cannot be taken from the internet.

## Status

| Part | State |
| --- | --- |
| Mobile app, [`app/`](app/) | MVP done: 18+ screens, full journey on mock data, 74 tests passing |
| AI photo check | **Simulated** behind a `FoodValidator` interface. The real YOLOv8 → TFLite model is not built yet |
| Landing page (`web/`) | Designed in Figma, not coded yet (Next.js / TypeScript planned) |
| ML (`ml/`) | Not started (Python, YOLOv8 → TFLite) |
| Backend | None. Everything is in-memory mock data (Supabase is planned, see [ARCHITECTURE.md](ARCHITECTURE.md)) |

## Run the app

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
cd app
flutter pub get
flutter run
```

```bash
flutter analyze
flutter test
```

Demo login: any valid email or phone number with any password signs in as the demo persona "Rafi Pratama".
The map uses OpenStreetMap tiles and needs internet. More detail (demo data, simulated chat, assumptions, routes,
folder structure) is in [app/README.md](app/README.md).

## Tech stack

- **Mobile:** Flutter / Dart, Riverpod, go_router, flutter_map
- **Design:** Figma (Bricolage Grotesque + Inter, Lucide icons), tokens in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)
- **Planned:** Next.js landing page, Supabase backend, YOLOv8 → TFLite on-device food check

## Documentation

| File | Contents |
| --- | --- |
| [PRD.md](PRD.md) | Product requirements, features and open questions |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, data model, AI validation rule |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Colors, typography, spacing and component rules |
| [AGENTS.md](AGENTS.md) | Conventions for contributors and coding agents |

## Conventions

- UI copy is **Indonesian**. Code, comments and docs are **English**.
- Use the theme tokens from the design system. Do not hardcode colors or font sizes in widgets.
- Never expose API keys. Keep secrets in `.env` or `--dart-define`, never in the repo.
