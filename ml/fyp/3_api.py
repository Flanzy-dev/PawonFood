"""
LANGKAH 3 — API: server yang dihubungi aplikasi Flutter.

Menyediakan 2 alamat:
  GET  /recommend?user_id=u12&n=10   -> daftar item yang direkomendasikan
  POST /event                        -> catat aksi baru (klik/like/beli)

Jalankan:  uvicorn backend.3_api:app --reload --port 8000
Lalu buka: http://127.0.0.1:8000/docs  (bisa dicoba langsung di browser)
"""

import csv
import os
import pickle

import numpy as np
import scipy.sparse as sp
from fastapi import FastAPI
from pydantic import BaseModel

HERE = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(HERE, "data")
MODEL_FILE = os.path.join(DATA_DIR, "model.npz")
MAPS_FILE = os.path.join(DATA_DIR, "maps.pkl")
INTER_FILE = os.path.join(DATA_DIR, "interactions.npz")
EVENTS_FILE = os.path.join(DATA_DIR, "events.csv")

app = FastAPI(title="FYP Marketplace API")

# --- Muat model sekali saat server menyala ---
_model = np.load(MODEL_FILE)
USER_FACTORS = _model["user_factors"]   # vektor selera tiap pengguna
ITEM_FACTORS = _model["item_factors"]   # vektor ciri tiap item

with open(MAPS_FILE, "rb") as f:
    _maps = pickle.load(f)
USER_IDS = _maps["user_ids"]
ITEM_IDS = _maps["item_ids"]
USER_POS = {uid: i for i, uid in enumerate(USER_IDS)}  # id asli -> nomor

INTERACTIONS = sp.load_npz(INTER_FILE).tocsr()


@app.get("/")
def home():
    return {"status": "ok", "pengguna": len(USER_IDS), "item": len(ITEM_IDS)}


@app.get("/recommend")
def recommend(user_id: str, n: int = 10):
    """Kembalikan daftar item yang direkomendasikan untuk satu pengguna."""
    pos = USER_POS.get(user_id)

    if pos is None:
        # Pengguna baru (belum ada riwayat) -> tampilkan item terpopuler.
        populer = np.asarray(INTERACTIONS.sum(axis=0)).ravel()
        top = np.argsort(-populer)[:n]
        return {
            "user_id": user_id,
            "tipe": "populer (pengguna baru)",
            "items": [ITEM_IDS[i] for i in top],
        }

    # Hitung skor cocok = selera pengguna x ciri tiap item.
    skor = ITEM_FACTORS @ USER_FACTORS[pos]

    # Jangan rekomendasikan item yang sudah pernah dilihat/dibeli pengguna.
    sudah = INTERACTIONS[pos].indices
    skor[sudah] = -np.inf

    top = np.argsort(-skor)[:n]
    return {
        "user_id": user_id,
        "tipe": "personal",
        "items": [ITEM_IDS[i] for i in top],
    }


class Event(BaseModel):
    user_id: str
    item_id: str
    event: str  # "view" | "addtocart" | "transaction"


@app.post("/event")
def catat_event(ev: Event):
    """Catat aksi baru pengguna. Dipakai untuk melatih ulang model berkala.

    Di sini aksi hanya ditambahkan ke events.csv. Model dilatih ulang dengan
    menjalankan kembali 2_train.py (misalnya terjadwal tiap malam).
    """
    baris = ["", ev.user_id, ev.event, ev.item_id]  # timestamp dikosongkan
    with open(EVENTS_FILE, "a", newline="", encoding="utf-8") as f:
        csv.writer(f).writerow(baris)
    return {"status": "tercatat", "event": ev.model_dump()}
