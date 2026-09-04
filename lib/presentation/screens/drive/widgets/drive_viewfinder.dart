import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/hazard_detector.dart';

/// Live camera feed for the drive screen, with a branded fallback when no
/// camera is available (web preview, emulator, denied permission).
class DriveViewfinder extends StatefulWidget {
  const DriveViewfinder({
    super.key,
    required this.active,
    this.onCameraReady,
    this.boxes = const [],
  });

  /// Whether detection is running — drives the scan animation.
  final bool active;

  /// Called once the rear camera controller is initialized (or null on failure).
  final ValueChanged<CameraController?>? onCameraReady;

  /// Normalized hazard boxes to draw over the live preview.
  final List<HazardDetection> boxes;

  @override
  State<DriveViewfinder> createState() => _DriveViewfinderState();
}

class _DriveViewfinderState extends State<DriveViewfinder> {
  CameraController? _controller;
  bool _initializing = true;
  bool _failed = false;

  CameraDescription _pickWidestBackCamera(List<CameraDescription> cameras) {
    final backs = cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();
    if (backs.isEmpty) return cameras.first;

    int score(CameraDescription c) {
      final n = c.name.toLowerCase();
      if (n.contains('ultra') || n.contains('uw')) return 3;
      if (n.contains('wide') || n.contains('0.5') || n.contains('0_5')) {
        return 2;
      }
      if (n.contains('tele') || n.contains('zoom')) return 0;
      return 1;
    }

    backs.sort((a, b) => score(b).compareTo(score(a)));
    return backs.first;
  }

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _failed = true);
        widget.onCameraReady?.call(null);
        return;
      }
      final back = _pickWidestBackCamera(cameras);
      // low keeps preview + YOLO responsive. medium made mid-range phones hang
      // because image-stream frames are huge to convert every inference.
      final controller = CameraController(
        back,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      // Widest FOV so more of the road is in frame.
      try {
        final minZoom = await controller.getMinZoomLevel();
        await controller.setZoomLevel(minZoom);
      } catch (_) {}
      // Locked focus = less AF hunting jank while driving.
      try {
        await controller.setFocusMode(FocusMode.locked);
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      setState(() {
        _controller = controller;
        _initializing = false;
      });
      widget.onCameraReady?.call(controller);
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _initializing = false;
        });
      }
      widget.onCameraReady?.call(null);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    Widget feed;
    if (controller != null && controller.value.isInitialized) {
      // Portrait phone + wide camera strip (like dashcam apps):
      // fill width, keep natural aspect → sharp image, black bars top/bottom.
      // BoxFit.cover on low-res was what made the feed look blurry.
      final ar = controller.value.aspectRatio;
      final bandAr = ar >= 1 ? ar : 1 / ar;
      feed = ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: bandAr,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                if (widget.boxes.isNotEmpty)
                  CustomPaint(
                    painter: _HazardBoxesPainter(widget.boxes),
                  ),
              ],
            ),
          ),
        ),
      );
    } else if (_initializing && !_failed) {
      feed = const _RoadBackdrop(
        child: Center(
          child: CircularProgressIndicator(color: Colors.white70),
        ),
      );
    } else {
      feed = const _RoadBackdrop(child: _NoCameraNote());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        feed,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Light veil only — heavy black made the road look soft/blurry.
              colors: [Color(0x66000000), Color(0x00000000), Color(0x88000000)],
              stops: [0, 0.35, 1],
            ),
          ),
        ),
        if (widget.active) const _ScanLine(),
      ],
    );
  }
}

class _HazardBoxesPainter extends CustomPainter {
  _HazardBoxesPainter(this.boxes);

  final List<HazardDetection> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      if (!box.hasBox) continue;
      final rect = Rect.fromLTRB(
        box.left! * size.width,
        box.top! * size.height,
        box.right! * size.width,
        box.bottom! * size.height,
      );
      if (rect.width < 4 || rect.height < 4) continue;

