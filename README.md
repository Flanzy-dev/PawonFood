# PawonFood

*Dari dapur rumah tangga ke komunitas. Masak lebih? Jual dan bagikan tanpa ribet.*

PawonFood is a food marketplace for one neighborhood at a time. Home cooks, *ibu kos*, and *warung* list leftover or extra portions, and people within 1 km (students, neighbors, orphanages) can buy them cheaply, haggle over the price, or get them for free. The food gets eaten instead of thrown away, and the cook earns a little money.

We built it for a sustainability hackathon at UGM. It targets SDG 2 (Zero Hunger), SDG 8 (Decent Work and Economic Growth), and SDG 12 (Responsible Consumption).

**Team** (Computer Science, Binus University)
- Raditya Christiano Aravajordan (2902649234)
- Daniel Isaac Ismanto (2902587362)
- Muhammad Cesar Maulana (2902733232)

## Why

- **Delivery apps don't fit home cooks.** GoFood and ShopeeFood require an MoU, a long verification process, fixed opening hours, and a 20–30% commission. That doesn't work for someone who cooks 5–10 extra portions a day.
- **Most food waste comes from homes.** According to Bappenas (2021), 80% of food wasted at the consumption stage in Indonesia comes from households.
- **Short-distance delivery is overpriced.** Many students living in *kos* don't have a motorbike, and paying courier fees for food 300 meters away makes no sense.
- **Food-rescue apps skip home kitchens.** Surplus and DamoGO only work with restaurants and bakeries, use fixed prices, and require pickup. None of them let a household sell its leftovers.

## How it works

Every account can both buy and sell. There's no MoU and no platform commission.

**Buying.** Browse the home feed or the 1 km map. The feed reorders itself based on what you tap and how long you look at it. You can take free food, pay the listed price, or make an offer in chat. Then choose to pick it up yourself (no fee) or have the cook bring it over. When you receive the food, scan the cook's QR code and leave a rating.

**Selling.** Take a photo of the food with the in-app camera. The app checks that the photo actually shows food. Set a price (free, fixed, or open to offers) and say whether you can deliver. Publishing takes three taps or fewer. You keep everything you earn, and each completed handover gives you impact points that raise your level (*Pawon Friend → Pawon Elite → Pawon Hero*) and can be exchanged for vouchers.

Photos can only come from the live camera, not the gallery, so people can't post pictures they found online. Every handover is confirmed by scanning a QR code in person.

## Status

| Part | State |
| --- | --- |
| Mobile app ([`app/`](app/)) | MVP complete. All 75 hi-fi Figma screens are built, the full flow runs on mock data, and 74 tests pass. |
| Feed ranking | Runs on the device. Reorders the feed using taps and view time. |
| Photo check | Simulated behind the `FoodValidator` interface. The real YOLOv8 → TFLite model is still in progress. |
| Landing page ([`web/`](web/)) | Built with Next.js and TypeScript (single static page, Indonesian copy). Store links and the contact email are not set yet; see [web/README.md](web/README.md). |
| ML (`ml/`) | In progress. Python, YOLOv8 exported to TFLite. |
| Backend | None yet. All data is mocked in memory. Supabase is planned (see [ARCHITECTURE.md](ARCHITECTURE.md)). |

## Running the app

You need the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
cd app
flutter pub get
flutter run
```

Checks:

```bash
flutter analyze
flutter test
```

You can sign in with any valid email or phone number and any password. You'll be logged in as the demo user "Rafi Pratama". The map loads OpenStreetMap tiles, so you need an internet connection.

[app/README.md](app/README.md) covers the demo data, simulated chat, routes, and folder structure.

## Stack

- **Mobile:** Flutter/Dart, Riverpod, go_router, flutter_map
- **Design:** Figma, Bricolage Grotesque + Inter, Lucide icons. Tokens are in [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).
- **Web:** Next.js 16, React 19, TypeScript, plain CSS with the design tokens, Lucide icons
- **Planned:** Supabase, YOLOv8 → TFLite on the device

## Docs

| File | Contents |
| --- | --- |
| [PRD_PawonFood.md](PRD_PawonFood.md) | Product requirements, features, feed ranking, open questions |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design, data model, photo validation rules |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Colors, typography, spacing, components |
| [AGENTS.md](AGENTS.md) | Conventions for contributors and coding agents |

## Conventions

- In-app text is in Indonesian. Code, comments, and docs are in English.
- Use the theme tokens. Don't hardcode colors or font sizes in widgets.
- Keep secrets in `.env` or `--dart-define`. Never commit API keys.
