import 'package:sqflite/sqflite.dart';

Future<void> v2(Database db) async {
  await db.execute('''
      CREATE TABLE tag(
        id TEXT PRIMARY KEY,
        color TEXT,
        name TEXT
      );
    ''');

  await db.execute('''
      CREATE TABLE tag_turnover(
        id TEXT PRIMARY KEY,
        turnoverId TEXT,
        tagId TEXT NOT NULL,
        amountValue INTEGER NOT NULL,
        amountUnit TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY(turnoverId) REFERENCES turnover(id),
        FOREIGN KEY(tagId) REFERENCES tag(id)
      );
    ''');
}
