import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diagnosis_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';

final diagnosesProvider = StreamProvider<List<DiagnosisResult>>((ref) {
  final asyncUser = ref.watch(authStateProvider);
  return asyncUser.when(
    data: (user) => user != null
        ? FirebaseService.diagnosesStream(user.uid)
        : Stream.value([]),
    loading: () => Stream.value([]),
    error: (err, stack) => Stream.value([]),
  );
});
