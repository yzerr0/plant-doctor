import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/weather_model.dart';
import '../providers/weather_provider.dart';
import '../theme.dart';

class WeatherPanel extends ConsumerWidget {
  const WeatherPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(weatherProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: weather.when(
        data: (data) => data == null
            ? _PermissionPrompt(onTap: () async {
                await Geolocator.requestPermission();
                ref.invalidate(locationProvider);
              })
            : _WeatherCard(data: data),
        loading: () => _loadingCard(),
        error: (_, __) => _errorCard(),
      ),
    );
  }

  Widget _loadingCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: const Row(
      children: [
        SizedBox(width: 14, height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.green)),
        SizedBox(width: 10),
        Text('Loading weather...', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    ),
  );

  Widget _errorCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: const Row(
      children: [
        Icon(Icons.cloud_off_outlined, color: Colors.grey, size: 18),
        SizedBox(width: 8),
        Text('Weather unavailable', style: TextStyle(color: Colors.grey, fontSize: 13)),
      ],
    ),
  );
}

class _PermissionPrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _PermissionPrompt({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightGreen),
      ),
      child: const Row(
        children: [
          Icon(Icons.location_off_outlined, color: AppTheme.green, size: 18),
          SizedBox(width: 10),
          Text('Tap to enable local weather',
            style: TextStyle(fontSize: 13, color: AppTheme.green,
                fontWeight: FontWeight.w500)),
          Spacer(),
          Icon(Icons.chevron_right, color: AppTheme.green, size: 18),
        ],
      ),
    ),
  );
}

class _WeatherCard extends StatelessWidget {
  final WeatherData data;
  const _WeatherCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final w = data.current;
    final condition = w.condition.isNotEmpty
        ? w.condition[0].toUpperCase() + w.condition.substring(1)
        : 'Unknown';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOCAL WEATHER',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${w.tempC.toStringAsFixed(1)}°C',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                    color: AppTheme.green)),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(emoji: '💧', value: '${w.humidityPct}%', label: 'Humidity'),
                    _Stat(emoji: '☂️', value: '${w.rainChancePct}%', label: 'Rain'),
                    _Stat(emoji: '🌞', value: '${w.uvIndex}', label: 'UV'),
                    _Stat(emoji: '💨',
                        value: '${w.windKph.toStringAsFixed(0)}',
                        label: 'km/h'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(condition,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String emoji, value, label;
  const _Stat({required this.emoji, required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 15)),
      const SizedBox(height: 2),
      Text(value,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      Text(label,
        style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ],
  );
}
