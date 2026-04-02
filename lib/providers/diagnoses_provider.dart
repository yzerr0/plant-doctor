import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diagnosis_model.dart';
import '../services/firebase_service.dart';
import '../services/local_store_service.dart';
import 'auth_provider.dart';

final diagnosesProvider = StreamProvider<List<DiagnosisResult>>((ref) async* {
  final asyncUser = ref.watch(authStateProvider);
  final user = asyncUser.valueOrNull;

  if (user == null) {
    yield [];
    return;
  }

  final uid = user.uid;

  // 1. Serve the Hive cache immediately so the UI isn't blank on cold start.
  final cached = await LocalStoreService.loadDiagnoses(uid);
  if (cached.isNotEmpty) yield cached;

  // 2. Drain any pending offline deletes now that we (likely) have connectivity.
  final pending = await LocalStoreService.getPendingDeletes(uid);
  for (final id in pending) {
    try {
      await FirebaseService.deleteDiagnosis(id);
      await LocalStoreService.clearPendingDelete(uid, id);
    } catch (_) {
      // Still offline — leave in queue, try again next session.
    }
  }

  // 3. Stream live from Firestore. Each emission is saved to Hive so the cache
  //    stays fresh for the next offline session.
  await for (final diagnoses in FirebaseService.diagnosesStream(uid)) {
    await LocalStoreService.saveDiagnoses(uid, diagnoses);
    yield diagnoses;
  }
});
