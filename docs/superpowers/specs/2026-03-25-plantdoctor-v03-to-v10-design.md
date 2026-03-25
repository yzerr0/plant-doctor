# PlantDoctor — v0.3 → v1.0 Feature Expansion Design

**Date:** 2026-03-25
**Status:** Approved
**Session:** Brainstorming — full feature roadmap, monetisation, weather, profiles, admin BI

---

## 1. Overview

PlantDoctor is a Flutter app that photographs plants and returns species identification, disease diagnosis, care guidance, and treatment plans via a Kindwise → Claude Vision pipeline. The demo (v0.2) is complete. This document defines the full roadmap from v0.3 through v1.0 — covering new features, monetisation strategy, architecture changes, and tech stack additions.

---

## 2. Decisions Made

| Decision | Choice | Rationale |
|---|---|---|
| Build order | Features first (Option B) | Ship compelling features before introducing a paywall. Retrofit monetisation is clean. |
| Monetisation | Generous freemium (Option A) | 15 free scans/month + $3.99/month premium. Low friction to try, real revenue from power users. |
| Species ID | Keep plant.id (Kindwise) forever | Best accuracy for tropical houseplants and cultivars. PlantNet too weak for this use case. CNN (v0.7) replaces disease detection only — Kindwise keeps doing species ID. |
| CNN scope | Disease detection only | PlantVillage covers 14 crop species / 38 disease classes. Cannot replace Kindwise for broad species ID. v0.7 CNN replaces Claude Vision's disease classification role; Claude generates narrative only. |
| Cost reduction | Global species info cache | Cache Claude-generated care info per species in Firestore. ~35–40% fewer Claude tokens from day one. |
| State management | Migrate to Riverpod in v0.3 | Do it before weather + profiles + notifications add cross-widget state. Avoids painful mid-development refactor. Weather provider created as a typed stub in v0.3; fully implemented in v0.4. |
| Auth | Google + Apple + Email + Guest | Apple Sign-in required by App Store policy. Guest (anonymous) preserved as try-before-signup path. |
| Auth migration | Firebase linkWithCredential() | Links anonymous UID to real account. All Firestore data preserved under same UID. |
| Weather fetch ownership | Cloud Function owns all weather fetches | Prevents client-side spoofing. Single cache source of truth. Home screen calls a lightweight `getWeather` callable; scan flow calls it internally. |
| Weather API | OpenWeatherMap free tier | 1M calls/month free. Cache per rounded lat/lng for 30 min. Well inside free tier for any realistic user base. |
| Scan count strategy | Inline reset, no scheduled function | `monthlyScanCount` + `scanCountMonth` fields on user document. Cloud Function resets inline when month changes. No full-collection iteration. No scheduled function needed. |
| RevenueCat entitlement | Cached in Firestore, updated by webhook | Cloud Function reads `users/{uid}.isPremium` locally (fast). RevenueCat webhook updates it on subscription events. No per-scan HTTP call to RevenueCat. |
| Admin dashboard | Retool v1, custom later | Connects to Firestore directly. Ships in a day. Replace with Flutter Web/React if outgrown. |
| CNN | Parallel track from v0.4 | Research project (weeks of training + TFLite optimisation). Deploy target is v0.7, not a sprint. |
| Cut: home screen widget | Deferred post-launch | Platform-native Kotlin/Swift. Complex, low ROI pre-launch. |
| Cut: multi-angle scan | Deferred post-launch | Complicates scan UX before core flow is validated by real users. |
| Dark mode | v0.5 (not v0.7) | One day of Flutter ThemeData work. High user expectation. Demoing v0.5 profiles publicly — impression matters. |
| Location permission | Deferred to first weather use | Requesting on first launch before user sees value risks iOS App Store review flags. Show value first. |

---

## 3. Monetisation Architecture

### Tiers

| Tier | Price | Scan limit | Features |
|---|---|---|---|
| Free | $0 | 15 scans/month | Full diagnosis quality, weather, plant profiles, reminders, hardiness zone |
| Premium | $3.99/month | Unlimited | + Plant Chat, Before/After Compare, Disease Progression AI, Seasonal Calendar, Share/Export |

