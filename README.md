# RAASTA

AI-powered real-time road hazard detection for Pakistani roads.

**Project path:** `E:\Android\projects\raasta_app`  
(C: was almost full — project + build caches live on E:)

## Current status

- App: Module 1 + GPS drive HUD (see `lib/`)
- ML: YOLO training for M2+M5 lives in `ml/` — **use Google Colab** (no local NVIDIA GPU)

```text
ml/README.md                      ← start here
ml/colab/RAASTA_YOLOv8_M2_M5.ipynb
```

## Run on phone (no Android Studio)

1. Phone: **Settings → About phone → Build number** (tap 7×) → enable **USB debugging**
2. Plug USB, accept the prompt
3. Open a **new** PowerShell (so cache env vars load):

```powershell
cd E:\Android\projects\raasta_app
adb devices
flutter pub get
flutter run
```

## Disk setup (already applied)

| Item | Location |
|------|----------|
| Project | `E:\Android\projects\raasta_app` |
| Android SDK | `E:\Android\Sdk` |
| Gradle cache | `E:\Android\gradle-home` |
| Pub cache | `E:\Android\pub-cache` |

Do **not** use `E:\CUi Z\...` for the Flutter project — the space in the path breaks Android builds.
