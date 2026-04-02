import 'dart:async';
import 'dart:io' show Platform;
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Checks permission and returns current position if granted.
  /// Does NOT auto-request if denied — caller decides when to prompt.
  static Future<Position?> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // On Android, bypass the Fused Location Provider (requires Google Play
    // Services) and use the raw Android LocationManager. This works on
    // emulators with mock GPS set via Extended Controls, and on devices where
    // GMS is unavailable or has connectivity issues.
    final LocationSettings settings = Platform.isAndroid
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            forceLocationManager: true,
          )
        : const LocationSettings(accuracy: LocationAccuracy.best);

    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Requests location permission if not yet granted.
  /// Safe to call even if already granted — will not show dialog again.
  /// Handles deniedForever silently.
  static Future<void> requestPermission() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    // deniedForever — OS won't show dialog, nothing to do
  }

  /// Returns true only if permission is already granted — no dialog shown.
  static Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
