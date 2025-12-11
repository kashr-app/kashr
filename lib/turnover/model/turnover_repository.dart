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

  Future<List<Turnover>> getTurnoversByApiIds(List<UuidValue> apiIds) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'turnover',
      where: 'api_id IN (${List.filled(apiIds.length, '?').join(',')})',
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
      where: 'booking_date >= ? AND booking_date < ?',
      whereArgs: [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
      orderBy: 'booking_date DESC',
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
      SELECT account_id, api_id
      FROM turnover
      WHERE api_id IN ($placeholders)
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
          'account_id = ? AND api_id IN (${List.filled(apiIds.length, '?').join(',')})',
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
      LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
      WHERE t.booking_date >= ? AND t.booking_date < ?
      GROUP BY t.id
      HAVING
        COUNT(tt.id) = 0 OR
        COALESCE(SUM(tt.amount_value), 0) != t.amount_value
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
  Future<List<TurnoverWithTags>> getUnallocatedTurnoversForMonth(
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
        tt.turnover_id as tt_turnover_id,
        tt.tag_id as tt_tag_id,
        tt.amount_value as tt_amount_value,
        tt.amount_unit as tt_amount_unit,
        tt.note as tt_note,
        tt.created_at as tt_created_at,
        tt.booking_date as tt_booking_date,
        tt.account_id as tt_account_id,
        tt.recurring_rule_id as tt_recurring_rule_id,
        t.id as t_id,
        t.name as t_name,
        t.color as t_color
      FROM tag_turnover tt
      LEFT JOIN tag t ON tt.tag_id = t.id
      WHERE tt.turnover_id IN ($placeholders)
      ORDER BY tt.amount_value DESC
      ''', turnoverIds);

    // Group tag turnovers by turnover ID
    final tagTurnoversByTurnoverId = <String, List<TagTurnoverWithTag>>{};
    for (final map in tagTurnoverMaps) {
      final turnoverId = map['tt_turnover_id'] as String?;
      if (turnoverId == null) continue;

      final tagTurnover = TagTurnover(
        id: UuidValue.fromString(map['tt_id'] as String),
        turnoverId: UuidValue.fromString(turnoverId),
        tagId: UuidValue.fromString(map['tt_tag_id'] as String),
        amountValue:
            (Decimal.fromInt(map['tt_amount_value'] as int) /
                    Decimal.fromInt(100))
                .toDecimal(),
        amountUnit: map['tt_amount_unit'] as String,
        note: map['tt_note'] as String?,
        createdAt: DateTime.parse(map['tt_created_at'] as String),
        bookingDate: DateTime.parse(map['tt_booking_date'] as String),
        accountId: UuidValue.fromString(map['tt_account_id'] as String),
        recurringRuleId: map['tt_recurring_rule_id'] != null
            ? UuidValue.fromString(map['tt_recurring_rule_id'] as String)
            : null,
      );

      final tag = Tag(
        id: UuidValue.fromString(map['t_id'] as String),
        name: map['t_name'] as String,
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

    final whereClauses = ['account_id = ?'];
    final whereArgs = <Object>[accountId.uuid];

    if (startDateInclusive != null) {
      whereClauses.add('booking_date >= ?');
      whereArgs.add(
        Jiffy.parseFromDateTime(
          startDateInclusive,
        ).format(pattern: isoDateFormat),
      );
    }

    if (endDateInclusive != null) {
      whereClauses.add('booking_date <= ?');
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
      orderBy: 'booking_date ${direction.name}',
      limit: limit,
    );

    return maps.map((e) => Turnover.fromJson(e)).toList();
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
    final placeholders = List.filled(turnoverIds.length, '?').join(', ');
    final args = turnoverIds.map((id) => id.uuid).toList();

    final maps = await db.rawQuery(
      '''
      SELECT t.id
      FROM turnover t
      LEFT JOIN tag_turnover tt ON t.id = tt.turnover_id
      WHERE t.id IN ($placeholders)
      GROUP BY t.id
      HAVING COUNT(tt.id) = 0
      ''',
      [args],
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
      whereClauses.add('t.booking_date >= ? AND t.booking_date < ?');
      whereArgs.add(startDate.format(pattern: isoDateFormat));
      whereArgs.add(endDate.format(pattern: isoDateFormat));
    }

    // Sign filter - filter by income (positive) or expense (negative)
    if (filter.sign != null) {
      switch (filter.sign!) {
        case TurnoverSign.income:
          whereClauses.add('t.amount_value > 0');
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
      whereArgs.add(_sanitizeFts5Query(filter.searchQuery!));
    }

    // Tag filter - turnovers must have ALL specified tags
    if (filter.tagIds != null && filter.tagIds!.isNotEmpty) {
      // For each tag, ensure the turnover has a tag_turnover entry with that tagId
      for (final tagId in filter.tagIds!) {
        whereClauses.add('''
          EXISTS (
            SELECT 1 FROM tag_turnover tt_filter
            WHERE tt_filter.turnover_id = t.id AND tt_filter.tag_id = ?
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
          ? 'ABS(t.amount_value) DESC, t.booking_date DESC NULLS FIRST'
          : sort.toSqlOrderBy();

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
        tt.turnover_id as tt_turnover_id,
        tt.tag_id as tt_tag_id,
        tt.amount_value as tt_amount_value,
        tt.amount_unit as tt_amount_unit,
        tt.note as tt_note,
        tt.created_at as tt_created_at,
        tt.booking_date as tt_booking_date,
        tt.account_id as tt_account_id,
        tt.recurring_rule_id as tt_recurring_rule_id,
        t.id as t_id,
        t.name as t_name,
        t.color as t_color
      FROM tag_turnover tt
      LEFT JOIN tag t ON tt.tag_id = t.id
      WHERE tt.turnover_id IN ($placeholders)
      ORDER BY tt.amount_value DESC
      ''', turnoverIds);

    // Group tag turnovers by turnover ID
    final tagTurnoversByTurnoverId = <String, List<TagTurnoverWithTag>>{};
    for (final map in tagTurnoverMaps) {
      final turnoverId = map['tt_turnover_id'] as String?;
      if (turnoverId == null) continue;

      final tagTurnover = TagTurnover(
        id: UuidValue.fromString(map['tt_id'] as String),
        turnoverId: UuidValue.fromString(turnoverId),
        tagId: UuidValue.fromString(map['tt_tag_id'] as String),
        amountValue:
            (Decimal.fromInt(map['tt_amount_value'] as int) /
                    Decimal.fromInt(100))
                .toDecimal(),
        amountUnit: map['tt_amount_unit'] as String,
        note: map['tt_note'] as String?,
        createdAt: DateTime.parse(map['tt_created_at'] as String),
        bookingDate: DateTime.parse(map['tt_booking_date'] as String),
        accountId: UuidValue.fromString(map['tt_account_id'] as String),
        recurringRuleId: map['tt_recurring_rule_id'] != null
            ? UuidValue.fromString(map['tt_recurring_rule_id'] as String)
            : null,
      );

      final tag = Tag(
        id: UuidValue.fromString(map['t_id'] as String),
        name: map['t_name'] as String,
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

  /// Sanitizes a user input string for use with SQLite FTS5 MATCH queries.
  ///
  /// This function escapes all user input as literal text, with the exception
  /// of a single trailing `*` which enables prefix search (e.g., "foo*" matches
  /// "food", "football", etc.).
  ///
  /// All tokens are quoted to prevent FTS5 syntax interpretation. Internal
  /// quotes are escaped by doubling them per FTS5 convention.
  String _sanitizeFts5Query(String query) {
    if (query.trim().isEmpty) return query;

    final tokens = <String>[];

    for (var token in query.split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;

      // Check if token has a trailing asterisk (prefix search)
      final hasTrailingStar = token.endsWith('*');

      // Remove trailing asterisk for escaping
      final tokenWithoutStar = hasTrailingStar
          ? token.substring(0, token.length - 1)
          : token;

      if (tokenWithoutStar.isEmpty) continue;

      // Escape internal quotes by doubling them (FTS5 convention)
      final escaped = tokenWithoutStar.replaceAll('"', '""');

      // Quote the token, add trailing * outside quotes if needed
      tokens.add(hasTrailingStar ? '"$escaped"*' : '"$escaped"');
    }

    return tokens.join(' ');
  }
}
