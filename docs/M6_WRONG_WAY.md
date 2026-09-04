# M6 — Wrong-way driving

**Owner:** Zoya  
**How it works:** GPS heading (no extra AI model)

---

## What the app does

1. At trip start, locks your **forward direction** (baseline heading) after ~5 moving GPS samples  
2. If you keep driving **~opposite** (≥135°) while moving **≥8 km/h** → starts a confirm timer  
3. After **60 seconds** → **one** wrong-way alert (banner + voice)  
4. **90 second** cooldown before another wrong-way alert  
5. Event saved in trip history as `wrongWay` (M7 dashboard)

---

## Demo mode (viva / indoor)

**Settings → M6 · Wrong-way → Wrong-way demo mode → ON**

| Setting | Behavior |
|---------|----------|
| Demo **ON** | Simulates conflict; alert after **~20s** (trip auto-starts ~2s after Drive opens) |
| Demo **OFF** | Real GPS: need movement + opposite heading for **~60s** |

### Demo steps (2 minutes)

1. Turn **Wrong-way demo mode** ON in Settings  
2. Open **Drive** → wait ~2s (trip starts automatically)  
3. Watch chip: `Wrong-way demo… alert in Xs`  
4. After ~20s: red **DANGER · Wrong way** banner + voice  
5. End drive → check trip summary / dashboard for wrong-way count  

Turn demo **OFF** before real road tests.

---

## Real road test (GPS)

1. Demo mode **OFF**  
2. Allow **Location** (while using app)  
3. Start Drive → drive forward normally **>8 km/h** for ~30s (locks baseline)  
4. Only for a **safe test area**: briefly go opposite direction  
5. After ~60s sustained conflict → alert fires  

**Note:** Heading needs a phone with compass/GPS bearing. Tunnels and standing still will not trigger real mode.

---

## Constants (code)

| Constant | Value |
|----------|--------|
| Confirm (real) | 60s |
| Confirm (demo) | 20s |
| Cooldown | 90s |
| Min speed | 8 km/h |
| Opposite angle | ≥135° |

File: `lib/data/services/wrong_way_service.dart`

---

## FYP report (one paragraph)

> Module 6 detects wrong-way driving using GPS heading heuristics rather than a dedicated neural network. The system establishes a baseline forward heading during normal travel, then monitors for sustained heading conflict (≥135°) while the vehicle exceeds 8 km/h. A 60-second confirmation window reduces false alarms from U-turns and GPS noise; demo mode compresses this to 20 seconds for indoor evaluation. Alerts are delivered via visual banner, TTS (English/Urdu), and logged to the offline trip store for Module 7 analytics.

---

## Do not

- Train a wrong-way YOLO class (not needed for FYP)  
- Expect laptop/indoor detection without **demo mode**  
- Use demo mode on the road (turn it off)
