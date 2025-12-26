import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/account/model/account_repository.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/extensions/map_extensios.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/cubit/turnover_tags_state.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_repository.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/transfer_repository.dart';
import 'package:kashr/turnover/model/transfer_with_details.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:kashr/turnover/services/tag_suggestion_service.dart';
import 'package:kashr/turnover/services/transfer_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing tags associated with a turnover.
class TurnoverTagsCubit extends Cubit<TurnoverTagsState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TurnoverRepository _turnoverRepository;
  final AccountRepository _accountRepository;
  final TransferRepository _transferRepository;
  final TagRepository _tagRepository;
  final TagSuggestionService _suggestionService;
  final Logger _log;

  TurnoverTagsCubit(
    this._tagTurnoverRepository,
    this._turnoverRepository,
    this._accountRepository,
    this._transferRepository,
    this._tagRepository,
    this._log, {
    TagSuggestionService? suggestionService,
  }) : _suggestionService = suggestionService ?? TagSuggestionService(),
       super(const TurnoverTagsState());

  /// Loads the turnover and its associated TagTurnovers.
  Future<void> loadTurnover(UuidValue turnoverId) async {
    emit(state.copyWith(status: Status.loading));
    try {
      final turnover = await _turnoverRepository.getTurnoverById(turnoverId);
      if (turnover == null) {
        emit(
          state.copyWith(
            status: Status.error,
            errorMessage: 'Turnover not found',
          ),
        );
        return;
      }

      final account = await _accountRepository.getAccountById(
        turnover.accountId,
      );
      final isManual = account?.syncSource == SyncSource.manual;

      final currentTagTurnoversById = await _tagTurnoverRepository
          .getByTurnover(turnoverId);

      emit(
        state.copyWith(
          status: Status.success,
          turnover: turnover,
          initialTurnover: turnover,
          currentTagTurnoversById: currentTagTurnoversById,
          initialTagTurnovers: currentTagTurnoversById.values.toList(),
          isManualAccount: isManual,
        ),
      );

      // Load transfers asynchronously (don't block the UI)
      loadTransfers();

      // Load suggestions asynchronously (don't block the UI)
      _loadSuggestions(turnover);
    } catch (e, s) {
      _log.e('Failed to load turnover', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load turnover: $e',
        ),
      );
    }
  }

  /// Loads tag suggestions for the turnover.
  ///
  /// Called after the turnover is loaded. Runs in the background to avoid
  /// blocking the UI. Only shows suggestions if there's unallocated money.
  Future<void> _loadSuggestions(Turnover turnover) async {
    try {
      // Only load suggestions if there's unallocated money
      final remainingAmount = turnover.amountValue - state.totalTagAmount;
      if (remainingAmount == Decimal.zero) {
        emit(state.copyWith(suggestions: []));
        return;
      }

      final suggestions = await _suggestionService.getSuggestionsForTurnover(
        turnover,
      );

      // Filter out tags that are already added to this turnover
      final filteredSuggestions = suggestions
          .where((s) => !state.currentTagTurnoversById.containsKey(s.tag.id))
          .toList();

      emit(state.copyWith(suggestions: filteredSuggestions));
    } catch (e, s) {
      _log.e('Failed to load suggestions', error: e, stackTrace: s);
      // Don't emit error state - suggestions are optional
      emit(state.copyWith(suggestions: []));
    }
  }

  /// Loads transfer information for the TagTurnovers.
  ///
  /// Called after the turnover is loaded. Runs in the background to avoid
  /// blocking the UI. Loads transfer details for any TagTurnovers with transfer semantics.
  Future<void> loadTransfers() async {
    try {
      final tagTurnovers = state.currentTagTurnoversById.values.toList();
      if (tagTurnovers.isEmpty) return;

      final tagTurnoverIds = tagTurnovers.map((item) => item.id).toList();

      // Get transfer IDs for these TagTurnovers
      final transferIdByTagTurnoverId = await _transferRepository
          .getTransferIdsForTagTurnovers(tagTurnoverIds);

      if (transferIdByTagTurnoverId.isEmpty) {
        emit(state.copyWith(transferByTagTurnoverId: {}));
        return;
      }

      // Fetch transfer details
      final transferService = TransferService(
        _log,
        transferRepository: _transferRepository,
        tagTurnoverRepository: _tagTurnoverRepository,
        tagRepository: _tagRepository,
      );
      final transferIds = transferIdByTagTurnoverId.values.toSet().toList();
      final transfersWithDetails = await transferService
          .getTransfersWithDetails(transferIds);

      // Map transfers back to TagTurnover IDs
      final transferByTagTurnoverId = <UuidValue, TransferWithDetails>{};
      for (final entry in transferIdByTagTurnoverId.entries) {
        final tagTurnoverId = entry.key;
        final transferId = entry.value;
        final transferDetails = transfersWithDetails[transferId];
        if (transferDetails != null) {
          transferByTagTurnoverId[tagTurnoverId] = transferDetails;
        }
      }

      emit(state.copyWith(transferByTagTurnoverId: transferByTagTurnoverId));
    } catch (e, s) {
      _log.e('Failed to load transfers', error: e, stackTrace: s);
      // Don't emit error state - transfers are optional
      emit(state.copyWith(transferByTagTurnoverId: {}));
    }
  }

  /// Adds a tag to the turnover with the remaining non-allocated amount.
  void addTag(Tag tag) {
    final t = state.turnover;
    if (t == null) return;

    // Calculate the remaining non-allocated amount
    final remainingAmount = t.amountValue - state.totalTagAmount;

    final newTagTurnover = TagTurnover(
      id: const Uuid().v4obj(),
      turnoverId: t.id,
      tagId: tag.id,
      amountValue: remainingAmount,
      amountUnit: t.amountUnit,
      counterPart: t.counterPart,
      note: null,
      createdAt: DateTime.now(),
      bookingDate: t.bookingDate ?? DateTime.now(),
      accountId: t.accountId,
    );

    // Remove this tag from suggestions
    final updatedSuggestions = state.suggestions
        .where((s) => s.tag.id != tag.id)
        .toList();

    emit(
      state.copyWith(
        currentTagTurnoversById: {
          ...state.currentTagTurnoversById,
          newTagTurnover.id: newTagTurnover,
        },
        suggestions: updatedSuggestions,
      ),
    );
  }

  /// Updates the TagTurnover locally (not saved to DB yet).
  void updateTagTurnover(TagTurnover tagTurnover) {
    // we copy first to keep order
    final copy = {...state.currentTagTurnoversById};
    copy[tagTurnover.id] = tagTurnover;

    emit(state.copyWith(currentTagTurnoversById: copy));
  }

  /// Updates the amount of a TagTurnover locally (not saved to DB yet).
  void updateTagTurnoverAmount(UuidValue tagTurnoverId, int amountScaled) {
    final newAmount = (Decimal.fromInt(amountScaled) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);

    // we copy first to keep order
    final copy = {...state.currentTagTurnoversById};
    copy[tagTurnoverId] = copy[tagTurnoverId]!.copyWith(amountValue: newAmount);

    emit(state.copyWith(currentTagTurnoversById: copy));
  }

  /// Updates the note of a TagTurnover locally (not saved to DB yet).
  void updateTagTurnoverNote(UuidValue tagTurnoverId, String? note) {
    // we copy first to keep order
    final copy = {...state.currentTagTurnoversById};
    copy[tagTurnoverId] = copy[tagTurnoverId]!.copyWith(note: note);

    emit(state.copyWith(currentTagTurnoversById: copy));
  }

  /// Deletes a TagTurnover in-memory (will removed from DB on save).
  void deleteTagTurnover(UuidValue tagTurnoverId) {
    final updatedTagTurnovers = state.currentTagTurnoversById.where(
      (id, _) => id != tagTurnoverId,
    );

    emit(state.copyWith(currentTagTurnoversById: updatedTagTurnovers));
  }

  /// Removes [tagTurnover] from the turnover, but does not delete it.
  /// After saving, it will become a pending TagTurnover.
  void unallocateTagTurnover(TagTurnover tagTurnover) {
    final updatedTagTurnovers = state.currentTagTurnoversById.where(
      (id, _) => id != tagTurnover.id,
    );

    final wasInitial = state.initialTagTurnovers.any(
      (it) => it.id == tagTurnover.id,
    );

    // If it was initial, track it for unallocating
    final updatedUnallocated = wasInitial
        ? [...state.unallocatedTagTurnovers, tagTurnover]
        : state.unallocatedTagTurnovers;

    emit(
      state.copyWith(
        currentTagTurnoversById: updatedTagTurnovers,
        unallocatedTagTurnovers: updatedUnallocated,
      ),
    );
  }

  /// Saves all changes to the database.
  /// This includes both the turnover and all TagTurnovers.
  Future<void> saveAll() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null) return;

      // Update the turnover itself
      await _turnoverRepository.updateTurnover(t);

      final currentIds = state.currentTagTurnoversById.keys.toSet();

      final initialTagTurnoversById = state.initialTagTurnovers.associateBy(
        (it) => it.id,
      );
      final initialIds = initialTagTurnoversById.keys.toSet();

      // Batch unallocate TagTurnovers that were marked for unallocating
      if (state.unallocatedTagTurnovers.isNotEmpty) {
        await _tagTurnoverRepository.unallocateManyFromTurnover(
          state.unallocatedTagTurnovers,
        );
      }

      // Delete TagTurnovers that were removed (in initial but not in current,
      // and not in unallocated - those are just unallocated, not deleted)
      final unallocatedIds = state.unallocatedTagTurnovers
          .map((it) => it.id)
          .toSet();
      final removedIds = initialIds
          .difference(currentIds)
          .difference(unallocatedIds);

      if (removedIds.isNotEmpty) {
        await _tagTurnoverRepository.deleteTagTurnoversBatch(
          removedIds.toList(),
        );
      }

      // Batch create and update TagTurnovers
      final toCreate = <TagTurnover>[];
      final toUpdate = <TagTurnover>[];

      final associatedPendingIds = state.allocatedPendingTagTurnovers
          .map((it) => it.id)
          .toSet();

      for (final tt in state.currentTagTurnoversById.values) {
        final id = tt.id;
        final wasInitial = initialIds.contains(id);
        final wasPending = associatedPendingIds.contains(id);

        if (wasInitial || wasPending) {
          // TagTurnover existed in database - update it
          toUpdate.add(tt);
        } else {
          // New TagTurnover - create it
          toCreate.add(tt);
        }
      }

      if (toCreate.isNotEmpty) {
        await _tagTurnoverRepository.createTagTurnoversBatch(toCreate);
      }

      if (toUpdate.isNotEmpty) {
        await _tagTurnoverRepository.updateTagTurnoversBatch(toUpdate);
      }

      // Reset initial state to current state after successful save
      // Clear allocatedPendingTagTurnovers and unallocatedTagTurnovers
      emit(
        state.copyWith(
          status: Status.success,
          initialTurnover: state.turnover,
          initialTagTurnovers: state.currentTagTurnoversById.values.toList(),
          allocatedPendingTagTurnovers: [],
          unallocatedTagTurnovers: [],
        ),
      );
      _log.i('Successfully saved turnover and TagTurnovers');
    } catch (e, s) {
      _log.e('Failed to save changes', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to save: $e',
        ),
      );
    }
  }

  /// Updates the turnover with new values.
  ///
  /// When the turnover's sign changes (e.g., from negative to positive),
  /// all TagTurnover signs are flipped to match.
  ///
  /// When the new amount would cause existing TagTurnovers to exceed it,
  /// the TagTurnovers are adjusted proportionally to fit within the new amount.
  /// This prevents invalid states where TagTurnovers exceed the turnover amount.
  ///
  /// The turnover is NOT persisted immediately - only the in-memory state is
  /// updated. Persistence happens when the user saves via [saveAll].
  /// Updates the turnover amount and adjusts associated TagTurnovers.
  ///
  /// If the sign changes and any TagTurnovers are linked to transfers,
  /// sets an error state requiring manual unlink first.
  Future<void> updateTurnover(Turnover updatedTurnover) async {
    try {
      emit(state.copyWith(status: Status.loading));

      final currentTurnover = state.turnover;
      if (currentTurnover == null) return;

      final oldAmount = currentTurnover.amountValue;
      final newAmount = updatedTurnover.amountValue;

      // Determine if sign has changed
      final oldIsNegative = oldAmount < Decimal.zero;
      final newIsNegative = newAmount < Decimal.zero;
      final signChanged = oldIsNegative != newIsNegative;

      // Check if any tagTurnovers are part of a Transfer before allowing sign change
      if (signChanged && state.currentTagTurnoversById.isNotEmpty) {
        final tagTurnoverIds = state.currentTagTurnoversById.keys.toList();
        final linkedTransfers = await _transferRepository
            .getTransferIdsForTagTurnovers(tagTurnoverIds);

        if (linkedTransfers.isNotEmpty) {
          emit(
            state.copyWith(
              status: Status.error,
              errorMessage:
                  'Cannot change sign: ${linkedTransfers.length} '
                  'TagTurnover(s) are linked to transfers. Please unlink them '
                  'from the transfers first.',
            ),
          );
          return;
        }
      }

      final newAbsAmount = newAmount.abs();
      final totalTagAmount = state.totalTagAmount.abs();

      var updatedTagTurnovers = state.currentTagTurnoversById.values;

      // If sign changed, flip all TagTurnover signs
      if (signChanged && state.currentTagTurnoversById.isNotEmpty) {
        updatedTagTurnovers = updatedTagTurnovers.map(
          (it) => it.copyWith(amountValue: -it.amountValue),
        );
        _log.i('Flipped TagTurnover signs to match turnover sign change');
      }

      // Scale down TagTurnovers if they would exceed the new amount
      if (totalTagAmount > newAbsAmount && updatedTagTurnovers.isNotEmpty) {
        updatedTagTurnovers = _scaleToFit(
          tagTurnovers: updatedTagTurnovers.toList(),
          targetAbsAmount: newAbsAmount,
          targetIsNegative: newIsNegative,
        );

        _log.i('Scaled TagTurnovers to fit new amount');
      }

      emit(
        state.copyWith(
          status: Status.success,
          turnover: updatedTurnover,
          currentTagTurnoversById: updatedTagTurnovers.associateBy(
            (it) => it.id,
          ),
        ),
      );
      _log.i('Successfully updated turnover');
    } catch (e, s) {
      _log.e('Failed to update turnover', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to update turnover: $e',
        ),
      );
    }
  }

  /// Allocate pending TagTurnovers with the current turnover.
  ///
  /// This method allocates the provided TagTurnovers to the current turnover,
  /// updates their account IDs, and scales them down if necessary to fit
  /// within the available amount.
  ///
  /// [pendingTagTurnovers] - The pending TagTurnovers to allocate
  void allocatePendingTagTurnovers(List<TagTurnover> pendingTagTurnovers) {
    try {
      final t = state.turnover;
      if (t == null) return;

      // Update account IDs and allocate to turnover
      var newAllocatedTagTurnovers = pendingTagTurnovers.map((tt) {
        return tt.copyWith(
          // ensure they match the account (which has been confirmed by the user before if different)
          accountId: t.accountId,
          turnoverId: t.id,
        );
      }).toList();

      // Check if scaling is needed using the state method
      final check = state.checkIfWouldExceed(newAllocatedTagTurnovers);
      if (check.wouldExceed) {
        final existingTotal = state.totalTagAmount.abs();
        final availableAmount = t.amountValue.abs() - existingTotal;
        final targetIsNegative = t.amountValue < Decimal.zero;

        newAllocatedTagTurnovers = _scaleToFit(
          tagTurnovers: newAllocatedTagTurnovers,
          targetAbsAmount: availableAmount,
          targetIsNegative: targetIsNegative,
        );

        _log.i('Scaled pending TagTurnovers to fit available amount');
      }

      // Combine with existing TagTurnovers
      final updatedTagTurnovers = {
        ...state.currentTagTurnoversById,
        ...newAllocatedTagTurnovers.associateBy((it) => it.id),
      };

      emit(
        state.copyWith(
          currentTagTurnoversById: updatedTagTurnovers,
          allocatedPendingTagTurnovers: newAllocatedTagTurnovers,
        ),
      );

      _log.i(
        'Allocated ${newAllocatedTagTurnovers.length} pending TagTurnovers',
      );
    } catch (e, s) {
      _log.e(
        'Failed to allocate pending TagTurnovers',
        error: e,
        stackTrace: s,
      );
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to allocate TagTurnovers: $e',
        ),
      );
    }
  }

  /// Deletes the turnover and handles associated TagTurnovers.
  /// If [makePending] is true, TagTurnovers will have their turnoverId set to null.
  /// If false, all TagTurnovers will be deleted.
  Future<void> deleteTurnover({required bool makePending}) async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null) return;

      if (makePending) {
        // Set turnoverId to null for all TagTurnovers
        final tagTurnovers = await _tagTurnoverRepository.getByTurnover(t.id);
        for (final tagTurnover in tagTurnovers.values) {
          await _tagTurnoverRepository.unallocateFromTurnover(tagTurnover.id);
        }
      } else {
        // Delete all TagTurnovers
        await _tagTurnoverRepository.deleteAllForTurnover(t.id);
      }

      // Delete the turnover
      await _turnoverRepository.deleteTurnover(t.id);

      _log.i('Successfully deleted turnover');
      emit(state.copyWith(status: Status.success));
    } catch (e, s) {
      _log.e('Failed to delete turnover', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to delete turnover: $e',
        ),
      );
    }
  }

  /// Scales a list of TagTurnovers proportionally to fit within a target amount.
  ///
  /// Returns a new list of scaled TagTurnovers. The original list is not modified.
  /// Each TagTurnover's amount is scaled by the same factor to ensure the total
  /// does not exceed [targetAbsAmount].
  ///
  /// [tagTurnovers] - The list of TagTurnovers to scale
  /// [targetAbsAmount] - The target absolute amount that the sum should not exceed
  /// [targetIsNegative] - Whether the target amount is negative (affects sign)
  List<TagTurnover> _scaleToFit({
    required List<TagTurnover> tagTurnovers,
    required Decimal targetAbsAmount,
    required bool targetIsNegative,
  }) {
    if (tagTurnovers.isEmpty) return [];

    // Calculate total absolute amount of all TagTurnovers
    final totalTagAmount = tagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.amountValue.abs(),
    );

    // If total is already within target, no scaling needed
    if (totalTagAmount <= targetAbsAmount) {
      return tagTurnovers;
    }

    // Calculate scale factor to fit TagTurnovers within target amount
    final scaleFactor = (targetAbsAmount / totalTagAmount).toDecimal(
      scaleOnInfinitePrecision: 10,
    );

    // Scale each TagTurnover
    return tagTurnovers.map((tt) {
      // Scale the absolute value
      final scaledAbsAmount = (tt.amountValue.abs() * scaleFactor).floor(
        scale: 2,
      );
      // Apply the correct sign based on the target
      final signedAmount = targetIsNegative
          ? -scaledAbsAmount
          : scaledAbsAmount;
      return tt.copyWith(amountValue: signedAmount);
    }).toList();
  }
}
