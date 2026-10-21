import 'package:flutter_test/flutter_test.dart';

import 'package:raasta/data/models/sign_detection.dart';
import 'package:raasta/data/models/traffic_sign.dart';
import 'package:raasta/data/services/sign_confirmer.dart';

SignDetection hit(TrafficSign sign, {double conf = 0.9, DateTime? at}) =>
    SignDetection(
      sign: sign,
      confidence: conf,
      left: 0.4,
      top: 0.2,
      right: 0.5,
      bottom: 0.3,
      at: at ?? DateTime(2026),
    );

void main() {
  final t0 = DateTime(2026, 1, 1, 12);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  group('SignConfirmer', () {
    test('confirms only after 3 consecutive frames', () {
      final c = SignConfirmer();
      expect(c.add([hit(TrafficSign.stop)], at(0)), isNull);
      expect(c.add([hit(TrafficSign.stop)], at(1)), isNull);
      expect(c.add([hit(TrafficSign.stop)], at(2))?.sign, TrafficSign.stop);
    });

    test('a missed frame resets the streak', () {
      final c = SignConfirmer();
      c.add([hit(TrafficSign.stop)], at(0));
      c.add([hit(TrafficSign.stop)], at(1));
      c.add([], at(2));
      expect(c.add([hit(TrafficSign.stop)], at(3)), isNull);
    });

    test('same sign is not confirmed again within the cooldown', () {
      final c = SignConfirmer();
      for (var i = 0; i < 3; i++) {
        c.add([hit(TrafficSign.stop)], at(i));
      }
      for (var i = 3; i < 6; i++) {
        expect(c.add([hit(TrafficSign.stop)], at(i)), isNull);
      }
      // Sign leaves view, then is seen again 20+ s after the first confirm.
      c.add([], at(6));
      c.add([hit(TrafficSign.stop)], at(21));
      c.add([hit(TrafficSign.stop)], at(22));
      expect(c.add([hit(TrafficSign.stop)], at(23))?.sign, TrafficSign.stop);
    });

    test('low confidence and plain ignore classes never confirm', () {
      final c = SignConfirmer();
      for (var i = 0; i < 5; i++) {
        expect(
          c.add([
            hit(TrafficSign.stop, conf: 0.4),
            hit(TrafficSign.busStop),
          ], at(i)),
          isNull,
        );
      }
    });

    test('speed-limit candidate confirms (for OCR)', () {
      final c = SignConfirmer();
      c.add([hit(TrafficSign.mph20)], at(0));
      c.add([hit(TrafficSign.mph20)], at(1));
      expect(c.add([hit(TrafficSign.mph20)], at(2))?.sign, TrafficSign.mph20);
    });

    test('spoken signs win over shown signs and the candidate', () {
      final c = SignConfirmer();
      List<SignDetection> frame() => [
        hit(TrafficSign.mph20, conf: 0.99),
        hit(TrafficSign.noParking, conf: 0.95),
        hit(TrafficSign.stop, conf: 0.7),
      ];
      c.add(frame(), at(0));
      c.add(frame(), at(1));
      expect(c.add(frame(), at(2))?.sign, TrafficSign.stop);
    });
  });

  group('OcrGate', () {
    test('one job at a time', () {
      final g = OcrGate();
      expect(g.tryBegin(TrafficSign.stop, at(0)), isTrue);
      expect(g.tryBegin(TrafficSign.noParking, at(0)), isFalse);
      g.end();
      expect(g.tryBegin(TrafficSign.noParking, at(1)), isTrue);
    });

    test('same sign at most once per 10 s', () {
      final g = OcrGate();
      expect(g.tryBegin(TrafficSign.mph20, at(0)), isTrue);
      g.end();
      expect(g.tryBegin(TrafficSign.mph20, at(9)), isFalse);
      expect(g.tryBegin(TrafficSign.mph20, at(10)), isTrue);
    });

    test('plain ignore classes are never read', () {
      final g = OcrGate();
      expect(g.tryBegin(TrafficSign.busStop, at(0)), isFalse);
      expect(g.isBusy, isFalse);
    });
  });
}
