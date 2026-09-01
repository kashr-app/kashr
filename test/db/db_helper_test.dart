import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/db/db_helper.dart';

import '../helpers/test_app.dart';
import '../helpers/test_database.dart';

/// Proves the test harness itself is sound.
///
/// Every other database-backed test reads its numbers through this same
/// fixture, so if this file is red their failures mean nothing.
void main() {
  useInMemoryDatabase();

  group('adoptForTesting', () {
    test('leaves the database at the current schema version', () async {
      final db = await DatabaseHelper().database;

      final version = await db.rawQuery('PRAGMA user_version');

      expect(version.first['user_version'], DatabaseHelper().dbVersion);
    });

    test('enforces foreign keys', () async {
      final db = await DatabaseHelper().database;

      final pragma = await db.rawQuery('PRAGMA foreign_keys');

      expect(pragma.first['foreign_keys'], 1);
    });

    test('round-trips an account through the real repository', () async {
      final app = TestApp();
      addTearDown(app.dispose);

      final account = await app.givenAccount(openingBalance: '12.34');

      expect(await app.accountRepository.getAccountById(account.id), account);
    });
  });
}
