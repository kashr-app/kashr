import 'package:decimal/decimal.dart';
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
  final TagSuggestionService _suggestionService;
  final _log = Logger();

  TurnoverTagsCubit(
    this._tagTurnoverRepository,
    this._tagRepository,
    this._turnoverRepository, {
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
          tagTurnovers: tagTurnoversWithTags,
          initialTagTurnovers: tagTurnoversWithTags,
          availableTags: allTags,
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

  /// Saves all tag turnovers to the database.
  Future<void> saveAll() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final t = state.turnover;
      if (t == null) return;

      // Delete all existing tag turnovers for this turnover
      await _tagTurnoverRepository.deleteAllForTurnover(t.id!);

      // Create all current tag turnovers
      for (final tt in state.tagTurnovers) {
        await _tagTurnoverRepository.createTagTurnover(tt.tagTurnover);
      }

      // Reset initial state to current state after successful save
      emit(state.copyWith(
        status: Status.success,
        initialTagTurnovers: state.tagTurnovers,
      ));
      _log.i('Successfully saved tag turnovers');
    } catch (e, s) {
      _log.e('Failed to save tag turnovers', error: e, stackTrace: s);
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
}
