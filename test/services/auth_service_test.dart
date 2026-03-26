import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:plant_doctor/services/auth_service.dart';

@GenerateMocks([FirebaseAuth, User, UserCredential])
import 'auth_service_test.mocks.dart';

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthService authService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(auth: mockAuth);
  });

  group('ensureAnonymousSession', () {
    test('calls signInAnonymously when currentUser is null', () async {
      when(mockAuth.currentUser).thenReturn(null);
      when(mockAuth.signInAnonymously())
          .thenAnswer((_) async => MockUserCredential());
      await authService.ensureAnonymousSession();
      verify(mockAuth.signInAnonymously()).called(1);
    });

    test('does not call signInAnonymously when user already exists', () async {
      when(mockAuth.currentUser).thenReturn(MockUser());
      await authService.ensureAnonymousSession();
      verifyNever(mockAuth.signInAnonymously());
    });
  });

  group('isAnonymous', () {
    test('returns true when user is anonymous', () {
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.isAnonymous).thenReturn(true);
      expect(authService.isAnonymous, isTrue);
    });

    test('returns true when no current user', () {
      when(mockAuth.currentUser).thenReturn(null);
      expect(authService.isAnonymous, isTrue);
    });

    test('returns false when signed in with provider', () {
      final mockUser = MockUser();
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.isAnonymous).thenReturn(false);
      expect(authService.isAnonymous, isFalse);
    });
  });
}
