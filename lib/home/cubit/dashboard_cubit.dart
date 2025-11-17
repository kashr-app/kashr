import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/home/cubit/dashboard_state.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

/// Cubit for managing the dashboard state.
class DashboardCubit extends Cubit<DashboardState> {
  final TurnoverRepository _turnoverRepository;
  final TagTurnoverRepository _tagTurnoverRepository;
  final _log = Logger();

  DashboardCubit(
    this._turnoverRepository,
    this._tagTurnoverRepository,
  ) : super(
          DashboardState(
            selectedYear: DateTime.now().year,
            selectedMonth: DateTime.now().month,
            totalIncome: Decimal.zero,
            totalExpenses: Decimal.zero,
            unallocatedIncome: Decimal.zero,
            unallocatedExpenses: Decimal.zero,
            unallocatedTurnovers: const [],
            unallocatedCount: 0,
          ),
        );

  /// Loads spending data for the currently selected month.
  Future<void> loadMonthData() async {
    emit(state.copyWith(status: Status.loading));
    try {
      final turnovers = await _turnoverRepository.getTurnoversForMonth(
        year: state.selectedYear,
        month: state.selectedMonth,
      );

      final incomeTagSummaries =
          await _tagTurnoverRepository.getIncomeTagSummariesForMonth(
        year: state.selectedYear,
        month: state.selectedMonth,
      );

      final expenseTagSummaries =
          await _tagTurnoverRepository.getExpenseTagSummariesForMonth(
        year: state.selectedYear,
        month: state.selectedMonth,
      );

      final unallocatedTurnovers =
          await _turnoverRepository.getUnallocatedTurnoversForMonth(
        year: state.selectedYear,
        month: state.selectedMonth,
        limit: 1,
      );

      final unallocatedCount =
          await _turnoverRepository.countUnallocatedTurnoversForMonth(
        year: state.selectedYear,
        month: state.selectedMonth,
      );

      // Separate income (positive) from expenses (negative)
      final totalIncome = turnovers
          .where((t) => t.amountValue > Decimal.zero)
          .fold<Decimal>(
            Decimal.zero,
            (sum, turnover) => sum + turnover.amountValue,
          );

      final totalExpenses = turnovers
          .where((t) => t.amountValue < Decimal.zero)
          .fold<Decimal>(
            Decimal.zero,
            (sum, turnover) => sum + turnover.amountValue,
          )
          .abs();

      // Sum of all tagged income
      final totalAllocatedIncome = incomeTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount.abs(),
      );

      // Sum of all tagged expenses
      final totalAllocatedExpenses = expenseTagSummaries.fold<Decimal>(
        Decimal.zero,
        (sum, summary) => sum + summary.totalAmount.abs(),
      );

      // Unallocated amounts
      final unallocatedIncome = totalIncome - totalAllocatedIncome;
      final unallocatedExpenses = totalExpenses - totalAllocatedExpenses;

      emit(
        state.copyWith(
          status: Status.success,
          totalIncome: totalIncome,
          totalExpenses: totalExpenses,
          unallocatedIncome: unallocatedIncome,
          unallocatedExpenses: unallocatedExpenses,
          incomeTagSummaries: incomeTagSummaries,
          expenseTagSummaries: expenseTagSummaries,
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
    final newMonth = state.selectedMonth - 1;
    if (newMonth < 1) {
      emit(
        state.copyWith(
          selectedYear: state.selectedYear - 1,
          selectedMonth: 12,
        ),
      );
    } else {
      emit(state.copyWith(selectedMonth: newMonth));
    }
    await loadMonthData();
  }

  /// Navigates to the next month.
  Future<void> nextMonth() async {
    final newMonth = state.selectedMonth + 1;
    if (newMonth > 12) {
      emit(
        state.copyWith(
          selectedYear: state.selectedYear + 1,
          selectedMonth: 1,
        ),
      );
    } else {
      emit(state.copyWith(selectedMonth: newMonth));
    }
    await loadMonthData();
  }

  /// Sets a specific month and year.
  Future<void> selectMonth(int year, int month) async {
    emit(state.copyWith(selectedYear: year, selectedMonth: month));
    await loadMonthData();
  }
}
