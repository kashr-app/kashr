import 'dart:async';

import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/turnover/model/fts.dart';
import 'package:kashr/turnover/model/tag.dart';
import 'package:kashr/turnover/model/tag_turnover.dart';
import 'package:kashr/turnover/model/tag_turnover_change.dart';
import 'package:kashr/turnover/model/tag_turnover_sort.dart';
import 'package:kashr/turnover/model/tag_turnovers_filter.dart';
import 'package:kashr/turnover/model/turnover.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:jiffy/jiffy.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

class TagTurnoverRepository {
  final Logger _log;
  final StreamController<TagTurnoverChange> _changeController =
      StreamController<TagTurnoverChange>.broadcast();

  TagTurnoverRepository(this._log);

  /// Stream of tag turnover changes for reactive updates.
  Stream<TagTurnoverChange> watchChanges() => _changeController.stream;

  /// Disposes the repository and closes the change stream.
  void dispose() {
    _changeController.close();
  }

  Future<int> createTagTurnover(TagTurnover tagTurnover) async {
    final db = await DatabaseHelper().database;
    final result = await db.insert('tag_turnover', tagTurnover.toJson());
    _changeController.add(TagTurnoversInserted([tagTurnover]));
    return result;
  }

  Future<void> createTagTurnoversBatch(List<TagTurnover> tagTurnovers) async {
    final db = await DatabaseHelper().database;

    final batch = db.batch();
    for (var tag in tagTurnovers) {
      batch.insert('tag_turnover', tag.toJson());
    }
    await batch.commit(noResult: true);
    _changeController.add(TagTurnoversInserted(tagTurnovers));
  }

  /// Batch updates multiple tag turnovers in a single transaction.
  Future<void> updateTagTurnoversBatch(List<TagTurnover> tagTurnovers) async {
    if (tagTurnovers.isEmpty) return;

    final db = await DatabaseHelper().database;
    final batch = db.batch();

    for (final tt in tagTurnovers) {
      batch.update(
        'tag_turnover',
        tt.toJson(),
        where: 'id = ?',
        whereArgs: [tt.id.uuid],
      );
    }

    await batch.commit(noResult: true);
    _changeController.add(TagTurnoversUpdated(tagTurnovers));
  }

  /// Batch deletes multiple tag turnovers by their IDs.
  Future<void> deleteTagTurnoversBatch(List<UuidValue> ids) async {
    if (ids.isEmpty) return;

    final db = await DatabaseHelper().database;
    final batch = db.batch();

    for (final id in ids) {
      batch.delete('tag_turnover', where: 'id = ?', whereArgs: [id.uuid]);
    }

    await batch.commit(noResult: true);
    _changeController.add(TagTurnoversDeleted(ids));
  }

  /// Unallocates multiple tag turnovers from their turnovers by setting
  /// turnover_id to null, effectively making them pending tag turnovers.
  Future<void> unallocateManyFromTurnover(List<TagTurnover> tts) async {
    if (tts.isEmpty) return;

    final db = await DatabaseHelper().database;
    final batch = db.batch();

    final result = <TagTurnover>[];

    for (final t in tts) {
      batch.update(
        'tag_turnover',
        {'turnover_id': null},
        where: 'id = ?',
        whereArgs: [t.id.uuid],
      );
      result.add(t.copyWith(turnoverId: null));
    }

    await batch.commit(noResult: true);
    _changeController.add(TagTurnoversUpdated(result));
  }

