import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/db/db_helper.dart';
import 'package:kashr/db/sqlite_compat.dart';
import 'package:kashr/logging/services/log_service.dart';

/// Gives every test in the calling file a fresh, fully migrated in-memory
/// database, installed where the repositories look for one.
///
/// Nothing here is faked: the repositories run their real SQL against real
/// SQLite, which is the only way a date comparison bug can surface at all.
void useInMemoryDatabase() {
  setUp(() async {
    // The migrations log through LogService.instance and force-unwrap it.
    LogService();
    await DatabaseHelper().adoptForTesting(
      await SqliteDatabase.create(':memory:'),
    );
  });

  tearDown(() => DatabaseHelper().close());
}
