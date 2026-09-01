import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:kashr/core/model/booking_date.dart';
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
    return YearMonth.of(BookingDate.today());
  }

  /// Creates a YearMonth from the given day
  factory YearMonth.of(BookingDate day) {
    return YearMonth(year: day.year, month: day.month);
  }

  /// The first day of this month
  BookingDate get firstDay => BookingDate(year, month, 1);

  Period get period => Period(
    PeriodType.month,
    startInclusive: firstDay,
    endExclusive: firstDay.addPeriod(PeriodType.month),
  );

  factory YearMonth.fromJson(Map<String, dynamic> json) =>
      _$YearMonthFromJson(json);
}
