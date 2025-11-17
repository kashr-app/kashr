import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover.dart';
import 'package:finanalyzer/turnover/model/turnover_with_tags.dart';
import 'package:decimal/decimal.dart';
import 'package:jiffy/jiffy.dart';
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

  /// Fetches turnovers for a specific month and year.
  Future<List<Turnover>> getTurnoversForMonth({
    required int year,
    required int month,
  }) async {
    final db = await DatabaseHelper().database;

    final startDate = Jiffy.parseFromDateTime(DateTime(year, month));
    final endDate = startDate.add(months: 1);

    final maps = await db.query(
      'turnover',
      where: 'bookingDate >= ? AND bookingDate < ?',
      whereArgs: [
        startDate.format(pattern: isoDateFormat),
        endDate.format(pattern: isoDateFormat),
      ],
      orderBy: 'bookingDate DESC',
    );

    return maps.map((map) => Turnover.fromJson(map)).toList();
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

  /// Fetches a paginated list of turnovers with their associated tags.
  /// This method efficiently loads all data in a single query to avoid N+1 problems.
  Future<List<TurnoverWithTags>> getTurnoversWithTagsPaginated({
    required int limit,
    required int offset,
  }) async {
    final db = await DatabaseHelper().database;

    // First, get the paginated turnovers
    final turnoverMaps = await db.query(
      'turnover',
      orderBy: 'bookingDate DESC NULLS FIRST, createdAt DESC',
      limit: limit,
      offset: offset,
    );

    if (turnoverMaps.isEmpty) {
      return [];
    }

    final turnovers =
        turnoverMaps.map((map) => Turnover.fromJson(map)).toList();
    final turnoverIds =
        turnovers.where((t) => t.id != null).map((t) => t.id!.uuid).toList();

    if (turnoverIds.isEmpty) {
      // Return turnovers without tags if no valid IDs
      return turnovers
          .map((t) => TurnoverWithTags(turnover: t, tagTurnovers: []))
          .toList();
    }

    // Fetch all tag_turnovers for these turnovers with their tags in one query
    final placeholders = List.generate(turnoverIds.length, (_) => '?').join(',');
    final tagTurnoverMaps = await db.rawQuery(
      '''
      SELECT
        tt.id as tt_id,
        tt.turnoverId as tt_turnoverId,
        tt.tagId as tt_tagId,
        tt.amountValue as tt_amountValue,
        tt.amountUnit as tt_amountUnit,
        tt.note as tt_note,
        t.id as t_id,
        t.name as t_name,
        t.color as t_color
      FROM tag_turnover tt
      LEFT JOIN tag t ON tt.tagId = t.id
      WHERE tt.turnoverId IN ($placeholders)
      ORDER BY tt.amountValue DESC
      ''',
      turnoverIds,
    );

    // Group tag turnovers by turnover ID
    final tagTurnoversByTurnoverId = <String, List<TagTurnoverWithTag>>{};
    for (final map in tagTurnoverMaps) {
      final turnoverId = map['tt_turnoverId'] as String?;
      if (turnoverId == null) continue;

      final tagTurnover = TagTurnover(
        id: map['tt_id'] != null
            ? UuidValue.fromString(map['tt_id'] as String)
            : null,
        turnoverId: UuidValue.fromString(turnoverId),
        tagId: UuidValue.fromString(map['tt_tagId'] as String),
        amountValue: (Decimal.fromInt(map['tt_amountValue'] as int) /
                Decimal.fromInt(scaleFactor))
            .toDecimal(),
        amountUnit: map['tt_amountUnit'] as String,
        note: map['tt_note'] as String?,
      );

      final tag = Tag(
        id: map['t_id'] != null
            ? UuidValue.fromString(map['t_id'] as String)
            : null,
        name: map['t_name'] as String? ?? 'Unknown',
        color: map['t_color'] as String?,
      );

      final tagTurnoverWithTag = TagTurnoverWithTag(
        tagTurnover: tagTurnover,
        tag: tag,
      );

      tagTurnoversByTurnoverId
          .putIfAbsent(turnoverId, () => [])
          .add(tagTurnoverWithTag);
    }

    // Combine turnovers with their tag turnovers
    return turnovers.map((turnover) {
      final turnoverId = turnover.id?.uuid;
      final tagTurnovers = turnoverId != null
          ? (tagTurnoversByTurnoverId[turnoverId] ?? <TagTurnoverWithTag>[])
          : <TagTurnoverWithTag>[];
      return TurnoverWithTags(
        turnover: turnover,
        tagTurnovers: tagTurnovers,
      );
    }).toList();
  }
}
