import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/traffic_sign.dart';
import 'ocr_service.dart';
import 'sign_confirmer.dart';
import 'sign_interpreter.dart';

export 'sign_interpreter.dart' show SignDetection;

/// Padding added around a sign box before OCR (fraction of box size).
const signCropPadding = 0.15;

/// Crops smaller than this on the short side are too blurry to read.
const minSignCropSide = 48;

/// Normalized box [left, top, right, bottom] grown by [signCropPadding]
/// and clamped to the frame.
List<double> paddedSignBox(SignDetection d) {
  final padX = (d.right - d.left) * signCropPadding;
  final padY = (d.bottom - d.top) * signCropPadding;
  return [
    (d.left - padX).clamp(0.0, 1.0),
    (d.top - padY).clamp(0.0, 1.0),
    (d.right + padX).clamp(0.0, 1.0),
    (d.bottom + padY).clamp(0.0, 1.0),
  ];
}

/// Padded crop of [d] from an upright image (Sign test screen). Null when
/// the crop is under [minSignCropSide].
img.Image? cropSignFromImage(img.Image upright, SignDetection d) {
  final box = paddedSignBox(d);
  final x = (box[0] * upright.width).floor();
  final y = (box[1] * upright.height).floor();
  final w = (box[2] * upright.width).ceil() - x;
  final h = (box[3] * upright.height).ceil() - y;
  if (w < minSignCropSide || h < minSignCropSide) return null;
  return img.copyCrop(upright, x: x, y: y, width: w, height: h);
}

/// Module 3: confirms traffic signs from shared camera frames, then reads
/// them with OCR.
///
/// Does not own the camera. Frames are pushed in via [onCameraFrame] (wired
/// to [CameraYoloHazardDetector.onFrameTap]) so the camera is opened once.
///
/// Confirmation (streak + cooldown) is done by [SignConfirmer]. Confirmed
/// spoken/shown signs go out on [detections] straight away. OCR then runs
/// in the background, gated by [OcrGate], on a high-res crop of the same
/// frame, and results go out on [readings]:
/// - the speed-limit candidate (class 0) is emitted only when OCR reads a
///   valid limit; it never appears on [detections].
/// - other signs are re-emitted with [SignDetection.ocrText] when text
///   was found.
class SignDetector {
  SignDetector({SignInterpreter? interpreter, OcrService? ocr})
    : _model = interpreter ?? SignInterpreter(),
      _ocr = ocr ?? OcrService();

  final SignInterpreter _model;
  final OcrService _ocr;
  final _controller = StreamController<SignDetection>.broadcast();
  final _readings = StreamController<SignDetection>.broadcast();

  static const minInferGap = Duration(milliseconds: 2500);
  static const confThreshold = SignInterpreter.confThreshold;

  /// Longest side of an OCR crop; keeps the YUV→RGB work small.
  static const maxCropSide = 640;

  final _confirmer = SignConfirmer(confThreshold: confThreshold);
  final _ocrGate = OcrGate();

  bool _running = false;
  bool _busy = false;
  DateTime? _lastInferAt;
  DateTime? _lastDebugLog;

  /// Confirmed signs to show (and speak, for [SignAction.speak]).
  Stream<SignDetection> get detections => _controller.stream;

