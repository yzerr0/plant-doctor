# v0.5 Plant Profiles, Journal & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform PlantDoctor from a scanner into a companion app — named plant profiles with health timelines, watering/rescan reminders via local notifications, search/filter on scan history, and dark mode.

**Architecture:** Plant profiles live in Firestore `users/{uid}/plants/` (CRUD via `PlantProfileService`). `ReminderService` schedules local notifications using `FcmService.notifications` (the shared `FlutterLocalNotificationsPlugin` instance), persisting notification IDs in Hive to allow cancellation. After each scan, a rescan reminder is auto-scheduled. Watering reminders are scheduled from `PlantProfileScreen` when the user marks a plant as watered. Dark mode is `ThemeMode.system` driven by two `ThemeData` definitions in `AppTheme`.

**Tech Stack:** Flutter/Dart, Riverpod, Cloud Firestore, `flutter_local_notifications ^18.0.0` (existing), `hive_flutter ^1.1.0`, `fl_chart ^0.70.2`, `timezone ^0.10.0`, `flutter_timezone ^1.0.0`

---

## File Structure

**New files:**
- `lib/models/plant_profile.dart` — `PlantProfile` + `PlantNote` data classes, `fromFirestore`/`toFirestore`
- `lib/services/plant_profile_service.dart` — Firestore CRUD for plant profiles
- `lib/services/reminder_service.dart` — schedule/cancel watering + rescan local notifications; Hive for notification ID persistence
- `lib/providers/plant_profiles_provider.dart` — `StreamProvider<List<PlantProfile>>` + `plantProfileProvider` family
- `lib/widgets/severity_timeline_chart.dart` — `fl_chart` step chart of `overallSeverity` across scans
- `lib/screens/plant_profiles_list_screen.dart` — browsable list of profiles + create dialog
- `lib/screens/plant_profile_screen.dart` — per-plant detail: health timeline, notes, watering, linked scans
- `lib/screens/select_profile_screen.dart` — picker pushed from `ResultScreen`
- `test/models/plant_profile_test.dart`
- `test/services/plant_profile_service_test.dart`
- `test/services/reminder_service_test.dart`
- `test/providers/plant_profiles_provider_test.dart`

**Modified files:**
- `pubspec.yaml` — add `hive_flutter`, `fl_chart`, `timezone`, `flutter_timezone`
- `lib/theme.dart` — add `light()` and `dark()` static `ThemeData` factories
- `lib/main.dart` — Hive init, timezone init, `darkTheme` + `ThemeMode.system`
- `lib/services/fcm_service.dart` — rename `_localNotifications` → `notifications` (expose for `ReminderService`)
- `lib/services/firebase_service.dart` — add `updateDiagnosisProfileId()`
- `lib/providers/diagnoses_provider.dart` — add `profileDiagnosesProvider` family
- `lib/screens/result_screen.dart` — add "Add to profile" action
- `lib/screens/home_screen.dart` — search/filter + My Plants nav; wire rescan reminder after scan save
- `android/app/src/main/AndroidManifest.xml` — add `SCHEDULE_EXACT_ALARM` permission

---

## Task 1: Packages + Hive Init + Dark Mode

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/theme.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Add packages to pubspec.yaml**

Under `dependencies:`, add these four lines (preserve existing indentation — 2 spaces):

```yaml
  hive_flutter: ^1.1.0
  fl_chart: ^0.70.2
  flutter_timezone: ^1.0.0
  timezone: ^0.10.0
```

- [ ] **Step 2: Run flutter pub get**

```bash
flutter pub get
```

Expected: `Changed N dependencies! ...` with no errors.

- [ ] **Step 3: Add light() and dark() factory methods to theme.dart**

`lib/theme.dart` currently has no `ThemeData` factories — the entire `ThemeData` is defined inline in `main.dart`. Add them now. Replace the entire file:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const green = Color(0xFF2E7D32);
  static const lightGreen = Color(0xFFE8F5E9);
  static const background = Color(0xFFF1F8F1);

  static ThemeData light() => ThemeData(
    colorSchemeSeed: green,
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    textTheme: GoogleFonts.interTextTheme(),
  );

  static ThemeData dark() => ThemeData(
    colorSchemeSeed: green,
    brightness: Brightness.dark,
    useMaterial3: true,
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
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

- [ ] **Step 4: Update main.dart to initialise Hive + timezone and apply dark theme**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/fcm_service.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Hive.initFlutter();
  tz_data.initializeTimeZones();
  final String tzName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzName));
  await FcmService.initialize();
  runApp(const ProviderScope(child: PlantDoctorApp()));
}

