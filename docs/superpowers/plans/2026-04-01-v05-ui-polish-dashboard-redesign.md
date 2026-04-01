# v0.5 UI Polish — Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current home screen (scan button hero + flat weather panel) with a green expandable hero, persistent bottom nav with centre scan FAB, dynamic watering urgency banner, Deep Space dark theme, and real image thumbnails on diagnosis cards.

**Architecture:** `HomeScreen` becomes a shell Scaffold with a `FloatingActionButton.centerDocked` + `BottomAppBar` for navigation; `_HomeTab` is a `CustomScrollView` with a pinned `SliverAppBar` green hero; `MyPlantsScreen` renders inside an `IndexedStack` slot alongside `_HomeTab`. `AppTheme.dark()` is replaced with explicit Deep Space `ColorScheme`. An `urgentWateringProvider` consolidates watering + weather state into a single banner model.

**Tech Stack:** Flutter, Riverpod, `cached_network_image: ^3.3.0` (already in pubspec), `google_fonts`

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/theme.dart` | Deep Space dark palette + hero gradient tokens |
| Modify | `lib/providers/species_provider.dart` | Add `WateringBannerData` model + `urgentWateringProvider` |
| Rewrite | `lib/screens/home_screen.dart` | Shell + _HomeTab + _GreenHero + _WateringBanner + updated _DiagnosisCard |
| Delete | `lib/widgets/weather_panel.dart` | Logic absorbed into _GreenHero |
| Modify | `test/screens/home_screen_test.dart` | Update tests for new widget tree |

> `lib/main.dart` already has `darkTheme: AppTheme.dark()` + `themeMode: ThemeMode.system` — **no changes needed**.

---

## Task 1: Deep Space dark theme

**Files:**
- Modify: `lib/theme.dart`
- Test: `test/theme_test.dart` (create)

- [ ] **Step 1: Write the failing tests**

Create `test/theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/theme.dart';

void main() {
  group('AppTheme.dark()', () {
    test('scaffold background is Deep Space #1a1a2e', () {
      expect(AppTheme.dark().scaffoldBackgroundColor,
          const Color(0xFF1A1A2E));
    });

    test('card surface is #252540', () {
      expect(AppTheme.dark().colorScheme.surface,
          const Color(0xFF252540));
    });

    test('primaryContainer is #1e2d20', () {
      expect(AppTheme.dark().colorScheme.primaryContainer,
          const Color(0xFF1E2D20));
    });

    test('onSurface is #e8e8ff', () {
      expect(AppTheme.dark().colorScheme.onSurface,
          const Color(0xFFE8E8FF));
    });
  });

  test('AppTheme.green is #2d7a4f', () {
    expect(AppTheme.green, const Color(0xFF2D7A4F));
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```
flutter test test/theme_test.dart
```

Expected: FAIL — `AppTheme.green` is currently `0xFF2E7D32` and dark theme uses M3 seed generation.

- [ ] **Step 3: Update lib/theme.dart**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand greens
  static const green = Color(0xFF2D7A4F);
  static const lightGreen = Color(0xFFE8F5E9);
  static const background = Color(0xFFF4F6F4);

  // Hero gradient stop colours (used in home_screen.dart)
  static const heroGreenStart = Color(0xFF1E5C38);
  static const heroGreenEnd   = Color(0xFF3A9160);
  static const heroBlueEnd    = Color(0xFF1A2535);
  static const heroRedEnd     = Color(0xFF2D1A0A);

  static ThemeData light() => ThemeData(
    colorSchemeSeed: green,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.interTextTheme(),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF1A1A2E),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    colorScheme: const ColorScheme.dark(
      background:           Color(0xFF1A1A2E),
      surface:              Color(0xFF252540),
      surfaceVariant:       Color(0xFF1E2D20),
      primary:              Color(0xFF2D7A4F),
      onPrimary:            Colors.white,
      primaryContainer:     Color(0xFF1E2D20),
      onPrimaryContainer:   Color(0xFF81C784),
      onSurface:            Color(0xFFE8E8FF),
      onSurfaceVariant:     Color(0xFF9090C0),
      outline:              Color(0xFF252540),
    ),
  );

  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'healthy': return const Color(0xFF4CAF50);
      case 'low':     return const Color(0xFFFFEB3B);
      case 'medium':  return const Color(0xFFFF9800);
      case 'high':    return const Color(0xFFF44336);
      default:        return const Color(0xFF9E9E9E);
    }
  }

  static IconData severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'healthy': return Icons.check_circle;
      case 'low':     return Icons.info;
      case 'medium':  return Icons.warning;
      case 'high':    return Icons.dangerous;
      default:        return Icons.help;
    }
  }
}
```

- [ ] **Step 4: Run tests**

```
flutter test test/theme_test.dart
```

Expected: all 5 tests PASS.

- [ ] **Step 5: Run full suite to catch any green-colour breakage**

```
flutter test
```

Expected: all tests PASS (colour change from `#2E7D32` → `#2D7A4F` is minor; no logic depends on the exact hex).

