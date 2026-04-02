# Onboarding Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a 3-screen onboarding sequence on first launch (welcome → location permission → notifications permission), never again after that.

**Architecture:** A new `OnboardingScreen` with a `PageView` of 3 pages built from a reusable `_OnboardingPage` widget. First-launch state stored as `'hasSeenOnboarding'` in the existing `'offline_cache'` Hive box. `_AppRouterState` in `main.dart` reads this flag async on startup and routes to `OnboardingScreen` instead of `HomeScreen` when the flag is absent/false.

**Tech Stack:** Flutter, Hive (hive_flutter), geolocator, permission_handler — all already in pubspec.yaml.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `lib/screens/onboarding_screen.dart` | `OnboardingScreen` + private `_OnboardingPage` + `_Dot` widgets |
| Modify | `lib/main.dart` | Add `_hasSeenOnboarding` flag read + routing to `_AppRouterState` |
| Create | `test/screens/onboarding_screen_test.dart` | Widget tests for page navigation and skip behaviour |

---

## Task 1: Create OnboardingScreen widget

**Files:**
- Create: `lib/screens/onboarding_screen.dart`
- Create: `test/screens/onboarding_screen_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/screens/onboarding_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/screens/onboarding_screen.dart';

void main() {
  testWidgets('shows PlantDoctor title and Get Started on page 1', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    expect(find.text('PlantDoctor'), findsOneWidget);
    expect(find.text('Get Started →'), findsOneWidget);
    expect(find.text('Skip for now'), findsNothing);
  });

  testWidgets('Get Started advances to page 2 which has skip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    expect(find.text('Weather-Smart Care'), findsOneWidget);
    expect(find.text('Skip for now'), findsOneWidget);
  });

  testWidgets('Skip on page 2 advances to page 3', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onComplete: () async {})),
    );
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Never Miss a Watering'), findsOneWidget);
  });

  testWidgets('Skip on page 3 calls onComplete', (tester) async {
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onComplete: () async { completed = true; }),
      ),
    );
    // advance to page 2
    await tester.tap(find.text('Get Started →'));
    await tester.pumpAndSettle();
    // advance to page 3
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    // skip on page 3
    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}
```

- [ ] **Step 2: Run tests — expect FAIL (OnboardingScreen not found)**

```bash
cd D:/Documents/ext/plant/pd
flutter test test/screens/onboarding_screen_test.dart
```

Expected: compilation error — `OnboardingScreen` doesn't exist yet.

