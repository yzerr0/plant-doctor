import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/diagnosis_model.dart';

/// Hive-backed local cache for diagnoses + offline delete queue.
///
/// Keys used in the box:
///   diagnoses_{uid}        → JSON string of List<Map>
///   pending_deletes_{uid}  → JSON string of List<String> (diagnosis IDs)
class LocalStoreService {
  static const _boxName = 'offline_cache';

  static Future<Box> _box() => Hive.openBox(_boxName);

  // ── Diagnoses cache ────────────────────────────────────────────────────────

  static Future<void> saveDiagnoses(
      String uid, List<DiagnosisResult> diagnoses) async {
    final box = await _box();
    final payload = jsonEncode(diagnoses
        .map((d) => {'id': d.id, 'imageUrl': d.imageUrl, ...d.toFirestore()})
        .toList());
    await box.put('diagnoses_$uid', payload);
  }

  static Future<List<DiagnosisResult>> loadDiagnoses(String uid) async {
    final box = await _box();
    final raw = box.get('diagnoses_$uid') as String?;
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            final id = m['id'] as String? ?? '';
            return DiagnosisResult.fromFirestore(id, m);
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove a single diagnosis from the local cache without touching Firestore.
  static Future<void> removeFromCache(String uid, String diagnosisId) async {
    final current = await loadDiagnoses(uid);
    final updated = current.where((d) => d.id != diagnosisId).toList();
    await saveDiagnoses(uid, updated);
  }

  // ── Pending-delete queue ───────────────────────────────────────────────────

  static Future<void> queueDelete(String uid, String diagnosisId) async {
    final box = await _box();
    final key = 'pending_deletes_$uid';
    final raw = box.get(key) as String?;
    final ids = raw != null
        ? List<String>.from(jsonDecode(raw) as List)
        : <String>[];
    if (!ids.contains(diagnosisId)) ids.add(diagnosisId);
    await box.put(key, jsonEncode(ids));
  }

  static Future<List<String>> getPendingDeletes(String uid) async {
    final box = await _box();
    final raw = box.get('pending_deletes_$uid') as String?;
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw) as List);
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearPendingDelete(
      String uid, String diagnosisId) async {
    final box = await _box();
    final key = 'pending_deletes_$uid';
    final ids = await getPendingDeletes(uid);
    ids.remove(diagnosisId);
    await box.put(key, jsonEncode(ids));
  }
}
