# PlantDoctor – CLAUDE.md

> Read this file at the start of every session. Update it when architecture changes.

---

## What This App Does

**PlantDoctor** — photograph any plant, get back:
- Species identification + confidence (Kindwise plant.id API — permanent, best accuracy for houseplants/cultivars)
- Health diagnosis — what's wrong, severity, cause (Claude Vision with confirmed species context)
- Weather-contextualised care advice — diagnosis factors in your real local weather
- Care guide — light, water, humidity, temp, difficulty, toxicity
- Step-by-step treatment plan + prevention tips
- Plant profiles + health timeline journal
- Watering reminders + frost/rain alerts

Point. Shoot. Know everything about your plant.

---

## Current Status — v0.4.0

**v0.4 complete. Starting v0.5 (Plant Profiles, Journal & Polish).**

Full spec: `docs/superpowers/specs/2026-03-25-plantdoctor-v03-to-v10-design.md`

Completed (v0.3):
- ✅ Image picker (gallery + live camera via ImageSource.camera)
- ✅ Firebase Storage upload
- ✅ Kindwise species ID via Cloud Function
- ✅ Claude Vision disease detection with confirmed species context
- ✅ Claude generates care grid, summary, treatment narrative
- ✅ Full result screen (8 sections, tappable care cells, copy button, colored certainty chip)
- ✅ Firestore persistence + scan history journal
- ✅ Swipe-to-delete diagnoses (confirmDismiss pattern)
- ✅ Google + Apple + Email + Guest auth (Firebase Auth)
- ✅ Anonymous UID → real auth linking (linkWithCredential — no history lost)
- ✅ Riverpod migration (authStateProvider, diagnosesProvider)
- ✅ Global species info cache (speciesCache/{key} — ~35–40% fewer Claude tokens)
- ✅ Firebase Security Rules locked (per-user paths + cache read-only from functions)
- ✅ Claude 529 overload retry logic (withRetry — 3 attempts, exponential backoff)

Completed (v0.4):
- ✅ GPS location (geolocator, AndroidSettings forceLocationManager for emulator compat)
- ✅ `getWeather` Cloud Function (OpenWeatherMap 2.5, 30-min Firestore cache per grid cell)
- ✅ Local weather panel on home screen (WeatherPanel widget, 4 states)
- ✅ Weather-contextualised diagnosis (weather + hardiness zone sent to Claude at scan time)
- ✅ Frost & heat wave push alerts (FCM + sendWeatherAlerts scheduled function)
- ✅ Rain-skip watering alerts
- ✅ USDA hardiness zone detection (phzmapi.org, stored on users/{uid})
- ✅ Promise.race timeout on all Firestore admin SDK reads (prevents cold-start hangs)

---

## Roadmap

### v0.4 — Weather & Environmental Intelligence ⭐ Killer differentiator
- ✅ GPS location (geolocator, permission deferred to first use)
- ✅ `getWeather` Cloud Function (OpenWeatherMap, cache per grid cell 30 min)
- ✅ Local weather panel on home screen
- ✅ Weather-contextualised diagnosis (weather sent to Claude at scan time)
- ✅ Frost & heat wave push alerts (FCM)
- ✅ Rain-skip watering alerts
- ✅ USDA hardiness zone detection

### v0.5 — Plant Profiles, Journal & Polish
- [ ] Named plant profiles (Firestore `users/{uid}/plants/`)
- [ ] Health timeline chart per plant
- [ ] Plant notes (free-text per plant)
- [ ] Watering + rescan reminders (flutter_local_notifications, rain-adjusted)
- [ ] Dashboard home redesign
- [ ] Search & filter history
- [ ] Dark mode (ThemeMode.system)

### v0.6 — Monetisation + Admin Intelligence
- [ ] Freemium: 15 free scans/month (server-side inline reset — no scheduled function)
- [ ] Premium $3.99/month via RevenueCat
- [ ] Premium features: Plant Chat, Before/After Compare, Disease Progression AI, Seasonal Calendar, Share/Export
- [ ] Admin BI dashboard (Retool v1 → custom if outgrown)

