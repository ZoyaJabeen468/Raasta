#!/usr/bin/env python3
"""Merge multiple YOLO-format datasets into one RAASTA dataset.

Each source folder must look like:
  images/train|val|test  +  labels/train|val|test
  OR flat train/images + train/labels (Roboflow export)

Usage:
  python merge_yolo_datasets.py --sources path1 path2 --out ../datasets/raasta_merged
"""

from __future__ import annotations

import argparse
import random
import shutil
import sys
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from class_map import CLASS_NAMES, CLASS_TO_ID, canonical_name  # noqa: E402


IMG_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}


def find_splits(root: Path) -> dict[str, tuple[Path, Path]]:
    """Return {split: (images_dir, labels_dir)} for a YOLO dataset root."""
    splits: dict[str, tuple[Path, Path]] = {}

    # Layout A: images/train + labels/train
    for split in ("train", "val", "valid", "test"):
        img = root / "images" / split
        lbl = root / "labels" / split
        if img.is_dir() and lbl.is_dir():
            splits["val" if split == "valid" else split] = (img, lbl)

    # Layout B: train/images + train/labels
    for split in ("train", "val", "valid", "test"):
        img = root / split / "images"
        lbl = root / split / "labels"
        if img.is_dir() and lbl.is_dir():
            splits["val" if split == "valid" else split] = (img, lbl)

    # Layout C: train/*.jpg next to labels in parallel folders named train/val
    for split in ("train", "val", "valid", "test"):
        if split in splits:
            continue
        folder = root / ("valid" if split == "val" else split)
        if not folder.is_dir():
            continue
        images = [p for p in folder.iterdir() if p.suffix.lower() in IMG_EXTS]
        if images:
            # labels may be beside images or in labels/
            splits["val" if split == "valid" else split] = (folder, folder)

    return splits


def load_source_names(root: Path) -> dict[int, str]:
    for name in ("data.yaml", "dataset.yaml"):
        yml = root / name
        if yml.is_file():
            data = yaml.safe_load(yml.read_text(encoding="utf-8"))
            names = data.get("names")
            if isinstance(names, dict):
                return {int(k): str(v) for k, v in names.items()}
            if isinstance(names, list):
                return {i: str(n) for i, n in enumerate(names)}
    return {}


def rewrite_label(
    src_label: Path,
    dst_label: Path,
    id_to_name: dict[int, str],
) -> int:
    """Rewrite one YOLO label file. Returns number of kept boxes."""
    if not src_label.is_file():
        return 0

    kept = []
    for line in src_label.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        old_id = int(float(parts[0]))
        raw_name = id_to_name.get(old_id, str(old_id))
        canon = canonical_name(raw_name)
        if canon is None:
            continue
        new_id = CLASS_TO_ID[canon]
        kept.append(f"{new_id} " + " ".join(parts[1:5]))

    if not kept:
        return 0
    dst_label.parent.mkdir(parents=True, exist_ok=True)
    dst_label.write_text("\n".join(kept) + "\n", encoding="utf-8")
    return len(kept)


def merge(sources: list[Path], out: Path, val_ratio: float, seed: int) -> None:
    random.seed(seed)
    if out.exists():
        shutil.rmtree(out)

    for split in ("train", "val"):
        (out / "images" / split).mkdir(parents=True)
        (out / "labels" / split).mkdir(parents=True)

    counters = {n: 0 for n in CLASS_NAMES}
    image_idx = 0

    for src in sources:
        src = src.resolve()
        if not src.is_dir():
            print(f"[skip] not a folder: {src}")
            continue
        print(f"[source] {src}")
        id_to_name = load_source_names(src)
        if not id_to_name:
            print("  ! no data.yaml names — cannot remap; skip")
            continue

        splits = find_splits(src)
        if not splits:
            print("  ! no train/val images found; skip")
            continue

        # If only train exists, carve out a val split.
        pairs: list[tuple[str, Path, Path]] = []
        for split, (img_dir, lbl_dir) in splits.items():
            images = sorted(
                p for p in img_dir.rglob("*") if p.suffix.lower() in IMG_EXTS
            )
            for img in images:
                pairs.append((split, img, lbl_dir / f"{img.stem}.txt"))

        # Rebalance unknown 'test' into train.
        normalized: list[tuple[str, Path, Path]] = []
        only_train = [p for p in pairs if p[0] == "train"]
        has_val = any(p[0] == "val" for p in pairs)

        for split, img, lbl in pairs:
            if split == "test":
                split = "train"
            if split not in ("train", "val"):
                split = "train"
            normalized.append((split, img, lbl))

        if not has_val and only_train:
            random.shuffle(normalized)
            cut = max(1, int(len(normalized) * val_ratio))
            for i, (_, img, lbl) in enumerate(normalized):
                normalized[i] = ("val" if i < cut else "train", img, lbl)

        for split, img, lbl in normalized:
            boxes = rewrite_label(
                lbl,
                out / "labels" / split / f"{image_idx:06d}.txt",
                id_to_name,
            )
            if boxes == 0:
                # drop negative / unmapped images for a cleaner first train
                continue
            dst_img = out / "images" / split / f"{image_idx:06d}{img.suffix.lower()}"
            shutil.copy2(img, dst_img)
            # recount from rewritten file
            for line in (out / "labels" / split / f"{image_idx:06d}.txt").read_text(
                encoding="utf-8"
            ).splitlines():
                cid = int(line.split()[0])
                counters[CLASS_NAMES[cid]] += 1
            image_idx += 1

    data_yaml = {
        "path": str(out.resolve()),
        "train": "images/train",
        "val": "images/val",
        "names": {i: n for i, n in enumerate(CLASS_NAMES)},
    }
    (out / "data.yaml").write_text(
        yaml.safe_dump(data_yaml, sort_keys=False), encoding="utf-8"
    )

    print("\n=== merge done ===")
    print(f"images kept: {image_idx}")
    print("box counts:")
    for name, count in counters.items():
        print(f"  {name:12s} {count}")
    print(f"yaml: {out / 'data.yaml'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sources",
        nargs="+",
        required=True,
        help="YOLO dataset root folders to merge",
    )
    parser.add_argument(
        "--out",
        default=str(SCRIPT_DIR.parent / "datasets" / "raasta_merged"),
    )
    parser.add_argument("--val-ratio", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    merge([Path(s) for s in args.sources], Path(args.out), args.val_ratio, args.seed)


if __name__ == "__main__":
    main()
