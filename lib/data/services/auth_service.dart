import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/firebase_bootstrap.dart';
import '../../firebase_options.dart';
import '../local/local_store.dart';
import '../models/user_profile.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Federated identity providers offered on the welcome screen.
enum SocialProvider {
  google,
  facebook;

  String get label => this == SocialProvider.google ? 'Google' : 'Facebook';
}

class AuthService {
  AuthService({
    LocalStore? store,
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _store = store ?? LocalStore.instance,
        _firebase = firebaseAuth,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: const ['email', 'profile'],
              serverClientId:
                  DefaultFirebaseOptions.googleWebClientId.trim().isEmpty
                      ? null
                      : DefaultFirebaseOptions.googleWebClientId.trim(),
            );

  final LocalStore _store;
  final FirebaseAuth? _firebase;
  final GoogleSignIn _googleSignIn;

  FirebaseAuth get _auth {
    if (!FirebaseBootstrap.ready) {
      throw AuthException(
        FirebaseBootstrap.initError ??
            'Firebase is not configured. See FIREBASE_SETUP.md',
      );
    }
    return _firebase ?? FirebaseAuth.instance;
  }

  Future<UserProfile?> restoreSession() async {
    if (!FirebaseBootstrap.ready) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    return _toProfile(user);
  }

  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw AuthException('Could not create account. Try again.');
      }
      await user.updateDisplayName(name.trim());
      await user.reload();
      final fresh = _auth.currentUser ?? user;
      final profile = _toProfile(fresh, fallbackName: name.trim());
      await _store.saveUser(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw AuthException('Could not sign in. Try again.');
      }
      final profile = _toProfile(user);
      await _store.saveUser(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<UserProfile> signInWithProvider(SocialProvider social) async {
    try {
      switch (social) {
        case SocialProvider.google:
          return await _signInWithGoogle();
        case SocialProvider.facebook:
          return await _signInWithFacebook();
      }
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapSocialError(e, social));
    } catch (e) {
      debugPrint('Social sign-in error ($social): $e');
      throw AuthException(
        'Could not sign in with ${social.label}. ${e.toString()}',
      );
    }
  }

  Future<UserProfile> _signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider()..addScope('email');
      final cred = await _auth.signInWithPopup(provider);
      return _finishSocial(cred.user, 'Google');
    }

    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw AuthException('Google sign-in cancelled.');
    }

    final googleAuth = await account.authentication;
    if (googleAuth.idToken == null && googleAuth.accessToken == null) {
      throw AuthException(
        'Google sign-in failed (no token). Enable Google in Firebase '
        'Authentication, add your Android SHA-1, set googleWebClientId in '
        'firebase_options.dart, and place google-services.json. '
        'See FIREBASE_SETUP.md.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final cred = await _auth.signInWithCredential(credential);
    return _finishSocial(cred.user, 'Google');
  }

  Future<UserProfile> _signInWithFacebook() async {
    if (kIsWeb) {
      final provider = FacebookAuthProvider()..addScope('email');
      final cred = await _auth.signInWithPopup(provider);
      return _finishSocial(cred.user, 'Facebook');
    }

    final result = await FacebookAuth.instance.login(
      permissions: const ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.cancelled) {
      throw AuthException('Facebook sign-in cancelled.');
    }
    if (result.status != LoginStatus.success || result.accessToken == null) {
      throw AuthException(
        result.message?.isNotEmpty == true
            ? result.message!
            : 'Facebook sign-in failed. Create a Facebook app, enable '
                'Facebook in Firebase Authentication, and set App ID / '
                'Client Token in AndroidManifest. See FIREBASE_SETUP.md.',
      );
    }

    final credential = FacebookAuthProvider.credential(
      result.accessToken!.tokenString,
    );
    final cred = await _auth.signInWithCredential(credential);
    return _finishSocial(cred.user, 'Facebook');
  }

  Future<UserProfile> _finishSocial(User? user, String label) async {
    if (user == null) {
      throw AuthException('Could not sign in with $label.');
    }
    final profile = _toProfile(user);
    await _store.saveUser(profile);
    return profile;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<void> signOut() async {
    if (!FirebaseBootstrap.ready) return;
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<UserProfile> updateDisplayName(String name) async {
    final user = _requireUser();
    try {
      await user.updateDisplayName(name.trim());
      await user.reload();
      final profile = _toProfile(
        _auth.currentUser ?? user,
        fallbackName: name.trim(),
      );
      await _store.saveUser(profile);
      return profile;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _requireUser();
    try {
      await _reauthenticate(user, currentPassword);
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireUser();
    try {
      await _reauthenticate(user, currentPassword);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  Future<void> deleteAccount(String currentPassword) async {
    final user = _requireUser();
    try {
      await _reauthenticate(user, currentPassword);
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    }
  }

  /// True when the signed-in user can change email/password (email provider).
  bool get hasPasswordProvider {
    if (!FirebaseBootstrap.ready) return true;
    final user = _auth.currentUser;
    if (user == null) return false;
    return user.providerData.any((p) => p.providerId == 'password');
  }

  User _requireUser() {
    final user = _auth.currentUser;
    if (user == null) {
      throw AuthException('You are signed out. Sign in and try again.');
    }
    return user;
  }

  Future<void> _reauthenticate(User user, String password) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw AuthException(
        'This account uses Google/Facebook. Password changes are not '
        'available for social logins.',
      );
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  UserProfile _toProfile(User user, {String? fallbackName}) {
    return UserProfile(
      id: user.uid,
      name: (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : (fallbackName ?? user.email?.split('@').first ?? 'Driver'),
      email: user.email ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  String _mapSocialError(FirebaseAuthException e, SocialProvider social) {
    switch (e.code) {
      case 'operation-not-allowed':
        return '${social.label} sign-in is not enabled yet. '
            'Turn it on in Firebase Console → Authentication → Sign-in method.';
      case 'popup-closed-by-user':
      case 'cancelled-popup-request':
      case 'web-context-canceled':
        return 'Sign-in cancelled.';
      case 'account-exists-with-different-credential':
        return 'This email is already registered with a different sign-in '
            'method. Use that method instead.';
      default:
        return _mapFirebaseError(e);
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'invalid-email':
        return 'Enter a valid email';
      case 'weak-password':
        return 'Password is too weak. Use 8+ characters with upper, lower, '
            'number, and special character.';
      case 'user-not-found':
        return 'No account found for this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your internet connection';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'requires-recent-login':
        return 'Please sign in again before making this change';
      case 'credential-already-in-use':
        return 'That email is already linked to another account';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
