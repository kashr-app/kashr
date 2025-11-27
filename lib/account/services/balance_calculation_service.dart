import 'package:decimal/decimal.dart';
import 'package:finanalyzer/account/model/account.dart';
import 'package:finanalyzer/core/extensions/decimal_extensions.dart';
import 'package:finanalyzer/turnover/model/turnover_repository.dart';

class BalanceCalculationService {
  final TurnoverRepository _turnoverRepository;

  BalanceCalculationService(this._turnoverRepository);

  /// Calculate current balance for an account
  /// currentBalance = openingBalance + sum(all turnovers)
  Future<Decimal> calculateCurrentBalance(
    Account account, {
    DateTime? asOf,
  }) async {
    // Get all turnovers up to cutoff date
    final turnovers = await _turnoverRepository.getTurnoversForAccount(
      accountId: account.id!,
      upTo: asOf,
    );

    final turnoverSum = turnovers.sum((t) => t.amountValue);

    return account.openingBalance + turnoverSum;
  }
}

