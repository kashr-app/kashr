import 'package:sqflite/sqflite.dart';

Future<void> v8(Database db) async {
  await db.execute('''
    ALTER TABLE tag ADD COLUMN semantic TEXT
  ''');
}
