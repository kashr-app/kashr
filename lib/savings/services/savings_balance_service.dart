import 'package:decimal/decimal.dart';
import 'package:finanalyzer/savings/model/savings.dart';
import 'package:finanalyzer/savings/model/savings_repository.dart';
import 'package:finanalyzer/savings/model/savings_virtual_booking_repository.dart';
import 'package:finanalyzer/turnover/model/tag_turnover_repository.dart';
import 'package:uuid/uuid.dart';

/// Service for calculating savings balances
///
/// Balance formula:
/// Savings Balance = Sum(TagTurnover where tag = Savings.tag)
///                 + Sum(SavingsVirtualBooking where savingsId = Savings.id)
class SavingsBalanceService {
  final TagTurnoverRepository _tagTurnoverRepository;
  final SavingsVirtualBookingRepository _virtualBookingRepository;
  final SavingsRepository _savingsRepository;

  SavingsBalanceService(
    this._tagTurnoverRepository,
    this._virtualBookingRepository,
    this._savingsRepository,
  );

  /// Calculate total balance for a savings (across all accounts)
  Future<Decimal> calculateTotalBalance(Savings savings) async {
    final turnoversSum = await _tagTurnoverRepository.sumByTag(savings.tagId);
    final virtualSum = await _virtualBookingRepository.sumBySavingsId(
      savings.id!,
    );
    return turnoversSum + virtualSum;
  }

  /// Calculate savings balance for a specific account
  Future<Decimal> calculateBalanceForAccount(
    Savings savings,
    UuidValue accountId,
  ) async {
    final turnoverSum = await _tagTurnoverRepository.sumByTagAndAccount(
      savings.tagId,
      accountId,
    );
    final virtualSum = await _virtualBookingRepository.sumBySavingsIdAndAccount(
      savings.id!,
      accountId,
    );

    return turnoverSum + virtualSum;
  }

  /// Get savings breakdown per account for a specific savings
  Future<Map<UuidValue, Decimal>> getAccountBreakdown(Savings savings) async {
    // Get all accounts that have either TagTurnovers or VirtualBookings
    // for this savings
    final accountIds = {
      ...(await _tagTurnoverRepository.findAccountsByTagId(savings.tagId)),
      ...(await _virtualBookingRepository.findAccountsBySavings(savings.id!)),
    }.toList();

    final breakdown = <UuidValue, Decimal>{};

    for (final accountId in accountIds) {
      final balance = await calculateBalanceForAccount(savings, accountId);

      if (balance != Decimal.zero) {
        breakdown[accountId] = balance;
      }
    }

    return breakdown;
  }

  /// Get savings breakdown per savings for an account
  Future<Map<Savings, SavingsAccountInfo>> getSavingsBreakdownForAccount(
    UuidValue accountId,
  ) async {
    final allSavings = await _savingsRepository.getAll();

    final breakdown = <Savings, SavingsAccountInfo>{};
    for (final savings in allSavings) {
      final savingsForAccount = await calculateBalanceForAccount(
        savings,
        accountId,
      );

      if (savingsForAccount != Decimal.zero) {
        final total = await calculateTotalBalance(savings);
        breakdown[savings] = SavingsAccountInfo(
          totalSavings: total,
          savingsOnAccount: savingsForAccount,
        );
      }
    }

    return breakdown;
  }

  /// Get goal progress for a savings (if it has a goal)
  /// Returns null if no goal is set
  Future<double?> getGoalProgress(
    Savings savings,
    Decimal currentSavingsBalance,
  ) async {
    if (savings.goalValue == null) return null;
    if (savings.goalValue! == Decimal.zero) return null;

    final progress = (currentSavingsBalance / savings.goalValue!).toDouble();
    return progress;
  }
}

class SavingsAccountInfo {
  final Decimal totalSavings;
  final Decimal savingsOnAccount;

  SavingsAccountInfo({
    required this.totalSavings,
    required this.savingsOnAccount,
  });
}
