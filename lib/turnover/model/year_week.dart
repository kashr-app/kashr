import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/core/model/period.dart';

part '../../_gen/turnover/model/year_week.freezed.dart';
part '../../_gen/turnover/model/year_week.g.dart';

/// Represents a specific year and week combination.
/// Both year and week are required to ensure a valid period.
@freezed
abstract class YearWeek with _$YearWeek {
  const YearWeek._();

  const factory YearWeek({
    /// The year (e.g., 2024)
    required int year,

    /// The ISO week number (1-53)
    required int week,
  }) = _YearWeek;

  /// Creates a YearWeek from the current date
  factory YearWeek.now() {
    return YearWeek.of(DateTime.now());
  }

  /// Creates a YearWeek from the given date
  factory YearWeek.of(DateTime date) {
    final weekData = _getIsoWeekNumber(date);
    return YearWeek(year: weekData.$1, week: weekData.$2);
  }

  /// Creates a DateTime representing the first day of this week (Monday)
  DateTime toDateTime() {
    // Start from Jan 4th which is always in week 1
    final jan4 = DateTime(year, 1, 4);
    final jiffy = Jiffy.parseFromDateTime(jan4);
    final weekStart = jiffy.startOf(Unit.week);
    // Add weeks to get to the desired week
    return weekStart.add(weeks: week - 1).dateTime;
  }

  /// Calculates ISO 8601 week number for a given date.
  /// Returns (year, week) tuple.
  static (int, int) _getIsoWeekNumber(DateTime date) {
    // ISO 8601: Week 1 is the first week with a Thursday in it
    // Weeks start on Monday (1) and end on Sunday (7)

    // Get the Thursday of the current week
    final thursday = date.add(Duration(days: DateTime.thursday - date.weekday));

    // January 4th is always in week 1
    final jan4 = DateTime(thursday.year, 1, 4);

    // Find the Monday of week 1
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));

    // Calculate the week number
    final weekNumber =
        ((thursday.difference(week1Monday).inDays) / 7).floor() + 1;

    return (thursday.year, weekNumber);
  }

  Period get period {
    final startDate = Jiffy.parseFromDateTime(toDateTime());
    return Period(
      PeriodType.week,
      startInclusive: startDate.dateTime,
      endExclusive: startDate.add(weeks: 1).dateTime,
    );
  }

  factory YearWeek.fromJson(Map<String, dynamic> json) =>
      _$YearWeekFromJson(json);
}
