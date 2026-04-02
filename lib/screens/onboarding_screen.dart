import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/location_service.dart';
class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

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
    await widget.onComplete();
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
          await LocationService.requestPermission();
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
        color: active ? cs.primary : cs.onSurface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
