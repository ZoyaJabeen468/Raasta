# RAASTA — Full data pipeline (download → merge → train)

**For:** Zoya · **Goal:** Best model with **public datasets only** (no your own photos)  
**Where everything runs:** [Google Colab](https://colab.research.google.com) + **Google Drive** (`MyDrive/raasta/`)

---

## Big picture (4 phases)

```text
PHASE 1  Download raw zips / Roboflow  →  Drive: raw/ + extracted/
PHASE 2  Convert labels to 11 classes  →  still in extracted/
PHASE 3  Merge into one YOLO folder    →  Drive: merged/
PHASE 4  Train / fine-tune + export    →  Drive: weights/ + exports/
                                      →  PC: assets/models/raasta_m2_m5.tflite
```

**You never need multi‑GB datasets on your laptop.** Only the final `.tflite` (~12 MB).

---

## Accounts (free, 10 minutes)

| Account | Why |
|---------|-----|
| [Google](https://accounts.google.com) | Colab + Drive |
| [Roboflow](https://roboflow.com) | Many road + animal sets (API key) |
| [Kaggle](https://www.kaggle.com) (optional) | `road_anomaly_ds`, some pothole sets |

---

## Drive folder layout (use this every time)

```text
MyDrive/raasta/
  raw/         ← zip files (delete after extract to save space)
  extracted/   ← unzipped sources (delete after merge if low on space)
  merged/      ← KEEP — images/train, labels/train, images/val, data.yaml
  weights/     ← KEEP — best.pt from training
  exports/     ← KEEP — .tflite for phone
```

**Free space tip:** After merge works, delete `raw/` and `extracted/` (you already did this — good).

---

## Your 11 classes (do not change)

`pothole`, `crack`, `speed_bump`, `person`, `cow`, `buffalo`, `dog`, `cat`, `horse`, `donkey`, `goat`

Child / man / woman / elderly → all train as **`person`**.

---

## PHASE 1 — Where to download (priority order)

Run **one dataset at a time** in Colab. Notebook: **`ml/colab/RAASTA_DOWNLOAD_DATASETS.ipynb`**

### Road damage (M2) — download these

| # | Dataset | Where | Size | Classes |
|---|---------|-------|------|---------|
| 1 | **RDD2022 India** | [RoadDamageDetector](https://github.com/sekilab/RoadDamageDetector) — link in download notebook | ~0.5 GB | pothole, crack |
| 2 | **RDD2022 Japan** | Same GitHub | ~1 GB | pothole, crack |
| 3 | **RDD2022 USA** (optional) | Same GitHub | ~0.4 GB | pothole, crack |
| 4 | **Kaggle road_anomaly_ds** | [kaggle.com/datasets](https://www.kaggle.com/datasets) — search `road_anomaly_ds` | small | pothole, crack, speed_bump |
| 5 | **SBP-YOLO** | [GitHub SBP-YOLO](https://github.com/chuanqi1997/SBP-YOLO) — Google Drive link in README | ~medium | speed_bump, pothole |

**Skip for FYP:** RDD Norway (~10 GB) unless you have 20+ GB free on Drive.

### People + night (M5) — download these

| # | Dataset | Where | Size | Classes |
|---|---------|-------|------|---------|
| 6 | **BDD100K** (detection) | [bdd-data.berkeley.edu](https://bdd-data.berkeley.edu) | ~5–7 GB images | **person** (keep **night** tag) |
| 7 | **ExDark** | [GitHub ExDark](https://github.com/cs-chan/Exclusively-Dark-Image-Dataset) | ~1.5 GB | person, dog, cat (night) |
| 8 | **COCO 2017** | [cocodataset.org](https://cocodataset.org) — train images + labels | large (filter classes) | person, cow, dog, cat, horse |

### Animals + bumps (Roboflow — easiest in Colab)

Get API key: Roboflow → Account → API Key.

Use notebook **`RAASTA_FINETUNE_PERSON_ANIMALS.ipynb`** cell 3, or search Universe:

| Search on Roboflow | Class |
|--------------------|-------|
| speed bump detection | speed_bump |
| road degradation / pothole | pothole, crack |
| cows, dogs, cats, horses | animals |
| goat detection, buffalo detection, donkey detection | goat, buffalo, donkey |
| pedestrian / coco person | person |

---

## PHASE 2 & 3 — Fetch, remap, merge

### Option A — You already have `merged/` (fastest)

If `MyDrive/raasta/merged/data.yaml` exists from earlier training:

1. Skip re-downloading everything  
2. Run **`RAASTA_FINETUNE_PERSON_ANIMALS.ipynb`** — it adds Roboflow data + samples your old `merged/`  
3. Fine-tune from `weights/.../best.pt`

### Option B — Full merge from scratch (max data)

1. **`RAASTA_DOWNLOAD_DATASETS.ipynb`** — RDD India, Japan, (+ USA) into `extracted/`  
2. **`RAASTA_YOLOv8_M2_M5.ipynb`** — Roboflow road + COCO subset → builds `merged/` in Colab `/content` then copy to Drive  
   - Or run merge cells that write directly to `MyDrive/raasta/merged/`  
3. **`RAASTA_FINETUNE_PERSON_ANIMALS.ipynb`** — add more person/animal Roboflow sets on top  

### Label remapping rules (RDD → Raasta)

| RDD code | Your class |
|----------|------------|
| D00, D10, D20 | crack |
| D40 | pothole |

All remapping logic: `ml/scripts/class_map.py`

### Merge size targets (realistic “max” without breaking Colab)

| Class | Target images (order of magnitude) |
|-------|-------------------------------------|
| crack | 8k–15k |
| pothole | 4k–10k |
| speed_bump | 2k–5k |
| person | 10k–20k (**≥30% night** from BDD + ExDark) |
| dog, cat | 2k–4k each |
| cow, horse | 2k–4k each |
| goat, buffalo, donkey | 500–2k each |

**Total merged train:** aim **35k–55k images** after dedup. More than ~60k often slows Colab without much gain.

---

## PHASE 4 — Train (best quality path)

### Pass 1 — Base train (if starting fresh)

**Notebook:** `ml/colab/RAASTA_YOLOv8_M2_M5.ipynb`

- Runtime: **T4 GPU**
- Start: `yolov8n.pt`
- Epochs: **80–100**
- imgsz: **640**
- batch: **8** (or 4 if OOM)
- Output: `MyDrive/raasta/weights/m2_m5_v1/weights/best.pt`

### Pass 2 — Person + animals boost (you did this)

**Notebook:** `ml/colab/RAASTA_FINETUNE_PERSON_ANIMALS.ipynb`

- Start: Pass 1 `best.pt`
- Epochs: **50**
- lr0: **0.0006** (low = fine-tune)
- Output: `m2_m5_people_animals_v1/.../best.pt`  
- mAP50 you got: **~0.63** ✓

### Pass 3 — Night boost (recommended next)

**Same fine-tune notebook**, add downloads:

- BDD100K persons with **night** filter  
- **ExDark** (People, Dog, Cat)  
- Keep **2000+** samples from old `merged/` (road skill)  
- Train **30 epochs** from Pass 2 `best.pt`  
- Report **day mAP** vs **night mAP** in FYP

### Export to phone

**Notebook:** fine-tune cell 6

```text
MyDrive/raasta/exports/raasta_m2_m5_people_animals.tflite
```

Copy to PC:

```text
E:\Android\projects\raasta_app\assets\models\raasta_m2_m5.tflite
```

---

## Step-by-step checklist (do in order)

### Week 1 — Downloads (CPU Colab OK)

- [ ] Mount Drive, create folders (`RAASTA_DOWNLOAD_DATASETS.ipynb` setup)
- [ ] RDD2022 **India** → `extracted/RDD2022_India`
- [ ] RDD2022 **Japan** → `extracted/RDD2022_Japan`
- [ ] (Optional) RDD **USA**
- [ ] Roboflow key saved
- [ ] ExDark zip → `extracted/ExDark` (for night)
- [ ] (If space) BDD100K 100k images pack — or use Roboflow night pedestrian as lighter substitute

### Week 2 — Merge + train

- [ ] Build `merged/` with 11 classes + `data.yaml`
- [ ] Check box counts per class (person high, donkey not zero)
- [ ] Pass 1 or Pass 2 fine-tune on **T4 GPU**
- [ ] Note **mAP50** + per-class scores
- [ ] Export TFLite → test on phone

### Week 3 — Night pass + report

- [ ] Pass 3 night fine-tune
- [ ] Table: day vs night detection examples
- [ ] Screenshot failures for report (`docs/eval/`)

---

## Which notebook when?

| You want to… | Open this file in Colab |
|--------------|-------------------------|
| Download RDD zips to Drive | `RAASTA_DOWNLOAD_DATASETS.ipynb` |
| First full train (Roboflow + COCO) | `RAASTA_YOLOv8_M2_M5.ipynb` |
| Boost person/animals (you did this) | `RAASTA_FINETUNE_PERSON_ANIMALS.ipynb` |
| Night + more data (next) | Same fine-tune notebook + BDD/ExDark cells |
| Written steps for person/animals | `RAASTA_FINETUNE_PERSON_ANIMALS.md` |
| Dataset theory / sizes | `docs/DATASET_PLAN_M2_M5.md` |

---

## Honest limits (write in report)

- Public data is mostly **daytime** for potholes/cracks  
- **Buffalo / donkey** are rare — Roboflow helps but not perfect  
- **Night road damage** needs augmentation + ExDark/BDD for people, not potholes  
- Phone demo ≠ paper accuracy — report both mAP and real road tests  

---

## If Drive is full again

Delete (safe after merge):

1. `raw/*.zip`  
2. `extracted/*` (keep `merged/` + `weights/` + `exports/`)  
3. Empty Google Drive trash  

---

## Next action for you today

1. Open Colab → upload **`RAASTA_DOWNLOAD_DATASETS.ipynb`**  
2. Run **Setup** + **RDD India** (if not already on Drive)  
3. Open **`RAASTA_FINETUNE_PERSON_ANIMALS.ipynb`** on **T4 GPU**  
4. Add **ExDark** + extra Roboflow night/pedestrian downloads in cell 3  
5. Run merge + **30 epoch** fine-tune from your current `best.pt`  
6. Replace TFLite in app  

When a download fails (404), paste the error — we swap the dataset name.
