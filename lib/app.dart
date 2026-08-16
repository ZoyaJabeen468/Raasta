import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_viewport.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/driver_profile_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/trips_provider.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/signup_screen.dart';
import 'presentation/screens/drive/drive_screen.dart';
import 'presentation/screens/home/edit_profile_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/intro/intro_screen.dart';
import 'presentation/screens/onboarding/language_screen.dart';
import 'presentation/screens/onboarding/permissions_screen.dart';
import 'presentation/screens/reports/reports_screen.dart';
import 'presentation/screens/settings/change_email_screen.dart';
import 'presentation/screens/settings/change_password_screen.dart';
import 'presentation/screens/settings/delete_account_screen.dart';
import 'presentation/screens/settings/info_screen.dart';
import 'presentation/screens/settings/settings_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/welcome_screen.dart';

class RaastaApp extends StatelessWidget {
  const RaastaApp({super.key, required this.settings});

  final SettingsProvider settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TripsProvider()),
        ChangeNotifierProvider(create: (_) => DriverProfileProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, config, _) => MaterialApp(
          title: 'RAASTA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: config.themeMode,
          builder: (context, child) =>
              AppViewport(child: child ?? const SizedBox()),
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (_) => const SplashScreen(),
            AppRoutes.intro: (_) => const IntroScreen(),
            AppRoutes.welcome: (_) => const WelcomeScreen(),
            AppRoutes.login: (_) => const LoginScreen(),
            AppRoutes.signup: (_) => const SignupScreen(),
            AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
            AppRoutes.permissions: (_) => const PermissionsScreen(),
            AppRoutes.language: (_) => const LanguageScreen(),
            AppRoutes.home: (_) => const HomeScreen(),
            AppRoutes.drive: (_) => const DriveScreen(),
            AppRoutes.reports: (_) => const ReportsScreen(),
            AppRoutes.editProfile: (_) => const EditProfileScreen(),
            AppRoutes.settings: (_) => const SettingsScreen(),
            AppRoutes.changeEmail: (_) => const ChangeEmailScreen(),
            AppRoutes.changePassword: (_) => const ChangePasswordScreen(),
            AppRoutes.deleteAccount: (_) => const DeleteAccountScreen(),
            AppRoutes.about: (_) => InfoScreen.about,
            AppRoutes.faq: (_) => InfoScreen.faq,
            AppRoutes.privacy: (_) => InfoScreen.privacy,
          },
        ),
      ),
    );
  }
}
