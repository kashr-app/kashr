import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/core/extensions/map_extensios.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/tag_suggestion_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing tags associated with a turnover.
class TurnoverTagsCubit extends Cubit<TurnoverTagsState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TurnoverRepository _turnoverRepository;
  final AccountRepository _accountRepository;
  final TagSuggestionService _suggestionService;
  final _log = Logger();

  TurnoverTagsCubit(
    this._tagTurnoverRepository,
    this._turnoverRepository,
    this._accountRepository, {
    TagSuggestionService? suggestionService,
  }) : _suggestionService = suggestionService ?? TagSuggestionService(),
       super(const TurnoverTagsState());

  /// Loads the turnover and its associated tag turnovers.
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

      final tagTurnovers = await _tagTurnoverRepository.getByTurnover(
        turnoverId,
      );

      final currentTagTurnoversById = tagTurnovers.associateBy((it) => it.id);

      emit(
        state.copyWith(
          status: Status.success,
          turnover: turnover,
          initialTurnover: turnover,
          currentTagTurnoversById: currentTagTurnoversById,
          initialTagTurnovers: tagTurnovers,
          isManualAccount: isManual,
        ),
      );

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

  /// Updates the amount of a tag turnover locally (not saved to DB yet).
  void updateTagTurnoverAmount(UuidValue tagTurnoverId, int amountScaled) {
    final newAmount = (Decimal.fromInt(amountScaled) / Decimal.fromInt(100))
        .toDecimal(scaleOnInfinitePrecision: 2);

    // we copy first to keep order
    final copy = {...state.currentTagTurnoversById};
    copy[tagTurnoverId] = copy[tagTurnoverId]!.copyWith(amountValue: newAmount);

    emit(state.copyWith(currentTagTurnoversById: copy));
  }

  /// Updates the note of a tag turnover locally (not saved to DB yet).
  void updateTagTurnoverNote(UuidValue tagTurnoverId, String? note) {
    // we copy first to keep order
    final copy = {...state.currentTagTurnoversById};
    copy[tagTurnoverId] = copy[tagTurnoverId]!.copyWith(note: note);

    emit(state.copyWith(currentTagTurnoversById: copy));
  }

  /// Removes a tag turnover locally (not saved to DB yet).
  void removeTagTurnover(UuidValue tagTurnoverId) {
    final updatedTagTurnovers = state.currentTagTurnoversById.where(
      (id, _) => id != tagTurnoverId,
    );

    emit(state.copyWith(currentTagTurnoversById: updatedTagTurnovers));
  }

  /// Unlinks a tag turnover from the current turnover.
  /// The tag turnover is removed from the current ones and marked for unlinking.
  /// After saving, it will become a pending tag turnover.
  void unlinkTagTurnover(TagTurnover tagTurnover) {
    final updatedTagTurnovers = state.currentTagTurnoversById.where(
      (id, _) => id != tagTurnover.id,
    );

    final wasInitial = state.initialTagTurnovers.any(
      (it) => it.id == tagTurnover.id,
    );

    // If it was initial, track it for unlinking
    final updatedUnlinked = wasInitial
        ? [...state.unlinkedTagTurnovers, tagTurnover]
        : state.unlinkedTagTurnovers;

    emit(
      state.copyWith(
        currentTagTurnoversById: updatedTagTurnovers,
        unlinkedTagTurnovers: updatedUnlinked,
      ),
    );
  }

  /// Saves all changes to the database.
  /// This includes both the turnover and all tag turnovers.
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

      // Batch unlink tag turnovers that were marked for unlinking
      if (state.unlinkedTagTurnovers.isNotEmpty) {
        await _tagTurnoverRepository.unlinkManyFromTurnover(
          state.unlinkedTagTurnovers,
        );
      }

      // Delete tag turnovers that were removed (in initial but not in current,
      // and not in unlinked - those are just unlinked, not deleted)
      final unlinkedIds = state.unlinkedTagTurnovers.map((it) => it.id).toSet();
      final removedIds = initialIds
          .difference(currentIds)
          .difference(unlinkedIds);

      if (removedIds.isNotEmpty) {
        await _tagTurnoverRepository.deleteTagTurnoversBatch(
          removedIds.toList(),
        );
      }

      // Batch create and update tag turnovers
      final toCreate = <TagTurnover>[];
      final toUpdate = <TagTurnover>[];

      final associatedPendingIds = state.associatedPendingTagTurnovers
          .map((it) => it.id)
          .toSet();

      for (final tt in state.currentTagTurnoversById.values) {
        final id = tt.id;
        final wasInitial = initialIds.contains(id);
        final wasPending = associatedPendingIds.contains(id);

        if (wasInitial || wasPending) {
          // Tag turnover existed in database - update it
          toUpdate.add(tt);
        } else {
          // New tag turnover - create it
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
      // Clear associatedPendingIds and unlinkedTagTurnoverIds
      emit(
        state.copyWith(
          status: Status.success,
          initialTurnover: state.turnover,
          initialTagTurnovers: state.currentTagTurnoversById.values.toList(),
          associatedPendingTagTurnovers: [],
          unlinkedTagTurnovers: [],
        ),
      );
      _log.i('Successfully saved turnover and tag turnovers');
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
  /// all tag turnover signs are flipped to match.
  ///
  /// When the new amount would cause existing tag turnovers to exceed it,
  /// the tag turnovers are adjusted proportionally to fit within the new amount.
  /// This prevents invalid states where tag turnovers exceed the turnover amount.
  ///
  /// The turnover is NOT persisted immediately - only the in-memory state is
  /// updated. Persistence happens when the user saves via [saveAll].
  void updateTurnover(Turnover updatedTurnover) {
    final currentTurnover = state.turnover;
    if (currentTurnover == null) return;

    final oldAmount = currentTurnover.amountValue;
    final newAmount = updatedTurnover.amountValue;

    // Determine if sign has changed
    final oldIsNegative = oldAmount < Decimal.zero;
    final newIsNegative = newAmount < Decimal.zero;
    final signChanged = oldIsNegative != newIsNegative;

    final newAbsAmount = newAmount.abs();
    final totalTagAmount = state.totalTagAmount.abs();

    var updatedTagTurnovers = state.currentTagTurnoversById.values;

    // If sign changed, flip all tag turnover signs
    if (signChanged && state.currentTagTurnoversById.isNotEmpty) {
      updatedTagTurnovers = updatedTagTurnovers.map(
        (it) => it.copyWith(amountValue: -it.amountValue),
      );
      _log.i('Flipped tag turnover signs to match turnover sign change');
    }

    // Scale down tag turnovers if they would exceed the new amount
    if (totalTagAmount > newAbsAmount && updatedTagTurnovers.isNotEmpty) {
      updatedTagTurnovers = _scaleToFit(
        tagTurnovers: updatedTagTurnovers.toList(),
        targetAbsAmount: newAbsAmount,
        targetIsNegative: newIsNegative,
      );

      _log.i('Scaled tag turnovers to fit new amount');
    }

    emit(
      state.copyWith(
        turnover: updatedTurnover,
        currentTagTurnoversById: updatedTagTurnovers.associateBy((it) => it.id),
      ),
    );
  }

  /// Associates pending tag turnovers with the current turnover.
  ///
  /// This method links the provided tag turnovers to the current turnover,
  /// updates their account IDs, and scales them down if necessary to fit
  /// within the available amount.
  ///
  /// [pendingTagTurnovers] - The pending tag turnovers to associate
  void associatePendingTagTurnovers(List<TagTurnover> pendingTagTurnovers) {
    try {
      final t = state.turnover;
      if (t == null) return;

      // Update account IDs and link to turnover
      var newAssociatedTagTurnovers = pendingTagTurnovers.map((tt) {
        return tt.copyWith(
          // ensure they match the account (which has been confirmed by the user before if different)
          accountId: t.accountId,
          turnoverId: t.id,
        );
      }).toList();

      // Check if scaling is needed using the state method
      final check = state.checkIfWouldExceed(newAssociatedTagTurnovers);
      if (check.wouldExceed) {
        final existingTotal = state.totalTagAmount.abs();
        final availableAmount = t.amountValue.abs() - existingTotal;
        final targetIsNegative = t.amountValue < Decimal.zero;

        newAssociatedTagTurnovers = _scaleToFit(
          tagTurnovers: newAssociatedTagTurnovers,
          targetAbsAmount: availableAmount,
          targetIsNegative: targetIsNegative,
        );

        _log.i('Scaled pending tag turnovers to fit available amount');
      }

      // Combine with existing tag turnovers
      final updatedTagTurnovers = {
        ...state.currentTagTurnoversById,
        ...newAssociatedTagTurnovers.associateBy((it) => it.id),
      };

      emit(
        state.copyWith(
          currentTagTurnoversById: updatedTagTurnovers,
          associatedPendingTagTurnovers: newAssociatedTagTurnovers,
        ),
      );

      _log.i(
        'Associated ${newAssociatedTagTurnovers.length} pending tag turnovers',
      );
    } catch (e, s) {
      _log.e(
        'Failed to associate pending tag turnovers',
        error: e,
        stackTrace: s,
      );
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to associate tag turnovers: $e',
        ),
      );
    }
  }

  /// Deletes the turnover and handles associated tag turnovers.
  /// If [makePending] is true, tag turnovers will have their turnoverId set to null.
  /// If false, all tag turnovers will be deleted.
  Future<void> deleteTurnover({required bool makePending}) async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null) return;

      if (makePending) {
        // Set turnoverId to null for all tag turnovers
        final tagTurnovers = await _tagTurnoverRepository.getByTurnover(t.id);
        for (final tagTurnover in tagTurnovers) {
          await _tagTurnoverRepository.unlinkFromTurnover(tagTurnover.id);
        }
      } else {
        // Delete all tag turnovers
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

  /// Scales a list of tag turnovers proportionally to fit within a target amount.
  ///
  /// Returns a new list of scaled tag turnovers. The original list is not modified.
  /// Each tag turnover's amount is scaled by the same factor to ensure the total
  /// does not exceed [targetAbsAmount].
  ///
  /// [tagTurnovers] - The list of tag turnovers to scale
  /// [targetAbsAmount] - The target absolute amount that the sum should not exceed
  /// [targetIsNegative] - Whether the target amount is negative (affects sign)
  List<TagTurnover> _scaleToFit({
    required List<TagTurnover> tagTurnovers,
    required Decimal targetAbsAmount,
    required bool targetIsNegative,
  }) {
    if (tagTurnovers.isEmpty) return [];

    // Calculate total absolute amount of all tag turnovers
    final totalTagAmount = tagTurnovers.fold<Decimal>(
      Decimal.zero,
      (sum, tt) => sum + tt.amountValue.abs(),
    );

    // If total is already within target, no scaling needed
    if (totalTagAmount <= targetAbsAmount) {
      return tagTurnovers;
    }

    // Calculate scale factor to fit tag turnovers within target amount
    final scaleFactor = (targetAbsAmount / totalTagAmount).toDecimal(
      scaleOnInfinitePrecision: 10,
    );

    // Scale each tag turnover
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