### v0.7 — CNN Deployment (parallel track from v0.4)
- [ ] PlantVillage CNN on Cloud Run (disease detection for 14 crop species / 38 classes)
- [ ] Graceful fallback to Claude Vision for out-of-scope species
- [ ] Offline mode (Hive full cache)

### v1.0 — Launch
- [ ] Onboarding flow (location permission deferred — not on first screen)
- [ ] iOS full support (Info.plist, APNs, App Store metadata)
- [ ] Play Store submission

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| State | Riverpod |
| Auth | Firebase Auth — Google + Apple + Email + Guest (Anonymous) |
| Database | Cloud Firestore |
| Image Storage | Firebase Storage |
| Species ID | Kindwise plant.id API — permanent (best accuracy for houseplants/cultivars) |
| Disease detection + Care | Claude Vision (claude-sonnet-4) |
| Weather | OpenWeatherMap API (Cloud Function owned, cached) |
| Location | geolocator Flutter package |
| Notifications | flutter_local_notifications + Firebase Cloud Messaging |
| Local cache | Hive (notification IDs in v0.5, full offline in v0.7) |
| Subscriptions | RevenueCat |
| Backend | Firebase Cloud Functions (Node 20) |
| Admin dashboard | Retool (v0.6) → custom Flutter Web/React if outgrown |
| CNN hosting | Cloud Run (v0.7) |
| Routing | Navigator.push → GoRouter (when nav complexity warrants) |

---

## Architecture — Diagnosis Pipeline (v0.3+)

```
User photo (camera or gallery)
    │
    ▼
Firebase Storage          ← image uploaded, download URL returned
    │
    ▼
Cloud Function: diagnosePlant(imageUrl, lat?, lng?)
    │
    ├─ Kindwise plant.id API      ← species ID (permanent — best accuracy)
    │      returns: scientificName, displayName, confidence
    │
    ├─ speciesCache lookup        ← Firestore global cache by scientificName
    │      HIT  → skip Claude species info, use cached SpeciesInfo
    │      MISS → Claude generates SpeciesInfo, writes to cache
    │
    ├─ weatherCache lookup        ← if lat/lng provided (v0.4+)
    │      returns: WeatherData (temp, humidity, UV, rain chance)
    │
    └─ Claude Vision              ← disease detection + summary
           input: image + species name + weather context (v0.4+)
           returns: overallSeverity, issues[], summary, followUpIn
    │
    ▼
DiagnosisResult → Firestore (users/{uid}/diagnoses/) + ResultScreen
```

**Cost reduction:** Species info cache eliminates ~35–40% of Claude output tokens after warmup. CNN (v0.7) reduces Claude usage by ~60% for in-scope crop species.

---

## Monetisation

- **Free:** 15 scans/month, full diagnosis quality, weather, profiles, reminders
- **Premium ($3.99/month):** Unlimited scans + Plant Chat, Before/After Compare, Disease Progression AI, Seasonal Calendar, Share/Export
- **Enforcement:** Server-side only (Cloud Function inline reset). Never client-side.
- **Scan count pattern:** `monthlyScanCount` + `scanCountMonth` fields on `users/{uid}`. Reset lazily inline when month changes. No scheduled function.
- **RevenueCat:** `isPremium` written to Firestore by webhook. Cloud Function reads locally — no per-scan HTTP call.
- **Break-even:** ~60 premium subscribers covers ~1,000 free users at 15 scans/month.

---