- [ ] **Step 6: Commit**

```bash
git add lib/theme.dart test/theme_test.dart
git commit -m "feat: Deep Space dark theme palette + update primary green to #2d7a4f"
```

---

## Task 2: Watering urgency provider

**Files:**
- Modify: `lib/providers/species_provider.dart`
- Test: `test/providers/species_provider_test.dart` (already exists — add urgency tests)

- [ ] **Step 1: Write the failing tests**

Append to `test/providers/species_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/watering_prefs.dart';
import 'package:plant_doctor/providers/species_provider.dart';

// Pure date-math helpers used by urgentWateringProvider
void main() {
  // (existing tests above)

  group('daysUntilWatering', () {
    test('returns negative when overdue', () {
      final last = DateTime.now().subtract(const Duration(days: 10));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, isNegative);
    });

    test('returns 0 when due today', () {
      final last = DateTime.now().subtract(const Duration(days: 7));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, 0);
    });

    test('returns positive when upcoming', () {
      final last = DateTime.now().subtract(const Duration(days: 3));
      final prefs = WateringPrefs(intervalDays: 7, lastWateredAt: last);
      final days = daysUntilWatering(prefs);
      expect(days, 4);
    });

    test('returns null when lastWateredAt is null', () {
      final prefs = WateringPrefs(intervalDays: 7);
      expect(daysUntilWatering(prefs), isNull);
    });
  });

  group('WateringBannerKind priority', () {
    test('overdue has lower index than dueToday', () {
      expect(WateringBannerKind.overdue.index,
          lessThan(WateringBannerKind.dueToday.index));
    });

    test('dueToday has lower index than dueSoon', () {
      expect(WateringBannerKind.dueToday.index,
          lessThan(WateringBannerKind.dueSoon.index));
    });
  });
}
```

- [ ] **Step 2: Run tests to confirm they fail**

```
flutter test test/providers/species_provider_test.dart
```

Expected: FAIL — `daysUntilWatering` and `WateringBannerKind` not yet defined.

- [ ] **Step 3: Add to lib/providers/species_provider.dart**

Add the following after the existing `wateringPrefsProvider` (append to file):

