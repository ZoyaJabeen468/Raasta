# RAASTA — Fine-tune for people + animals (beginner guide)

**Goal:** Make `person` and animal classes (cow, buffalo, dog, cat, horse, donkey, goat) much more reliable, while keeping road damage (pothole / crack / speed_bump).

**Critical rule (do not skip):**  
Keep the **same 11 classes**. Do **not** create separate classes for child / man / woman / old.

| What you want in real life | How we train YOLO | Why |
|----------------------------|-------------------|-----|
| Child, man, woman, elderly on road | All labeled **`person`** (class 3) | Phone app only has `person`. More varied photos make one class smarter. |
| Cow breeds, calves, etc. | Still **`cow`** | Same idea — diversity inside the class. |
| Donkey vs horse | Keep separate classes 8 / 9 | Add **more donkey** images so horse stops “stealing” them. |

**Time:** ~2–4 hours on Colab **T4 GPU** (50 epochs).  
**Start from:** your existing `best.pt` (or current fine-tuned weights) — never from scratch.

---

## Before you start (checklist)

1. Laptop browser + Google account  
2. [Google Colab](https://colab.research.google.com)  
3. Google Drive with ~5 GB free (`MyDrive/raasta/…` already used before)  
4. Free [Roboflow](https://roboflow.com) account → copy **API key**  
5. Know where your weights live, usually:  
   `MyDrive/raasta/weights/m2_m5_v1/weights/best.pt`  
   **or** after last fine-tune:  
   `MyDrive/raasta/weights/m2_m5_ft1/finetune/weights/best.pt`

If you are not sure which `.pt` is newest, use the one with the **higher mAP50** from training plots / `results.csv`.

---

## Step 0 — Open Colab correctly

1. Go to [colab.research.google.com](https://colab.research.google.com)  
2. **File → New notebook**  
3. **Runtime → Change runtime type → T4 GPU → Save**  
4. Confirm GPU:

```python
import torch
print(torch.cuda.is_available(), torch.cuda.get_device_name(0) if torch.cuda.is_available() else "NO GPU")
```

You must see `True` and a GPU name. If not, change runtime again.

---

## Step 1 — Setup + Drive

Paste **one cell**, run it.

```python
from google.colab import drive
drive.mount("/content/drive")

!pip -q uninstall -y pillow pillow-simd 2>/dev/null
!pip -q install -U "pillow==11.2.1" "ultralytics>=8.3.0" roboflow pyyaml

import os, shutil, random, yaml, gc
from pathlib import Path
from collections import Counter, defaultdict
import torch
from ultralytics import YOLO

assert torch.cuda.is_available(), "Runtime → Change runtime type → T4 GPU"
print("GPU:", torch.cuda.get_device_name(0))

DRIVE = Path("/content/drive/MyDrive/raasta")
MERGED = DRIVE / "merged"

# Prefer latest fine-tune if it exists; else original best
CANDIDATES = [
    DRIVE / "weights/m2_m5_ft1/finetune/weights/best.pt",
    DRIVE / "weights/m2_m5_v1/weights/best.pt",
]
BEST = next((p for p in CANDIDATES if p.exists()), None)
assert BEST is not None, f"No best.pt found under {DRIVE}/weights — upload your weights first"
assert (MERGED / "data.yaml").exists(), f"Missing {MERGED}/data.yaml — need your previous merged dataset"
print("Starting weights:", BEST)
print("Merged data:", MERGED)
```

---

## Step 2 — Fixed 11-class map (must match the Flutter app)

```python
CLASS_NAMES = [
    "pothole", "crack", "speed_bump",
    "person", "cow", "buffalo", "dog", "cat", "horse", "donkey", "goat",
]
CLASS_TO_ID = {n: i for i, n in enumerate(CLASS_NAMES)}
print(CLASS_TO_ID)
```

**Aliases** (child / man / woman → person):

```python
ALIASES = {
    # person family → class person
    "person": "person", "pedestrian": "person", "people": "person",
    "human": "person", "man": "person", "woman": "person",
    "child": "person", "boy": "person", "girl": "person",
    "kid": "person", "elderly": "person", "old": "person",
    "adult": "person", "walker": "person",
    # animals
    "cow": "cow", "cattle": "cow", "ox": "cow", "bull": "cow",
    "buffalo": "buffalo", "water buffalo": "buffalo",
    "dog": "dog", "puppy": "dog",
    "cat": "cat", "kitten": "cat",
    "horse": "horse",
    "donkey": "donkey", "ass": "donkey", "mule": "donkey",
    "goat": "goat",
    # road (keep skill)
    "pothole": "pothole", "crack": "crack", "speed_bump": "speed_bump",
    "speed bump": "speed_bump", "speedbreaker": "speed_bump", "bump": "speed_bump",
}

def canon(name: str):
    k = name.strip().lower().replace("_", " ").replace("-", " ")
    return ALIASES.get(k)
```

---

## Step 3 — Download extra datasets (Roboflow)

Paste your Roboflow API key. Run.  
If one project 404s, comment that block and continue — you still get the others.

```python
ROBOFLOW_API_KEY = ""  # <-- PASTE KEY HERE
assert ROBOFLOW_API_KEY.strip(), "Paste Roboflow API key"

from roboflow import Roboflow
rf = Roboflow(api_key=ROBOFLOW_API_KEY.strip())

RAW = Path("/content/ft_raw")
shutil.rmtree(RAW, ignore_errors=True)
RAW.mkdir(parents=True)

def rf_download(workspace, project, version, folder):
    out = RAW / folder
    print(f"Downloading {workspace}/{project} v{version} …")
    ds = rf.workspace(workspace).project(project).version(version).download(
        "yolov8", location=str(out)
    )
    print(" →", ds.location)
    return Path(ds.location)

downloads = []

# --- PEOPLE (map everything to person later) ---
# Large pedestrian / person sets (public Universe projects).
# If a name 404s, skip that line and tell me the error — we'll swap.
try:
    downloads.append(("person", rf_download("roboflow-100", "people-in-paintings", 1, "rf_people_a")))
except Exception as e:
    print("skip people-a:", e)

try:
    downloads.append(("person", rf_download("public-datasets", "coco-person", 1, "rf_coco_person")))
except Exception as e:
    print("skip coco-person:", e)
    try:
        downloads.append(("person", rf_download("microsoft", "coco", 1, "rf_coco")))
    except Exception as e2:
        print("skip coco:", e2)

# --- ANIMALS (boost weak classes: donkey, goat, buffalo especially) ---
animal_jobs = [
    ("cow", "joseph-nelson", "cows", 1, "rf_cows"),
    ("dog", "joseph-nelson", "dogs", 1, "rf_dogs"),
    ("cat", "joseph-nelson", "cats", 1, "rf_cats"),
    ("horse", "joseph-nelson", "horses", 1, "rf_horses"),
    ("goat", "augmented-startups", "goats-clyzb", 1, "rf_goats"),
    ("donkey", "search", "donkey-detection", 1, "rf_donkey"),
    ("buffalo", "search", "buffalo-detection", 1, "rf_buffalo"),
]

for canon_name, ws, proj, ver, folder in animal_jobs:
    try:
        downloads.append((canon_name, rf_download(ws, proj, ver, folder)))
    except Exception as e:
        print(f"skip {canon_name} ({ws}/{proj}):", e)

print("Downloaded sets:", len(downloads))
for c, p in downloads:
    print(" ", c, "→", p)
```

**Beginner tip:** Roboflow Universe search is your friend. In the website, search:

- `pedestrian yolo` / `person detection`  
- `donkey detection`  
- `buffalo detection`  
- `goat detection`  

Open a dataset → **Download → YOLO v8** → copy workspace / project / version into `rf_download(...)` above.

---

## Step 4 — Build a balanced fine-tune mix

We:

1. Keep a **large sample** of your old merged data (so potholes don’t get forgotten)  
2. Add **extra person + animal** images with remapped class IDs  
3. Cap per class so one class doesn’t dominate

```python
OUT = Path("/content/ft_person_animals")
shutil.rmtree(OUT, ignore_errors=True)
for split in ("train", "val"):
    (OUT / "images" / split).mkdir(parents=True)
    (OUT / "labels" / split).mkdir(parents=True)

rng = random.Random(42)

def yolo_pairs(root: Path):
    """Find (image, label) pairs under common Roboflow layouts."""
    pairs = []
    candidates = [
        (root / "train" / "images", root / "train" / "labels"),
        (root / "valid" / "images", root / "valid" / "labels"),
        (root / "val" / "images", root / "val" / "labels"),
        (root / "images" / "train", root / "labels" / "train"),
        (root / "images" / "val", root / "labels" / "val"),
        (root / "images" / "valid", root / "labels" / "valid"),
    ]
    # also flat
    if (root / "images").exists() and (root / "labels").exists():
        candidates.append((root / "images", root / "labels"))
    for img_dir, lbl_dir in candidates:
        if not img_dir.exists() or not lbl_dir.exists():
            continue
        for img in img_dir.rglob("*"):
            if img.suffix.lower() not in {".jpg", ".jpeg", ".png", ".bmp", ".webp"}:
                continue
            lbl = lbl_dir / f"{img.stem}.txt"
            if not lbl.exists():
                # try same relative under labels
                try:
                    rel = img.relative_to(img_dir)
                    lbl = lbl_dir / rel.with_suffix(".txt")
                except Exception:
                    pass
            if lbl.exists() and lbl.stat().st_size > 0:
                pairs.append((img, lbl))
    return pairs

def remap_label_file(src_lbl: Path, name_by_id: dict[int, str] | None, force_class: str | None):
    """Rewrite YOLO lines to our CLASS_TO_ID. force_class overrides all boxes."""
    lines_out = []
    for line in src_lbl.read_text(encoding="utf-8", errors="ignore").strip().splitlines():
        parts = line.split()
        if len(parts) < 5:
            continue
        if force_class is not None:
            cid = CLASS_TO_ID[force_class]
        else:
            old_id = int(float(parts[0]))
            raw = name_by_id.get(old_id, str(old_id)) if name_by_id else str(old_id)
            cname = canon(raw)
            if cname is None:
                continue
            cid = CLASS_TO_ID[cname]
        parts[0] = str(cid)
        lines_out.append(" ".join(parts))
    return lines_out

def read_names(yaml_path: Path):
    if not yaml_path.exists():
        return None
    data = yaml.safe_load(yaml_path.read_text())
    names = data.get("names")
    if isinstance(names, dict):
        return {int(k): str(v) for k, v in names.items()}
    if isinstance(names, list):
        return {i: str(n) for i, n in enumerate(names)}
    return None

copied = Counter()
n_files = {"train": 0, "val": 0}

def add_pair(img: Path, lbl_lines: list[str], split: str, prefix: str):
    if not lbl_lines:
        return
    stem = f"{prefix}_{img.stem}_{n_files[split]}"
    shutil.copy2(img, OUT / "images" / split / f"{stem}{img.suffix.lower()}")
    (OUT / "labels" / split / f"{stem}.txt").write_text("\n".join(lbl_lines) + "\n")
    n_files[split] += 1
    for line in lbl_lines:
        copied[CLASS_NAMES[int(line.split()[0])]] += 1

# A) Keep old multi-class skill (important!)
for split, limit in [("train", 4000), ("val", 600)]:
    img_dir = MERGED / "images" / split
    lbl_dir = MERGED / "labels" / split
    imgs = [p for p in img_dir.glob("*") if p.suffix.lower() in {".jpg", ".jpeg", ".png"}]
    rng.shuffle(imgs)
    for img in imgs[:limit]:
        lbl = lbl_dir / f"{img.stem}.txt"
        if not lbl.exists():
            continue
        lines = lbl.read_text(encoding="utf-8", errors="ignore").strip().splitlines()
        clean = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 5 and int(float(parts[0])) < len(CLASS_NAMES):
                clean.append(" ".join(parts))
        add_pair(img, clean, split, "old")

print("After old merged sample:", dict(copied), "files", n_files)

# B) Add new downloads (force class when the whole set is one category)
PER_SET_LIMIT = {
    "train": 900,
    "val": 120,
}

for force_or_auto, root in downloads:
    names = read_names(root / "data.yaml")
    pairs = yolo_pairs(root)
    rng.shuffle(pairs)
    # 85% train / 15% val
    cut = int(len(pairs) * 0.85)
    buckets = {"train": pairs[:cut], "val": pairs[cut:]}
    for split, items in buckets.items():
        for img, lbl in items[: PER_SET_LIMIT[split]]:
            # If Roboflow set is single-purpose, force that class
            force = force_or_auto if force_or_auto in CLASS_TO_ID else None
            lines = remap_label_file(lbl, names, force)
            add_pair(img, lines, split, force_or_auto or "mix")

print("Final box counts:", dict(copied))
print("Files:", n_files)

yaml_path = OUT / "data.yaml"
yaml_path.write_text(yaml.safe_dump({
    "path": str(OUT),
    "train": "images/train",
    "val": "images/val",
    "names": {i: n for i, n in enumerate(CLASS_NAMES)},
}, sort_keys=False))
print("Wrote", yaml_path)
```

**Healthy target counts (approximate):**

- `person`: high (thousands of boxes if possible)  
- each animal: at least a few hundred boxes; **donkey / buffalo / goat** especially need a boost  
- keep pothole / crack / speed_bump from the “old” sample  

If `donkey` is still near 0, search Roboflow for another donkey set and add another `rf_download` line, then re-run Step 4.

---

## Step 5 — Train (fine-tune)

```python
gc.collect()
torch.cuda.empty_cache()

RUN = DRIVE / "weights/m2_m5_people_animals_v1"
RUN.mkdir(parents=True, exist_ok=True)

model = YOLO(str(BEST))
model.train(
    data=str(OUT / "data.yaml"),
    epochs=50,
    imgsz=640,
    batch=8,          # if CUDA out of memory → 4
    workers=2,
    device=0,
    project=str(RUN),
    name="finetune",
    exist_ok=True,
    pretrained=True,
    lr0=0.0006,       # low LR = fine-tune
    lrf=0.01,
    patience=15,
    cache=False,
    amp=True,
    plots=True,
    save_period=5,
    mosaic=0.4,
    close_mosaic=10,
    fliplr=0.5,
    degrees=10.0,
    translate=0.1,
    scale=0.5,
    hsv_h=0.015,
    hsv_s=0.7,
    hsv_v=0.4,
)

FT_BEST = RUN / "finetune" / "weights" / "best.pt"
print("Fine-tuned best:", FT_BEST)
```

### If Colab disconnects mid-train

```python
from ultralytics import YOLO
last = DRIVE / "weights/m2_m5_people_animals_v1/finetune/weights/last.pt"
YOLO(str(last)).train(resume=True)
```

### What to write down for your FYP report

After training finishes, open the run folder plots / print metrics:

```python
from ultralytics import YOLO
m = YOLO(str(DRIVE / "weights/m2_m5_people_animals_v1/finetune/weights/best.pt"))
metrics = m.val(data=str(OUT / "data.yaml"))
print("mAP50:", metrics.box.map50)
print("mAP50-95:", metrics.box.map)
# per-class
print(metrics.box.maps)  # if available
```

Realistic targets after this fine-tune:

| Metric | Hope for |
|--------|----------|
| Overall mAP50 | ~0.55–0.75 |
| person | clear gain |
| donkey / goat | better than before (still may lag cow/dog) |

---

## Step 6 — Export TFLite for the phone

```python
from ultralytics import YOLO
import shutil

FT_BEST = DRIVE / "weights/m2_m5_people_animals_v1/finetune/weights/best.pt"
model = YOLO(str(FT_BEST))

# quick visual sanity (optional)
!mkdir -p /content/demo_tests
model.predict(source="/content/demo_tests", imgsz=640, conf=0.25, save=True)

export_path = model.export(format="tflite", imgsz=640)
print("TFLite:", export_path)

out = DRIVE / "exports"
out.mkdir(parents=True, exist_ok=True)
shutil.copy2(FT_BEST, out / "raasta_m2_m5_people_animals.pt")
shutil.copy2(export_path, out / "raasta_m2_m5_people_animals.tflite")
print("Copied to", out)
```

---

## Step 7 — Put the model in the Flutter app

On your Windows PC:

1. Download from Drive:  
   `MyDrive/raasta/exports/raasta_m2_m5_people_animals.tflite`
2. Rename / replace:  
   `E:\Android\projects\raasta_app\assets\models\raasta_m2_m5.tflite`
3. Full restart the app (uninstall optional):

```powershell
cd E:\Android\projects\raasta_app
flutter run -d 3420472029000H0 --device-timeout 60
```

**Do not change** Flutter `numClasses = 11` or class IDs — this fine-tune keeps them identical.

---

## Step 8 — How to test fairly

1. Prefer **phone** Drive mode, not only laptop screen photos  
2. One subject at a time first (one person crossing, one goat, etc.)  
3. Watch debug line in console: `YOLO peak=… (label)`  
4. Animals still need higher confidence in the app (we already raised animal threshold)

---

## What NOT to do

- Do **not** add classes `child`, `man`, `woman` unless you are ready to change Flutter + retrain from scratch  
- Do **not** train on CPU on this laptop  
- Do **not** start from `yolov8n.pt` for this pass — continue from `best.pt`  
- Do **not** drop all old pothole data — the model will forget road damage  

---

## Your “do this now” order

1. Open Colab → T4 GPU  
2. Run Steps 1–2  
3. Paste Roboflow key → Step 3 (fix 404s by swapping Universe datasets)  
4. Step 4 — check box counts, especially `person` and `donkey`  
5. Step 5 — wait for training  
6. Step 6 — export  
7. Step 7 — replace TFLite in the app  
8. Tell me: **mAP50**, and which classes still fail in phone demos  

I will then help you with a second short fine-tune only on the weak classes if needed.
