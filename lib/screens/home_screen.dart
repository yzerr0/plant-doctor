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
import '../providers/connectivity_provider.dart';
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 6,
        tooltip: 'Scan a Plant',
        child: Ink(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF3EC47A), Color(0xFF1B5E38)],
            ),
          ),
          child: const SizedBox.expand(
            child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 27),
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor =
        isDark ? const Color(0xFF81C784) : AppTheme.green;
    final inactiveColor = Theme.of(context).colorScheme.onSurfaceVariant;

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
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.normal,
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

  Future<void> _showSearchFilter() async {
    if (!mounted) return;
    final controller = TextEditingController(text: _searchQuery);
    String filter = _severityFilter;

    try {
      await showModalBottomSheet(
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
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'Search plants...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
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
                      final text = controller.text;
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {
                          _searchQuery = text;
                          _severityFilter = filter;
                        });
                      }
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
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

    final isWide = MediaQuery.of(context).size.shortestSide >= 600;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isWide ? 680 : double.infinity),
        child: CustomScrollView(
      slivers: [
        // ── Green hero app bar ──────────────────────────────────────
        SliverAppBar(
          expandedHeight: 210,
          pinned: false,
          floating: false,
          backgroundColor: AppTheme.green,
          elevation: 0,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: _GreenHero(),
            collapseMode: CollapseMode.none,
          ),
          // Rounded strip creates "card overlapping hero" effect
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
                _OfflineBanner(ref: ref),
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
                  child: hasFilter
                      ? Center(
                          child: Text(
                            'No results match your filter',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                fontSize: 15),
                          ),
                        )
                      : _EmptyState(),
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
                              borderRadius: BorderRadius.circular(12),
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
          error: (_, __) => const SliverFillRemaining(
              child: Center(
                  child: Text('Error loading diagnoses',
                      style: TextStyle(color: Colors.grey)))),
        ),
      ],
        ),
      ),
    );
  }
}

// ─── Green hero (greeting + weather) ─────────────────────────────────────────

class _GreenHero extends ConsumerWidget {
  const _GreenHero();

