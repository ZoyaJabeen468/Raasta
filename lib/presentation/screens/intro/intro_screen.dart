import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/raasta_logo.dart';
import '../../../data/local/local_store.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

class _IntroPage {
  const _IntroPage({
    required this.title,
    required this.line,
    required this.photo,
  });

  final String title;
  final String line;
  final String photo;
}

const _pages = [
  _IntroPage(
    title: 'Road hazards',
    line: 'Spot damage before you reach it.',
    photo: 'assets/branding/intro/hazards.jpg',
  ),
  _IntroPage(
    title: 'Traffic signs',
    line: 'Reads boards aloud in English or Urdu.',
    photo: 'assets/branding/intro/signs.jpg',
  ),
  _IntroPage(
    title: 'People and animals',
    line: 'Alerts for who shares the road with you.',
    photo: 'assets/branding/intro/life.jpg',
  ),
  _IntroPage(
    title: 'Trip summary',
    line: 'Your drives, saved on this phone.',
    photo: 'assets/branding/intro/trips.jpg',
  ),
];

/// First-run onboarding: full-bleed road photography, then Sign in.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await LocalStore.instance.markIntroSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
  }

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Builder(
        builder: (context) {
          final isLast = _index >= _pages.length - 1;
          final dots = Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_pages.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 7,
                width: active ? 28 : 7,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.mint
                      : AppColors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(AppRadii.full),
                ),
              );
            }),
          );

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: AppColors.forest,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              backgroundColor: AppColors.forest,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => _IntroPhoto(page: _pages[i]),
                  ),
                  const _Scrim(),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: _index == 0 ? 0 : 1,
                                  child: IgnorePointer(
                                    ignoring: _index == 0,
                                    child: BackCircle(onTap: _back),
                                  ),
                                ),
                              ),
                              const Expanded(
                                child: Center(
                                  child: RaastaWordmark(
                                    fontSize: 13,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: TextButton(
                                  onPressed: _finish,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.mint,
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(44, 40),
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            _pages[_index].title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sora(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _pages[_index].line,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              color: AppColors.white.withValues(alpha: 0.82),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (isLast) ...[
                            dots,
                            const SizedBox(height: 22),
                            GradientButton(
                              label: 'Get started',
                              onPressed: _next,
                            ),
                          ] else
                            Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: dots,
                                  ),
                                ),
                                Material(
                                  color: AppColors.mint,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _next,
                                    child: const SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IntroPhoto extends StatelessWidget {
  const _IntroPhoto({required this.page});

  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      page.photo,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x88062E2B),
              Color(0x22062E2B),
              Color(0xE0062E2B),
            ],
            stops: [0, 0.42, 1],
          ),
        ),
      ),
    );
  }
}
