import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/auth_navigator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/raasta_logo.dart';
import '../providers/auth_provider.dart';

/// Brand splash. Logo, then wordmark, then tagline. No loader bar.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  late final Animation<double> _logoScale;
  late final Animation<double> _wordFade;
  late final Animation<Offset> _wordSlide;
  late final Animation<double> _tagFade;
  late final Animation<Offset> _tagSlide;

  bool _failed = false;

  static const _minSplash = Duration(milliseconds: 4600);
  static const _minReadySplash = Duration(milliseconds: 3600);
  static const _maxColdSplash = Duration(milliseconds: 5600);

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0B5E57),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _logoScale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0, 0.28, curve: Curves.easeOutCubic),
      ),
    );
    _wordFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.46, curve: Curves.easeOut),
    );
    _wordSlide = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.18, 0.46, curve: Curves.easeOutCubic),
      ),
    );
    _tagFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.48, 0.82, curve: Curves.easeOut),
    );
    _tagSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.48, 0.82, curve: Curves.easeOutCubic),
      ),
    );

    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    final auth = context.read<AuthProvider>();
    final started = DateTime.now();

    try {
      await auth.bootstrap();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
      return;
    }

    final bootstrapMs = DateTime.now().difference(started).inMilliseconds;
    final alreadyReady = auth.isLoggedIn || !auth.isBooting;
    final isWarm = alreadyReady && auth.isLoggedIn;
    var hold = isWarm ? _minReadySplash : _minSplash;

    if (!isWarm) {
      final elapsed = Duration(milliseconds: bootstrapMs);
      final remainingToCap = _maxColdSplash - elapsed;
      if (remainingToCap < hold) {
        hold = remainingToCap > Duration.zero ? remainingToCap : Duration.zero;
      }
    }

    final elapsed = DateTime.now().difference(started);
    final remaining = hold - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }

    if (kDebugMode) {
      debugPrint(
        'Splash timing: bootstrap=${bootstrapMs}ms warm=$isWarm',
      );
    }

    if (!mounted) return;
    await _exit.forward();
    if (!mounted) return;
    await AuthNavigator.afterSplash(context, auth);
  }

  @override
  void dispose() {
    _enter.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.tealDeep,
      body: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _exit, curve: Curves.easeInOut),
        ),
        child: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.splashGradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const _GlowBackdrop(),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),
                      ScaleTransition(
                        scale: _logoScale,
                        child: const RaastaLogo(
                          size: 120,
                          circular: true,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _wordFade,
                        child: SlideTransition(
                          position: _wordSlide,
                          child: const RaastaWordmark(
                            fontSize: 32,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _tagFade,
                        child: SlideTransition(
                          position: _tagSlide,
                          child: Text(
                            'Know the road before you reach it.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              color: AppColors.white.withValues(alpha: 0.88),
                              fontSize: 14.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      if (_failed)
                        TextButton(
                          onPressed: _boot,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Try again'),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBackdrop extends StatelessWidget {
  const _GlowBackdrop();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          top: -120,
          right: -80,
          child: _Glow(size: 280, opacity: 0.08),
        ),
        Positioned(
          bottom: -140,
          left: -90,
          child: _Glow(size: 320, opacity: 0.06),
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
