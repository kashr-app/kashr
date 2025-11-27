import 'package:sqflite/sqflite.dart';

Future<void> v6(Database db) async {
  // Add new columns to tag_turnover
  await db.execute('''
    ALTER TABLE tag_turnover ADD COLUMN booking_date TEXT NOT NULL DEFAULT '2025-01-01'
  ''');

  await db.execute('''
    ALTER TABLE tag_turnover ADD COLUMN account_id TEXT NOT NULL DEFAULT ''
  ''');

  await db.execute('''
    ALTER TABLE tag_turnover ADD COLUMN recurring_rule_id TEXT
  ''');

  // Backfill bookingDate from Turnover for existing TagTurnovers
  await db.execute('''
    UPDATE tag_turnover
    SET booking_date = (
      SELECT t.bookingDate
      FROM turnover t
      WHERE t.id = tag_turnover.turnoverId
    )
    WHERE turnoverId IS NOT NULL
  ''');

  // Backfill accountId from Turnover
  await db.execute('''
    UPDATE tag_turnover
    SET account_id = (
      SELECT t.accountId
      FROM turnover t
      WHERE t.id = tag_turnover.turnoverId
    )
    WHERE turnoverId IS NOT NULL
  ''');

  // Create indexes for efficient querying
  await db.execute('''
    CREATE INDEX idx_tag_turnover_unmatched ON tag_turnover(turnoverId)
    WHERE turnoverId IS NULL
  ''');

  await db.execute('''
    CREATE INDEX idx_tag_turnover_account ON tag_turnover(account_id)
  ''');

  await db.execute('''
    CREATE INDEX idx_tag_turnover_booking_date ON tag_turnover(booking_date)
  ''');
}
