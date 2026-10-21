import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/widgets/ambient_scaffold.dart';
import '../../../data/models/traffic_sign.dart';
import '../../../data/services/ocr_service.dart';
import '../../../data/services/sign_detector.dart';
import '../../../data/services/sign_interpreter.dart';
import '../../../data/services/tts_service.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/app_card.dart';

/// M3 demo: run the sign model + OCR on a picked photo. Works without a
/// phone camera (Android emulator gallery / virtual camera).
class SignTestScreen extends StatefulWidget {
  const SignTestScreen({super.key});

  @override
  State<SignTestScreen> createState() => _SignTestScreenState();
}

/// One detected sign plus what OCR read from its crop.
class _SignResult {
  const _SignResult({required this.detection, this.ocr, this.note});

  final SignDetection detection;
  final SignOcrResult? ocr;

  /// Why OCR has no result (crop too small, OCR unavailable…).
  final String? note;
}

class _SignTestScreenState extends State<SignTestScreen> {
  /// OCR only the most confident boxes, like the live gate.
  static const _maxOcrBoxes = 3;

  final _model = SignInterpreter(stillImage: true);
  final _ocr = OcrService();
  final _tts = TtsService();

  bool _busy = false;
  String? _error;
  Uint8List? _preview;
  double _aspect = 1;
  List<_SignResult> _results = const [];

  @override
  void dispose() {
    _model.close();
    _ocr.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, maxWidth: 1600);
    } catch (e) {
      _showSnack('Could not open the ${source.name}: $e');
      return;
    }
    if (picked == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _results = const [];
    });
    try {
      await _analyze(await picked.readAsBytes());
    } catch (e) {
      debugPrint('Sign test failed: $e');
      if (mounted) setState(() => _error = 'Could not analyse image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze(Uint8List bytes) async {
    if (!await _model.load()) {
      setState(() => _error = 'Sign model failed to load: ${_model.lastDebug}');
      return;
    }

    // EXIF rotation is baked in so boxes line up with the preview.
    final decoded = await Isolate.run(() {
      final raw = img.decodeImage(bytes);
      if (raw == null) return null;
      final upright = img.bakeOrientation(raw);
      return (upright, img.encodeJpg(upright, quality: 85));
    });
    if (decoded == null) {
      setState(() => _error = 'Unsupported image format.');
      return;
    }
    final (rgb, preview) = decoded;
    if (!mounted) return;
    setState(() {
      _preview = preview;
      _aspect = rgb.width / rgb.height;
    });

    final size = _model.inputSize;
    final nchw = _model.isNchw;
    final prepared = await Isolate.run(
      () => SignInterpreter.prepareFrame(rgb, size, nchw),
    );
    final hits = List.of(await _model.detectPrepared(prepared))
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    debugPrint('Sign test ${_model.lastDebug} hits=${hits.length}');

    final results = <_SignResult>[];
    for (var i = 0; i < hits.length; i++) {
      final d = hits[i];
      if (i >= _maxOcrBoxes) {
        results.add(_SignResult(detection: d, note: 'OCR skipped'));
        continue;
      }
      if (!OcrService.isSupported) {
        results.add(
          _SignResult(detection: d, note: 'OCR needs Android or iOS'),
        );
        continue;
      }
      final crop = cropSignFromImage(rgb, d);
      if (crop == null) {
        results.add(_SignResult(detection: d, note: 'Crop too small for OCR'));
        continue;
      }
      final ocr = await _ocr.readSign(crop, sign: d.sign.classLabel);
      results.add(
        _SignResult(
          detection: d,
          ocr: ocr,
          note: ocr == null ? 'OCR failed (see log)' : null,
        ),
      );
    }
    if (mounted) setState(() => _results = results);
  }

  Future<void> _speak(_SignResult r) async {
    final language = context.read<SettingsProvider>().settings.language;
    final sign = r.detection.sign;
    final limit = r.ocr?.speedLimit;
    if (sign.isSpeedLimitCandidate) {
      if (limit == null) {
        _showSnack('No speed limit read, so the app stays silent.');
        return;
      }
      await _tts.announceSpeedLimit(language, limitKph: limit);
      return;
    }
    await _tts.announceSign(language, english: sign.english, urdu: sign.urdu);
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final preview = _preview;

    return AmbientScaffold(
      appBar: AppBar(title: const Text('Sign recognition test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            Text(
              'Pick a photo with a road sign. The sign model and English OCR '
              'run on this device, exactly as on the Drive screen.',
              style: GoogleFonts.dmSans(color: p.textSecondary, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: GoogleFonts.dmSans(color: AppColors.alert),
                ),
              ),
            if (preview != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: _aspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(preview, fit: BoxFit.fill),
                      CustomPaint(
                        painter: _BoxPainter([
                          for (final r in _results) r.detection,
                        ]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_busy && _results.isEmpty && _error == null)
                Text(
                  'No sign found above '
                  '${(SignInterpreter.confThreshold * 100).round()}% '
                  'confidence (${_model.lastDebug}).',
                  style: GoogleFonts.dmSans(color: p.textSecondary),
                ),
              for (final r in _results) ...[
                _ResultCard(result: r, onSpeak: () => _speak(r)),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onSpeak});

  final _SignResult result;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = result.detection;
    final sign = d.sign;
    final ocr = result.ocr;
    final canSpeak = sign.isSpeedLimitCandidate || sign.english.isNotEmpty;

    Widget line(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: GoogleFonts.dmSans(
                color: p.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: GoogleFonts.dmSans(color: p.textPrimary),
            ),
          ],
        ),
      ),
    );

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(sign.icon, color: sign.color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sign.title,
                  style: GoogleFonts.sora(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                line('Class', sign.classLabel),
                line('Confidence', '${(d.confidence * 100).toStringAsFixed(1)}%'),
                line('Action', _actionLabel(sign)),
                line(
                  'OCR text',
                  ocr == null
                      ? (result.note ?? '-')
                      : (ocr.text.isEmpty ? '(none)' : '"${ocr.text}"'),
                ),
                line('Speed limit', ocr?.speedLimit?.toString() ?? '-'),
                if (ocr != null) line('OCR time', '${ocr.elapsedMs} ms'),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Speak',
            onPressed: canSpeak ? onSpeak : null,
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
    );
  }

  static String _actionLabel(TrafficSign sign) {
    if (sign.isSpeedLimitCandidate) return 'speed-limit candidate (OCR)';
    return sign.action.name;
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.detections);

  final List<SignDetection> detections;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in detections) {
      final rect = Rect.fromLTRB(
        d.left * size.width,
        d.top * size.height,
        d.right * size.width,
        d.bottom * size.height,
      );
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = d.sign.color;
      canvas.drawRect(rect, paint);

      final label = TextPainter(
        text: TextSpan(
          text: ' ${d.sign.classLabel} ${(d.confidence * 100).round()}% ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            background: Paint()..color = d.sign.color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dy = rect.top - label.height < 0 ? rect.top : rect.top - label.height;
      label.paint(canvas, Offset(rect.left, dy));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.detections != detections;
}
