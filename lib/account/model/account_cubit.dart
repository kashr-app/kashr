import 'package:flutter_bloc/flutter_bloc.dart';
import 'account_repository.dart';
import 'account.dart';

class AccountCubit extends Cubit<List<Account>> {
  final AccountRepository accountRepository;

  AccountCubit(this.accountRepository) : super([]);

  Future<List<Account>> loadAccounts() async {
    final accounts = await accountRepository.findAll();
    emit(accounts);
    return accounts;
  }

  Future<void> addAccount(Account account) async {
    await accountRepository.createAccount(account);
    emit([...state, account]);
  }
}
