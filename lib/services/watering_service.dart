import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/watering_prefs.dart';

class WateringService {
  static final _db = FirebaseFirestore.instance;

  /// Deterministic Firestore document key for a species name.
  static String docKey(String scientificName) =>
      base64Url.encode(utf8.encode(scientificName));

  static CollectionReference _col(String uid) =>
      _db.collection('users').doc(uid).collection('wateringPrefs');

  static Stream<WateringPrefs?> prefsStream(String uid, String scientificName) {
    return _col(uid).doc(docKey(scientificName)).snapshots().map(
          (s) => s.exists
              ? WateringPrefs.fromFirestore(s.data() as Map<String, dynamic>)
              : null,
        );
  }

  static Future<void> savePrefs(
      String uid, String scientificName, WateringPrefs prefs) async {
    await _col(uid).doc(docKey(scientificName)).set(prefs.toFirestore());
  }

  static Future<void> markWatered(String uid, String scientificName) async {
    await _col(uid)
        .doc(docKey(scientificName))
        .set({'lastWateredAt': Timestamp.now()}, SetOptions(merge: true));
  }

  static Future<void> updateInterval(
      String uid, String scientificName, int intervalDays) async {
    await _col(uid)
        .doc(docKey(scientificName))
        .set({'intervalDays': intervalDays}, SetOptions(merge: true));
  }
}
