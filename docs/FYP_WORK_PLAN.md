# Raasta FYP — Joint Work Plan (Zoya & Amna)

**Project:** Raasta — Real-time road hazard awareness for drivers (Pakistan)  
**Team:** Zoya (BS Data Science) · Amna (BAI)  
**App stack:** Flutter + on-device TFLite (YOLOv8) + Firebase Auth + Hive  
**Collaboration:** GitHub (one repo, PR-based)  
**Document purpose:** Single source of truth for who does what, how, and when. Update this file when scope changes.

---

## 1. Project goal (one sentence)

Raasta uses the phone’s rear camera, GPS, and voice alerts to warn drivers about road damage, people/animals, traffic signs, speeding, and wrong-way driving, then stores a local trip summary — with no internet required while driving.

---

## 2. Modules overview & current status

| Module | Name | Status (as of plan date) | Owner going forward |
|--------|------|--------------------------|---------------------|
| M1 | User onboarding & profile | **Done** | Shared credit (Phase-1) |
| M2 | Road damage detection | **In app** (fine-tuned TFLite) | **Zoya** |
| M3 | Traffic sign reading | **Not started** | **Amna** |
| M4 | Speed monitoring & alerts | **Mostly done** (GPS + HUD; limit hard-coded 60) | **Amna** (connect limits from M3) |
| M5 | Pedestrians & animals | **In app** (same YOLO as M2) | **Zoya** |
| M6 | Wrong-way driving | **In app** (GPS heading + demo mode) | **Zoya** |
| M7 | Driver insights dashboard | **Mostly done** | **Zoya** (extend for new hazards) |

**Already working in the app (do not rebuild):** signup/login, permissions, language (EN/Urdu/bilingual), live camera drive screen, M2 pothole/crack/speed_bump TFLite, GPS speed HUD, overspeed voice + cooldown, trip start/end, local Hive history, weekly dashboard.

---

## 3. Equal workload split

### Zoya (BS Data Science) — ~50%

| Area | Responsibility |
|------|----------------|
| **M2 + M5** | One YOLOv8n model, 8 classes → TFLite → Flutter alerts |
| **M6** | Wrong-way detection (heuristics + delay + alerts) |
| **M7** | Trip/hazard analytics for all new event types |
| **Evaluation** | Metrics tables, confusion notes, failure cases for report |

### Amna (BAI) — ~50%

| Area | Responsibility |
|------|----------------|
| **M3** | Sign detection + OCR (EN/Urdu) + speak in preferred language |
| **M4 link** | Speed limit from detected signs (replace fixed 60 km/h) |
| **Pipeline** | Run OCR only when a sign is detected (battery) |
| **Integration** | Clean APIs so Zoya’s M7 can log sign/speed events |

### Shared (both)

- GitHub PRs and code review of each other’s work  
- Joint road tests and demo video  
- Final report merge, slides, viva prep  
- Week 8–9 full-app integration

---

## 4. Class / event contracts (so we don’t conflict)

### Zoya’s YOLO classes (`raasta_m2_m5`)

| ID | Class | Module |
|----|--------|--------|
| 0 | `pothole` | M2 |
| 1 | `crack` | M2 |
| 2 | `speed_bump` | M2 |
| 3 | `person` | M5 |
| 4 | `cow` | M5 |
| 5 | `dog` | M5 |
| 6 | `goat` | M5 |
| 7 | `horse` | M5 |

### Events Amna must emit for M7 (Zoya displays)

When these happen, write into the same trip log structure (extend Hive model together in one PR):

- `speed_warning` (limit used, current speed)  
- `sign_read` (optional count: signs spoken)  
- `wrong_way` — **Zoya emits this**; Amna does not own M6  

### Events Zoya must emit for M7

- Counts: pothole, crack, speed_bump, person, cow, buffalo, dog, cat, horse, donkey, goat  
- `wrongWay` alert count (M6)  

---

## 5. How to work — Zoya (detailed)

### 5.1 M2 + M5 — Train one model

**Goal:** Fine-tune `yolov8n.pt` on 8 classes; ship `assets/models/raasta_m2_m5.tflite`.

**Where:** Google Colab (T4 GPU). Local PC has no NVIDIA GPU — do **not** train locally.

**Start here:**

