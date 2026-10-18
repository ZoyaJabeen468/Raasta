import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
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

  Isolate? _prepIsolate;
  SendPort? _prepPort;
  final ReceivePort _prepReplies = ReceivePort();
  Future<void>? _prepStart;
  bool _prepListening = false;
  int _prepSeq = 0;
  final Map<int, Completer<YoloPreProcessResult?>> _prepWaiters = {};

  int inputSize = 320;
  String debug = 'not started';

  bool get isReady => _ready;

  Future<bool> start() async {
    if (_ready) return true;
    try {
      _ready = await _yolo.load();
      debug = _yolo.lastDebug;
      inputSize = _yolo.inputSize;
      if (_ready) await _ensurePrepIsolate();
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
      final pre = await _preprocess(frame, inputSize, nchw);
      if (pre == null) return null;

      final output = await _yolo.runModelAsync(pre.flatIn);
      if (output == null) {
        debug = _yolo.lastDebug;
        return null;
      }

      // NMS is cheap; spawning a second isolate per frame was the lag.
      final result = YoloM2Interpreter.postprocessStatic(
        YoloPostProcessData(
          output: output,
          outShape: List<int>.from(_yolo.outShape),
          frameW: pre.frameW,
          frameH: pre.frameH,
          roiOffsetY: pre.roiOffsetY,
          gain: pre.gain,
          padX: pre.padX,
          padY: pre.padY,
          inputSize: inputSize,
        ),
      );
      debug = _yolo.lastDebug;
      return result;
    } catch (e, st) {
      debug = 'detect failed: $e';
      debugPrint('YoloFrameWorker $debug\n$st');
      return null;
    }
  }

  Future<YoloPreProcessResult?> _preprocess(
    YoloCameraFrame frame,
    int inputSize,
    bool nchw,
  ) async {
    await _ensurePrepIsolate();
    final port = _prepPort;
    if (port == null) {
      return Isolate.run(() => _prepareFrame(frame, inputSize, nchw));
    }

    final id = ++_prepSeq;
    final waiter = Completer<YoloPreProcessResult?>();
    _prepWaiters[id] = waiter;
    port.send(<String, Object?>{
      'id': id,
      'w': frame.width,
      'h': frame.height,
      'bgra': frame.isBgra,
      'p0': TransferableTypedData.fromList([frame.plane0]),
      'rs0': frame.rowStride0,
      'p1': frame.plane1 == null
          ? null
          : TransferableTypedData.fromList([frame.plane1!]),
      'p2': frame.plane2 == null
          ? null
          : TransferableTypedData.fromList([frame.plane2!]),
      'uvr': frame.uvRowStride,
      'uvp': frame.uvPixelStride,
      'so': frame.sensorOrientation,
      'front': frame.isFront,
      'size': inputSize,
      'nchw': nchw,
    });
    return waiter.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {
        _prepWaiters.remove(id);
        return null;
      },
    );
  }

  Future<void> _ensurePrepIsolate() {
    if (_prepPort != null) return Future.value();
    return _prepStart ??= _startPrepIsolate();
  }

  Future<void> _startPrepIsolate() async {
    final ready = Completer<SendPort>();
    if (!_prepListening) {
      _prepListening = true;
      _prepReplies.listen((message) {
        if (message is SendPort) {
          if (!ready.isCompleted) ready.complete(message);
          return;
        }
        _onPrepResult(message);
      });
    }
    _prepIsolate = await Isolate.spawn(_prepIsolateMain, _prepReplies.sendPort);
    _prepPort = await ready.future;
  }

  void _onPrepResult(dynamic message) {
    if (message is! Map) return;
    final id = message['id'];
    if (id is! int) return;
    final waiter = _prepWaiters.remove(id);
    if (waiter == null || waiter.isCompleted) return;
    if (message['ok'] != true) {
      waiter.complete(null);
      return;
    }
    final flat = message['flat'];
    if (flat is! Float32List) {
      waiter.complete(null);
      return;
    }
    waiter.complete(
      YoloPreProcessResult(
        flatIn: flat,
        frameW: message['fw'] as int,
        frameH: message['fh'] as int,
        roiOffsetY: message['roi'] as int,
        gain: (message['gain'] as num).toDouble(),
        padX: (message['padX'] as num).toDouble(),
        padY: (message['padY'] as num).toDouble(),
      ),
    );
  }

  void close() {
    _ready = false;
    _prepIsolate?.kill(priority: Isolate.immediate);
    _prepIsolate = null;
    _prepPort = null;
    _prepStart = null;
    for (final waiter in _prepWaiters.values) {
      if (!waiter.isCompleted) waiter.complete(null);
    }
    _prepWaiters.clear();
    _prepReplies.close();
    _yolo.close();
  }
}

