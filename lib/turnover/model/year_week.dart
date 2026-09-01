import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/model/period.dart';

part '../../_gen/turnover/model/year_week.freezed.dart';
part '../../_gen/turnover/model/year_week.g.dart';

/// Represents a specific year and week combination.
/// Both year and week are required to ensure a valid period.
///
/// Weeks start on the day the user configured, so the numbering is not ISO
/// unless they left it on Monday. Numbering and bounds both come from Jiffy's
/// configured locale, because deriving them from two different calendars is
/// how the week picker used to offer a number it then could not honour.
@freezed
abstract class YearWeek with _$YearWeek {
  const YearWeek._();

  const factory YearWeek({
    /// The year (e.g., 2024)
    required int year,

    /// The week number within [year] (1-53)
    required int week,
  }) = _YearWeek;

  /// Creates a YearWeek from the current date
  factory YearWeek.now() {
    return YearWeek.of(BookingDate.today());
  }

  /// Creates a YearWeek from the given day
  factory YearWeek.of(BookingDate day) {
    // A week that straddles New Year belongs to the year its middle falls in,
    // so it is counted once rather than as the last week of one year and the
    // first of the next.
    final midWeek = PeriodType.week.startOf(day).addDays(3);
    return YearWeek(
      year: midWeek.year,
      week: Jiffy.parseFromDateTime(midWeek.atMidnight).weekOfYear,
    );
  }

  /// The first day of this week, in the user's configured start day
  BookingDate get firstDay {
    // Jan 4th is in week 1 whatever day weeks start on, so it anchors the
    // count without a special case.
    final jan4 = Jiffy.parseFromDateTime(DateTime(year, 1, 4));
    final weekStart = jan4.startOf(Unit.week);
    return BookingDate.on(weekStart.add(weeks: week - 1).dateTime);
  }

  Period get period => Period(
    PeriodType.week,
    startInclusive: firstDay,
    endExclusive: firstDay.addPeriod(PeriodType.week),
  );

  factory YearWeek.fromJson(Map<String, dynamic> json) =>
      _$YearWeekFromJson(json);
}
