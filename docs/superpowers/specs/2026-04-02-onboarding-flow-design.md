# PlantDoctor — Onboarding Flow Design

**Date:** 2026-04-02
**Version target:** v1.0
**Status:** Approved, ready for implementation

---

## Goal

Show a 3-screen onboarding sequence on first launch only. Explain the app's value, then request location and notification permissions in context. Zero friction — no auth step, no required actions beyond screen 1.

---

## Screens

### Screen 1 — Welcome (no skip)

- **Hero:** Full-width gradient (`#1b4332 → #2d6a4f → #40916c`), large 🌿 emoji centred
- **Title:** `PlantDoctor`
- **Body:** "Point your camera at any plant. Get species ID, health diagnosis, and care advice instantly."
- **CTA:** "Get Started →" (advances to screen 2)
- **Skip:** None — screen 1 is a single tap

### Screen 2 — Location Permission (skippable)

- **Hero:** Blue gradient (`#0d2137 → #1a3a5c → #1e4976`), 🌦️ emoji
- **Title:** `Weather-Smart Care`
- **Body:** "PlantDoctor uses your location to factor in local weather — frost alerts, rain-skip watering, and humidity advice."
- **CTA:** "Allow Location" → triggers OS location permission dialog → advances
- **Skip:** "Skip for now" → advances without requesting permission

### Screen 3 — Notifications Permission (skippable)

- **Hero:** Amber gradient (`#2d1b00 → #4a2f00 → #6b4400`), 🔔 emoji
- **Title:** `Never Miss a Watering`
- **Body:** "Get watering reminders, frost alerts, and rescan nudges — timed to your plant's actual needs."
- **CTA:** "Allow Notifications" → triggers OS notification permission dialog → advances
- **Skip:** "Skip for now" → completes onboarding, enters app

---

## First-Launch Detection

Box: `'offline_cache'` (same box used by `LocalStoreService`)
Key: `'hasSeenOnboarding'` → bool

- `_AppRouterState` opens the box async in `initState` and reads the key into a `bool? _hasSeenOnboarding` field (starts null = unknown).
- While null, the router shows the same `CircularProgressIndicator` spinner already used for auth loading.
- Once resolved: if `false` (or missing) → show `OnboardingScreen`. If `true` → show `HomeScreen` as today.
- On onboarding completion (screen 3 primary or skip): write `true` to the box, then `Navigator.pushReplacement(HomeScreen)`.
- Anonymous auth still happens silently in `initState` as today — onboarding is purely a routing layer on top.

---

## Architecture

### New file: `lib/screens/onboarding_screen.dart`

```
OnboardingScreen (StatefulWidget)
├── PageController
├── _OnboardingPage × 3  (reusable widget)
│   ├── heroEmoji: String
│   ├── heroGradient: LinearGradient
│   ├── title: String
│   ├── body: String
│   ├── primaryLabel: String
│   ├── onPrimary: Future<void> Function()   ← async, handles permission + advance
│   └── onSkip: VoidCallback?               ← null on screen 1 = no skip link shown
└── _handleComplete()  → Hive write + Navigator.pushReplacement(HomeScreen)
```

`_OnboardingPage` is a private widget inside the same file — not exported.

### Modified: `lib/main.dart` (`_AppRouterState`)

Add `bool? _hasSeenOnboarding` state (null = not yet read). In `initState`, open `'offline_cache'` box async and read `'hasSeenOnboarding'` key, then call `setState`. Router condition:

```
_hasSeenOnboarding == null || auth loading  → CircularProgressIndicator
user != null && _hasSeenOnboarding == true  → HomeScreen
user != null && _hasSeenOnboarding == false → OnboardingScreen
user == null (auth error)                   → error message (as today)
```

---

## Permission Handling

| Screen | Permission | Package |
|--------|-----------|---------|
| Screen 2 | Location (`LocationPermission`) | `geolocator` — already in pubspec |
| Screen 3 | Notifications (`Permission.notification`) | `permission_handler` — already pulled in by `flutter_local_notifications` |

Both requests happen only when the user taps the primary CTA. Tapping "Skip for now" skips the request entirely. If the user has previously denied a permission (e.g. re-installs), the OS dialog behaviour is unchanged — the app does not re-prompt or redirect to settings.

---

## Dependencies

No new packages. All required packages already in `pubspec.yaml`:
- `hive_flutter` — first-launch flag storage
- `geolocator` — location permission request
- `permission_handler` — notification permission request

---

## Files Changed

| Action | File |
|--------|------|
| Create | `lib/screens/onboarding_screen.dart` |
| Modify | `lib/main.dart` — add onboarding routing to `_AppRouterState` |

---

## Out of Scope

- No sign-in step in onboarding (existing anonymous auth + result screen banner handles this)
- No "reset onboarding" setting (not needed for v1.0)
- No iOS-specific permission strings in `Info.plist` — handled separately under iOS support track
- No animation between screens beyond default `PageView` swipe
