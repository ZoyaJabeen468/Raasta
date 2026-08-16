import 'package:email_validator/email_validator.dart';

abstract final class Validators {
  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email is required';
    if (!EmailValidator.validate(v)) return 'Enter a valid email';
    return null;
  }

  /// Strong password for sign-up / change-password.
  /// At least 8 chars, upper, lower, digit, special.
  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password is required';
    if (v.length < 8) return 'At least 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(v)) {
      return 'Include at least one uppercase letter (A–Z)';
    }
    if (!RegExp(r'[a-z]').hasMatch(v)) {
      return 'Include at least one lowercase letter (a–z)';
    }
    if (!RegExp(r'[0-9]').hasMatch(v)) {
      return 'Include at least one number (0–9)';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`]').hasMatch(v)) {
      return 'Include at least one special character (!@#…)';
    }
    return null;
  }

  /// Checklist used under the password field (live feedback).
  static List<PasswordRule> passwordRules(String value) {
    return [
      PasswordRule('At least 8 characters', value.length >= 8),
      PasswordRule('One uppercase letter (A–Z)', RegExp(r'[A-Z]').hasMatch(value)),
      PasswordRule('One lowercase letter (a–z)', RegExp(r'[a-z]').hasMatch(value)),
      PasswordRule('One number (0–9)', RegExp(r'[0-9]').hasMatch(value)),
      PasswordRule(
        'One special character (!@#…)',
        RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-+=\[\]\\;/`]').hasMatch(value),
      ),
    ];
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Name is required';
    if (v.length < 2) return 'Enter your full name';
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != password) return 'Passwords do not match';
    return null;
  }
}

class PasswordRule {
  const PasswordRule(this.label, this.met);
  final String label;
  final bool met;
}
