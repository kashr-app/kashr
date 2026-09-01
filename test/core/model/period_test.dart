import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/period.dart';

void main() {
  group('of', () {
    test('ends where the next period begins', () {
      final period = Period.of(DateTime(2026, 9, 15), PeriodType.month);

      expect(period.startInclusive, DateTime(2026, 9, 1));
      expect(period.endExclusive, DateTime(2026, 10, 1));
      expect(period.endExclusive, period.add().startInclusive);
    });
  });
}
