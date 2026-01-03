import 'package:kashr/db/sqlite_compat.dart';

/// Migration v15: Add performance indexes for dashboard queries
///
/// Adds missing indexes on heavily-queried columns to improve dashboard
/// load performance, particularly for monthly queries.
Future<void> v15(SqliteDatabase db) async {
  // Index on turnover.booking_date for monthly queries
  // This is critical for getTurnoversForMonth() performance
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_turnover_booking_date
      ON turnover(booking_date)
  ''');

  // Index on turnover.account_id for account-specific queries
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_turnover_account_id
      ON turnover(account_id)
  ''');

  // Composite index for turnover queries by account and date
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_turnover_account_booking
      ON turnover(account_id, booking_date)
  ''');

  // Index on tag_turnover.tag_id for tag summary queries
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tag_turnover_tag_id
      ON tag_turnover(tag_id)
  ''');

  // Index on tag_turnover.turnover_id for efficient joins
  // (there's already a partial index for WHERE turnover_id IS NULL,
  // but we need a full index for regular joins)
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tag_turnover_turnover_id
      ON tag_turnover(turnover_id)
  ''');

  // Composite index for tag_turnover queries by tag and date
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_tag_turnover_tag_booking
      ON tag_turnover(tag_id, booking_date)
  ''');
}
