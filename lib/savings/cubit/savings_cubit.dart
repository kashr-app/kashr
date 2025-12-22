import 'package:decimal/decimal.dart';
import 'package:finanalyzer/core/associate_by.dart';
import 'package:finanalyzer/core/extensions/map_extensios.dart';
import 'package:finanalyzer/core/status.dart';
import 'package:finanalyzer/savings/cubit/savings_state.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/services/savings_balance_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

/// Cubit for managing all savings state.
class SavingsCubit extends Cubit<SavingsState> {
  final SavingsRepository _savingsRepository;
  final SavingsBalanceService _savingsBalanceService;
  final Logger log;

  SavingsCubit(this._savingsRepository, this._savingsBalanceService, this.log)
    : super(const SavingsState());

  /// Load all savings and their related data.
  Future<void> loadAllSavings() async {
    try {
      emit(state.copyWith(status: Status.loading));

      final allSavings = await _savingsRepository.getAll();
      final savingsById = allSavings.associateBy((s) => s.id);

      // Load tags and balances for all savings
      final balancesBySavingsId = <UuidValue, Decimal>{};

      for (final savings in savingsById.values) {
        final balance = await _savingsBalanceService.calculateTotalBalance(
          savings,
        );
        balancesBySavingsId[savings.id] = balance;
      }

      emit(
        state.copyWith(
          status: Status.success,
          savingsById: savingsById,
          balancesBySavingsId: balancesBySavingsId,
        ),
      );
    } catch (e, stackTrace) {
      log.e('Failed to load savings', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to load savings: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _reloadSavings(UuidValue id) async {
    try {
      emit(state.copyWith(status: Status.loading));
      final savings = await _savingsRepository.getById(id);
      if (null == savings) {
        throw Exception('Could not find savings $id');
      }
      final balance = await _savingsBalanceService.calculateTotalBalance(
        savings,
      );
      emit(
        state.copyWith(
          status: Status.success,
          savingsById: {...state.savingsById, id: savings},
          balancesBySavingsId: {...state.balancesBySavingsId, id: balance},
        ),
      );
    } catch (e, stackTrace) {
      log.e('Failed to reload savings $id', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to reload savings $id: ${e.toString()}',
        ),
      );
    }
  }

  /// Create a new savings.
  Future<void> createSavings(Savings savings) async {
    try {
      emit(state.copyWith(status: Status.loading));
      await _savingsRepository.create(savings);
      await _reloadSavings(savings.id);
    } catch (e, stackTrace) {
      log.e('Failed to create savings', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to create savings: ${e.toString()}',
        ),
      );
    }
  }

  /// Update the savings goal.
  Future<void> updateGoal(
    UuidValue savingsId,
    Decimal? goalValue,
    String? goalUnit,
  ) async {
    try {
      emit(state.copyWith(status: Status.loading));
      final savings = state.savingsById[savingsId]!;
      final updatedSavings = savings.copyWith(
        goalValue: goalValue,
        goalUnit: goalUnit,
      );

      await _savingsRepository.update(updatedSavings);
      await _reloadSavings(savings.id);
    } catch (e, stackTrace) {
      log.e('Failed to update goal', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to update goal: ${e.toString()}',
        ),
      );
    }
  }

  /// Delete a savings by ID.
  Future<bool> deleteSavings(UuidValue savingsId) async {
    try {
      emit(state.copyWith(status: Status.loading));
      await _savingsRepository.delete(savingsId);
      emit(
        state.copyWith(
          status: Status.success,
          savingsById: state.savingsById.where((id, _) => id != savingsId),
          balancesBySavingsId: state.balancesBySavingsId.where(
            (id, _) => id != savingsId,
          ),
        ),
      );
      return true;
    } catch (e, stackTrace) {
      log.e('Failed to delete savings', error: e, stackTrace: stackTrace);
      emit(
        state.copyWith(
          status: Status.error,
          errorMessage: 'Failed to delete savings: ${e.toString()}',
        ),
      );
      return false;
    }
  }
}
