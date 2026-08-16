# RAASTA

AI-powered real-time road hazard awareness for drivers in Pakistan.

Flutter app + on-device YOLOv8 (TFLite) for road damage, pedestrians, and animals, with GPS speed HUD, voice alerts (English/Urdu), and local trip insights.

## Team

| Member | Focus |
|--------|--------|
| **Zoya** | M2+M5 detection model, M6 wrong-way, M7 insights |
| **Amna** | M3 traffic signs + OCR, M4 sign-based speed limits |

See [`docs/FYP_WORK_PLAN.md`](docs/FYP_WORK_PLAN.md) for the full split.

## What's in this repo

| Path | Contents |
|------|----------|
| `lib/` | Flutter app (auth, drive, dashboard, reports, settings) |
| `assets/models/` | On-device TFLite model |
| `ml/` | Training scripts, Colab notebooks, class map |
| `docs/` | FYP work plan and dataset notes |
| `FIREBASE_SETUP.md` | Firebase / Google / Facebook setup |

## Run the app

```powershell
git clone https://github.com/ZoyaJabeen468/Raasta.git
cd Raasta
flutter pub get
flutter run
```

Phone: enable **Developer options → USB debugging**, plug in USB, accept the prompt, then `flutter devices` / `flutter run`.

## ML training

Use **Google Colab (T4 GPU)** — see:

- `ml/README.md`
- `ml/colab/RAASTA_YOLOv8_M2_M5.ipynb`
- `ml/colab/RAASTA_FINETUNE_HOME.md`

Do **not** commit Roboflow API keys or large training datasets. Weights/datasets live on Google Drive.

## Security notes

- Firebase **client** config lives in `lib/firebase_options.dart` (normal for Flutter). Restrict that API key in Google Cloud (Android package + SHA-1).
- Never commit: Roboflow keys, Facebook app secrets, `google-services.json`, keystores (`.jks`), or `.env` files.
- Collaborators: use feature branches + pull requests for larger changes.

## Branch workflow (team)

```powershell
git pull origin main
git checkout -b yourname/feature-name
# ... make changes ...
git add -A
git commit -m "Short description of why"
git push -u origin yourname/feature-name
```

Then open a **Pull Request** on GitHub into `main`.