  /// OCR results: speed-limit readings and text for confirmed signs.
  Stream<SignDetection> get readings => _readings.stream;
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
    _confirmer.reset();
    _ocrGate.reset();
    _lastInferAt = null;
  }

  void dispose() {
    _running = false;
    _model.close();
    _ocr.dispose();
    _controller.close();
    _readings.close();
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
      final rotation = _SignFrame.rotationFor(
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        isFront: isFront,
      );
      final prepared = await Isolate.run(() {
        final rgb = snap.toRgb(maxSide: size, rotation: rotation);
        if (rgb == null) return null;
        return SignInterpreter.prepareFrame(rgb, size, nchw);
      });
      if (prepared == null || !_running) return;

      final hits = await _model.detectPrepared(prepared);

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 5)) {
        _lastDebugLog = now;
        debugPrint('Signs ${_model.lastDebug} hits=${hits.length}');
      }

      final pick = _confirmer.add(hits, now);
      if (pick == null) return;
      if (!pick.sign.isSpeedLimitCandidate && !_controller.isClosed) {
        _controller.add(pick);
      }
      // Not awaited: the next camera frame doesn't wait for OCR.
      unawaited(_readSign(pick, snap, rotation, now));
    } catch (e, st) {
      debugPrint('Sign inference error: $e\n$st');
    } finally {
      _busy = false;
    }
  }

  Future<void> _readSign(
    SignDetection pick,
    _SignFrame snap,
    int rotation,
    DateTime now,
  ) async {
    final label = pick.sign.classLabel;
    if (!OcrService.isSupported) return;
    if (!_ocrGate.tryBegin(pick.sign, now)) {
      debugPrint('RAASTA OCR: sign=$label skipped (gate)');
      return;
    }
    try {
      final box = paddedSignBox(pick);
      final crop = await Isolate.run(
        () => snap.cropRgb(box: box, rotation: rotation, maxSide: maxCropSide),
      );
      if (crop == null) {
        debugPrint('RAASTA OCR: sign=$label skipped (crop too small)');
        return;
      }
      if (!_running) return;

      final result = await _ocr.readSign(crop, sign: label);
      if (result == null || !_running || _readings.isClosed) return;

      if (pick.sign.isSpeedLimitCandidate) {
        final limit = result.speedLimit;
        if (limit == null) return;
        _readings.add(pick.withOcr(text: result.text, speedLimit: limit));
      } else if (result.text.isNotEmpty) {
        _readings.add(pick.withOcr(text: result.text));
      }
    } catch (e) {
      debugPrint('RAASTA OCR: sign=$label failed: $e');
    } finally {
      _ocrGate.end();
    }
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

  /// Degrees to rotate the sensor image so it is upright.
  static int rotationFor({
    required int sensorOrientation,
    required DeviceOrientation deviceOrientation,
    required bool isFront,
  }) {
    final deviceDeg = switch (deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    return isFront
        ? (sensorOrientation + deviceDeg) % 360
        : (sensorOrientation - deviceDeg + 360) % 360;
  }

  /// Upright RGB frame, subsampled only as far as the model needs
  /// (signs are small, so keep as much detail as possible).
  img.Image? toRgb({required int maxSide, required int rotation}) {
    try {
      final longest = width > height ? width : height;
      final step = (longest ~/ maxSide).clamp(1, 8);
      final rgb = isBgra
          ? _bgraToImage(step, 0, 0, width, height)
          : _yuv420ToImage(step, 0, 0, width, height);
      if (rgb == null) return null;
      return _rotate(rgb, rotation);
    } catch (e) {
      debugPrint('Sign camera->rgb failed: $e');
      return null;
    }
  }

  /// Upright crop of [box] (normalized left, top, right, bottom in the
  /// upright frame, as produced by the model) at sensor resolution, capped
  /// at [maxSide]. Null if the crop is under [minSignCropSide].
  img.Image? cropRgb({
    required List<double> box,
    required int rotation,
    required int maxSide,
  }) {
    try {
      // Map the upright box back to sensor coordinates (inverse of
      // img.copyRotate for 90 / 180 / 270).
      final (l, t, r, b) = (box[0], box[1], box[2], box[3]);
      final (sl, st, sr, sb) = switch (rotation) {
        90 => (t, 1 - r, b, 1 - l),
        180 => (1 - r, 1 - b, 1 - l, 1 - t),
        270 => (1 - b, l, 1 - t, r),
        _ => (l, t, r, b),
      };
      final x0 = (sl * width).floor().clamp(0, width - 1);
      final y0 = (st * height).floor().clamp(0, height - 1);
      final cw = ((sr * width).ceil() - x0).clamp(0, width - x0);
      final ch = ((sb * height).ceil() - y0).clamp(0, height - y0);
      final shortSide = cw < ch ? cw : ch;
      if (shortSide < minSignCropSide) return null;

      final longSide = cw > ch ? cw : ch;
      final step = (longSide ~/ maxSide).clamp(1, shortSide ~/ minSignCropSide);
      final rgb = isBgra
          ? _bgraToImage(step, x0, y0, cw, ch)
          : _yuv420ToImage(step, x0, y0, cw, ch);
      if (rgb == null) return null;
      return _rotate(rgb, rotation);
    } catch (e) {
      debugPrint('Sign crop failed: $e');
      return null;
    }
  }

  static img.Image _rotate(img.Image rgb, int rotation) {
    if (rotation == 90) return img.copyRotate(rgb, angle: 90);
    if (rotation == 270) return img.copyRotate(rgb, angle: 270);
    if (rotation == 180) return img.copyRotate(rgb, angle: 180);
    return rgb;
  }

  /// Converts the region at ([x0], [y0]) of size [cw] x [ch], taking every
  /// [step]-th pixel.
  img.Image _bgraToImage(int step, int x0, int y0, int cw, int ch) {
    final w = cw ~/ step;
    final h = ch ~/ step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final row = (y0 + y * step) * rowStride0;
      for (var x = 0; x < w; x++) {
        final i = row + (x0 + x * step) * 4;
        if (i + 2 >= plane0.length) continue;
        out.setPixelRgb(x, y, plane0[i + 2], plane0[i + 1], plane0[i]);
      }
    }
    return out;
  }

  img.Image? _yuv420ToImage(int step, int x0, int y0, int cw, int ch) {
    final u = plane1;
    final v = plane2;
    if (u == null || v == null) return null;
    final w = cw ~/ step;
    final h = ch ~/ step;
    final out = img.Image(width: w, height: h);
    for (var y = 0; y < h; y++) {
      final srcY = y0 + y * step;
      final yRow = srcY * rowStride0;
      final uvRow = (srcY >> 1) * uvRowStride;
      for (var x = 0; x < w; x++) {
        final srcX = x0 + x * step;
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
