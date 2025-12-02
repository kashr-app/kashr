import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/cubit/tag_cubit.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/services/tag_suggestion_service.dart';
import 'package:finanalyzer/turnover/services/tag_turnover_scaling_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing tags associated with a turnover.
class TurnoverTagsCubit extends Cubit<TurnoverTagsState> {
  final TagTurnoverRepository _tagTurnoverRepository;
  final TagCubit _tagCubit;
  final TurnoverRepository _turnoverRepository;
  final AccountRepository _accountRepository;
  final TagSuggestionService _suggestionService;
  final _log = Logger();

  TurnoverTagsCubit(
    this._tagTurnoverRepository,
    this._tagCubit,
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
      await _tagCubit.loadTags();
      final allTags = _tagCubit.state.tags;
      final tagMap = {for (final tag in allTags) tag.id!: tag};

      final tagTurnoversWithTags = tagTurnovers.map((tt) {
        final tag = tagMap[tt.tagId];
        return TagTurnoverWithTag(
          tagTurnover: tt,
          tag: tag ?? Tag(name: 'Unknown', id: tt.tagId),
        );
      }).toList();

      emit(
        state.copyWith(
          status: Status.success,
          turnover: turnover,
          initialTurnover: turnover,
          tagTurnovers: tagTurnoversWithTags,
          initialTagTurnovers: tagTurnoversWithTags,
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
      final existingTagIds = state.tagTurnovers.map((tt) => tt.tag.id).toSet();
      final filteredSuggestions = suggestions
          .where((s) => !existingTagIds.contains(s.tag.id))
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
      tagId: tag.id!,
      amountValue: remainingAmount,
      amountUnit: t.amountUnit,
      note: null,
      createdAt: DateTime.now(),
      bookingDate: t.bookingDate ?? DateTime.now(),
      accountId: t.accountId,
    );

    final updatedTagTurnovers = [
      ...state.tagTurnovers,
      TagTurnoverWithTag(tagTurnover: newTagTurnover, tag: tag),
    ];

    // Remove this tag from suggestions
    final updatedSuggestions = state.suggestions
        .where((s) => s.tag.id != tag.id)
        .toList();

    emit(
      state.copyWith(
        tagTurnovers: updatedTagTurnovers,
        suggestions: updatedSuggestions,
      ),
    );
  }

  /// Updates the amount of a tag turnover locally (not saved to DB yet).
  void updateTagTurnoverAmount(UuidValue tagTurnoverId, int amountScaled) {
    final updatedTagTurnovers = state.tagTurnovers.map((tt) {
      if (tt.tagTurnover.id == tagTurnoverId) {
        final newAmount = (Decimal.fromInt(amountScaled) / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 2);
        return tt.copyWith(
          tagTurnover: tt.tagTurnover.copyWith(amountValue: newAmount),
        );
      }
      return tt;
    }).toList();

    emit(state.copyWith(tagTurnovers: updatedTagTurnovers));
  }

  /// Updates the note of a tag turnover locally (not saved to DB yet).
  void updateTagTurnoverNote(UuidValue tagTurnoverId, String? note) {
    final updatedTagTurnovers = state.tagTurnovers.map((tt) {
      if (tt.tagTurnover.id == tagTurnoverId) {
        return tt.copyWith(tagTurnover: tt.tagTurnover.copyWith(note: note));
      }
      return tt;
    }).toList();

    emit(state.copyWith(tagTurnovers: updatedTagTurnovers));
  }

  /// Removes a tag turnover locally (not saved to DB yet).
  void removeTagTurnover(UuidValue tagTurnoverId) {
    final updatedTagTurnovers = state.tagTurnovers
        .where((tt) => tt.tagTurnover.id != tagTurnoverId)
        .toList();

    emit(state.copyWith(tagTurnovers: updatedTagTurnovers));
  }

  /// Unlinks a tag turnover from the current turnover.
  /// The tag turnover is removed from the list and marked for unlinking.
  /// After saving, it will become a pending tag turnover.
  void unlinkTagTurnover(UuidValue tagTurnoverId) {
    final updatedTagTurnovers = state.tagTurnovers
        .where((tt) => tt.tagTurnover.id != tagTurnoverId)
        .toList();

    // Check if this tag turnover was in the initial state (already persisted)
    final wasInitial = state.initialTagTurnovers.any(
      (tt) => tt.tagTurnover.id == tagTurnoverId,
    );

    // If it was initial, track it for unlinking
    final updatedUnlinkedIds = wasInitial
        ? {...state.unlinkedTagTurnoverIds, tagTurnoverId.uuid}
        : state.unlinkedTagTurnoverIds;

    emit(
      state.copyWith(
        tagTurnovers: updatedTagTurnovers,
        unlinkedTagTurnoverIds: updatedUnlinkedIds,
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

      // Get IDs of current and initial tag turnovers
      final currentIds = state.tagTurnovers
          .map((tt) => tt.tagTurnover.id)
          .whereType<UuidValue>()
          .toSet();

      final initialIds = state.initialTagTurnovers
          .map((tt) => tt.tagTurnover.id)
          .whereType<UuidValue>()
          .toSet();

      // Unlink tag turnovers that were marked for unlinking
      for (final idString in state.unlinkedTagTurnoverIds) {
        final id = UuidValue.fromString(idString);
        await _tagTurnoverRepository.unlinkFromTurnover(id);
      }

      // Delete tag turnovers that were removed (in initial but not in current,
      // and not in unlinked - those are just unlinked, not deleted)
      final unlinkedUuidValues = state.unlinkedTagTurnoverIds
          .map((id) => UuidValue.fromString(id))
          .toSet();
      final removedIds = initialIds
          .difference(currentIds)
          .difference(unlinkedUuidValues);
      for (final id in removedIds) {
        await _tagTurnoverRepository.deleteTagTurnover(id);
      }

      // Update or create current tag turnovers
      for (final tt in state.tagTurnovers) {
        final id = tt.tagTurnover.id;
        final idString = id.uuid;
        final wasInitial = initialIds.contains(id);
        final wasPending = state.associatedPendingIds.contains(idString);

        if (wasInitial || wasPending) {
          // Tag turnover existed in database - update it
          await _tagTurnoverRepository.updateTagTurnover(tt.tagTurnover);
        } else {
          // Brand new tag turnover - create it
          await _tagTurnoverRepository.createTagTurnover(tt.tagTurnover);
        }
      }

      // Reset initial state to current state after successful save
      // Clear associatedPendingIds and unlinkedTagTurnoverIds
      emit(
        state.copyWith(
          status: Status.success,
          initialTurnover: state.turnover,
          initialTagTurnovers: state.tagTurnovers,
          associatedPendingIds: {},
          unlinkedTagTurnoverIds: {},
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

    List<TagTurnoverWithTag> updatedTagTurnovers = state.tagTurnovers;

    // If sign changed, flip all tag turnover signs
    if (signChanged && state.tagTurnovers.isNotEmpty) {
      updatedTagTurnovers = updatedTagTurnovers.map((tt) {
        final flippedAmount = -tt.tagTurnover.amountValue;
        return tt.copyWith(
          tagTurnover: tt.tagTurnover.copyWith(amountValue: flippedAmount),
        );
      }).toList();

      _log.i('Flipped tag turnover signs to match turnover sign change');
    }

    // Scale down tag turnovers if they would exceed the new amount
    if (totalTagAmount > newAbsAmount && updatedTagTurnovers.isNotEmpty) {
      updatedTagTurnovers = TagTurnoverScalingService.scaleWithTagsToFit(
        tagTurnovers: updatedTagTurnovers,
        targetAbsAmount: newAbsAmount,
        targetIsNegative: newIsNegative,
      );

      _log.i('Scaled tag turnovers to fit new amount');
    }

    emit(
      state.copyWith(
        turnover: updatedTurnover,
        tagTurnovers: updatedTagTurnovers,
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
      final updatedPendingTagTurnovers = pendingTagTurnovers.map((tt) {
        return tt.copyWith(
          // ensure they match the account (which has been confirmed by the user before if different)
          accountId: t.accountId,
          turnoverId: t.id,
        );
      }).toList();

      // Get all tags for the updated tag turnovers
      final allTags = _tagCubit.state.tags;
      final tagMap = {for (final tag in allTags) tag.id!: tag};

      // Convert to TagTurnoverWithTag
      var newTagTurnoversWithTags = updatedPendingTagTurnovers.map((tt) {
        final tag = tagMap[tt.tagId];
        return TagTurnoverWithTag(
          tagTurnover: tt,
          tag: tag ?? Tag(name: 'Unknown', id: tt.tagId),
        );
      }).toList();

      // Check if scaling is needed using the state method
      final check = state.checkIfWouldExceed(updatedPendingTagTurnovers);
      if (check.wouldExceed) {
        final existingTotal = state.totalTagAmount.abs();
        final availableAmount = t.amountValue.abs() - existingTotal;
        final targetIsNegative = t.amountValue < Decimal.zero;

        newTagTurnoversWithTags = TagTurnoverScalingService.scaleWithTagsToFit(
          tagTurnovers: newTagTurnoversWithTags,
          targetAbsAmount: availableAmount,
          targetIsNegative: targetIsNegative,
        );

        _log.i('Scaled pending tag turnovers to fit available amount');
      }

      // Combine with existing tag turnovers
      final updatedTagTurnovers = [
        ...state.tagTurnovers,
        ...newTagTurnoversWithTags,
      ];

      // Track the IDs of pending tag turnovers we're associating
      final pendingIds = updatedPendingTagTurnovers
          .map((tt) => tt.id.uuid)
          .whereType<String>()
          .toSet();

      final updatedAssociatedPendingIds = {
        ...state.associatedPendingIds,
        ...pendingIds,
      };

      emit(
        state.copyWith(
          tagTurnovers: updatedTagTurnovers,
          associatedPendingIds: updatedAssociatedPendingIds,
        ),
      );

      _log.i('Associated ${pendingTagTurnovers.length} pending tag turnovers');
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
}
