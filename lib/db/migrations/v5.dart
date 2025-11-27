import 'package:sqflite/sqflite.dart';

Future<void> v5(Database db) async {
  // Add new columns to account table
  await db.execute('''
    ALTER TABLE account ADD COLUMN account_type TEXT NOT NULL DEFAULT 'checking'
  ''');

  await db.execute('''
    ALTER TABLE account ADD COLUMN sync_source TEXT
  ''');

  await db.execute('''
    ALTER TABLE account ADD COLUMN opening_balance INTEGER NOT NULL DEFAULT 0
  ''');

  await db.execute('''
    ALTER TABLE account ADD COLUMN opening_balance_date TEXT
  ''');

  await db.execute('''
    ALTER TABLE account ADD COLUMN is_hidden INTEGER DEFAULT 0
  ''');

  await db.execute('''
    ALTER TABLE account ADD COLUMN currency TEXT NOT NULL DEFAULT 'EUR'
  ''');

  // Migrate existing accounts
  await db.execute('''
    UPDATE account
    SET sync_source = 'comdirect'
    WHERE apiId IS NOT NULL
  ''');

  await db.execute('''
    UPDATE account
    SET opening_balance_date = createdAt
  ''');

  // Create indexes
  await db.execute('''
    CREATE INDEX idx_account_type ON account(account_type)
  ''');

  await db.execute('''
    CREATE INDEX idx_account_hidden ON account(is_hidden)
  ''');
}
