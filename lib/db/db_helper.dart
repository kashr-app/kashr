import 'dart:async';
import 'dart:io';

import 'package:finanalyzer/db/migrations/schema_v11.dart';
import 'package:finanalyzer/db/migrations/v11.dart';
import 'package:finanalyzer/db/sqlite_compat.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

const dbFileName = 'app_database.db';

const dbVersion = 11;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static sqlite3.Database? _database;
  static Completer<SqliteDatabase>? _initCompleter;

  final log = Logger();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<SqliteDatabase> get database async {
    if (_database != null) return SqliteDatabase(_database!);

    // If initialization is already in progress, wait for it
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<SqliteDatabase>();

    try {
      _database = await _initDb();
      _database!.execute('PRAGMA foreign_keys = ON');
      final dbWrapper = SqliteDatabase(_database!);
      _initCompleter!.complete(dbWrapper);
      _initCompleter = null;
      return dbWrapper;
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<sqlite3.Database> _initDb() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Only Android and iOS platforms are supported. '
        'Desktop and web support can be added in the future.',
      );
    }

    final path = await getDatabasePath();

    final db = sqlite3.sqlite3.open(path);
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

  Future<void> _migrate(sqlite3.Database db) async {
    final version = _getCurrentVersion(db);

    if (version == 0) {
      log.i('New database installation, creating schema at v$dbVersion');
      await createSchemaV11(SqliteDatabase(db));
      _setVersion(db, dbVersion);
      log.i('Database schema created at v$dbVersion');
    } else if (version == 10) {
      log.i('Upgrading database from v$version to v$dbVersion');
      await v11(SqliteDatabase(db));
      _setVersion(db, dbVersion);
      log.i('Database upgraded to v$dbVersion');
    } else if (version == dbVersion) {
      log.i('Database already at v$dbVersion');
    } else {
      // Unsupported version
      throw UnsupportedDatabaseVersionException(version, dbVersion);
    }
  }

  int _getCurrentVersion(sqlite3.Database db) {
    try {
      final result = db.select('PRAGMA user_version');
      if (result.isEmpty) return 0;
      return result.first['user_version'] as int;
    } catch (e) {
      log.e('Failed to get database version', error: e);
      return 0;
    }
  }

  void _setVersion(sqlite3.Database db, int version) {
    db.execute('PRAGMA user_version = $version');
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
