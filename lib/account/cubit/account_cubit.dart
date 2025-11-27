import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/cubit/account_state.dart';
import 'package:finanalyzer/account/services/balance_calculation_service.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:collection/collection.dart';
import '../model/account_repository.dart';
import '../model/account.dart';

class AccountCubit extends Cubit<AccountState> {
  final AccountRepository _accountRepository;
  final BalanceCalculationService _balanceService;
  final log = Logger();

  AccountCubit(this._accountRepository, this._balanceService)
      : super(const AccountState());

  Future<void> loadAccounts() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final accounts = await _accountRepository.findAll();

      // Calculate balances for all accounts
      final balances = <String, Decimal>{};
      for (final account in accounts) {
        if (account.id != null) {
          final balance = await _balanceService.calculateCurrentBalance(
            account,
          );
          balances[account.id!.uuid] = balance;
        }
      }

      final accountsByIsHidden = groupBy(accounts, (a) => a.isHidden);

      emit(
        state.copyWith(
          status: Status.success,
          accounts: accountsByIsHidden[false] ?? [],
          hiddenAccounts: accountsByIsHidden[true] ?? [],
          balances: balances,
        ),
      );
    } catch (e, stackTrace) {
      log.e('Failed to load accounts', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load accounts: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> addAccount(Account account) async {
    await _accountRepository.createAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(Account account) async {
    try {
      if (account.id == null) return;

      await _accountRepository.deleteAccount(account.id!);
      await loadAccounts();
    } catch (e, stackTrace) {
      log.e('Failed to delete account', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to delete account: ${e.toString()}',
        ),
      );
    }
  }

  /// Update the opening balance for an account based on current real balance.
  /// This recalculates the opening balance so that:
  /// currentRealBalance = openingBalance + sum(turnovers)
  /// Therefore: openingBalance = currentRealBalance - sum(turnovers)
  Future<void> updateBalanceFromReal(
    Account account,
    Decimal currentRealBalance,
  ) async {
    try {
      if (account.id == null) return;

      // Get current calculated balance (opening + turnovers)
      final calculatedBalance = await _balanceService.calculateCurrentBalance(
        account,
      );

      // Calculate what the opening balance should be
      // currentRealBalance = openingBalance + sum(turnovers)
      // openingBalance = currentRealBalance - sum(turnovers)
      final turnoverSum = calculatedBalance - account.openingBalance;
      final newOpeningBalance = currentRealBalance - turnoverSum;

      // Update the account with new opening balance
      final updatedAccount = account.copyWith(
        openingBalance: newOpeningBalance,
      );

      await _accountRepository.updateAccount(updatedAccount);
      await loadAccounts();
    } catch (e, stackTrace) {
      log.e('Failed to update balance', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to update balance: ${e.toString()}',
        ),
      );
    }
  }

  void toggleHiddenAccounts() {
    emit(state.copyWith(showHiddenAccounts: !state.showHiddenAccounts));
  }
}