void _prepIsolateMain(SendPort replies) {
  final inbox = ReceivePort();
  replies.send(inbox.sendPort);
  inbox.listen((raw) {
    if (raw is! Map) return;
    final id = raw['id'];
    try {
      Uint8List plane(Object? value) {
        if (value is TransferableTypedData) {
          return value.materialize().asUint8List();
        }
        return value as Uint8List;
      }

      final p1 = raw['p1'];
      final p2 = raw['p2'];
      final frame = YoloCameraFrame(
        width: raw['w'] as int,
        height: raw['h'] as int,
        isBgra: raw['bgra'] as bool,
        plane0: plane(raw['p0']),
        rowStride0: raw['rs0'] as int,
        plane1: p1 == null ? null : plane(p1),
        plane2: p2 == null ? null : plane(p2),
        uvRowStride: raw['uvr'] as int,
        uvPixelStride: raw['uvp'] as int,
        sensorOrientation: raw['so'] as int,
        isFront: raw['front'] as bool,
      );
      final pre = _prepareFrame(
        frame,
        raw['size'] as int,
        raw['nchw'] as bool,
      );
      if (pre == null) {
        replies.send(<String, Object?>{'id': id, 'ok': false});
        return;
      }
      replies.send(<String, Object?>{
        'id': id,
        'ok': true,
        'flat': pre.flatIn,
        'fw': pre.frameW,
        'fh': pre.frameH,
        'roi': pre.roiOffsetY,
        'gain': pre.gain,
        'padX': pre.padX,
        'padY': pre.padY,
      });
    } catch (e) {
      replies.send(<String, Object?>{'id': id, 'ok': false, 'err': '$e'});
    }
  });
}

YoloPreProcessResult? _prepareFrame(
  YoloCameraFrame frame,
  int inputSize,
  bool nchw,
) {
  if (!frame.isBgra) return _yuvToTensor(frame, inputSize, nchw);
  final rgb = _toRgb(frame);
  if (rgb == null) return null;
  final small = _downscale(rgb, inputSize);
  return YoloM2Interpreter.preprocessStatic(small, inputSize, nchw);
}

/// Rotates, letterboxes and normalises a YUV frame straight into the model
/// tensor in one pass. Building img.Image copies for each step cost ~2 s a
/// frame on the phone (0.4 fps on the debug pill).
YoloPreProcessResult? _yuvToTensor(
  YoloCameraFrame frame,
  int size,
  bool nchw,
) {
  final u = frame.plane1;
  final v = frame.plane2;
  if (u == null || v == null) return null;
  final yPlane = frame.plane0;
  final w = frame.width;
  final h = frame.height;
  final rotation = _portraitRotation(
    sensorOrientation: frame.sensorOrientation,
    isFront: frame.isFront,
  );
  final swap = rotation == 90 || rotation == 270;
  final rw = swap ? h : w;
  final rh = swap ? w : h;
  final scale = math.min(size / rw, size / rh);
  final nw = (rw * scale).round().clamp(1, size);
  final nh = (rh * scale).round().clamp(1, size);
  final dx = ((size - nw) / 2).round();
  final dy = ((size - nh) / 2).round();

  final area = size * size;
  final floats = Float32List(3 * area)..fillRange(0, 3 * area, 114 / 255.0);

  final rxs = Int32List(nw);
  for (var ox = 0; ox < nw; ox++) {
    rxs[ox] = ((ox + 0.5) * rw / nw).floor().clamp(0, rw - 1);
  }
  final rys = Int32List(nh);
  for (var oy = 0; oy < nh; oy++) {
    rys[oy] = ((oy + 0.5) * rh / nh).floor().clamp(0, rh - 1);
  }

  final yStride = frame.rowStride0;
  final uvStride = frame.uvRowStride;
  final uvPixel = frame.uvPixelStride;
  final yLen = yPlane.length;
  final uLast = u.length - 1;
  final vLast = v.length - 1;
  const inv = 1 / 255.0;

  for (var oy = 0; oy < nh; oy++) {
    final ry = rys[oy];
    final rowBase = (dy + oy) * size + dx;
    for (var ox = 0; ox < nw; ox++) {
      final rx = rxs[ox];
      int sx;
      int sy;
      // Matches img.copyRotate so boxes line up with the old path.
      switch (rotation) {
        case 90:
          sx = ry;
          sy = h - 1 - rx;
        case 180:
          sx = w - 1 - rx;
          sy = h - 1 - ry;
        case 270:
          sx = w - 1 - ry;
          sy = rx;
        default:
          sx = rx;
          sy = ry;
      }
      final yi = sy * yStride + sx;
      if (yi >= yLen) continue;
      final yp = yPlane[yi];
      final uvi = (sy >> 1) * uvStride + (sx >> 1) * uvPixel;
      final up = u[uvi > uLast ? uLast : uvi] - 128;
      final vp = v[uvi > vLast ? vLast : uvi] - 128;
      final r = (yp + 1.370705 * vp).clamp(0.0, 255.0);
      final g = (yp - 0.337633 * up - 0.698001 * vp).clamp(0.0, 255.0);
      final b = (yp + 1.732446 * up).clamp(0.0, 255.0);
      final o = rowBase + ox;
      if (nchw) {
        floats[o] = r * inv;
        floats[area + o] = g * inv;
        floats[2 * area + o] = b * inv;
      } else {
        final i = o * 3;
        floats[i] = r * inv;
        floats[i + 1] = g * inv;
        floats[i + 2] = b * inv;
      }
    }
  }

  return YoloPreProcessResult(
    flatIn: floats,
    frameW: rw,
    frameH: rh,
    roiOffsetY: 0,
    gain: scale,
    padX: dx.toDouble(),
    padY: dy.toDouble(),
  );
}

img.Image _downscale(img.Image src, int maxSide) {
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  final scale = maxSide / longest;
  return img.copyResize(
    src,
    width: (src.width * scale).round().clamp(1, maxSide),
    height: (src.height * scale).round().clamp(1, maxSide),
    interpolation: img.Interpolation.nearest,
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
  // Always skip pixels. Step 1 made laptop/monitor tests feel frozen.
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