      final color = box.type.color;

      // Soft fill
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.fill
          ..color = color.withValues(alpha: 0.18),
      );

      // Dark outline for contrast on bright roads
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.5
          ..color = Colors.black.withValues(alpha: 0.55),
      );
      // Colored frame
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = color,
      );

      // Bold corner brackets (demo / FYP look)
      final corner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..color = color;
      final c = (rect.shortestSide * 0.22).clamp(14.0, 28.0);
      void bracket(Offset o, double dx, double dy) {
        canvas.drawLine(o, o.translate(dx, 0), corner);
        canvas.drawLine(o, o.translate(0, dy), corner);
      }

      bracket(rect.topLeft, c, c);
      bracket(rect.topRight, -c, c);
      bracket(rect.bottomLeft, c, -c);
      bracket(rect.bottomRight, -c, -c);

      final pct = (box.confidence * 100).clamp(0, 99).round();
      final dist = box.distanceMeters;
      final label = dist != null
          ? '${box.type.label}  $pct%  ·  ${dist.round()}m'
          : '${box.type.label}  $pct%';

      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.left,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          maxLines: 1,
          ellipsis: '…',
        ),
      )
        ..pushStyle(ui.TextStyle(color: Colors.white))
        ..addText(label);
      final paragraph = builder.build()
        ..layout(ui.ParagraphConstraints(width: size.width * 0.85));

      final tagW = paragraph.maxIntrinsicWidth + 20;
      final tagH = paragraph.height + 10;
      var tagTop = rect.top - tagH - 6;
      if (tagTop < 4) tagTop = rect.top + 6;
      final tagLeft = rect.left.clamp(4.0, size.width - tagW - 4);

      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tagLeft, tagTop, tagW, tagH),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        tagRect,
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      canvas.drawRRect(tagRect, Paint()..color = color);
      canvas.drawParagraph(
        paragraph,
        Offset(tagLeft + 10, tagTop + 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HazardBoxesPainter oldDelegate) {
    if (oldDelegate.boxes.length != boxes.length) return true;
    for (var i = 0; i < boxes.length; i++) {
      final a = oldDelegate.boxes[i];
      final b = boxes[i];
      if (a.type != b.type ||
          a.left != b.left ||
          a.top != b.top ||
          a.right != b.right ||
          a.bottom != b.bottom ||
          a.confidence != b.confidence ||
          a.distanceMeters != b.distanceMeters) {
        return true;
      }
    }
    return false;
  }
}

class _RoadBackdrop extends StatelessWidget {
  const _RoadBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF10201F), Color(0xFF0A1514)],
        ),
      ),
      child: CustomPaint(
        painter: _PerspectiveRoadPainter(),
        child: child,
      ),
    );
  }
}

class _NoCameraNote extends StatelessWidget {
  const _NoCameraNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              kIsWeb ? 'Camera preview unavailable' : 'No camera found',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Detection is simulated here. Run on your phone for the live '
              'camera feed.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerspectiveRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizon = h * 0.42;

    final road = Path()
      ..moveTo(w * 0.42, horizon)
      ..lineTo(w * 0.58, horizon)
      ..lineTo(w * 0.95, h)
      ..lineTo(w * 0.05, h)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF16302E));

    final dash = Paint()
      ..color = const Color(0x33FFFFFF)
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final t = i / 5;
      final y = horizon + (h - horizon) * (t * t);
      final len = (h - horizon) * 0.05 * (t + 0.3);
      dash.strokeWidth = w * (0.006 + 0.02 * t);
      canvas.drawLine(Offset(w * 0.5, y), Offset(w * 0.5, y + len), dash);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Align(
          alignment: Alignment(0, -1 + _c.value * 2),
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.tealBright.withValues(alpha: 0),
                  AppColors.tealBright.withValues(alpha: 0.9),
                  AppColors.tealBright.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
