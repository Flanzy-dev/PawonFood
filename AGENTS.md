
# Agent Instructions

## Before You Start

- Read PRD.md
- Read DESIGN_SYSTEM.md
- Read ARCHITECTURE.md
- Read Product.md and `Evaluasi Ide Aplikasi PawonFood.md`. Use the cleaned evaluation doc. Ignore the `(raw)` file,
  which has corrupted text.
- Treat `PawonFood UI apps.pdf` (mobile) and `PawonFood UI.pdf` (landing page) as the visual source of truth
- Inspect existing widgets and components before creating new ones

## General Rules

- Mobile app: Flutter / Dart, under `/app`. Landing page: Next.js / TypeScript, under `/web`. ML scripts: Python, under `/ml`.
- Use theme tokens from DESIGN_SYSTEM.md. Never hardcode colors or font sizes in widgets.
- Reuse existing components and keep them modular
- Follow the existing folder structure
- UI copy is **Indonesian**, matching the mockups word for word (e.g. "Bagikan sekarang", "Sisa 2 porsi").
  Code, comments and docs are in English.
- MVP first: build the core journey (upload → YOLO validate → map/feed → negotiate → pickup) with mock data.
  Do not build password reset, profile editing or in-app payments unless asked.
- Food photos come from the camera only. Never add a gallery picker for listings.
- Tier names: Sobat Pawon → Food Savior → Pahlawan Pangan. Never use "Borjuis".
- Ask before making major architectural changes

## Security

- Never expose API keys (Maps, Supabase service role, payment keys)
- Keep secrets in environment variables (`.env`, `--dart-define`), never in the repo
- Validate user input (price ≥ 0, portions ≥ 1, pickup time in the future)
- Verify authorization server-side (Supabase RLS)
- Never add flows that ask users to transfer money outside the app

## Commands

Mobile app (`/app`):

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

Landing page (`/web`):

```bash
npm install
npm run dev
npm run build
npm run lint
```

ML (`/ml`):

```bash
pip install ultralytics
python train.py      # model.train(data='dataset.yaml', epochs=50, imgsz=416)
python export.py     # model.export(format='tflite', int8=True, imgsz=416) → copy to /app/assets
```
