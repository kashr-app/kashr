import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/model/tag.dart';
import 'package:uuid/uuid.dart';

class TagRepository {
  Future<int> createTag(Tag tag) async {
    final db = await DatabaseHelper().database;
    return await db.insert('tag', tag.toJson());
  }

  Future<Tag?> getTagById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'tag',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    if (maps.isNotEmpty) {
      return Tag.fromJson(maps.first);
    }
    return null;
  }

  Future<List<Tag>> getAllTags() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query('tag', orderBy: 'name ASC');
    return maps.map((e) => Tag.fromJson(e)).toList();
  }

  Future<int> updateTag(Tag tag) async {
    final db = await DatabaseHelper().database;
    return db.update(
      'tag',
      tag.toJson(),
      where: 'id = ?',
      whereArgs: [tag.id?.uuid],
    );
  }

  Future<int> deleteTag(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return db.delete(
      'tag',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }
}
