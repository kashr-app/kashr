import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover.dart';
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
    if (turnovers.isEmpty || tag.id == null) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds = turnovers
        .where((t) => t.id != null)
        .map((t) => t.id!.uuid)
        .toList();

    if (turnoverIds.isEmpty) return;

    // Fetch all existing tag turnovers for these turnovers in one query
    final placeholders = List.generate(
      turnoverIds.length,
      (_) => '?',
    ).join(',');
    final existingTagTurnovers = await db.rawQuery('''
      SELECT turnoverId, SUM(amountValue) as total
      FROM tag_turnover
      WHERE turnoverId IN ($placeholders)
      GROUP BY turnoverId
      ''', turnoverIds);

    // Build a map of turnover ID to allocated amount
    final allocatedByTurnover = <String, Decimal>{};
    for (final row in existingTagTurnovers) {
      final turnoverId = row['turnoverId'] as String;
      allocatedByTurnover[turnoverId] = _unscale(row['total']);
    }

    // Create batch insert
    final batch = db.batch();

    for (final turnover in turnovers) {
      if (turnover.id == null) continue;

      final allocatedAmount =
          allocatedByTurnover[turnover.id!.uuid] ?? Decimal.zero;
      final remainingAmount = turnover.amountValue - allocatedAmount;

      // Only create if there's remaining amount to allocate
      if (remainingAmount != Decimal.zero) {
        final tagTurnover = TagTurnover(
          id: const Uuid().v4obj(),
          turnoverId: turnover.id!,
          tagId: tag.id!,
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
    if (turnovers.isEmpty || tag.id == null) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds = turnovers
        .where((t) => t.id != null)
        .map((t) => t.id!.uuid)
        .toList();

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
      WHERE tagId = ? AND turnoverId IN ($placeholders)
      ''',
      [tag.id!.uuid, ...turnoverIds],
    );
  }

  Future<List<TagTurnover>> getByTurnover(UuidValue turnoverId) async {
    final db = await DatabaseHelper().database;

    final maps = await db.query(
      'tag_turnover',
      where: 'turnoverId = ?',
      whereArgs: [turnoverId.uuid],
    );

    return maps.map((e) => TagTurnover.fromJson(e)).toList();
  }

  Future<List<TagTurnover>> getByTag(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    final maps = await db.query(
      'tag_turnover',
      where: 'tagId = ?',
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

    final whereClauses = ['turnoverId IS NULL'];
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
      {'turnoverId': turnoverId.uuid},
      where: 'id = ?',
      whereArgs: [tagTurnoverId.uuid],
    );
  }

  /// Unlink a matched TagTurnover from its Turnover
  Future<int> unlinkFromTurnover(UuidValue tagTurnoverId) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'turnoverId': null},
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
      whereArgs: [tagTurnover.id?.uuid],
    );
  }

  Future<int> deleteTagTurnover(UuidValue id) async {
    final db = await DatabaseHelper().database;

    return db.delete('tag_turnover', where: 'id = ?', whereArgs: [id.uuid]);
  }

  Future<int> deleteAllForTurnover(UuidValue turnoverId) async {
    final db = await DatabaseHelper().database;

    return db.delete(
      'tag_turnover',
      where: 'turnoverId = ?',
      whereArgs: [turnoverId.uuid],
    );
  }

  Future<int> updateAmount(UuidValue id, Decimal amountValue) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'amountValue': amountValue.toString()},
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }

  Future<Decimal> sumByTag(UuidValue tagId) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amountValue) AS total
      FROM tag_turnover
      WHERE tagId = ?
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
      SELECT SUM(amountValue) AS total
      FROM tag_turnover
      WHERE tagId = ? AND account_id = ?
    ''',
      [tagId.uuid, accountId.uuid],
    );

    return _unscale(result.first['total']);
  }

  /// Fetches tag summaries for a specific month and year.
  /// Returns a list of TagSummary objects containing tag info and total amount.
  Future<List<TagSummary>> getTagSummariesForMonth({
    required int year,
    required int month,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(DateTime(year, month));
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        SUM(tt.amountValue) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      INNER JOIN turnover tv ON tt.turnoverId = tv.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnoverId IS NOT NULL
      GROUP BY t.id, t.name, t.color
      ORDER BY total_amount DESC
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.map((map) {
      final tag = Tag(
        id: UuidValue.fromString(map['tag_id'] as String),
        name: map['tag_name'] as String,
        color: map['tag_color'] as String?,
      );

      final totalAmount = _unscale(map['total_amount']);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches income tag summaries (positive turnovers only) for a month.
  /// Excludes transfer tags (semantic = 'transfer').
  Future<List<TagSummary>> getIncomeTagSummariesForMonth({
    required int year,
    required int month,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(DateTime(year, month));
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        SUM(tt.amountValue) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      INNER JOIN turnover tv ON tt.turnoverId = tv.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnoverId IS NOT NULL
        AND tv.amountValue > 0
        AND t.semantic IS NULL
      GROUP BY t.id, t.name, t.color
      ORDER BY total_amount DESC
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.map((map) {
      final tag = Tag(
        id: UuidValue.fromString(map['tag_id'] as String),
        name: map['tag_name'] as String,
        color: map['tag_color'] as String?,
      );

      final totalAmount = _unscale(map['total_amount']);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches expense tag summaries (negative turnovers only) for a month.
  /// Excludes transfer tags (semantic = 'transfer').
  Future<List<TagSummary>> getExpenseTagSummariesForMonth({
    required int year,
    required int month,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(DateTime(year, month));
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        SUM(tt.amountValue) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      INNER JOIN turnover tv ON tt.turnoverId = tv.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnoverId IS NOT NULL
        AND tv.amountValue < 0
        AND t.semantic IS NULL
      GROUP BY t.id, t.name, t.color
      ORDER BY total_amount ASC
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.map((map) {
      final tag = Tag(
        id: UuidValue.fromString(map['tag_id'] as String),
        name: map['tag_name'] as String,
        color: map['tag_color'] as String?,
      );

      final totalAmount = _unscale(map['total_amount']);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches transfer tag summaries for a month.
  /// Only includes tags with semantic = 'transfer'.
  Future<List<TagSummary>> getTransferTagSummariesForMonth({
    required int year,
    required int month,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(DateTime(year, month));
    final endDate = startDate.add(months: 1);

    final result = await db.rawQuery(
      '''
      SELECT
        t.id as tag_id,
        t.name as tag_name,
        t.color as tag_color,
        t.semantic as tag_semantic,
        SUM(tt.amountValue) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnoverId IS NOT NULL
        AND t.semantic = 'transfer'
      GROUP BY t.id, t.name, t.color, t.semantic
      ORDER BY total_amount DESC
      ''',
      [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
    );

    return result.map((map) {
      final tag = Tag(
        id: UuidValue.fromString(map['tag_id'] as String),
        name: map['tag_name'] as String,
        color: map['tag_color'] as String?,
        semantic: map['tag_semantic'] == 'transfer'
            ? TagSemantic.transfer
            : null,
      );

      final totalAmount = _unscale(map['total_amount']);

      return TagSummary(tag: tag, totalAmount: totalAmount);
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
        SUM(tt.amountValue) as total_amount
      FROM tag_turnover tt
      INNER JOIN tag t ON tt.tagId = t.id
      INNER JOIN turnover tv ON tt.turnoverId = tv.id
      WHERE tt.booking_date >= ? AND tt.booking_date < ?
        AND tt.turnoverId IS NOT NULL
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
      final month = map['month'] as String;
      final tag = Tag(
        id: UuidValue.fromString(map['tag_id'] as String),
        name: map['tag_name'] as String,
        color: map['tag_color'] as String?,
      );

      final totalAmount = _unscale(map['total_amount']);

      final summary = TagSummary(tag: tag, totalAmount: totalAmount);

      summariesByMonth.putIfAbsent(month, () => []).add(summary);
    }

    return summariesByMonth;
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
      WHERE tagId = ?
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
  final Tag tag;
  final Decimal totalAmount;

  TagSummary({required this.tag, required this.totalAmount});
}
