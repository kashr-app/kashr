import 'package:decimal/decimal.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/model/tag_turnover.dart';
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
}
