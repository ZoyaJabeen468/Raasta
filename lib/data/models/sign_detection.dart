import 'traffic_sign.dart';

/// One decoded sign from a single frame, optionally enriched with OCR.
class SignDetection {
  const SignDetection({
    required this.sign,
    required this.confidence,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.at,
    this.ocrText,
    this.ocrSpeedLimit,
  });

  final TrafficSign sign;
  final double confidence;

  /// Normalized box in the full camera frame (0–1).
  final double left;
  final double top;
  final double right;
  final double bottom;

  final DateTime at;

  /// Cleaned OCR text from the sign crop (uppercase). Null until OCR ran.
  final String? ocrText;

  /// Speed limit read by OCR. Only set for [TrafficSign.isSpeedLimitCandidate].
  final int? ocrSpeedLimit;

  /// True when [other] is the same confirmed sighting (e.g. an OCR update).
  bool sameSightingAs(SignDetection other) =>
      sign == other.sign && at == other.at;

  SignDetection withOcr({String? text, int? speedLimit}) => SignDetection(
    sign: sign,
    confidence: confidence,
    left: left,
    top: top,
    right: right,
    bottom: bottom,
    at: at,
    ocrText: text,
    ocrSpeedLimit: speedLimit,
  );
}
