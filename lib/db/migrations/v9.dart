import 'package:sqflite/sqflite.dart';

Future<void> v9(Database db) async {
  // Create backup_config table (singleton)
  await db.execute('''
    CREATE TABLE IF NOT EXISTS backup_config (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      auto_backup_enabled INTEGER NOT NULL DEFAULT 0,
      backup_frequency TEXT NOT NULL DEFAULT 'weekly',
      last_auto_backup INTEGER,
      encryption_enabled INTEGER NOT NULL DEFAULT 0,
      max_local_backups INTEGER NOT NULL DEFAULT 5,
      auto_backup_to_cloud INTEGER NOT NULL DEFAULT 0
    )
  ''');

  // Initialize default config
  await db.execute('''
    INSERT INTO backup_config (id) VALUES (1)
  ''');
}
