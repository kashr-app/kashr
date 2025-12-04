import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> replaceTable(
  Transaction txn, {
  required String replaced,
  required String replacement,
}) async {
  final indexCreateStatements = await getIndexCreateStatements(txn, replaced);

  await txn.execute('DROP TABLE $replaced');
  await txn.execute('ALTER TABLE $replacement RENAME TO $replaced');

  await executeStatements(txn, indexCreateStatements);
}

Future<void> copyDataForSameColumnCount(
  Transaction txn, {
  required String from,
  required String to,
  required Map<String, String> columnRenames,
}) async {
  // Fetch column names from the old table
  final columns = (await txn.rawQuery(
    'PRAGMA table_info($from)',
  )).map((row) => row['name'] as String).toList();

  final columnsNew = (await txn.rawQuery(
    'PRAGMA table_info($to)',
  )).map((row) => row['name'] as String).toList();

  // assert that method can be used
  if (columns.length != columnsNew.length) {
    throw Exception('Count of columns is not equal');
  }

  // Keep order but replace old column names with the new ones
  final mappedColumns = columns.map((c) => columnRenames[c] ?? c).toList();

  final oldColsSql = columns.map((c) => '"$c"').join(', ');
  final newColsSql = mappedColumns.map((c) => '"$c"').join(', ');

  // INSERT with dynamic column mapping
  await txn.execute('''
    INSERT INTO $to
      ($newColsSql)
    SELECT
      $oldColsSql
    FROM $from;
  ''');
}

Future<List<String>> getIndexCreateStatements(
  Transaction txn,
  String table,
) async {
  final rows = await txn.rawQuery(
    '''
    SELECT sql 
    FROM sqlite_master
    WHERE type = 'index'
      AND tbl_name = ?
      AND sql IS NOT NULL
  ''',
    [table],
  );

  return rows.map((row) => row['sql'] as String).toList();
}

Future<void> executeStatements(Transaction txn, List<String> statements) async {
  for (final stmt in statements) {
    await txn.execute(stmt);
  }
}