## Secrets Required

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
firebase functions:secrets:set KINDWISE_API_KEY
firebase functions:secrets:set OPENWEATHER_API_KEY      # v0.4
firebase functions:secrets:set REVENUECAT_SECRET_KEY    # v0.6
```

Keys are stored in Google Secret Manager and injected at runtime. Never in source code.

---

## Project Structure

```
lib/
├── main.dart                     # Firebase init, auth, run app
├── theme.dart                    # AppTheme: colors, severityColor(), severityIcon()
├── models/
│   ├── diagnosis_model.dart      # DiagnosisResult + SpeciesInfo + PlantIssue + WeatherSnapshot
│   └── plant_profile.dart        # PlantProfile + PlantNote (v0.5)
├── services/
│   ├── storage_service.dart      # Upload image → return download URL
│   ├── firebase_service.dart     # Firestore save / delete / stream
│   ├── weather_service.dart      # getWeather callable wrapper (v0.4)
│   └── auth_service.dart         # Sign-in / link / sign-out (v0.3)
├── providers/                    # Riverpod providers (v0.3+)
│   ├── auth_provider.dart
│   ├── diagnoses_provider.dart
│   ├── weather_provider.dart
│   └── plant_profiles_provider.dart
├── screens/
│   ├── home_screen.dart          # Dashboard + scan button + diagnoses list
│   ├── loading_screen.dart       # Lottie animation
│   ├── result_screen.dart        # Full diagnosis display (8 sections, tappable care cells, copy button)
│   ├── auth_screen.dart          # Google / Apple / Email / Guest sign-in (v0.3)
│   ├── email_auth_screen.dart    # Email + password sign-in / create account (v0.3)
│   └── plant_profile_screen.dart # Per-plant history + timeline (v0.5)
└── widgets/
    ├── severity_badge.dart       # Colored pill: healthy/low/medium/high
    └── issue_card.dart           # Expandable card per issue

functions/
├── index.js                      # diagnosePlant (withRetry for Claude 529), getWeather, chatWithPlant, etc.
├── lib/
│   └── utils.js                  # speciesCacheKey() — normalises scientific name to Firestore doc ID
└── package.json

docs/
└── superpowers/specs/
    └── 2026-03-25-plantdoctor-v03-to-v10-design.md   # Full feature spec
```

---

## Key Firestore Collections

```
users/{uid}                          # user doc: monthlyScanCount, isPremium, hardinessZone, fcmToken
users/{uid}/diagnoses/{id}           # DiagnosisResult docs
users/{uid}/plants/{id}              # PlantProfile docs (v0.5)
speciesCache/{scientificName}        # global — Cloud Function write only
weatherCache/{lat2dp_lng2dp}         # global — Cloud Function write only (v0.4)
seasonalCalendars/{species}_{zone}   # global — Cloud Function write only (v0.6)
```

---

## Firebase Security Rules (v0.3+)

Rules are locked — do not revert to `allow read, write: if true`.
See full rules in spec or `firestore.rules`.

- Per-user data (`users/{uid}/...`): auth user can read/write own data only
- Global caches (`speciesCache`, `weatherCache`): any auth user (incl. anonymous) can read; write only from admin SDK
- Anonymous auth users have `request.auth != null` — they can fully use the app

---

## Common Bugs

| Bug | Fix |
|---|---|
| Kindwise 401 | Check KINDWISE_API_KEY is set in Secret Manager and listed in `secrets: [...]` |
| Kindwise returns no diseases | `is_healthy.binary` may be true — check probability threshold (currently 0.20) |
| Claude returns JSON in code fences | Already stripped with `.replace()` chain |
| `signInAnonymously` fails | Enable Anonymous Auth in Firebase Console |
| Firestore permission denied | Check Security Rules — anonymous users need `request.auth != null` not `request.auth.uid` check on global caches |
| Storage upload hangs | Check Storage rules — user must be authenticated |
| Cloud Function cold start on demo | `minInstances: 1` already set |
| `callable.call()` throws on Android emulator | Test on real device or deployed function |
| RevenueCat webhook 401 | Verify `REVENUECAT_SECRET_KEY` matches what's set in RevenueCat dashboard |
| Weather not loading | Check OPENWEATHER_API_KEY in Secret Manager; verify geolocator permission granted |
| Claude 529 overloaded | `withRetry` handles automatically (3 attempts, 2s/4s backoff) — transient, no action needed |
| Google Sign-In fails on device | Ensure SHA-1 fingerprint added to Firebase project (Project Settings → Android app) |
