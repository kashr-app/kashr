import 'package:kashr/db/sqlite_compat.dart';

/// Migration v17: change backup frequency to interval_days and last_auto_backup to last_backup_at
///
/// Changes:
/// - `frequency TEXT NOT NULL,` to `interval_days INTEGER NOT NULL`
/// - `last_auto_backup TEXT,` to `last_backup_at TEXT`
Future<void> v17(SqliteDatabase db) async {
  // Create new table with the desired schema
  await db.execute('''
    CREATE TABLE backup_config_new (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      auto_backup_enabled INTEGER NOT NULL,
      interval_days INTEGER NOT NULL,
      last_backup_at TEXT,
      encryption_enabled INTEGER NOT NULL,
      max_local_backups INTEGER NOT NULL,
      auto_backup_to_cloud INTEGER NOT NULL
    )
  ''');

  // Copy and transform existing data
  await db.execute('''
    INSERT INTO backup_config_new (
      id,
      auto_backup_enabled,
      interval_days,
      last_backup_at,
      encryption_enabled,
      max_local_backups,
      auto_backup_to_cloud
    )
    SELECT
      id,
      auto_backup_enabled,
      CASE frequency
        WHEN 'daily' THEN 1
        WHEN 'weekly' THEN 7
        WHEN 'monthly' THEN 30
        ELSE 30
      END,
      last_auto_backup,
      encryption_enabled,
      max_local_backups,
      auto_backup_to_cloud
    FROM backup_config
  ''');

  // Replace old table
  await db.execute('DROP TABLE backup_config');
  await db.execute('ALTER TABLE backup_config_new RENAME TO backup_config');
}