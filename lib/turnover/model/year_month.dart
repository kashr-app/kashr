import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:jiffy/jiffy.dart';
import 'package:kashr/core/model/period.dart';

part '../../_gen/turnover/model/year_month.freezed.dart';
part '../../_gen/turnover/model/year_month.g.dart';

/// Represents a specific year and month combination.
/// Both year and month are required to ensure a valid period.
@freezed
abstract class YearMonth with _$YearMonth {
  const YearMonth._();

  const factory YearMonth({
    /// The year (e.g., 2024)
    required int year,

    /// The month (1-12)
    required int month,
  }) = _YearMonth;

  /// Creates a YearMonth from the current date
  factory YearMonth.now() {
    return YearMonth.of(DateTime.now());
  }

  /// Creates a YearMonth from the given date
  factory YearMonth.of(DateTime date) {
    return YearMonth(year: date.year, month: date.month);
  }

  /// Creates a DateTime representing the first day of this month
  DateTime toDateTime() => DateTime(year, month);

  Period get period {
    final startDate = Jiffy.parseFromDateTime(toDateTime());
    return Period(
      PeriodType.month,
      startInclusive: startDate.dateTime,
      endExclusive: startDate.add(months: 1).dateTime,
    );
  }

  factory YearMonth.fromJson(Map<String, dynamic> json) =>
      _$YearMonthFromJson(json);
}
