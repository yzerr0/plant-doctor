# PlantDoctor — Design Spec
**Date:** 2026-03-24
**Type:** Hackathon demo
**Goal:** Working demo — shippable, impressive, fast to build

---

## What It Does

User photographs a plant (healthy or sick). The app returns:
- Plant species identification + confidence score
- Rich species info (origin, care tips, fun fact)
- Health diagnosis (what's wrong, severity, cause)
- Step-by-step treatment plan
- Prevention tips

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (Dart) |
| Auth | Firebase Anonymous Auth |
| Database | Cloud Firestore |
| Image Storage | Firebase Storage |
| AI | Claude Vision via Firebase Cloud Function |
| State | setState |
| Routing | Navigator.push |

---

## Visual Design

**Style:** Botanical + clinical undertones
- Deep greens (`#2E7D32`) as primary, light green backgrounds (`#E8F5E9`, `#f1f8f1`)
- White cards with subtle shadows — clean, data-forward
- Severity communicated with color badges: green / yellow / orange / red
- Fun fact chip uses the green tint; toxicity cell uses red tint
- Google Fonts for polish; Lottie for loading animation

---

## Architecture

```
Android Emulator (Flutter)
  ├─ Home Screen       → Scan button + past diagnoses list
  ├─ Loading Screen    → "Analyzing..." Lottie animation
  └─ Result Screen     → Full diagnosis display

  On "Scan" tap:
  1. image_picker       → gallery pick (ImageSource.gallery for emulator)
  2. StorageService     → upload to Firebase Storage → download URL
  3. httpsCallable      → diagnosePlant(imageUrl)
  4. Cloud Function     → fetch image, call Claude Vision, return JSON
  5. DiagnosisResult.fromJson() → parse
  6. FirebaseService.saveDiagnosis() → Firestore
  7. Navigator.pushReplacement → Result Screen

Firebase project
  ├─ Anonymous Auth
  ├─ Firestore  →  users/{uid}/diagnoses/{id}
  ├─ Storage    →  diagnoses/{uid}/{timestamp}.jpg
  └─ Functions  →  diagnosePlant (secret: ANTHROPIC_API_KEY)
```

---

## Project Structure

```
lib/
├── main.dart                   # Firebase init, anonymous sign-in, runApp
├── theme.dart                  # AppTheme — colors, severityColor(), severityIcon()
├── models/
│   └── diagnosis_model.dart    # DiagnosisResult, SpeciesInfo, PlantIssue
├── services/
│   ├── storage_service.dart    # Upload image → return download URL
│   └── firebase_service.dart   # Firestore save + stream reads
├── screens/
│   ├── home_screen.dart        # Scan button + past diagnoses list
│   ├── loading_screen.dart     # "Analyzing your plant..." with Lottie
│   └── result_screen.dart      # Full diagnosis + species info display
└── widgets/
    ├── severity_badge.dart     # Colored pill: healthy / low / medium / high
    └── issue_card.dart         # Expandable card per issue

functions/
├── index.js                    # Cloud Function: diagnosePlant
└── package.json
```

---

## Data Model

### `DiagnosisResult`
| Field | Type | Notes |
|---|---|---|
| id | String | timestamp millis |
| imageUrl | String | Firebase Storage download URL |
| plantSpecies | String | "Common name (Scientific name)" |
| confidence | double | 0.0–1.0 |
| overallSeverity | String | healthy / low / medium / high |
| summary | String | 2–3 sentence plain English |
| followUpIn | int | days until next check |
| speciesInfo | SpeciesInfo | care data |
| issues | List\<PlantIssue\> | empty if healthy |
| createdAt | DateTime | Persisted as ISO 8601 string; `fromFirestore` must parse it back (not `DateTime.now()`) |

### `SpeciesInfo`
origin, lifespan, difficulty, light, water, humidity, temperature, toxicity, funFact

### `PlantIssue`
name, severity, cause, symptoms[], treatment[], preventionTips[]

### Firestore path
`users/{uid}/diagnoses/{id}` — ordered by `createdAt` descending, limit 20

---

## Cloud Function (`diagnosePlant`)

- Runtime: Node 20, timeout 60s
- Secret: `ANTHROPIC_API_KEY` via Firebase Secret Manager
- Input: `{ imageUrl: string }`
- Calls `claude-sonnet-4-20250514` with vision — image URL + structured JSON prompt
- Strips accidental markdown fences before `JSON.parse()`
- Returns `{ success: true, diagnosis: {...} }`
- Throws on `diagnosis.error` (no plant detected)
- Use `minInstances: 1` in the `onCall` config to eliminate cold start on demo day:
  ```javascript
  exports.diagnosePlant = onCall(
    { secrets: [anthropicKey], timeoutSeconds: 60, minInstances: 1 },
    async (request) => { ... }
  );
  ```

---

## Screens

### Home Screen
- AppBar: "🌿 PlantDoctor" on green background
- Large "📷 Scan a Plant" FAB-style button (centered, rounded, green)
- "Recent Diagnoses" section label
- List of `DiagnosisResult` cards: thumbnail emoji placeholder → plant name → date + subtitle → severity badge chip
- Empty state: "No plants scanned yet" centered message
- Tapping a card navigates to `ResultScreen(diagnosis: item)`

### Loading Screen
- Full-screen dark green or white background
- Lottie plant/leaf animation (centered)
- "Analyzing your plant..." text below
- Non-dismissable; on **success**: home uses `Navigator.pushReplacement` to swap loading for Result Screen; on **error**: home calls `Navigator.pop` to return, then shows a SnackBar

### Result Screen (`SingleChildScrollView`, top to bottom)
1. Hero image — full-width `CachedNetworkImage` from `imageUrl`
2. Species header — name (bold), scientific name (italic), confidence % chip
3. Severity banner — full-width colored bar with `severityIcon` + label
4. Summary — plain text paragraph
5. Care grid — 3-column, 2-row grid (6 cells: light, water, humidity, temp, difficulty, toxicity)
6. Fun fact chip — green tint, leaf icon + `funFact` text
7. Issues section — one `IssueCard` per issue (expandable: shows cause, symptoms, treatment, prevention)
8. Follow-up footer — "🗓 Check again in X days"

### Widgets
- `SeverityBadge(severity)` — colored pill using `AppTheme.severityColor()`
- `IssueCard(issue)` — `ExpansionTile` with severity-colored left border; collapsed shows name + badge; expanded shows cause, symptoms list, treatment steps, prevention tips

---

## Build Order (Infrastructure → UI)

1. **Environment setup** — Flutter SDK, Firebase CLI, Node 20
2. **Firebase project** — run the following, then enable services in Firebase Console:
   ```bash
   npm install -g firebase-tools
   firebase login
   firebase init   # select: Functions, Firestore, Storage
   ```
   In Firebase Console: Authentication → Sign-in methods → enable **Anonymous**; confirm Firestore and Storage are provisioned; set rules open for hackathon (see CLAUDE.md)
3. **Cloud Function** — write `index.js`, set `ANTHROPIC_API_KEY` secret, deploy, smoke test
4. **Flutter project init** — `flutter create`, `flutterfire configure`, `pubspec.yaml` dependencies
5. **Models + Services** — `diagnosis_model.dart`, `storage_service.dart`, `firebase_service.dart`
6. **Theme + Widgets** — `theme.dart`, `severity_badge.dart`, `issue_card.dart`
7. **Home Screen** — scan flow + journal list
8. **Loading Screen** — Lottie animation
9. **Result Screen** — full diagnosis display

---

## Known Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `callable.call()` unreliable on Android emulator | If emulator can't reach the deployed function, run demo on a physical Android device instead — this is the safest fallback |
| Claude returns JSON in markdown fences | Already stripped in Cloud Function |
| Cold start slow on demo day | `minInstances: 1` in `onCall` config |
| Firestore permission denied | Rules set to `allow read, write: if true` |
| iOS camera requires Info.plist entries | Add `NSCameraUsageDescription` + `NSPhotoLibraryUsageDescription` post-demo |

---

## Out of Scope (Do Not Build)

Onboarding, settings, notifications, social features, profile screens, custom animations beyond loading screen, iOS-specific setup (post-demo).
