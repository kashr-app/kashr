import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_sort.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:decimal/decimal.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:jiffy/jiffy.dart';
import 'turnover.dart';
import 'package:uuid/uuid.dart';

const int scaleFactor = 100; // Define scale factor (e.g., 2 decimal places)

class TurnoverRepository {
  Future<int> createTurnover(Turnover turnover) async {
    final db = await DatabaseHelper().database;
    return await db.insert('turnover', turnover.toJson());
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

  Future<List<Turnover>> getTurnovers() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'turnover',
      orderBy: 'bookingDate DESC NULLS FIRST',
    );

    return maps.map((map) => Turnover.fromJson(map)).toList();
  }

  Future<List<Turnover>> getTurnoversByApiIds(List<UuidValue> apiIds) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'turnover',
      where: 'apiId IN (${List.filled(apiIds.length, '?').join(',')})',
      whereArgs: apiIds.map((id) => id.uuid).toList(),
    );
    return result.map((e) => Turnover.fromJson(e)).toList();
  }

  /// Fetches turnovers for a specific month and year.
  Future<List<Turnover>> getTurnoversForMonth(YearMonth yearMonth) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    final maps = await db.query(
      'turnover',
      where: 'bookingDate >= ? AND bookingDate < ?',
      whereArgs: [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
      orderBy: 'bookingDate DESC',
    );

    return maps.map((map) => Turnover.fromJson(map)).toList();
  }

  // Custom method to find accountId and apiId by a list of API IDs
  Future<List<TurnoverAccountIdAndApiId>> findAccountIdAndApiIdIn(
    List<String> apiIds,
  ) async {
    final db = await DatabaseHelper().database;

    // Create placeholders for the IN clause
    final placeholders = List.generate(apiIds.length, (_) => '?').join(',');

    // Query the database
    final results = await db.rawQuery('''
      SELECT accountId, apiId
      FROM turnover
      WHERE apiId IN ($placeholders)
    ''', apiIds.map((e) => e).toList());

    return results.map((e) => TurnoverAccountIdAndApiId.fromJson(e)).toList();
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
    return await db.update(
      'turnover',
      turnover.toJson(),
      where: 'id = ?',
      whereArgs: [turnover.id.uuid],
    );
  }

  Future<int> deleteTurnover(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return await db.delete('turnover', where: 'id = ?', whereArgs: [id.uuid]);
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
          'accountId = ? AND apiId IN (${List.filled(apiIds.length, '?').join(',')})',
      whereArgs: [accountId.uuid, ...apiIds],
    );
    return result.map((e) => Turnover.fromJson(e)).toList();
  }

  /// Counts unallocated turnovers for a specific month and year.
  /// A turnover is considered unallocated if:
  /// - It has no tag_turnover entries, OR
  /// - The sum of tag_turnover amounts doesn't equal the turnover amount
  Future<int> countUnallocatedTurnoversForMonth(YearMonth yearMonth) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(yearMonth.toDateTime());
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT COUNT(DISTINCT t.id) as count
      FROM turnover t
      LEFT JOIN tag_turnover tt ON t.id = tt.turnoverId
      WHERE t.bookingDate >= ? AND t.bookingDate < ?
      GROUP BY t.id
      HAVING
        COUNT(tt.id) = 0 OR
        COALESCE(SUM(tt.amountValue), 0) != t.amountValue
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.length; // Number of rows = number of unallocated turnovers
  }

  /// Fetches unallocated turnovers for a specific month and year.
  /// A turnover is considered unallocated if:
  /// - It has no tag_turnover entries, OR
  /// - The sum of tag_turnover amounts doesn't equal the turnover amount
  Future<List<TurnoverWithTags>> getUnallocatedTurnoversForMonth(YearMonth yearMonth, {
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
      LEFT JOIN tag_turnover tt ON t.id = tt.turnoverId
      WHERE t.bookingDate >= ? AND t.bookingDate < ?
      GROUP BY t.id
      HAVING
        COUNT(tt.id) = 0 OR
        COALESCE(SUM(tt.amountValue), 0) != t.amountValue
      ORDER BY ABS(t.amountValue) DESC, t.bookingDate DESC NULLS FIRST
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
    final turnoverIds = turnovers.map((t) => t.id.uuid).toList();

    if (turnoverIds.isEmpty) {
      return turnovers
          .map((t) => TurnoverWithTags(turnover: t, tagTurnovers: []))
          .toList();
    }

    // Fetch all tag_turnovers for these turnovers with their tags in one query
    final placeholders = List.generate(
      turnoverIds.length,
      (_) => '?',
    ).join(',');
    final tagTurnoverMaps = await db.rawQuery('''
      SELECT
        tt.id as tt_id,
        tt.turnoverId as tt_turnoverId,
        tt.tagId as tt_tagId,
        tt.amountValue as tt_amountValue,
        tt.amountUnit as tt_amountUnit,
        tt.note as tt_note,
        tt.createdAt as tt_createdAt,
        tt.booking_date as tt_bookingDate,
        tt.account_id as tt_accountId,
        tt.recurring_rule_id as tt_recurringRuleId,
        t.id as t_id,
        t.name as t_name,
        t.color as t_color
      FROM tag_turnover tt
      LEFT JOIN tag t ON tt.tagId = t.id
      WHERE tt.turnoverId IN ($placeholders)
      ORDER BY tt.amountValue DESC
      ''', turnoverIds);

    // Group tag turnovers by turnover ID
    final tagTurnoversByTurnoverId = <String, List<TagTurnoverWithTag>>{};
    for (final map in tagTurnoverMaps) {
      final turnoverId = map['tt_turnoverId'] as String?;
      if (turnoverId == null) continue;

      final tagTurnover = TagTurnover(
        id: UuidValue.fromString(map['tt_id'] as String),
        turnoverId: UuidValue.fromString(turnoverId),
        tagId: UuidValue.fromString(map['tt_tagId'] as String),
        amountValue:
            (Decimal.fromInt(map['tt_amountValue'] as int) /
                    Decimal.fromInt(scaleFactor))
                .toDecimal(),
        amountUnit: map['tt_amountUnit'] as String,
        note: map['tt_note'] as String?,
        createdAt: DateTime.parse(map['tt_createdAt'] as String),
        bookingDate: DateTime.parse(map['tt_bookingDate'] as String),
        accountId: UuidValue.fromString(map['tt_accountId'] as String),
        recurringRuleId: map['tt_recurringRuleId'] != null
            ? UuidValue.fromString(map['tt_recurringRuleId'] as String)
            : null,
      );

      final tag = Tag(
        id: map['t_id'] != null
            ? UuidValue.fromString(map['t_id'] as String)
            : null,
        name: map['t_name'] as String? ?? 'Unknown',
        color: map['t_color'] as String?,
      );

      final tagTurnoverWithTag = TagTurnoverWithTag(
        tagTurnover: tagTurnover,
        tag: tag,
      );

      tagTurnoversByTurnoverId
          .putIfAbsent(turnoverId, () => [])
          .add(tagTurnoverWithTag);
    }

    // Combine turnovers with their tag turnovers
    return turnovers.map((turnover) {
      final turnoverId = turnover.id.uuid;
      return TurnoverWithTags(
        turnover: turnover,
        tagTurnovers:
            tagTurnoversByTurnoverId[turnoverId] ?? <TagTurnoverWithTag>[],
      );
    }).toList();
  }

  /// Get all turnovers for a specific account
  /// Optionally filter by date range
  /// [startDateInclusive] filters turnovers with bookingDate >= startDate
  /// [endDateInclusive] filters turnovers with bookingDate <= endDate
  Future<List<Turnover>> getTurnoversForAccount({
    required UuidValue accountId,
    DateTime? startDateInclusive,
    DateTime? endDateInclusive,
    int? limit,
    SortDirection direction = SortDirection.asc,
  }) async {
    final db = await DatabaseHelper().database;

    final whereClauses = ['accountId = ?'];
    final whereArgs = <Object>[accountId.uuid];

    if (startDateInclusive != null) {
      whereClauses.add('bookingDate >= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          startDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    if (endDateInclusive != null) {
      whereClauses.add('bookingDate <= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          endDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    final maps = await db.query(
      'turnover',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'bookingDate ${direction.name}',
      limit: limit,
    );

    return maps.map((e) => Turnover.fromJson(e)).toList();
  }

  /// Fetches a paginated list of turnovers with their associated tags.
  /// This method efficiently loads all data in a single query to avoid N+1 problems.
  Future<List<TurnoverWithTags>> getTurnoversWithTagsPaginated({
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
      whereClauses.add('t.bookingDate >= ? AND t.bookingDate < ?');
      whereArgs.add(startDate.format(pattern: isoDateFormat));
      whereArgs.add(endDate.format(pattern: isoDateFormat));
    }

    // Sign filter - filter by income (positive) or expense (negative)
    if (filter.sign != null) {
      switch (filter.sign!) {
        case TurnoverSign.income:
          whereClauses.add('t.amountValue > 0');
          break;
        case TurnoverSign.expense:
          whereClauses.add('t.amountValue < 0');
          break;
      }
    }

    // Tag filter - turnovers must have ALL specified tags
    if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
      // For each tag, ensure the turnover has a tag_turnover entry with that tagId
      for (final tagId in filter.tagIds!) {
        whereClauses.add('''
          EXISTS (
            SELECT 1 FROM tag_turnover tt_filter
            WHERE tt_filter.turnoverId = t.id AND tt_filter.tagId = ?
          )
        ''');
        whereArgs.add(tagId);
      }
    }

    // Query based on filters
    final List<Map<String, Object?>> turnoverMaps;

    if (filter.unallocatedOnly == true) {
      // Use the unallocated query logic
      final whereClause = whereClauses.isNotEmpty
          ? 'WHERE ${whereClauses.join(' AND ')}'
          : '';

      // For unallocated, use custom sort or default to amount DESC
      final orderBy =
          sort.orderBy == SortField.bookingDate &&
              sort.direction == SortDirection.desc
          ? 'ABS(t.amountValue) DESC, t.bookingDate DESC NULLS FIRST'
          : sort.toSqlOrderBy();

      turnoverMaps = await db.rawQuery(
        '''
        SELECT DISTINCT t.*
        FROM turnover t
        LEFT JOIN tag_turnover tt ON t.id = tt.turnoverId
        $whereClause
        GROUP BY t.id
        HAVING
          COUNT(tt.id) = 0 OR
          COALESCE(SUM(tt.amountValue), 0) != t.amountValue
        ORDER BY $orderBy
        LIMIT ? OFFSET ?
        ''',
        [...whereArgs, limit, offset],
      );
    } else {
      // Regular query - need to use raw query to support tag filtering
      final whereClause = whereClauses.isNotEmpty
          ? 'WHERE ${whereClauses.join(' AND ')}'
          : '';
      final orderBy = sort.toSqlOrderBy();

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

    if (turnoverMaps.isEmpty) {
      return [];
    }

    final turnovers = turnoverMaps
        .map((map) => Turnover.fromJson(map))
        .toList();
    final turnoverIds = turnovers.map((t) => t.id.uuid).toList();

    if (turnoverIds.isEmpty) {
      // Return turnovers without tags if no valid IDs
      return turnovers
          .map((t) => TurnoverWithTags(turnover: t, tagTurnovers: []))
          .toList();
    }

    // Fetch all tag_turnovers for these turnovers with their tags in one query
    final placeholders = List.generate(
      turnoverIds.length,
      (_) => '?',
    ).join(',');
    final tagTurnoverMaps = await db.rawQuery('''
      SELECT
        tt.id as tt_id,
        tt.turnoverId as tt_turnoverId,
        tt.tagId as tt_tagId,
        tt.amountValue as tt_amountValue,
        tt.amountUnit as tt_amountUnit,
        tt.note as tt_note,
        tt.createdAt as tt_createdAt,
        tt.booking_date as tt_bookingDate,
        tt.account_id as tt_accountId,
        tt.recurring_rule_id as tt_recurringRuleId,
        t.id as t_id,
        t.name as t_name,
        t.color as t_color
      FROM tag_turnover tt
      LEFT JOIN tag t ON tt.tagId = t.id
      WHERE tt.turnoverId IN ($placeholders)
      ORDER BY tt.amountValue DESC
      ''', turnoverIds);

    // Group tag turnovers by turnover ID
    final tagTurnoversByTurnoverId = <String, List<TagTurnoverWithTag>>{};
    for (final map in tagTurnoverMaps) {
      final turnoverId = map['tt_turnoverId'] as String?;
      if (turnoverId == null) continue;

      final tagTurnover = TagTurnover(
        id: UuidValue.fromString(map['tt_id'] as String),
        turnoverId: UuidValue.fromString(turnoverId),
        tagId: UuidValue.fromString(map['tt_tagId'] as String),
        amountValue:
            (Decimal.fromInt(map['tt_amountValue'] as int) /
                    Decimal.fromInt(scaleFactor))
                .toDecimal(),
        amountUnit: map['tt_amountUnit'] as String,
        note: map['tt_note'] as String?,
        createdAt: DateTime.parse(map['tt_createdAt'] as String),
        bookingDate: DateTime.parse(map['tt_bookingDate'] as String),
        accountId: UuidValue.fromString(map['tt_accountId'] as String),
        recurringRuleId: map['tt_recurringRuleId'] != null
            ? UuidValue.fromString(map['tt_recurringRuleId'] as String)
            : null,
      );

      final tag = Tag(
        id: map['t_id'] != null
            ? UuidValue.fromString(map['t_id'] as String)
            : null,
        name: map['t_name'] as String? ?? 'Unknown',
        color: map['t_color'] as String?,
      );

      final tagTurnoverWithTag = TagTurnoverWithTag(
        tagTurnover: tagTurnover,
        tag: tag,
      );

      tagTurnoversByTurnoverId
          .putIfAbsent(turnoverId, () => [])
          .add(tagTurnoverWithTag);
    }

    // Combine turnovers with their tag turnovers
    return turnovers.map((turnover) {
      final turnoverId = turnover.id.uuid;
      return TurnoverWithTags(
        turnover: turnover,
        tagTurnovers: tagTurnoversByTurnoverId[turnoverId] ?? [],
      );
    }).toList();
  }
}