  /// Batch adds a tag to multiple turnovers.
  /// For each turnover, allocates the remaining unallocated amount to the tag.
  Future<void> batchAddTagToTurnovers(
    List<Turnover> turnovers,
    UuidValue tagId,
  ) async {
    if (turnovers.isEmpty) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds = turnovers.map((t) => t.id).toList();

    if (turnoverIds.isEmpty) return;

    // Fetch all existing tag turnovers for these turnovers in one query
    final (placeholders, args) = db.inClause(
      turnoverIds,
      toArg: (it) => it.uuid,
    );
    final existingTagTurnovers = await db.rawQuery(
      '''
      SELECT turnover_id, SUM(amount_value) as total
      FROM tag_turnover
      WHERE turnover_id IN ($placeholders)
      GROUP BY turnover_id
      ''',
      [...args],
    );

    // Build a map of turnover ID to allocated amount
    final allocatedByTurnover = <String, Decimal>{};
    for (final row in existingTagTurnovers) {
      final turnoverId = row['turnover_id'] as String;
      allocatedByTurnover[turnoverId] = _unscale(row['total']);
    }

    // Create batch insert
    final batch = db.batch();
    final createdTagTurnovers = <TagTurnover>[];

    for (final turnover in turnovers) {
      final allocatedAmount =
          allocatedByTurnover[turnover.id.uuid] ?? Decimal.zero;
      final remainingAmount = turnover.amountValue - allocatedAmount;

      // Only create if there's remaining amount to allocate
      if (remainingAmount != Decimal.zero) {
        final tagTurnover = TagTurnover(
          id: const Uuid().v4obj(),
          turnoverId: turnover.id,
          tagId: tag.id,
          amountValue: remainingAmount,
          amountUnit: turnover.amountUnit,
          counterPart: turnover.counterPart,
          note: null,
          createdAt: DateTime.now(),
          bookingDate: turnover.bookingDate ?? DateTime.now(),
          accountId: turnover.accountId,
        );

        batch.insert('tag_turnover', tagTurnover.toJson());
        createdTagTurnovers.add(tagTurnover);
      }
    }

    await batch.commit(noResult: true);

    if (createdTagTurnovers.isNotEmpty) {
      _changeController.add(TagTurnoversInserted(createdTagTurnovers));
    }
  }

  /// Batch deletes all tag_turnover entries for the specified [tagId] across
  /// the given [turnoverIds].
  Future<void> batchDeleteByTurnoverInAndTag(
    List<UuidValue> turnoverIds,
    UuidValue tagId,
  ) async {
    if (turnoverIds.isEmpty) return;

    final db = await DatabaseHelper().database;

    if (turnoverIds.isEmpty) return;

    // Build the SQL query with placeholders
    final (placeholders, args) = db.inClause(
      turnoverIds,
      toArg: (it) => it.uuid,
    );

    // First, get the IDs of tag_turnovers that will be deleted
    final toDeleteRows = await db.rawQuery(
      '''
      SELECT id FROM tag_turnover
      WHERE tag_id = ? AND turnover_id IN ($placeholders)
      ''',
      [tagId.uuid, ...args],
    );

    final deletedIds = toDeleteRows
        .map((row) => UuidValue.fromString(row['id'] as String))
        .toList();

    // Delete all tag_turnover entries for this tag and these turnovers
    await db.delete(
      'tag_turnover',
      where: 'tag_id = ? AND turnover_id IN ($placeholders)',
      whereArgs: [tagId.uuid, ...args],
    );

    if (deletedIds.isNotEmpty) {
      _changeController.add(TagTurnoversDeleted(deletedIds));
    }
  }

  /// Batch unallocates all tag_turnover entries for the specified [tagId]
  /// across the given [turnoverIds] by setting their turnover_id to null.
  /// This keeps the taggings but removes them from the turnovers.
  Future<void> batchUnallocateByTurnoverInAndTag(
    List<UuidValue> turnoverIds,
    UuidValue tagId,
  ) async {
    if (turnoverIds.isEmpty) return;

    final db = await DatabaseHelper().database;

    // Build the SQL query with placeholders
    final (placeholders, args) = db.inClause(
      turnoverIds,
      toArg: (it) => it.uuid,
    );

    // Fetch all tag_turnovers that will be unallocated
    final rows = await db.rawQuery(
      '''
      SELECT * FROM tag_turnover
      WHERE tag_id = ? AND turnover_id IN ($placeholders)
      ''',
      [tagId.uuid, ...args],
    );

    final tagTurnovers = rows.map((row) => TagTurnover.fromJson(row)).toList();

    if (tagTurnovers.isNotEmpty) {
      await unallocateManyFromTurnover(tagTurnovers);
    }
  }

