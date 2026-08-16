# Datasets checklist — RAASTA M2 + M5

Use the Colab notebook first. Add these manually only if you want more accuracy.

## Must-have (wired in Colab)

| Class | Source | Link |
|-------|--------|------|
| speed_bump | Roboflow Universe v15 | https://universe.roboflow.com/speed-bump-detection/speed-bump-detection-se0eh/dataset/15 |
| pothole / crack / bump | Road Degradation Beta | https://universe.roboflow.com/nsip-project/road-degradation-beta |
| unmarked bump / pothole | speed-unmarked-bumb | https://universe.roboflow.com/pothole-detection-1nczj/speed-unmarked-bumb |
| person / animals | Open Images + Roboflow M5 sets | downloaded in notebook |

## Your list (optional extras)

| Source | Link | Notes |
|--------|------|-------|
| SciDB pothole/cracks | https://www.scidb.cn/en/detail?dataSetId=e9ffbca43e6e4a5ebdd25663d0de9ad1 | Convert labels to YOLO if not YOLO |
| Kaggle pothole/cracks/manhole | https://www.kaggle.com/datasets/sabidrahman/pothole-cracks-and-openmanhole | Needs `kaggle.json` |
| GitHub cracks+potholes | https://github.com/biankatpas/Cracks-and-Potholes-in-Road-Images-Dataset | May need label conversion |
| Marked speed bump (India) | https://data.mendeley.com/datasets/bvpt9xdjz8/1 | Great for Pakistan-like roads |
| SpeedHump Mendeley | https://data.mendeley.com/datasets/xt5bjdhy5g/1 | Extra bumps |
| Kaggle speed bump | https://www.kaggle.com/datasets/ziya07/speed-bump-dataset | Small; optional |

## After public data — biggest accuracy win

Film 10–20 minutes of Islamabad/Rawalpindi roads with your phone mount.
Label ~150–300 frames in Roboflow (free tier) for pothole/crack/speed_bump/person/animals.
Fine-tune your `best.pt` for 20 more epochs.

That local fine-tune usually beats adding another random Kaggle zip.
