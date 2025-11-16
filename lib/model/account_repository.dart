import 'package:finanalyzer/db_helper.dart';
import 'package:uuid/uuid.dart';
import 'account.dart';

class AccountRepository {
  Future<Account> createAccount(Account account) async {
    final db = await DatabaseHelper().database;
    await db.insert('account', account.toJson());
    return account;
  }

  Future<Account?> getAccountById(UuidValue id) async {
    final db = await DatabaseHelper().database;
    final maps =
        await db.query('account', where: 'id = ?', whereArgs: [id.uuid]);

    if (maps.isNotEmpty) {
      return Account.fromJson(maps.first);
    }
    return null;
  }

  Future<Account> updateAccount(Account account) async {
    final id = account.id;
    if (id == null) {
      throw 'Cannot update non-persisted account (id = null)';
    }
    final db = await DatabaseHelper().database;
    final count = await db.update('account', account.toJson(),
        where: 'id = ?', whereArgs: [id.uuid]);
    if (count != 1) {
      throw 'Update was not applied to exactly one row but $count rows.';
    }
    return account;
  }

  Future<int> deleteAccount(UuidValue id) async {
    final db = await DatabaseHelper().database;
    return await db.delete('account', where: 'id = ?', whereArgs: [id.uuid]);
  }

  Future<List<AccountIdAndApiId>> findAccountIdAndApiIdIn(
      List<String> accountApiIds) async {
    final db = await DatabaseHelper().database;

    final placeholders = List.filled(accountApiIds.length, '?').join(',');
    final results = await db.rawQuery('''
      SELECT id, apiId
      FROM account
      WHERE apiId IN ($placeholders)
    ''', accountApiIds);

    return results.map((e) => AccountIdAndApiId.fromJson(e)).toList();
  }

  Future<List<Account>> findAll() async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'account',
    );
    return result.map((e) => Account.fromJson(e)).toList();
  }
}
