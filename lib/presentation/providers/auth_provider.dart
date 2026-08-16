import 'package:flutter/foundation.dart';

import '../../data/local/local_store.dart';
import '../../data/models/language_preference.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, LocalStore? store})
      : _auth = authService ?? AuthService(),
        _store = store ?? LocalStore.instance;

  final AuthService _auth;
  final LocalStore _store;

  UserProfile? _user;
  bool _booting = true;
  bool _busy = false;
  String? _error;
  String? _info;
  bool _onboardingDone = false;
  LanguagePreference _language = LanguagePreference.english;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isBooting => _booting;
  bool get isBusy => _busy;
  String? get error => _error;
  String? get info => _info;
  bool get onboardingDone => _onboardingDone;
  LanguagePreference get language => _language;
  bool get hasPasswordProvider => _auth.hasPasswordProvider;

  Future<void> bootstrap() async {
    _booting = true;
    notifyListeners();
    try {
      _user = await _auth.restoreSession();
      _onboardingDone = await _store.isOnboardingDone();
      _language = await _store.language();
    } finally {
      _booting = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    return _run(() async {
      _user = await _auth.signUp(
        name: name,
        email: email,
        password: password,
      );
      _onboardingDone = false;
    });
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _run(() async {
      _user = await _auth.signIn(email: email, password: password);
      _onboardingDone = await _store.isOnboardingDone();
      _language = await _store.language();
    });
  }

  /// True when this sign-in created a brand new account, so callers can route
  /// through onboarding instead of straight to home.
  bool _isNewAccount = false;
  bool get isNewAccount => _isNewAccount;

  Future<bool> signInWithProvider(SocialProvider provider) async {
    return _run(() async {
      _user = await _auth.signInWithProvider(provider);
      _onboardingDone = await _store.isOnboardingDone();
      _language = await _store.language();
      _isNewAccount = !_onboardingDone;
    });
  }

  Future<bool> sendPasswordReset(String email) async {
    return _run(() async {
      await _auth.sendPasswordResetEmail(email);
      _info = 'Reset link sent. Check your email inbox.';
    });
  }

  Future<bool> updateName(String name) async {
    return _run(() async {
      _user = await _auth.updateDisplayName(name);
    });
  }

  Future<bool> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    return _run(() async {
      await _auth.changeEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );
      _info = 'Confirm the link we sent to $newEmail to finish the change.';
    });
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    return _run(() async {
      await _auth.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _info = 'Password updated.';
    });
  }

  Future<bool> deleteAccount(String currentPassword) async {
    final ok = await _run(() async {
      await _auth.deleteAccount(currentPassword);
    });
    if (ok) {
      _user = null;
      notifyListeners();
    }
    return ok;
  }

  Future<void> completeOnboarding(LanguagePreference language) async {
    _language = language;
    await _store.setLanguage(language);
    await _store.markOnboardingDone();
    _onboardingDone = true;
    notifyListeners();
  }

  Future<void> setLanguage(LanguagePreference language) async {
    _language = language;
    await _store.setLanguage(language);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _error = null;
    _info = null;
    notifyListeners();
  }

  void clearMessages() {
    if (_error == null && _info == null) return;
    _error = null;
    _info = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    _busy = true;
    _error = null;
    _info = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Something went wrong. Please try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
