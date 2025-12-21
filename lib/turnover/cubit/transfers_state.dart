import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/model/transfer_item.dart';
import 'package:finanalyzer/turnover/model/transfers_filter.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part '../../_gen/turnover/cubit/transfers_state.freezed.dart';

@freezed
abstract class TransfersState with _$TransfersState {
  const factory TransfersState({
    @Default(Status.initial) Status status,
    @Default({}) Map<UuidValue, TransferItem> transferItemsById,
    @Default(TransfersFilter.empty) TransfersFilter filter,
    @Default(TransfersFilter.empty) TransfersFilter lockedFilters,
    @Default(20) int limit,
    @Default(0) int offset,
    @Default(true) bool hasMore,
    @Default(false) bool isLoadingMore,
  }) = _TransfersState;
}
