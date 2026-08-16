import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Tinted page wash with soft out-of-focus circles behind it.
///
/// Screens layer their content on top of this instead of sitting on a flat
/// background, which is what gives the app depth on every surface.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({
    super.key,
    required this.child,
    this.blobs = const [
      AmbientBlob(top: -90, right: -70, size: 260),
      AmbientBlob(top: 180, left: -110, size: 240, opacity: 0.7),
      AmbientBlob(bottom: -120, right: -80, size: 300, opacity: 0.55),
    ],
  });

  final Widget child;
  final List<AmbientBlob> blobs;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.washTop, p.washBottom],
          stops: const [0, 0.45],
        ),
      ),
      child: Stack(
        children: [
          for (final blob in blobs) blob.build(context),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

/// Placement description for one blurred circle in [AmbientBackground].
@immutable
class AmbientBlob {
  const AmbientBlob({
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
    this.opacity = 1,
  });

  final double size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double opacity;

  Widget build(BuildContext context) {
    final p = context.palette;

    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                p.blob.withValues(alpha: p.blob.a * opacity),
                p.blob.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
