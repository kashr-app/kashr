import 'package:kashr/db/sqlite_compat.dart';

/// Migration v19: Store booking dates as calendar days, not timestamps.
///
/// A booking date is the day a transaction was booked on, but it used to be
/// modelled as a `DateTime` and therefore written by `toIso8601String()` as a
/// full timestamp. Reads compensated by comparing against date-only bounds,
/// which works only because ISO-8601 sorts as text. Now that the app writes
/// `yyyy-MM-dd`, the rows written before it have to catch up: a mixed corpus
/// still sorts correctly, but `MAX()` across two rows and any equality
/// comparison would prefer the longer string for the same day.
///
/// `substr(..., 1, 10)` is the whole conversion: the values were written from
/// *local* `DateTime`s, so they carry no offset suffix and their first ten
/// characters are the calendar day that was meant.
///
/// `account.download_cursor_date` is in the list because v18 backfilled it
/// from `MAX(turnover.booking_date)`, so it holds the same shape.
///
/// The `length(...) > 10` guard makes this re-runnable. Migrations run outside
/// a transaction, so a crash part-way through replays every statement.
Future<void> v19(SqliteDatabase db) async {
  const dayColumns = [
    ('turnover', 'booking_date'),
    ('tag_turnover', 'booking_date'),
    ('savings_virtual_booking', 'booking_date'),
    ('account', 'download_cursor_date'),
  ];

  for (final (table, column) in dayColumns) {
    await db.execute('''
      UPDATE $table SET $column = substr($column, 1, 10)
      WHERE $column IS NOT NULL AND length($column) > 10
    ''');
  }
}
