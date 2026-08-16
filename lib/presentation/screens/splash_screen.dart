import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/auth_navigator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/raasta_logo.dart';
import '../providers/auth_provider.dart';

/// Brand splash. Holds briefly so the first open feels calm,
/// then fades into the next screen (no hard cut).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _exit;
  late final AnimationController _road;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  String _status = 'Starting up';
  bool _failed = false;

  /// Full brand hold on a cold open.
  static const _minSplash = Duration(milliseconds: 2800);

  /// Shorter when a session is already restored.
  static const _minReadySplash = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _road = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _logoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );
    _textSlide =
        Tween<Offset>(
          begin: const Offset(0, 0.35),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _enter,
            curve: const Interval(0.35, 1, curve: Curves.easeOutCubic),
          ),
        );

    _enter.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  void _setStatus(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _boot() async {
    setState(() => _failed = false);
    final auth = context.read<AuthProvider>();
    final started = DateTime.now();

    try {
      _setStatus('Loading…');
      await auth.bootstrap();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _status = 'Could not start';
      });
      return;
    }

    final alreadyReady = auth.isLoggedIn || !auth.isBooting;
    final hold = alreadyReady && auth.isLoggedIn
        ? _minReadySplash
        : _minSplash;

    final elapsed = DateTime.now().difference(started);
    final remaining = hold - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
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
    _road.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _exit, curve: Curves.easeInOut),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.splashGradient),
          child: Stack(
            children: [
              const Positioned.fill(child: _GlowBackdrop()),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _road,
                          builder: (context, _) =>
                              RaastaLogo(size: 116, dashPhase: _road.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _textFade,
                      child: SlideTransition(
                        position: _textSlide,
                        child: Column(
                          children: [
                            const RaastaWordmark(
                              fontSize: 32,
                              color: AppColors.white,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Know the road before you reach it.',
                              style: GoogleFonts.dmSans(
                                color: AppColors.white.withValues(alpha: 0.88),
                                fontSize: 14.5,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          if (!_failed) _LoadingBar(animation: _road),
                          if (!_failed) const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            child: Text(
                              _status,
                              key: ValueKey(_status),
                              style: GoogleFonts.dmSans(
                                color: AppColors.white.withValues(alpha: 0.7),
                                fontSize: 12.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (_failed) ...[
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: _boot,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.white,
                              ),
                              child: const Text('Try again'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
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
          child: _Glow(size: 280, opacity: 0.18),
        ),
        Positioned(
          bottom: -140,
          left: -90,
          child: _Glow(size: 320, opacity: 0.14),
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

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            return Stack(
              children: [
                Container(color: AppColors.white.withValues(alpha: 0.22)),
                Align(
                  alignment: Alignment(-1 + animation.value * 2, 0),
                  child: Container(
                    width: 34,
                    color: AppColors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
