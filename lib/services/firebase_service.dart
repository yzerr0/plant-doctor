import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diagnosis_model.dart';
import 'local_store_service.dart';

class FirebaseService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<void> saveDiagnosis(DiagnosisResult result) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('diagnoses')
        .doc(result.id)
        .set(result.toFirestore());
  }

  /// Deletes a diagnosis. If offline, removes it from the local Hive cache
  /// immediately and queues the Firestore delete for the next online session.
  static Future<void> deleteDiagnosis(String id) async {
    final uid = _uid;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('diagnoses')
          .doc(id)
          .delete();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed') {
        // Offline — remove optimistically from cache and queue for later.
        await LocalStoreService.removeFromCache(uid, id);
        await LocalStoreService.queueDelete(uid, id);
        return;
      }
      rethrow;
    }
  }

  static Future<void> updateDiagnosisProfileId(
      String diagnosisId, String profileId) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('diagnoses')
        .doc(diagnosisId)
        .update({'plantProfileId': profileId});
  }

  static Stream<List<DiagnosisResult>> diagnosesStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('diagnoses')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs
            .map((d) => DiagnosisResult.fromFirestore(d.id, d.data()))
            .toList());
  }
}
