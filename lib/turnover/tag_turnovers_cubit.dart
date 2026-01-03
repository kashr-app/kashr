import 'dart:async';

import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/extensions/map_extensios.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_change.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:kashr/turnover/tag_turnovers_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing the tag turnovers page state.
class TagTurnoversCubit extends Cubit<TagTurnoversState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TransferRepository _transferRepository;
  final TransferService _transferService;
  final Logger _log;

  StreamSubscription<TagTurnoverChange>? _tagTurnoverSubscription;
  StreamSubscription<TransferChange>? _transferSubscription;

  static const _pageSize = 10;

  TagTurnoversCubit(
    this._tagTurnoverRepository,
    this._transferRepository,
    this._transferService,
    this._log, {
    required TagTurnoversFilter initialFilter,
    required TagTurnoverSort initialSort,
    TagTurnoversFilter lockedFilters = TagTurnoversFilter.empty,
  }) : super(
         TagTurnoversState(
           filter: initialFilter.lockWith(lockedFilters),
           sort: initialSort,
         ),
       ) {
    unawaited(loadMore());

    _tagTurnoverSubscription = _tagTurnoverRepository.watchChanges().listen(
      _onTagTurnoverChanged,
    );

    _transferSubscription = _transferRepository.watchChanges().listen(
      _onTransferChanged,
    );
  }

  @override
  Future<void> close() async {
    await _tagTurnoverSubscription?.cancel();
    await _transferSubscription?.cancel();
    return super.close();
  }

  Future<void> _onTagTurnoverChanged(TagTurnoverChange change) async {
    switch (change) {
      case TagTurnoversInserted(:final tagTurnovers):
        final copy = await _setItems(tagTurnovers.associateBy((it) => it.id));

        final valueFn = state.sort.orderBy.valueFn;
        final isAsc = state.sort.direction.isAsc;
        final itemById = copy.itemById.sortedByValue(valueFn, isAsc: isAsc);

        emit(copy.copyWith(itemById: itemById));
      case TagTurnoversUpdated(:final tagTurnovers):
        final newState = await _setItems(
          tagTurnovers.associateBy((it) => it.id),
        );
        emit(newState);
      case TagTurnoversDeleted(:final ids):
        final idsSet = ids.toSet();
        final itemByIdFiltered = state.itemById.where(
          (id, _) => !idsSet.contains(id),
        );
        emit(state.copyWith(itemById: itemByIdFiltered));
    }
  }

  Future<void> _onTransferChanged(TransferChange change) async {
    switch (change) {
      case TransferCreated(:final transfer):
        emit(
          state.copyWith(
            transferByTagTurnoverId: {
              ...state.transferByTagTurnoverId,
              if (transfer.fromTagTurnover?.id != null)
                transfer.fromTagTurnover!.id: transfer,
              if (transfer.toTagTurnover?.id != null)
                transfer.toTagTurnover!.id: transfer,
            },
          ),
        );
      case TransferUpdated(:final transfer):
        final transferDetailsByTTId = await _loadTransfersForItems(
          [transfer.fromTagTurnoverId, transfer.toTagTurnoverId].nonNulls,
        );
        final from = transferDetailsByTTId[transfer.fromTagTurnoverId];
        final to = transferDetailsByTTId[transfer.toTagTurnoverId];

        final newTransferByTTId = <UuidValue, TransferWithDetails>{
          ...state.transferByTagTurnoverId.where(
            (ttId, oldTransfer) => oldTransfer.transfer.id != transfer.id,
          ),
          if (transfer.fromTagTurnoverId != null && from != null)
            transfer.fromTagTurnoverId!: from,
          if (transfer.toTagTurnoverId != null && to != null)
            transfer.toTagTurnoverId!: to,
        };
        emit(state.copyWith(transferByTagTurnoverId: newTransferByTTId));
      case TransferDeleted(:final transfer):
        final newTransferByTTId = <UuidValue, TransferWithDetails>{
          ...state.transferByTagTurnoverId.where(
            (ttId, oldTransfer) => oldTransfer.transfer.id != transfer.id,
          ),
        };
        emit(state.copyWith(transferByTagTurnoverId: newTransferByTTId));
    }
  }

  /// Updates the filter and reloads data.
  void updateFilter(TagTurnoversFilter newFilter) {
    emit(state.copyWith(filter: newFilter));
    refresh();
  }

  /// Updates the sort and reloads data.
  void updateSort(TagTurnoverSort newSort) {
    emit(state.copyWith(sort: newSort));
    refresh();
  }

  /// Refreshes the list by clearing all data and reloading.
  Future<void> refresh() async {
    emit(
      state.copyWith(
        itemById: {},
        transferByTagTurnoverId: {},
        currentOffset: 0,
        hasMore: true,
        error: null,
      ),
    );
    await loadMore();
  }

  Future<TagTurnoversState> _setItems(
    Map<UuidValue, TagTurnover> itemById,
  ) async {
    // Fetch transfer information for new/updated items
    final transfersMap = await _loadTransfersForItems(itemById.keys);

    // keep order for existing items
    final itemByIdNew = {...state.itemById};
    for (final it in itemById.entries) {
      itemByIdNew[it.key] = it.value;
    }

    return state.copyWith(
      itemById: itemByIdNew,
      transferByTagTurnoverId: {
        ...state.transferByTagTurnoverId,
        ...transfersMap,
      },
    );
  }

  /// Loads the next page of tag turnovers.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final newItems = (await _tagTurnoverRepository.getTagTurnoversPaginated(
        limit: _pageSize,
        offset: state.currentOffset,
        filter: state.filter,
        sort: state.sort,
      )).associateBy((it) => it.id);

      final copy = await _setItems(newItems);

      emit(
        copy.copyWith(
          currentOffset: state.currentOffset + newItems.length,
          hasMore: newItems.length >= _pageSize,
          isLoading: false,
        ),
      );
    } catch (error, stackTrace) {
      _log.e(
        'Error fetching tag turnovers page',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(error: error.toString(), isLoading: false));
    }
  }

  /// Loads transfer information for the given tag turnovers.
  Future<Map<UuidValue, TransferWithDetails>> _loadTransfersForItems(
    Iterable<UuidValue> tagTurnoverIds,
  ) async {
    try {
      // Get transfer IDs for these tag turnovers
      final transferIdByTagTurnoverId = await _transferRepository
          .getTransferIdsForTagTurnovers(tagTurnoverIds);

      if (transferIdByTagTurnoverId.isEmpty) return {};

      // Fetch transfer details
      final transferIds = transferIdByTagTurnoverId.values.toSet().toList();
      final transfersWithDetails = await _transferService
          .getTransfersWithDetails(transferIds);

      // Map transfers back to tag turnover IDs
      final result = <UuidValue, TransferWithDetails>{};
      for (final entry in transferIdByTagTurnoverId.entries) {
        final tagTurnoverId = entry.key;
        final transferId = entry.value;
        final transferDetails = transfersWithDetails[transferId];
        if (transferDetails != null) {
          result[tagTurnoverId] = transferDetails;
        }
      }
      return result;
    } catch (error, stackTrace) {
      _log.e(
        'Error loading transfers for tag turnovers',
        error: error,
        stackTrace: stackTrace,
      );
      // Don't fail the whole operation if transfer loading fails
      return {};
    }
  }

  /// Toggles selection for a tag turnover.
  void toggleSelection(UuidValue id) {
    final newSelectedIds = Set<UuidValue>.from(state.selectedIds);
    if (newSelectedIds.contains(id)) {
      newSelectedIds.remove(id);
    } else {
      newSelectedIds.add(id);
    }
    emit(state.copyWith(selectedIds: newSelectedIds));
  }

  /// Clears all selections.
  void clearSelection() {
    emit(state.copyWith(selectedIds: {}));
  }

  /// Batch deletes the selected tag turnovers.
  Future<bool> batchDelete() async {
    if (state.selectedIds.isEmpty) return false;

    try {
      final idsToDelete = state.selectedIds.toList();
      await _tagTurnoverRepository.deleteTagTurnoversBatch(idsToDelete);

      clearSelection();
      return true;
    } catch (error, stackTrace) {
      _log.e(
        'Error batch deleting tag turnovers',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(error: error.toString()));
      return false;
    }
  }

  /// Updates a tag turnover.
  Future<void> updateTagTurnover(TagTurnover tagTurnover) async {
    try {
      await _tagTurnoverRepository.updateTagTurnover(tagTurnover);
    } catch (error, stackTrace) {
      _log.e(
        'Error updating tag turnover',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(error: error.toString()));
    }
  }

  /// Deletes a tag turnover.
  Future<void> deleteTagTurnover(UuidValue id) async {
    try {
      await _tagTurnoverRepository.deleteTagTurnover(id);
    } catch (error, stackTrace) {
      _log.e(
        'Error deleting tag turnover',
        error: error,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(error: error.toString()));
    }
  }
}
