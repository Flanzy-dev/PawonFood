# Architecture

## System overview

```text
Receiver / Provider                         Visitor
      ↓                                        ↓
Flutter mobile app                    Next.js landing site
(on-device YOLO validator)            (marketing, provider sign-up, store links)
      ↓                                        ↓
      └──────────────→  Backend  ←─────────────┘
                 MVP: local mock JSON
                 Post-MVP: Supabase
                 (Postgres + Auth + Storage + Realtime)
```

External services:

- Maps: Google Maps SDK or `flutter_map` (OSM). The MVP uses mock coordinates around Pogung.
- AI: YOLOv8 Nano exported to TFLite, running on-device via `flutter_vision`. No server cost.
- Payments (post-MVP): QRIS via Midtrans / Xendit, with no transaction fee. The MVP is cash on pickup.
- Web hosting: Vercel (Next.js).

## AI food validator

Purpose:

- Block fraud: empty photos, non-food objects, photos taken from the internet.
- Auto-fill the category.

Pipeline:

1. **Dataset**: transfer learning from pretrained `yolov8n.pt`. Data comes from Food-101 (Kaggle) and Indonesian food sets
   on Roboflow Universe (nasi rames, gorengan, lauk). Each photo gets one of three labels:
   `makanan_matang`, `bahan_mentah` or `bukan_makanan`.
   Fallback if accuracy is low: two classes, `food` / `non-food`.
2. **Train** with `ultralytics`: `model.train(data='dataset.yaml', epochs=50, imgsz=416)`. 30–50 epochs is enough for the MVP.
3. **Export**: `model.export(format='tflite', int8=True, imgsz=416)`.
4. **Ship**: copy the exported model to `app/assets/yolov8n_pawonfood.tflite`, with `assets/labels.txt` listing the
   classes in index order.
5. **Run in the app**:
   - `FlutterVision.loadYoloModel(modelVersion: "yolov8", quantization: true, numThreads: 2, useGpu: true)`.
   - Call `yoloOnImage(iouThreshold: 0.4, confThreshold: 0.5, classThreshold: 0.5)`.
   - Dispose the model with `closeYoloModel()`.

Decision rule (identical on device and in the optional server validator):

| Condition                                | Result                                                              |
| ---------------------------------------- | ------------------------------------------------------------------- |
| No detections                            | `rejected` ("Tidak ada makanan yang terdeteksi di foto.")         |
| `bukan_makanan` with confidence > 0.70 | `rejected` ("Gambar terdeteksi bukan makanan. Mohon foto ulang.") |
| Any food class with confidence > 0.60    | `approved`, category = class                                      |
| Otherwise                                | `pending_review` (manual review)                                  |

Optional server-side validator: a small Python service running the same `ultralytics` model with the same rule.
It re-checks uploads when the backend exists.

### Cloud vision validator (built)

`app/server/` is a dependency-free Node service with `POST /v1/food-validation`. It sends the photo to a Qwen vision
model (Alibaba Cloud Model Studio, OpenAI-compatible API) and runs a rules layer on the answer. The app uses it when
built with `--dart-define=PAWON_VALIDATOR_URL=...`; otherwise it keeps the simulated validator. The model key stays on
the server.

- **Qwen only observes.** It returns `is_food`, `category`, `food_name`, `visual_condition`, `visible_signs`,
  `image_quality` and `warnings`. It gives no scores, no expiry dates and no safety claims.
- **The server decides** `listing_eligible` and `decision`:

| Condition                                                   | Decision          |
| ----------------------------------------------------------- | ----------------- |
| Not food (`is_food` false or `bukan_makanan`)               | `rejected`        |
| Image not `good`, or condition `cannot_assess`              | `retake`          |
| `visible_spoilage` (mould, rot, insects)                    | `rejected`        |
| `unknown` category or `minor_concerns`                      | `pending_review`  |
| Otherwise                                                   | `approved`        |

A failed or malformed check never approves a photo. The visual check does not certify food safety; the provider
guarantee stays. Setup, deployment and limits are in `app/server/README.md`.

