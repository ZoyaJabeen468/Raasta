/// Cleaned OCR text from a sign crop plus the speed limit it shows, if any.
class SignText {
  const SignText({required this.text, this.speedLimit});

  /// Uppercase, single-spaced. Empty when nothing was read.
  final String text;

  /// km/h when the text holds a plausible speed-limit number, else null.
  final int? speedLimit;
}

/// Pure Dart (no plugins) so it can be unit tested without a device.
SignText parseSignText(String raw) {
  final text = cleanSignText(raw);
  return SignText(text: text, speedLimit: parseSpeedLimit(text));
}

/// Uppercases and collapses all whitespace (including line breaks) to
/// single spaces.
String cleanSignText(String raw) =>
    raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Returns the first standalone 2–3 digit number from 10 to 120 that is a
/// multiple of 5 (10, 15, … 120). Everything else is ignored.
///
/// OCR often reads digits as look-alike letters (O→0, I/L→1, S→5). Those are
/// fixed only when the token is otherwise numeric, so words like "STOP" or
/// "SLOW" never turn into numbers. A trailing unit (KM, KMH, KPH, MPH) is
/// allowed, e.g. "60KMH".
int? parseSpeedLimit(String text) {
  final tokens = text.toUpperCase().split(RegExp(r'[^A-Z0-9]+'));
  for (final token in tokens) {
    final value = _speedFromToken(token);
    if (value != null) return value;
  }
  return null;
}

const _unitSuffixes = ['KMH', 'KPH', 'MPH', 'KM'];
const _lookAlikes = {'O': '0', 'I': '1', 'L': '1', 'S': '5'};

int? _speedFromToken(String token) {
  var core = token;
  for (final unit in _unitSuffixes) {
    if (core.length > unit.length && core.endsWith(unit)) {
      core = core.substring(0, core.length - unit.length);
      break;
    }
  }
  if (core.length < 2 || core.length > 3) return null;
  if (!core.contains(RegExp(r'[0-9]'))) return null;

  final digits = StringBuffer();
  for (final ch in core.split('')) {
    if (RegExp(r'[0-9]').hasMatch(ch)) {
      digits.write(ch);
    } else if (_lookAlikes.containsKey(ch)) {
      digits.write(_lookAlikes[ch]);
    } else {
      return null;
    }
  }

  final s = digits.toString();
  if (s.startsWith('0')) return null;
  final value = int.parse(s);
  if (value < 10 || value > 120 || value % 5 != 0) return null;
  return value;
}
