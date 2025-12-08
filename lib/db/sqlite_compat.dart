import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Compatibility layer that wraps sqlite3.Database to provide a sqflite-like API.
///
/// This minimizes changes to existing repository code while using the native
/// sqlite3 package.
class SqliteDatabase {
  final sqlite3.Database _db;

  SqliteDatabase(this._db);

  /// Inserts a row into the specified table.
  ///
  /// Returns the row ID of the inserted row.
  int insert(String table, Map<String, Object?> values) {
    final columns = values.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    final columnNames = columns.join(', ');

    final sql = 'INSERT INTO $table ($columnNames) VALUES ($placeholders)';
    _db.execute(sql, values.values.toList());

    return _db.lastInsertRowId;
  }

  /// Updates rows in the specified table.
  ///
  /// Returns the number of rows affected.
  int update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    final columns = values.keys.toList();
    final setClause = columns.map((col) => '$col = ?').join(', ');

    final sql = 'UPDATE $table SET $setClause${where != null ? ' WHERE $where' : ''}';

    final args = [...values.values, if (whereArgs != null) ...whereArgs];
    _db.execute(sql, args);

    return _db.updatedRows;
  }

  /// Deletes rows from the specified table.
  ///
  /// Returns the number of rows affected.
  int delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    final sql = 'DELETE FROM $table${where != null ? ' WHERE $where' : ''}';
    _db.execute(sql, whereArgs ?? []);

    return _db.updatedRows;
  }

  /// Queries the specified table.
  ///
  /// Returns a list of maps representing the rows.
  List<Map<String, Object?>> query(
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
    final sql = _buildSelectQuery(
      table: table,
      distinct: distinct,
      columns: columns,
      where: where,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );

    return rawQuery(sql, whereArgs);
  }

  /// Executes a raw SQL query and returns the results.
  List<Map<String, Object?>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    final resultSet = _db.select(sql, arguments ?? []);
    return resultSet.map((row) => row).toList();
  }

  /// Executes a raw SQL update/delete query.
  ///
  /// Returns the number of rows affected.
  int rawUpdate(String sql, [List<Object?>? arguments]) {
    _db.execute(sql, arguments ?? []);
    return _db.updatedRows;
  }

  /// Executes a raw SQL delete query.
  ///
  /// Returns the number of rows affected.
  int rawDelete(String sql, [List<Object?>? arguments]) {
    return rawUpdate(sql, arguments);
  }

  /// Executes a raw SQL statement without returning results.
  ///
  /// Used for DDL statements like CREATE TABLE, DROP TABLE, etc.
  void execute(String sql, [List<Object?>? arguments]) {
    _db.execute(sql, arguments ?? []);
  }

  /// Creates a batch for executing multiple operations.
  SqliteBatch batch() {
    return SqliteBatch(_db);
  }

  /// Executes a function within a transaction.
  Future<T> transaction<T>(
    Future<T> Function(SqliteDatabase txn) action,
  ) async {
    _db.execute('BEGIN TRANSACTION');
    try {
      final result = await action(this);
      _db.execute('COMMIT');
      return result;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  /// Closes the database connection.
  void close() {
    _db.close();
  }

  /// Builds a SELECT query from the given parameters.
  String _buildSelectQuery({
    required String table,
    bool? distinct,
    List<String>? columns,
    String? where,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    final buffer = StringBuffer('SELECT ');

    if (distinct == true) {
      buffer.write('DISTINCT ');
    }

    if (columns == null || columns.isEmpty) {
      buffer.write('*');
    } else {
      buffer.write(columns.join(', '));
    }

    buffer.write(' FROM $table');

    if (where != null) {
      buffer.write(' WHERE $where');
    }

    if (groupBy != null) {
      buffer.write(' GROUP BY $groupBy');
    }

    if (having != null) {
      buffer.write(' HAVING $having');
    }

    if (orderBy != null) {
      buffer.write(' ORDER BY $orderBy');
    }

    if (limit != null) {
      buffer.write(' LIMIT $limit');
    }

    if (offset != null) {
      buffer.write(' OFFSET $offset');
    }

    return buffer.toString();
  }
}

/// Batch operations for executing multiple SQL statements efficiently.
class SqliteBatch {
  final sqlite3.Database _db;
  final List<_BatchOperation> _operations = [];

  SqliteBatch(this._db);

  /// Adds an insert operation to the batch.
  void insert(String table, Map<String, Object?> values) {
    _operations.add(_BatchOperation.insert(table, values));
  }

  /// Adds an update operation to the batch.
  void update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    _operations.add(_BatchOperation.update(table, values, where, whereArgs));
  }

  /// Adds a delete operation to the batch.
  void delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) {
    _operations.add(_BatchOperation.delete(table, where, whereArgs));
  }

  /// Adds a raw SQL operation to the batch.
  void rawInsert(String sql, [List<Object?>? arguments]) {
    _operations.add(_BatchOperation.rawSql(sql, arguments));
  }

  /// Adds a raw SQL operation to the batch.
  void rawUpdate(String sql, [List<Object?>? arguments]) {
    _operations.add(_BatchOperation.rawSql(sql, arguments));
  }

  /// Adds a raw SQL operation to the batch.
  void rawDelete(String sql, [List<Object?>? arguments]) {
    _operations.add(_BatchOperation.rawSql(sql, arguments));
  }

  /// Commits the batch, executing all operations in a transaction.
  ///
  /// If [noResult] is true, the results are not returned (more efficient).
  Future<List<Object?>> commit({bool? noResult, bool? continueOnError}) async {
    final results = <Object?>[];

    _db.execute('BEGIN TRANSACTION');
    try {
      for (final op in _operations) {
        try {
          final result = op.execute(_db);
          if (noResult != true) {
            results.add(result);
          }
        } catch (e) {
          if (continueOnError != true) {
            rethrow;
          }
          results.add(e);
        }
      }
      _db.execute('COMMIT');
      return results;
    } catch (e) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

/// Represents a single batch operation.
class _BatchOperation {
  final String type;
  final String? table;
  final Map<String, Object?>? values;
  final String? where;
  final List<Object?>? whereArgs;
  final String? sql;
  final List<Object?>? arguments;

  _BatchOperation._({
    required this.type,
    this.table,
    this.values,
    this.where,
    this.whereArgs,
    this.sql,
    this.arguments,
  });

  factory _BatchOperation.insert(String table, Map<String, Object?> values) {
    return _BatchOperation._(
      type: 'insert',
      table: table,
      values: values,
    );
  }

  factory _BatchOperation.update(
    String table,
    Map<String, Object?> values,
    String? where,
    List<Object?>? whereArgs,
  ) {
    return _BatchOperation._(
      type: 'update',
      table: table,
      values: values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  factory _BatchOperation.delete(
    String table,
    String? where,
    List<Object?>? whereArgs,
  ) {
    return _BatchOperation._(
      type: 'delete',
      table: table,
      where: where,
      whereArgs: whereArgs,
    );
  }

  factory _BatchOperation.rawSql(String sql, List<Object?>? arguments) {
    return _BatchOperation._(
      type: 'raw',
      sql: sql,
      arguments: arguments,
    );
  }

  /// Executes this operation on the database.
  Object? execute(sqlite3.Database db) {
    switch (type) {
      case 'insert':
        final columns = values!.keys.toList();
        final placeholders = List.filled(columns.length, '?').join(', ');
        final columnNames = columns.join(', ');
        final insertSql =
            'INSERT INTO $table ($columnNames) VALUES ($placeholders)';
        db.execute(insertSql, values!.values.toList());
        return db.lastInsertRowId;

      case 'update':
        final columns = values!.keys.toList();
        final setClause = columns.map((col) => '$col = ?').join(', ');
        final updateSql = 'UPDATE $table SET $setClause${where != null ? ' WHERE $where' : ''}';
        final args = [...values!.values, ...?whereArgs];
        db.execute(updateSql, args);
        return db.updatedRows;

      case 'delete':
        final deleteSql = 'DELETE FROM $table${where != null ? ' WHERE $where' : ''}';
        db.execute(deleteSql, whereArgs ?? []);
        return db.updatedRows;

      case 'raw':
        db.execute(sql!, arguments ?? []);
        return db.lastInsertRowId;

      default:
        throw UnsupportedError('Unknown batch operation type: $type');
    }
  }
}
