import 'dart:isolate';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Message types for database operations
sealed class DatabaseCommand {}

class InsertCommand extends DatabaseCommand {
  final String table;
  final Map<String, Object?> values;
  InsertCommand(this.table, this.values);
}

class QueryCommand extends DatabaseCommand {
  final String table;
  final bool? distinct;
  final List<String>? columns;
  final String? where;
  final List<Object?>? whereArgs;
  final String? groupBy;
  final String? having;
  final String? orderBy;
  final int? limit;
  final int? offset;

  QueryCommand({
    required this.table,
    this.distinct,
    this.columns,
    this.where,
    this.whereArgs,
    this.groupBy,
    this.having,
    this.orderBy,
    this.limit,
    this.offset,
  });
}

class RawQueryCommand extends DatabaseCommand {
  final String sql;
  final List<Object?>? arguments;
  RawQueryCommand(this.sql, [this.arguments]);
}

class UpdateCommand extends DatabaseCommand {
  final String table;
  final Map<String, Object?> values;
  final String? where;
  final List<Object?>? whereArgs;

  UpdateCommand(this.table, this.values, {this.where, this.whereArgs});
}

class DeleteCommand extends DatabaseCommand {
  final String table;
  final String? where;
  final List<Object?>? whereArgs;

  DeleteCommand(this.table, {this.where, this.whereArgs});
}

class ExecuteCommand extends DatabaseCommand {
  final String sql;
  final List<Object?>? arguments;
  ExecuteCommand(this.sql, [this.arguments]);
}

class TransactionCommand extends DatabaseCommand {
  final List<DatabaseCommand> commands;
  TransactionCommand(this.commands);
}

class CloseCommand extends DatabaseCommand {}

/// Isolate worker that hosts the database
void databaseIsolateWorker(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  sqlite3.Database? db;

  receivePort.listen((message) {
    if (message is List && message.length == 3) {
      final command = message[0] as DatabaseCommand;
      final SendPort replyPort = message[1];
      final String? dbPath = message[2];

      try {
        // Initialize database if needed
        if (db == null && dbPath != null) {
          db = sqlite3.sqlite3.open(dbPath);
        }

        final result = _executeCommand(db!, command);
        replyPort.send({'success': true, 'result': result});
      } catch (e, stackTrace) {
        replyPort.send({
          'success': false,
          'error': e.toString(),
          'stack': stackTrace.toString(),
        });
      }
    }
  });
}

dynamic _executeCommand(sqlite3.Database db, DatabaseCommand command) {
  return switch (command) {
    InsertCommand() => _handleInsert(db, command),
    QueryCommand() => _handleQuery(db, command),
    RawQueryCommand() => _handleRawQuery(db, command),
    UpdateCommand() => _handleUpdate(db, command),
    DeleteCommand() => _handleDelete(db, command),
    ExecuteCommand() => _handleExecute(db, command),
    TransactionCommand() => _handleTransaction(db, command),
    CloseCommand() => db.close(),
  };
}

int _handleInsert(sqlite3.Database db, InsertCommand cmd) {
  final columns = cmd.values.keys.toList();
  final placeholders = List.filled(columns.length, '?').join(', ');
  final columnNames = columns.join(', ');
  final sql = 'INSERT INTO ${cmd.table} ($columnNames) VALUES ($placeholders)';
  db.execute(sql, cmd.values.values.toList());
  return db.lastInsertRowId;
}

List<Map<String, Object?>> _handleQuery(sqlite3.Database db, QueryCommand cmd) {
  final buffer = StringBuffer('SELECT ');

  if (cmd.distinct == true) buffer.write('DISTINCT ');
  buffer.write(cmd.columns?.join(', ') ?? '*');
  buffer.write(' FROM ${cmd.table}');

  if (cmd.where != null) buffer.write(' WHERE ${cmd.where}');
  if (cmd.groupBy != null) buffer.write(' GROUP BY ${cmd.groupBy}');
  if (cmd.having != null) buffer.write(' HAVING ${cmd.having}');
  if (cmd.orderBy != null) buffer.write(' ORDER BY ${cmd.orderBy}');
  if (cmd.limit != null) buffer.write(' LIMIT ${cmd.limit}');
  if (cmd.offset != null) buffer.write(' OFFSET ${cmd.offset}');

  final resultSet = db.select(buffer.toString(), cmd.whereArgs ?? []);
  return resultSet.map((row) => row).toList();
}

List<Map<String, Object?>> _handleRawQuery(
  sqlite3.Database db,
  RawQueryCommand cmd,
) {
  final resultSet = db.select(cmd.sql, cmd.arguments ?? []);
  return resultSet.map((row) => row).toList();
}

int _handleUpdate(sqlite3.Database db, UpdateCommand cmd) {
  final columns = cmd.values.keys.toList();
  final setClause = columns.map((col) => '$col = ?').join(', ');
  final sql =
      'UPDATE ${cmd.table} SET $setClause${cmd.where != null ? ' WHERE ${cmd.where}' : ''}';
  final args = [...cmd.values.values, if (cmd.whereArgs != null) ...cmd.whereArgs!];
  db.execute(sql, args);
  return db.updatedRows;
}

int _handleDelete(sqlite3.Database db, DeleteCommand cmd) {
  final sql =
      'DELETE FROM ${cmd.table}${cmd.where != null ? ' WHERE ${cmd.where}' : ''}';
  db.execute(sql, cmd.whereArgs ?? []);
  return db.updatedRows;
}

void _handleExecute(sqlite3.Database db, ExecuteCommand cmd) {
  db.execute(cmd.sql, cmd.arguments ?? []);
}

void _handleTransaction(sqlite3.Database db, TransactionCommand cmd) {
  db.execute('BEGIN TRANSACTION');
  try {
    for (final subCmd in cmd.commands) {
      _executeCommand(db, subCmd);
    }
    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    rethrow;
  }
}