### Scan Count — Inline Reset Pattern

Each user document (`users/{uid}`) carries two fields:

```
monthlyScanCount: integer   // number of scans this calendar month
scanCountMonth: string      // "YYYY-MM" of the current count window, e.g. "2026-03"
```

Cloud Function logic on each scan:

```js
const currentMonth = new Date().toISOString().slice(0, 7); // "2026-03"
const userDoc = await db.collection('users').doc(uid).get();
const { monthlyScanCount = 0, scanCountMonth = '', isPremium = false } = userDoc.data() ?? {};

const effectiveCount = scanCountMonth === currentMonth ? monthlyScanCount : 0;

if (!isPremium && effectiveCount >= 15) {
  throw new HttpsError('resource-exhausted', 'Monthly scan limit reached. Upgrade to premium.');
}

// ... run diagnosis ...

await db.collection('users').doc(uid).set({
  monthlyScanCount: effectiveCount + 1,
  scanCountMonth: currentMonth,
}, { merge: true });
```

**Benefits:** No scheduled function. No full-collection iteration. Resets lazily per user on their first scan of a new month. Scales to any user count at zero extra cost.

### RevenueCat Integration

- `purchases_flutter` package on client — manages paywall UI and initiates purchases.
- RevenueCat webhook (`POST /webhook`) hits a Firebase Cloud Function HTTP endpoint (`revenuecat_webhook`) on subscription events (purchased, renewed, cancelled, expired).
- **Webhook authentication:** `revenuecat_webhook` validates the `Authorization` header against `REVENUECAT_SECRET_KEY` before processing any payload. Requests that fail validation return 401 immediately. This prevents fraudulent `isPremium: true` grants from any actor who discovers the function URL.
  ```js
  if (req.headers.authorization !== revenuecatKey.value()) {
    res.status(401).send('Unauthorized');
    return;
  }
  ```
- Webhook handler writes `isPremium: true/false` and `premiumExpiresAt` to `users/{uid}` document.
- Cloud Function checks `users/{uid}.isPremium` locally — zero extra HTTP calls per scan.
- Failsafe: if `isPremium` field missing (new user, webhook delay), treat as free tier.
- RevenueCat entitlement name: `premium`.

```
REVENUECAT_SECRET_KEY  → Secret Manager (added in v0.6)
```

---

## 4. Cross-Cutting Architecture Changes

These land in v0.3 and persist across all releases.

### 4.1 Global Species Info Cache

```
Firestore: speciesCache/{scientificName}
  - speciesInfo: SpeciesInfo (light, water, humidity, temp, difficulty, toxicity, funFact, origin, lifespan)
  - cachedAt: ISO timestamp
  - scanCount: integer (global hit count for analytics)
```

- Written by Cloud Function after first successful Claude call for any species.
- Read before Claude call. Cache hit → skip species info generation entirely; pass cached `speciesInfo` directly.
- Claude prompt on cache hit: disease detection + summary only (~40% fewer output tokens).
- Cache key: Kindwise `scientificName` (e.g. `"Monstera deliciosa"`). Remains stable post-v0.7 because Kindwise continues doing species ID.
- Read-only for all auth users. Write-only from Cloud Functions via admin SDK (bypasses Security Rules).
- No conflict with v0.7 CNN: CNN replaces disease detection, not species ID. Kindwise still provides `scientificName` as the cache key.

### 4.2 Weather Cache & Fetch Architecture

**Owner:** Cloud Function owns all weather fetches. Client never calls OpenWeatherMap directly.

**Two callables:**
- `getWeather(lat, lng)` — lightweight callable for home screen weather panel.
- `diagnosePlant(imageUrl, lat, lng)` — existing scan callable, extended to accept coordinates and fetch weather internally.

**Cache document:**
```
Firestore: weatherCache/{lat2dp_lng2dp}   (lat/lng rounded to 2 decimal places, e.g. "48.85_2.35")
  - current: { tempC, humidityPct, uvIndex, rainChancePct, condition, windKph }
  - forecast: [ { date, rainChancePct, minTempC, maxTempC } ]  // 5 days
  - fetchedAt: ISO timestamp
  - expiresAt: ISO timestamp (fetchedAt + 30 minutes)
```

