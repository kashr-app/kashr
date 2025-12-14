import 'dart:async';
import 'dart:isolate';
import 'package:finanalyzer/db/database_isolate.dart';

/// Async wrapper for sqlite3.Database that runs operations in background isolate.
///
/// Operations are asynchronous and run in a dedicated
/// isolate, preventing UI thread blocking.
class SqliteDatabase {
  final Isolate _isolate;
  final SendPort _sendPort;
  final String _dbPath;

  SqliteDatabase._(this._isolate, this._sendPort, this._dbPath);

  /// Initialize the database in a background isolate
  static Future<SqliteDatabase> create(String dbPath) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(
      databaseIsolateWorker,
      receivePort.sendPort,
    );
    final sendPort = await receivePort.first as SendPort;
    return SqliteDatabase._(isolate, sendPort, dbPath);
  }

  /// Send a command to the isolate and wait for result
  Future<T> _sendCommand<T>(DatabaseCommand command) async {
    final responsePort = ReceivePort();
    _sendPort.send([command, responsePort.sendPort, _dbPath]);

    final response = await responsePort.first as Map<String, dynamic>;
    responsePort.close();

    if (response['success'] == true) {
      return response['result'] as T;
    } else {
      throw Exception(
        'Database error: ${response['error']}\n${response['stack']}',
      );
    }
  }

  /// Inserts a row into the specified table.
  ///
  /// Returns the row ID of the inserted row.
  Future<int> insert(String table, Map<String, Object?> values) {
    return _sendCommand<int>(InsertCommand(table, values));
  }

  /// Updates rows in the specified table.
  ///
  /// Returns the number of rows affected.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    return _sendCommand<int>(
      UpdateCommand(table, values, where: where, whereArgs: whereArgs),
    );
  }

  /// Deletes rows from the specified table.
  ///
  /// Returns the number of rows affected.
  Future<int> delete(String table, {String? where, List<Object?>? whereArgs}) {
    return _sendCommand<int>(
      DeleteCommand(table, where: where, whereArgs: whereArgs),
    );
  }

  /// Queries the specified table.
  ///
  /// Returns a list of maps representing the rows.
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    return _sendCommand<List<Map<String, Object?>>>(
      QueryCommand(
        table: table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      ),
    );
  }

  /// Executes a raw SQL query and returns the results.
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    return _sendCommand<List<Map<String, Object?>>>(
      RawQueryCommand(sql, arguments),
    );
  }

  /// Executes a raw SQL statement without returning results.
  ///
  /// Used for DDL statements like CREATE TABLE, DROP TABLE, etc.
  Future<void> execute(String sql, [List<Object?>? arguments]) {
    return _sendCommand<void>(ExecuteCommand(sql, arguments));
  }

  /// Creates a batch for executing multiple operations.
  SqliteBatch batch() {
    return SqliteBatch(this);
  }

  /// Executes a function within a transaction.
  Future<T> transaction<T>(
    Future<T> Function(SqliteDatabase txn) action,
  ) async {
    // Start transaction
    await execute('BEGIN TRANSACTION');
    try {
      final result = await action(this);
      await execute('COMMIT');
      return result;
    } catch (e) {
      await execute('ROLLBACK');
      rethrow;
    }
  }

  /// Closes the database connection.
  Future<void> close() async {
    await _sendCommand<void>(CloseCommand());
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// Batch operations for executing multiple SQL statements efficiently.
class SqliteBatch {
  final SqliteDatabase _db;
  final List<DatabaseCommand> _commands = [];

  SqliteBatch(this._db);

  /// Adds an insert operation to the batch.
  void insert(String table, Map<String, Object?> values) {
    _commands.add(InsertCommand(table, values));
  }

  /// Adds an update operation to the batch.
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    _commands.add(
      UpdateCommand(table, values, where: where, whereArgs: whereArgs),
    );
  }

  /// Adds a delete operation to the batch.
  void delete(String table, {String? where, List<Object?>? whereArgs}) {
    _commands.add(DeleteCommand(table, where: where, whereArgs: whereArgs));
  }

  /// Adds a raw SQL operation to the batch.
  void rawSql(String sql, [List<Object?>? arguments]) {
    _commands.add(ExecuteCommand(sql, arguments));
  }

  /// Commits the batch, executing all operations in a transaction.
  ///
  /// If [noResult] is true, the results are not returned (more efficient).
  Future<List<Object?>> commit({bool? noResult, bool? continueOnError}) async {
    await _db._sendCommand<void>(TransactionCommand(_commands));
    return []; // Results not tracked in this implementation
  }
}
