import 'package:freezed_annotation/freezed_annotation.dart';

part '../../_gen/turnover/model/turnover_sort.freezed.dart';
part '../../_gen/turnover/model/turnover_sort.g.dart';

/// Enum for specifying which field to sort by
enum SortField {
  bookingDate,
  amount,
  counterPart,
}

/// Enum for sort direction
enum SortDirection {
  asc,
  desc,
}

/// Sort configuration for querying turnovers.
@freezed
abstract class TurnoverSort with _$TurnoverSort {
  const factory TurnoverSort({
    required SortField orderBy,
    required SortDirection direction,
  }) = _TurnoverSort;

  const TurnoverSort._();

  /// Default sort: bookingDate DESC
  static const defaultSort = TurnoverSort(
    orderBy: SortField.bookingDate,
    direction: SortDirection.desc,
  );

  /// Generates SQL ORDER BY clause based on sort configuration
  ///
  /// [tableAlias] is the table alias to use for column references (default: 't')
  String toSqlOrderBy({String tableAlias = 't'}) {
    final fieldName = switch (orderBy) {
      SortField.bookingDate => '$tableAlias.bookingDate',
      SortField.amount => 'ABS($tableAlias.amountValue)',
      SortField.counterPart => '$tableAlias.counterPart',
    };

    final directionStr = switch (direction) {
      SortDirection.asc => 'ASC',
      SortDirection.desc => 'DESC',
    };

    // For bookingDate, add NULLS FIRST/LAST handling
    if (orderBy == SortField.bookingDate) {
      final nullsHandling = direction == SortDirection.desc ? 'NULLS FIRST' : 'NULLS LAST';
      return '$fieldName $directionStr $nullsHandling';
    }

    return '$fieldName $directionStr';
  }

  factory TurnoverSort.fromJson(Map<String, dynamic> json) =>
      _$TurnoverSortFromJson(json);
}