### Feed ranking

`feedProvider` ranks the Beranda feed ("Pilihan untukmu di sekitar") by `feedScore`
(`app/lib/core/services/food_score.dart`), highest first, nearest first on a tie. As in the PRD:

```text
score = affinity × proximity × urgency
```

| Factor | Range | How it is computed |
| --- | --- | --- |
| Affinity | 0.2..1 | From the FYP recommender (below): 1 for the item it ranks first, down to 0.2 for the last; 0.6 for a listing it does not rank (published in the app). 1 for every listing when no recommender is configured |
| Proximity | 0.2..1 | 1 at the user, 0.2 at the edge of the search radius |
| Urgency | 0.2..1 | Half from stock (1 portion = 1, 8+ = 0), half from time left to `pickup_by` (≤ 30 min = 1, ≥ 6 h = 0), then floored at 0.2 |

The floors keep any single factor from zeroing a listing out of the product.

**FYP recommender** (`ml/fyp/`, see its README): a trained ALS model (500 users × 200 items) behind a small FastAPI
server, received ready to use. The app reads `GET /recommend?user_id=u0&n=200` once (`fypRankingProvider`) with
`--dart-define=PAWON_FYP_URL=...`. It reports actions with `POST /event`:

- `view` when the food detail stays open 3 s;
- `addtocart` on "Ambil" or a sent offer;
- `transaction` on a successful QR scan.

The server only appends these to `data/events.csv`; the order learns from them after the model is retrained. The model
was trained on another dataset, so for the demo the demo account is model user `u0`, and each mock listing carries a
model item id (`fypItem` in `listings.json`). A failed or missing server leaves the feed on proximity × urgency.

Card labels are separate from the order: *Sehat* at a health score ≥ 0.5 (sum of the provider's tags: Sayur/buah 0.4,
Protein 0.25, Tidak digoreng 0.2, Rendah gula 0.15), *Segar* for raw ingredients at freshness ≥ 0.75. Freshness:
cooked food is 1 when just cooked and 0 after 6 h (0.5 if unknown), raw ingredients are 0.9, sealed food follows
`best_before` (3+ days = 1, today = 0.2). The tags are set by the provider; the cloud validator only pre-selects them
from `health_signals` (what is visibly in the photo, never a health rating, never low sugar). Nothing here certifies food
safety.

### Recipe ideas

Fresh ingredients ("Bahan mentah") can carry a recipe. The local library is `assets/mock/recipes.json`, matched to the
listing's name and description by ingredient keywords (`recipe_matcher.dart`). With `PAWON_VALIDATOR_URL` set, the
share form can also ask `POST /v1/recipe-ideas` on `app/server`: text only, the same token and rate limit, and a
strict schema that drops recipes with safety or health claims. Details in `app/server/README.md`.

