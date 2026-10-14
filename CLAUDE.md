# CLAUDE.md

PawonFood is a hyperlocal surplus-food sharing app ("Dari dapur ke dapur") built for a UGM sustainability hackathon, starting in Pogung, Sleman. The Flutter mobile app lives in `/app` (all 75 Figma hi-fi screens, mock data, simulated QR/payment/ads). `/web` and `/ml` do not exist yet.

@AGENTS.md

## Repo State

- Spec docs at the root: [PRD.md](PRD.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [AGENTS.md](AGENTS.md). Read them before building anything.
- [reference/](reference/) holds source material. AGENTS.md mentions `Product.md`, the evaluation doc and the UI PDFs without a path. They all live in `reference/`.
  - Use `Evaluasi Ide Aplikasi PawonFood.md` (cleaned). Ignore the `(raw)` file, which has corrupted text.
  - `PawonFood UI apps.pdf` (mobile) and `PawonFood UI.pdf` (landing page) are the visual source of truth.
- `/app` (Flutter/Dart) exists: see [app/README.md](app/README.md) for how to run it, the demo account, and the assumptions made for the PRD open questions. Flutter is at `~/flutter/bin` and is not on PATH, so run `export PATH="$HOME/flutter/bin:$PATH"` first. `flutter create` fails inside this OneDrive folder; scaffold elsewhere and copy.
- Motion lives in `app/lib/core/motion/` (rules in DESIGN_SYSTEM.md → Motion). Use those widgets and tokens instead of ad-hoc durations, and keep every animation off under `Motion.reduced`.
- Don't run `dart format` on existing files: this SDK's formatter uses the tall style and rewrites code written in the older 160-column style.
- The AI photo check in the app is **simulated** (`FoodValidator` interface). The real YOLO/TFLite model comes from `/ml`.
- `/render` is a headless render engine with no npm dependencies: canvas scenes → headless Chrome over CDP → ffmpeg MP4. It makes the 20 s 9:16 pitch-video ad with a code-synthesized soundtrack, every cut on a 120 BPM grid (`npm run render:ad`, then `npm run review:ad` to check dead frames and beat lock; VO script and CapCut guide in [render/AD.md](render/AD.md)) and the 8 s feature promo in landscape and portrait (`npm run render`, `npm run render:portrait`, `npm run preview`). It reads fonts and photos from `app/assets`, and the ad's Figma-AI watercolours from `render/web/media/`. All motion uses closed-form springs (`render/web/spring.js`); easing curves are banned there. See [render/README.md](render/README.md). Local only, like the other root folders.
- Not yet created: `/web` (Next.js/TypeScript), `/ml` (Python, YOLOv8 → TFLite).
- `.fallow/` is a generated cache from the fallow analyzer. Don't edit it.
- Git: only `/app` is a repository (GitHub `Flanzy-dev/PawonFood`, app contents at the repo root). The root folder, its docs, `reference/` and `.claude/` are local only and must not be pushed. The old root history is kept locally in `.git-old-backup/`.

## Design Work

- Figma lo-fi wireframes (page "Lo-fi v2") were generated programmatically through a Figma plugin bridge, and the PawonFood logo concepts the same way. The scripts and exports from those sessions are not in this repo.
- The same page also holds the 18 hi-fi screens (below the lo-fi rows) and the app flow map "Alur aplikasi PawonFood". The Figma file is on the Starter plan (3 pages max), which is why they share a page.
- Keep UI copy in Indonesian and match the mockups word for word. Code, comments and docs stay in English.
