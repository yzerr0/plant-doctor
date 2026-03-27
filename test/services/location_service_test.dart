import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plant_doctor/services/location_service.dart';

// Note: Full geolocator testing requires a real device or platform mock.
// This test validates the service exists and the method signatures compile.
void main() {
  test('LocationService has expected static methods', () {
    // Verifies the API surface compiles correctly
    expect(LocationService.getCurrentPosition, isA<Function>());
    expect(LocationService.hasPermission, isA<Function>());
  });
}
