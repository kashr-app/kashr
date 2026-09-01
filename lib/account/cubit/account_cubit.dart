import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:kashr/account/cubit/account_state.dart';
import 'package:kashr/account/services/balance_calculation_service.dart';
import 'package:kashr/core/associate_by.dart';
import 'package:kashr/core/model/booking_date.dart';
import 'package:kashr/core/model/period.dart';
import 'package:kashr/core/status.dart';
import 'package:kashr/turnover/model/turnover_change.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:collection/collection.dart';
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
  ) : super(AccountState(projectionPeriod: Period.now(PeriodType.month))) {
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
    final projectionPeriod = Period.now(PeriodType.month);

    final balances = <UuidValue, Decimal>{};
    final projectedBalances = <UuidValue, Decimal>{};
    for (final account in accounts) {
      final balance = await _balanceService.calculateCurrentBalance(account);
      balances[account.id] = balance;

      final projected = await _balanceService.calculateProjectedBalance(
        account,
        endExclusive: BookingDate.on(projectionPeriod.endExclusive),
      );
      projectedBalances[account.id] = projected;
    }
    emit(
      state.copyWith(
        balances: balances,
        projectedBalances: projectedBalances,
        projectionPeriod: projectionPeriod,
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

  /// Update the opening balance for an account based on [currentRealBalance].
  /// This recalculates the opening balance so that:
  /// currentRealBalance = openingBalance + sum(turnovers)
  /// Therefore: openingBalance = currentRealBalance - sum(turnovers)
  ///
  /// [recordManualCheck] stamps [Account.lastManualSyncAt]. Only the user
  /// reconciling a balance by hand does that; a download reconciles the same
  /// balance but records its progress in [Account.downloadCursorDate].
  Future<void> syncBalanceFromReal(
    Account account,
    Decimal currentRealBalance, {
    required bool recordManualCheck,
  }) async {
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
        lastManualSyncAt: recordManualCheck
            ? DateTime.now()
            : account.lastManualSyncAt,
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

  /// Records that booked transactions are complete through [cursorDate] for
  /// the given accounts.
  ///
  /// Only ever moves a cursor forward. A download of a range that ends in the
  /// past - the user filling a gap in the history - covers less than what the
  /// account is already caught up on, and must not make it look behind again.
  ///
  /// Reads the accounts from the current state so that a balance
  /// reconciliation that ran during the same download is not overwritten.
  Future<void> advanceDownloadCursors(
    Iterable<UuidValue> accountIds,
    DateTime cursorDate,
  ) async {
    for (final id in accountIds) {
      final account = state.accountById[id];
      if (account == null) continue;
      final current = account.downloadCursorDate;
      if (current != null && !current.isBefore(cursorDate)) continue;
      await _accountRepository.updateAccount(
        account.copyWith(downloadCursorDate: cursorDate),
      );
    }
    await loadAccounts();
  }

  /// Computes opening balance dates for multiple accounts.
  ///
  /// Returns a map of accountId to opening balance date. The opening balance
  /// date is calculated as 1 day before the earliest turnover booking date,
  /// or the account creation date if no turnovers exist.
  Future<Map<UuidValue, BookingDate>> getOpeningBalanceDates(
    Iterable<UuidValue> accountIds,
  ) async {
    if (accountIds.isEmpty) {
      return {};
    }

    final earliestDates = await _turnoverRepository
        .getEarliestBookingDatesForAccounts(accountIds: accountIds);

    final result = <UuidValue, BookingDate>{};
    for (final accountId in accountIds) {
      final account = state.accountById[accountId];
      if (account == null) continue;

      final earliestDate = earliestDates[accountId];
      if (earliestDate == null) {
        result[accountId] = BookingDate.on(account.createdAt);
      } else {
        // One day before earliest turnover
        result[accountId] = earliestDate.addDays(-1);
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
