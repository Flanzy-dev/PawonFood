# PawonFood validation server

A small HTTP service that checks a food photo for the share flow (step 1 of 3). It sends the photo to a cloud
**Qwen vision model** (Alibaba Cloud Model Studio, OpenAI-compatible API). Qwen describes what it sees, a strict
schema validates the answer, and a **rules layer** decides whether the listing may go ahead. The app never holds a
model key.

It is Node 24 with no npm dependencies (built-in `node:http`, `fetch` and `node:test`), the same approach as `/render`.

```text
Flutter camera ──JPEG──▶ POST /v1/food-validation
                           ├─ client token (optional) · rate limit · size, type and pixel checks
                           ├─ Qwen VL: visual observation only (JSON)
                           ├─ schema.js: strict parse, drops scores and safety claims
                           └─ rules.js: decision + listing_eligible + reason ──▶ app
```

## Run locally

```bash
cd app/server
cp .env.example .env        # then set QWEN_API_KEY
npm start                   # http://localhost:8787
npm test                    # node:test, no network calls
```

Without a key, `QWEN_PROVIDER=fake npm start` answers every photo as cooked food in good condition. This is for UI
work only, and it is refused when `NODE_ENV=production`.

Point the app at the server:

```bash
cd app
flutter run --dart-define=PAWON_VALIDATOR_URL=http://10.0.2.2:8787         # Android emulator → host machine
flutter run --dart-define=PAWON_VALIDATOR_URL=http://192.168.1.20:8787     # phone on the same Wi-Fi (Android debug)
flutter run --dart-define=PAWON_VALIDATOR_URL=https://your-host.example    # deployed server
```

Without `PAWON_VALIDATOR_URL`, the app keeps the simulated validator and its demo switch. Plain HTTP only works in
Android **debug** builds (`android/app/src/debug/AndroidManifest.xml`). iOS and release builds need HTTPS, so use a
deployed server or an HTTPS tunnel.

## Environment variables

| Variable | Default | Notes |
| --- | --- | --- |
| `QWEN_API_KEY` | (none) | **Required** for `QWEN_PROVIDER=qwen`. Model Studio API key. Only ever read from the environment. |
| `QWEN_BASE_URL` | `https://dashscope-intl.aliyuncs.com/compatible-mode/v1` | Use the endpoint of the region your key belongs to (Beijing: `https://dashscope.aliyuncs.com/compatible-mode/v1`). |
| `QWEN_MODEL` | `qwen3-vl-plus` | Any vision model in your Model Studio account (for example `qwen3-vl-flash` for lower cost). |
| `QWEN_TIMEOUT_MS` | `20000` | Upstream timeout. The app gives up after 25 s. |
| `QWEN_REASONING_EFFORT` | (empty) | Sent as `reasoning_effort` when set. Use `none` for local Ollama models with thinking (see below). |
| `QWEN_PROVIDER` | `qwen` | `fake` for local development without a key. |
| `PORT` / `HOST` | `8787` / `0.0.0.0` | |
| `MAX_UPLOAD_BYTES` | `5242880` (5 MB) | Larger bodies get 413; anything over 4× this cuts the connection. |
| `RATE_LIMIT_PER_MIN` | `10` | Per client IP, in memory. |
| `TRUST_PROXY` | `0` | `1` reads the client IP from `X-Forwarded-For`. Only behind a proxy you control. |
| `PAWON_CLIENT_TOKEN` | (empty) | If set, requests must send `X-Pawon-Client: <token>`. Pass the same value to the app with `--dart-define=PAWON_CLIENT_TOKEN=...`. |

The server refuses to start with a missing key or an invalid value, and says which variable is wrong.

### Getting a Model Studio key

1. Sign in to Alibaba Cloud Model Studio (international site) and activate Model Studio.
2. Create an API key in the console and note which region it belongs to.
3. Put the key in `.env` (git-ignored) or in your host's secret settings. Never put it in the app or in the repo.
4. Check that your `QWEN_MODEL` is listed for your account and region. The official vision guide is at
   <https://help.aliyun.com/en/model-studio/qwen-vl-compatible-with-openai>.

### Local model with Ollama (no account)

Any vision model that Ollama serves works through its OpenAI-compatible API. Tested on 2026-10-14 with `qwen3.5:4b`
(Q4_K_M) on an RTX 3050 Laptop (6 GB):

```bash
ollama pull qwen3.5:4b
ollama show qwen3.5:4b        # "vision" must be listed under Capabilities
```

```env
QWEN_API_KEY=ollama           # any non-empty value; Ollama ignores it
QWEN_BASE_URL=http://localhost:11434/v1
QWEN_MODEL=qwen3.5:4b
QWEN_REASONING_EFFORT=none
QWEN_TIMEOUT_MS=60000
```

`QWEN_REASONING_EFFORT=none` is required. With thinking on, the model spends its whole token budget reasoning and
returns no JSON, which the server reports as `model_bad_response`. (`think: false` has no effect on the
OpenAI-compatible route.) With thinking off, each photo took 2–3 s once the model was loaded.

Results on the app's own photos:

- 8 food photos: all `approved`, with sensible names and categories (cooked dishes `makanan_matang`, raw vegetables
  `bahan_mentah`).
- The app icon: `rejected` as `bukan_makanan`.

None of the test photos showed spoilage, so that path is still untested on a real model. The laptop must stay on
with Ollama running, and the phone must reach the server, during a demo.

## API

`POST /v1/food-validation` with the raw image as the body (`Content-Type: image/jpeg` or `image/png`). It needs no
multipart. The image is held in memory for the request only. It is never written to disk and never logged.

`200` response:

