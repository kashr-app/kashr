import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/account/model/account_repository.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/cubit/turnover_tags_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
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
  final TagRepository _tagRepository;
  final TurnoverRepository _turnoverRepository;
  final AccountRepository _accountRepository;
  final TagSuggestionService _suggestionService;
  final _log = Logger();

  TurnoverTagsCubit(
    this._tagTurnoverRepository,
    this._tagRepository,
    this._turnoverRepository,
    this._accountRepository, {
    TagSuggestionService? suggestionService,
  })  : _suggestionService =
            suggestionService ?? TagSuggestionService(),
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
      final allTags = await _tagRepository.getAllTags();
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
          availableTags: allTags,
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
      final existingTagIds =
          state.tagTurnovers.map((tt) => tt.tag.id).toSet();
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

    emit(state.copyWith(
      tagTurnovers: updatedTagTurnovers,
      suggestions: updatedSuggestions,
    ));
  }

  /// Updates the amount of a tag turnover locally (not saved to DB yet).
  void updateTagTurnoverAmount(UuidValue tagTurnoverId, int amountScaled) {
    final updatedTagTurnovers = state.tagTurnovers.map((tt) {
      if (tt.tagTurnover.id == tagTurnoverId) {
        final newAmount = (Decimal.fromInt(amountScaled) /
                Decimal.fromInt(100))
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
        return tt.copyWith(
          tagTurnover: tt.tagTurnover.copyWith(note: note),
        );
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

  /// Saves all changes to the database.
  /// This includes both the turnover and all tag turnovers.
  Future<void> saveAll() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null || t.id == null) return;

      // Update the turnover itself
      await _turnoverRepository.updateTurnover(t);

      // Delete all existing tag turnovers for this turnover
      await _tagTurnoverRepository.deleteAllForTurnover(t.id!);

      // Create all current tag turnovers
      for (final tt in state.tagTurnovers) {
        await _tagTurnoverRepository.createTagTurnover(tt.tagTurnover);
      }

      // Reset initial state to current state after successful save
      emit(state.copyWith(
        status: Status.success,
        initialTurnover: state.turnover,
        initialTagTurnovers: state.tagTurnovers,
      ));
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

  /// Searches for available tags by name.
  List<Tag> searchTags(String query) {
    if (query.isEmpty) {
      return state.availableTags;
    }
    final lowerQuery = query.toLowerCase();
    return state.availableTags
        .where((tag) => tag.name.toLowerCase().contains(lowerQuery))
        .toList();
  }

  /// Creates a new tag and adds it to the available tags.
  Future<Tag?> createAndAddTag(String name, String? color) async {
    try {
      final newTag = Tag(
        id: const Uuid().v4obj(),
        name: name,
        color: color,
      );

      await _tagRepository.createTag(newTag);

      final updatedAvailableTags = [...state.availableTags, newTag];
      emit(state.copyWith(availableTags: updatedAvailableTags));

      _log.i('Created new tag: $name');
      return newTag;
    } catch (e, s) {
      _log.e('Failed to create tag', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to create tag: $e',
        ),
      );
      return null;
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
      // Calculate scale factor to fit tag turnovers within new amount
      final scaleFactor = (newAbsAmount / totalTagAmount).toDecimal(
        scaleOnInfinitePrecision: 10,
      );

      updatedTagTurnovers = updatedTagTurnovers.map((tt) {
        // Scale the absolute value
        final scaledAbsAmount = (tt.tagTurnover.amountValue.abs() * scaleFactor)
            .floor(scale: 2);
        // Apply the correct sign based on the new turnover
        final signedAmount = newIsNegative ? -scaledAbsAmount : scaledAbsAmount;
        return tt.copyWith(
          tagTurnover: tt.tagTurnover.copyWith(amountValue: signedAmount),
        );
      }).toList();

      _log.i(
        'Scaled tag turnovers by factor $scaleFactor to fit new amount',
      );
    }

    emit(state.copyWith(
      turnover: updatedTurnover,
      tagTurnovers: updatedTagTurnovers,
    ));
  }

  /// Deletes the turnover and handles associated tag turnovers.
  /// If [makePending] is true, tag turnovers will have their turnoverId set to null.
  /// If false, all tag turnovers will be deleted.
  Future<void> deleteTurnover({required bool makePending}) async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null || t.id == null) return;

      if (makePending) {
        // Set turnoverId to null for all tag turnovers
        final tagTurnovers = await _tagTurnoverRepository.getByTurnover(t.id!);
        for (final tagTurnover in tagTurnovers) {
          if (tagTurnover.id != null) {
            await _tagTurnoverRepository.unlinkFromTurnover(tagTurnover.id!);
          }
        }
      } else {
        // Delete all tag turnovers
        await _tagTurnoverRepository.deleteAllForTurnover(t.id!);
      }

      // Delete the turnover
      await _turnoverRepository.deleteTurnover(t.id!);

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