  Future<Map<UuidValue, Map<UuidValue, TagTurnover>>> getByTurnoverIds(
    Iterable<UuidValue> turnoverIds,
  ) async {
    final db = await DatabaseHelper().database;

    final (placeholders, args) = db.inClause(
      turnoverIds,
      toArg: (it) => it.uuid,
    );
    final maps = await db.query(
      'tag_turnover',
      where: 'turnover_id IN ($placeholders)',
      whereArgs: args.toList(),
    );

    Map<UuidValue, Map<UuidValue, TagTurnover>> result = {};
    for (final ttMap in maps) {
      final tt = TagTurnover.fromJson(ttMap);
      // can guarantee turnoverId to be not null here because we queried by the turnover_id being set.
      final turnoverId = tt.turnoverId!;
      result.putIfAbsent(turnoverId, () => <UuidValue, TagTurnover>{})[tt.id] =
          tt;
    }

    return result;
  }

  Future<Map<UuidValue, TagTurnover>> getByTurnover(
    UuidValue turnoverId,
  ) async {
    final byId = await (getByTurnoverIds([turnoverId]));
    return byId[turnoverId] ?? {};
  }

  Future<List<TagTurnover>> getByTag(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    final maps = await db.query(
      'tag_turnover',
      where: 'tag_id = ?',
      whereArgs: [tagId.uuid],
    );

    return maps.map((e) => TagTurnover.fromJson(e)).toList();
  }

  /// Get unmatched TagTurnovers (turnoverId IS NULL)
  /// Optionally filter by account and date range
  Future<List<TagTurnover>> getUnmatched({
    UuidValue? accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await DatabaseHelper().database;

    final whereClauses = ['turnover_id IS NULL'];
    final whereArgs = <Object>[];

    if (accountId != null) {
      whereClauses.add('account_id = ?');
      whereArgs.add(accountId.uuid);
    }

    if (startDate != null) {
      whereClauses.add('booking_date >= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(startDate).format(pattern: isoDateFormat),
      );
    }

    if (endDate != null) {
      whereClauses.add('booking_date < ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(endDate).format(pattern: isoDateFormat),
      );
    }

    final maps = await db.query(
      'tag_turnover',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'booking_date DESC',
    );

    return maps.map((e) => TagTurnover.fromJson(e)).toList();
  }

  /// Allocate [tagTurnoverId] to a [turnoverId].
  Future<void> allocateToTurnover(
    UuidValue tagTurnoverId,
    UuidValue turnoverId,
  ) async {
    final tagTurnover = await getById(tagTurnoverId);
    if (tagTurnover == null) {
      _log.e('Could not find tagTurnover to allocate');
    } else {
      final updated = tagTurnover.copyWith(turnoverId: turnoverId);
      // will emit changes
      await updateTagTurnover(updated);
    }
  }

  /// Unallocates a matched TagTurnover from its Turnover
  Future<void> unallocateFromTurnover(UuidValue tagTurnoverId) async {
    final tagTurnover = await getById(tagTurnoverId);
    if (tagTurnover == null) {
      _log.e('Could not find tagTurnover to unallocate');
    } else {
      final updated = tagTurnover.copyWith(turnoverId: null);
      // will emit changes
      await updateTagTurnover(updated);
    }
  }

  /// Get TagTurnover by ID
  Future<TagTurnover?> getById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'tag_turnover',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    if (maps.isEmpty) return null;
    return TagTurnover.fromJson(maps.first);
  }

  /// Get TagTurnover by IDs
  Future<Map<UuidValue, TagTurnover>> getByIds(Iterable<UuidValue> ids) async {
    if (ids.isEmpty) return {};

    final db = await DatabaseHelper().database;

    final (placeholders, args) = db.inClause(ids, toArg: (it) => it.uuid);

    final result = await db.query(
      'tag_turnover',
      where: 'id IN ($placeholders)',
      whereArgs: args.toList(),
    );

    final res = <UuidValue, TagTurnover>{};
    for (final map in result) {
      final tt = TagTurnover.fromJson(map);
      res[tt.id] = tt;
    }
    return res;
  }

  Future<int> updateTagTurnover(TagTurnover tagTurnover) async {
    final db = await DatabaseHelper().database;

    final result = await db.update(
      'tag_turnover',
      tagTurnover.toJson(),
      where: 'id = ?',
      whereArgs: [tagTurnover.id.uuid],
    );

    _changeController.add(TagTurnoversUpdated([tagTurnover]));

    return result;
  }

