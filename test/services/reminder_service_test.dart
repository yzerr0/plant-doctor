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
