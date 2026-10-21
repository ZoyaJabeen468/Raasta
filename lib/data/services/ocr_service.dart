import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/sign_text_parser.dart';

/// OCR result for one sign crop.
class SignOcrResult {
  const SignOcrResult({
    required this.text,
    required this.speedLimit,
    required this.elapsedMs,
  });

  /// Uppercase, single-spaced. May be empty when no text was found.
  final String text;
  final int? speedLimit;
  final int elapsedMs;
}

/// M3 English OCR on sign crops with on-device Google ML Kit (Latin script).
///
/// ML Kit has no Urdu (Arabic-script) recognizer, so Urdu signs are not
/// read. Urdu is voice output only, from the fixed phrases in
/// `traffic_sign.dart` and the Urdu speed-limit phrase in `TtsService`.
class OcrService {
  TextRecognizer? _recognizer;
  bool _closed = false;
  int _fileSeq = 0;

  /// Crops are upscaled to at least this short side; ML Kit misses
  /// characters that are only a few pixels tall.
  static const _minOcrSide = 160;

  /// ML Kit only ships for Android and iOS.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Reads text from an upright sign crop. Never throws; returns null if OCR
  /// is unavailable or fails. [sign] is only used for the log line.
  Future<SignOcrResult?> readSign(img.Image crop, {String sign = '-'}) async {
    if (_closed || !isSupported) return null;
    final watch = Stopwatch()..start();
    File? file;
    try {
      final jpg = await Isolate.run(() => _encodeForOcr(crop));
      file = File(
        '${Directory.systemTemp.path}/raasta_ocr_${_fileSeq++ % 4}.jpg',
      );
      await file.writeAsBytes(jpg, flush: true);

      final recognizer = _recognizer ??= TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      final recognized = await recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final parsed = parseSignText(recognized.text);
      final ms = watch.elapsedMilliseconds;
      debugPrint(
        "RAASTA OCR: sign=$sign text='${parsed.text}' "
        'limit=${parsed.speedLimit} ms=$ms',
      );
      return SignOcrResult(
        text: parsed.text,
        speedLimit: parsed.speedLimit,
        elapsedMs: ms,
      );
    } catch (e) {
      debugPrint('RAASTA OCR: sign=$sign failed: $e');
      return null;
    } finally {
      if (file != null) {
        unawaited(file.delete().then((_) {}, onError: (_) {}));
      }
    }
  }

  static Uint8List _encodeForOcr(img.Image crop) {
    final short = crop.width < crop.height ? crop.width : crop.height;
    var out = crop;
    if (short > 0 && short < _minOcrSide) {
      final scale = _minOcrSide / short;
      out = img.copyResize(
        crop,
        width: (crop.width * scale).round(),
        height: (crop.height * scale).round(),
        interpolation: img.Interpolation.cubic,
      );
    }
    return img.encodeJpg(out, quality: 92);
  }

  void dispose() {
    _closed = true;
    final recognizer = _recognizer;
    _recognizer = null;
    if (recognizer != null) unawaited(recognizer.close());
  }
}
