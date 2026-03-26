import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth;
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<void> ensureAnonymousSession() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  /// Links anonymous user to Google, or signs in with Google if no anon user.
  /// Falls back to direct sign-in if the Google account already has a Firebase account.
  Future<void> linkOrSignInWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _linkOrSignIn(credential);
  }

  /// Links anonymous user to Apple ID, or signs in with Apple if no anon user.
  Future<void> linkOrSignInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    await _linkOrSignIn(oauthCredential);
  }

  /// Links anonymous user to email+password, or signs in directly if no anon user.
  Future<void> linkOrSignInWithEmail(String email, String password) async {
    final credential =
        EmailAuthProvider.credential(email: email, password: password);
    await _linkOrSignIn(credential);
  }

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> _linkOrSignIn(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        await current.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
        // Account already exists — fall through to sign in directly
      }
    }
    await _auth.signInWithCredential(credential);
  }
}
