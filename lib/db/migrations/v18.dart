import 'package:kashr/db/sqlite_compat.dart';

/// Migration v18: Split `last_sync_date` into a download cursor and a manual
/// balance check timestamp.
///
/// `last_sync_date` carried two meanings depending on the account kind: for
/// downloaded accounts it was stamped whenever the balance was reconciled (and
/// even at account discovery, which made "never downloaded" inexpressible),
/// for manual accounts it recorded when the user last checked the balance.
///
/// Changes:
/// - Adds `download_cursor_date TEXT` ("booked transactions are complete
///   through this booking date", downloaded accounts only)
/// - Adds `last_manual_sync_at TEXT` ("the user reconciled this balance at
///   this moment", manual accounts only)
/// - Drops `last_sync_date`
///
/// The cursor is backfilled from the newest turnover booking date rather than
/// from `last_sync_date`, because that column may hold a discovery timestamp
/// for an account that was never downloaded. A booking date is never later
/// than the true frontier, so it errs towards re-fetching.
///
/// `ALTER TABLE ... DROP COLUMN` needs SQLite 3.35+, which the bundled
/// `package:sqlite3` provides on every platform. Rebuilding the table instead
/// is not an option: `turnover` and `savings_virtual_booking` reference
/// `account`, the latter with ON DELETE CASCADE, and foreign keys are on.
Future<void> v18(SqliteDatabase db) async {
  await db.execute('ALTER TABLE account ADD COLUMN download_cursor_date TEXT');
  await db.execute('ALTER TABLE account ADD COLUMN last_manual_sync_at TEXT');

  await db.execute('''
    UPDATE account
    SET download_cursor_date = (
      SELECT MAX(t.booking_date)
      FROM turnover t
      WHERE t.account_id = account.id AND t.booking_date IS NOT NULL
    )
    WHERE sync_source IS NOT NULL AND sync_source <> 'manual'
  ''');

  await db.execute('''
    UPDATE account
    SET last_manual_sync_at = last_sync_date
    WHERE sync_source IS NULL OR sync_source = 'manual'
  ''');

  await db.execute('ALTER TABLE account DROP COLUMN last_sync_date');
}