1. Read `ml/README.md` and `ml/DATASETS.md`  
2. Open Colab → upload `ml/colab/RAASTA_YOLOv8_M2_M5.ipynb`  
3. Runtime → GPU (T4)  
4. Add Roboflow API key  
5. Run all → download `.pt` + `.tflite`  
6. Put TFLite in `assets/models/raasta_m2_m5.tflite`  
7. Update Flutter interpreter: `numClasses = 8`, map new `HazardType`s, TTS phrases  

**Target:** mAP50 ≈ 0.55–0.75 (realistic). Do not chase 96% paper numbers.

**Polish (after baseline works):**

- Add 50–200 local Islamabad/Rawalpindi frames if possible  
- Tune confidence per class (speed_bump usually higher threshold)  
- Keep ROI focused on road; night = more night images + torch, not a second model  

**Done when:** Live phone demo detects at least pothole/bump + person (and ideally 1 animal class) with voice alert.

### 5.2 M6 — Wrong-way (no custom training)

**Goal:** Visual + voice warning after confirmation delay.

**Implemented approach:**

1. Lock a **baseline GPS heading** after several moving samples at trip start  
2. If heading stays ~opposite (≥135°) while moving → start confirm timer  
3. After **60s** conflict → one alert + **90s** cooldown; short blips ignored  
4. **Demo mode** (Settings → Wrong-way demo): force conflict so viva works indoors; alert after **~20s**  
5. Log as `HazardType.wrongWay` into trip Hive history (M7)

**Do not** train a wrong-way neural net for FYP.

**Done when:** Demo (or staged reverse) shows delayed alert + M7 count.

### 5.3 M7 — Dashboard extensions

**Goal:** Show new hazard types + wrong-way + keep weekly overview accurate.

**Tasks:**

- Extend `HazardType` / trip counters for M5 + wrong-way  
- Trip summary sheet after drive  
- Weekly totals still work offline (Hive)  

**Done when:** After a test drive, dashboard numbers match what was announced.

### 5.4 Evaluation pack (viva)

Save in `docs/eval/` or report appendix:

- Training curves / best mAP50  
- Per-class notes (what fails: small cracks, night goats, etc.)  
- 5–10 screenshot/video failure examples  

---

## 6. How to work — Amna (detailed)

### 6.1 M3 — Traffic sign reading

**Goal:** Detect sign → OCR text → speak in user language (EN / Urdu / bilingual).

**Do this in layers (don’t start with Urdu OCR):**

| Step | What | How |
|------|------|-----|
| 1 | Sign **detector** | Fine-tune small YOLO on traffic signs **or** use a public sign model; export TFLite |
| 2 | **English OCR** | Prefer Google ML Kit Text Recognition (on-device) or similar pretrained OCR — **do not train OCR from scratch** |
| 3 | **Urdu OCR** | Pretrained Urdu-capable OCR; if weak, demo common signs with template/fallback phrases |
| 4 | Translate when needed | Simple mapping / translation for spoken output — not a full NMT research model |
| 5 | TTS | Reuse existing `TtsService` + language preference from M1 |
| 6 | Battery | Run OCR **only** when detector finds a sign (gate high-res crop) |

**Scope safety (if time is short):** English + numeric speed-limit signs first; Urdu as best-effort for viva.

**Done when:** Point phone at a speed-limit / stop-style sign → text appears and is spoken.

### 6.2 M4 — Speed limit from signs

**Goal:** Replace hard-coded `speedLimitKph = 60`.

**Tasks:**

1. When OCR/sign pipeline reads a speed limit (e.g. 40/50/60/80), update active limit  
2. Keep existing GPS speed, margin (~3 km/h), cooldown (~45s), green/yellow/red HUD  
3. Optional: remember last known limit for the trip until a new sign appears  

**Done when:** Overspeed alert uses the **sign’s** limit, not always 60.

### 6.3 Integration notes for Amna

- Prefer new files under clear names, e.g. `lib/data/services/sign_detector.dart`, `ocr_service.dart`  
- Avoid rewriting Zoya’s YOLO M2/M5 interpreter unless agreed in a GitHub Issue  
- Document in PR: how Drive screen calls your pipeline (order of models / frame skip)

---

## 7. GitHub workflow (both must follow)

### Branches

