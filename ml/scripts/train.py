#!/usr/bin/env python3
"""Train YOLOv8 for RAASTA M2+M5. Prefer Google Colab with a GPU."""

from __future__ import annotations

import argparse
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data",
        default=str(ROOT / "datasets" / "raasta_merged" / "data.yaml"),
        help="Path to data.yaml",
    )
    parser.add_argument(
        "--model",
        default="yolov8n.pt",
        help="Base checkpoint: yolov8n.pt (phone) or yolov8s.pt (accuracy)",
    )
    parser.add_argument("--epochs", type=int, default=80)
    parser.add_argument("--imgsz", type=int, default=640)
    parser.add_argument("--batch", type=int, default=16)
    parser.add_argument("--device", default="0", help="'0' GPU, 'cpu' for CPU")
    parser.add_argument("--name", default="raasta_m2_m5")
    args = parser.parse_args()

    data = Path(args.data)
    if not data.is_file():
        raise SystemExit(f"Missing data yaml: {data}\nMerge datasets first.")

    print(f"Training {args.model} on {data}")
    model = YOLO(args.model)
    model.train(
        data=str(data),
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device,
        project=str(ROOT / "runs"),
        name=args.name,
        exist_ok=True,
        patience=20,
        hsv_h=0.015,
        hsv_s=0.7,
        hsv_v=0.4,
        degrees=5.0,
        translate=0.1,
        scale=0.5,
        fliplr=0.5,
        mosaic=1.0,
        close_mosaic=10,
    )
    best = ROOT / "runs" / args.name / "weights" / "best.pt"
    print(f"\nBest weights: {best}")
    print("Next: python export_tflite.py --weights", best)


if __name__ == "__main__":
    main()
