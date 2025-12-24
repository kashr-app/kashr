import 'package:kashr/core/uuid_json_converter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/model/tag_turnovers_filter.freezed.dart';
part '../../_gen/turnover/model/tag_turnovers_filter.g.dart';

/// Filter options for querying tag turnovers.
@freezed
abstract class TagTurnoversFilter with _$TagTurnoversFilter {
  const factory TagTurnoversFilter({
    /// Filter to show only transfer tag turnovers (tags with semantic='transfer')
    bool? transferTagOnly,

    /// Filter to only show such that are not yet linked to complete Transfer.
    ///
    /// This includes unlinked tag turnovers and linked ones if their Transfer
    /// only has a single side set. This excludes transfers, that have two
    /// sides even if the transfer needs review.
    bool? unfinishedTransfersOnly,

    /// Filter by specific period (year and month)
    YearMonth? period,

    /// Filter by specific tag IDs
    @UUIDListNullableJsonConverter() List<UuidValue>? tagIds,

    /// Filter by specific account IDs
    @UUIDListNullableJsonConverter() List<UuidValue>? accountIds,

    /// Filter by turnover sign (income/expense)
    TurnoverSign? sign,

    /// Search query for full-text search
    String? searchQuery,

    /// Filter by match status: null = all, true = matched only, false = pending only
    bool? isMatched,

    @UUIDListNullableJsonConverter() List<UuidValue>? excludeTagTurnoverIds,
  }) = _TagTurnoversFilter;

  const TagTurnoversFilter._();

  /// Returns true if any filters are active
  bool get hasFilters =>
      transferTagOnly == true ||
      unfinishedTransfersOnly == true ||
      period != null ||
      tagIds?.isNotEmpty == true ||
      accountIds?.isNotEmpty == true ||
      sign != null ||
      searchQuery?.isNotEmpty == true ||
      isMatched != null ||
      excludeTagTurnoverIds?.isNotEmpty == true;

  /// Merges this filter with [locked] filters to ensure locked filters
  /// are always applied.
  TagTurnoversFilter lockWith(TagTurnoversFilter locked) {
    return copyWith(
      transferTagOnly: locked.transferTagOnly ?? transferTagOnly,
      unfinishedTransfersOnly:
          locked.unfinishedTransfersOnly ?? unfinishedTransfersOnly,
      period: locked.period ?? period,
      tagIds: locked.tagIds ?? tagIds,
      accountIds: locked.accountIds ?? accountIds,
      sign: locked.sign ?? sign,
      searchQuery: locked.searchQuery ?? searchQuery,
      isMatched: locked.isMatched ?? isMatched,
      excludeTagTurnoverIds:
          locked.excludeTagTurnoverIds ?? excludeTagTurnoverIds,
    );
  }

  /// Returns a filter with all values set to null (no filtering)
  static const empty = TagTurnoversFilter();

  factory TagTurnoversFilter.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoversFilterFromJson(json);
}
