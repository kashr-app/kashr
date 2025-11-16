import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const dbFileName = 'app_database.db';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final options = OpenDatabaseOptions(
      version: 1,
      onCreate: _onCreate,
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

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE account(
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        name TEXT NOT NULL,
        identifier TEXT,
        apiId TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE turnover(
        id TEXT PRIMARY KEY,
        createdAt TEXT NOT NULL,
        accountId TEXT NOT NULL,
        bookingDate TEXT,
        amountValue INTEGER NOT NULL,
        amountUnit TEXT NOT NULL,
        counterPart TEXT,
        purpose TEXT NOT NULL,
        apiId TEXT,
        FOREIGN KEY(accountId) REFERENCES account(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE tag(
        id TEXT PRIMARY KEY,
        color TEXT,
        name TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE tag_turnover(
        id TEXT PRIMARY KEY,
        turnoverId TEXT NOT NULL,
        tagId TEXT NOT NULL,
        amountValue INTEGER NOT NULL,
        amountUnit TEXT NOT NULL,
        note TEXT,
        FOREIGN KEY(turnoverId) REFERENCES turnover(id),
        FOREIGN KEY(tagId) REFERENCES tag(id)
      );
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }
}