Who sees what: the recipe is for buyers only (not on the seller's own listing). A recipe the seller attached
(`listing.recipe`) is shown as verified by the seller; without one, the detail screen shows the best library match with
a "Belum diverifikasi pemberi" label. AI-written recipes only exist in the share form, so one reaches a buyer only when
the seller picked it.

## Project structure

```text
/app                      # Flutter mobile app (Dart)
  /lib
    /core
      /theme              # Colors, typography, spacing tokens from DESIGN_SYSTEM.md
      /widgets            # Shared widgets (FoodCard, Chip, PillBadge, BottomNav, ...)
      /models             # User, Listing, Offer, Message, Pickup, Review, ...
      /services           # FoodValidator (flutter_vision), repositories, location
      /mock               # Mock JSON data for the MVP
    /features
      /home               # Beranda feed + mini map
      /map                # Peta with price pins and clusters
      /share              # Bagikan: camera → review → publish (3 steps)
      /listing            # Food detail
      /chat               # Pesan list + negotiation thread
      /profile            # Level, impact, tukar poin, settings
  /assets                 # yolov8n_pawonfood.tflite, labels.txt, images
/web                      # Next.js landing page (TypeScript)
  /app
  /components
  /public
/ml                       # YOLO training: dataset.yaml, train.py, export.py, validate.py
/docs                     # Project documentation and design PDFs
```

## Data model

| Entity                 | Key fields                                                                                                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                   | id, name, roles (receiver / provider), tier (`sobat_pawon` / `food_savior` / `pahlawan_pangan`), points, saved pickup point, location                                           |
| Listing                | id, provider_id, photo_url, name, category, portions_left, original_price, price, is_free, negotiable, pickup_by, pickup_point, lat/lng, delivery_fee (null = pickup only), allows_pickup (false = delivery only), ai_status, ai_confidence, health_tags, recipe (fresh ingredients), status, created_at |
| Offer                  | id, listing_id, receiver_id, amount, portions, status (`pending` / `accepted` / `rejected`), delivery (address, lat/lng, fee; null = pickup) |
| Conversation / Message | conversation per (listing, receiver); messages with sender, body, type (`text` / `offer` / `system`), created_at                                                                |
| Pickup                 | id, offer_id, qr_token (one reservation, one scan), deadline (= listing `pickup_by`), status (`reserved` / `picked_up` / `expired` / `cancelled`), pay_method (`cash` / `qris`), paid_at, picked_up_at |
| Review                 | pickup_id, rating, comment                                                                                                                                                            |
| PointLedger            | user_id, delta, reason (pickup, free-food bonus, redemption)                                                                                                                          |
| Reward                 | id, name (voucher minimarket, diskon ojek, sertifikat), cost                                                                                                                          |

Listing status: `available → reserved → picked_up`, or `expired` once past `pickup_by`, or `habis` when no portions are left.

## Key flows

### Share (provider)

Target: 3 taps or fewer.

1. Tap the Bagikan FAB. The camera opens; gallery upload is disabled.
2. The live YOLO preview shows the detected class. The provider takes the photo and the validation rule runs.
3. The form is pre-filled (category, portions, price, pickup time, pickup point). The provider confirms and publishes.
4. The listing appears in the feed and on the map.

### Claim (receiver)

1. Open a listing from the feed or map.
2. When the provider opened delivery, pick "Ambil sendiri" or "Minta diantar" ("Cara ambil") on the detail. The
   delivery goes to the receiver's primary saved point unless they change it, and must be within 1 km of the food. The
   fee always comes from the listing.
3. Take it ("Ambil") or make an offer. The choice travels with the offer, which says only "diantar": the provider
   sees the address once the reservation exists. The provider accepts.
4. The portions are reserved until the pickup deadline, and the choice is fixed. When food plus delivery fee is above
   Rp0, the receiver picks how to pay ("Pilih cara bayar": cash at handover, or QRIS in the app, post-MVP). Free food
   with free delivery skips this. A voucher only comes off the food.
5. Pickup: the receiver walks to the pickup point ("Lihat rute"). Delivery: the provider brings the food to the
   address ("Lihat rute antar", the same route screen with the delivery address as the destination). Either way the
   provider opens the reservation's QR ("Buka QR ambil").
6. The receiver scans it ("Pindai QR") inside the pickup window. The pickup is marked `picked_up`, the receiver lands on
   the review, and the provider earns points. A scan after the deadline expires the reservation and reopens the
   portions. There is no code to read out.

## Data flow

1. User interacts with the UI
2. App validates input locally (and runs the YOLO check for photos)
3. Request goes to the repository layer. In the MVP this is mock data; later it is Supabase.
4. Backend verifies authentication and authorization (Supabase RLS policies) before reads and writes
5. Response returns to the UI
6. UI handles success, loading (including the "AI sedang memindai..." scan state), empty and error states

## Security notes

- Camera-only capture for listing photos. Never accept gallery or file uploads for listings.
- Authorization is enforced server-side (RLS): providers edit only their own listings, and only conversation members read messages.
- Pickup codes are generated server-side and shown only to the receiver and the provider.
- No off-app payment instructions. The in-app warning banner is required on Pesan.
