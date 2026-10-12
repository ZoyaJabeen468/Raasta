import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'yolo_m2_interpreter.dart';

/// One camera frame, copied so a background isolate can read it safely.
class YoloCameraFrame {
  YoloCameraFrame({
    required this.width,
    required this.height,
    required this.isBgra,
    required this.plane0,
    required this.rowStride0,
    required this.sensorOrientation,
    this.plane1,
    this.plane2,
    this.uvRowStride = 0,
    this.uvPixelStride = 1,
    this.isFront = false,
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
  final int sensorOrientation;
  final bool isFront;
}

/// Loads the model on the platform thread, then keeps pixel work off the UI.
///
/// Creating the TFLite interpreter inside a raw isolate aborts the process
/// on some Android phones, which closed the app as soon as Drive opened.
class YoloFrameWorker {
  final YoloM2Interpreter _yolo = YoloM2Interpreter();
  bool _ready = false;

  int inputSize = 320;
  String debug = 'not started';

  bool get isReady => _ready;

  Future<bool> start() async {
    if (_ready) return true;
    try {
      _ready = await _yolo.load();
      debug = _yolo.lastDebug;
      inputSize = _yolo.inputSize;
      return _ready;
    } catch (e, st) {
      debug = 'worker start failed: $e';
      debugPrint('YoloFrameWorker $debug\n$st');
      _ready = false;
      return false;
    }
  }

  Future<YoloPostProcessResult?> detect(YoloCameraFrame frame) async {
    if (!_ready) return null;
    try {
      final inputSize = _yolo.inputSize;
      final nchw = _yolo.isNchw;
      final pre = await Isolate.run(
        () => _prepareFrame(frame, inputSize, nchw),
      );
      if (pre == null) return null;

      final output = await _yolo.runModelAsync(pre.flatIn);
      if (output == null) {
        debug = _yolo.lastDebug;
        return null;
      }

      final post = YoloPostProcessData(
        output: output,
        outShape: List<int>.from(_yolo.outShape),
        frameW: pre.frameW,
        frameH: pre.frameH,
        roiOffsetY: pre.roiOffsetY,
        gain: pre.gain,
        padX: pre.padX,
        padY: pre.padY,
        inputSize: inputSize,
      );
      final result = await Isolate.run(
        () => YoloM2Interpreter.postprocessStatic(post),
      );
      debug = _yolo.lastDebug;
      return result;
    } catch (e, st) {
      debug = 'detect failed: $e';
      debugPrint('YoloFrameWorker $debug\n$st');
      return null;
    }
  }

  void close() {
    _ready = false;
    _yolo.close();
  }
}

YoloPreProcessResult? _prepareFrame(
  YoloCameraFrame frame,
  int inputSize,
  bool nchw,
) {
  final rgb = _toRgb(frame);
  if (rgb == null) return null;
  final small = _downscale(rgb, inputSize);
  return YoloM2Interpreter.preprocessStatic(small, inputSize, nchw);
}

img.Image _downscale(img.Image src, int maxSide) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  final scale = maxSide / longest;
  return img.copyResize(
    src,
    width: (src.width * scale).round().clamp(1, maxSide),
    height: (src.height * scale).round().clamp(1, maxSide),
    interpolation: img.Interpolation.linear,
  );
}

/// Portrait-locked drive. Rotate by the camera sensor only, so boxes match
/// the upright preview. A tilting mount used to flip this and label the
/// wrong part of the frame.
int _portraitRotation({required int sensorOrientation, required bool isFront}) {
  final sensor = sensorOrientation % 360;
  if (!isFront) return sensor;
  return (360 - sensor) % 360;
}

int _sampleStep(int width, int height) {
  final longest = width > height ? width : height;
  if (longest >= 1400) return 3;
  if (longest >= 900) return 2;
  return 1;
}

img.Image? _toRgb(YoloCameraFrame frame) {
  final step = _sampleStep(frame.width, frame.height);
  final rgb = frame.isBgra ? _bgra(frame, step) : _yuv(frame, step);
  if (rgb == null) return null;
  final rotation = _portraitRotation(
    sensorOrientation: frame.sensorOrientation,
    isFront: frame.isFront,
  );
  if (rotation == 90) return img.copyRotate(rgb, angle: 90);
  if (rotation == 270) return img.copyRotate(rgb, angle: 270);
  if (rotation == 180) return img.copyRotate(rgb, angle: 180);
  return rgb;
}

img.Image _bgra(YoloCameraFrame frame, int step) {
  final w = frame.width ~/ step;
  final h = frame.height ~/ step;
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final srcY = y * step;
    final row = srcY * frame.rowStride0;
    for (var x = 0; x < w; x++) {
      final i = row + (x * step) * 4;
      if (i + 2 >= frame.plane0.length) continue;
      out.setPixelRgb(
        x,
        y,
        frame.plane0[i + 2] & 0xff,
        frame.plane0[i + 1] & 0xff,
        frame.plane0[i] & 0xff,
      );
    }
  }
  return out;
}

img.Image? _yuv(YoloCameraFrame frame, int step) {
  final u = frame.plane1;
  final v = frame.plane2;
  if (u == null || v == null) return null;
  final w = frame.width ~/ step;
  final h = frame.height ~/ step;
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    final srcY = y * step;
    final yRow = srcY * frame.rowStride0;
    final uvRow = (srcY >> 1) * frame.uvRowStride;
    for (var x = 0; x < w; x++) {
      final srcX = x * step;
      final yIndex = yRow + srcX;
      if (yIndex >= frame.plane0.length) continue;
      final yp = frame.plane0[yIndex] & 0xff;
      final uvIndex = uvRow + (srcX >> 1) * frame.uvPixelStride;
      final ui = uvIndex.clamp(0, u.length - 1);
      final vi = uvIndex.clamp(0, v.length - 1);
      final up = u[ui] & 0xff;
      final vp = v[vi] & 0xff;
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
