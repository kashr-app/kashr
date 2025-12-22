import 'dart:async';

import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/turnover/cubit/tag_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing Tag entities.
///
/// This cubit acts as a reactive cache that automatically updates
/// when tags change in the repository.
class TagCubit extends Cubit<TagState> {
  final TagRepository _repository;
  final Logger _log;
  StreamSubscription<List<Tag>?>? _subscription;

  TagCubit(this._repository, this._log) : super(const TagState()) {
    // Subscribe to tag changes from the repository
    _subscription = _repository.watchTags().listen(_onTagsChanged);
  }

  void _onTagsChanged(List<Tag>? tags) {
    if (tags != null) {
      emit(
        state.copyWith(
          tags: tags,
          tagById: tags.associateBy((t) => t.id),
          status: Status.success,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  /// Loads all tags from cache or the repository.
  Future<void> loadTags({bool invalidateCache = false}) async {
    emit(state.copyWith(status: Status.loading));
    try {
      await _repository.getAllTagsCached(invalidate: invalidateCache);
      // state is upated by watching the repository
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
      final tagWithId = tag.copyWith(id: tag.id);
      await _repository.createTag(tagWithId);
      // No need to call loadTags() - the stream will auto-update
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
      // No need to call loadTags() - the stream will auto-update
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
      // No need to call loadTags() - the stream will auto-update
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
      // No need to call loadTags() - the stream will auto-update
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
