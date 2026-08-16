# Raasta — Final Dataset Plan (Module 2 + Module 5)

**Owner:** Zoya  
**Goal:** One YOLOv8 model for day **and** night driving alerts  
**Principle:** Prefer large academic / research datasets. Use Roboflow only as a small filler for gaps (especially speed bumps). Cap total training images so Colab can finish.

---

## 1. Important decisions (read first)

### 1.1 Do NOT download “everything in GBs” blindly

| Reality | What it means for Raasta |
|---------|---------------------------|
| Free Colab disk is limited (~70–100 GB) | Full Open Images (~561 GB) will **not** fit |
| Bigger ≠ better | Wrong-domain images hurt phone demos |
| Speed-bump data is scarce worldwide | No clean multi‑GB bump-only set exists |
| Phone app needs real-time | Train **YOLOv8n**, not a huge slow model |

**Rule:** Use **large sources selectively** (filter classes / countries / night tags). Aim for a merged set of roughly **25k–60k images**, not 500 GB raw.

### 1.2 Class taxonomy (final for FYP)

Keep **one class per alert type**. Do **not** split person into man/woman/child — the alert is the same, and labels for age/gender are rare and noisy.

| ID | Class name | Covers (merged labels) | Module |
|----|------------|------------------------|--------|
| 0 | `pothole` | pot hole, D40, open hole | M2 |
| 1 | `crack` | longitudinal / transverse / alligator / D00,D10,D20 | M2 |
| 2 | `speed_bump` | marked, unmarked, hump, breaker, broken/worn bump | M2 |
| 3 | `person` | man, woman, boy, girl, child, elderly, pedestrian, people | M5 |
| 4 | `cow` | cattle, cow | M5 |
| 5 | `buffalo` | water buffalo, buffalo | M5 |
| 6 | `dog` | dog | M5 |
| 7 | `cat` | cat | M5 |
| 8 | `horse` | horse | M5 |
| 9 | `donkey` | donkey, ass, mule*(map mule→donkey if few labels)* | M5 |
| 10 | `goat` | goat | M5 |

**11 classes total** (was 8). Update `ml/configs/raasta.yaml` + Flutter `HazardType` when training starts.

If a rare class has &lt;300 boxes after merge, either collect local images or merge it into a temporary `animal_other` — prefer collecting locals for viva.

---

## 2. Module 2 — Road damage & bumps (recommended stack)

### Tier A — Must use (large / research-grade)

| Dataset | Approx size | What you get | Why |
|---------|-------------|--------------|-----|
| **RDD2022** (CRDDC) | Full zip multi‑GB; **India ~0.5 GB**, Japan ~1 GB, Norway alone **~9.9 GB** | Cracks + potholes (VOC XML → convert to YOLO) | Best public road-damage set; **India subset is priority for Pakistan-like roads** |
| **SBP-YOLO set** | ~7.5k images (Drive / Baidu) | Speed bumps + potholes | Stronger bump+pothole mix than tiny Roboflow-only sets |
| **Kaggle `road_anomaly_ds`** | ~6.4k, YOLO-ready | Pothole, Speedbump, Crack | Easy merge; already unified labels |

**RDD2022 download (official mirrors):**  
https://github.com/sekilab/RoadDamageDetector  

Priority downloads for you:
1. `RDD2022_India.zip` (~502 MB) — **required**  
2. `RDD2022_Japan.zip` (~1 GB) — recommended  
3. `RDD2022_United_States.zip` (~424 MB) — optional  
4. Skip full Norway (~10 GB) unless you have Drive space and time — diminishing returns for Pakistan demo  

**Label map for RDD2022 → Raasta:**
- `D00`, `D10`, `D20` → `crack`  
- `D40` → `pothole`  
- Ignore other damage codes if rare  

**SBP-YOLO:** https://github.com/chuanqi1997/SBP-YOLO (Google Drive dataset link in README)

### Tier B — Speed bumps (all variants) — combine many small sets

There is **no** perfect multi‑GB “all bump types” dataset. Build coverage by stacking:

| Source | Focus |
|--------|--------|
| Mendeley — Marked Speed Bump India | Marked South-Asian breakers |
| Mendeley — Speed Hump/Bump | Extra humps |
| Roboflow Speed Bump v15 | Extra marked bumps (filler only) |
| Roboflow / Kaggle unmarked bump sets | Unmarked / faded bumps |
| **Your own phone video** (mandatory) | Broken, worn, Pakistani-style, night bumps |

### Tier C — Optional extras

| Source | Notes |
|--------|--------|
| SciDB pothole/cracks | Convert labels if needed |
| GitHub Cracks-and-Potholes | Extra crack/pothole frames |
| Kaggle pothole-cracks-manhole | Map manhole carefully (optional; can confuse model) |

### M2 day + night strategy

| Method | Action |
|--------|--------|
| Public day data | RDD2022 + SBP + Kaggle anomaly (mostly daytime) |
| Augmentation | YOLO built-in: brightness, HSV, mosaic, flip — helps twilight |
| Real night | **Record 15–30 min night drives** (Rawalpindi/Islamabad), sample frames, label bumps/potholes/cracks |
| Do not | Train a separate night-only model for FYP |

---

## 3. Module 5 — Humans & animals (recommended stack)

### Tier A — Must use (large)

| Dataset | Approx size | Classes for Raasta | Day/night |
|---------|-------------|--------------------|-----------|
| **BDD100K** detection images | Images pack **~5–7 GB** | `person` (also has cars — **filter to person only**) | Explicit **day / night / dawn-dusk** tags — **best night person source** |
| **COCO 2017** (person + animals subset) | Full COCO large; you only keep needed classes | person, dog, cat, horse, cow *(sheep/goat limited)* | Mostly day; huge diversity of people |
| **Open Images V7 — filtered download only** | Full set **~561 GB — DO NOT download all** | Filter: Person, Cat, Dog, Horse, Cattle, Donkey*(if present)* | Mixed; use FiftyOne / OI download tools with **class filter + max_samples** |

