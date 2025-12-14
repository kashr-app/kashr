import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/decimal_json_converter.dart';
import 'package:finanalyzer/db/db_helper.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking.dart';
import 'package:uuid/uuid.dart';

class SavingsVirtualBookingRepository {
  Future<int> create(SavingsVirtualBooking booking) async {
    final db = await DatabaseHelper().database;
    return await db.insert('savings_virtual_booking', booking.toJson());
  }

  Future<SavingsVirtualBooking?> getById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings_virtual_booking',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );

    if (maps.isNotEmpty) {
      return SavingsVirtualBooking.fromJson(maps.first);
    }
    return null;
  }

  Future<List<SavingsVirtualBooking>> getBySavingsId(
    UuidValue savingsId,
  ) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings_virtual_booking',
      where: 'savings_id = ?',
      whereArgs: [savingsId.uuid],
      orderBy: 'booking_date DESC',
    );
    return maps.map((e) => SavingsVirtualBooking.fromJson(e)).toList();
  }

  Future<List<SavingsVirtualBooking>> getBySavingsIdAndAccount(
    UuidValue savingsId,
    UuidValue accountId,
  ) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings_virtual_booking',
      where: 'savings_id = ? AND account_id = ?',
      whereArgs: [savingsId.uuid, accountId.uuid],
      orderBy: 'booking_date DESC',
    );
    return maps.map((e) => SavingsVirtualBooking.fromJson(e)).toList();
  }

  Future<List<SavingsVirtualBooking>> getByAccountId(
    UuidValue accountId,
  ) async {
    final db = await DatabaseHelper().database;
    final maps = await db.query(
      'savings_virtual_booking',
      where: 'account_id = ?',
      whereArgs: [accountId.uuid],
      orderBy: 'booking_date DESC',
    );
    return maps.map((e) => SavingsVirtualBooking.fromJson(e)).toList();
  }

  Future<int> update(SavingsVirtualBooking booking) async {
    final db = await DatabaseHelper().database;
    return await db.update(
      'savings_virtual_booking',
      booking.toJson(),
      where: 'id = ?',
      whereArgs: [booking.id.uuid],
    );
  }

  Future<int> delete(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return await db.delete(
      'savings_virtual_booking',
      where: 'id = ?',
      whereArgs: [id.uuid],
    );
  }

  Future<Decimal> sumBySavingsId(UuidValue savingsId) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_value) as total
      FROM savings_virtual_booking
      WHERE savings_id = ?
      ''',
      [savingsId.uuid],
    );

    return _unscale(result.first['total']);
  }

  Future<Decimal> sumBySavingsIdAndAccount(
    UuidValue savingsId,
    UuidValue accountId,
  ) async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount_value) as total
      FROM savings_virtual_booking
      WHERE savings_id = ? AND account_id = ?
      ''',
      [savingsId.uuid, accountId.uuid],
    );

    return _unscale(result.first['total']);
  }

  Decimal _unscale(Object? result) {
    return decimalUnscale(result as int? ?? 0) ?? Decimal.zero;
  }

  Future<List<UuidValue>> findAccountsBySavings(UuidValue savingsId) async {
    final db = await DatabaseHelper().database;
    final result = await db.rawQuery(
      '''
      SELECT DISTINCT account_id
      FROM savings_virtual_booking
      WHERE savings_id = ?
      ''',
      [savingsId.uuid],
    );
    return result
        .map((m) => UuidValue.fromString(m['account_id'] as String))
        .toList();
  }
}
