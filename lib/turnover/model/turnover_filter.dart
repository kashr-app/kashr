import 'package:kashr/core/uuid_json_converter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

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

    /// Filter by specific tag IDs
    /// If provided, only turnovers with ALL these tags are shown
    @UUIDListNullableJsonConverter() List<UuidValue>? tagIds,

    // Filter by account
    @UUIDNullableJsonConverter() UuidValue? accountId,

    /// Filter by turnover sign (income/expense)
    /// If null, shows both income and expenses
    TurnoverSign? sign,

    /// Search query for full-text search across turnover purpose,
    /// counterpart, tag names, and tag_turnover notes
    String? searchQuery,
  }) = _TurnoverFilter;

  const TurnoverFilter._();

  /// Returns true if any filters are active
  bool get hasFilters =>
      unallocatedOnly == true ||
      period != null ||
      (tagIds != null && tagIds!.isNotEmpty) ||
      accountId != null ||
      sign != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  /// Returns a filter with all values set to null (no filtering)
  static const empty = TurnoverFilter();

  factory TurnoverFilter.fromJson(Map<String, dynamic> json) =>
      _$TurnoverFilterFromJson(json);
}