**Lookup logic (in both callables):**
```js
const key = `${lat.toFixed(2)}_${lng.toFixed(2)}`;
const cached = await db.collection('weatherCache').doc(key).get();
if (cached.exists && new Date(cached.data().expiresAt) > new Date()) {
  return cached.data(); // cache hit
}
// else: fetch from OpenWeatherMap, write cache, return
```

### 4.3 Anonymous → Real Auth Migration

- User scans as guest (anonymous UID) — data saved to `users/{anonUid}/diagnoses/`.
- On sign-up: Firebase `linkWithCredential(GoogleAuthProvider / AppleAuthProvider / EmailAuthProvider)`.
- UID is preserved — all Firestore data remains intact with no migration needed.
- If user signs in fresh (no anonymous session): standard sign-in, empty history.
- Sign-up prompt shown after first scan result: "Save your plant history — create an account."
- Account linking is silent to the user if they were already anonymous — they just see their history preserved.

### 4.4 Firebase Security Rules

```javascript
// Firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Per-user data — any authenticated user (including anonymous) can read/write own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /diagnoses/{diagnosisId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      match /plants/{plantId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Global species cache — any auth user (including anonymous) can read
    // Write is via admin SDK from Cloud Functions — bypasses these rules
    match /speciesCache/{speciesId} {
      allow read: if request.auth != null;
      allow write: if false;
    }

    // Weather cache — same as species cache
    match /weatherCache/{cacheId} {
      allow read: if request.auth != null;
      allow write: if false;
    }
  }
}

// Storage
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

**Notes:**
- `users/{uid}.monthlyScanCount`, `users/{uid}.isPremium` etc. are fields on the user document — covered by the `users/{userId}` rule above. Client can read (to show scan count UI) but only Cloud Functions write these fields via admin SDK.
- Anonymous Auth users have `request.auth != null` — they can read/write their own data and read global caches.

---

## 5. Release Roadmap

### v0.3 — Core Upgrade (Auth, Camera & Foundation)

**Goal:** Fix structural gaps. Everything else builds on this.

| Feature | Detail |
|---|---|
| Live camera input | `camera` Flutter package. Replace gallery-only `ImagePicker` source. |
| Google Sign-in | `google_sign_in` package. Firebase Auth integration. |
| Apple Sign-in | `sign_in_with_apple` package. Required for iOS App Store when any third-party auth is offered. |
| Email/password auth | Firebase Auth email provider. |
| Guest continuation | Anonymous auth preserved. Sign-up prompt after first scan result. |
| Anonymous UID linking | `linkWithCredential()` on sign-up — all scan history preserved under same UID. |
| Global species info cache | Cloud Function checks `speciesCache/{scientificName}` before calling Claude. Writes on miss. |
| Riverpod migration | Replace all `setState`. Providers: `authProvider`, `diagnosesProvider`, `weatherProvider` (stub — returns null until v0.4 implements it), `plantProfilesProvider` (stub until v0.5). |
| Firebase Security Rules | Per-user Firestore + Storage rules. Global cache collections locked to Cloud Function writes. `users/{uid}` document rule covers `monthlyScanCount`, `isPremium`, etc. |

**New packages:** `google_sign_in`, `sign_in_with_apple`, `camera`, `flutter_riverpod`, `riverpod_annotation`
**New Cloud Function logic:** Species cache read/write wrapping existing `diagnoseAndDescribe()`.

---

### v0.4 — Weather & Environmental Intelligence

**Goal:** The app's primary differentiator. AI diagnosis that knows your local weather.

| Feature | Detail |
|---|---|
| GPS location | `geolocator` + `permission_handler`. Permission deferred — requested when user first taps weather panel, not on launch. |
| `getWeather` callable | Lightweight Cloud Function callable. Accepts `{ lat, lng }`. Checks weatherCache, fetches OpenWeatherMap on miss. Returns `WeatherData`. |
| Local weather panel | Home screen card: temp, humidity, UV, rain chance, condition icon. Calls `getWeather` on app open if permission granted. |
| Weather-contextualised diagnosis | `diagnosePlant` extended to accept `{ imageUrl, lat, lng }`. Fetches weather internally (cache-first). Adds 4-line weather context block to Claude prompt. |
| `weatherProvider` implementation | Replaces v0.3 stub. Calls `getWeather` callable. Exposes `WeatherData?` to UI. |
| Frost & heat wave alerts | FCM push. Cloud Function `sendWeatherAlerts` checks tomorrow's forecast against each plant's safe temperature range. Triggered by scheduled function (daily, 07:00 UTC). Requires `firebase_messaging` device token stored on user document. |
| Rain-skip watering alerts | `sendWateringReminder` Cloud Function (also v0.5) suppresses if `forecast[0].rainChancePct >= 40`. |
| Hardiness zone detection | Reverse-geocode lat/lng to USDA zone (1–13a/b) using a static zone lookup or a simple geocoding call. Stored on `users/{uid}.hardinessZone`. Displayed as badge on result screen. |

**New packages:** `geolocator`, `flutter_local_notifications`, `permission_handler`, `firebase_messaging`
**New secrets:** `OPENWEATHER_API_KEY`
**iOS setup:** APNs certificate required for FCM push on iOS. Add `firebase_messaging` to `Info.plist` background modes.
**New Cloud Functions:** `getWeather`, `sendWeatherAlerts` (scheduled daily)

---

### v0.5 — Plant Profiles, Journal & Polish

**Goal:** Transform scanner into companion. Dark mode. Watering reminders with weather awareness.

| Feature | Detail |
|---|---|
| Named plant profiles | Firestore `users/{uid}/plants/{plantId}`. Fields: `name`, `location` (indoor/outdoor), `primarySpecies`, `primaryScientificName`, `diagnosisIds[]`, `wateringIntervalDays`, `lastWateredAt`, `notes[]`, `hardinessZone`, `createdAt`. `primarySpecies` set from first attached scan. Required by seasonal calendar (v0.6) and health timeline. |
| Attach scans to profiles | Diagnosis result screen: "Add to plant profile" action. Writes `plantProfileId` to diagnosis doc and `diagnosisId` to plant doc. |
| Health timeline | Chart of `overallSeverity` across attached scans, sorted by `createdAt`. `fl_chart` line/step chart. |
| Plant notes | `notes: [{ text, createdAt }]` array on plant doc. Add/delete from profile screen. |
| Watering reminders | `wateringIntervalDays` + `lastWateredAt` on plant profile. Local notification scheduled via `flutter_local_notifications`. Reminder suppressed by `sendWateringReminder` Cloud Function if rain forecast ≥ 40%. Notification scheduling state (notification IDs) stored in Hive locally. |
| Rescan reminders | Local notification scheduled at `diagnosis.createdAt + followUpIn days`. Notification ID stored in Hive to allow cancellation if scan deleted. |
| Dashboard redesign | Plant count, severity breakdown (healthy / low / medium / high counts from stream), upcoming task chips (watering due, rescan due), weather mini-card. |
| Search & filter | Client-side search on `plantSpecies` name across loaded diagnoses. Severity filter chips. Date range picker. |
| Dark mode | `ThemeData.dark()` companion to existing `AppTheme`. `MaterialApp(themeMode: ThemeMode.system)`. All existing color constants verified in both themes. |

**New packages:** `hive`, `hive_flutter`, `fl_chart`
**Hive usage in v0.5:** Notification ID persistence for watering + rescan reminders (allows cancel on delete). Extended to full offline cache in v0.7.
**New Firestore collections:** `users/{uid}/plants/`

---

### v0.6 — Monetisation + Admin Intelligence

**Goal:** Revenue. Gate premium features. Owner visibility into business performance.

| Feature | Detail |
|---|---|
| Freemium scan gates | Cloud Function inline reset pattern (Section 3). Checks `isPremium` and `monthlyScanCount` before Kindwise call. |
| RevenueCat integration | `purchases_flutter`. Entitlement `premium`. Paywall screen shown when limit hit or premium feature tapped. `revenuecat_webhook` Cloud Function updates `users/{uid}.isPremium` on subscription events. |
| Premium paywall screen | Lists premium benefits. Initiated from scan limit error or premium feature tap. |
| Plant Chat [Premium] | `chatWithPlant(diagnosisId, message)` Cloud Function. Fetches diagnosis from the **caller-scoped path** `users/{uid}/diagnoses/{diagnosisId}` — ownership enforced by path, not a global lookup. Passes full `DiagnosisResult` as context to Claude with user message. Returns response string. Conversation history not persisted (stateless). |
| Before/After Compare [Premium] | Requires plant profile with ≥ 2 scans. Client sends `{ diagnosisIdA, diagnosisIdB }` to `compareScans` Cloud Function. Function fetches both docs from `users/{uid}/diagnoses/` — caller-scoped path enforces ownership. Diffs issues, returns structured comparison. UI renders side-by-side photos + severity change chips. |
| Disease Progression AI [Premium] | Part of `compareScans` output. Claude receives both diagnosis JSONs and returns: issue status per problem ("worsened" / "stable" / "resolved" / "new"). |
| Seasonal Calendar [Premium] | `generateSeasonalCalendar(scientificName, hardinessZone)` Cloud Function. Cached in `seasonalCalendars/{scientificName}_{zone}`. Claude generates 12-month care table. Premium only; cache shared globally across all premium users. |
| Share / Export [Premium] | `pdf` package generates single-page diagnosis card (image + species + summary + top issue). System share sheet via `share_plus`. |
| Admin BI Dashboard (Retool v1) | Retool connected to Firestore. Panels: DAU/MAU (from `users` collection `lastSeenAt`), scans/day (aggregate from diagnoses), free vs premium user counts, MRR estimate (premium count × $3.99), estimated Claude cost (scan count × $0.008 after cache), conversion rate. Claude-powered weekly narrative via Retool webhook → `adminInsightNarrative` Cloud Function → Claude. |

**New packages:** `purchases_flutter`, `pdf`, `share_plus`
**New secrets:** `REVENUECAT_SECRET_KEY`
**New Cloud Functions:** `revenuecat_webhook`, `chatWithPlant`, `compareScans`, `generateSeasonalCalendar`, `adminInsightNarrative`

---

### v0.7 — CNN Deployment + Cost Elimination

**Goal:** Replace Claude Vision disease classification with self-hosted CNN. Per-scan cost → ~$0.

> **Parallel track:** CNN training begins at v0.4 in the background. Steps: acquire PlantVillage dataset (54K images, 38 disease classes, 14 crop species), train TensorFlow model, optimise to TFLite, validate accuracy, deploy to Cloud Run. v0.7 is the deployment target — not when training starts. Timeline is research-dependent.

| Feature | Detail |
|---|---|
| PlantVillage CNN on Cloud Run | Cloud Run service wrapping TFLite model. Input: base64 image. Output: `{ diseaseClass, confidence }`. Called by Cloud Function instead of full Claude Vision for in-scope crop species. |
| Graceful fallback | If CNN confidence < 0.60 or species outside PlantVillage scope → fall back to full Claude Vision call. Kindwise continues doing species ID for all species. |
| Reduced Claude usage | CNN-in-scope scans: Claude receives CNN classification result as context. Generates narrative only — ~60% fewer input tokens. |
| Offline mode | Hive cache extended: all diagnoses and plant profiles mirrored to local Hive boxes on fetch. Full offline read access. Write queue for notes/profile changes made offline, synced on reconnect. |

**New infrastructure:** Cloud Run service (CNN), TFLite model artefacts
**Kindwise:** Remains in stack for species ID. KINDWISE_API_KEY not removed.

---

### v1.0 — Launch

**Goal:** App Store + Play Store submission. Onboarding. Final polish.

| Feature | Detail |
|---|---|
| Onboarding flow | 3 screens: (1) Welcome + value prop, (2) first scan walkthrough — no permissions yet, (3) feature highlights. Location permission deferred to first weather panel tap (not onboarding). Avoids App Store review flag for eager permission requests. |
| iOS full support | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocationWhenInUseUsageDescription` in `Info.plist`. APNs cert confirmed. App Store screenshots and metadata. |
| Play Store submission | Android App Bundle. Store listing, privacy policy URL, content rating questionnaire. |

