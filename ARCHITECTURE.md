# Architecture

## System Overview

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
- AI: YOLOv8 Nano exported to TFLite, running **on-device** via `flutter_vision`. No server cost.
- Payments (post-MVP): Midtrans / Xendit. The MVP is cash on pickup.
- Web hosting: Vercel (Next.js).

## AI Food Validator

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

## Project Structure

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

## Data Model

| Entity                 | Key fields                                                                                                                                                                            |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                   | id, name, roles (receiver / provider), tier (`sobat_pawon` / `food_savior` / `pahlawan_pangan`), points, saved pickup point, location                                           |
| Listing                | id, provider_id, photo_url, name, category, portions_left, original_price, price, is_free, negotiable, pickup_by, pickup_point, lat/lng, ai_status, ai_confidence, status, created_at |
| Offer                  | id, listing_id, receiver_id, amount, portions, status (`pending` / `accepted` / `rejected`)                                                                                     |
| Conversation / Message | conversation per (listing, receiver); messages with sender, body, type (`text` / `offer` / `system`), created_at                                                                |
| Pickup                 | id, offer_id, code (`PWN-XXXX`), status (`waiting` / `picked_up` / `cancelled`), picked_up_at                                                                                 |
| Review                 | pickup_id, rating, comment                                                                                                                                                            |
| PointLedger            | user_id, delta, reason (pickup, free-food bonus, redemption)                                                                                                                          |
| Reward                 | id, name (voucher minimarket, diskon ojek, sertifikat), cost                                                                                                                          |

Listing status: `available → reserved → picked_up`, or `expired` once past `pickup_by`, or `habis` when no portions are left.

## Key Flows

**Share (provider).** Target: 3 taps or fewer.

1. Tap the Bagikan FAB. The camera opens; gallery upload is disabled.
2. The live YOLO preview shows the detected class. The provider takes the photo and the validation rule runs.
3. The form is pre-filled (category, portions, price, pickup time, pickup point). The provider confirms and publishes.
4. The listing appears in the feed and on the map.

#### Claim (receiver)

1. Open a listing from the feed or map.
2. Make an offer or start a chat. The provider accepts.
3. The system message shows the pickup code `PWN-XXXX`.
4. The receiver walks to the pickup point, shows the code and pays cash.
5. The receiver taps "Sudah saya ambil". The pickup is marked `picked_up`, the receiver leaves a review, and the
   provider earns points.

## Data Flow

1. User interacts with the UI
2. App validates input locally (and runs the YOLO check for photos)
3. Request goes to the repository layer. In the MVP this is mock data; later it is Supabase.
4. Backend verifies authentication and authorization (Supabase RLS policies) before reads and writes
5. Response returns to the UI
6. UI handles success, loading (including the "AI sedang memindai..." scan state), empty and error states

## Security Notes

- Camera-only capture for listing photos. Never accept gallery or file uploads for listings.
- Authorization is enforced server-side (RLS): providers edit only their own listings, and only conversation members read messages.
- Pickup codes are generated server-side and shown only to the receiver and the provider.
- No off-app payment instructions. The in-app warning banner is required on Pesan.
