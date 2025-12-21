import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/transfers_filter.freezed.dart';
part '../../_gen/turnover/model/transfers_filter.g.dart';

/// Filter for the transfers page.
@freezed
abstract class TransfersFilter with _$TransfersFilter {
  const factory TransfersFilter({
    /// If true, show only transfers that need review.
    /// If false, show all transfers.
    @Default(false) bool needsReviewOnly,
  }) = _TransfersFilter;

  const TransfersFilter._();

  /// Empty filter (shows all transfers).
  static const empty = TransfersFilter();

  /// Filter for showing only transfers that need review.
  static const needsReview = TransfersFilter(needsReviewOnly: true);

  /// Returns true if any filters are active.
  bool get hasFilters => needsReviewOnly;

  /// Merges the filter with [locked] filters to ensure locked filters
  /// are always applied.
  TransfersFilter lockWith(TransfersFilter locked) {
    return copyWith(needsReviewOnly: locked.needsReviewOnly || needsReviewOnly);
  }

  factory TransfersFilter.fromJson(Map<String, dynamic> json) =>
      _$TransfersFilterFromJson(json);
}
