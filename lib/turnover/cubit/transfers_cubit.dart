import 'dart:async';

import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/cubit/transfers_state.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_item.dart';
import 'package:kashr/turnover/model/transfers_filter.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing the transfers page state.
class TransfersCubit extends Cubit<TransfersState> {
  final TransferRepository _transferRepository;
  final TransferService _transferService;
  StreamSubscription<TransferChange>? _transferChangeSubscription;

  final Logger _log;

  TransfersCubit(
    this._transferRepository,
    this._transferService,
    this._log, {
    TransfersFilter initialFilter = TransfersFilter.empty,
    TransfersFilter lockedFilters = TransfersFilter.empty,
  }) : super(
         TransfersState(
           filter: initialFilter.lockWith(lockedFilters),
           lockedFilters: lockedFilters,
         ),
       ) {
    _transferChangeSubscription = _transferRepository.watchChanges().listen(
      _onTransferChange,
      onError: (error, stackTrace) {
        _log.e(
          'Error in transfer changes stream',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    // start loading async (no await)
    loadTransfers();
  }

  @override
  Future<void> close() {
    _transferChangeSubscription?.cancel();
    return super.close();
  }

  void _onTransferChange(TransferChange change) async {
    // When transfers change, reload all items to stay in sync
    await loadTransfers();
  }

  /// Updates the filter and reloads data.
  void updateFilter(TransfersFilter newFilter) {
    emit(state.copyWith(filter: newFilter.lockWith(state.lockedFilters)));
    loadTransfers();
  }

  /// Loads transfer items based on the current filter.
  /// This resets pagination and loads the first page.
  Future<void> loadTransfers() async {
    emit(
      state.copyWith(
        status: Status.loading,
        offset: 0,
        hasMore: true,
        transferItemsById: {},
      ),
    );

    try {
      final transferItemsById = await _transferService.getTransferReviewItems(
        filter: state.filter,
        limit: state.limit,
        offset: 0,
      );

      emit(
        state.copyWith(
          status: Status.success,
          transferItemsById: transferItemsById,
          offset: transferItemsById.length,
          hasMore: transferItemsById.length >= state.limit,
        ),
      );
    } catch (e, stackTrace) {
      _log.e('Failed to load transfer items', error: e, stackTrace: stackTrace);
      emit(state.copyWith(status: Status.error));
    }
  }

  /// Loads the next page of transfer items.
  Future<void> loadMoreTransfers() async {
    // Don't load if already loading, no more items, or not in success state
    if (state.isLoadingMore ||
        !state.hasMore ||
        state.status != Status.success) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final moreTransferItems = await _transferService.getTransferReviewItems(
        filter: state.filter,
        limit: state.limit,
        offset: state.offset,
      );

      // Merge new items with existing ones
      final updatedItemsById = {
        ...state.transferItemsById,
        ...moreTransferItems,
      };

      emit(
        state.copyWith(
          transferItemsById: updatedItemsById,
          offset: state.offset + moreTransferItems.length,
          hasMore: moreTransferItems.length >= state.limit,
          isLoadingMore: false,
        ),
      );
    } catch (e, stackTrace) {
      _log.e(
        'Failed to load more transfer items',
        error: e,
        stackTrace: stackTrace,
      );
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  /// Confirms a transfer (marks it as reviewed).
  Future<void> confirmTransfer(UuidValue transferId) async {
    try {
      final reviewItem = state.transferItemsById[transferId];
      if (reviewItem == null) return;

      // Only invalid transfers can be confirmed
      if (reviewItem case WithTransferItem(:final transferWithDetails)) {
        if (transferWithDetails.canConfirm) {
          await _transferRepository.updateTransfer(
            transferWithDetails.transfer,
            assocsChanged: false,
          );
        }
      }
    } catch (e, stackTrace) {
      _log.e('Failed to confirm transfer', error: e, stackTrace: stackTrace);
      emit(state.copyWith(status: Status.error));
    }
  }

  /// Deletes a transfer.
  Future<void> deleteTransfer(UuidValue transferId) async {
    try {
      final reviewItem = state.transferItemsById[transferId];
      if (reviewItem == null) return;

      // Only items with transfer entity can be deleted
      if (reviewItem case WithTransferItem(:final transferWithDetails)) {
        await _transferRepository.deleteTransfer(transferWithDetails.transfer);
      }
    } catch (e, stackTrace) {
      _log.e('Failed to delete transfer', error: e, stackTrace: stackTrace);
      emit(state.copyWith(status: Status.error));
    }
  }
}
