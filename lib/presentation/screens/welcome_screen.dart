import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/navigation/auth_navigator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/widgets/raasta_logo.dart';
import '../../data/services/auth_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/brand_buttons.dart';
import '../widgets/firebase_setup_banner.dart';

/// Landing screen — brand first, then the sign-in sheet rises in smoothly
/// (no hard split snap on open).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  SocialProvider? _pending;
  late final AnimationController _sheet;
  late final Animation<Offset> _sheetSlide;
  late final Animation<double> _sheetFade;
  late final Animation<double> _heroScale;

  @override
  void initState() {
    super.initState();
    _sheet = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _sheetSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheet, curve: Curves.easeOutCubic));
    _sheetFade = CurvedAnimation(
      parent: _sheet,
      curve: const Interval(0.05, 1, curve: Curves.easeOut),
    );
    _heroScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _sheet, curve: Curves.easeOutCubic),
    );

    // Let the brand land first, then raise the actions panel.
    Future<void>.delayed(const Duration(milliseconds: 480), () {
      if (mounted) _sheet.forward();
    });
  }

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  Future<void> _social(SocialProvider provider) async {
    setState(() => _pending = provider);

    final auth = context.read<AuthProvider>();
    final ok = await auth.signInWithProvider(provider);

    if (!mounted) return;
    setState(() => _pending = null);

    if (ok) {
      await AuthNavigator.afterAuth(
        context,
        auth,
        isNewUser: auth.isNewAccount,
      );
    } else if (auth.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(auth.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final busy = _pending != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final short = constraints.maxHeight < 640;
              final heroFlex = short ? 38 : 44;
              final sheetFlex = 100 - heroFlex;

              return Column(
                children: [
                  Expanded(
                    flex: heroFlex,
                    child: ScaleTransition(
                      scale: _heroScale,
                      child: const _BrandHero(),
                    ),
                  ),
                  Expanded(
                    flex: sheetFlex,
                    child: FadeTransition(
                      opacity: _sheetFade,
                      child: SlideTransition(
                        position: _sheetSlide,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: p.background,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(28),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 24,
                                offset: const Offset(0, -8),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              short ? 18 : 28,
                              24,
                              28,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    width: 40,
                                    height: 4,
                                    margin: EdgeInsets.only(
                                      bottom: short ? 12 : 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: p.border,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ),
                                const FirebaseSetupBanner(),
                                SocialButton(
                                  label: 'Continue with Google',
                                  glyph: const GoogleGlyph(),
                                  loading: _pending == SocialProvider.google,
                                  onPressed: busy
                                      ? null
                                      : () => _social(SocialProvider.google),
                                ),
                                const SizedBox(height: 12),
                                SocialButton(
                                  label: 'Continue with Facebook',
                                  glyph: const FacebookGlyph(),
                                  loading: _pending == SocialProvider.facebook,
                                  onPressed: busy
                                      ? null
                                      : () => _social(SocialProvider.facebook),
                                ),
                                const SizedBox(height: 22),
                                const LabelledDivider(label: 'or'),
                                const SizedBox(height: 22),
                                GradientButton(
                                  label: 'Create an account',
                                  icon: Icons.mail_outline_rounded,
                                  onPressed: busy
                                      ? null
                                      : () => Navigator.of(context).pushNamed(
                                            AppRoutes.signup,
                                          ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Already have an account? ',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 14,
                                        color: p.textSecondary,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => Navigator.of(
                                                context,
                                              ).pushNamed(AppRoutes.login),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: const Size(0, 40),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        'Sign in',
                                        style: GoogleFonts.dmSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: p.brand,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const _LegalNote(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = GoogleFonts.dmSans(
      fontSize: 11.5,
      height: 1.5,
      color: p.textSecondary.withValues(alpha: 0.85),
    );
    final link = base.copyWith(
      color: p.brand,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: p.brand,
    );

    void open(String route) => Navigator.of(context).pushNamed(route);

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => open(AppRoutes.privacy),
          ),
          const TextSpan(text: '. Learn more in '),
          TextSpan(
            text: 'About',
            style: link,
            recognizer: TapGestureRecognizer()
              ..onTap = () => open(AppRoutes.about),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -50,
          child: _Glow(size: 230, opacity: 0.16),
        ),
        Positioned(
          bottom: -40,
          left: -60,
          child: _Glow(size: 220, opacity: 0.12),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RaastaLogo(size: 96),
              const SizedBox(height: 26),
              const RaastaWordmark(fontSize: 30, color: AppColors.white),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Know the road before you reach it.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    height: 1.4,
                    letterSpacing: 0.1,
                    color: AppColors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.white.withValues(alpha: opacity),
            AppColors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
