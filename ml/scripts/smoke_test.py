#!/usr/bin/env python3
"""Tiny smoke test: load YOLOv8n and run one prediction (downloads weights)."""

from ultralytics import YOLO


def main() -> None:
    model = YOLO("yolov8n.pt")
    # Built-in demo image (downloaded automatically).
    results = model.predict(source="https://ultralytics.com/images/bus.jpg", imgsz=320)
    boxes = results[0].boxes
    print(f"OK — detections: {0 if boxes is None else len(boxes)}")
    print("Ultralytics is working. Prefer Colab GPU for real training.")


if __name__ == "__main__":
    main()
