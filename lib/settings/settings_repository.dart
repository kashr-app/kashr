import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/settings/settings_state.dart';

class SettingsRepository {
  Future<SettingsState> loadAll() async {
    final db = await DatabaseHelper().database;
    final result = db.query('settings');
    final map = <String, Object?>{};
    for (final row in result) {
      final key = row['key'] as String;
      final value = row['value'];
      map[key] = value;
    }
    return SettingsState.fromJson(map);
  }

  Future<void> upsertSetting(String key, String? value) async {
    final db = await DatabaseHelper().database;
    db.execute(
      '''
          INSERT INTO settings
            (key, value)
          VALUES
            (?, ?)
          ON CONFLICT(key) DO UPDATE SET value=excluded.value
        ''',
      [key, value],
    );
  }
}
