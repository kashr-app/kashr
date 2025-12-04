import 'package:finanalyzer/backup/model/backup_config.dart';
import 'package:finanalyzer/db/migrations/helpers.dart';
import 'package:sqflite/sqflite.dart';

// Renames all camelCase columns to snake_case and removes some unnecessary things like
// unused DEFAULT values or irrelevant indices.
Future<void> v10(Database db) async {
  await db.execute('PRAGMA foreign_keys = OFF');
  await db.transaction((txn) async {
    await _accounts(txn);
    await _backupConfig(txn);
    await _savings(txn);
    await _tag(txn);
    await _tagTurnover(txn);
    await _turnover(txn);
  });
  await db.execute('PRAGMA foreign_keys = ON');
}

Future<void> _accounts(Transaction txn) async {
  // drop irrelevant indices
  await txn.execute('DROP INDEX idx_account_type');
  await txn.execute('DROP INDEX idx_account_hidden');

  // * renamed camelCase columns to snake_case
  // * removed DEFAULTs
  // * added NOT NULLs
  await txn.execute('''
    CREATE TABLE account_new(
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      name TEXT NOT NULL,
      identifier TEXT,
      api_id TEXT,
      account_type TEXT NOT NULL,
      sync_source TEXT,
      currency TEXT NOT NULL,
      opening_balance INTEGER NOT NULL,
      opening_balance_date TEXT NOT NULL,
      is_hidden INTEGER NOT NULL
    )
  ''');

  await copyDataForSameColumnCount(
    txn,
    from: 'account',
    to: 'account_new',
    columnRenames: {'createdAt': 'created_at', 'apiId': 'api_id'},
  );
  await replaceTable(txn, replaced: 'account', replacement: 'account_new');
}

Future<void> _backupConfig(Transaction txn) async {
  await txn.execute('DROP TABLE backup_config');
  // * store DateTime as TEXT
  // * remove defaults
  await txn.execute('''
    CREATE TABLE backup_config (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      auto_backup_enabled INTEGER NOT NULL,
      frequency TEXT NOT NULL,
      last_auto_backup TEXT,
      encryption_enabled INTEGER NOT NULL,
      max_local_backups INTEGER NOT NULL,
      auto_backup_to_cloud INTEGER NOT NULL
    )
  ''');
  await txn.insert('backup_config', BackupConfig.defaultConfig().toJson());
}

Future<void> _savings(Transaction txn) async {
  // We dont need this index because it is assumed that there are only few savings
  await txn.execute('DROP INDEX idx_savings_tag_id');

  // * store DateTime as TEXT
  // * remove defaults
  await txn.execute('''
    CREATE TABLE savings_new (
      id TEXT PRIMARY KEY,
      tag_id TEXT NOT NULL UNIQUE,
      goal_value INTEGER,
      goal_unit TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(tag_id) REFERENCES tag(id) ON DELETE CASCADE
    )
  ''');
  await copyDataForSameColumnCount(
    txn,
    from: 'savings',
    to: 'savings_new',
    columnRenames: {},
  );
  await replaceTable(txn, replaced: 'savings', replacement: 'savings_new');

  // await txn.execute('''
  //   CREATE TABLE savings_virtual_booking (
  //     id TEXT PRIMARY KEY,
  //     savings_id TEXT NOT NULL,
  //     account_id TEXT NOT NULL,
  //     amount_value INTEGER NOT NULL,
  //     amount_unit TEXT NOT NULL,
  //     note TEXT, booking_date TEXT NOT NULL,
  //     created_at TEXT NOT NULL,
  //     FOREIGN KEY(savings_id) REFERENCES savings(id) ON DELETE CASCADE,
  //     FOREIGN KEY(account_id) REFERENCES account(id) ON DELETE CASCADE
  //   )
  // ''');

  // These indices remain
  // CREATE INDEX idx_savings_virtual_booking_account_id ON savings_virtual_booking(account_id)
  // CREATE INDEX idx_savings_virtual_booking_savings_id ON savings_virtual_booking(savings_id)
}

Future<void> _tag(Transaction txn) async {
  // add NOT NULL to name
  await txn.execute('''
    CREATE TABLE tag_new (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      color TEXT,
      semantic TEXT
    )
  ''');
  await copyDataForSameColumnCount(
    txn,
    from: 'tag',
    to: 'tag_new',
    columnRenames: {},
  );
  await replaceTable(txn, replaced: 'tag', replacement: 'tag_new');
}

Future<void> _tagTurnover(Transaction txn) async {
  // need to recreate this index, because we will rename its referred column name
  await txn.execute('DROP INDEX idx_tag_turnover_unmatched');

  // rename camelCase to snake_case
  // booking_date remove default
  // account_id remove default
  await txn.execute('''
    CREATE TABLE "tag_turnover_new"(
      id TEXT PRIMARY KEY,
      turnover_id TEXT,
      tag_id TEXT NOT NULL,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      note TEXT,
      created_at TEXT NOT NULL,
      booking_date TEXT NOT NULL,
      account_id TEXT NOT NULL,
      recurring_rule_id TEXT,
      FOREIGN KEY(turnover_id) REFERENCES turnover(id),
      FOREIGN KEY(tag_id) REFERENCES tag(id)
    )
  ''');

  await copyDataForSameColumnCount(
    txn,
    from: 'tag_turnover',
    to: 'tag_turnover_new',
    columnRenames: {
      'tagId': 'tag_id',
      'turnoverId': 'turnover_id',
      'amountValue': 'amount_value',
      'amountUnit': 'amount_unit',
      'createdAt': 'created_at',
    },
  );
  await replaceTable(
    txn,
    replaced: 'tag_turnover',
    replacement: 'tag_turnover_new',
  );

  // recreate index that we removed before because of it referencing a renamed column
  await txn.execute('''
    CREATE INDEX idx_tag_turnover_unmatched
      ON tag_turnover(turnover_id)
      WHERE turnover_id IS NULL
  ''');

  // These indices remain:
  // CREATE INDEX idx_tag_turnover_account ON tag_turnover(account_id)
  // CREATE INDEX idx_tag_turnover_booking_date ON tag_turnover(booking_date)
  // CREATE INDEX idx_tag_turnover_unmatched ON tag_turnover(turnover_id) WHERE turnover_id IS NULL
}

Future<void> _turnover(Transaction txn) async {
  await txn.execute('''
    CREATE TABLE turnover_new(
      id TEXT PRIMARY KEY,
      created_at TEXT NOT NULL,
      account_id TEXT NOT NULL,
      booking_date TEXT,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      counter_part TEXT,
      purpose TEXT NOT NULL,
      api_id TEXT,
      FOREIGN KEY(account_id) REFERENCES account(id)
    )
  ''');

  await copyDataForSameColumnCount(
    txn,
    from: 'turnover',
    to: 'turnover_new',
    columnRenames: {
      'createdAt': 'created_at',
      'accountId': 'account_id',
      'bookingDate': 'booking_date',
      'amountValue': 'amount_value',
      'amountUnit': 'amount_unit',
      'counterPart': 'counter_part',
      'apiId': 'api_id',
    },
  );
  await replaceTable(txn, replaced: 'turnover', replacement: 'turnover_new');
}
