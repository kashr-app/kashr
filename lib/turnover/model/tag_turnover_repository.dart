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
