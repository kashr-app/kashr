import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/savings/model/savings.dart';
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
    return db.update(
      'savings',
      savings.toJson(),
      where: 'id = ?',
      whereArgs: [savings.id?.uuid],
    );
  }

  Future<int> delete(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return db.delete(
      'savings',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }
}
