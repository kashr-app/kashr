import 'dart:async';
import 'dart:io';

import 'package:finanalyzer/db/migrations/schema_v12.dart';
import 'package:finanalyzer/db/migrations/v13.dart';
import 'package:finanalyzer/db/migrations/v14.dart';
import 'package:finanalyzer/db/sqlite_compat.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

const dbFileName = 'app_database.db';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static SqliteDatabase? _database;
  static Completer<SqliteDatabase>? _initCompleter;

  final log = Logger();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<SqliteDatabase> get database async {
    if (_database != null) return _database!;

    // If initialization is already in progress, wait for it
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<SqliteDatabase>();

    try {
      _database = await _initDb();
      await _database!.execute('PRAGMA foreign_keys = ON');
      _initCompleter!.complete(_database!);
      _initCompleter = null;
      return _database!;
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<SqliteDatabase> _initDb() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Only Android and iOS platforms are supported. '
        'Desktop and web support can be added in the future.',
      );
    }

    final path = await getDatabasePath();

    final db = await SqliteDatabase.create(path);
    await _migrate(db);
    return db;
  }

  Future<String> getDatabasePath() async {
    // Get application documents directory
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    // Construct databases directory path
    // On Android: /data/data/com.example.finanalyzer/databases/
    // On iOS: <app documents parent>/databases/
    final String dbDir = join(appDocDir.parent.path, 'databases');

    await Directory(dbDir).create(recursive: true);

    return join(dbDir, dbFileName);
  }

  Future<String?> sqlLiteVersion() async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery('SELECT sqlite_version()');
    return result.isNotEmpty
        ? result.first['sqlite_version()'] as String?
        : null;
  }

  int get dbVersion {
    return _migrations.keys.last;
  }

  final _migrations = <int, Future<void> Function(SqliteDatabase db)>{
    // version => migration function
    13: v13,
    14: v14,
  };

  Future<void> _migrate(SqliteDatabase db) async {
    var oldVersion = await _getCurrentVersion(db);
    final newVersion = dbVersion;

    final targetVersion = _migrations.keys.last;

    if (oldVersion == 0) {
      log.i('New database installation, creating schema at v$newVersion');
      await createSchemaV12(db);
      await _setVersion(db, 12);
      oldVersion = 12;
      log.i('Database schema created at v$newVersion');
    }
    if (oldVersion < targetVersion) {
      for (int i = oldVersion + 1; i <= newVersion; i++) {
        final m = _migrations[i];

        if (null == m) {
          log.e("Could not find database migration for v$i.");
          throw Exception('Could not find database migration v$i');
        }
        log.i("applying migration v$i");
        await m(db);
        await _setVersion(db, i);
        log.i('Database upgraded to v$i');
      }
    } else if (oldVersion == targetVersion) {
      log.d('No database migration. Version already at v$newVersion');
    } else {
      throw UnsupportedDatabaseVersionException(oldVersion, newVersion);
    }
  }

  Future<int> _getCurrentVersion(SqliteDatabase db) async {
    try {
      final result = await db.rawQuery('PRAGMA user_version');
      if (result.isEmpty) return 0;
      return result.first['user_version'] as int;
    } catch (e) {
      log.e('Failed to get database version', error: e);
      return 0;
    }
  }

  Future<void> _setVersion(SqliteDatabase db, int version) async {
    await db.execute('PRAGMA user_version = $version');
    log.i('Database version set to $version');
  }

  Future<void> close() async {
    if (_database != null) {
      _database!.close();
      _database = null;
      _initCompleter = null;
    }
  }
}

class UnsupportedDatabaseVersionException implements Exception {
  final int currentVersion;
  final int expectedVersion;

  const UnsupportedDatabaseVersionException(
    this.currentVersion,
    this.expectedVersion,
  );

  @override
  String toString() {
    return 'UnsupportedDatabaseVersionException: Current database version is '
        'v$currentVersion, but expected v$expectedVersion or v${expectedVersion - 1}. '
        'This database version is not supported. Please restore from a backup or '
        'reinstall the application.';
  }
}
