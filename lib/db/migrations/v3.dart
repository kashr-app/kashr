import 'package:sqflite/sqflite.dart';

Future<void> v3(Database db) async {
  // Add createdAt column to tag_turnover table
  // SQLite doesn't support non-constant defaults in ALTER TABLE,
  // so we add it as nullable first, then update existing rows
  await db.execute('''
    ALTER TABLE tag_turnover
    ADD COLUMN createdAt TEXT
  ''');

  // Set a default timestamp for all existing rows
  // Use a historical date to indicate these are legacy records
  await db.execute('''
    UPDATE tag_turnover
    SET createdAt = datetime('now')
    WHERE createdAt IS NULL
  ''');
}