```text
main                 → demo-ready only
develop              → weekly integration
feature/zoya-m2-m5
feature/zoya-m6-wrong-way
feature/zoya-m7-extend
feature/amna-m3-signs
feature/amna-m4-speed-limit
```

### Rules

1. **No direct commits to `main`**  
2. Open a PR → other person reviews (even a short “LGTM”) → merge to `develop`  
3. Sunday (or agreed day): merge `develop` → `main`, tag `v0.x.y`  
4. Issue labels: `zoya`, `amna`, `shared`, `blocked`, `scope-change`  
5. Commit style: `feat(m5): add animal classes to interpreter`  

### Folder ownership (reduce merge pain)

| Path | Primary owner |
|------|----------------|
| `ml/` (datasets, Colab, train scripts) | Zoya |
| `ml/` sign-specific subfolder (if needed) | Amna |
| `assets/models/raasta_m2_m5.tflite` | Zoya |
| `assets/models/` sign / OCR assets | Amna |
| M5 / M6 / M7 Dart services | Zoya |
| M3 / M4-from-sign Dart services | Amna |
| Shared: `drive_provider`, trip Hive models | Coordinate via Issue before big edits |

---

## 8. 10-week timeline (parallel)

| Week | Zoya | Amna | Shared |
|------|------|------|--------|
| **1** | Dataset merge + Colab baseline train | Sign dataset + detector baseline | Repo branches + Issues board |
| **2** | Improve mAP; export TFLite v1 | Sign TFLite / detector in app stub | — |
| **3** | Flutter: 8-class + M5 TTS | English OCR + speak | Smoke test on one phone |
| **4** | Thresholds + night samples | Urdu / bilingual path | — |
| **5** | Start M6 prototype (delay logic) | M4: live speed limit from signs | — |
| **6** | M6 alerts + M7 wrong-way log | Harden OCR gating / battery | Joint road test #1 |
| **7** | M7 charts for all new types | Polish M3 false positives | — |
| **8** | Integration fixes | Integration fixes | One APK with all modules |
| **9** | Report: data, train, M2/M5/M6/M7 | Report: M3, M4, algorithms | Merge report |
| **10** | Viva prep | Viva prep | Demo video + slides |

If behind: Amna drops deep Urdu OCR first; Zoya keeps M6 simple (GPS heading conflict + long delay) before fancy vision.

---

## 9. Definition of done (committee checklist)

### Must demo (both present)

- [ ] Login + permissions + language  
- [ ] Live M2 hazards (pothole / bump)  
- [ ] M5 at least person (+ one animal if possible)  
- [ ] Sign read + spoken (Amna)  
- [ ] Overspeed uses sign limit (Amna)  
- [ ] Wrong-way delayed alert (Zoya)  
- [ ] Trip saved + weekly dashboard (Zoya)

### Report must include

- [ ] Module ownership table (this document’s §3)  
- [ ] Dataset sources + train setup (Zoya)  
- [ ] M3 pipeline diagram (Amna)  
- [ ] M6 algorithm + why 60s delay (Zoya)  
- [ ] Limitations (honest): night, Urdu OCR, false alarms  

---

## 10. Communication

- Prefer GitHub Issues for tasks and blockers  
- For urgent blocks: message + link the Issue  
- Scope changes only with label `scope-change` and both agree (update **this file**)  
- Do not silently take the other’s module  

---

## 11. Quick “what do I do tomorrow?”

### Zoya

1. Create GitHub Project/Issues for M2+M5, M6, M7  
2. Run/fix `RAASTA_YOLOv8_M2_M5.ipynb` on Colab  
3. Note best **mAP50** and share with Amna in a short Discord/WhatsApp update  

### Amna

1. Create Issues for M3 steps (detect → OCR EN → TTS → Urdu → gate)  
2. Pick sign dataset + OCR library (ML Kit recommended for speed)  
3. Branch `feature/amna-m3-signs` and add a stub service that logs “sign candidate” boxes  

---

## 12. Document control

| Version | Date | Notes |
|---------|------|--------|
| 1.0 | 2026-08-11 | Initial equal split: Zoya = M2+M5+M6+M7; Amna = M3+M4 link |

**Owners of this plan file:** Zoya & Amna (both may edit via PR).

---

*Raasta — work equally, merge weekly, demo one app.*