  void _showAccountMenu(BuildContext context, WidgetRef ref) {
    final user = ref.read(authStateProvider).valueOrNull;
    final email = user?.email ?? user?.displayName ?? 'Signed in';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.lightGreen,
                    child: const Icon(Icons.person, color: AppTheme.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(email,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.read(authServiceProvider).signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  LinearGradient _heroGradient(WeatherData? weather, bool isDark) {
    if (weather != null && weather.current.tempC <= 2.0) {
      // Frost: red-warning tones in both modes
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [Color(0xFF1A0D1F), AppTheme.heroRedEnd]
            : const [AppTheme.heroGreenStart, AppTheme.heroRedEnd],
      );
    }
    if (weather != null &&
        (weather.current.condition == 'rainy' ||
            weather.current.condition == 'stormy')) {
      // Rain: dark stormy tones
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [AppTheme.heroDarkBlueStart, AppTheme.heroDarkRainyEnd]
            : const [AppTheme.heroGreenStart, AppTheme.heroBlueEnd],
      );
    }
    // Default: deep navy in dark, green in light
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [AppTheme.heroDarkBlueStart, AppTheme.heroDarkBlueEnd]
          : const [AppTheme.heroGreenStart, AppTheme.heroGreenEnd],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final isAnonymous = user?.isAnonymous ?? true;
    final firstName = !isAnonymous
        ? (user?.displayName?.split(' ').firstOrNull ?? '')
        : '';
    final weather = ref.watch(weatherProvider).valueOrNull;

    final h = DateTime.now().hour;
    final greeting =
        h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(gradient: _heroGradient(weather, isDark)),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstName.isNotEmpty) ...[
                        Text(greeting,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13)),
                        Text('$firstName 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20)),
                      ] else
                        Text('$greeting 👋',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20)),
                    ],
                  ),
                  if (isAnonymous)
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
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
                    )
                  else
                    GestureDetector(
                      onTap: () => _showAccountMenu(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.person_outline,
                            color: Colors.white, size: 18),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _WeatherHeroCard(
                weather: weather,
                onEnableWeather: () async {
                  await Geolocator.requestPermission();
                  ref.invalidate(locationProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherHeroCard extends StatelessWidget {
  final WeatherData? weather;
  final VoidCallback onEnableWeather;
  const _WeatherHeroCard({required this.weather, required this.onEnableWeather});

  String _conditionEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'sunny':  return '☀️';
      case 'cloudy': return '⛅';
      case 'rainy':  return '🌧️';
      case 'stormy': return '⛈️';
      default:       return '🌤️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: weather == null ? _noWeatherRow(context) : _weatherDataRow(weather!),
    );
  }

  Widget _noWeatherRow(BuildContext context) => GestureDetector(
        onTap: onEnableWeather,
        child: const Row(children: [
          Icon(Icons.location_off_outlined, color: Colors.white70, size: 16),
          SizedBox(width: 8),
          Text('Tap to enable weather',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );

  Widget _weatherDataRow(WeatherData data) {
    final w = data.current;
    return Row(
      children: [
        Text(_conditionEmoji(w.condition),
            style: const TextStyle(fontSize: 28)),
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
                    ? w.condition[0].toUpperCase() + w.condition.substring(1)
                    : '',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65), fontSize: 11)),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _bannerStyle(data.kind, isDark);

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
        title =
            '${data.plantName} due in ${data.daysUntil} day${data.daysUntil == 1 ? '' : 's'}';
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: style.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: style.border, width: 3)),
        ),
        child: Row(
          children: [
            Text(style.icon, style: const TextStyle(fontSize: 18)),
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
                          color: style.subtitleColor, fontSize: 11)),
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

  _BannerStyle _bannerStyle(WateringBannerKind kind, bool isDark) {
    switch (kind) {
      case WateringBannerKind.overdue:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF2D1515) : const Color(0xFFFFEBEE),
            border: const Color(0xFFEF5350),
            titleColor: isDark ? const Color(0xFFFFCDD2) : const Color(0xFFB71C1C),
            subtitleColor: isDark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F),
            icon: '💧');
      case WateringBannerKind.dueToday:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF2D2010) : const Color(0xFFFFF3E0),
            border: const Color(0xFFFF9800),
            titleColor: isDark ? const Color(0xFFFFE0B2) : const Color(0xFFE65100),
            subtitleColor: isDark ? const Color(0xFFFFCC80) : const Color(0xFFF57C00),
            icon: '💧');
      case WateringBannerKind.dueSoon:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF1A2535) : const Color(0xFFE3F2FD),
            border: const Color(0xFF42A5F5),
            titleColor: isDark ? const Color(0xFFBBDEFB) : const Color(0xFF1565C0),
            subtitleColor: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2),
            icon: '💧');
      case WateringBannerKind.allGood:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF1E2D20) : const Color(0xFFE8F5E9),
            border: const Color(0xFF66BB6A),
            titleColor: isDark ? const Color(0xFFC8E6C9) : const Color(0xFF1B5E20),
            subtitleColor: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
            icon: '💧');
      case WateringBannerKind.rainSkip:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF2D1A2D) : const Color(0xFFF3E5F5),
            border: const Color(0xFFAB47BC),
            titleColor: isDark ? const Color(0xFFE1BEE7) : const Color(0xFF4A148C),
            subtitleColor: isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2),
            icon: '🌧️');
      case WateringBannerKind.frost:
        return _BannerStyle(
            bg: isDark ? const Color(0xFF2D1515) : const Color(0xFFFFEBEE),
            border: const Color(0xFFFF5252),
            titleColor: isDark ? const Color(0xFFFFCDD2) : const Color(0xFFB71C1C),
            subtitleColor: isDark ? const Color(0xFFFF8A80) : const Color(0xFFD32F2F),
            icon: '🌡️');
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

// ─── Offline banner ──────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final WidgetRef ref;
  const _OfflineBanner({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (isOnline) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1A0A),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: Colors.orange.shade700, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: Colors.orange.shade300),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — showing cached scans',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade200),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.camera_alt_rounded, size: 38, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Scan your first plant',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Point your camera at any plant to get an instant species ID, health diagnosis, and personalised care guide.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_downward_rounded, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Tap the camera button below',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: cs.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Diagnosis card with real thumbnail ──────────────────────────────────────

class _DiagnosisCard extends StatelessWidget {
  final DiagnosisResult diagnosis;
  final VoidCallback onTap;
  const _DiagnosisCard({required this.diagnosis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final date =
        '${months[diagnosis.createdAt.month - 1]} ${diagnosis.createdAt.day}';
    final subtitle = diagnosis.issues.isEmpty
        ? 'Healthy'
        : '${diagnosis.issues.length} issue${diagnosis.issues.length > 1 ? 's' : ''} found';

    final imageSize = MediaQuery.of(context).size.shortestSide >= 600 ? 68.0 : 48.0;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: diagnosis.imageUrl,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.lightGreen,
                    child: Icon(Icons.local_florist,
                        color: AppTheme.green, size: imageSize * 0.54),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.lightGreen,
                    child: Icon(Icons.local_florist,
                        color: AppTheme.green, size: imageSize * 0.54),
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
                            fontWeight: FontWeight.w600, fontSize: 14),
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
