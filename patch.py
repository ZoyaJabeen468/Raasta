import os

YOLO_FILE = r'E:\Android\projects\raasta_app\lib\data\services\yolo_m2_interpreter.dart'
CAMERA_FILE = r'E:\Android\projects\raasta_app\lib\data\services\camera_yolo_detector.dart'

with open(YOLO_FILE, 'r', encoding='utf-8') as f:
    yolo_code = f.read()
    
# We will inject the new classes at the top after imports.
import_str = "import 'hazard_detector.dart';\n"
classes_str = '''
class YoloPreProcessResult {
  const YoloPreProcessResult({
    required this.flatIn,
    required this.frameW,
    required this.frameH,
    required this.roiOffsetY,
    required this.gain,
    required this.padX,
    required this.padY,
  });
  final Float32List flatIn;
  final int frameW;
  final int frameH;
  final int roiOffsetY;
  final double gain;
  final double padX;
  final double padY;
}

class YoloPostProcessData {
  const YoloPostProcessData({
    required this.output,
    required this.outShape,
    required this.frameW,
    required this.frameH,
    required this.roiOffsetY,
    required this.gain,
    required this.padX,
    required this.padY,
    required this.inputSize,
  });
  final Float32List output;
  final List<int> outShape;
  final int frameW;
  final int frameH;
  final int roiOffsetY;
  final double gain;
  final double padX;
  final double padY;
  final int inputSize;
}

class YoloPostProcessResult {
  const YoloPostProcessResult({
    required this.hits,
    required this.peakScore,
    required this.peakLabel,
  });
  final List<HazardDetection> hits;
  final double peakScore;
  final String peakLabel;
}

class _RawParseResult {
  const _RawParseResult(this.dets, this.peakScore, this.peakLabel);
  final List<_Det> dets;
  final double peakScore;
  final String peakLabel;
}
'''
yolo_code = yolo_code.replace(import_str, import_str + classes_str)

# Now replace the instance methods with static methods where needed.
replace_detect_from = '''  List<HazardDetection> detect(img.Image rgb) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return const [];

    try {
      final roi = _lowerRoi(rgb);
      final letterboxed = _letterbox(roi.image, _inputSize);
      final flatIn = _packInput(letterboxed.image);

      final inputNested = flatIn.reshape<double>(_inShape);
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final flatOut = List<double>.filled(outElements, 0.0);
      final outputNested = flatOut.reshape<double>(_outShape);

      interpreter.run(inputNested, outputNested);

      final output = Float32List(outElements);
      _flattenDoubles(outputNested, output, 0);

      var absSum = 0.0;
      for (final v in output) {
        absSum += v.abs();
      }
      lastDebug = 'outSum= n=';

      final raw = _parseYoloOutput(
        output,
        gain: letterboxed.gain,
        padX: letterboxed.padX,
        padY: letterboxed.padY,
        roiOffsetY: roi.offsetY,
        frameW: rgb.width,
        frameH: rgb.height,
      );
      return _nms(
        raw,
        frameW: rgb.width.toDouble(),
        frameH: rgb.height.toDouble(),
      );
    } catch (e, st) {
      lastDebug = 'detect error: ';
      debugPrint('YoloM2 detect failed: \\n');
      return const [];
    }
  }'''

replace_detect_to = '''  bool get isNchw => _nchw;
  List<int> get outShape => _outShape;

  Float32List? runModel(Float32List flatIn) {
    final interpreter = _interpreter;
    if (interpreter == null || !_ready) return null;

    try {
      final inputNested = flatIn.reshape<double>(_inShape);
      final outElements = _outShape.fold<int>(1, (a, b) => a * b);
      final flatOut = List<double>.filled(outElements, 0.0);
      final outputNested = flatOut.reshape<double>(_outShape);

      interpreter.run(inputNested, outputNested);

      final output = Float32List(outElements);
      _flattenDoubles(outputNested, output, 0);

      var absSum = 0.0;
      for (final v in output) {
        absSum += v.abs();
      }
      lastDebug = 'outSum= n=';
      return output;
    } catch (e, st) {
      lastDebug = 'runModel error: ';
      debugPrint('YoloM2 runModel failed: \\n');
      return null;
    }
  }

  static YoloPreProcessResult preprocessStatic(
    img.Image src,
    int inputSize,
    bool isNchw,
  ) {
    final roi = _lowerRoiStatic(src);
    final letterboxed = _letterboxStatic(roi.image, inputSize);
    final flatIn = _packInputStatic(letterboxed.image, inputSize, isNchw);

    return YoloPreProcessResult(
      flatIn: flatIn,
      frameW: src.width,
      frameH: src.height,
      roiOffsetY: roi.offsetY,
      gain: letterboxed.gain,
      padX: letterboxed.padX,
      padY: letterboxed.padY,
    );
  }

  static YoloPostProcessResult postprocessStatic(YoloPostProcessData data) {
    final raw = _parseYoloOutputStatic(
      data.output,
      outShape: data.outShape,
      inputSize: data.inputSize,
      gain: data.gain,
      padX: data.padX,
      padY: data.padY,
      roiOffsetY: data.roiOffsetY,
      frameW: data.frameW,
      frameH: data.frameH,
    );
    final hits = _nmsStatic(
      raw.dets,
      frameW: data.frameW.toDouble(),
      frameH: data.frameH.toDouble(),
    );
    return YoloPostProcessResult(
      hits: hits,
      peakScore: raw.peakScore,
      peakLabel: raw.peakLabel,
    );
  }'''