```dart
// ─── Watering banner ─────────────────────────────────────────────────────────

enum WateringBannerKind {
  overdue,   // 0 — most urgent
  dueToday,  // 1
  dueSoon,   // 2
  rainSkip,  // 3
  allGood,   // 4
  frost,     // 5 — weather override
}

class WateringBannerData {
  final WateringBannerKind kind;
  final String plantName;
  final String scientificName;
  final int daysUntil; // negative = overdue, 0 = today, positive = future

  const WateringBannerData({
    required this.kind,
    required this.plantName,
    required this.scientificName,
    required this.daysUntil,
  });
}

/// Returns days until next watering (negative if overdue, null if never set).
int? daysUntilWatering(WateringPrefs prefs) {
  if (prefs.lastWateredAt == null) return null;
  final nextWater =
      prefs.lastWateredAt!.add(Duration(days: prefs.intervalDays));
  final today = DateTime.now();
  final todayMidnight = DateTime(today.year, today.month, today.day);
  final nextMidnight = DateTime(
      nextWater.year, nextWater.month, nextWater.day);
  return nextMidnight.difference(todayMidnight).inDays;
}

/// The single most urgent watering banner across all tracked species.
/// Returns null if no species have `lastWateredAt` set and no frost.
final urgentWateringProvider = Provider<WateringBannerData?>((ref) {
  final groups = ref.watch(speciesGroupsProvider);
  final weather = ref.watch(weatherProvider).valueOrNull;

  // Frost check: live temperature ≤ 2°C
  if (weather != null && weather.current.tempC <= 2.0) {
    return const WateringBannerData(
      kind: WateringBannerKind.frost,
      plantName: '',
      scientificName: '',
      daysUntil: 0,
    );
  }

  // Rain skip: next day forecast > 50%
  final hasRainForecast = weather != null &&
      weather.forecast.isNotEmpty &&
      weather.forecast.first.rainChancePct > 50;

  WateringBannerData? mostUrgent;

  for (final group in groups) {
    final prefs =
        ref.watch(wateringPrefsProvider(group.scientificName)).valueOrNull;
    if (prefs == null) continue;

    final days = daysUntilWatering(prefs);
    if (days == null) continue; // never recorded a watering

    WateringBannerKind kind;
    if (hasRainForecast) {
      kind = WateringBannerKind.rainSkip;
    } else if (days < 0) {
      kind = WateringBannerKind.overdue;
    } else if (days == 0) {
      kind = WateringBannerKind.dueToday;
    } else if (days <= 3) {
      kind = WateringBannerKind.dueSoon;
    } else {
      kind = WateringBannerKind.allGood;
    }

    final candidate = WateringBannerData(
      kind: kind,
      plantName: group.commonName,
      scientificName: group.scientificName,
      daysUntil: days,
    );

    if (mostUrgent == null ||
        candidate.kind.index < mostUrgent!.kind.index) {
      mostUrgent = candidate;
    }
  }

  return mostUrgent;
});
```

Also add the `weatherProvider` import at the top of `lib/providers/species_provider.dart`:

```dart
import 'weather_provider.dart';
```

- [ ] **Step 4: Run tests**

```
flutter test test/providers/species_provider_test.dart
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/providers/species_provider.dart test/providers/species_provider_test.dart
git commit -m "feat: add WateringBannerData model and urgentWateringProvider"
```

---

## Task 3: Rewrite HomeScreen

**Files:**
- Rewrite: `lib/screens/home_screen.dart`
- Modify: `test/screens/home_screen_test.dart`

- [ ] **Step 1: Update the test first**

Replace `test/screens/home_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders without error', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen shows PlantDoctor title', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('🌿 PlantDoctor'), findsOneWidget);
  });

  testWidgets('HomeScreen shows bottom navigation bar', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(BottomAppBar), findsOneWidget);
  });

  testWidgets('HomeScreen shows scan FAB', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests to confirm current state**

```
flutter test test/screens/home_screen_test.dart
```

Expected: first test passes; new tests fail (no BottomAppBar/FAB yet).

- [ ] **Step 3: Rewrite lib/screens/home_screen.dart**

```dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/diagnosis_model.dart';
import '../models/weather_model.dart';
import '../providers/auth_provider.dart';
import '../providers/diagnoses_provider.dart';
import '../providers/species_provider.dart';
import '../providers/weather_provider.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/reminder_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/severity_badge.dart';
import 'auth_screen.dart';
import 'loading_screen.dart';
import 'plant_profile_screen.dart';
import 'plant_profiles_list_screen.dart';
import 'result_screen.dart';

