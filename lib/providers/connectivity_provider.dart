import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits `true` when the device has any network connection, `false` when offline.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  // Emit current state immediately.
  final initial = await Connectivity().checkConnectivity();
  yield _isOnline(initial);

  // Then track changes.
  await for (final result in Connectivity().onConnectivityChanged) {
    yield _isOnline(result);
  }
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);
