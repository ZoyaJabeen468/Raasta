import 'package:flutter_test/flutter_test.dart';

import 'package:raasta/data/models/traffic_sign.dart';

void main() {
  group('TrafficSign.fromClassId', () {
    test('maps model class ids', () {
      expect(TrafficSign.fromClassId(0), TrafficSign.mph20);
      expect(TrafficSign.fromClassId(18), TrafficSign.stop);
    });

    test('out-of-range ids are null', () {
      expect(TrafficSign.fromClassId(-1), isNull);
      expect(TrafficSign.fromClassId(24), isNull);
    });

    test('has exactly 24 classes', () {
      expect(TrafficSign.values.length, TrafficSign.numClasses);
    });
  });

  group('actions', () {
    test('stop speaks, no_parking shows, bus_stop is ignored', () {
      expect(TrafficSign.stop.action, SignAction.speak);
      expect(TrafficSign.noParking.action, SignAction.show);
      expect(TrafficSign.busStop.action, SignAction.ignore);
    });

    test('20_mph is a silent speed-limit candidate sent to OCR', () {
      expect(TrafficSign.mph20.action, SignAction.ignore);
      expect(TrafficSign.mph20.isSpeedLimitCandidate, isTrue);
      expect(TrafficSign.mph20.wantsOcr, isTrue);
      expect(TrafficSign.busStop.wantsOcr, isFalse);
      expect(TrafficSign.stop.isSpeedLimitCandidate, isFalse);
    });
  });
}
