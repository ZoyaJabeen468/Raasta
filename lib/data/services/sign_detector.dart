import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/traffic_sign.dart';
import 'sign_interpreter.dart';

export 'sign_interpreter.dart' show SignDetection;

/// Module 3: confirms traffic signs from shared camera frames.
///
/// Does not own the camera. Frames are pushed in via [onCameraFrame] (wired
/// to [CameraYoloHazardDetector.onFrameTap]) so the camera is opened once.
///
/// A sign is emitted on [detections] only when it is seen in
/// [requiredStreak] consecutive inferences and hasn't been emitted in the
/// last [signCooldown]. [SignAction.ignore] classes are never emitted.
class SignDetector {
  SignDetector({SignInterpreter? interpreter})
    : _model = interpreter ?? SignInterpreter();

  final SignInterpreter _model;
  final _controller = StreamController<SignDetection>.broadcast();

  static const minInferGap = Duration(milliseconds: 2500);
  static const requiredStreak = 3;
  static const signCooldown = Duration(seconds: 20);
  static const confThreshold = SignInterpreter.confThreshold;

  bool _running = false;
  bool _busy = false;
  DateTime? _lastInferAt;
  DateTime? _lastDebugLog;
  final Map<TrafficSign, int> _streak = {};
  final Map<TrafficSign, DateTime> _lastEmitAt = {};

  Stream<SignDetection> get detections => _controller.stream;
  bool get isReady => _model.isReady;
  double get debugPeakScore => _model.lastPeakScore;
  String get debugPeakLabel => _model.lastPeakLabel;

  /// Loads the model. Returns false on web or if the model fails to load;
  /// in that case frames are ignored.
  Future<bool> start() async {
    if (_running) return true;
    final loaded = await _model.load();
    _running = loaded;
    return loaded;
  }

  Future<void> stop() async {
    _running = false;
    _streak.clear();
    _lastEmitAt.clear();
    _lastInferAt = null;
  }

  void dispose() {
    _running = false;
    _model.close();
    _controller.close();
  }

  /// Called from the camera image-stream callback. Copies the frame and
  /// returns immediately; inference runs afterwards.
  void onCameraFrame(CameraImage frame, CameraController camera) {
    if (!_running || _busy) return;
    final now = DateTime.now();
    if (_lastInferAt != null && now.difference(_lastInferAt!) < minInferGap) {
      return;
    }
    _lastInferAt = now;
    _busy = true;

    try {
      final snap = _SignFrame.from(frame);
      unawaited(
        _runInference(
          snap: snap,
          sensorOrientation: camera.description.sensorOrientation,
          deviceOrientation: camera.value.deviceOrientation,
          isFront:
              camera.description.lensDirection == CameraLensDirection.front,
        ),
      );
    } catch (e) {
      debugPrint('Sign frame copy failed: $e');
      _busy = false;
    }
  }

  Future<void> _runInference({
    required _SignFrame snap,
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required bool isFront,
  }) async {
    try {
      if (!_running) return;

      // Pixel work off the UI isolate, or the camera preview freezes.
      final size = _model.inputSize;
      final nchw = _model.isNchw;
      final prepared = await Isolate.run(() {
        final rgb = snap.toRgb(
          maxSide: size,
          sensorOrientation: sensorOrientation,
          deviceOrientation: deviceOrientation,
          isFront: isFront,
        );
        if (rgb == null) return null;
        return SignInterpreter.prepareFrame(rgb, size, nchw);
      });
      if (prepared == null || !_running) return;

      final hits = (await _model.detectPrepared(prepared))
          .where(
            (h) =>
                h.confidence >= confThreshold &&
                h.sign.action != SignAction.ignore,
          )
          .toList();

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 5)) {
        _lastDebugLog = now;
        debugPrint('Signs ${_model.lastDebug} hits=${hits.length}');
      }

      _handleHits(hits, now);
    } catch (e, st) {
      debugPrint('Sign inference error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  void _handleHits(List<SignDetection> hits, DateTime now) {
    // Best box per sign for this frame.
    final best = <TrafficSign, SignDetection>{};
    for (final h in hits) {
      final prev = best[h.sign];
      if (prev == null || h.confidence > prev.confidence) best[h.sign] = h;
    }

    // Streaks only survive across consecutive frames.
    _streak.removeWhere((sign, _) => !best.containsKey(sign));
    for (final sign in best.keys) {
      _streak[sign] = (_streak[sign] ?? 0) + 1;
    }

    final ready = best.values.where((d) {
      if ((_streak[d.sign] ?? 0) < requiredStreak) return false;
      final last = _lastEmitAt[d.sign];
      return last == null || now.difference(last) >= signCooldown;
    }).toList();
    if (ready.isEmpty) return;

    // One sign per inference: spoken signs first, then confidence.
    ready.sort((a, b) {
      final ap = a.sign.action == SignAction.speak ? 1 : 0;
      final bp = b.sign.action == SignAction.speak ? 1 : 0;
      if (ap != bp) return bp.compareTo(ap);
      return b.confidence.compareTo(a.confidence);
    });
    final pick = ready.first;
    _lastEmitAt[pick.sign] = now;
    _streak[pick.sign] = 0;
    if (!_controller.isClosed) _controller.add(pick);
  }
}

