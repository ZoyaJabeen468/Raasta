# RAASTA — short fine-tune (improve pothole generalization)

**Goal:** Improve detection on clear / demo-style pothole photos **without going outside**.  
**Start from:** `MyDrive/raasta/weights/m2_m5_v1/weights/best.pt`  
**Time:** ~45–90 min on Colab T4 (25 epochs)

## Before you run
1. Runtime → **GPU (T4)**  
2. Have Drive space (~2–3 GB free)  
3. Optional: Roboflow API key (free) — used to download an extra public pothole set

---

### Cell 1 — Setup
```python
from google.colab import drive
drive.mount("/content/drive")

!pip -q uninstall -y pillow pillow-simd 2>/dev/null
!pip -q install -U "pillow==11.2.1" "ultralytics>=8.3.0" roboflow pyyaml

import os, shutil, random, yaml
from pathlib import Path
from collections import defaultdict
import torch
from ultralytics import YOLO

assert torch.cuda.is_available(), "Runtime → Change runtime type → T4 GPU"
print("GPU:", torch.cuda.get_device_name(0))

DRIVE = Path("/content/drive/MyDrive/raasta")
BEST = DRIVE / "weights/m2_m5_v1/weights/best.pt"
MERGED = DRIVE / "merged"
assert BEST.exists(), f"Missing {BEST}"
assert (MERGED / "data.yaml").exists(), f"Missing {MERGED}/data.yaml"
print("best.pt OK, merged OK")
```

### Cell 2 — Class map (must match your 11 classes)
```python
CLASS_NAMES = [
    "pothole", "crack", "speed_bump",
    "person", "cow", "buffalo", "dog", "cat", "horse", "donkey", "goat",
]
# New public pothole datasets → always class 0
```

### Cell 3 — Download public pothole images (Roboflow)
Paste your key, or skip this cell and use Cell 3b.
```python
ROBOFLOW_API_KEY = ""  # <-- paste key

from roboflow import Roboflow
rf = Roboflow(api_key=ROBOFLOW_API_KEY.strip())

FT = Path("/content/finetune_raw")
shutil.rmtree(FT, ignore_errors=True)
FT.mkdir(parents=True)

# Public single-class pothole set (good for clear hole photos)
ds = (
    rf.workspace("atksharmanew")
    .project("pothole-detection-yolov8")
    .version(1)
    .download("yolov8", location=str(FT / "rf_pothole"))
)
print("Downloaded to", ds.location)
```

If that project 404s, try:
```python
ds = (
    rf.workspace("brad-dwyer")
    .project("pothole-voxrl")
    .version(1)
    .download("yolov8", location=str(FT / "rf_pothole"))
)
```

### Cell 3b — Fallback without Roboflow (GitHub pothole images + empty labels skip)
Only use if Roboflow fails; weaker but still helps a little.
```python
FT = Path("/content/finetune_raw/gh")
(FT / "images/train").mkdir(parents=True, exist_ok=True)
(FT / "labels/train").mkdir(parents=True, exist_ok=True)
!wget -q -O {FT}/images/train/gh1.jpg "https://raw.githubusercontent.com/jhasuman/potholes-detection/master/images/1.jpg"
# Rough full-frame box as weak label (class 0). Better than nothing for FYP fine-tune.
(FT / "labels/train/gh1.txt").write_text("0 0.5 0.55 0.7 0.45\n")
print("Fallback sample ready")
```

