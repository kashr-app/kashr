import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/services/balance_calculation_service.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/model/turnover_change.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:collection/collection.dart';
import 'package:jiffy/jiffy.dart';
import 'package:uuid/uuid.dart';
import '../model/account_repository.dart';
import '../model/account.dart';

class AccountCubit extends Cubit<AccountState> {
  final AccountRepository _accountRepository;
  final BalanceCalculationService _balanceService;
  final TurnoverRepository _turnoverRepository;
  final Logger log;

  StreamSubscription<TurnoverChange>? _turnoverSubscription;

  AccountCubit(
    this._accountRepository,
    this._balanceService,
    this._turnoverRepository,
    this.log,
  ) : super(
        AccountState(
          projectionDate: Jiffy.parseFromDateTime(
            DateTime.now(),
          ).endOf(Unit.month).dateTime,
        ),
      ) {
    _turnoverSubscription = _turnoverRepository.watchChanges().listen(
      _onTurnoverChanged,
    );
  }

  @override
  Future<void> close() async {
    await _turnoverSubscription?.cancel();
    return super.close();
  }

  void _onTurnoverChanged(TurnoverChange change) async {
    await _calcBalances(state.accountById.values);
  }

  Future<void> loadAccounts() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final accounts = await _accountRepository.findAll();

      // Calculate balances for all accounts
      await _calcBalances(accounts);

      // non-hidden first
      final orderedAccounts = accounts.sorted((a, b) => a.isHidden ? 1 : -1);
      final accountsByIsHidden = groupBy(orderedAccounts, (a) => a.isHidden);

      emit(
        state.copyWith(
          status: Status.success,
          accountById: orderedAccounts.associateBy((it) => it.id),
          accountsByIsHidden: accountsByIsHidden,
          visibleAccounts: state.showHiddenAccounts
              ? orderedAccounts
              : (accountsByIsHidden[false] ?? []),
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

  Future<void> _calcBalances(Iterable<Account> accounts) async {
    // Calculate end of current month for projected balance
    final now = DateTime.now();
    final endOfMonth = Jiffy.parseFromDateTime(now).endOf(Unit.month).dateTime;

    final balances = <UuidValue, Decimal>{};
    final projectedBalances = <UuidValue, Decimal>{};
    for (final account in accounts) {
      final balance = await _balanceService.calculateCurrentBalance(account);
      balances[account.id] = balance;

      final projected = await _balanceService.calculateProjectedBalance(
        account,
        asOf: endOfMonth,
      );
      projectedBalances[account.id] = projected;
    }
    emit(
      state.copyWith(
        balances: balances,
        projectedBalances: projectedBalances,
        projectionDate: endOfMonth,
      ),
    );
  }

  Future<void> addAccount(Account account) async {
    await _accountRepository.createAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(Account account) async {
    try {
      await _accountRepository.deleteAccount(account.id);
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
        lastSyncDate: DateTime.now(),
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

  /// Computes opening balance dates for multiple accounts.
  ///
  /// Returns a map of accountId to opening balance date. The opening balance
  /// date is calculated as 1 day before the earliest turnover booking date,
  /// or the account creation date if no turnovers exist.
  Future<Map<UuidValue, DateTime>> getOpeningBalanceDates(
    Iterable<UuidValue> accountIds,
  ) async {
    if (accountIds.isEmpty) {
      return {};
    }

    final earliestDates = await _turnoverRepository
        .getEarliestBookingDatesForAccounts(accountIds: accountIds);

    final result = <UuidValue, DateTime>{};
    for (final accountId in accountIds) {
      final account = state.accountById[accountId];
      if (account == null) continue;

      final earliestDate = earliestDates[accountId];
      if (earliestDate == null) {
        result[accountId] = account.createdAt;
      } else {
        // One day before earliest turnover
        result[accountId] = earliestDate.subtract(const Duration(days: 1));
      }
    }

    return result;
  }

  void toggleHiddenAccounts() {
    final showHidden = !state.showHiddenAccounts;
    emit(
      state.copyWith(
        showHiddenAccounts: showHidden,
        visibleAccounts: showHidden
            ? state.accountById.values.toList()
            : (state.accountsByIsHidden[false] ?? []),
      ),
    );
  }
}