yolo_code = yolo_code.replace(replace_detect_from, replace_detect_to)

# Change instance methods to static
yolo_code = yolo_code.replace("Float32List _packInput(img.Image image)", "static Float32List _packInputStatic(img.Image image, int size, bool isNchw)")
yolo_code = yolo_code.replace("final size = _inputSize;", "")
yolo_code = yolo_code.replace("if (_nchw) {", "if (isNchw) {")

yolo_code = yolo_code.replace("int _flattenDoubles(dynamic node, Float32List out, int index)", "static int _flattenDoubles(dynamic node, Float32List out, int index)")

yolo_code = yolo_code.replace("_Roi _lowerRoi(img.Image src)", "static _Roi _lowerRoiStatic(img.Image src)")

yolo_code = yolo_code.replace("_Letterbox _letterbox(img.Image src, int size)", "static _Letterbox _letterboxStatic(img.Image src, int size)")

yolo_code = yolo_code.replace('''  List<_Det> _parseYoloOutput(
    Float32List output, {
    required double gain,
    required double padX,
    required double padY,
    required int roiOffsetY,
    required int frameW,
    required int frameH,
  }) {''', '''  static _RawParseResult _parseYoloOutputStatic(
    Float32List output, {
    required List<int> outShape,
    required int inputSize,
    required double gain,
    required double padX,
    required double padY,
    required int roiOffsetY,
    required int frameW,
    required int frameH,
  }) {''')
yolo_code = yolo_code.replace("if (_outShape.length < 3)", "if (outShape.length < 3)")
yolo_code = yolo_code.replace("lastDebug = 'bad out shape ';", "")
yolo_code = yolo_code.replace("return const [];", "return const _RawParseResult([], 0, '-');")
yolo_code = yolo_code.replace("final d1 = _outShape[1];", "final d1 = outShape[1];")
yolo_code = yolo_code.replace("final d2 = _outShape[2];", "final d2 = outShape[2];")
yolo_code = yolo_code.replace("lastDebug = 'bad channels= shape=';", "")
yolo_code = yolo_code.replace("cx *= _inputSize;", "cx *= inputSize;")
yolo_code = yolo_code.replace("cy *= _inputSize;", "cy *= inputSize;")
yolo_code = yolo_code.replace("w *= _inputSize;", "w *= inputSize;")
yolo_code = yolo_code.replace("h *= _inputSize;", "h *= inputSize;")
yolo_code = yolo_code.replace("lastPeakScore = peak;", "")
yolo_code = yolo_code.replace("lastPeakLabel =", "final peakLabel =")
yolo_code = yolo_code.replace("return dets;", "return _RawParseResult(dets, peak, peakLabel);")

yolo_code = yolo_code.replace('''  List<HazardDetection> _nms(
    List<_Det> dets, {
    required double frameW,
    required double frameH,
  }) {''', '''  static List<HazardDetection> _nmsStatic(
    List<_Det> dets, {
    required double frameW,
    required double frameH,
  }) {''')
yolo_code = yolo_code.replace("_estimateDistanceMeters(d, frameW, frameH)", "_estimateDistanceMetersStatic(d, frameW, frameH)")
yolo_code = yolo_code.replace("double _estimateDistanceMeters(_Det d, double frameW, double frameH)", "static double _estimateDistanceMetersStatic(_Det d, double frameW, double frameH)")
yolo_code = yolo_code.replace("double _iou(_Det a, _Det b)", "static double _iouStatic(_Det a, _Det b)")
yolo_code = yolo_code.replace("_iou(dets[i], dets[j])", "_iouStatic(dets[i], dets[j])")

