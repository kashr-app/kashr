import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/tag_turnover_sort.freezed.dart';
part '../../_gen/turnover/model/tag_turnover_sort.g.dart';

/// Enum for specifying which field to sort by for tag turnovers
enum TagTurnoverSortField {
  bookingDate,
  amount,
  createdAt;

  String label() {
    return switch (this) {
      TagTurnoverSortField.bookingDate => 'Booking Date',
      TagTurnoverSortField.amount => 'Amount',
      TagTurnoverSortField.createdAt => 'Created',
    };
  }
}

/// Enum for sort direction
enum TagTurnoverSortDirection { asc, desc }

/// Sort configuration for querying tag turnovers.
@freezed
abstract class TagTurnoverSort with _$TagTurnoverSort {
  const factory TagTurnoverSort({
    required TagTurnoverSortField orderBy,
    required TagTurnoverSortDirection direction,
  }) = _TagTurnoverSort;

  const TagTurnoverSort._();

  /// Default sort: bookingDate DESC
  static const defaultSort = TagTurnoverSort(
    orderBy: TagTurnoverSortField.bookingDate,
    direction: TagTurnoverSortDirection.desc,
  );

  /// Generates SQL ORDER BY clause based on sort configuration
  String toSqlOrderBy({String tableAlias = 'tt'}) {
    final fieldName = switch (orderBy) {
      TagTurnoverSortField.bookingDate => '$tableAlias.booking_date',
      TagTurnoverSortField.amount => 'ABS($tableAlias.amount_value)',
      TagTurnoverSortField.createdAt => '$tableAlias.created_at',
    };

    final directionStr = switch (direction) {
      TagTurnoverSortDirection.asc => 'ASC',
      TagTurnoverSortDirection.desc => 'DESC',
    };

    return '$fieldName $directionStr';
  }

  factory TagTurnoverSort.fromJson(Map<String, dynamic> json) =>
      _$TagTurnoverSortFromJson(json);

  TagTurnoverSort toggleDirection() {
    return copyWith(
      direction: direction == TagTurnoverSortDirection.asc
          ? TagTurnoverSortDirection.desc
          : TagTurnoverSortDirection.asc,
    );
  }
}
