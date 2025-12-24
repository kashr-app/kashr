import 'package:kashr/account/model/account.dart';
import 'package:kashr/account/model/account_repository.dart';
import 'package:uuid/uuid_value.dart';

class AccountService {
  final AccountRepository accountRepository;

  AccountService(this.accountRepository);

  // Async function to get account IDs by API IDs
  Future<Map<String, UuidValue>> getAccountIdByAccountApiId(List<String> apiIds) async {
    final accounts = await accountRepository.findAccountIdAndApiIdIn(apiIds);
    return Map<String, UuidValue>.fromEntries(
      accounts.map((acc) => MapEntry(acc.apiId, acc.id))
    );
  }

  // Async function to create a new account
  Future<Account> createAccount(Account account) async {
    return await accountRepository.createAccount(account);
  }
}