/// Copied camera planes so inference can run after the stream callback
/// returns (the plugin recycles CameraImage buffers).
class _SignFrame {
  _SignFrame._({
    required this.width,
    required this.height,
    required this.isBgra,
    required this.plane0,
    required this.rowStride0,
    this.plane1,
    this.plane2,
    this.uvRowStride = 0,
    this.uvPixelStride = 1,
  });

  final int width;
  final int height;
  final bool isBgra;
  final Uint8List plane0;
  final int rowStride0;
  final Uint8List? plane1;
  final Uint8List? plane2;
  final int uvRowStride;
  final int uvPixelStride;

  factory _SignFrame.from(CameraImage image) {
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    Uint8List copyOf(Uint8List src) => Uint8List.fromList(src);
    if (isBgra || image.planes.length < 3) {
      return _SignFrame._(
        width: image.width,
        height: image.height,
        isBgra: isBgra,
        plane0: copyOf(image.planes[0].bytes),
        rowStride0: image.planes[0].bytesPerRow,
      );
    }
    return _SignFrame._(
      width: image.width,
      height: image.height,
      isBgra: false,
      plane0: copyOf(image.planes[0].bytes),
      rowStride0: image.planes[0].bytesPerRow,
      plane1: copyOf(image.planes[1].bytes),
      plane2: copyOf(image.planes[2].bytes),
      uvRowStride: image.planes[1].bytesPerRow,
      uvPixelStride: image.planes[1].bytesPerPixel ?? 1,
    );
  }

  /// Upright RGB frame, subsampled only as far as the model needs
  /// (signs are small, so keep as much detail as possible).
  img.Image? toRgb({
    required int maxSide,
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required bool isFront,
  }) {
    try {
      final longest = width > height ? width : height;
      final step = (longest ~/ maxSide).clamp(1, 8);
      final rgb = isBgra ? _bgraToImage(step) : _yuv420ToImage(step);
      if (rgb == null) return null;

      final deviceDeg = switch (deviceOrientation) {
        DeviceOrientation.portraitUp => 0,
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
      };
      final rotation = isFront
          ? (sensorOrientation + deviceDeg) % 360
          : (sensorOrientation - deviceDeg + 360) % 360;

      if (rotation == 90) return img.copyRotate(rgb, angle: 90);
      if (rotation == 270) return img.copyRotate(rgb, angle: 270);
      if (rotation == 180) return img.copyRotate(rgb, angle: 180);
      return rgb;
    } catch (e) {
      debugPrint('Sign camera->rgb failed: $e');
      return null;
    }
  }

  img.Image _bgraToImage(int step) {
    final w = width ~/ step;
    final h = height ~/ step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final row = (y * step) * rowStride0;
      for (var x = 0; x < w; x++) {
        final i = row + (x * step) * 4;
        if (i + 2 >= plane0.length) continue;
        out.setPixelRgb(x, y, plane0[i + 2], plane0[i + 1], plane0[i]);
      }
    }
    return out;
  }

  img.Image? _yuv420ToImage(int step) {
    final u = plane1;
    final v = plane2;
    if (u == null || v == null) return null;
    final w = width ~/ step;
    final h = height ~/ step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final srcY = y * step;
      final yRow = srcY * rowStride0;
      final uvRow = (srcY >> 1) * uvRowStride;
      for (var x = 0; x < w; x++) {
        final srcX = x * step;
        final yi = yRow + srcX;
        if (yi >= plane0.length) continue;
        final yp = plane0[yi];
        final uvIndex = uvRow + (srcX >> 1) * uvPixelStride;
        final up = u[uvIndex.clamp(0, u.length - 1)];
        final vp = v[uvIndex.clamp(0, v.length - 1)];
        final r = (yp + 1.370705 * (vp - 128)).round().clamp(0, 255);
        final g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128))
            .round()
            .clamp(0, 255);
        final b = (yp + 1.732446 * (up - 128)).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }
}
