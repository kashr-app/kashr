import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:jiffy/jiffy.dart';
import 'package:uuid/uuid.dart';

class TagTurnoverRepository {
  Future<int> createTagTurnover(TagTurnover tagTurnover) async {
    final db = await DatabaseHelper().database;
    return await db.insert('tag_turnover', tagTurnover.toJson());
  }

  Future<void> createTagTurnoversBatch(List<TagTurnover> tagTurnovers) async {
    final db = await DatabaseHelper().database;

    final batch = db.batch();
    for (var tag in tagTurnovers) {
      batch.insert('tag_turnover', tag.toJson());
    }
    await batch.commit(noResult: true);
  }

  /// Batch adds a tag to multiple turnovers.
  /// For each turnover, allocates the remaining unallocated amount to the tag.
  /// This is done efficiently in a single database transaction to avoid N+1.
  Future<void> batchAddTagToTurnovers(List<Turnover> turnovers, Tag tag) async {
    if (turnovers.isEmpty) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds = turnovers.map((t) => t.id.uuid).toList();

    if (turnoverIds.isEmpty) return;

    // Fetch all existing tag turnovers for these turnovers in one query
    final placeholders = List.generate(
      turnoverIds.length,
      (_) => '?',
    ).join(',');
    final existingTagTurnovers = await db.rawQuery('''
      SELECT turnover_id, SUM(amount_value) as total
      FROM tag_turnover
      WHERE turnover_id IN ($placeholders)
      GROUP BY turnover_id
      ''', turnoverIds);

    // Build a map of turnover ID to allocated amount
    final allocatedByTurnover = <String, Decimal>{};
    for (final row in existingTagTurnovers) {
      final turnoverId = row['turnover_id'] as String;
      allocatedByTurnover[turnoverId] = _unscale(row['total']);
    }

    // Create batch insert
    final batch = db.batch();

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
          note: null,
          createdAt: DateTime.now(),
          bookingDate: turnover.bookingDate ?? DateTime.now(),
          accountId: turnover.accountId,
        );

        batch.insert('tag_turnover', tagTurnover.toJson());
      }
    }

    await batch.commit(noResult: true);
  }

  /// Batch removes a tag from multiple turnovers.
  /// Deletes all tag_turnover entries for the specified tag across
  /// the given turnovers. This is done efficiently in a single
  /// database transaction.
  Future<void> batchRemoveTagFromTurnovers(
    List<Turnover> turnovers,
    Tag tag,
  ) async {
    if (turnovers.isEmpty) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds = turnovers.map((t) => t.id.uuid).toList();

    if (turnoverIds.isEmpty) return;

    // Build the SQL query with placeholders
    final placeholders = List.generate(
      turnoverIds.length,
      (_) => '?',
    ).join(',');

    // Delete all tag_turnover entries for this tag and these turnovers
    await db.rawDelete(
      '''
      DELETE FROM tag_turnover
      WHERE tag_id = ? AND turnover_id IN ($placeholders)
      ''',
      [tag.id.uuid, ...turnoverIds],
    );
  }

  Future<List<TagTurnover>> getByTurnover(UuidValue turnoverId) async {
    final db = await DatabaseHelper().database;

    final maps = await db.query(
      'tag_turnover',
      where: 'turnover_id = ?',
      whereArgs: [turnoverId.uuid],
    );

    return maps.map((e) => TagTurnover.fromJson(e)).toList();
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

  /// Link an unmatched TagTurnover to a Turnover (confirm match)
  Future<int> linkToTurnover(
    UuidValue tagTurnoverId,
    UuidValue turnoverId,
  ) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'turnover_id': turnoverId.uuid},
      where: 'id = ?',
      whereArgs: [tagTurnoverId.uuid],
    );
  }

  /// Unlink a matched TagTurnover from its Turnover
  Future<int> unlinkFromTurnover(UuidValue tagTurnoverId) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'turnover_id': null},
      where: 'id = ?',
      whereArgs: [tagTurnoverId.uuid],
    );
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

  Future<int> updateTagTurnover(TagTurnover tagTurnover) async {
    final db = await DatabaseHelper().database;

    return db.update(
      'tag_turnover',
      tagTurnover.toJson(),
      where: 'id = ?',
      whereArgs: [tagTurnover.id.uuid],
    );
  }

  Future<int> deleteTagTurnover(UuidValue id) async {
    final db = await DatabaseHelper().database;

    return db.delete('tag_turnover', where: 'id = ?', whereArgs: [id.uuid]);
  }

  Future<int> deleteAllByTagId(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    return db.delete(
      'tag_turnover',
      where: 'tag_id = ?',
      whereArgs: [tagId.uuid],
    );
  }

  Future<int> deleteAllForTurnover(UuidValue turnoverId) async {
    final db = await DatabaseHelper().database;

    return db.delete(
      'tag_turnover',
      where: 'turnover_id = ?',
      whereArgs: [turnoverId.uuid],
    );
  }

  Future<int> updateAmount(UuidValue id, Decimal amountValue) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'amount_value': amountValue.toString()},
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }

  Future<int> updateTagByTagId(UuidValue oldTagId, UuidValue newTagId) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'tag_id': newTagId.uuid},
      where: 'tag_id = ?',
      whereArgs: [oldTagId.uuid],
    );
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

  /// Fetches transfer tag summaries for a month.
  /// Only includes tags with semantic = 'transfer'.
  Future<Map<TurnoverSign, List<TagSummary>>> getTransferTagSummariesForMonth(
    YearMonth yearMonth,
  ) async {
    return {
      TurnoverSign.income: await getTagSummariesForMonth(
        yearMonth,
        TurnoverSign.income,
        semantic: TagSemantic.transfer,
      ),
      TurnoverSign.expense: await getTagSummariesForMonth(
        yearMonth,
        TurnoverSign.expense,
        semantic: TagSemantic.transfer,
      ),
    };
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
  getTagTurnoversForMonthlyDashboard({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
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
