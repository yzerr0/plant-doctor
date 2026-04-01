import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'fcm_service.dart';

class ReminderService {
  static const _boxName = 'reminders';

  static const _notifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'plant_alerts',
      'Plant Alerts',
      channelDescription:
          'Frost, heat wave, and watering alerts for your plants.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<Box> _box() => Hive.openBox(_boxName);

  static int _id(String prefix, String key) =>
      (prefix.hashCode ^ key.hashCode).abs() % 0x7FFFFFFF;

  // ── Rescan reminders ──────────────────────────────────────────────────────

  static Future<void> scheduleRescan({
    required String diagnosisId,
    required String plantSpecies,
    required DateTime scanDate,
    required int followUpDays,
  }) async {
    final scheduledDate = scanDate.add(Duration(days: followUpDays));
    if (scheduledDate.isBefore(DateTime.now())) return;
    final id = _id('rescan', diagnosisId);
    await FcmService.notifications.zonedSchedule(
      id,
      'Time to rescan $plantSpecies',
      'Check how your plant is doing — $followUpDays days have passed.',
      tz.TZDateTime.from(scheduledDate, tz.local),
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    final box = await _box();
    await box.put('rescan_$diagnosisId', id);
  }

  static Future<void> cancelRescan(String diagnosisId) async {
    final box = await _box();
    final id = box.get('rescan_$diagnosisId') as int?;
    if (id != null) {
      await FcmService.notifications.cancel(id);
      await box.delete('rescan_$diagnosisId');
    }
  }

  // ── Watering reminders ────────────────────────────────────────────────────

  static String _wateringKey(String scientificName) =>
      base64Url.encode(utf8.encode(scientificName));

  static Future<void> scheduleWatering({
    required String scientificName,
    required String plantName,
    required int intervalDays,
    required DateTime lastWateredAt,
  }) async {
    await cancelWatering(scientificName); // clear previous reminder first
    final nextWatering = lastWateredAt.add(Duration(days: intervalDays));
    if (nextWatering.isBefore(DateTime.now())) return;
    final key = _wateringKey(scientificName);
    final id = _id('watering', key);
    await FcmService.notifications.zonedSchedule(
      id,
      'Water $plantName today',
      'Your plant hasn\'t been watered for $intervalDays days.',
      tz.TZDateTime.from(nextWatering, tz.local),
      _notifDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    final box = await _box();
    await box.put('watering_$key', id);
  }

  static Future<void> cancelWatering(String scientificName) async {
    final key = _wateringKey(scientificName);
    final box = await _box();
    final id = box.get('watering_$key') as int?;
    if (id != null) {
      await FcmService.notifications.cancel(id);
      await box.delete('watering_$key');
    }
  }
}
