import 'package:kashr/db/sqlite_compat.dart';

/// Migration v20: Record when a download actually ran.
///
/// `download_cursor_date` answers "booked transactions are complete through
/// this day". The UI has been showing it as "Last download", which is a
/// different question, and since v19 made the column unambiguously a calendar
/// day there is nothing left in it that could answer the other one.
///
/// Deliberately not backfilled. Seeding an event time from the cursor would
/// invent the very fact this column exists to stop inventing, so accounts
/// downloaded before this migration read as never downloaded until their next
/// run - which is true, in the sense that we never recorded one.
Future<void> v20(SqliteDatabase db) async {
  await db.execute('ALTER TABLE account ADD COLUMN last_download_at TEXT');
}
