import 'dart:async';

import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TagRepository {
  final _log = Logger();

  final _tagsController = StreamController<List<Tag>>.broadcast();
  List<Tag>? _cachedTags;

  /// Initial value is null in case tags have not yet been loaded from the DB.
  Stream<List<Tag>?> watchTags() async* {
    // Emit cached value immediately for new listeners
    yield _cachedTags;
    // Then emit all future updates
    yield* _tagsController.stream;
  }

  void _emitTags(List<Tag> tags) {
    _cachedTags = tags;
    _tagsController.add(tags);
  }

  Future<List<Tag>> _reloadAndEmitTags() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('tag', orderBy: 'name ASC');
    final tags = maps.map((e) => Tag.fromJson(e)).toList();
    _emitTags(tags);
    return tags;
  }

  void dispose() {
    _tagsController.close();
  }

  Future<int> createTag(Tag tag) async {
    final db = await DatabaseHelper().database;
    final result = await db.insert('tag', tag.toJson());
    await _reloadAndEmitTags();
    return result;
  }

  /// Loads the tags from the cache unless the cache was not initialized
  /// or [invalidate] is true (defaults to false).
  Future<List<Tag>> getAllTagsCached({bool invalidate = false}) async {
    if (!invalidate && _cachedTags != null) return _cachedTags!;
    return await _reloadAndEmitTags();
  }

  /// Returns all tags indexed by their ID from the cache.
  /// If [invalidate] is true, reloads from database first.
  Future<Map<UuidValue, Tag>> getByIdsCached({bool invalidate = false}) async {
    final tags = await getAllTagsCached(invalidate: invalidate);
    return tags.associateBy((it) => it.id);
  }

  Future<int> updateTag(Tag tag) async {
    final db = await DatabaseHelper().database;
    final result = await db.update(
      'tag',
      tag.toJson(),
      where: 'id = ?',
      whereArgs: [tag.id.uuid],
    );
    await _reloadAndEmitTags();
    return result;
  }

  Future<int> deleteTag(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final result = await db.delete(
      'tag',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
    await _reloadAndEmitTags();
    return result;
  }

  /// Merges two tags by moving all tag_turnover references from source to target
  /// and handling savings based on the resolution strategy.
  ///
  /// This operation is atomic - either all changes succeed or none do.
  ///
  /// Parameters:
  /// - [sourceTagId]: The tag to merge from (will be deleted)
  /// - [targetTagId]: The tag to merge into (will remain)
  Future<void> mergeTags(UuidValue sourceTagId, UuidValue targetTagId) async {
    final db = await DatabaseHelper().database;

    try {
      await db.transaction((txn) async {
        // Step 1: Update all tag_turnover references from source to target
        final turnoverCount = await txn.update(
          'tag_turnover',
          {'tag_id': targetTagId.uuid},
          where: 'tag_id = ?',
          whereArgs: [sourceTagId.uuid],
        );

        _log.i(
          'Merged $turnoverCount tag_turnover entries from ${sourceTagId.uuid} to ${targetTagId.uuid}',
        );

        // Step 2: Handle savings
        {
          // Get source and target savings IDs
          final sourceSavingsRows = await txn.query(
            'savings',
            columns: ['id'],
            where: 'tag_id = ?',
            whereArgs: [sourceTagId.uuid],
          );
          final targetSavingsRows = await txn.query(
            'savings',
            columns: ['id'],
            where: 'tag_id = ?',
            whereArgs: [targetTagId.uuid],
          );

          final sourceSavingsId = sourceSavingsRows.isNotEmpty
              ? sourceSavingsRows.first['id'] as String
              : null;
          final targetSavingsId = targetSavingsRows.isNotEmpty
              ? targetSavingsRows.first['id'] as String
              : null;

          if (sourceSavingsId != null && targetSavingsId != null) {
            // both source and target have savings => transfer source's virtual bookings to target savings and remove source savings
            final transferredCount = await txn.update(
              'savings_virtual_booking',
              {'savings_id': targetSavingsId},
              where: 'savings_id = ?',
              whereArgs: [sourceSavingsId],
            );
            _log.i(
              'Transferred $transferredCount virtual bookings from source to target',
            );

            // Delete source savings (virtual bookings already transferred)
            await txn.delete(
              'savings',
              where: 'id = ?',
              whereArgs: [sourceSavingsId],
            );
            _log.i('Deleted source savings, kept target savings');
          } else if (sourceSavingsId != null && targetSavingsId == null) {
            // only source savings exists => Update source savings to point to target tag
            await txn.update(
              'savings',
              {'tag_id': targetTagId.uuid},
              where: 'id = ?',
              whereArgs: [sourceSavingsId],
            );
            _log.i('Transferred source savings to target tag');
          }
          // else target savings exists but not source savings => noop
          // else neither source nor target savings exists => noop
        }

        // Step 3: Delete source tag
        final deleteCount = await txn.delete(
          'tag',
          where: 'id = ?',
          whereArgs: [sourceTagId.uuid],
        );

        if (deleteCount == 0) {
          throw Exception('Failed to delete source tag');
        }

        _log.i('Deleted source tag ${sourceTagId.uuid}');
      });

      _log.i(
        'Successfully merged tag ${sourceTagId.uuid} into ${targetTagId.uuid}',
      );

      // Emit updated tags list to all listeners
      await _reloadAndEmitTags();
    } catch (e, s) {
      _log.e('Failed to merge tags', error: e, stackTrace: s);
      rethrow;
    }
  }
}
