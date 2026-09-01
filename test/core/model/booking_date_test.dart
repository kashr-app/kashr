import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/booking_date.dart';

void main() {
  group('on', () {
    test('keeps the day and drops the time', () {
      final date = BookingDate.on(DateTime(2026, 9, 30, 14, 23, 45, 678));

      expect(date, BookingDate(2026, 9, 30));
    });

    test('reads two moments of one day as the same day', () {
      expect(
        BookingDate.on(DateTime(2026, 9, 30, 0, 1)),
        BookingDate.on(DateTime(2026, 9, 30, 23, 59)),
      );
    });
  });

  group('parse', () {
    test('reads a stored day', () {
      expect(BookingDate.parse('2026-09-30'), BookingDate(2026, 9, 30));
    });

    test('reads a timestamp written before the format was normalised', () {
      expect(
        BookingDate.parse('2026-09-30T14:23:00.000'),
        BookingDate(2026, 9, 30),
      );
    });
  });

  group('iso', () {
    test('pads every field', () {
      expect(BookingDate(2026, 1, 5).iso, '2026-01-05');
    });

    test('orders the same way SQL compares the stored text', () {
      final days = [
        BookingDate(2026, 10, 1),
        BookingDate(2026, 9, 30),
        BookingDate(2026, 1, 5),
      ]..sort();

      expect(days.map((it) => it.iso), [
        '2026-01-05',
        '2026-09-30',
        '2026-10-01',
      ]);
    });
  });

  group('addDays', () {
    test('rolls over into the next month', () {
      expect(BookingDate(2026, 1, 31).addDays(1), BookingDate(2026, 2, 1));
    });

    test('rolls back over a year boundary', () {
      expect(BookingDate(2026, 1, 1).addDays(-1), BookingDate(2025, 12, 31));
    });

    test('lands on the next day across a daylight saving change', () {
      expect(BookingDate(2026, 3, 28).addDays(1), BookingDate(2026, 3, 29));
    });
  });

  group('daysUntil', () {
    test('counts calendar days, not elapsed hours', () {
      // The local day of a DST switch is 23 or 25 hours long, so a Duration
      // based answer rounds to 0 or 2 here.
      expect(BookingDate(2026, 3, 28).daysUntil(BookingDate(2026, 3, 29)), 1);
    });

    test('is negative looking backwards', () {
      expect(BookingDate(2026, 9, 30).daysUntil(BookingDate(2026, 9, 23)), -7);
    });

    test('is zero on the same day', () {
      expect(BookingDate(2026, 9, 30).daysUntil(BookingDate(2026, 9, 30)), 0);
    });
  });
}