---

## 6. Updated Data Model

### Updated: DiagnosisResult

```dart
class DiagnosisResult {
  // existing fields unchanged ...
  final String? plantProfileId;         // null if not attached to a profile
  final WeatherSnapshot? weatherAtScan; // null for scans before v0.4
  final String? usHardinessZone;        // "6b", "10a", etc. — null before v0.4
}
```

### New: WeatherSnapshot

```dart
class WeatherSnapshot {
  final double tempC;
  final int humidityPct;
  final int uvIndex;
  final int rainChancePct;
  final String condition;  // "sunny" | "cloudy" | "rainy" | "stormy"
  final double windKph;
}
```

### New: PlantProfile

```dart
class PlantProfile {
  final String id;
  final String name;                    // user-given name, e.g. "My balcony basil"
  final String location;                // "indoor" | "outdoor"
  final String? primarySpecies;         // common name from first attached scan
  final String? primaryScientificName;  // scientific name — used as species cache key + seasonal calendar key
  final String? hardinessZone;          // copied from users/{uid}.hardinessZone
  final List<String> diagnosisIds;
  final int wateringIntervalDays;
  final DateTime? lastWateredAt;
  final List<PlantNote> notes;
  final DateTime createdAt;
}

class PlantNote {
  final String text;
  final DateTime createdAt;
}
```

