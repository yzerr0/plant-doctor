# PlantDoctor v0.5 — UI Polish & Dashboard Redesign

**Date:** 2026-04-01
**Status:** Approved
**Scope:** Complete v0.5 remaining work. Skip v0.6 (monetisation). Android-first.

---

## 1. Overview

The v0.5 polish pass delivers three things:
1. **Dashboard redesign** — new home screen layout replacing the scan button hero with a greeting + weather hero, surfacing watering reminders, and moving scan to a bottom nav FAB.
2. **Dark mode** — `ThemeMode.system` with a Deep Space palette.
3. **Real scan thumbnails** — diagnosis cards show actual plant photos instead of a generic leaf icon.

These changes bring PlantDoctor in line with top-rated plant apps (Planta, Greg, PictureThis) in terms of first-impression quality.

---

## 2. Decisions

| Decision | Choice |
|---|---|
| Navigation | Bottom nav: Home / Scan FAB (centre) / My Plants |
| Home hero | Greeting + weather unified in expanded green header |
| Scan button | Removed from body — lives in bottom nav FAB only |
| Watering banner | Dynamic urgency colours surfaced on home screen |
| Search | Icon in RECENT SCANS header row (no persistent search bar) |
| Diagnosis card thumbnails | `CachedNetworkImage` from `diagnosis.imageUrl` |
| Dark mode palette | Deep Space — `#1a1a2e` bg, `#252540` cards, `#1e2d20` accents |
| Weather hero tint | Shifts with condition (green/default, blue/rain, red/frost-heat) |
| Revenue (v0.6) | Deferred — not in this spec |
| iOS-specific work | Deferred — Android focus |

---

## 3. Navigation

Replace the current single-screen `HomeScreen` + toolbar icon pattern with a `ScaffoldWithNavBar` wrapper:

```
BottomNavigationBar (3 items):
  [0] Home     — icon: home_outlined / home (selected)
  [1] Scan     — floating action style centre button (camera_alt)
  [2] My Plants — icon: yard_outlined / yard (selected)
```

- Scan tab does not navigate to a screen — it triggers the scan flow directly (same `_scanPlant` logic as today).
- Active tab indicator: `#2d7a4f` (light) / `#81c784` (dark).
- Bottom nav background: `white` (light) / `#1a1a2e` (dark).
- The toolbar `yard_outlined` icon is removed.
- Sign In button stays in top-right `AppBar.actions`.

---

## 4. Home Screen Redesign

### 4.1 AppBar
- Title: `🌿 PlantDoctor` (unchanged)
- Actions: empty — Sign In moves into the hero greeting row
- No My Plants icon (moved to bottom nav)

### 4.2 Green Hero Header
Replaces the scan button. Extends the `AppBar` green into a hero section:

```
AppBar (green, no elevation)
  └─ Flexible bottom / SliverAppBar expanded area:
       Greeting row: "Good morning" / "Youssef 👋" (left) + Sign In pill (right, if anonymous)
       Weather card: condition icon + temp (large) + HUM / UV / RAIN stats row
         └─ background: rgba(white, 0.10) frosted panel
         └─ hero tint shifts: default green | rainy → blue tint | frost/heat → red-orange tint
```

Greeting uses:
- Signed-in: `"Good morning/afternoon/evening, {displayName.split(' ')[0]}"`.
- Anonymous: `"Good morning 👋"` (no name).

### 4.3 Watering Reminder Banner
Sits between the hero and the scan list. Dynamic colour based on urgency. Derived from `wateringPrefsProvider` across all species groups:

| State | Condition | Colour | CTA |
|---|---|---|---|
| Overdue | `lastWateredAt + interval < now` | Red `#2d1515` / border `#ef5350` | "Water Now →" |
| Due today | diff == 0 days | Orange `#2d2010` / border `#ff9800` | "Mark Watered →" |
| Due soon | diff 1–3 days | Blue `#1a2535` / border `#42a5f5` | Informational |
| All good | diff 4+ days | Green `#1e2d20` / border `#66bb6a` | Informational |
| Rain skip | rain forecast >50% | Purple `#2d1a2d` / border `#ab47bc` | Reminder paused |
| Frost alert | `weatherProvider` current temp ≤ 2°C | Red `#2d1515` / border `#ff5252` | "Bring plants in" |

- Shows the single most urgent plant. If none tracked yet, hidden entirely.
- Tapping navigates to `SpeciesHistoryScreen` for that plant.

### 4.4 Recent Scans Section
```
Row: "RECENT SCANS"  [🔍 icon]
ListView of _DiagnosisCard (updated)
```

Search icon opens a search overlay (same logic as old search bar — filter by species name and severity). Not a persistent bar.

### 4.5 Diagnosis Card — Real Thumbnails
Replace the `Icons.local_florist` placeholder with:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: CachedNetworkImage(
    imageUrl: diagnosis.imageUrl,
    width: 48, height: 48,
    fit: BoxFit.cover,
    placeholder: (_, _) => Container(color: AppTheme.lightGreen,
      child: const Icon(Icons.local_florist, color: AppTheme.green)),
    errorWidget: (_, _, _) => Container(color: AppTheme.lightGreen,
      child: const Icon(Icons.local_florist, color: AppTheme.green)),
  ),
)
```

---

## 5. Dark Mode

### 5.1 Palette — Deep Space

| Token | Light | Dark |
|---|---|---|
| `background` | `#f4f6f4` | `#1a1a2e` |
| `surface` (cards) | `#ffffff` | `#252540` |
| `surfaceVariant` (accent bg) | `#e8f5e9` | `#1e2d20` |
| `primary` | `#2d7a4f` | `#2d7a4f` |
| `onPrimary` | `#ffffff` | `#ffffff` |
| `primaryContainer` | `#e8f5e9` | `#1e2d20` |
| `onPrimaryContainer` | `#1b5e20` | `#81c784` |
| `onSurface` | `#111111` | `#e8e8ff` |
| `onSurfaceVariant` | `#555555` | `#9090c0` |
| `outline` | `#e0e0e0` | `#252540` |

### 5.2 Implementation
- `ThemeMode.system` in `MaterialApp`.
- `AppTheme` gains a `darkTheme` `ThemeData` using the tokens above.
- `AppTheme.severityColor()` already returns absolute colours — keep as-is (they work on both themes).
- Watering banner colours are hardcoded per state (not theme-derived) — they carry semantic meaning, not surface role.
- Weather hero tint: a `_heroGradient(WeatherData? weather)` helper returns the appropriate `LinearGradient` based on `weather.current.condition`.

---

## 6. Files Affected

| Action | File |
|---|---|
| Modify | `lib/theme.dart` — add `darkTheme`, update `AppTheme` tokens |
| Modify | `lib/main.dart` — add `darkTheme:`, `themeMode: ThemeMode.system` |
| Rewrite | `lib/screens/home_screen.dart` — new layout, bottom nav, hero, watering banner, thumbnail cards |
| Delete | `lib/widgets/weather_panel.dart` — logic absorbed into home hero |
| Modify | `test/screens/home_screen_test.dart` — update for new widget tree |

---

## 7. Out of Scope

- Revenue / paywall (v0.6)
- iOS APNs / App Store metadata
- CNN disease detection (v0.7)
- Offline mode (v0.7)
- Onboarding flow (v1.0)
