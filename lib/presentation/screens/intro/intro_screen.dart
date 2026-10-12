import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/raasta_logo.dart';
import '../../../data/local/local_store.dart';
import '../../widgets/brand_buttons.dart';
import '../../widgets/screen_back_button.dart';

enum _IntroKind { road, signs, life, trips }

class _IntroPage {
  const _IntroPage({
    required this.kind,
    required this.title,
    required this.line,
    required this.features,
  });

  final _IntroKind kind;
  final String title;
  final String line;
  final List<_IntroFeature> features;
}

class _IntroFeature {
  const _IntroFeature({
    required this.label,
    required this.accent,
    required this.symbol,
  });

  final String label;
  final Color accent;
  final _FeatureSymbol symbol;
}

enum _FeatureSymbol {
  pothole,
  crack,
  bump,
  board,
  text,
  speak,
  person,
  animal,
  alert,
  log,
  count,
  week,
}

const _pages = [
  _IntroPage(
    kind: _IntroKind.road,
    title: 'Road hazards',
    line: 'Spot damage before you reach it.',
    features: [
      _IntroFeature(
        label: 'Potholes',
        accent: Color(0xFFC45C26),
        symbol: _FeatureSymbol.pothole,
      ),
      _IntroFeature(
        label: 'Cracks',
        accent: Color(0xFFB8860B),
        symbol: _FeatureSymbol.crack,
      ),
      _IntroFeature(
        label: 'Bumps',
        accent: Color(0xFF2F7D6D),
        symbol: _FeatureSymbol.bump,
      ),
    ],
  ),
  _IntroPage(
    kind: _IntroKind.signs,
    title: 'Traffic signs',
    line: 'Reads boards aloud in English or Urdu.',
    features: [
      _IntroFeature(
        label: 'Detect',
        accent: Color(0xFF2F6FED),
        symbol: _FeatureSymbol.board,
      ),
      _IntroFeature(
        label: 'Read',
        accent: Color(0xFF5B4FC9),
        symbol: _FeatureSymbol.text,
      ),
      _IntroFeature(
        label: 'Speak',
        accent: Color(0xFF0F8A82),
        symbol: _FeatureSymbol.speak,
      ),
    ],
  ),
  _IntroPage(
    kind: _IntroKind.life,
    title: 'People and animals',
    line: 'Alerts for who shares the road with you.',
    features: [
      _IntroFeature(
        label: 'People',
        accent: Color(0xFF3B82C4),
        symbol: _FeatureSymbol.person,
      ),
      _IntroFeature(
        label: 'Animals',
        accent: Color(0xFF8B6B3D),
        symbol: _FeatureSymbol.animal,
      ),
      _IntroFeature(
        label: 'Alerts',
        accent: Color(0xFF2F9E6B),
        symbol: _FeatureSymbol.alert,
      ),
    ],
  ),
  _IntroPage(
    kind: _IntroKind.trips,
    title: 'Trip summary',
    line: 'Your drives, saved on this phone.',
    features: [
      _IntroFeature(
        label: 'Trips',
        accent: Color(0xFF0F8A82),
        symbol: _FeatureSymbol.log,
      ),
      _IntroFeature(
        label: 'Hazards',
        accent: Color(0xFFD64545),
        symbol: _FeatureSymbol.count,
      ),
      _IntroFeature(
        label: 'Weekly',
        accent: Color(0xFF3B82C4),
        symbol: _FeatureSymbol.week,
      ),
    ],
  ),
];