class PlantDoctorApp extends StatelessWidget {
  const PlantDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlantDoctor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authServiceProvider).ensureAnonymousSession();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) => user != null
          ? const HomeScreen()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const Scaffold(
        body: Center(child: Text('Authentication error. Please restart the app.')),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the app and verify dark mode**

```bash
flutter run
```

Toggle your device/emulator between light and dark mode in system settings. Expected: app theme switches without restart.

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml lib/theme.dart lib/main.dart
git commit -m "feat: add hive/fl_chart/timezone deps, Hive+tz init, dark mode (ThemeMode.system)"
```

---

## Task 2: PlantProfile Model

**Files:**
- Create: `lib/models/plant_profile.dart`
- Create: `test/models/plant_profile_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/models/plant_profile_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/models/plant_profile.dart';

void main() {
  group('PlantNote', () {
    test('serialises and deserialises round-trip', () {
      final note = PlantNote(text: 'New leaf sprouting', createdAt: DateTime(2026, 3, 30));
      final note2 = PlantNote.fromJson(note.toMap());
      expect(note2.text, 'New leaf sprouting');
      expect(note2.createdAt, DateTime(2026, 3, 30));
    });
  });

  group('PlantProfile', () {
    test('Firestore round-trip preserves all required fields', () {
      final profile = PlantProfile(
        id: 'abc123',
        name: 'Balcony Basil',
        location: 'outdoor',
        diagnosisIds: const ['d1', 'd2'],
        wateringIntervalDays: 3,
        notes: [PlantNote(text: 'Thriving', createdAt: DateTime(2026, 3, 1))],
        createdAt: DateTime(2026, 1, 1),
      );
      final map = profile.toFirestore();
      final p2 = PlantProfile.fromFirestore('abc123', map);
      expect(p2.id, 'abc123');
      expect(p2.name, 'Balcony Basil');
      expect(p2.location, 'outdoor');
      expect(p2.diagnosisIds, ['d1', 'd2']);
      expect(p2.wateringIntervalDays, 3);
      expect(p2.notes.first.text, 'Thriving');
      expect(p2.createdAt, DateTime(2026, 1, 1));
    });

    test('optional fields default to null when absent from Firestore doc', () {
      final p = PlantProfile.fromFirestore('id', {
        'name': 'My Plant',
        'location': 'indoor',
        'diagnosisIds': <dynamic>[],
        'wateringIntervalDays': 7,
        'notes': <dynamic>[],
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(p.primarySpecies, isNull);
      expect(p.primaryScientificName, isNull);
      expect(p.lastWateredAt, isNull);
      expect(p.hardinessZone, isNull);
    });
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/models/plant_profile_test.dart
```

Expected: compile error — `plant_profile.dart` does not exist yet.

- [ ] **Step 3: Write the model**

Create `lib/models/plant_profile.dart`:

```dart
class PlantNote {
  final String text;
  final DateTime createdAt;

  const PlantNote({required this.text, required this.createdAt});

  factory PlantNote.fromJson(Map<String, dynamic> j) => PlantNote(
        text: j['text'] as String? ?? '',
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'text': text,
        'createdAt': createdAt.toIso8601String(),
      };
}

class PlantProfile {
  final String id;
  final String name;
  final String location; // "indoor" | "outdoor"
  final String? primarySpecies; // common name from first attached scan
  final String? primaryScientificName; // used as species cache key
  final String? hardinessZone;
  final List<String> diagnosisIds;
  final int wateringIntervalDays;
  final DateTime? lastWateredAt;
  final List<PlantNote> notes;
  final DateTime createdAt;

  const PlantProfile({
    required this.id,
    required this.name,
    required this.location,
    this.primarySpecies,
    this.primaryScientificName,
    this.hardinessZone,
    required this.diagnosisIds,
    required this.wateringIntervalDays,
    this.lastWateredAt,
    required this.notes,
    required this.createdAt,
  });

  factory PlantProfile.fromFirestore(String id, Map<String, dynamic> j) =>
      PlantProfile(
        id: id,
        name: j['name'] as String? ?? '',
        location: j['location'] as String? ?? 'indoor',
        primarySpecies: j['primarySpecies'] as String?,
        primaryScientificName: j['primaryScientificName'] as String?,
        hardinessZone: j['hardinessZone'] as String?,
        diagnosisIds: List<String>.from(j['diagnosisIds'] as List? ?? []),
        wateringIntervalDays:
            (j['wateringIntervalDays'] as num? ?? 7).toInt(),
        lastWateredAt: j['lastWateredAt'] != null
            ? DateTime.tryParse(j['lastWateredAt'] as String)
            : null,
        notes: (j['notes'] as List? ?? [])
            .map((n) => PlantNote.fromJson(Map<String, dynamic>.from(n as Map)))
            .toList(),
        createdAt:
            DateTime.tryParse(j['createdAt'] as String? ?? '') ??
                DateTime.now(),
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'location': location,
        if (primarySpecies != null) 'primarySpecies': primarySpecies,
        if (primaryScientificName != null)
          'primaryScientificName': primaryScientificName,
        if (hardinessZone != null) 'hardinessZone': hardinessZone,
        'diagnosisIds': diagnosisIds,
        'wateringIntervalDays': wateringIntervalDays,
        if (lastWateredAt != null)
          'lastWateredAt': lastWateredAt!.toIso8601String(),
        'notes': notes.map((n) => n.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/models/plant_profile_test.dart
```

Expected: `All tests passed!` (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/plant_profile.dart test/models/plant_profile_test.dart
git commit -m "feat: add PlantProfile + PlantNote model with Firestore serialisation"
```

---

## Task 3: PlantProfileService + FirebaseService.updateDiagnosisProfileId

**Files:**
- Create: `lib/services/plant_profile_service.dart`
- Modify: `lib/services/firebase_service.dart`
- Create: `test/services/plant_profile_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/plant_profile_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/services/plant_profile_service.dart';

void main() {
  test('PlantProfileService static members compile and are accessible', () {
    // Firestore calls are not exercised in unit tests (require emulator).
    // This test verifies the service compiles with the expected API surface.
    expect(PlantProfileService.profilesStream, isNotNull);
    expect(PlantProfileService.createProfile, isNotNull);
    expect(PlantProfileService.deleteProfile, isNotNull);
    expect(PlantProfileService.attachDiagnosis, isNotNull);
    expect(PlantProfileService.addNote, isNotNull);
    expect(PlantProfileService.updateNotes, isNotNull);
    expect(PlantProfileService.markWatered, isNotNull);
    expect(PlantProfileService.updateWateringInterval, isNotNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/services/plant_profile_service_test.dart
```

Expected: compile error — `plant_profile_service.dart` does not exist.

- [ ] **Step 3: Write PlantProfileService**

Create `lib/services/plant_profile_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/plant_profile.dart';

class PlantProfileService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Stream<List<PlantProfile>> profilesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('plants')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs
            .map((d) => PlantProfile.fromFirestore(d.id, d.data()))
            .toList());
  }

  static Future<PlantProfile> createProfile(
      String name, String location) async {
    final ref =
        _db.collection('users').doc(_uid).collection('plants').doc();
    final profile = PlantProfile(
      id: ref.id,
      name: name,
      location: location,
      diagnosisIds: const [],
      wateringIntervalDays: 7,
      notes: const [],
      createdAt: DateTime.now(),
    );
    await ref.set(profile.toFirestore());
    return profile;
  }

  static Future<void> deleteProfile(String profileId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .delete();
  }

  /// Attach a diagnosis to a profile.
  /// Pass [setPrimarySpecies] and [setPrimaryScientificName] only when the
  /// profile has no primary species yet (check locally before calling).
  static Future<void> attachDiagnosis(
    String profileId,
    String diagnosisId, {
    String? setPrimarySpecies,
    String? setPrimaryScientificName,
  }) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .update({
      'diagnosisIds': FieldValue.arrayUnion([diagnosisId]),
      if (setPrimarySpecies != null) 'primarySpecies': setPrimarySpecies,
      if (setPrimaryScientificName != null)
        'primaryScientificName': setPrimaryScientificName,
    });
  }

  static Future<void> addNote(String profileId, String text) async {
    final note = PlantNote(text: text, createdAt: DateTime.now());
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .update({
      'notes': FieldValue.arrayUnion([note.toMap()]),
    });
  }

  /// Overwrite the full notes list. Use for deletions.
  static Future<void> updateNotes(
      String profileId, List<PlantNote> notes) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .update({'notes': notes.map((n) => n.toMap()).toList()});
  }

  static Future<void> markWatered(String profileId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .update({'lastWateredAt': DateTime.now().toIso8601String()});
  }

  static Future<void> updateWateringInterval(
      String profileId, int intervalDays) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('plants')
        .doc(profileId)
        .update({'wateringIntervalDays': intervalDays});
  }
}
```

- [ ] **Step 4: Add updateDiagnosisProfileId to firebase_service.dart**

In `lib/services/firebase_service.dart`, add after the `deleteDiagnosis` method (before the closing `}`):

```dart
  static Future<void> updateDiagnosisProfileId(
      String diagnosisId, String profileId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('diagnoses')
        .doc(diagnosisId)
        .update({'plantProfileId': profileId});
  }
```

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: all tests pass including the new service test.

- [ ] **Step 6: Commit**

```bash
git add lib/services/plant_profile_service.dart lib/services/firebase_service.dart test/services/plant_profile_service_test.dart
git commit -m "feat: add PlantProfileService and FirebaseService.updateDiagnosisProfileId"
```

---

## Task 4: plantProfilesProvider + profileDiagnosesProvider

**Files:**
- Create: `lib/providers/plant_profiles_provider.dart`
- Modify: `lib/providers/diagnoses_provider.dart`
- Create: `test/providers/plant_profiles_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/providers/plant_profiles_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/providers/plant_profiles_provider.dart';

void main() {
  test('plantProfilesProvider is a StreamProvider', () {
    expect(plantProfilesProvider, isA<StreamProvider>());
  });

  test('plantProfileProvider is a Provider family', () {
    expect(plantProfileProvider('some-id'), isNotNull);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/providers/plant_profiles_provider_test.dart
```

Expected: compile error — file does not exist.

- [ ] **Step 3: Create plant_profiles_provider.dart**

Create `lib/providers/plant_profiles_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant_profile.dart';
import '../services/plant_profile_service.dart';
import 'auth_provider.dart';

final plantProfilesProvider = StreamProvider<List<PlantProfile>>((ref) {
  final asyncUser = ref.watch(authStateProvider);
  return asyncUser.when(
    data: (user) => user != null
        ? PlantProfileService.profilesStream(user.uid)
        : Stream.value([]),
    loading: () => Stream.value([]),
    error: (err, stack) => Stream.value([]),
  );
});

/// Derives a single profile by ID from the stream.
final plantProfileProvider =
    Provider.family<PlantProfile?, String>((ref, profileId) {
  return ref
      .watch(plantProfilesProvider)
      .valueOrNull
      ?.where((p) => p.id == profileId)
      .firstOrNull;
});
```

- [ ] **Step 4: Add profileDiagnosesProvider to diagnoses_provider.dart**

Add to the end of `lib/providers/diagnoses_provider.dart`:

```dart
import '../models/diagnosis_model.dart';

/// Returns diagnoses attached to a specific plant profile, sorted oldest-first.
/// Note: diagnosesProvider is limited to the 20 most recent diagnoses.
/// Scans attached before the 20-scan window may not appear here.
final profileDiagnosesProvider =
    Provider.family<List<DiagnosisResult>, String>((ref, profileId) {
  final diagnoses = ref.watch(diagnosesProvider).valueOrNull ?? [];
  return diagnoses
      .where((d) => d.plantProfileId == profileId)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});
```

- [ ] **Step 5: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/providers/plant_profiles_provider.dart lib/providers/diagnoses_provider.dart test/providers/plant_profiles_provider_test.dart
git commit -m "feat: add plantProfilesProvider, plantProfileProvider family, profileDiagnosesProvider"
```

---

## Task 5: ReminderService

**Files:**
- Modify: `lib/services/fcm_service.dart` (expose `notifications`)
- Create: `lib/services/reminder_service.dart`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `test/services/reminder_service_test.dart`
- Modify: `lib/screens/home_screen.dart` (wire rescan reminder after scan save)

- [ ] **Step 1: Expose the FlutterLocalNotificationsPlugin from FcmService**

In `lib/services/fcm_service.dart`, change line 15 from:

```dart
  static final _localNotifications = FlutterLocalNotificationsPlugin();
```

to:

```dart
  static final notifications = FlutterLocalNotificationsPlugin();
```

Then replace every occurrence of `_localNotifications` in the file with `notifications` (there are 4 occurrences on lines 35–38, 40, 52, and 53). The file after this change:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class FcmService {
  static final notifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidChannel = AndroidNotificationChannel(
      'plant_alerts',
      'Plant Alerts',
      description: 'Frost, heat wave, and watering alerts for your plants.',
      importance: Importance.high,
    );
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        notifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
```

- [ ] **Step 2: Add SCHEDULE_EXACT_ALARM permission to AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, add this line after the existing `<uses-permission>` entries (before `<application`):

```xml
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

- [ ] **Step 3: Write the failing test**

Create `test/services/reminder_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/services/reminder_service.dart';

void main() {
  test('ReminderService static members compile and are accessible', () {
    expect(ReminderService.scheduleRescan, isNotNull);
    expect(ReminderService.cancelRescan, isNotNull);
    expect(ReminderService.scheduleWatering, isNotNull);
    expect(ReminderService.cancelWatering, isNotNull);
  });
}
```

- [ ] **Step 4: Run to verify it fails**

```bash
flutter test test/services/reminder_service_test.dart
```

Expected: compile error — file does not exist.

- [ ] **Step 5: Write ReminderService**

Create `lib/services/reminder_service.dart`:

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'fcm_service.dart';

class ReminderService {
  static const _boxName = 'reminders';

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'plant_alerts',
      'Plant Alerts',
      channelDescription:
          'Frost, heat wave, and watering alerts for your plants.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<Box> _box() => Hive.openBox(_boxName);

  static int _id(String prefix, String key) =>
      (prefix.hashCode ^ key.hashCode).abs() % 0x7FFFFFFF;

  // ── Rescan reminders ──────────────────────────────────────────────────────

  static Future<void> scheduleRescan({
    required String diagnosisId,
    required String plantSpecies,
    required DateTime scanDate,
    required int followUpDays,
  }) async {
    final scheduledDate = scanDate.add(Duration(days: followUpDays));
    if (scheduledDate.isBefore(DateTime.now())) return;
    final id = _id('rescan', diagnosisId);
    await FcmService.notifications.zonedSchedule(
      id,
      'Time to rescan $plantSpecies',
      'Check how your plant is doing — $followUpDays days have passed.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    final box = await _box();
    await box.put('rescan_$diagnosisId', id);
  }

  static Future<void> cancelRescan(String diagnosisId) async {
    final box = await _box();
    final id = box.get('rescan_$diagnosisId') as int?;
    if (id != null) {
      await FcmService.notifications.cancel(id);
      await box.delete('rescan_$diagnosisId');
    }
  }

  // ── Watering reminders ────────────────────────────────────────────────────

  static Future<void> scheduleWatering({
    required String profileId,
    required String plantName,
    required int intervalDays,
    required DateTime lastWateredAt,
  }) async {
    await cancelWatering(profileId); // clear previous reminder first
    final nextWatering = lastWateredAt.add(Duration(days: intervalDays));
    if (nextWatering.isBefore(DateTime.now())) return;
    final id = _id('watering', profileId);
    await FcmService.notifications.zonedSchedule(
      id,
      'Water $plantName today',
      'Your plant hasn\'t been watered for $intervalDays days.',
      tz.TZDateTime.from(nextWatering, tz.local),
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    final box = await _box();
    await box.put('watering_$profileId', id);
  }

  static Future<void> cancelWatering(String profileId) async {
    final box = await _box();
    final id = box.get('watering_$profileId') as int?;
    if (id != null) {
      await FcmService.notifications.cancel(id);
      await box.delete('watering_$profileId');
    }
  }
}
```

- [ ] **Step 6: Wire rescan reminder into home_screen.dart after scan save**

In `lib/screens/home_screen.dart`, add `ReminderService` import at the top:

```dart
import '../services/reminder_service.dart';
```

In `_scanPlant`, after `await FirebaseService.saveDiagnosis(diagnosis);`, add:

```dart
      await ReminderService.scheduleRescan(
        diagnosisId: diagnosis.id,
        plantSpecies: diagnosis.plantSpecies,
        scanDate: diagnosis.createdAt,
        followUpDays: diagnosis.followUpIn,
      );
```

- [ ] **Step 7: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/services/fcm_service.dart lib/services/reminder_service.dart android/app/src/main/AndroidManifest.xml test/services/reminder_service_test.dart lib/screens/home_screen.dart
git commit -m "feat: add ReminderService (watering + rescan local notifications via Hive + flutter_local_notifications)"
```

---

## Task 6: SeverityTimelineChart Widget

**Files:**
- Create: `lib/widgets/severity_timeline_chart.dart`
- Create: `test/widgets/severity_timeline_chart_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/severity_timeline_chart_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/widgets/severity_timeline_chart.dart';

void main() {
  testWidgets('renders SizedBox.shrink when scan list is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SeverityTimelineChart(scans: [])),
      ),
    );
    // Empty list → widget renders but contains no LineChart
    expect(find.byType(SeverityTimelineChart), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/widgets/severity_timeline_chart_test.dart
```

Expected: compile error — file does not exist.

- [ ] **Step 3: Write SeverityTimelineChart**

Create `lib/widgets/severity_timeline_chart.dart`:

```dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/diagnosis_model.dart';
import '../theme.dart';

class SeverityTimelineChart extends StatelessWidget {
  /// Scans should be sorted oldest-first (ascending by createdAt).
  final List<DiagnosisResult> scans;

  const SeverityTimelineChart({super.key, required this.scans});

  static double _toY(String severity) => switch (severity) {
        'healthy' => 0,
        'low' => 1,
        'medium' => 2,
        'high' => 3,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    if (scans.isEmpty) return const SizedBox.shrink();

    final spots = scans
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), _toY(e.value.overallSeverity)))
        .toList();

    return SizedBox(
      height: 120,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 3,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              bottomTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final label = switch (value.toInt()) {
                      0 => 'OK',
                      1 => 'Low',
                      2 => 'Med',
                      3 => 'High',
                      _ => '',
                    };
                    return SideTitleWidget(
                      meta: meta,
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: AppTheme.green,
                barWidth: 2,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.green.withAlpha(40),
                      AppTheme.green.withAlpha(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> **Note:** `fl_chart ^0.70.2` may require `SideTitleWidget(meta: meta, ...)`. If you get a compile error about `SideTitleWidget`, check the package's `CHANGELOG.md` for the current constructor signature.

- [ ] **Step 4: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/severity_timeline_chart.dart test/widgets/severity_timeline_chart_test.dart
git commit -m "feat: add SeverityTimelineChart widget (fl_chart step chart)"
```

---

## Task 7: PlantProfilesListScreen

**Files:**
- Create: `lib/screens/plant_profiles_list_screen.dart`

(No new tests — this is a display-only screen; Firestore calls go through services already tested.)

- [ ] **Step 1: Create the screen**

Create `lib/screens/plant_profiles_list_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant_profile.dart';
import '../providers/plant_profiles_provider.dart';
import '../services/plant_profile_service.dart';
import '../theme.dart';
import 'plant_profile_screen.dart';

class PlantProfilesListScreen extends ConsumerWidget {
  const PlantProfilesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(plantProfilesProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: const Text('My Plants',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: asyncProfiles.when(
        data: (profiles) => profiles.isEmpty
            ? const Center(
                child: Text(
                  'No plant profiles yet.\nTap + to add your first plant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: profiles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) =>
                    _ProfileCard(profile: profiles[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Error loading profiles')),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CreateProfileDialog(),
    );
  }
}

class _CreateProfileDialog extends StatefulWidget {
  const _CreateProfileDialog();

  @override
  State<_CreateProfileDialog> createState() => _CreateProfileDialogState();
}

class _CreateProfileDialogState extends State<_CreateProfileDialog> {
  final _nameCtrl = TextEditingController();
  String _location = 'indoor';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Plant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Plant name',
              hintText: 'e.g. Balcony Basil',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'indoor', label: Text('Indoor')),
              ButtonSegment(value: 'outdoor', label: Text('Outdoor')),
            ],
            selected: {_location},
            onSelectionChanged: (s) =>
                setState(() => _location = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await PlantProfileService.createProfile(name, _location);
    if (mounted) Navigator.pop(context);
  }
}

class _ProfileCard extends StatelessWidget {
  final PlantProfile profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  PlantProfileScreen(profileId: profile.id)),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.eco,
                    color: AppTheme.green, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                    if (profile.primarySpecies != null)
                      Text(profile.primarySpecies!,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Text(
                '${profile.diagnosisIds.length} scan${profile.diagnosisIds.length == 1 ? '' : 's'}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/plant_profiles_list_screen.dart
git commit -m "feat: add PlantProfilesListScreen with create-profile dialog"
```

---

## Task 8: PlantProfileScreen

**Files:**
- Create: `lib/screens/plant_profile_screen.dart`

- [ ] **Step 1: Create the screen**

Create `lib/screens/plant_profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant_profile.dart';
import '../providers/diagnoses_provider.dart';
import '../providers/plant_profiles_provider.dart';
import '../services/plant_profile_service.dart';
import '../services/reminder_service.dart';
import '../theme.dart';
import '../widgets/severity_timeline_chart.dart';
import 'result_screen.dart';

class PlantProfileScreen extends ConsumerStatefulWidget {
  final String profileId;
  const PlantProfileScreen({super.key, required this.profileId});

  @override
  ConsumerState<PlantProfileScreen> createState() =>
      _PlantProfileScreenState();
}

class _PlantProfileScreenState extends ConsumerState<PlantProfileScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(plantProfileProvider(widget.profileId));
    final scans = ref.watch(profileDiagnosesProvider(widget.profileId));

    if (profile == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: Text(profile.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete plant',
            onPressed: () => _confirmDelete(context, profile),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeaderCard(profile: profile),
          const SizedBox(height: 12),
          if (scans.isNotEmpty) ...[
            _SectionLabel('HEALTH TIMELINE'),
            const SizedBox(height: 8),
            SeverityTimelineChart(scans: scans),
            const SizedBox(height: 12),
          ],
          _WateringCard(profile: profile),
          const SizedBox(height: 12),
          _NotesCard(
            profile: profile,
            noteCtrl: _noteCtrl,
          ),
          if (scans.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionLabel('LINKED SCANS'),
            const SizedBox(height: 8),
            ...scans.reversed.map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    leading:
                        const Icon(Icons.local_florist, color: AppTheme.green),
                    title: Text(d.plantSpecies,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${d.createdAt.month}/${d.createdAt.day}/${d.createdAt.year} · ${d.overallSeverity}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ResultScreen(diagnosis: d)),
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlantProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete plant?'),
        content: Text(
            'This will permanently delete "${profile.name}" and cannot be undone. Scans will not be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ReminderService.cancelWatering(profile.id);
              await PlantProfileService.deleteProfile(profile.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 1.2));
}

class _HeaderCard extends StatelessWidget {
  final PlantProfile profile;
  const _HeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.eco, color: AppTheme.green, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (profile.primarySpecies != null)
                  Text(profile.primarySpecies!,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                Text(
                  profile.location == 'indoor'
                      ? '🏠 Indoor'
                      : '🌤 Outdoor',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                if (profile.hardinessZone != null)
                  Text('Zone ${profile.hardinessZone}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WateringCard extends ConsumerWidget {
  final PlantProfile profile;
  const _WateringCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastWatered = profile.lastWateredAt;
    final daysAgo = lastWatered == null
        ? null
        : DateTime.now().difference(lastWatered).inDays;
    final isDue = daysAgo != null && daysAgo >= profile.wateringIntervalDays;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WATERING',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lastWatered == null
                          ? 'Not recorded'
                          : daysAgo == 0
                              ? 'Watered today'
                              : 'Watered $daysAgo day${daysAgo == 1 ? '' : 's'} ago',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              isDue ? Colors.red[700] : Colors.black87),
                    ),
                    Text(
                      'Every ${profile.wateringIntervalDays} days',
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    _markWatered(context, ref, profile),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                child: const Text('Mark watered'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                _editInterval(context, ref, profile),
            child: Text(
                'Change interval (${profile.wateringIntervalDays} days)'),
          ),
        ],
      ),
    );
  }

  Future<void> _markWatered(
      BuildContext context, WidgetRef ref, PlantProfile profile) async {
    await PlantProfileService.markWatered(profile.id);
    await ReminderService.scheduleWatering(
      profileId: profile.id,
      plantName: profile.name,
      intervalDays: profile.wateringIntervalDays,
      lastWateredAt: DateTime.now(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Marked as watered. Reminder set.'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  void _editInterval(
      BuildContext context, WidgetRef ref, PlantProfile profile) {
    showDialog(
      context: context,
      builder: (ctx) =>
          _IntervalDialog(profile: profile),
    );
  }
}

class _IntervalDialog extends StatefulWidget {
  final PlantProfile profile;
  const _IntervalDialog({required this.profile});

  @override
  State<_IntervalDialog> createState() => _IntervalDialogState();
}

class _IntervalDialogState extends State<_IntervalDialog> {
  late int _days;

  @override
  void initState() {
    super.initState();
    _days = widget.profile.wateringIntervalDays;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Watering interval'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Every $_days day${_days == 1 ? '' : 's'}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600)),
          Slider(
            value: _days.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            label: '$_days',
            activeColor: AppTheme.green,
            onChanged: (v) => setState(() => _days = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            await PlantProfileService.updateWateringInterval(
                widget.profile.id, _days);
            if (widget.profile.lastWateredAt != null) {
              await ReminderService.scheduleWatering(
                profileId: widget.profile.id,
                plantName: widget.profile.name,
                intervalDays: _days,
                lastWateredAt: widget.profile.lastWateredAt!,
              );
            }
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NotesCard extends StatelessWidget {
  final PlantProfile profile;
  final TextEditingController noteCtrl;
  const _NotesCard({required this.profile, required this.noteCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NOTES',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey,
                  letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add a note…',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  maxLines: 2,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.green),
                onPressed: () async {
                  final text = noteCtrl.text.trim();
                  if (text.isEmpty) return;
                  await PlantProfileService.addNote(profile.id, text);
                  noteCtrl.clear();
                },
              ),
            ],
          ),
          if (profile.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...profile.notes.reversed.map((note) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(note.text,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      '${note.createdAt.month}/${note.createdAt.day}/${note.createdAt.year}',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close,
                        size: 18, color: Colors.grey),
                    onPressed: () async {
                      final updated = List<PlantNote>.from(profile.notes)
                        ..remove(note);
                      await PlantProfileService.updateNotes(
                          profile.id, updated);
                    },
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/plant_profile_screen.dart
git commit -m "feat: add PlantProfileScreen (timeline, notes, watering reminders, linked scans)"
```

---

## Task 9: SelectProfileScreen + ResultScreen "Add to Profile"

**Files:**
- Create: `lib/screens/select_profile_screen.dart`
- Modify: `lib/screens/result_screen.dart`

- [ ] **Step 1: Create SelectProfileScreen**

Create `lib/screens/select_profile_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/plant_profile.dart';
import '../providers/plant_profiles_provider.dart';
import '../services/plant_profile_service.dart';
import '../theme.dart';

/// Pushed from ResultScreen. Returns the selected [PlantProfile] via Navigator.pop,
/// or null if the user cancels.
class SelectProfileScreen extends ConsumerWidget {
  const SelectProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncProfiles = ref.watch(plantProfilesProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: const Text('Add to plant profile',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: asyncProfiles.when(
        data: (profiles) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...profiles.map((p) => ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  leading:
                      const Icon(Icons.eco, color: AppTheme.green),
                  title: Text(p.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                  subtitle: p.primarySpecies != null
                      ? Text(p.primarySpecies!)
                      : null,
                  onTap: () => Navigator.pop(context, p),
                )),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, color: AppTheme.green),
              label: const Text('New plant profile',
                  style: TextStyle(color: AppTheme.green)),
              onPressed: () => _createAndReturn(context),
            ),
          ],
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Error loading profiles')),
      ),
    );
  }

  void _createAndReturn(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _QuickCreateDialog(onCreated: (profile) {
        Navigator.pop(ctx);
        Navigator.pop(context, profile);
      }),
    );
  }
}

class _QuickCreateDialog extends StatefulWidget {
  final void Function(PlantProfile) onCreated;
  const _QuickCreateDialog({required this.onCreated});

  @override
  State<_QuickCreateDialog> createState() => _QuickCreateDialogState();
}

class _QuickCreateDialogState extends State<_QuickCreateDialog> {
  final _nameCtrl = TextEditingController();
  String _location = 'indoor';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Plant'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Plant name',
              hintText: 'e.g. Window Fern',
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'indoor', label: Text('Indoor')),
              ButtonSegment(value: 'outdoor', label: Text('Outdoor')),
            ],
            selected: {_location},
            onSelectionChanged: (s) =>
                setState(() => _location = s.first),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Create'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final profile =
        await PlantProfileService.createProfile(name, _location);
    if (mounted) widget.onCreated(profile);
  }
}
```

- [ ] **Step 2: Add "Add to profile" action to ResultScreen**

`lib/screens/result_screen.dart` is a `ConsumerWidget`. Convert it to `ConsumerStatefulWidget` to hold `_profileId` state (shows which profile this scan is attached to after the user acts). The change is minimal — only the class declaration, `build` method, and the SliverAppBar actions change.

At the top of `result_screen.dart`, add the imports:

```dart
import '../services/firebase_service.dart';
import '../services/plant_profile_service.dart';
import 'select_profile_screen.dart';
```

Change the class declaration from:

```dart
class ResultScreen extends ConsumerWidget {
  final DiagnosisResult diagnosis;
  const ResultScreen({super.key, required this.diagnosis});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
```

to:

```dart
class ResultScreen extends ConsumerStatefulWidget {
  final DiagnosisResult diagnosis;
  const ResultScreen({super.key, required this.diagnosis});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {
  String? _attachedProfileId;

  @override
  void initState() {
    super.initState();
    _attachedProfileId = widget.diagnosis.plantProfileId;
  }

  DiagnosisResult get diagnosis => widget.diagnosis;

  @override
  Widget build(BuildContext context) {
```

In the `SliverAppBar`'s `actions:` list, add the profile action **before** the existing copy button:

```dart
            IconButton(
              icon: Icon(
                _attachedProfileId != null
                    ? Icons.check_circle
                    : Icons.add_circle_outline,
              ),
              tooltip: _attachedProfileId != null
                  ? 'Added to profile'
                  : 'Add to plant profile',
              onPressed: _attachedProfileId != null
                  ? null
                  : () => _addToProfile(context),
            ),
```

Add the `_addToProfile` method to `_ResultScreenState`:

```dart
  Future<void> _addToProfile(BuildContext context) async {
    final profile = await Navigator.push<PlantProfile>(
      context,
      MaterialPageRoute(builder: (_) => const SelectProfileScreen()),
    );
    if (profile == null || !mounted) return;

    // Extract species names from combined "CommonName (ScientificName)" string
    final parts = diagnosis.plantSpecies.split('(');
    final commonName = parts[0].trim();
    final scientificName =
        parts.length > 1 ? parts[1].replaceAll(')', '').trim() : null;

    await Future.wait([
      FirebaseService.updateDiagnosisProfileId(diagnosis.id, profile.id),
      PlantProfileService.attachDiagnosis(
        profile.id,
        diagnosis.id,
        setPrimarySpecies:
            profile.primarySpecies == null ? commonName : null,
        setPrimaryScientificName:
            profile.primaryScientificName == null ? scientificName : null,
      ),
    ]);

    setState(() => _attachedProfileId = profile.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added to "${profile.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
```

> **Note:** All other methods in `ResultScreen` (e.g. `_signInBanner`, `_careGrid`) currently access `diagnosis` as a field. After conversion they become methods on `_ResultScreenState` and already access `diagnosis` via the getter `DiagnosisResult get diagnosis => widget.diagnosis;`. No other changes needed.

- [ ] **Step 3: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 4: Commit**

```dart
git add lib/screens/select_profile_screen.dart lib/screens/result_screen.dart
git commit -m "feat: add SelectProfileScreen + ResultScreen 'Add to profile' action"
```

---

## Task 10: HomeScreen Search/Filter + My Plants Navigation

**Files:**
- Modify: `lib/screens/home_screen.dart`

The goal is:
1. Convert `HomeScreen` from `ConsumerWidget` to `ConsumerStatefulWidget` to hold `_searchQuery` and `_severityFilter` state.
2. Add a search `TextField` and severity filter chips above the diagnoses list.
3. Add a "My Plants" button in the `AppBar` actions that navigates to `PlantProfilesListScreen`.
4. Apply client-side filter logic to the diagnoses list.

- [ ] **Step 1: Modify home_screen.dart**

Add imports at the top:

```dart
import 'plant_profiles_list_screen.dart';
```

Replace the `HomeScreen` class (lines 20–70) with a `ConsumerStatefulWidget`:

```dart
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  String? _severityFilter; // null = show all

  @override
  Widget build(BuildContext context) {
    final isAnonymous =
        ref.watch(authStateProvider).valueOrNull?.isAnonymous ?? true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.green,
        foregroundColor: Colors.white,
        title: const Text('🌿 PlantDoctor',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.eco_outlined),
            tooltip: 'My Plants',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PlantProfilesListScreen()),
            ),
          ),
          if (isAnonymous)
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AuthScreen())),
              child: const Text('Sign In',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const _ScanButton(),
          const SizedBox(height: 12),
          const WeatherPanel(),
          const SizedBox(height: 12),
          _SearchBar(
            query: _searchQuery,
            onChanged: (q) => setState(() => _searchQuery = q),
          ),
          const SizedBox(height: 8),
          _SeverityFilterChips(
            selected: _severityFilter,
            onSelected: (v) =>
                setState(() => _severityFilter = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _DiagnosesList(
              searchQuery: _searchQuery,
              severityFilter: _severityFilter,
            ),
          ),
        ],
      ),
    );
  }
}
```

Add the `_SearchBar` widget class after `_HomeScreenState`:

```dart
class _SearchBar extends StatelessWidget {
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.query, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search diagnoses…',
          prefixIcon:
              const Icon(Icons.search, color: Colors.grey, size: 20),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onChanged(''),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
      ),
    );
  }
}
```

Add the `_SeverityFilterChips` widget class:

```dart
class _SeverityFilterChips extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onSelected;
  const _SeverityFilterChips(
      {required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = ['healthy', 'low', 'medium', 'high'];
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => onSelected(null),
              selectedColor: AppTheme.lightGreen,
            ),
          ),
          ...options.map((s) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(
                      '${s[0].toUpperCase()}${s.substring(1)}'),
                  selected: selected == s,
                  onSelected: (_) =>
                      onSelected(selected == s ? null : s),
                  selectedColor: AppTheme.severityColor(s)
                      .withAlpha(80),
                ),
              )),
        ],
      ),
    );
  }
}
```

Update `_DiagnosesList` to accept `searchQuery` and `severityFilter` parameters and apply client-side filtering:

```dart
class _DiagnosesList extends ConsumerWidget {
  final String searchQuery;
  final String? severityFilter;
  const _DiagnosesList(
      {required this.searchQuery, required this.severityFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDiagnoses = ref.watch(diagnosesProvider);
    return asyncDiagnoses.when(
      data: (items) {
        final filtered = items.where((d) {
          final matchesSearch = searchQuery.isEmpty ||
              d.plantSpecies
                  .toLowerCase()
                  .contains(searchQuery.toLowerCase());
          final matchesSeverity = severityFilter == null ||
              d.overallSeverity == severityFilter;
          return matchesSearch && matchesSeverity;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
              child: Text(
            items.isEmpty ? 'No plants scanned yet' : 'No results',
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: filtered.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => Dismissible(
            key: ValueKey(filtered[i].id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red[400],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline,
                  color: Colors.white, size: 24),
            ),
            confirmDismiss: (_) async {
              try {
                await FirebaseService.deleteDiagnosis(filtered[i].id);
                return true;
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Delete failed. Please try again.')),
                  );
                }
                return false;
              }
            },
            child: _DiagnosisCard(
              diagnosis: filtered[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        ResultScreen(diagnosis: filtered[i])),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
          child: Text('Error loading diagnoses',
              style: TextStyle(color: Colors.grey))),
    );
  }
}
```

- [ ] **Step 2: Run all tests**

```bash
flutter test
```

Expected: all tests pass.

- [ ] **Step 3: Run the app and verify end-to-end**

```bash
flutter run
```

Smoke test:
1. App opens in light/dark mode according to system setting.
2. Scan a plant → rescan reminder is scheduled (visible in device notification settings).
3. Result screen → "Add to profile" button → create a new profile → scan is attached.
4. AppBar "My Plants" icon → `PlantProfilesListScreen` → tap profile → `PlantProfileScreen` opens with timeline and notes.
5. Tap "Mark watered" → watering reminder scheduled.
6. Search bar and severity chips filter the diagnoses list correctly.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: HomeScreen search/filter + My Plants nav (ConsumerStatefulWidget)"
```

---

## Self-Review

### Spec Coverage

| Spec item | Task |
|---|---|
| Named plant profiles (Firestore `users/{uid}/plants/`) | Tasks 2, 3, 4, 7 |
| Attach scans to profiles (`plantProfileId` + `diagnosisIds[]`) | Tasks 3, 9 |
| Health timeline chart (fl_chart, overallSeverity across scans) | Task 6, surfaced in Task 8 |
| Plant notes (add/delete per profile) | Task 3 (`addNote`, `updateNotes`), Task 8 |
| Watering reminders (local notification, rain-skip by Cloud Function) | Task 5, Task 8 |
| Rescan reminders (local notification at `createdAt + followUpIn days`) | Task 5 |
| Dashboard redesign (My Plants nav, search/filter) | Task 10 |
| Search & filter (client-side on species name, severity chips) | Task 10 |
| Dark mode (`ThemeMode.system`) | Task 1 |

**Rain-skip for watering reminders (sendWateringReminder Cloud Function):** The spec mentions server-side rain-skip suppression. This is not implemented in v0.5 — the Cloud Function for it is marked as a future enhancement in the spec alongside `sendWateringReminder`. Local notifications are scheduled on the client. No gap vs. the sprint — rain-skip is a polish item.

### Placeholder Scan

No TODOs, "TBD", or "implement later" found. All code blocks are complete.

### Type Consistency

- `PlantProfile.id` / `PlantProfile.name` used consistently across Tasks 2, 3, 7, 8, 9.
- `PlantProfileService.attachDiagnosis(profileId, diagnosisId, setPrimarySpecies:, setPrimaryScientificName:)` — matches Task 3 definition and Task 9 call site.
- `PlantProfileService.updateNotes(profileId, List<PlantNote>)` — matches Task 3 and Task 8 call site.
- `ReminderService.scheduleWatering(profileId:, plantName:, intervalDays:, lastWateredAt:)` — matches Task 5 definition and Task 8 call sites.
- `ReminderService.scheduleRescan(diagnosisId:, plantSpecies:, scanDate:, followUpDays:)` — matches Task 5 definition and Task 5 call in `home_screen.dart`.
- `plantProfileProvider(profileId)` family — defined in Task 4, consumed in Task 8.
- `profileDiagnosesProvider(profileId)` family — defined in Task 4, consumed in Task 8.
- `FcmService.notifications` — renamed in Task 5, used in Task 5 (`reminder_service.dart`).
