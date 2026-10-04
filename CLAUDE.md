# CLAUDE.md

PawonFood is a hyperlocal surplus-food sharing app ("Dari dapur ke dapur") built for a UGM sustainability hackathon, starting in Pogung, Sleman. The Flutter mobile app MVP lives in `/app` (all 18 screens, mock data). `/web` and `/ml` do not exist yet.

@AGENTS.md

## Repo State

- Spec docs at the root: [PRD.md](PRD.md), [ARCHITECTURE.md](ARCHITECTURE.md), [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md), [AGENTS.md](AGENTS.md). Read them before building anything.
- [reference/](reference/) holds source material. AGENTS.md mentions `Product.md`, the evaluation doc and the UI PDFs without a path. They all live in `reference/`.
  - Use `Evaluasi Ide Aplikasi PawonFood.md` (cleaned). Ignore the `(raw)` file, which has corrupted text.
  - `PawonFood UI apps.pdf` (mobile) and `PawonFood UI.pdf` (landing page) are the visual source of truth.
- `/app` (Flutter/Dart) exists: see [app/README.md](app/README.md) for how to run it, the demo account, and the assumptions made for the PRD open questions. Flutter is at `~/flutter/bin` and is not on PATH, so run `export PATH="$HOME/flutter/bin:$PATH"` first. `flutter create` fails inside this OneDrive folder; scaffold elsewhere and copy.
- The AI photo check in the app is **simulated** (`FoodValidator` interface). The real YOLO/TFLite model comes from `/ml`.
- Not yet created: `/web` (Next.js/TypeScript), `/ml` (Python, YOLOv8 → TFLite).
- `.fallow/` is a generated cache from the fallow analyzer. Don't edit it.
- This directory is not a git repository.

## Design Work

- Figma lo-fi wireframes (page "Lo-fi v2") were generated programmatically through a Figma plugin bridge, and the PawonFood logo concepts the same way. The scripts and exports from those sessions are not in this repo.
- The same page also holds the 18 hi-fi screens (below the lo-fi rows) and the app flow map "Alur aplikasi PawonFood". The Figma file is on the Starter plan (3 pages max), which is why they share a page.
- Keep UI copy in Indonesian and match the mockups word for word. Code, comments and docs stay in English.