### Updated: users/{uid} document fields

```
monthlyScanCount: integer      // resets inline when scanCountMonth changes
scanCountMonth: string         // "YYYY-MM"
isPremium: boolean             // written by revenuecat_webhook
premiumExpiresAt: timestamp?   // for display only; isPremium is source of truth
hardinessZone: string?         // set on first weather fetch with location
lastSeenAt: timestamp          // updated on app open — for DAU tracking in admin dashboard
fcmToken: string?              // FCM device token for push alerts
```

### New Firestore Collections

```
speciesCache/{scientificName}              — global, Cloud Function write only
weatherCache/{lat2dp_lng2dp}              — global, Cloud Function write only
seasonalCalendars/{scientificName}_{zone} — global, Cloud Function write only (v0.6)
users/{uid}/plants/{plantId}              — per-user plant profiles (v0.5)
```

---

## 7. Updated Tech Stack

| Layer | v0.2 | v1.0 |
|---|---|---|
| State | setState | Riverpod |
| Auth | Anonymous only | Google + Apple + Email + Guest |
| Species ID | plant.id (Kindwise) | plant.id (Kindwise) — permanent |
| Disease detection | Claude Vision | Claude Vision → CNN fallback pattern (v0.7) |
| Care info | Claude (per scan) | Claude (cached per species after first scan) |
| Weather | — | OpenWeatherMap API (Cloud Function owned) |
| Location | — | geolocator |
| Notifications | — | flutter_local_notifications + FCM |
| Local storage | — | Hive (v0.5 for notif IDs, v0.7 full offline) |
| Subscriptions | — | RevenueCat |
| Admin dashboard | — | Retool → custom if outgrown |
| CNN hosting | — | Cloud Run (v0.7, parallel track) |

---

## 8. Cost Model at Scale

| Stage | Per-scan cost | Notes |
|---|---|---|
| v0.2 (now) | ~$0.06–0.12 | Kindwise + full Claude call |
| v0.3 | ~$0.04–0.08 | Species cache cuts ~35–40% of Claude tokens |
| v0.6 | ~$0.04–0.08 | Revenue from premium subs begins offsetting |
| v0.7 | ~$0.01–0.02 | CNN for in-scope crops. Claude narrative only. Kindwise species ID remains. |

**Break-even (v0.6):** ~60 premium subscribers at $3.99/month covers ~1,000 free users at 15 scans/month.

---

## 9. Post-Launch Candidates (Not in Scope)

- Home screen widget (Android/iOS native — complex, low ROI pre-launch)
- Multi-angle scan (complicates UX before core is validated)
- Custom admin dashboard (replace Retool if outgrown)
- Facebook/phone auth (add if market requires)
- Plant barcode/QR scan
