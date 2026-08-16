# RAASTA ML — YOLO training (Module 2 + Module 5)

Train **one** YOLOv8 model that detects:

| ID | Class | Module |
|----|--------|--------|
| 0 | `pothole` | M2 |
| 1 | `crack` | M2 |
| 2 | `speed_bump` | M2 |
| 3 | `person` | M5 |
| 4 | `cow` | M5 |
| 5 | `dog` | M5 |
| 6 | `goat` | M5 |
| 7 | `horse` | M5 |

## Important (read this)

Your PC has **no NVIDIA GPU**. Training a real model here would take **days** and accuracy would be poor.

**Do all training in Google Colab (free T4 GPU)** using the notebook in `colab/`.
Then copy the exported `.tflite` into `assets/models/` for the Flutter app.

Realistic FYP target: **mAP50 ≈ 0.55–0.75** on a mixed 8-class model.
Papers quoting “96%” are usually single-task / different metrics — don’t chase that number.

---

## Fastest path (beginner)

### 1. Accounts (free, 10 minutes)

1. [Google account](https://accounts.google.com) → open Colab  
2. [Roboflow](https://roboflow.com) → create account → **Account → Roboflow API** → copy key  
3. (Optional) [Kaggle](https://www.kaggle.com) → Settings → API → download `kaggle.json`

### 2. Open the notebook

1. Go to [Google Colab](https://colab.research.google.com)  
2. **File → Upload notebook** → choose  
   `ml/colab/RAASTA_YOLOv8_M2_M5.ipynb`  
3. **Runtime → Change runtime type → T4 GPU**  
4. Paste your Roboflow API key in the first setup cell  
5. **Runtime → Run all**

Training on T4 for ~50–80 epochs of YOLOv8n usually takes **1–3 hours**.

### 3. Download results

From Colab, download:

- `raasta_m2_m5.pt` (PyTorch weights — keep for retraining)  
- `raasta_m2_m5.tflite` (phone model)

Put the TFLite file here:

```text
assets/models/raasta_m2_m5.tflite
```

(We wire this into Flutter in the next step after training finishes.)

---

## Datasets used (curated for RAASTA)

### Road damage + bumps (your list + picks)

| Priority | Dataset | Use for |
|----------|---------|---------|
| 1 | [Roboflow Speed Bump v15](https://universe.roboflow.com/speed-bump-detection/speed-bump-detection-se0eh/dataset/15) | `speed_bump` |
| 2 | [Roboflow Road Degradation](https://universe.roboflow.com/nsip-project/road-degradation-beta) | `pothole`, `crack`, `speed_bump` |
| 3 | [Kaggle pothole/cracks/manhole](https://www.kaggle.com/datasets/sabidrahman/pothole-cracks-and-openmanhole) | `pothole`, `crack` |
| 4 | [Cracks-and-Potholes GitHub](https://github.com/biankatpas/Cracks-and-Potholes-in-Road-Images-Dataset) | extra `pothole`/`crack` |
| 5 | [Marked Speed Bump India (Mendeley)](https://data.mendeley.com/datasets/bvpt9xdjz8/1) | South-Asian bumps |
| 6 | SciDB RDD | optional extra potholes/cracks |

### Pedestrians + animals (M5) — added for you

| Priority | Dataset | Use for |
|----------|---------|---------|
| 1 | COCO 2017 (filtered) | `person`, `cow`, `dog`, `horse` |
| 2 | [Open Images — Goat](https://storage.googleapis.com/openimages/web/index.html) / Roboflow goat sets | `goat` |
| 3 | [Roboflow animals / livestock](https://universe.roboflow.com/) search “cow dog goat horse” | boost M5 |

The Colab notebook downloads the **Roboflow + COCO** pieces automatically. Kaggle/Mendeley/GitHub are optional extras if you want more accuracy later.

---

## Local scripts (optional)

Only needed if you merge datasets on your PC later:

```powershell
cd E:\Android\projects\raasta_app\ml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

| Script | Purpose |
|--------|---------|
| `scripts/merge_yolo_datasets.py` | Merge many YOLO folders → one dataset with unified class IDs |
| `scripts/train.py` | Local train (CPU — slow; prefer Colab) |
| `scripts/export_tflite.py` | Export `.pt` → `.tflite` |
| `scripts/smoke_test.py` | Quick sanity check that ultralytics runs |

---

## Accuracy tips (do these)

1. Prefer **YOLOv8n** for the phone (fast). Use **YOLOv8s** only if n is too weak in demos.  
2. Train **at least 50 epochs**; stop early if `mAP50` plateaus.  
3. Keep images of **road ahead from dash / phone** — close-up pavement-only photos help less for driving.  
4. After public training, add **50–200 clips from Islamabad/Rawalpindi** — biggest accuracy jump for your viva.  
5. One model, eight classes — do **not** train seven separate models.

---

## After training — Flutter (next chat)

1. Drop `raasta_m2_m5.tflite` into `assets/models/`  
2. We replace `SimulatedHazardDetector` with a real TFLite detector  
3. Lower-half ROI + class-specific TTS (already planned)

---

## Honest expectation

| Goal | Realistic? |
|------|------------|
| Demo potholes / bumps / people on phone video | Yes |
| Perfect night + every goat breed | No (scope limitation) |
| Beat a paper’s 96% headline | Wrong comparison — ignore |

When Colab finishes, tell me the **mAP50** from the last epoch and share/download the `.tflite` — we’ll plug it into the app next.
