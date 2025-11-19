import 'package:sqflite/sqflite.dart';

Future<void> v4(Database db) async {
  // Make createdAt column NOT NULL in tag_turnover table
  // SQLite doesn't support ALTER COLUMN, so we need to recreate the table

  // Create new table with NOT NULL constraint
  await db.execute('''
    CREATE TABLE tag_turnover_new(
      id TEXT PRIMARY KEY,
      turnoverId TEXT,
      tagId TEXT NOT NULL,
      amountValue INTEGER NOT NULL,
      amountUnit TEXT NOT NULL,
      note TEXT,
      createdAt TEXT NOT NULL,
      FOREIGN KEY(turnoverId) REFERENCES turnover(id),
      FOREIGN KEY(tagId) REFERENCES tag(id)
    )
  ''');

  // Copy data from old table to new table
  await db.execute('''
    INSERT INTO tag_turnover_new
    SELECT id, turnoverId, tagId, amountValue, amountUnit, note, createdAt
    FROM tag_turnover
  ''');

  await db.execute('DROP TABLE tag_turnover');
  await db.execute('ALTER TABLE tag_turnover_new RENAME TO tag_turnover');
}
