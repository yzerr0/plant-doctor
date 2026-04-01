import 'package:flutter_test/flutter_test.dart';
import 'package:plant_doctor/services/watering_service.dart';

void main() {
  test('WateringService static members compile and are accessible', () {
    expect(WateringService.docKey, isNotNull);
    expect(WateringService.prefsStream, isNotNull);
    expect(WateringService.savePrefs, isNotNull);
    expect(WateringService.markWatered, isNotNull);
    expect(WateringService.updateInterval, isNotNull);
  });

  test('docKey produces a consistent base64url string', () {
    final key = WateringService.docKey('Monstera deliciosa');
    expect(key, isNotEmpty);
    expect(key, equals(WateringService.docKey('Monstera deliciosa')));
    expect(key, isNot(equals(WateringService.docKey('Ficus lyrata'))));
  });
}
