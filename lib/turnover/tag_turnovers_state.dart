import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../_gen/turnover/tag_turnovers_state.freezed.dart';

@freezed
abstract class TagTurnoversState with _$TagTurnoversState {
  const factory TagTurnoversState({
    @Default({}) Map<UuidValue, TagTurnover> itemById,
    @Default({}) Map<UuidValue, TransferWithDetails> transferByTagTurnoverId,
    @Default(0) int currentOffset,
    @Default(false) bool isLoading,
    @Default(true) bool hasMore,
    String? error,
    required TagTurnoversFilter filter,
    required TagTurnoverSort sort,
    @Default({}) Set<UuidValue> selectedIds,
  }) = _TagTurnoversState;
}
