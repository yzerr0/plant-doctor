import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
import 'screens/onboarding_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
  );
  await Hive.initFlutter();
  tz_data.initializeTimeZones();
  final tzInfo = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
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
    try {
      final box = await Hive.openBox('offline_cache');
      final seen = box.get('hasSeenOnboarding') as bool? ?? false;
      if (mounted) setState(() => _hasSeenOnboarding = seen);
    } catch (_) {
      // Hive unavailable — fail open, treat as first launch
      if (mounted) setState(() => _hasSeenOnboarding = false);
    }
  }

  Widget get _spinner =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return _spinner;
    }
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user == null) {
          return _spinner;
        }
        return _hasSeenOnboarding!
            ? const HomeScreen()
            : OnboardingScreen(
                onComplete: () async {
                  final box = await Hive.openBox('offline_cache');
                  await box.put('hasSeenOnboarding', true);
                  if (mounted) setState(() => _hasSeenOnboarding = true);
                },
              );
      },
      loading: () => _spinner,
      error: (_, __) => const Scaffold(
        body: Center(
            child: Text('Authentication error. Please restart the app.')),
      ),
    );
  }
}