// ─── Shell ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedIndex = 0; // 0 = Home, 1 = My Plants

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: const [_HomeTab(), MyPlantsScreen()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _scanPlant(context, ref),
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        tooltip: 'Scan a Plant',
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomNavBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }

  Future<void> _scanPlant(BuildContext context, WidgetRef ref) async {
    final photo = await _pickImage(context);
    if (photo == null) return;
    if (!context.mounted) return;

    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const LoadingScreen()));

    try {
      final imageUrl = await StorageService.uploadImage(File(photo.path));

      Position? position;
      if (await LocationService.hasPermission()) {
        position = await LocationService.getCurrentPosition();
      }

      final callable =
          FirebaseFunctions.instance.httpsCallable('diagnosePlant');
      final response = await callable.call({
        'imageUrl': imageUrl,
        if (position != null) ...{
          'lat': position.latitude,
          'lng': position.longitude,
        },
      });

      final rawDiagnosis =
          Map<String, dynamic>.from(response.data['diagnosis']);
      final diagnosis = DiagnosisResult.fromJson(
          DateTime.now().millisecondsSinceEpoch.toString(),
          imageUrl,
          rawDiagnosis);

      await FirebaseService.saveDiagnosis(diagnosis);

      await ReminderService.scheduleRescan(
        diagnosisId: diagnosis.id,
        plantSpecies: diagnosis.plantSpecies,
        scanDate: diagnosis.createdAt,
        followUpDays: diagnosis.followUpIn,
      );

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => ResultScreen(diagnosis: diagnosis)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Analysis failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<XFile?> _pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppTheme.green),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppTheme.green),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return null;
    return ImagePicker().pickImage(source: source, imageQuality: 85);
  }
}

// ─── Bottom nav bar ───────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  const _BottomNavBar(
      {required this.selectedIndex, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = cs.primary == AppTheme.green
        ? AppTheme.green
        : const Color(0xFF81C784); // dark mode
    final inactiveColor = cs.onSurfaceVariant;

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: selectedIndex == 0 ? Icons.home : Icons.home_outlined,
            label: 'Home',
            active: selectedIndex == 0,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTabSelected(0),
          ),
          const SizedBox(width: 56), // space for FAB notch
          _NavItem(
            icon: selectedIndex == 1 ? Icons.yard : Icons.yard_outlined,
            label: 'My Plants',
            active: selectedIndex == 1,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => onTabSelected(1),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: active ? activeColor : inactiveColor, size: 22),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: active
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: active ? activeColor : inactiveColor)),
            ],
          ),
        ),
      );
}

