import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/turnover_filter.freezed.dart';
part '../../_gen/turnover/model/turnover_filter.g.dart';

/// Filter options for querying turnovers.
@freezed
abstract class TurnoverFilter with _$TurnoverFilter {
  const factory TurnoverFilter({
    /// Filter to show only unallocated turnovers (turnovers without tags
    /// or where tag amounts don't sum to turnover amount)
    bool? unallocatedOnly,

    /// Filter by specific period (year and month)
    /// Both year and month must be provided together to ensure a valid filter
    YearMonth? period,

    /// Filter by specific tag IDs (UUIDs as strings)
    /// If provided, only turnovers with ALL these tags are shown
    List<String>? tagIds,

    /// Filter by turnover sign (income/expense)
    /// If null, shows both income and expenses
    TurnoverSign? sign,
  }) = _TurnoverFilter;

  const TurnoverFilter._();

  /// Returns true if any filters are active
  bool get hasFilters =>
      unallocatedOnly == true ||
      period != null ||
      (tagIds != null && tagIds!.isNotEmpty) ||
      sign != null;

  /// Returns a filter with all values set to null (no filtering)
  static const empty = TurnoverFilter();

  factory TurnoverFilter.fromJson(Map<String, dynamic> json) =>
      _$TurnoverFilterFromJson(json);
}
