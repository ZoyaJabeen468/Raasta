#!/usr/bin/env python3
"""Export a trained YOLO .pt model to TFLite for the Flutter app."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from ultralytics import YOLO

ROOT = Path(__file__).resolve().parents[1]
APP_ASSETS = ROOT.parent / "assets" / "models"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--weights",
        default=str(ROOT / "runs" / "raasta_m2_m5" / "weights" / "best.pt"),
    )
    parser.add_argument("--imgsz", type=int, default=320)
    parser.add_argument(
        "--out-name",
        default="raasta_m2_m5.tflite",
        help="Filename under assets/models/",
    )
    args = parser.parse_args()

    weights = Path(args.weights)
    if not weights.is_file():
        raise SystemExit(f"Missing weights: {weights}")

    model = YOLO(str(weights))
    # imgsz 320 keeps phone inference fast; raise to 640 if accuracy is weak.
    path = model.export(format="tflite", imgsz=args.imgsz, int8=False)
    exported = Path(path)
    APP_ASSETS.mkdir(parents=True, exist_ok=True)
    dest = APP_ASSETS / args.out_name
    shutil.copy2(exported, dest)
    print(f"Copied TFLite → {dest}")
    print("Next step: wire TFLite detector in Flutter (ask the agent).")


if __name__ == "__main__":
    main()
