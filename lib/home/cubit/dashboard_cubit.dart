import 'package:decimal/decimal.dart';
import 'package:finanalyzer/comdirect/comdirect_service.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
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
        year: state.selectedPeriod.year,
        month: state.selectedPeriod.month,
      );

      final incomeTagSummaries = await _tagTurnoverRepository
          .getIncomeTagSummariesForMonth(
            year: state.selectedPeriod.year,
            month: state.selectedPeriod.month,
          );

      final expenseTagSummaries = await _tagTurnoverRepository
          .getExpenseTagSummariesForMonth(
            year: state.selectedPeriod.year,
            month: state.selectedPeriod.month,
          );

      final transferTagSummaries = await _tagTurnoverRepository
          .getTransferTagSummariesForMonth(
            year: state.selectedPeriod.year,
            month: state.selectedPeriod.month,
          );

      final unallocatedTurnovers = await _turnoverRepository
          .getUnallocatedTurnoversForMonth(
            year: state.selectedPeriod.year,
            month: state.selectedPeriod.month,
            limit: 1,
          );

      final unallocatedCount = await _turnoverRepository
          .countUnallocatedTurnoversForMonth(
            year: state.selectedPeriod.year,
            month: state.selectedPeriod.month,
          );

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

      // Sum of all transfer tags (inflow)
      final totalTransferIncome = transferTagSummaries
          .where((s) => s.totalAmount > Decimal.zero)
          .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.totalAmount);

      // Sum of all transfer tags (outflow)
      final totalTransferExpenses = transferTagSummaries
          .where((s) => s.totalAmount < Decimal.zero)
          .fold<Decimal>(Decimal.zero, (sum, s) => sum + s.totalAmount.abs());

      // Unallocated = total - allocated income/expense - transfers
      final unallocatedIncome =
          totalAllIncome - totalAllocatedIncome - totalTransferIncome;
      final unallocatedExpenses =
          totalAllExpenses - totalAllocatedExpenses - totalTransferExpenses;

      // Total income/expenses for cashflow = allocated + unallocated
      // (excludes transfers)
      final totalIncome = totalAllocatedIncome + unallocatedIncome;
      final totalExpenses = totalAllocatedExpenses + unallocatedExpenses;

      // Calculate total transfers accounting for internal vs external transfers
      // For internal transfers (between tracked accounts), the amount appears
      // twice (once negative, once positive), but we sum in abs() so we divide by 2.
      // For external transfers (to/from untracked accounts), they appear once.
      final sumWithSign = transferTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount,
      );
      final sumOfAbs = transferTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount.abs(),
      );
      // External amount = abs(sumWithSign) (net that doesn't cancel)
      // Internal amount = (sumOfAbs - abs(sumWithSign)) / 2 (counted twice)
      // Total amount: internal / 2 + external = (sumOfAbs + abs(sumWithSign)) / 2
      final totalTransfers =
          ((sumOfAbs + sumWithSign.abs()) / Decimal.fromInt(2)).toDecimal(
            scaleOnInfinitePrecision: 2,
          );

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
    emit(
      state.copyWith(
        selectedPeriod: yearMonth,
      ),
    );
    await loadMonthData();
  }
}
