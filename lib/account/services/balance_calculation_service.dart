import 'package:decimal/decimal.dart';
import 'package:kashr/account/model/account.dart';
import 'package:kashr/core/model/booking_date.dart';
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
  /// currentBalance = openingBalance + sum(turnovers booked before
  /// [endExclusive], or of all time when it is null)
  Future<Decimal> calculateCurrentBalance(
    Account account, {
    BookingDate? endExclusive,
  }) async {
    final turnoverSum = await _turnoverRepository.sumTurnoversForAccount(
      accountId: account.id,
      endExclusive: endExclusive,
    );

    return account.openingBalance + turnoverSum;
  }

  /// Calculate the balance projected to [endExclusive]
  /// (current balance + unmatched TagTurnovers booked before it).
  /// If [endExclusive] is null, projects for all time.
  Future<Decimal> calculateProjectedBalance(
    Account account, {
    BookingDate? endExclusive,
  }) async {
    final current = await calculateCurrentBalance(
      account,
      endExclusive: endExclusive,
    );

    // TODO sum on DB instead
    final unmatched = await _tagTurnoverRepository.getUnmatched(
      accountId: account.id,
      endExclusive: endExclusive,
    );

    final unmatchedSum = unmatched
        .map((tt) => tt.amountValue)
        .fold(Decimal.zero, (sum, amount) => sum + amount);

    return current + unmatchedSum;
  }
}
