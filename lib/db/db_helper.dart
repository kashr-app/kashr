import 'dart:io';

import 'package:finanalyzer/db/migrations/v1.dart';
import 'package:finanalyzer/db/migrations/v2.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const dbFileName = 'app_database.db';

const dbVersion = 2;

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  final log = Logger();

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final options = OpenDatabaseOptions(
      version: dbVersion,
      onUpgrade: _onUpgrade,
    );
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      var factory = kIsWeb ? databaseFactoryFfiWeb : databaseFactoryFfi;
      final dbPath = await factory.getDatabasesPath();
      final path = join(dbPath, dbFileName);

      return await factory.openDatabase(path, options: options);
    }
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbFileName);

    return await openDatabase(
      path,
      version: options.version,
      onCreate: options.onCreate,
      onUpgrade: options.onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    final migrations = <int, Future<void> Function(Database db)>{
      // version => migration function
      1: v1,
      2: v2,
    };
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      final m = migrations[i];

      if (null == m) {
        log.e("Could not find database migration for v$i.");
        throw MigrationNotFoundException(i);
      }
      log.i("applying migration v$i");
      await m(db);
    }
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}

class MigrationNotFoundException implements Exception {
  final int migrationId;

  const MigrationNotFoundException(this.migrationId);

  @override
  String toString() {
    return 'MigrationNotFoundException: Database migration $migrationId not found. Application cannot proceed.';
  }
}
