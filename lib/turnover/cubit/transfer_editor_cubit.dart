import 'package:kashr/turnover/cubit/transfer_editor_state.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/services/transfer_service.dart'
    show TransferService, TransferLinkConflict;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing the state of the transfer editor page.
class TransferEditorCubit extends Cubit<TransferEditorState> {
  final TransferService _transferService;
  final TransferRepository _transferRepository;
  final TagTurnoverRepository _tagTurnoverRepository;
  final UuidValue? transferId;

  final Logger _log;

  TransferEditorCubit(
    this._log, {
    required TransferService transferService,
    required TransferRepository transferRepository,
    required TagTurnoverRepository tagTurnoverRepository,
    this.transferId,
  }) : _transferService = transferService,
       _transferRepository = transferRepository,
       _tagTurnoverRepository = tagTurnoverRepository,
       super(const TransferEditorState.initial()) {
    _loadTransfer();
  }

  Future<void> _loadTransfer() async {
    emit(const TransferEditorState.loading());

    try {
      // load from database
      final details = await _transferService.getTransferWithDetails(
        transferId!,
      );

      if (details == null) {
        emit(const TransferEditorState.error('Transfer not found'));
        return;
      }

      emit(TransferEditorState.loaded(details: details));
    } catch (e, s) {
      _log.e('Failed to load transfer', error: e, stackTrace: s);
      emit(TransferEditorState.error('Failed to load transfer: $e'));
    }
  }

  /// Reloads the transfer from the database.
  Future<void> reload() async {
    await _loadTransfer();
  }

  /// Confirmes the transfer.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> confirmTransfer() async {
    return state.maybeWhen(
      loaded: (details) async {
        try {
          final updated = details.transfer.copyWith(
            confirmedAt: DateTime.now(),
          );
          await _transferRepository.updateTransfer(
            updated,
            assocsChanged: false,
          );
          emit(
            TransferEditorState.loaded(
              details: details.copyWith(transfer: updated),
            ),
          );
          return true;
        } catch (e, s) {
          _log.e('Failed to confirm transfer', error: e, stackTrace: s);
          return false;
        }
      },
      orElse: () async => false,
    );
  }

  /// Deletes the transfer.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> delete() async {
    return state.maybeWhen(
      loaded: (details) async {
        try {
          await _transferRepository.deleteTransfer(details.transfer);
          return true;
        } catch (e, s) {
          _log.e('Failed to delete transfer', error: e, stackTrace: s);
          return false;
        }
      },
      orElse: () async => false,
    );
  }

  /// Unlinks a tag turnover from the transfer.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> unlinkTagTurnover({required bool isFromSide}) async {
    return state.maybeWhen(
      loaded: (details) async {
        // Update the transfer by setting the appropriate side to null
        final updatedTransfer = isFromSide
            ? details.transfer.copyWith(fromTagTurnoverId: null)
            : details.transfer.copyWith(toTagTurnoverId: null);

        try {
          await _transferRepository.updateTransfer(
            updatedTransfer,
            assocsChanged: true,
          );

          // Reload the transfer to reflect changes
          await _loadTransfer();

          return true;
        } catch (e, s) {
          _log.e(
            'Failed to unlink tag turnover from transfer',
            error: e,
            stackTrace: s,
          );
          emit(const TransferEditorState.error('Failed to unlink'));
          return false;
        }
      },
      orElse: () async => false,
    );
  }

  /// Updates a tag turnover.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> updateTagTurnover(TagTurnover tagTurnover) async {
    try {
      await _tagTurnoverRepository.updateTagTurnover(tagTurnover);

      // Reload the transfer to reflect changes
      await _loadTransfer();

      return true;
    } catch (e, s) {
      _log.e('Failed to update tag turnover', error: e, stackTrace: s);
      return false;
    }
  }

  /// Deletes a tag turnover.
  ///
  /// Returns true if successful, false otherwise.
  Future<bool> deleteTagTurnover(TagTurnover tagTurnover) async {
    try {
      await _tagTurnoverRepository.deleteTagTurnover(tagTurnover.id);

      // Reload the transfer to reflect changes
      await _loadTransfer();

      return true;
    } catch (e, s) {
      _log.e('Failed to delete tag turnover', error: e, stackTrace: s);
      return false;
    }
  }

  /// Links a tag turnover to the transfer.
  ///
  /// Returns a [TransferLinkConflict] if there's a conflict, or null on success.
  /// This method now uses TransferService.updateTransferWithTagTurnover.
  Future<TransferLinkConflict?> linkTagTurnover(TagTurnover toLink) async {
    return state.maybeWhen(
      loaded: (details) async {
        try {
          final (
            transferId,
            conflict,
          ) = await _transferService.linkTransferTagTurnovers(
            sourceTagTurnover: details.fromTagTurnover ?? details.toTagTurnover,
            selectedTagTurnover: toLink,
            transfer: details.transfer,
          );

          if (conflict != null) {
            // Conflict detected - return it to caller
            return conflict;
          }

          // Success - reload the transfer to reflect changes
          await _loadTransfer();
          return null;
        } catch (e, s) {
          _log.e(
            'Failed to link tag turnover to transfer',
            error: e,
            stackTrace: s,
          );
          emit(const TransferEditorState.error('Failed to update link'));
          return null;
        }
      },
      orElse: () async => null,
    );
  }
}