  Future<int> deleteTagTurnover(UuidValue id) async {
    final db = await DatabaseHelper().database;

    final result = await db.delete(
      'tag_turnover',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    _changeController.add(TagTurnoversDeleted([id]));

    return result;
  }

  Future<int> deleteAllByTagId(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    // First get the IDs to notify listeners
    final toDeleteRows = await db.query(
      'tag_turnover',
      columns: ['id'],
      where: 'tag_id = ?',
      whereArgs: [tagId.uuid],
    );

    final deletedIds = toDeleteRows
        .map((row) => UuidValue.fromString(row['id'] as String))
        .toList();

    final result = await db.delete(
      'tag_turnover',
      where: 'tag_id = ?',
      whereArgs: [tagId.uuid],
    );

    if (deletedIds.isNotEmpty) {
      _changeController.add(TagTurnoversDeleted(deletedIds));
    }

    return result;
  }

  Future<int> deleteAllForTurnover(UuidValue turnoverId) async {
    final db = await DatabaseHelper().database;

    // First get the IDs to notify listeners
    final toDeleteRows = await db.query(
      'tag_turnover',
      columns: ['id'],
      where: 'turnover_id = ?',
      whereArgs: [turnoverId.uuid],
    );

    final deletedIds = toDeleteRows
        .map((row) => UuidValue.fromString(row['id'] as String))
        .toList();

    final result = await db.delete(
      'tag_turnover',
      where: 'turnover_id = ?',
      whereArgs: [turnoverId.uuid],
    );

    if (deletedIds.isNotEmpty) {
      _changeController.add(TagTurnoversDeleted(deletedIds));
    }

    return result;
  }

  Future<int> updateTagByTagId(UuidValue oldTagId, UuidValue newTagId) async {
    final db = await DatabaseHelper().database;

    final result = await db.query(
      'tag_turnover',
      where: 'tag_id = ?',
      whereArgs: [oldTagId.uuid],
    );

    final updated = result.map(
      (map) => TagTurnover.fromJson(map).copyWith(tagId: newTagId),
    );

    // will emit updates
    await updateTagTurnoversBatch(updated.toList());

    return updated.length;
  }

  Future<Decimal> sumByTag(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_value) AS total
      FROM tag_turnover
      WHERE tag_id = ?
    ''',
      [tagId.uuid],
    );

    return _unscale(result.first['total']);
  }

  Future<Decimal> sumByTagAndAccount(
    UuidValue tagId,
    UuidValue accountId,
  ) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_value) AS total
      FROM tag_turnover
      WHERE tag_id = ? AND account_id = ?
    ''',
      [tagId.uuid, accountId.uuid],
    );

