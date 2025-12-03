import 'package:decimal/decimal.dart';
import 'package:finanalyzer/comdirect/comdirect_service.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/turnover/model/tag.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_filter.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:finanalyzer/turnover/model/year_month.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jiffy/jiffy.dart';
import 'package:logger/logger.dart';

/// Cubit for managing the dashboard state.
class DashboardCubit extends Cubit<DashboardState> {
  final TurnoverRepository _turnoverRepository;
  final TagTurnoverRepository _tagTurnoverRepository;
  final _log = Logger();

  DashboardCubit(this._turnoverRepository, this._tagTurnoverRepository)
    : super(
        DashboardState(
          selectedPeriod: YearMonth.now(),
          totalIncome: Decimal.zero,
          totalExpenses: Decimal.zero,
          totalTransfers: Decimal.zero,
          unallocatedIncome: Decimal.zero,
          unallocatedExpenses: Decimal.zero,
          unallocatedTurnovers: const [],
          unallocatedCount: 0,
        ),
      );

  Future<void> downloadBankData(
    ComdirectService service,
    ScaffoldMessengerState messenger,
  ) async {
    void setBankDownloadStatus(Status status) {
      emit(state.copyWith(bankDownloadStatus: status));
    }

    setBankDownloadStatus(Status.loading);

    final start = state.selectedPeriod.toDateTime();
    final end = Jiffy.parseFromDateTime(start).endOf(Unit.month).dateTime;

    final result = await service.fetchAccountsAndTurnovers(
      minBookingDate: start,
      maxBookingDate: end,
    );
    switch (result.status) {
      case ResultStatus.success:
        final autoMatchMsg = result.autoMatchedCount > 0
            ? ' ${result.autoMatchedCount} expenses auto-matched.'
            : '';
        final unmatchedMsg = result.unmatchedTurnovers.isNotEmpty
            ? ' ${result.unmatchedTurnovers.length} transactions need review.'
            : '';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Data loaded successfully.$autoMatchMsg$unmatchedMsg',
            ),
          ),
        );
        setBankDownloadStatus(Status.success);
        loadMonthData();
      case ResultStatus.unauthed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Not authorized. Please try to login at the bank again.',
            ),
          ),
        );
        setBankDownloadStatus(Status.initial);
      case ResultStatus.otherError:
        messenger.showSnackBar(
          SnackBar(content: Text('There was an error: ${result.errorMessage}')),
        );
        setBankDownloadStatus(Status.error);
    }
  }

  /// Loads spending data for the currently selected month.
  Future<void> loadMonthData() async {
    emit(state.copyWith(status: Status.loading));
    try {
      final turnovers = await _turnoverRepository.getTurnoversForMonth(
        state.selectedPeriod,
      );

      final incomeTagSummaries = await _tagTurnoverRepository
          .getIncomeTagSummariesForMonth(state.selectedPeriod);

      final expenseTagSummaries = await _tagTurnoverRepository
          .getExpenseTagSummariesForMonth(state.selectedPeriod);

      final (
        transferTagSummaries,
        totalTransfers,
        totalTransferIncome,
        totalTransferExpenses,
      ) = await _loadTransfersSummary();

      final unallocatedTurnovers = await _turnoverRepository
          .getUnallocatedTurnoversForMonth(state.selectedPeriod, limit: 1);

      final unallocatedCount = await _turnoverRepository
          .countUnallocatedTurnoversForMonth(state.selectedPeriod);

      // Calculate total from all turnovers (including transfers)
      final totalAllIncome = turnovers
          .where((t) => t.amountValue > Decimal.zero)
          .fold<Decimal>(
            Decimal.zero,
            (sum, turnover) => sum + turnover.amountValue,
          );

      final totalAllExpenses = turnovers
          .where((t) => t.amountValue < Decimal.zero)
          .fold<Decimal>(
            Decimal.zero,
            (sum, turnover) => sum + turnover.amountValue,
          )
          .abs();

      // Sum of all tagged income (non-transfer)
      final totalAllocatedIncome = incomeTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount.abs(),
      );

      // Sum of all tagged expenses (non-transfer)
      final totalAllocatedExpenses = expenseTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount.abs(),
      );

      // Unallocated = total - allocated income/expense - transfers
      final unallocatedIncome =
          totalAllIncome - totalAllocatedIncome - totalTransferIncome;
      final unallocatedExpenses =
          totalAllExpenses - totalAllocatedExpenses - totalTransferExpenses;

      // Total income/expenses for cashflow = allocated + unallocated
      // (excludes transfers)
      final totalIncome = totalAllocatedIncome + unallocatedIncome;
      final totalExpenses = totalAllocatedExpenses + unallocatedExpenses;

      emit(
        state.copyWith(
          status: Status.success,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          totalTransfers: totalTransfers,
          unallocatedIncome: unallocatedIncome,
          unallocatedExpenses: unallocatedExpenses,
          incomeTagSummaries: incomeTagSummaries,
          expenseTagSummaries: expenseTagSummaries,
          transferTagSummaries: transferTagSummaries,
          unallocatedTurnovers: unallocatedTurnovers,
          unallocatedCount: unallocatedCount,
        ),
      );
    } catch (e, s) {
      _log.e('Failed to load month data', error: e, stackTrace: s);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load spending data: $e',
        ),
      );
    }
  }

  Future<(List<TagSummary>, Decimal, Decimal, Decimal)>
  _loadTransfersSummary() async {
    final transferTagSummariesBySign = await _tagTurnoverRepository
        .getTransferTagSummariesForMonth(state.selectedPeriod);

    // Sum of all transfer tags (inflow)
    final totalTransferIncome = transferTagSummariesBySign[TurnoverSign.income]!
        .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.totalAmount);

    // Sum of all transfer tags (outflow)
    final totalTransferExpenses =
        transferTagSummariesBySign[TurnoverSign.expense]!.fold<Decimal>(
          Decimal.zero,
          (sum, s) => sum + s.totalAmount.abs(),
        );

    /// TODO introduce transfer entity
    /// ... because THE CURRENT IMPLEMENTATION DOES NOT WORK in case there are external turnovers with different sign on a single tag
    ///   example:
    ///     investment +10
    ///     investment -600
    ///     => should be 610, but is (610+590)/2 = 600
    ///
    /// SOLUTION: only allow internal transfers
    /// * users can easily create an virtual account for the counterpart
    /// * we could also enforce that there is a counter part transaction
    ///     * store the transfer as entity that matches the in and out tag turnovers
    ///     * only allow transfer tags when creating transfers
    ///     * only allow non-transfer tags when creating normal transactions (or ask if user wants to switch to transfer mode)
    ///     * can end up with tag turnvoers tagged with transfer tag but not being associated to a transfer entity:
    ///       * user manually tags the turnover
    ///       * when toggling a tags "isTransfer" attribute, we could end up with tagTurnovers marked as transfer but without Transfer entity => we could ask the user to match them and support it with tooling for good UX
    ///     * Display only the "positive" sign tag turnover in turnovers list
    ///
    /// ALTERNATE SOLUTION: we must know for every transfer tagTurnover if it is internal or external
    /// i.e. we need for each transfer tagTurnover an entity to track that information.
    ///     e.g. as fromAccount and toAccount, where one can be null (external) or both are set (internal)
    ///
    ///
    /// BUGGY BEST EFFORTS SOLUTION THAT IS CURRENTLY IMPLEMENTED
    /// * supports internal turnovers
    /// * partially supports external turnovers (in case there are not multiple ones that cancel out each other)
    ///     example:
    ///       investment +10
    ///       investment -600
    ///       => should be 610, but is (610+590)/2 = 600

    // Transfers can be external (one side tracked only) or internal (between tracked accounts)
    //
    // For internal transfers (between tracked accounts), the amount appears
    // twice (once negative, once positive).
    // For external transfers (to/from untracked accounts), they appear once.
    //
    // => total amount of transfers = externals.sumAbs() + internals.sumAbs()/2
    //
    // Which we can calculate as:
    // sumWithSign = sum of all tagTurnovers amounts = net sum that doesn't canacel (ie. some external)
    // sumOfAbs = sum of all tagTurnovers absolute amounts
    // External amount = abs(sumWithSign) = net sum (of values with sign) that doesn cancel
    // Internal amount = (sumOfAbs - abs(sumWithSign)) / 2
    // Total amount: external + internal/2 = (sumOfAbs + abs(sumWithSign)) / 2
    //
    // We apply that logic per tag
    final transferTagSummaries = transferTagSummariesBySign.values
        .expand((it) => it)
        .fold(<Tag, TagSummary>{}, (all, it) {
          final ts1 = all[it.tag];
          if (ts1 == null) {
            // a tag can either occur once or twice (income, expense)
            // if it occurs only once, we just keep it with sign and later ensure to .abs() all values
            all[it.tag] = it; // keep sign initially
            return all;
          }
          // if tha tag occurs twice, we calculate the total abs value according to the above formula.
          final ts2 = it;

          final sumWithSign = ts1.totalAmount + ts2.totalAmount;
          final sumOfAbs = ts1.totalAmount.abs() + ts2.totalAmount.abs();
          final totalAmount =
              ((sumOfAbs + sumWithSign.abs()) / Decimal.fromInt(2)).toDecimal(
                scaleOnInfinitePrecision: 2,
              );

          all[it.tag] = it.copyWith(totalAmount: totalAmount);
          return all;
        })
        .values
        .map((it) => it.copyWith(totalAmount: it.totalAmount.abs()))
        .toList();

    final totalTransfers = transferTagSummaries.fold<Decimal>(
      Decimal.zero,
      (sum, it) => sum + it.totalAmount.abs(),
    );
    return (
      transferTagSummaries,
      totalTransfers,
      totalTransferIncome,
      totalTransferExpenses,
    );
  }

  /// Navigates to the previous month.
  Future<void> previousMonth() async {
    final currentDate = state.selectedPeriod.toDateTime();
    final previousDate = DateTime(currentDate.year, currentDate.month - 1);
    emit(
      state.copyWith(
        selectedPeriod: YearMonth(
          year: previousDate.year,
          month: previousDate.month,
        ),
      ),
    );
    await loadMonthData();
  }

  /// Navigates to the next month.
  Future<void> nextMonth() async {
    final currentDate = state.selectedPeriod.toDateTime();
    final nextDate = DateTime(currentDate.year, currentDate.month + 1);
    emit(
      state.copyWith(
        selectedPeriod: YearMonth(year: nextDate.year, month: nextDate.month),
      ),
    );
    await loadMonthData();
  }

  /// Sets a specific month and year.
  Future<void> selectMonth(YearMonth yearMonth) async {
    emit(state.copyWith(selectedPeriod: yearMonth));
    await loadMonthData();
  }
}