with open(YOLO_FILE, 'w', encoding='utf-8') as f:
    f.write(yolo_code)

# Now modify camera_yolo_detector.dart
with open(CAMERA_FILE, 'r', encoding='utf-8') as f:
    cam_code = f.read()

cam_code = cam_code.replace("import 'package:flutter/services.dart';", "import 'package:flutter/services.dart';\\nimport 'dart:isolate';")

run_inference_from = '''  Future<void> _runInference({
    required _FrameSnapshot snap,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required bool isFront,
  }) async {
    try {
      // Let a camera/UI frame paint before heavy work.
      await Future<void>.delayed(Duration.zero);
      if (!_running) return;

      final rgb = snap.toRgb(
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        isFront: isFront,
      );
      if (rgb == null) return;

      final small = _downscale(rgb, _yolo.inputSize);
      final hits = _yolo.detect(small);

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 3)) {
        _lastDebugLog = now;
        debugPrint(
          'YOLO peak= '
          '() hits= ',
        );
      }'''

run_inference_to = '''  Future<void> _runInference({
    required _FrameSnapshot snap,
    required int sensorOrientation,
    required DeviceOrientation? deviceOrientation,
    required bool isFront,
  }) async {
    try {
      await Future<void>.delayed(Duration.zero);
      if (!_running) return;

      final preData = _InferencePreProcessData(
        snap: snap,
        sensorOrientation: sensorOrientation,
        deviceOrientation: deviceOrientation,
        isFront: isFront,
        inputSize: _yolo.inputSize,
        isNchw: _yolo.isNchw,
      );

      final preResult = await Isolate.run(() => _runPreProcessInIsolate(preData));
      if (preResult == null || !_running) return;

      final outputFloat32 = _yolo.runModel(preResult.flatIn);
      if (outputFloat32 == null || !_running) return;

      final postData = YoloPostProcessData(
        output: outputFloat32,
        outShape: _yolo.outShape,
        frameW: preResult.frameW,
        frameH: preResult.frameH,
        roiOffsetY: preResult.roiOffsetY,
        gain: preResult.gain,
        padX: preResult.padX,
        padY: preResult.padY,
        inputSize: _yolo.inputSize,
      );

      final postResult = await Isolate.run(() => _runPostProcessInIsolate(postData));

      _yolo.lastPeakScore = postResult.peakScore;
      _yolo.lastPeakLabel = postResult.peakLabel;
      final hits = postResult.hits;

      final now = DateTime.now();
      if (_lastDebugLog == null ||
          now.difference(_lastDebugLog!) > const Duration(seconds: 3)) {
        _lastDebugLog = now;
        debugPrint(
          'YOLO peak= '
          '() hits= ',
        );
      }'''

cam_code = cam_code.replace(run_inference_from, run_inference_to)
# Wait, I also want to reduce _minInferGap from 3000 to something reasonable like 250ms since it runs in an isolate now!
cam_code = cam_code.replace("static const _minInferGap = Duration(milliseconds: 3000);", "static const _minInferGap = Duration(milliseconds: 250);")

isolate_classes = '''
class _InferencePreProcessData {
  _InferencePreProcessData({
    required this.snap,
    required this.sensorOrientation,
    required this.deviceOrientation,
    required this.isFront,
    required this.inputSize,
    required this.isNchw,
  });
  final _FrameSnapshot snap;
  final int sensorOrientation;
  final DeviceOrientation? deviceOrientation;
  final bool isFront;
  final int inputSize;
  final bool isNchw;
}

YoloPreProcessResult? _runPreProcessInIsolate(_InferencePreProcessData data) {
  final rgb = data.snap.toRgb(
    sensorOrientation: data.sensorOrientation,
    deviceOrientation: data.deviceOrientation,
    isFront: data.isFront,
  );
  if (rgb == null) return null;

  final small = _downscale(rgb, data.inputSize);
  return YoloM2Interpreter.preprocessStatic(
    small,
    data.inputSize,
    data.isNchw,
  );
}

YoloPostProcessResult _runPostProcessInIsolate(YoloPostProcessData data) {
  return YoloM2Interpreter.postprocessStatic(data);
}
'''
cam_code += isolate_classes

with open(CAMERA_FILE, 'w', encoding='utf-8') as f:
    f.write(cam_code)

print("Patch applied successfully.")
