import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/raasta_logo.dart';
import '../../../data/local/local_store.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

class _IntroPage {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.line,
    required this.chips,
  });

  final IconData icon;
  final String title;
  final String line;
  final List<String> chips;
}

const _pages = [
  _IntroPage(
    icon: Icons.videocam_rounded,
    title: 'See ahead',
    line: 'Hazards spotted before you reach them.',
    chips: ['Potholes', 'Speed bumps'],
  ),
  _IntroPage(
    icon: Icons.campaign_rounded,
    title: 'Hear alerts',
    line: 'Spoken warnings that keep your eyes on the road.',
    chips: ['English & Urdu'],
  ),
  _IntroPage(
    icon: Icons.insights_rounded,
    title: 'Drive better',
    line: 'Every trip scored and summarised for you.',
    chips: ['Safety score'],
  ),
];

/// First-run intro — three short screens, skippable, with a back step.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _index = 0;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _scheduleAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAuto() {
    _auto?.cancel();
    _auto = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_index >= _pages.length - 1) return;
      _next();
    });
  }

  Future<void> _finish() async {
    _auto?.cancel();
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
    final p = context.palette;
    final isLast = _index >= _pages.length - 1;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _index == 0 ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _index == 0,
                      child: BackCircle(onTap: _back),
                    ),
                  ),
                  const Spacer(),
                  RaastaWordmark(fontSize: 14, color: p.brand),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      foregroundColor: p.textSecondary,
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    _scheduleAuto();
                  },
                  itemBuilder: (context, i) =>
                      _IntroSlide(page: _pages[i], key: ValueKey(i)),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    width: active ? 26 : 6,
                    decoration: BoxDecoration(
                      color: active ? p.brand : p.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),
              GradientButton(
                label: isLast ? 'Get started' : 'Continue',
                icon: isLast ? Icons.arrow_forward_rounded : null,
                onPressed: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSlide extends StatefulWidget {
  const _IntroSlide({super.key, required this.page});

  final _IntroPage page;

  @override
  State<_IntroSlide> createState() => _IntroSlideState();
}

class _IntroSlideState extends State<_IntroSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    final rise = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: rise,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 520;
            final tile = short ? 120.0 : 176.0;
            final titleSize = short ? 26.0 : 32.0;
            final gap = short ? 24.0 : 44.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _IllustrationTile(icon: widget.page.icon, size: tile),
                    SizedBox(height: gap),
                    Text(
                      widget.page.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.page.line,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: short ? 14.5 : 16,
                        color: p.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final chip in widget.page.chips)
                          _Chip(label: chip),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  const _IllustrationTile({required this.icon, this.size = 176});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final inner = size * 0.73;
    final radius = size * 0.32;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: p.brandSoft,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
          Container(
            width: inner,
            height: inner,
            decoration: BoxDecoration(
              gradient: AppColors.driveGradient,
              borderRadius: BorderRadius.circular(radius * 0.72),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.32),
                  blurRadius: size * 0.17,
                  offset: Offset(0, size * 0.09),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.white,
              size: size * 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: p.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: p.brand,
        ),
      ),
    );
  }
}