// ─── Home tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  String _searchQuery = '';
  String _severityFilter = 'all';

  void _showSearchFilter() {
    final tempQuery = _searchQuery;
    final tempFilter = _severityFilter;
    String query = tempQuery;
    String filter = tempFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                autofocus: true,
                controller: TextEditingController(text: query),
                decoration: const InputDecoration(
                  hintText: 'Search plants...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setModal(() => query = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      ['all', 'healthy', 'low', 'medium', 'high'].map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(f == 'all'
                            ? 'All'
                            : f[0].toUpperCase() + f.substring(1)),
                        selected: filter == f,
                        onSelected: (_) => setModal(() => filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.green,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      _searchQuery = query;
                      _severityFilter = filter;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncDiagnoses = ref.watch(diagnosesProvider);
    final allDiagnoses = asyncDiagnoses.valueOrNull ?? [];

    final filtered = allDiagnoses.where((d) {
      final matchesSearch = _searchQuery.isEmpty ||
          d.plantSpecies
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      final matchesSeverity = _severityFilter == 'all' ||
          d.overallSeverity.toLowerCase() == _severityFilter;
      return matchesSearch && matchesSeverity;
    }).toList();

    final hasFilter =
        _searchQuery.isNotEmpty || _severityFilter != 'all';

    return CustomScrollView(
      slivers: [
        // ── Green hero app bar ──────────────────────────────────────
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppTheme.green,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('🌿 PlantDoctor',
              style: TextStyle(
                  fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          actions: const [], // Sign In is inside hero
          flexibleSpace: FlexibleSpaceBar(
            background: _GreenHero(),
            collapseMode: CollapseMode.pin,
          ),
          // Rounded white strip creates "card overlapping hero" effect
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(20),
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
            ),
          ),
        ),

        // ── Watering banner + section header ───────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                const _WateringBanner(),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('RECENT SCANS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                            letterSpacing: 1.2)),
                    GestureDetector(
                      onTap: _showSearchFilter,
                      child: Icon(Icons.search,
                          size: 20,
                          color: hasFilter
                              ? AppTheme.green
                              : Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Scan list ───────────────────────────────────────────────
        asyncDiagnoses.when(
          data: (_) => filtered.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      hasFilter
                          ? 'No results match your filter'
                          : 'No plants scanned yet',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 15),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(filtered[i].id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white, size: 24),
                          ),
                          confirmDismiss: (_) async {
                            try {
                              await FirebaseService.deleteDiagnosis(
                                  filtered[i].id);
                              await ReminderService.cancelRescan(
                                  filtered[i].id);
                              return true;
                            } catch (_) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Delete failed. Please try again.')),
                                );
                              }
                              return false;
                            }
                          },
                          child: _DiagnosisCard(
                            diagnosis: filtered[i],
                            onTap: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) => ResultScreen(
                                      diagnosis: filtered[i])),
                            ),
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
          loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator())),
          error: (_, _) => const SliverFillRemaining(
              child: Center(
                  child: Text('Error loading diagnoses',
                      style: TextStyle(color: Colors.grey)))),
        ),
      ],
    );
  }
}

// ─── Green hero (greeting + weather) ─────────────────────────────────────────

class _GreenHero extends ConsumerWidget {
  _GreenHero();

  LinearGradient _heroGradient(WeatherData? weather) {
    if (weather != null && weather.current.tempC <= 2.0) {
      // Frost / extreme cold → red-orange tint
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.heroGreenStart, AppTheme.heroRedEnd],
      );
    }
    if (weather != null &&
        (weather.current.condition == 'rainy' ||
            weather.current.condition == 'stormy')) {
      // Rain → blue tint
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppTheme.heroGreenStart, AppTheme.heroBlueEnd],
      );
    }
    // Default green
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppTheme.heroGreenStart, AppTheme.heroGreenEnd],
    );
  }

  String _conditionEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':   return '☀️';
      case 'cloudy':  return '⛅';
      case 'rainy':   return '🌧️';
      case 'stormy':  return '⛈️';
      default:        return '🌤️';
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user?.isAnonymous ?? true;
    final firstName = !isAnonymous
        ? (user?.displayName?.split(' ').firstOrNull ?? '')
        : '';
    final weather = ref.watch(weatherProvider).valueOrNull;

    return Container(
      decoration: BoxDecoration(gradient: _heroGradient(weather)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Greeting row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(),
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13)),
                      Text(
                        firstName.isNotEmpty
                            ? '$firstName 👋'
                            : 'Good day 👋',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 20),
                      ),
                    ],
                  ),
                  if (isAnonymous)
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) => const AuthScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Text('Sign In',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              // Weather inline card
              _WeatherHeroCard(weather: weather, ref: ref),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherHeroCard extends StatelessWidget {
  final WeatherData? weather;
  final WidgetRef ref;
  const _WeatherHeroCard({required this.weather, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: weather == null
          ? _noWeatherRow(context)
          : _weatherDataRow(weather!),
    );
  }

  Widget _noWeatherRow(BuildContext context) => GestureDetector(
    onTap: () async {
      await Geolocator.requestPermission();
      ref.invalidate(locationProvider);
    },
    child: const Row(children: [
      Icon(Icons.location_off_outlined,
          color: Colors.white70, size: 16),
      SizedBox(width: 8),
      Text('Tap to enable weather',
          style: TextStyle(color: Colors.white70, fontSize: 13)),
    ]),
  );

  Widget _weatherDataRow(WeatherData data) {
    final w = data.current;
    final emoji = _conditionEmoji(w.condition);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${w.tempC.toStringAsFixed(1)}°C',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            Text(
                w.condition.isNotEmpty
                    ? w.condition[0].toUpperCase() +
                        w.condition.substring(1)
                    : '',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11)),
          ],
        ),
        const Spacer(),
        _HeroStat('HUM', '${w.humidityPct}%'),
        const SizedBox(width: 14),
        _HeroStat('UV', '${w.uvIndex}'),
        const SizedBox(width: 14),
        _HeroStat('RAIN', '${w.rainChancePct}%'),
      ],
    );
  }

  String _conditionEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':  return '☀️';
      case 'cloudy': return '⛅';
      case 'rainy':  return '🌧️';
      case 'stormy': return '⛈️';
      default:       return '🌤️';
    }
  }
}

