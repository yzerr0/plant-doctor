import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  Future<void> ensureAnonymousSession() async {
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    // Re-create anonymous session immediately so the app never sits in a
    // signed-out state. Doing it here (not via a listener) avoids race
    // conditions where the listener's ensureAnonymousSession() would fire
    // during normal sign-in user-swaps and fight the incoming real user.
    await _auth.signInAnonymously();
  }

  /// Links anonymous user to Google, or signs in with Google if no anon user.
  /// Falls back to direct sign-in if the Google account already has a Firebase account.
  Future<void> linkOrSignInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-id-token',
        message: 'Google Sign-In did not return an ID token. '
            'Enable Google Sign-In in Firebase Console and re-download google-services.json.',
      );
    }
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
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

  /// Signs in with email+password.
  /// Intentionally does NOT use linkWithCredential — email credentials have
  /// create-or-fail semantics on linkWithCredential, so passing a non-existent
  /// email would silently create an account instead of returning user-not-found.
  Future<void> linkOrSignInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new email+password account, upgrading anonymous session if active.
  Future<void> createOrLinkEmail(String email, String password) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      // Upgrade anonymous user to a real email account.
      try {
        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        await current.linkWithCredential(credential);
        return;
      } on FirebaseAuthException {
        // Surface email-already-in-use clearly; don't silently fall through to
        // sign-in — the password the user typed for *signup* is likely wrong for
        // the existing account and would produce a confusing "invalid credential" error.
        rethrow;
      }
    }
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    return _auth.createUserWithEmailAndPassword(
        email: email, password: password);
  }

  Future<void> _linkOrSignIn(AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current == null) {
      await _auth.signInWithCredential(credential);
      return;
    }
    if (current.isAnonymous) {
      // Anonymous user: upgrade to real account; fall back to sign-in if account exists
      try {
        await current.linkWithCredential(credential);
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' &&
            e.code != 'email-already-in-use') {
          rethrow;
        }
      }
      await _auth.signInWithCredential(credential);
    } else {
      // Already a real user: sign in directly.
      // Linking additional providers is intentionally not supported here —
      // it would silently merge separate accounts (e.g. Google + email overlap).
      await _auth.signInWithCredential(credential);
    }
  }
}