**BDD100K:** register/download from https://bdd-data.berkeley.edu / docs at https://doc.bdd100k.com/download.html  
Keep only images with `person` boxes; stratify so **≥30–40% night** in your person subset.

**Open Images — practical way:**
- Use FiftyOne / official class-filtered download  
- Cap e.g. **2k–5k images per animal class**  
- Prefer outdoor / road-like scenes if you can filter by metadata

### Tier B — Night / low-light boost

| Dataset | Size | Use |
|---------|------|-----|
| **ExDark** | ~1.5 GB, 7k images | Low-light `People`, `Cat`, `Dog` → map to `person`, `cat`, `dog` |
| Official: https://github.com/cs-chan/Exclusively-Dark-Image-Dataset | | |

### Tier C — Livestock / Pakistan-relevant animals

| Need | Source idea |
|------|-------------|
| cow / buffalo / goat / donkey | Open Images filtered + livestock/farm YOLO sets (Zenodo/Kaggle) + **local labeling** |
| buffalo / donkey often rare | Plan **local capture** on outskirts roads — biggest viva win |

### M5 class policy for “every kind of human”

Train **one** `person` class on:
- BDD100K persons (day+night)  
- COCO persons  
- ExDark people  

That already covers men, women, children, elderly visually. Separate classes are **not** worth it for alerts.

---

## 4. Suggested merged corpus size (realistic FYP)

| Class | Target images / instances (order of magnitude) | Priority |
|-------|-----------------------------------------------|----------|
| pothole | 4k–10k | High |
| crack | 6k–15k (RDD helps a lot) | High |
| speed_bump | 2k–5k (hardest; quality & local &gt; quantity) | Critical |
| person | 8k–20k with **≥25% night** | High |
| dog / cat | 1.5k–4k each (+ ExDark) | Medium |
| cow / horse | 1.5k–4k each | Medium |
| goat / buffalo / donkey | 500–2k each (boost with local) | Medium–Hard |

**Total merged training images:** aim **30k–50k** after dedup/split.  
**Val/Test:** 10–15% held out; keep a **night-only val slice** for reporting.

---

## 5. How to train (after datasets are ready)

### Pipeline

```text
1. Download Tier A sources to Google Drive (not only laptop)
2. Convert VOC/COCO/BDD JSON → YOLO txt
3. Remap all labels → 11 Raasta class IDs
4. Merge folders → train/val split (stratified)
5. Balance: undersample huge classes (crack/person), oversample bumps/donkey/buffalo
6. Train YOLOv8n, imgsz=320 or 640, 80–100 epochs, Colab T4
7. Report mAP50 overall + per-class + night-val subset
8. Export TFLite → assets/models/raasta_m2_m5.tflite
```

### Day/night training tricks (use all)

1. **Data:** BDD night persons + ExDark + your night road clips  
2. **Augmentation:** lower brightness / gamma in Ultralytics HSV aug  
3. **App side later:** enable torch / night exposure (not a second model)  
4. **Eval:** separate table “Day mAP” vs “Night mAP” in FYP report  

### What not to do

- Don’t train from scratch (always fine-tune `yolov8n.pt`)  
- Don’t use full Open Images / full Norway RDD unless you have paid storage + days  
- Don’t keep separate classes for “marked bump” vs “unmarked bump” unless you have balanced data — **one `speed_bump` class**, diversify images instead  
- Don’t rely on Roboflow as the backbone — only filler  

---

## 6. Download priority checklist (do in this order)

### Week dataset work — Zoya

- [ ] **1.** RDD2022 India (+ Japan) → convert → `pothole`/`crack`  
- [ ] **2.** SBP-YOLO Drive set → `speed_bump`/`pothole`  
- [ ] **3.** Kaggle `road_anomaly_ds` → merge  
- [ ] **4.** Mendeley marked bump (India) + unmarked sets → `speed_bump`  
- [ ] **5.** BDD100K images + det labels → filter `person`, keep night tags  
- [ ] **6.** COCO subset: person, dog, cat, horse, cow  
- [ ] **7.** Open Images **filtered** caps for cow/horse/dog/cat/donkey  
- [ ] **8.** ExDark → person/cat/dog night  
- [ ] **9.** Local Pakistan day+night clips (bumps, animals, people) — label in Roboflow/CVAT  
- [ ] **10.** Merge → balance → first Colab train  

Roboflow = step filler / labeling tool for **your** videos, not the main data source.

---

## 7. Storage plan

| Place | Use |
|-------|-----|
| Google Drive (student account) | Raw zips + merged YOLO folder |
| Colab | Train from Drive mount |
| Laptop | Only small samples + final `.pt` / `.tflite` |
| GitHub | **Never** commit multi‑GB datasets (gitignore `ml/datasets/`) |

---

## 8. Honest scope note for committee

> Speed bumps and Pakistani stray livestock (buffalo/donkey) are under-represented in public data. We combine RDD2022 / BDD100K / COCO / Open Images (filtered) / ExDark with locally collected night and day footage, and train a single multi-class YOLOv8n model evaluated on both day and night validation splits.

---

## 9. Next action after you approve this list

1. Confirm the **11-class** table (or trim buffalo/donkey if you want fewer classes).  
2. Start downloads **1→4** (M2) while Drive space is free.  
3. Then we update `class_map.py` + Colab notebook to use this stack (not Roboflow-only).

**Document version:** 1.0 — 2026-08-11  
