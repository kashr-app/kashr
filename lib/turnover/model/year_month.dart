import 'package:freezed_annotation/freezed_annotation.dart';

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
    final now = DateTime.now();
    return YearMonth(year: now.year, month: now.month);
  }

  /// Creates a DateTime representing the first day of this month
  DateTime toDateTime() => DateTime(year, month);

  factory YearMonth.fromJson(Map<String, dynamic> json) =>
      _$YearMonthFromJson(json);
}
