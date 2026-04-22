import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  // userChanges() fires on all user mutations (linkWithCredential, updateProfile,
  // etc.) in addition to sign-in/sign-out. authStateChanges() misses linkWithCredential
  // which is used to upgrade anonymous → email, so the UI would never see the change.
  return FirebaseAuth.instance.userChanges();
});
