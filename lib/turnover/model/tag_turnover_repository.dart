import 'package:decimal/decimal.dart';
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

  /// Batch adds a tag to multiple turnovers.
  /// For each turnover, allocates the remaining unallocated amount to the tag.
  /// This is done efficiently in a single database transaction to avoid N+1.
  Future<void> batchAddTagToTurnovers(
    List<Turnover> turnovers,
    Tag tag,
  ) async {
    if (turnovers.isEmpty || tag.id == null) return;

    final db = await DatabaseHelper().database;

    // Get all turnover IDs
    final turnoverIds =
        turnovers.where((t) => t.id != null).map((t) => t.id!.uuid).toList();

    if (turnoverIds.isEmpty) return;

    // Fetch all existing tag turnovers for these turnovers in one query
    final placeholders = List.generate(turnoverIds.length, (_) => '?').join(',');
    final existingTagTurnovers = await db.rawQuery(
      '''
      SELECT turnoverId, SUM(amountValue) as total
      FROM tag_turnover
      WHERE turnoverId IN ($placeholders)
      GROUP BY turnoverId
      ''',
      turnoverIds,
    );

    // Build a map of turnover ID to allocated amount
    final allocatedByTurnover = <String, Decimal>{};
    for (final row in existingTagTurnovers) {
      final turnoverId = row['turnoverId'] as String;
      final totalInt = row['total'] as int? ?? 0;
      allocatedByTurnover[turnoverId] = (Decimal.fromInt(totalInt) /
              Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);
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
    final turnoverIds =
        turnovers.where((t) => t.id != null).map((t) => t.id!.uuid).toList();

    if (turnoverIds.isEmpty) return;

    // Build the SQL query with placeholders
    final placeholders = List.generate(turnoverIds.length, (_) => '?').join(',');

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

  Future<List<TagTurnover>> getUnfinalizedTagTurnovers() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'tag_turnover',
      where: 'turnoverId IS NULL',
      orderBy: 'createdAt DESC',
    );
    return maps.map((e) => TagTurnover.fromJson(e)).toList();
  }

  Future<int> finalizeTagTurnover(
    UuidValue turnoverId,
    UuidValue tagTurnoverId,
  ) async {
    final db = await DatabaseHelper().database;

    return await db.update(
      'tag_turnover',
      {'turnoverId': turnoverId.uuid},
      where: 'id = ?',
      whereArgs: [tagTurnoverId.uuid],
    );
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

  Future<int> updateAmount(
    UuidValue id,
    Decimal amountValue,
  ) async {
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

    final totalString = result.first['total']?.toString();
    final total = (totalString == null)
        ? Decimal.zero
        : Decimal.parse(totalString);
    return (total / Decimal.fromInt(100)).toDecimal(
      scaleOnInfinitePrecision: 2,
    );
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
      WHERE tv.bookingDate >= ? AND tv.bookingDate < ?
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

      final totalAmountInt = map['total_amount'] as int? ?? 0;
      final totalAmount = (Decimal.fromInt(totalAmountInt) /
              Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches income tag summaries (positive turnovers only) for a month.
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
      WHERE tv.bookingDate >= ? AND tv.bookingDate < ?
        AND tv.amountValue > 0
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

      final totalAmountInt = map['total_amount'] as int? ?? 0;
      final totalAmount = (Decimal.fromInt(totalAmountInt) /
              Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }

  /// Fetches expense tag summaries (negative turnovers only) for a month.
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
      WHERE tv.bookingDate >= ? AND tv.bookingDate < ?
        AND tv.amountValue < 0
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

      final totalAmountInt = map['total_amount'] as int? ?? 0;
      final totalAmount = (Decimal.fromInt(totalAmountInt) /
              Decimal.fromInt(100))
          .toDecimal(scaleOnInfinitePrecision: 2);

      return TagSummary(tag: tag, totalAmount: totalAmount);
    }).toList();
  }
}

/// A summary of spending for a specific tag.
class TagSummary {
  final Tag tag;
  final Decimal totalAmount;

  TagSummary({required this.tag, required this.totalAmount});
}
