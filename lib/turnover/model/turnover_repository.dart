import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:kashr/core/decimal_json_converter.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/turnover/model/fts.dart';
import 'package:kashr/turnover/model/turnover_change.dart';
import 'package:kashr/turnover/model/turnover_filter.dart';
import 'package:kashr/turnover/model/turnover_sort.dart';
import 'package:kashr/turnover/model/year_month.dart';
import 'package:jiffy/jiffy.dart';
import 'package:uuid/uuid.dart';

import 'turnover.dart';

class TurnoverRepository {
  final StreamController<TurnoverChange> _changeController =
      StreamController<TurnoverChange>.broadcast();

  /// Stream of turnover changes for reactive updates.
  Stream<TurnoverChange> watchChanges() => _changeController.stream;

  void dispose() {
    _changeController.close();
  }

  Future<int> createTurnover(Turnover turnover) async {
    final db = await DatabaseHelper().database;
    final result = await db.insert('turnover', turnover.toJson());
    _changeController.add(TurnoversInserted([turnover]));
    return result;
  }

  Future<Turnover?> getTurnoverById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'turnover',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    if (maps.isNotEmpty) {
      final turnoverMap = maps.first;
      return Turnover.fromJson(turnoverMap);
    }
    return null;
  }

  Future<List<Turnover>> getTurnoversByApiIds(List<UuidValue> apiIds) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'turnover',
      where: 'api_id IN (${List.filled(apiIds.length, '?').join(',')})',
      whereArgs: apiIds.map((id) => id.uuid).toList(),
    );
    return result.map(Turnover.fromJson).toList();
  }

  /// Fetches turnovers for a specific month and year.
  Future<List<Turnover>> getTurnoversForMonth(YearMonth yearMonth) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    final maps = await db.query(
      'turnover',
      where: 'booking_date >= ? AND booking_date < ?',
      whereArgs: [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
      orderBy: 'booking_date DESC',
    );

    return maps.map(Turnover.fromJson).toList();
  }

  // Custom method to find accountId and apiId by a list of API IDs
  Future<List<TurnoverAccountIdAndApiId>> findAccountIdAndApiIdIn(
    List<String> apiIds,
  ) async {
    final db = await DatabaseHelper().database;

    final (placeholders, args) = db.inClause(apiIds);

    // Query the database
    final results = await db.rawQuery('''
      SELECT account_id, api_id
      FROM turnover
      WHERE api_id IN ($placeholders)
    ''', args.toList());

    return results.map(TurnoverAccountIdAndApiId.fromJson).toList();
  }

  // Example method to store a list of turnovers (already shown before)
  Future<List<Turnover>> saveAll(List<Turnover> turnovers) async {
    final db = await DatabaseHelper().database;

    final batch = db.batch();
    for (final turnover in turnovers) {
      batch.insert('turnover', turnover.toJson());
    }
    await batch.commit();
    return turnovers;
  }

  Future<void> batchUpdate(List<Turnover> turnovers) async {
    final db = await DatabaseHelper().database;
    final batch = db.batch();
    for (final turnover in turnovers) {
      batch.update(
        'turnover',
        turnover.toJson(),
        where: 'id = ?',
        whereArgs: [turnover.id.uuid],
      );
    }
    await batch.commit();
  }

  Future<int> updateTurnover(Turnover turnover) async {
    final db = await DatabaseHelper().database;
    final result = await db.update(
      'turnover',
      turnover.toJson(),
      where: 'id = ?',
      whereArgs: [turnover.id.uuid],
    );
    _changeController.add(TurnoversUpdated([turnover]));
    return result;
  }

  Future<int> deleteTurnover(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final result = await db.delete(
      'turnover',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
    _changeController.add(TurnoversDeleted([id]));
    return result;
  }

  Future<List<Turnover>> getTurnoversByApiIdsForAccount({
    required UuidValue accountId,
    required List<String> apiIds,
  }) async {
    final db = await DatabaseHelper().database;
    if (apiIds.isEmpty) {
      return [];
    }
    final result = await db.query(
      'turnover',
      where:
          'account_id = ? AND api_id IN (${List.filled(apiIds.length, '?').join(',')})',
      whereArgs: [accountId.uuid, ...apiIds],
    );
    return result.map(Turnover.fromJson).toList();
  }

  /// Counts unallocated turnovers.
  /// A turnover is considered unallocated if:
  /// - It has no tag_turnover entries, OR
  /// - The sum of tag_turnover amounts doesn't equal the turnover amount
  Future<int> countUnallocatedTurnovers({YearMonth? yearMonth}) async {
    final db = await DatabaseHelper().database;

    final whereClauses = <String>[];
    final whereArgs = <String>[];
    if (yearMonth != null) {
      final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
      final endDate = startDate.add(months: 1);
      whereClauses.add('t.booking_date >= ? AND t.booking_date < ?');
      whereArgs.addAll([
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ]);
    }

    final where = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM (
        SELECT t.id
        FROM turnover t
        LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
        $where
        GROUP BY t.id
        HAVING
          COUNT(tt.id) = 0 OR
          COALESCE(SUM(tt.amount_value), 0) != t.amount_value
      )
      ''', whereArgs);

    return result.first['count'] as int;
  }

  /// Sums the unallocated amount of all turnovers.
  /// A turnover is considered unallocated if:
  /// - It has no tag_turnover entries, OR
  /// - The sum of tag_turnover amounts doesn't equal the turnover amount
  Future<Decimal> sumUnallocatedTurnovers({YearMonth? yearMonth}) async {
    final db = await DatabaseHelper().database;

    final whereClauses = <String>[];
    final whereArgs = <String>[];
    if (yearMonth != null) {
      final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
      final endDate = startDate.add(months: 1);
      whereClauses.add('t.booking_date >= ? AND t.booking_date < ?');
      whereArgs.addAll([
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ]);
    }

    final where = whereClauses.isEmpty
        ? ''
        : 'WHERE ${whereClauses.join(' AND ')}';
    final result = await db.rawQuery('''
      SELECT SUM(unallocated_amount_abs) as total
      FROM (
        SELECT ABS(t.amount_value - COALESCE(SUM(tt.amount_value), 0)) as unallocated_amount_abs
        FROM turnover t
        LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
        $where
        GROUP BY t.id, t.amount_value
        HAVING
          COUNT(tt.id) = 0 OR
          COALESCE(SUM(tt.amount_value), 0) != t.amount_value
      )
      ''', whereArgs);

    return decimalUnscale(result.first['total'] as int? ?? 0)!;
  }

  /// Fetches unallocated turnovers for a specific month and year.
  /// A turnover is considered unallocated if:
  /// - It has no tag_turnover entries, OR
  /// - The sum of tag_turnover amounts doesn't equal the turnover amount
  Future<List<Turnover>> getUnallocatedTurnoversForMonth(
    YearMonth yearMonth, {
    int limit = 5,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    // Query to find turnovers that are not fully allocated
    // Orders by absolute amount DESC to prioritize high-value transactions
    final turnoverMaps = await db.rawQuery(
      '''
      SELECT DISTINCT t.*
      FROM turnover t
      LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
      WHERE t.booking_date >= ? AND t.booking_date < ?
      GROUP BY t.id
      HAVING
        COUNT(tt.id) = 0 OR
        COALESCE(SUM(tt.amount_value), 0) != t.amount_value
      ORDER BY ABS(t.amount_value) DESC, t.booking_date DESC NULLS FIRST
      LIMIT ?
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
        limit,
      ],
    );

    if (turnoverMaps.isEmpty) {
      return [];
    }

    final turnovers = turnoverMaps
        .map((map) => Turnover.fromJson(map))
        .toList();

    return turnovers;
  }

  /// Sumes all turnovers for a specific account up until
  /// [endDateInclusive] filters turnovers with bookingDate <= endDate
  Future<Decimal> sumTurnoversForAccount({
    required UuidValue accountId,
    DateTime? endDateInclusive,
  }) async {
    final db = await DatabaseHelper().database;

    final whereClauses = ['t.account_id = ?'];
    final whereArgs = <Object>[accountId.uuid];

    if (endDateInclusive != null) {
      whereClauses.add('t.booking_date <= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          endDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    final whereClause = 'WHERE ${whereClauses.join(' AND ')}';

    final maps = await db.rawQuery('''
        SELECT SUM(t.amount_value) as total
        FROM turnover t
        $whereClause
      ''', whereArgs);

    return decimalUnscale(maps.first['total'] as int? ?? 0)!;
  }

  /// Returns the ids of turnovers that are unmatched.
  /// An unmatched turnover is one that has NO associated tag_turnover entries.
  /// This ensures 1:1 matching semantics which are expected and easy to understand by the user.
  /// I.e. a turnover can only be matched fully and not partially.
  Future<Iterable<UuidValue>> filterUnmatched({
    required Iterable<UuidValue> turnoverIds,
  }) async {
    if (turnoverIds.isEmpty) {
      return [];
    }
    final db = await DatabaseHelper().database;

    // Create placeholders: (?, ?, ?, ...)
    final (placeholders, args) = db.inClause(
      turnoverIds,
      toArg: (id) => id.uuid,
    );

    final maps = await db.rawQuery(
      '''
      SELECT t.id
      FROM turnover t
      LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
      WHERE t.id IN ($placeholders)
      GROUP BY t.id
      HAVING COUNT(tt.id) = 0
      ''',
      [...args],
    );

    return maps.map((it) => UuidValue.fromString(it['id'] as String));
  }

  /// Get unmatched turnovers for a specific account.
  /// An unmatched turnover is one that has NO associated tag_turnover entries.
  /// This ensures 1:1 matching semantics which are expected and easy to understand by the user.
  /// I.e. a turnover can only be matched fully and not partially.
  ///
  /// Optionally filter by date range.
  /// [startDateInclusive] filters turnovers with bookingDate >= startDate
  /// [endDateInclusive] filters turnovers with bookingDate <= endDate
  Future<List<Turnover>> getUnmatchedTurnoversForAccount({
    required UuidValue accountId,
    DateTime? startDateInclusive,
    DateTime? endDateInclusive,
    int? limit,
    SortDirection direction = SortDirection.asc,
  }) async {
    final db = await DatabaseHelper().database;

    final whereClauses = ['t.account_id = ?'];
    final whereArgs = <Object>[accountId.uuid];

    if (startDateInclusive != null) {
      whereClauses.add('t.booking_date >= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          startDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    if (endDateInclusive != null) {
      whereClauses.add('t.booking_date <= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          endDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    final whereClause = 'WHERE ${whereClauses.join(' AND ')}';

    final maps = await db.rawQuery('''
      SELECT DISTINCT t.*
      FROM turnover t
      LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
      $whereClause
      GROUP BY t.id
      HAVING COUNT(tt.id) = 0
      ORDER BY t.booking_date ${direction.name}
      ${limit != null ? 'LIMIT ?' : ''}
      ''', limit != null ? [...whereArgs, limit] : whereArgs);

    return maps.map((e) => Turnover.fromJson(e)).toList();
  }

  /// Fetches a paginated list of turnovers.
  Future<List<Turnover>> getTurnoversPaginated({
    required int limit,
    required int offset,
    TurnoverFilter filter = TurnoverFilter.empty,
    TurnoverSort sort = TurnoverSort.defaultSort,
  }) async {
    final db = await DatabaseHelper().database;

    // Build WHERE clause and arguments based on filters
    final whereClauses = <String>[];
    final whereArgs = <Object>[];

    // Period filter (year and month)
    if (filter.period != null) {
      final startDate = Jiffy.parseFromDateTime(filter.period!.toDateTime());
      final endDate = startDate.add(months: 1);
      whereClauses.add('t.booking_date >= ? AND t.booking_date < ?');
      whereArgs.add(startDate.format(pattern: isoDateFormat));
      whereArgs.add(endDate.format(pattern: isoDateFormat));
    }

    // Sign filter - filter by income (positive) or expense (negative)
    if (filter.sign != null) {
      switch (filter.sign!) {
        case TurnoverSign.income:
          whereClauses.add('t.amount_value >= 0');
          break;
        case TurnoverSign.expense:
          whereClauses.add('t.amount_value < 0');
          break;
      }
    }

    // Search query filter using FTS5
    if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
      whereClauses.add('''
        EXISTS (
          SELECT 1 FROM turnover_fts
          WHERE turnover_fts.turnover_id = t.id
          AND turnover_fts MATCH ?
        )
      ''');
      whereArgs.add(sanitizeFts5Query(filter.searchQuery!));
    }

    if (filter.accountId != null) {
      whereClauses.add('t.account_id = ?');
      whereArgs.add(filter.accountId!.uuid);
    }

    // Tag filter - turnovers must have ALL specified tags
    if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
      // For each tag, ensure the turnover has a tag_turnover entry with that tagId
      for (final tagId in filter.tagIds!) {
        // "AND" semantics need an EXISTS per tag
        whereClauses.add('''
          EXISTS (
            SELECT 1 FROM tag_turnover tt_filter
            WHERE tt_filter.turnover_id = t.id AND tt_filter.tag_id = ?
          )
        ''');
        whereArgs.add(tagId.uuid);
      }
    }

    // Query based on filters

    final List<Map<String, Object?>> turnoverMaps;

    final whereClause = whereClauses.isNotEmpty
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';

    final orderBy = sort.toSqlOrderBy();

    if (filter.unallocatedOnly == true) {
      // Use the unallocated query logic
      turnoverMaps = await db.rawQuery(
        '''
        SELECT DISTINCT t.*
        FROM turnover t
        LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
        $whereClause
        GROUP BY t.id
        HAVING
          COUNT(tt.id) = 0 OR
          COALESCE(SUM(tt.amount_value), 0) != t.amount_value
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
        ''',
        [...whereArgs, limit, offset],
      );
    } else {
      // Regular query - need to use raw query to support tag filtering
      turnoverMaps = await db.rawQuery(
        '''
        SELECT t.*
        FROM turnover t
        $whereClause
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
        ''',
        [...whereArgs, limit, offset],
      );
    }

    return turnoverMaps.map((map) => Turnover.fromJson(map)).toList();
  }
}
