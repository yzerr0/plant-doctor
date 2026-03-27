import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Top-level handler required by firebase_messaging for background messages.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages from sendWeatherAlerts are handled by FCM automatically.
  // This handler is required by the package but no additional action needed here.
}

class FcmService {
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Register background handler before anything else
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (required on iOS; harmless on Android 12-)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Set up local notifications for foreground FCM display (Android)
    const androidChannel = AndroidNotificationChannel(
      'plant_alerts',
      'Plant Alerts',
      description: 'Frost, heat wave, and watering alerts for your plants.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Show FCM notifications as local notifications when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // Save token to Firestore (and keep it fresh on refresh)
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> _saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'fcmToken': token}, SetOptions(merge: true));
  }
}