/// First-run product intro inspired by minimal premium onboarding layouts.
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
    final p = context.palette;
    final isLast = _index >= _pages.length - 1;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.washTop, p.washBottom, p.background],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: _AmbientBlob(
                size: 220,
                color: p.blob,
              ),
            ),
            Positioned(
              bottom: 120,
              left: -70,
              child: _AmbientBlob(
                size: 200,
                color: p.blob.withValues(alpha: 0.55),
              ),
            ),
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
                            child: RaastaWordmark(fontSize: 13),
                          ),
                        ),
                        SizedBox(
                          width: 44,
                          child: TextButton(
                            onPressed: _finish,
                            style: TextButton.styleFrom(
                              foregroundColor: p.textSecondary,
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
                    Expanded(
                      child: PageView.builder(
                        controller: _controller,
                        itemCount: _pages.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) =>
                            _IntroSlide(page: _pages[i], key: ValueKey(i)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 7,
                          width: active ? 28 : 7,
                          decoration: BoxDecoration(
                            color: active ? p.brand : p.border,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    GradientButton(
                      label: isLast ? 'Get started' : 'Continue',
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientBlob extends StatelessWidget {
  const _AmbientBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
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
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    final scale = Tween<double>(begin: 0.96, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: rise,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 580;
            final heroH = short ? 200.0 : 248.0;
            final titleSize = short ? 24.0 : 28.0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: scale,
                      child: _HeroStage(
                        kind: widget.page.kind,
                        height: heroH,
                      ),
                    ),
                    SizedBox(height: short ? 22 : 28),
                    Text(
                      widget.page.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.sora(
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                        height: 1.15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.page.line,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: short ? 14 : 15,
                        color: p.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: short ? 16 : 20),
                    Row(
                      children: [
                        for (var i = 0;
                            i < widget.page.features.length;
                            i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _SlimChip(
                              feature: widget.page.features[i],
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: short ? 8 : 12),
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

/// Large floating hero card (fintech/minimal onboarding focus).
class _HeroStage extends StatelessWidget {
  const _HeroStage({required this.kind, required this.height});

  final _IntroKind kind;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _ScenePainter(kind: kind, palette: p),
          ),
          // Soft bottom fade for depth, like premium mock compositions.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.28,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    p.surface.withValues(alpha: 0),
                    p.surface.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim feature chip: tinted icon tile + short label.
class _SlimChip extends StatelessWidget {
  const _SlimChip({required this.feature});

  final _IntroFeature feature;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: feature.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(
              painter: _SymbolPainter(
                symbol: feature.symbol,
                color: feature.accent,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            feature.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.textPrimary,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.kind, required this.palette});

  final _IntroKind kind;
  final AppPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          palette.brandSoft,
          palette.surfaceAlt,
          palette.surface,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    switch (kind) {
      case _IntroKind.road:
        _paintRoadScene(canvas, size);
      case _IntroKind.signs:
        _paintSignScene(canvas, size);
      case _IntroKind.life:
        _paintLifeScene(canvas, size);
      case _IntroKind.trips:
        _paintTripScene(canvas, size);
    }
  }

  void _paintRoadScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final road = Path()
      ..moveTo(w * 0.36, h * 0.38)
      ..lineTo(w * 0.64, h * 0.38)
      ..lineTo(w * 1.08, h)
      ..lineTo(w * -0.08, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF3A4450));

    final edge = Paint()
      ..color = const Color(0xFFE8ECF0)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.36, h * 0.38), Offset(w * 0.06, h), edge);
    canvas.drawLine(Offset(w * 0.64, h * 0.38), Offset(w * 0.94, h), edge);

    final dash = Paint()
      ..color = const Color(0xFFF0C94A)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.5, h * 0.50), Offset(w * 0.5, h * 0.60), dash);
    canvas.drawLine(Offset(w * 0.5, h * 0.70), Offset(w * 0.5, h * 0.84), dash);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.33, h * 0.70),
        width: w * 0.13,
        height: h * 0.07,
      ),
      Paint()..color = const Color(0xFF1E242B),
    );

    final crack = Path()
      ..moveTo(w * 0.58, h * 0.56)
      ..lineTo(w * 0.63, h * 0.65)
      ..lineTo(w * 0.59, h * 0.73)
      ..lineTo(w * 0.66, h * 0.84);
    canvas.drawPath(
      crack,
      Paint()
        ..color = const Color(0xFFD6B26A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );

    final bump = Path()
      ..moveTo(w * 0.26, h * 0.88)
      ..quadraticBezierTo(w * 0.5, h * 0.76, w * 0.74, h * 0.88);
    canvas.drawPath(
      bump,
      Paint()
        ..color = const Color(0xFF9AA3AD)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintSignScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.78, w, h * 0.22),
      Paint()..color = const Color(0xFF4F6B5E).withValues(alpha: 0.32),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, h * 0.62),
          width: 9,
          height: h * 0.44,
        ),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF6B7580),
    );

    final board = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.34),
        width: w * 0.44,
        height: h * 0.34,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(board, Paint()..color = AppColors.white);
    canvas.drawRRect(
      board,
      Paint()
        ..color = const Color(0xFF2F6FED)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2,
    );

    final line = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.35, h * 0.26),
      Offset(w * 0.65, h * 0.26),
      line,
    );
    canvas.drawLine(
      Offset(w * 0.35, h * 0.34),
      Offset(w * 0.58, h * 0.34),
      line..color = const Color(0xFF64748B),
    );
    canvas.drawLine(
      Offset(w * 0.35, h * 0.42),
      Offset(w * 0.63, h * 0.42),
      line..color = const Color(0xFF334155),
    );

    final arc = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.80, h * 0.32),
        width: 30,
        height: 30,
      ),
      -0.9,
      1.8,
      false,
      arc,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.80, h * 0.32),
        width: 48,
        height: 48,
      ),
      -0.9,
      1.8,
      false,
      arc..color = AppColors.teal.withValues(alpha: 0.4),
    );
  }

  void _paintLifeScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final road = Path()
      ..moveTo(w * 0.42, h * 0.46)
      ..lineTo(w * 0.58, h * 0.46)
      ..lineTo(w * 1.04, h)
      ..lineTo(w * -0.04, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF3A4450));

    final personFill = Paint()..color = const Color(0xFF1E3A5F);
    final personStroke = Paint()
      ..color = const Color(0xFF1E3A5F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(w * 0.24, h * 0.44), 8, personFill);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.24, h * 0.57),
          width: 13,
          height: 24,
        ),
        const Radius.circular(4),
      ),
      personFill,
    );
    canvas.drawLine(
      Offset(w * 0.24, h * 0.68),
      Offset(w * 0.19, h * 0.82),
      personStroke,
    );
    canvas.drawLine(
      Offset(w * 0.24, h * 0.68),
      Offset(w * 0.29, h * 0.82),
      personStroke,
    );

    final animalFill = Paint()..color = const Color(0xFF6B4F2E);
    final animalStroke = Paint()
      ..color = const Color(0xFF6B4F2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.74, h * 0.60),
        width: 50,
        height: 26,
      ),
      animalFill,
    );
    canvas.drawCircle(Offset(w * 0.91, h * 0.54), 11, animalFill);
    canvas.drawLine(
      Offset(w * 0.63, h * 0.70),
      Offset(w * 0.63, h * 0.84),
      animalStroke,
    );
    canvas.drawLine(
      Offset(w * 0.83, h * 0.70),
      Offset(w * 0.83, h * 0.84),
      animalStroke,
    );

    final badge = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.42, h * 0.16, w * 0.16, h * 0.14),
      const Radius.circular(12),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xFFD64545));
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.205),
      2.4,
      Paint()..color = AppColors.white,
    );
    canvas.drawLine(
      Offset(w * 0.5, h * 0.228),
      Offset(w * 0.5, h * 0.268),
      Paint()
        ..color = AppColors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTripScene(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.13, h * 0.14, w * 0.74, h * 0.70),
      const Radius.circular(18),
    );
    canvas.drawRRect(card, Paint()..color = AppColors.white);
    canvas.drawRRect(
      card,
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.13, h * 0.14, w * 0.74, h * 0.13),
        const Radius.circular(18),
      ),
      Paint()..color = AppColors.tealDeep,
    );
    canvas.drawRect(
      Rect.fromLTWH(w * 0.13, h * 0.21, w * 0.74, h * 0.06),
      Paint()..color = AppColors.tealDeep,
    );

    final bars = <double>[0.26, 0.44, 0.36, 0.58, 0.40];
    for (var i = 0; i < bars.length; i++) {
      final bx = w * 0.22 + i * w * 0.12;
      final bh = h * bars[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, h * 0.74 - bh, w * 0.07, bh),
          const Radius.circular(4),
        ),
        Paint()
          ..color = i == 3
              ? AppColors.teal
              : AppColors.teal.withValues(alpha: 0.32),
      );
    }

    canvas.drawCircle(
      Offset(w * 0.28, h * 0.36),
      4.5,
      Paint()..color = const Color(0xFFD64545),
    );
    canvas.drawCircle(
      Offset(w * 0.40, h * 0.36),
      4.5,
      Paint()..color = const Color(0xFFE8A317),
    );
    canvas.drawCircle(
      Offset(w * 0.52, h * 0.36),
      4.5,
      Paint()..color = const Color(0xFF2F9E6B),
    );
  }

  @override
  bool shouldRepaint(covariant _ScenePainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.palette != palette;
  }
}

