import 'package:finanalyzer/db_helper.dart';
import 'turnover.dart';
import 'package:uuid/uuid.dart';

const int scaleFactor = 100; // Define scale factor (e.g., 2 decimal places)

class TurnoverRepository {
  Future<int> createTurnover(Turnover turnover) async {
    final db = await DatabaseHelper().database;
    return await db.insert('turnover', turnover.toJson());
  }

  Future<Turnover?> getTurnoverById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps =
        await db.query('turnover', where: 'id = ?', whereArgs: [id.uuid]);

    if (maps.isNotEmpty) {
      final turnoverMap = maps.first;
      return Turnover.fromJson(turnoverMap);
    }
    return null;
  }

  Future<List<Turnover>> getTurnovers() async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'turnover',
      orderBy: 'bookingDate DESC NULLS FIRST',
    );

    return maps.map((map) => Turnover.fromJson(map)).toList();
  }

  Future<List<Turnover>> getTurnoversByApiIds(List<UuidValue> apiIds) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'turnover',
      where: 'apiId IN (${List.filled(apiIds.length, '?').join(',')})',
      whereArgs: apiIds.map((id) => id.uuid).toList(),
    );
    return result.map((e) => Turnover.fromJson(e)).toList();
  }

  // Custom method to find accountId and apiId by a list of API IDs
  Future<List<TurnoverAccountIdAndApiId>> findAccountIdAndApiIdIn(
      List<String> apiIds) async {
    final db = await DatabaseHelper().database;

    // Create placeholders for the IN clause
    final placeholders = List.generate(apiIds.length, (_) => '?').join(',');

    // Query the database
    final results = await db.rawQuery('''
      SELECT accountId, apiId
      FROM turnover
      WHERE apiId IN ($placeholders)
    ''', apiIds.map((e) => e).toList());

    return results.map((e) => TurnoverAccountIdAndApiId.fromJson(e)).toList();
  }

  // Example method to store a list of turnovers (already shown before)
  Future<List<Turnover>> saveAll(List<Turnover> turnovers) async {
    final db = await DatabaseHelper().database;

    final batch = db.batch();
    for (final turnover in turnovers) {
      batch.insert('turnover', turnover.toJson());
    }
    await batch.commit();
    return turnovers;
  }
}
