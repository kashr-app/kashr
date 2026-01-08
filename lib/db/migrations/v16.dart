import 'package:kashr/db/sqlite_compat.dart';

/// Migration v16: Rename openingBalanceDate to lastSyncDate
///
/// Refactors the account table to rename `opening_balance_date` to
/// `last_sync_date`. The values are already representing these semantics.
/// The actual opening balance date is now computed on-demand as the day
/// before the earliest turnover on an account.
/// last_sync_date tracks when the balance was last recalculated or synced.
///
/// Changes:
/// - Renames `opening_balance_date` column to `last_sync_date`
Future<void> v16(SqliteDatabase db) async {
  await db.execute('''
    ALTER TABLE account
    RENAME COLUMN opening_balance_date TO last_sync_date
  ''');
}
