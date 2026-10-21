import 'package:flutter_test/flutter_test.dart';

import 'package:raasta/core/utils/sign_text_parser.dart';

void main() {
  group('parseSpeedLimit', () {
    final cases = <String, int?>{
      '60': 60,
      'SPEED LIMIT 40': 40,
      '6O': 60,
      'STOP': null,
      '7': null,
      '130': null,
      '55': 55,
      '': null,
    };
    cases.forEach((input, expected) {
      test("'$input' -> $expected", () {
        expect(parseSpeedLimit(input), expected);
      });
    });

    test('fixes look-alike letters only in numeric tokens', () {
      expect(parseSpeedLimit('I2O'), 120);
      expect(parseSpeedLimit('S0'), 50);
      expect(parseSpeedLimit('SO'), isNull);
      expect(parseSpeedLimit('SLOW'), isNull);
    });

    test('rejects non-multiples of 5 and out-of-range values', () {
      expect(parseSpeedLimit('42'), isNull);
      expect(parseSpeedLimit('5'), isNull);
      expect(parseSpeedLimit('125'), isNull);
      expect(parseSpeedLimit('060'), isNull);
    });

    test('accepts a trailing unit', () {
      expect(parseSpeedLimit('80KMH'), 80);
      expect(parseSpeedLimit('50 km/h'), 50);
    });
  });

  group('parseSignText', () {
    test('uppercases and collapses whitespace', () {
      final r = parseSignText('  speed\nlimit   60 ');
      expect(r.text, 'SPEED LIMIT 60');
      expect(r.speedLimit, 60);
    });

    test('empty input gives empty text and no limit', () {
      final r = parseSignText('');
      expect(r.text, '');
      expect(r.speedLimit, isNull);
    });
  });
}