- [ ] **Step 3: Create `lib/screens/onboarding_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  /// Injected in tests to avoid Hive + Navigator dependencies.
  /// Production code leaves this null and uses the default completion path.
  final Future<void> Function()? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  void _advance() {
    setState(() => _currentPage++);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleComplete() async {
    if (widget.onComplete != null) {
      await widget.onComplete!();
      return;
    }
    final box = await Hive.openBox('offline_cache');
    await box.put('hasSeenOnboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OnboardingPage(
        heroEmoji: '🌿',
        heroGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1b4332), Color(0xFF2d6a4f), Color(0xFF40916c)],
        ),
        title: 'PlantDoctor',
        body: 'Point your camera at any plant. Get species ID, health '
            'diagnosis, and care advice instantly.',
        primaryLabel: 'Get Started →',
        onPrimary: () async => _advance(),
        onSkip: null,
        currentPage: 0,
        totalPages: 3,
      ),
      _OnboardingPage(
        heroEmoji: '🌦️',
        heroGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0d2137), Color(0xFF1a3a5c), Color(0xFF1e4976)],
        ),
        title: 'Weather-Smart Care',
        body: 'PlantDoctor uses your location to factor in local weather — '
            'frost alerts, rain-skip watering, and humidity advice.',
        primaryLabel: 'Allow Location',
        onPrimary: () async {
          await Geolocator.requestPermission();
          _advance();
        },
        onSkip: _advance,
        currentPage: 1,
        totalPages: 3,
      ),
      _OnboardingPage(
        heroEmoji: '🔔',
        heroGradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2d1b00), Color(0xFF4a2f00), Color(0xFF6b4400)],
        ),
        title: 'Never Miss a Watering',
        body: 'Get watering reminders, frost alerts, and rescan nudges — '
            'timed to your plant\'s actual needs.',
        primaryLabel: 'Allow Notifications',
        onPrimary: () async {
          await Permission.notification.request();
          await _handleComplete();
        },
        onSkip: () => _handleComplete(),
        currentPage: 2,
        totalPages: 3,
      ),
    ];

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: pages,
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  final String heroEmoji;
  final LinearGradient heroGradient;
  final String title;
  final String body;
  final String primaryLabel;
  final Future<void> Function() onPrimary;
  final VoidCallback? onSkip;
  final int currentPage;
  final int totalPages;

  const _OnboardingPage({
    required this.heroEmoji,
    required this.heroGradient,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.currentPage,
    required this.totalPages,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          // Hero — top 40% of screen
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(gradient: heroGradient),
              child: Center(
                child: Text(heroEmoji, style: const TextStyle(fontSize: 80)),
              ),
            ),
          ),
          // Content — bottom 60%
          Expanded(
            flex: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      color: cs.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  const Spacer(),
                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  // Skip link
                  if (onSkip != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: onSkip,
                        child: Text(
                          'Skip for now',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      totalPages,
                      (i) => _Dot(active: i == currentPage),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: active ? 20 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.onSurface.withOpacity(0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — expect PASS**

```bash
flutter test test/screens/onboarding_screen_test.dart
```

Expected output: `All tests passed!` (4 tests)

- [ ] **Step 5: Commit**

```bash
cd D:/Documents/ext/plant/pd
git add lib/screens/onboarding_screen.dart test/screens/onboarding_screen_test.dart
git commit -m "feat: onboarding screen — 3 pages, permission requests, page dots"
```

---

## Task 2: Wire onboarding into the app router

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Read the current router code**

Open `lib/main.dart` lines 41–71. The relevant class is `_AppRouterState`. Currently it has:
- `initState`: calls `ensureAnonymousSession()`
- `build`: watches `authStateProvider`, routes to `HomeScreen` when user is non-null

- [ ] **Step 2: Add `_hasSeenOnboarding` field and `_loadOnboardingFlag` method**

In `_AppRouterState`, add the field and loader. Replace the entire `_AppRouterState` class:

```dart
class _AppRouterState extends ConsumerState<_AppRouter> {
  bool? _hasSeenOnboarding; // null = not yet read from Hive

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authServiceProvider).ensureAnonymousSession();
    });
    _loadOnboardingFlag();
  }

  Future<void> _loadOnboardingFlag() async {
    final box = await Hive.openBox('offline_cache');
    final seen = box.get('hasSeenOnboarding') as bool? ?? false;
    if (mounted) setState(() => _hasSeenOnboarding = seen);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _hasSeenOnboarding!
            ? const HomeScreen()
            : const OnboardingScreen();
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(
        body: Center(
            child: Text('Authentication error. Please restart the app.')),
      ),
    );
  }
}
```

- [ ] **Step 3: Add the OnboardingScreen import to `main.dart`**

Add this import below the existing `home_screen.dart` import:

```dart
import 'screens/onboarding_screen.dart';
```

- [ ] **Step 4: Run all tests**

```bash
flutter test
```

Expected: all tests pass including the 4 new onboarding tests.

- [ ] **Step 5: Smoke-test on device / emulator**

```bash
flutter run
```

Manual checklist:
- [ ] First launch: onboarding screen 1 appears (PlantDoctor, green hero)
- [ ] Tap "Get Started →": advances to screen 2 (Weather-Smart Care, blue hero)
- [ ] Tap "Skip for now": advances to screen 3 (Never Miss a Watering, amber hero)
- [ ] Tap "Skip for now": enters HomeScreen
- [ ] Kill and relaunch: goes directly to HomeScreen (no onboarding)
- [ ] Page dots update correctly as you advance

- [ ] **Step 6: Commit**

```bash
cd D:/Documents/ext/plant/pd
git add lib/main.dart
git commit -m "feat: route to onboarding on first launch via Hive flag"
```