class _SymbolPainter extends CustomPainter {
  _SymbolPainter({required this.symbol, required this.color});

  final _FeatureSymbol symbol;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (symbol) {
      case _FeatureSymbol.pothole:
        canvas.drawOval(
          Rect.fromCenter(center: c, width: 16, height: 10),
          fill,
        );
      case _FeatureSymbol.crack:
        final path = Path()
          ..moveTo(c.dx - 8, c.dy + 6)
          ..lineTo(c.dx - 2, c.dy - 2)
          ..lineTo(c.dx + 3, c.dy + 3)
          ..lineTo(c.dx + 8, c.dy - 6);
        canvas.drawPath(path, stroke);
      case _FeatureSymbol.bump:
        final path = Path()
          ..moveTo(c.dx - 10, c.dy + 5)
          ..quadraticBezierTo(c.dx, c.dy - 8, c.dx + 10, c.dy + 5);
        canvas.drawPath(path, stroke..strokeWidth = 2.2);
      case _FeatureSymbol.board:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c.translate(0, -1), width: 14, height: 12),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawLine(Offset(c.dx, c.dy + 5), Offset(c.dx, c.dy + 10), stroke);
      case _FeatureSymbol.text:
        canvas.drawLine(
          Offset(c.dx - 7, c.dy - 4),
          Offset(c.dx + 7, c.dy - 4),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 7, c.dy),
          Offset(c.dx + 4, c.dy),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 7, c.dy + 4),
          Offset(c.dx + 7, c.dy + 4),
          stroke,
        );
      case _FeatureSymbol.speak:
        canvas.drawCircle(c.translate(-3, 0), 3.5, fill);
        canvas.drawArc(
          Rect.fromCenter(center: c.translate(-1, 0), width: 14, height: 14),
          -0.8,
          1.6,
          false,
          stroke,
        );
      case _FeatureSymbol.person:
        canvas.drawCircle(Offset(c.dx, c.dy - 5), 3, fill);
        canvas.drawLine(
          Offset(c.dx, c.dy - 1),
          Offset(c.dx, c.dy + 5),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 5, c.dy + 1),
          Offset(c.dx + 5, c.dy + 1),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy + 5),
          Offset(c.dx - 4, c.dy + 10),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx, c.dy + 5),
          Offset(c.dx + 4, c.dy + 10),
          stroke,
        );
      case _FeatureSymbol.animal:
        canvas.drawOval(
          Rect.fromCenter(center: c.translate(0, 1), width: 14, height: 8),
          fill,
        );
        canvas.drawCircle(Offset(c.dx + 7, c.dy - 2), 2.8, fill);
      case _FeatureSymbol.alert:
        final path = Path()
          ..moveTo(c.dx, c.dy - 8)
          ..lineTo(c.dx + 8, c.dy + 7)
          ..lineTo(c.dx - 8, c.dy + 7)
          ..close();
        canvas.drawPath(path, stroke);
        canvas.drawCircle(Offset(c.dx, c.dy + 4), 1.2, fill);
        canvas.drawLine(
          Offset(c.dx, c.dy - 2),
          Offset(c.dx, c.dy + 1.5),
          stroke..strokeWidth = 1.6,
        );
      case _FeatureSymbol.log:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: 12, height: 16),
            const Radius.circular(2),
          ),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 3, c.dy - 3),
          Offset(c.dx + 3, c.dy - 3),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx - 3, c.dy + 1),
          Offset(c.dx + 3, c.dy + 1),
          stroke,
        );
      case _FeatureSymbol.count:
        canvas.drawCircle(c, 7, stroke);
        final tp = TextPainter(
          text: TextSpan(
            text: '3',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
      case _FeatureSymbol.week:
        canvas.drawLine(
          Offset(c.dx - 7, c.dy + 6),
          Offset(c.dx - 7, c.dy + 1),
          stroke..strokeWidth = 2.4,
        );
        canvas.drawLine(
          Offset(c.dx - 2, c.dy + 6),
          Offset(c.dx - 2, c.dy - 3),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx + 3, c.dy + 6),
          Offset(c.dx + 3, c.dy - 6),
          stroke,
        );
        canvas.drawLine(
          Offset(c.dx + 8, c.dy + 6),
          Offset(c.dx + 8, c.dy - 1),
          stroke,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter oldDelegate) {
    return oldDelegate.symbol != symbol || oldDelegate.color != color;
  }
}
