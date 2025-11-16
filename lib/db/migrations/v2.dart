import 'package:sqflite/sqflite.dart';

Future<void> v2(Database db) async {
  await _makeTurnoverIdNullable(db);
}

Future<void> _makeTurnoverIdNullable(Database db) async {
  await db.execute('''
      CREATE TABLE tag_turnover_new (
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

  // Copy data from old table to new table
  await db.execute('''
      INSERT INTO tag_turnover_new (id, turnoverId, tagId, amountValue, amountUnit, note)
      SELECT id, turnoverId, tagId, amountValue, amountUnit, note FROM tag_turnover;
    ''');

  await db.execute('DROP TABLE tag_turnover');

  await db.execute('ALTER TABLE tag_turnover_new RENAME TO tag_turnover');
}
