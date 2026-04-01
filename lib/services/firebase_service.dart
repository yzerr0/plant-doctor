import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/diagnosis_model.dart';

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

  static Future<void> deleteDiagnosis(String id) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('diagnoses')
        .doc(id)
        .delete();
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
