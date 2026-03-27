import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/weather_model.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

/// Fetches current device position. Triggers permission dialog if needed.
/// Invalidate this provider to retry after user grants permission.
final locationProvider = FutureProvider<Position?>((ref) async {
  return LocationService.getCurrentPosition();
});

/// Returns WeatherData if location is available, null otherwise.
/// Automatically re-evaluates when locationProvider changes.
final weatherProvider = FutureProvider<WeatherData?>((ref) async {
  final position = await ref.watch(locationProvider.future);
  if (position == null) return null;
  return WeatherService.getWeather(position.latitude, position.longitude);
});
