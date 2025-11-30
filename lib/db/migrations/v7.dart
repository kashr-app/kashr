import 'package:sqflite/sqflite.dart';

Future<void> v7(Database db) async {
  await db.execute('''
    CREATE TABLE savings (
      id TEXT PRIMARY KEY,
      tag_id TEXT NOT NULL UNIQUE,
      goal_value INTEGER,
      goal_unit TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY(tag_id) REFERENCES tag(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_savings_tag_id ON savings(tag_id)
  ''');

  await db.execute('''
    CREATE TABLE savings_virtual_booking (
      id TEXT PRIMARY KEY,
      savings_id TEXT NOT NULL,
      account_id TEXT NOT NULL,
      amount_value INTEGER NOT NULL,
      amount_unit TEXT NOT NULL,
      note TEXT,
      booking_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY(savings_id) REFERENCES savings(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES account(id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_savings_virtual_booking_savings_id
    ON savings_virtual_booking(savings_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_savings_virtual_booking_account_id
    ON savings_virtual_booking(account_id)
  ''');
}
