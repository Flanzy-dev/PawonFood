# FYP recommender ("Pilihan untukmu")

A trained recommender for the Beranda feed, received ready to use (`reference/fyp_siap_pakai/`). `3_api.py`, `data/` and
`requirements.txt` are kept as delivered. The teammate's guide in Indonesian is `reference/fyp_siap_pakai/CARA_PAKAI_TEMAN.md`.

- `data/model.npz`: ALS model, 500 users × 200 items, 50 factors.
- `data/maps.pkl`: the user ids (`u0`..`u499`) and item ids (`i0`..`i199`). Plain lists, checked with `pickletools`
  (no code in it).
- `data/interactions.npz`: who already interacted with what (sparse matrix), so the personal list skips those items.

## Run

```bash
cd ml/fyp
py -m venv .venv
.venv/Scripts/python -m pip install -r requirements-serve.txt   # fastapi, uvicorn, numpy, scipy
.venv/Scripts/python -m uvicorn 3_api:app --host 0.0.0.0 --port 8000
```

`requirements-serve.txt` leaves out `implicit`: it is only needed to train, and it has no wheel for Python 3.14.
In VS Code: run the tasks "AI: FYP setup" (once), then "AI: FYP server".

- `GET /` gives `{"status":"ok","pengguna":500,"item":200}`.
- `GET /recommend?user_id=u0&n=200` gives the items best first (`"tipe":"personal"`). An unknown user gets the most
  popular items.
- `POST /event` with `{"user_id":"u0","item_id":"i1","event":"view"}` appends a row to `data/events.csv`
  (git-ignored). `event` is `view`, `addtocart` or `transaction`.

## How the app uses it

Start the app with `--dart-define=PAWON_FYP_URL=http://10.0.2.2:8000` (emulator), or for a USB phone run
`adb reverse tcp:8000 tcp:8000` and use `http://127.0.0.1:8000`. Without the define, the feed ranks by distance and
urgency only and nothing is sent.

- **Ranking:** `score = affinity × proximity × urgency` (PRD). Affinity runs from 1 for the best-ranked item down to 0.2.
  It is 0.6 for listings the model does not know, for example food published in the app.
- **Events:** the food detail open for 3 s sends `view`, "Ambil" or an offer sends `addtocart`, and a successful QR
  scan sends `transaction`.

## Demo id mapping (important)

The model was trained on another dataset, so its ids are not PawonFood's. For the demo:

- The demo account uses model user `u0` (`fypDemoUser` in `app/lib/core/services/fyp.dart`).
- Each mock listing carries `fypItem` in `app/assets/mock/listings.json`. They are, in file order, the first 11 items
  `u0` had not interacted with: `i1, i100, i101, i102, i104, i105, i106, i107, i108, i109, i110`.

So the order really comes from the model, but its taste is not about food yet. The events the app sends do not change
the order until the model is retrained. That needs the teammate's `1_download_data.py` and `2_train.py`, which are not
in the package, and training data that uses PawonFood listing and user ids.
