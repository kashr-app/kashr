import 'package:flutter_test/flutter_test.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/turnover/model/year_week.dart';

void main() {
  for (final startOfWeek in [StartOfWeek.monday, StartOfWeek.sunday]) {
    group('weeks starting on ${startOfWeek.name}', () {
      setUp(() => Jiffy.setLocale('en', startOfWeek: startOfWeek));

      test('a day falls inside the week it is numbered into', () {
        // Two years by the day, so the New Year boundary - where the number
        // and the bounds are most likely to disagree - is covered from both
        // sides rather than sampled.
        var day = BookingDate(2025, 1, 1);
        final endExclusive = BookingDate(2027, 1, 1);

        while (day.isBefore(endExclusive)) {
          final week = YearWeek.of(day);
          final offsetInWeek = week.firstDay.daysUntil(day);

          expect(
            offsetInWeek,
            inInclusiveRange(0, 6),
            reason:
                '$day was numbered ${week.year}-W${week.week}, which starts '
                'on ${week.firstDay}',
          );
          day = day.addDays(1);
        }
      });

      test('the last week of a year is the one December 28th falls in', () {
        // What the period picker counts to when it lists selectable weeks.
        for (final year in [2024, 2025, 2026]) {
          final lastWeek = YearWeek.of(BookingDate(year, 12, 28));

          final oneTooFar = YearWeek(year: year, week: lastWeek.week + 1);

          expect(lastWeek.year, year);
          expect(
            YearWeek.of(oneTooFar.firstDay),
            YearWeek(year: year + 1, week: 1),
            reason:
                'week ${oneTooFar.week} of $year is really the first week of '
                '${year + 1}, so the picker must stop at ${lastWeek.week}',
          );
        }
      });
    });
  }
}
