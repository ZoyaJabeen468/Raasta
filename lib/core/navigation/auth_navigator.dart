import 'package:flutter/material.dart';

import '../constants/routes.dart';
import '../../data/local/local_store.dart';
import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/home_screen.dart';
import '../../presentation/screens/intro/intro_screen.dart';
import '../../presentation/screens/onboarding/permissions_screen.dart';
import '../../presentation/screens/welcome_screen.dart';

/// Central post-auth routing.
abstract final class AuthNavigator {
  static Future<void> afterAuth(
    BuildContext context,
    AuthProvider auth, {
    required bool isNewUser,
  }) async {
    if (!context.mounted) return;

    if (isNewUser || !auth.onboardingDone) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.permissions,
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  static Future<void> afterSplash(
    BuildContext context,
    AuthProvider auth,
  ) async {
    if (!context.mounted) return;

    late final Widget page;
    late final String name;

    if (auth.isLoggedIn) {
      if (auth.onboardingDone) {
        page = const HomeScreen();
        name = AppRoutes.home;
      } else {
        page = const PermissionsScreen();
        name = AppRoutes.permissions;
      }
    } else {
      final seenIntro = await LocalStore.instance.hasSeenIntro();
      if (!context.mounted) return;
      if (seenIntro) {
        page = const WelcomeScreen();
        name = AppRoutes.welcome;
      } else {
        page = const IntroScreen();
        name = AppRoutes.intro;
      }
    }

    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        settings: RouteSettings(name: name),
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 480),
      ),
    );
  }
}