```json
{
  "is_food": true,
  "category": "makanan_matang",
  "food_name": "Ayam goreng",
  "visual_condition": "no_visible_issues",
  "visible_signs": [],
  "image_quality": "good",
  "warnings": [],
  "health_signals": ["protein", "digoreng"],
  "listing_eligible": true,
  "decision": "approved",
  "reason": "Foto lolos validasi"
}
```

| Field | Values |
| --- | --- |
| `category` | `makanan_matang`, `bahan_mentah`, `makanan_kemasan`, `bukan_makanan`, `unknown` (any other model value becomes `unknown`) |
| `visual_condition` | `no_visible_issues`, `minor_concerns`, `visible_spoilage`, `cannot_assess` |
| `image_quality` | `good`, `blurry`, `too_dark`, `obstructed`, `too_far` |
| `decision` | `approved`, `pending_review`, `retake`, `rejected` |
| `visible_signs`, `warnings` | Short Indonesian phrases, at most 8 of 80 characters each. Percentages and "safe to eat" claims are dropped. |
| `health_signals` | Any of `sayur_buah`, `protein`, `digoreng`, `direbus_kukus`: what is visible, not a health rating. Unknown values are dropped, a missing field means none, and non-food always gets `[]`. The app turns them into pre-selected "Pilihan sehat" tags (`direbus_kukus` without `digoreng` → Tidak digoreng; Rendah gula is never suggested) |

The model fills the first eight fields. `listing_eligible`, `decision` and `reason` come only from `src/rules.js`,
checked in this order:

1. Not food (`is_food: false` or `bukan_makanan`) → `rejected`
2. `image_quality` other than `good`, or `cannot_assess` → `retake`
3. `visible_spoilage` (mould, rot, insects) → `rejected`
4. `unknown` category or `minor_concerns` → `pending_review` (eligible; the provider picks or confirms the category)
5. Otherwise → `approved`

Errors are `{"error": {"code", "message"}}` with a generic message. Provider status codes and bodies only go to the log.

| Status | Code | When |
| --- | --- | --- |
| 400 / 413 / 415 / 422 | `upload_invalid` | Empty body, too large, not a JPEG/PNG (checked by magic bytes), or a side under 320 px or over 4096 px |
| 401 | `unauthorized` | `PAWON_CLIENT_TOKEN` is set and the header is missing or wrong |
| 429 | `rate_limited` | With `Retry-After` |
| 502 | `model_unavailable`, `model_bad_response` | Upstream error, or an answer that fails the schema |
| 504 | `model_timeout` | No answer within `QWEN_TIMEOUT_MS` |

The app treats every non-200 answer as "not checked" and offers *Coba lagi*. A failure never approves a photo.

`GET /healthz` → `{"status":"ok"}`.

### `POST /v1/recipe-ideas`

Optional recipe ideas for fresh ingredients ("Minta ide dari AI" in the share form). Text only: no photo is sent.
Send `Content-Type: application/json` with `{"ingredients": "wortel dan kol"}` (2 to 200 characters, at most 2 KB body).
It uses the same `X-Pawon-Client` token and rate limit as the photo check.

```json
{ "recipes": [ { "title": "Sup Wortel Kol", "minutes": 25, "ingredients": ["2 buah wortel"], "steps": ["Didihkan air."] } ] }
```

The answer is validated like the photo check: at most 3 recipes, 12 lines of 160 characters, 1 to 180 minutes. A recipe
with a health or safety claim ("menyembuhkan", "aman dikonsumsi", percentages) is dropped as a whole, so the list can
be empty. Errors: `400` bad body, `413` too large, `415` not JSON, plus the codes in the table above. The fake
provider (`QWEN_PROVIDER=fake`) always answers with one fixed recipe. The app falls back to its local library on any error.

Logs are one JSON line per request: `req_id`, route, status, duration, upload size, pixel size, decision, error code.
The API key and client token are masked in every line.

## Deploy

Any Node 22.9+ host works. The service is stateless apart from the in-memory rate limit.

- **Render / Railway:** new web service from the `Flanzy-dev/PawonFood-docs` repo with root directory `app/server`, start
  command `npm start`. Set `QWEN_API_KEY`, `QWEN_BASE_URL`, `QWEN_MODEL`, `TRUST_PROXY=1` and `NODE_ENV=production` as
  secrets or environment variables. The platform provides HTTPS and `PORT`.
- **Fly.io / a VM:** `node src/main.js` behind HTTPS (Fly's proxy, Caddy or nginx), with the same variables.
- Health check path: `/healthz`.
- Build the app with `--dart-define=PAWON_VALIDATOR_URL=https://<your-host>`.

Run one instance, or move the rate limit to a shared store (Redis, or Supabase once it exists) before scaling out.

## Known limitations

- **Not a food-safety check.** The model only sees the surface in one photo. It cannot judge smell, temperature,
  storage or anything inside the food. The app says so ("Pengecekan foto oleh AI bukan jaminan keamanan pangan"), and
  the provider guarantee stays.
- **Accuracy is unmeasured.** No evaluation set exists yet. Collect real Pogung photos and measure before relying on
  the rejections.
- **Camera-only is enforced by the app, not the server.** The server cannot prove a photo came from the live camera.
- **No user auth yet.** `PAWON_CLIENT_TOKEN` ships inside the app, so it only stops casual traffic. Verify Supabase
  JWTs here once Supabase exists.
- **Rate limit per IP, in memory.** It resets on restart, is per instance, and users behind one NAT share it.
- **Cost and latency.** Every photo is a paid model call that usually takes a few seconds; budget the key accordingly.
- **YOLO is still the plan for on-device checks** (ARCHITECTURE.md). This service can sit next to it as the
  server-side re-check.