### Cell 4 — Build fine-tune dataset (new potholes + sample of your merged data)
```python
OUT = Path("/content/finetune_mix")
shutil.rmtree(OUT, ignore_errors=True)
for split in ("train", "val"):
    (OUT / "images" / split).mkdir(parents=True)
    (OUT / "labels" / split).mkdir(parents=True)

def copy_pair(img: Path, lbl: Path, split: str, prefix: str):
    if not img.exists() or not lbl.exists():
        return False
    if lbl.stat().st_size < 1:
        return False
    stem = f"{prefix}_{img.stem}"
    shutil.copy2(img, OUT / "images" / split / f"{stem}{img.suffix.lower()}")
    # force all class ids in THIS public set to 0 (pothole) if single-class source
    lines = []
    for line in lbl.read_text().strip().splitlines():
        parts = line.split()
        if len(parts) >= 5:
            parts[0] = "0"  # pothole
            lines.append(" ".join(parts))
    if not lines:
        return False
    (OUT / "labels" / split / f"{stem}.txt").write_text("\n".join(lines) + "\n")
    return True

# A) public pothole set
rf_root = Path("/content/finetune_raw/rf_pothole")
n_new = 0
if rf_root.exists():
    for split_src, split_dst, limit in [("train", "train", 800), ("valid", "val", 150), ("val", "val", 150)]:
        img_dir = rf_root / split_src / "images"
        if not img_dir.exists():
            img_dir = rf_root / "images" / split_src
        lbl_dir = rf_root / split_src / "labels"
        if not lbl_dir.exists():
            lbl_dir = rf_root / "labels" / split_src
        if not img_dir.exists():
            continue
        imgs = [p for p in img_dir.glob("*") if p.suffix.lower() in {".jpg", ".jpeg", ".png"}]
        random.shuffle(imgs)
        for img in imgs[:limit]:
            lbl = lbl_dir / f"{img.stem}.txt"
            if copy_pair(img, lbl, split_dst, "new"):
                n_new += 1
print("New pothole images added:", n_new)

# B) keep original multi-class skill — sample from your merged set
n_old = 0
for split, limit in [("train", 2500), ("val", 400)]:
    img_dir = MERGED / "images" / split
    lbl_dir = MERGED / "labels" / split
    imgs = [p for p in img_dir.glob("*") if p.suffix.lower() in {".jpg", ".jpeg", ".png"}]
    random.shuffle(imgs)
    for img in imgs[:limit]:
        lbl = lbl_dir / f"{img.stem}.txt"
        if not lbl.exists():
            continue
        stem = f"old_{img.stem}"
        shutil.copy2(img, OUT / "images" / split / f"{stem}{img.suffix.lower()}")
        shutil.copy2(lbl, OUT / "labels" / split / f"{stem}.txt")
        n_old += 1
print("Old merged images kept:", n_old)

yaml_path = OUT / "data.yaml"
yaml_path.write_text(yaml.safe_dump({
    "path": str(OUT),
    "train": "images/train",
    "val": "images/val",
    "names": {i: n for i, n in enumerate(CLASS_NAMES)},
}, sort_keys=False))
print("data.yaml →", yaml_path)
print("train imgs:", len(list((OUT/'images'/'train').glob('*'))))
print("val imgs:", len(list((OUT/'images'/'val').glob('*'))))
```

### Cell 5 — Fine-tune from best.pt (short)
```python
import gc
gc.collect()
torch.cuda.empty_cache()

RUN = DRIVE / "weights/m2_m5_ft1"
RUN.mkdir(parents=True, exist_ok=True)

model = YOLO(str(BEST))  # continue from your trained weights
model.train(
    data=str(OUT / "data.yaml"),
    epochs=25,
    imgsz=640,
    batch=8,          # drop to 4 if OOM
    workers=2,
    device=0,
    project=str(RUN),
    name="finetune",
    exist_ok=True,
    pretrained=True,
    lr0=0.0008,       # lower LR = fine-tune, not from scratch
    lrf=0.01,
    patience=10,
    cache=False,
    amp=True,
    plots=False,
    save_period=5,
    mosaic=0.3,
    close_mosaic=8,
    fliplr=0.5,
    degrees=8.0,
    translate=0.1,
    scale=0.5,
)

FT_BEST = RUN / "finetune" / "weights" / "best.pt"
print("Fine-tuned best:", FT_BEST)
```

### Cell 6 — Quick check + export TFLite
```python
from ultralytics import YOLO

FT_BEST = DRIVE / "weights/m2_m5_ft1/finetune/weights/best.pt"
model = YOLO(str(FT_BEST))

# sanity on the public-style samples folder if present
!mkdir -p /content/pothole_tests
!wget -q -O /content/pothole_tests/pot_github.jpg "https://raw.githubusercontent.com/jhasuman/potholes-detection/master/images/1.jpg"
model.predict(source="/content/pothole_tests", imgsz=640, conf=0.20, save=True)

export_path = model.export(format="tflite", imgsz=640)
print("TFLite:", export_path)

out = DRIVE / "exports"
out.mkdir(parents=True, exist_ok=True)
import shutil
shutil.copy2(FT_BEST, out / "raasta_m2_m5_ft.pt")
shutil.copy2(export_path, out / "raasta_m2_m5_ft.tflite")
print("Copied to Drive exports/")
```

### After success
1. Download `raasta_m2_m5_ft.tflite` from Drive `raasta/exports/`  
2. Replace  
   `E:\Android\projects\raasta_app\assets\models\raasta_m2_m5.tflite`  
3. Full restart the app  
4. Tell me: **fine-tune done**

---

**Notes**
- Do **not** start from `yolov8n.pt` — always from `best.pt`  
- If GPU disconnects: rerun Cell 5 with  
  `YOLO(".../finetune/weights/last.pt").train(resume=True)`  
- If Roboflow project 404s, tell me the error text — we’ll swap the dataset name
