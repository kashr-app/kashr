import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/db/migrations/v19.dart';
import 'package:kashr/db/sqlite_compat.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

/// Every row written before this migration holds a full timestamp, so the
/// fixture writes through the repositories and then puts the old shape back
/// by hand.
Future<void> _writeLegacyTimestamps(SqliteDatabase db) async {
  await db.execute(
    "UPDATE turnover SET booking_date = '2026-09-30T14:23:00.000'",
  );
  await db.execute(
    "UPDATE tag_turnover SET booking_date = '2026-09-30T00:00:00.000'",
  );
  await db.execute(
    "UPDATE account SET download_cursor_date = '2026-09-30T00:00:00.000'",
  );
}

Future<List<Object?>> _storedDays(SqliteDatabase db) async => [
  (await db.rawQuery(
    'SELECT booking_date FROM turnover',
  )).single['booking_date'],
  (await db.rawQuery(
    'SELECT booking_date FROM tag_turnover',
  )).single['booking_date'],
  (await db.rawQuery(
    'SELECT download_cursor_date FROM account',
  )).single['download_cursor_date'],
];

void main() {
  useInMemoryDatabase();

  group('v19', () {
    late TestApp app;
    late SqliteDatabase db;

    setUp(() async {
      app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount();
      final tag = await app.givenTag();
      await app.givenTurnover(
        account,
        bookedOn: BookingDate(2026, 9, 30),
        amount: '-10',
      );
      await app.givenTagTurnover(
        account,
        tag: tag,
        bookedOn: BookingDate(2026, 9, 30),
        amount: '-10',
      );
      db = await DatabaseHelper().database;
    });

    test('keeps the day a timestamp was booked on', () async {
      await _writeLegacyTimestamps(db);

      await v19(db);

      expect(await _storedDays(db), ['2026-09-30', '2026-09-30', '2026-09-30']);
    });

    test('can run twice, because a crashed migration replays', () async {
      await _writeLegacyTimestamps(db);

      await v19(db);
      await v19(db);

      expect(await _storedDays(db), ['2026-09-30', '2026-09-30', '2026-09-30']);
    });

    test('leaves a day the app already wrote alone', () async {
      await v19(db);

      expect(await _storedDays(db), ['2026-09-30', '2026-09-30', null]);
    });
  });
}