class _HeroStat extends StatelessWidget {
  final String label, value;
  const _HeroStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700)),
    ],
  );
}

// ─── Watering banner ──────────────────────────────────────────────────────────

class _WateringBanner extends ConsumerWidget {
  const _WateringBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(urgentWateringProvider);
    if (data == null) return const SizedBox.shrink();

    final style = _bannerStyle(data.kind);

    String title;
    String subtitle;
    String? cta;

    switch (data.kind) {
      case WateringBannerKind.overdue:
        title = '${data.plantName} needs water now';
        subtitle =
            '${(-data.daysUntil)} day${(-data.daysUntil) == 1 ? '' : 's'} overdue';
        cta = 'Water Now →';
      case WateringBannerKind.dueToday:
        title = '${data.plantName} due today';
        subtitle = 'Water before tonight';
        cta = 'Mark Watered →';
      case WateringBannerKind.dueSoon:
        title = '${data.plantName} due in ${data.daysUntil} day${data.daysUntil == 1 ? '' : 's'}';
        subtitle = 'Coming up soon';
        cta = null;
      case WateringBannerKind.allGood:
        title = 'Plants are watered 💧';
        subtitle = '${data.plantName} next in ${data.daysUntil} days';
        cta = null;
      case WateringBannerKind.rainSkip:
        title = 'Rain expected — skip watering';
        subtitle = 'Reminder paused for outdoor plants';
        cta = null;
      case WateringBannerKind.frost:
        title = 'Frost warning tonight';
        subtitle = 'Bring outdoor plants inside';
        cta = null;
    }

