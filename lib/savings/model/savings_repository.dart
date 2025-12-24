import 'package:kashr/db/db_helper.dart';
import 'package:kashr/savings/model/savings.dart';
import 'package:uuid/uuid.dart';

class SavingsRepository {
  Future<int> create(Savings savings) async {
    final db = await DatabaseHelper().database;
    return await db.insert('savings', savings.toJson());
  }

  Future<Savings?> getById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    if (maps.isNotEmpty) {
      return Savings.fromJson(maps.first);
    }
    return null;
  }

  Future<Savings?> getByTagId(UuidValue tagId) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings',
      where: 'tag_id = ?',
      whereArgs: [tagId.uuid],
    );

    if (maps.isNotEmpty) {
      return Savings.fromJson(maps.first);
    }
    return null;
  }

  Future<List<Savings>> getAll() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('savings', orderBy: 'created_at DESC');
    return maps.map((e) => Savings.fromJson(e)).toList();
  }

  Future<int> update(Savings savings) async {
    final db = await DatabaseHelper().database;
    return await db.update(
      'savings',
      savings.toJson(),
      where: 'id = ?',
      whereArgs: [savings.id.uuid],
    );
  }

  Future<int> delete(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return await db.delete(
      'savings',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }

  /// Updates the tag_id reference for a savings entry.
  ///
  /// Used during tag merge to transfer savings from one tag to another.
  Future<int> updateTagId(UuidValue oldTagId, UuidValue newTagId) async {
    final db = await DatabaseHelper().database;
    return await db.update(
      'savings',
      {'tag_id': newTagId.uuid},
      where: 'tag_id = ?',
      whereArgs: [oldTagId.uuid],
    );
  }
}
