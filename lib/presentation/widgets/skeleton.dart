import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// Shimmering placeholder block used while data loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 - 2 * (1 - _c.value), 0),
                  end: Alignment(1 + 2 * _c.value, 0),
                  colors: [p.surfaceAlt, p.border, p.surfaceAlt],
                ),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      ),
    );
  }
}

/// Card-shaped skeleton matching the app's [AppCard] geometry.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      height: height,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 14, width: 120),
          const SizedBox(height: 14),
          const SkeletonBox(height: 28, width: 180),
          const Spacer(),
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 12)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-page placeholder used by the dashboard and report tabs.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.cards = 3,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
  });

  final int cards;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        const SkeletonBox(height: 26, width: 160, radius: 10),
        const SizedBox(height: 22),
        for (var i = 0; i < cards; i++) ...[
          SkeletonCard(height: i == 0 ? 150 : 120),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
