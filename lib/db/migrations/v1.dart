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