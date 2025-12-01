import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:logger/logger.dart';

/// Cubit for managing Tag entities.
class TagCubit extends Cubit<TagState> {
  final TagRepository _repository;
  final _log = Logger();

  TagCubit(this._repository) : super(const TagState());

  /// Loads all tags from the repository.
  Future<void> loadTags() async {
    emit(state.copyWith(status: Status.loading));
    try {
      final tags = await _repository.getAllTags();
      emit(state.copyWith(status: Status.success, tags: tags));
    } catch (e, s) {
      _log.e('Failed to load tags', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load tags: $e',
        ),
      );
    }
  }

  /// Creates a new tag.
  Future<void> createTag(Tag tag) async {
    try {
      final tagWithId = tag.copyWith(id: tag.id ?? const Uuid().v4obj());
      await _repository.createTag(tagWithId);
      await loadTags();
    } catch (e, s) {
      _log.e('Failed to create tag', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to create tag: $e',
        ),
      );
    }
  }

  /// Updates an existing tag.
  Future<void> updateTag(Tag tag) async {
    try {
      await _repository.updateTag(tag);
      await loadTags();
    } catch (e, s) {
      _log.e('Failed to update tag', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to update tag: $e',
        ),
      );
    }
  }

  /// Deletes a tag.
  Future<void> deleteTag(UuidValue id) async {
    try {
      await _repository.deleteTag(id);
      await loadTags();
    } catch (e, s) {
      _log.e('Failed to delete tag', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to delete tag: $e',
        ),
      );
    }
  }

  /// Merges two tags by moving all tag_turnover references from source to
  /// target.
  ///
  /// Parameters:
  /// - [sourceTagId]: The tag to merge from (will be deleted)
  /// - [targetTagId]: The tag to merge into (will remain)
  Future<void> mergeTags(UuidValue sourceTagId, UuidValue targetTagId) async {
    emit(state.copyWith(status: Status.loading));
    try {
      await _repository.mergeTags(sourceTagId, targetTagId);
      await loadTags();
      _log.i('Successfully merged tags');
    } catch (e, s) {
      _log.e('Failed to merge tags', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to merge tags: $e',
        ),
      );
    }
  }
}
