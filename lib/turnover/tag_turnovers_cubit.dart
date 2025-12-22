import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_sort.dart';
import 'package:finanalyzer/turnover/model/tag_turnovers_filter.dart';
import 'package:finanalyzer/turnover/model/transfer_repository.dart';
import 'package:finanalyzer/turnover/model/transfer_with_details.dart';
import 'package:finanalyzer/turnover/services/transfer_service.dart';
import 'package:finanalyzer/turnover/tag_turnovers_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing the tag turnovers page state.
class TagTurnoversCubit extends Cubit<TagTurnoversState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TransferRepository _transferRepository;
  final TransferService _transferService;
  final Logger _log;

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
    // Start loading async (no await)
    loadMore();
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
        items: [],
        transferByTagTurnoverId: {},
        currentOffset: 0,
        hasMore: true,
        error: null,
      ),
    );
    await loadMore();
  }

  /// Loads the next page of tag turnovers.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    emit(state.copyWith(isLoading: true, error: null));

    try {
      final newItems = await _tagTurnoverRepository.getTagTurnoversPaginated(
        limit: _pageSize,
        offset: state.currentOffset,
        filter: state.filter,
        sort: state.sort,
      );

      // Fetch transfer information for new items
      final transfersMap = await _loadTransfersForItems(newItems);

      emit(
        state.copyWith(
          items: [...state.items, ...newItems],
          transferByTagTurnoverId: {
            ...state.transferByTagTurnoverId,
            ...transfersMap,
          },
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
    List<TagTurnover> items,
  ) async {
    try {
      final tagTurnoverIds = items.map((item) => item.id).toList();

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
      await refresh();
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
      await refresh();
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
      await refresh();
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