    return GestureDetector(
      onTap: data.scientificName.isEmpty
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SpeciesHistoryScreen(
                    scientificName: data.scientificName,
                    commonName: data.plantName,
                  ),
                ),
              ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(
              left: BorderSide(color: style.border, width: 3)),
        ),
        child: Row(
          children: [
            Text(style.icon,
                style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: style.titleColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: style.subtitleColor,
                          fontSize: 11)),
                ],
              ),
            ),
            if (cta != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: style.border,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(cta,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  _BannerStyle _bannerStyle(WateringBannerKind kind) {
    switch (kind) {
      case WateringBannerKind.overdue:
        return _BannerStyle(
          bg: const Color(0xFF2D1515),
          border: const Color(0xFFEF5350),
          titleColor: const Color(0xFFFFCDD2),
          subtitleColor: const Color(0xFFEF9A9A),
          icon: '💧',
        );
      case WateringBannerKind.dueToday:
        return _BannerStyle(
          bg: const Color(0xFF2D2010),
          border: const Color(0xFFFF9800),
          titleColor: const Color(0xFFFFE0B2),
          subtitleColor: const Color(0xFFFFCC80),
          icon: '💧',
        );
      case WateringBannerKind.dueSoon:
        return _BannerStyle(
          bg: const Color(0xFF1A2535),
          border: const Color(0xFF42A5F5),
          titleColor: const Color(0xFFBBDEFB),
          subtitleColor: const Color(0xFF90CAF9),
          icon: '💧',
        );
      case WateringBannerKind.allGood:
        return _BannerStyle(
          bg: const Color(0xFF1E2D20),
          border: const Color(0xFF66BB6A),
          titleColor: const Color(0xFFC8E6C9),
          subtitleColor: const Color(0xFFA5D6A7),
          icon: '💧',
        );
      case WateringBannerKind.rainSkip:
        return _BannerStyle(
          bg: const Color(0xFF2D1A2D),
          border: const Color(0xFFAB47BC),
          titleColor: const Color(0xFFE1BEE7),
          subtitleColor: const Color(0xFFCE93D8),
          icon: '🌧️',
        );
      case WateringBannerKind.frost:
        return _BannerStyle(
          bg: const Color(0xFF2D1515),
          border: const Color(0xFFFF5252),
          titleColor: const Color(0xFFFFCDD2),
          subtitleColor: const Color(0xFFFF8A80),
          icon: '🌡️',
        );
    }
  }
}

class _BannerStyle {
  final Color bg, border, titleColor, subtitleColor;
  final String icon;
  const _BannerStyle({
    required this.bg,
    required this.border,
    required this.titleColor,
    required this.subtitleColor,
    required this.icon,
  });
}

// ─── Diagnosis card with real thumbnail ──────────────────────────────────────

class _DiagnosisCard extends StatelessWidget {
  final DiagnosisResult diagnosis;
  final VoidCallback onTap;
  const _DiagnosisCard({required this.diagnosis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date =
        '${diagnosis.createdAt.month}/${diagnosis.createdAt.day}';
    final subtitle = diagnosis.issues.isEmpty
        ? 'Healthy'
        : '${diagnosis.issues.length} issue${diagnosis.issues.length > 1 ? 's' : ''} found';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: diagnosis.imageUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.lightGreen,
                    child: const Icon(Icons.local_florist,
                        color: AppTheme.green, size: 26),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.lightGreen,
                    child: const Icon(Icons.local_florist,
                        color: AppTheme.green, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(diagnosis.plantSpecies,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('$date · $subtitle',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SeverityBadge(severity: diagnosis.overallSeverity),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

```
flutter test test/screens/home_screen_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Run all tests**

```
flutter test
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_screen.dart test/screens/home_screen_test.dart
git commit -m "feat: home screen redesign — bottom nav FAB, green hero, watering banner, real thumbnails"
```

---

## Task 4: Delete WeatherPanel widget

**Files:**
- Delete: `lib/widgets/weather_panel.dart`

- [ ] **Step 1: Verify no remaining imports of weather_panel.dart**

```
grep -r "weather_panel" lib/ test/
```

Expected: no results (home_screen.dart no longer imports it after Task 3).

- [ ] **Step 2: Delete the file**

```bash
git rm lib/widgets/weather_panel.dart
```

- [ ] **Step 3: Run all tests**

```
flutter test
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: delete WeatherPanel widget — logic absorbed into home hero"
```

---

## Task 5: Manual smoke test

- [ ] Run on Android device/emulator:

```bash
flutter run
```

- [ ] Verify Home tab shows green expanded hero with greeting and weather stats
- [ ] Verify tapping the centre FAB launches the image picker (camera / gallery)
- [ ] Verify tapping My Plants tab switches to the species list
- [ ] Verify dark mode: toggle system dark mode on device — home screen uses Deep Space palette
- [ ] Verify diagnosis cards show the actual plant photo thumbnail (not leaf icon)
- [ ] Verify watering banner shows only when a plant has `lastWateredAt` set
- [ ] Verify watering banner changes colour based on urgency (set `intervalDays: 1` + `lastWateredAt: yesterday` via SpeciesHistoryScreen to test overdue red state)
- [ ] Verify search icon opens filter overlay; applying filter updates the list
