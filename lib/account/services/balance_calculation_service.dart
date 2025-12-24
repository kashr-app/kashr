import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/turnover/model/tag_turnover_repository.dart';
import 'package:kashr/turnover/model/turnover_repository.dart';

class BalanceCalculationService {
  final TurnoverRepository _turnoverRepository;
  final TagTurnoverRepository _tagTurnoverRepository;

  BalanceCalculationService(
    this._turnoverRepository,
    this._tagTurnoverRepository,
  );

  /// Calculate current balance for an account
  /// currentBalance = openingBalance + sum(all turnovers)
  Future<Decimal> calculateCurrentBalance(
    Account account, {
    DateTime? asOf,
  }) async {
    // Get all turnovers up to cutoff date
    final turnoverSum = await _turnoverRepository.sumTurnoversForAccount(
      accountId: account.id,
      endDateInclusive: asOf,
    );

    return account.openingBalance + turnoverSum;
  }

  /// Calculate projected balance as of a specific date
  /// (current balance + unmatched TagTurnovers up to that date).
  /// If asOf is null, projects for all time (includes all unmatched TagTurnovers).
  /// If asOf is provided, only includes unmatched TagTurnovers with booking dates
  /// before the asOf date.
  Future<Decimal> calculateProjectedBalance(
    Account account, {
    DateTime? asOf,
  }) async {
    final current = await calculateCurrentBalance(account, asOf: asOf);

    // TODO sum on DB instead
    // Get unmatched TagTurnovers (pending expenses) up to the asOf date
    final unmatched = await _tagTurnoverRepository.getUnmatched(
      accountId: account.id,
      endDate: asOf,
    );

    final unmatchedSum = unmatched
        .map((tt) => tt.amountValue)
        .fold(Decimal.zero, (sum, amount) => sum + amount);

    return current + unmatchedSum;
  }
}
