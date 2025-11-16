import 'package:sqflite/sqflite.dart';

Future<void> v1(Database db) async {
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
}