    return _unscale(result.first['total']);
  }

  /// Fetches tag summaries for a month and sign.
  /// Excludes transfer tags (semantic = 'transfer').
  Future<List<TagSummary>> getTagSummariesForMonth(
    YearMonth yearMonth,
    TurnoverSign sign, {
    required TagSemantic? semantic,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    final amountWhere = switch (sign) {
      TurnoverSign.income => 'AND tt.amount_value >= 0',
      TurnoverSign.expense => 'AND tt.amount_value < 0',
    };

    final semanticWhere =
        "AND t.semantic ${(semantic == null) ? 'IS NULL' : "= '${semantic.name}'"}";

    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        t.semantic as tag_semantic,
        SUM(tt.amount_value) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tag_id = t.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnover_id IS NOT NULL
        $semanticWhere
        $amountWhere
      GROUP BY t.id, t.name, t.color, t.semantic
      ORDER BY total_amount DESC
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.map((map) {
      final tagId = UuidValue.fromString(map['tag_id'] as String);
      final totalAmount = _unscale(map['total_amount']);

      return TagSummary(tagId: tagId, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches tag summaries across multiple months for analytics.
  /// Returns a map where the key is "YYYY-MM" and the value is
  /// a list of TagSummary for that month.
  Future<Map<String, List<TagSummary>>> getTagSummariesForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    List<UuidValue>? tagIds,
  }) async {
    final db = await DatabaseHelper().database;

    // Build tag filter if provided
    final tagFilter = tagIds != null && tagIds.isNotEmpty
        ? 'AND t.id IN (${List.filled(tagIds.length, '?').join(',')})'
        : '';

    final tagArgs = tagIds?.map((id) => id.uuid).toList() ?? <String>[];

    final result = await db.rawQuery(
      '''
      SELECT
        strftime('%Y-%m', tt.booking_date) as month,
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        SUM(tt.amount_value) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tag_id = t.id
      INNER JOIN turnover tv ON tt.turnover_id = tv.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnover_id IS NOT NULL
      $tagFilter
      GROUP BY month, t.id, t.name, t.color
      ORDER BY month ASC, total_amount DESC
      ''',
      [
        Jiffy.parseFromDateTime(startDate).format(pattern: isoDateFormat),
        Jiffy.parseFromDateTime(endDate).format(pattern: isoDateFormat),
        ...tagArgs,
      ],
    );

    final summariesByMonth = <String, List<TagSummary>>{};

    for (final map in result) {
      final tagId = UuidValue.fromString(map['tag_id'] as String);
      final totalAmount = _unscale(map['total_amount']);
      final summary = TagSummary(tagId: tagId, totalAmount: totalAmount);

      final month = map['month'] as String;
      summariesByMonth.putIfAbsent(month, () => []).add(summary);
    }

    return summariesByMonth;
  }

  Future<int> count(YearMonth yearMonth) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT COUNT(tt.id) as count
      FROM tag_turnover tt
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.first['count'] as int;
  }

  /// Fetches tag turnovers needed for dashboard calculations.
  /// Returns two DISJOINT sets:
  /// - allocatedInMonth: Tag turnovers with tt.booking_date in the month
  ///   (used for allocated sums)
  /// - allocatedOutsideMonthButTurnoverInMonth: Tag turnovers where
  ///   tv.booking_date is in the month but tt.booking_date is OUTSIDE
  ///   the month (needed to calculate untagged portions IN the month)
  Future<
    ({
      List<TagTurnover> allocatedInMonth,
      List<TagTurnover> allocatedOutsideMonthButTurnoverInMonth,
    })
  >
  getTagTurnoversForMonthlyDashboard(YearMonth yearMonth) async {
    final startDate = yearMonth.toDateTime();
    final endDate = Jiffy.parseFromDateTime(startDate).add(months: 1).dateTime;

    final db = await DatabaseHelper().database;

    final start = isoDateFormatter.format(startDate);
    final end = isoDateFormatter.format(endDate);

    final result = await db.rawQuery(
      '''
      SELECT DISTINCT tt.*,
        CASE WHEN tt.booking_date >= ? AND tt.booking_date < ?
             THEN 1 ELSE 0 END
               as is_allocated_in_month
      FROM tag_turnover tt
      INNER JOIN turnover tv ON tt.turnover_id = tv.id
      WHERE tt.turnover_id IS NOT NULL
        AND (
          (tt.booking_date >= ? AND tt.booking_date < ?)
          OR (tv.booking_date >= ? AND tv.booking_date < ?)
        )
      ''',
      [
        // For the CASE statement
        start, end,
        // For the WHERE clause
        start, end,
        start, end,
      ],
    );

    // Group by is_allocated_in_month flag using groupBy for single pass
    final grouped = result.groupListsBy(
      (map) => map['is_allocated_in_month'] == 1,
    );

    final allocatedInMonth = (grouped[true] ?? [])
        .map((map) => TagTurnover.fromJson(map))
        .toList();

    final allocatedOutside = (grouped[false] ?? [])
        .map((map) => TagTurnover.fromJson(map))
        .toList();

    return (
      allocatedInMonth: allocatedInMonth,
      allocatedOutsideMonthButTurnoverInMonth: allocatedOutside,
    );
  }

  Decimal _unscale(Object? result) {
    return decimalUnscale(result as int? ?? 0) ?? Decimal.zero;
  }

  Future<List<UuidValue>> findAccountsByTagId(UuidValue tagId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT account_id
      FROM tag_turnover
      WHERE tag_id = ?
      ''',
      [tagId.uuid],
    );
    return result
        .map((m) => UuidValue.fromString(m['account_id'] as String))
        .toList();
  }

  /// Fetches tag turnovers with associated tag and account details.
  /// Supports pagination, filtering, and sorting.
  Future<List<TagTurnover>> getTagTurnoversPaginated({
    required int limit,
    required int offset,
    required TagTurnoversFilter filter,
    required TagTurnoverSort sort,
  }) async {
    final db = await DatabaseHelper().database;

    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    // Filter by has transfer tag
    if (filter.transferTagOnly == true) {
      whereClauses.add('''
        EXISTS (
          SELECT 1 FROM tag t
          WHERE t.id = tt.tag_id
            AND t.semantic = 'transfer'
        )
      ''');
    }

    // Filter to only show tag turnovers not part of a finished transfer
    // (includes unlinked ones and those linked to transfers with only one side)
    if (filter.unfinishedTransfersOnly == true) {
      whereClauses.add('''
        tt.id NOT IN (
          SELECT tag_turnover_id
          FROM transfer_tag_turnover
          WHERE transfer_id IN (
            SELECT transfer_id
            FROM transfer_tag_turnover
            GROUP BY transfer_id
            HAVING COUNT(*) = 2
          )
        )
      ''');
    }

    // Filter by period
    if (filter.period != null) {
      final startDate = Jiffy.parseFromDateTime(filter.period!.toDateTime());
      final endDate = startDate.add(months: 1);
      whereClauses.add('tt.booking_date >= ?');
      whereClauses.add('tt.booking_date < ?');
      whereArgs.add(startDate.format(pattern: isoDateFormat));
      whereArgs.add(endDate.format(pattern: isoDateFormat));
    }

    // Filter by tag IDs
    if (filter.tagIds?.isNotEmpty == true) {
      final (placeholders, args) = db.inClause(
        filter.tagIds!,
        toArg: (id) => id.uuid,
      );
      whereClauses.add('tt.tag_id IN ($placeholders)');
      whereArgs.addAll(args);
    }

    // Filter by account IDs
    if (filter.accountIds?.isNotEmpty == true) {
      final (placeholders, args) = db.inClause(
        filter.accountIds!,
        toArg: (id) => id.uuid,
      );
      whereClauses.add('tt.account_id IN ($placeholders)');
      whereArgs.addAll(args);
    }

    // Filter by sign
    if (filter.sign != null) {
      switch (filter.sign!) {
        case TurnoverSign.income:
          whereClauses.add('tt.amount_value >= 0');
          break;
        case TurnoverSign.expense:
          whereClauses.add('tt.amount_value < 0');
          break;
      }
    }

    // Filter by matched/pending status
    if (filter.isMatched != null) {
      whereClauses.add(
        filter.isMatched!
            ? 'tt.turnover_id IS NOT NULL'
            : 'tt.turnover_id IS NULL',
      );
    }

    // Search query
    if (filter.searchQuery?.isNotEmpty == true) {
      whereClauses.add('''
        EXISTS (
          SELECT 1 FROM tag_turnover_fts
          WHERE tag_turnover_fts.tag_turnover_id = tt.id
          AND tag_turnover_fts MATCH ?
        )
      ''');
      whereArgs.add(sanitizeFts5Query(filter.searchQuery!));
    }

    // Filter by excluded
    if (filter.excludeTagTurnoverIds?.isNotEmpty == true) {
      final (placeholders, args) = db.inClause(
        filter.excludeTagTurnoverIds!,
        toArg: (it) => it.uuid,
      );
      whereClauses.add('tt.id NOT IN ($placeholders)');
      whereArgs.addAll(args);
    }

    final whereClause = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';

    final orderByClause = sort.toSqlOrderBy();

    final query =
        '''
      SELECT
        tt.*
      FROM tag_turnover tt
      $whereClause
      ORDER BY $orderByClause
      LIMIT ? OFFSET ?
    ''';

    final result = await db.rawQuery(query, [...whereArgs, limit, offset]);

    return result.map((map) => TagTurnover.fromJson(map)).toList();
  }
}

/// A summary of spending for a specific tag.
class TagSummary {
  final UuidValue tagId;
  final Decimal totalAmount;

  TagSummary({required this.tagId, required this.totalAmount});

  TagSummary copyWith({UuidValue? tagId, Decimal? totalAmount}) {
    return TagSummary(
      tagId: tagId ?? this.tagId,
      totalAmount: totalAmount ?? this.totalAmount,
    );
  }
}
