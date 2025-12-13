import 'package:finanalyzer/db/sqlite_compat.dart';

Future<void> v13(SqliteDatabase db) async {
  db.execute('''
    CREATE TABLE settings(
      key TEXT PRIMARY KEY,
      value TEXT
    )
''');
}
