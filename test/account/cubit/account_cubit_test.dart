// Fails until the date boundary bug is fixed; see test/README.md.
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashr/account/cubit/account_cubit.dart';
import 'package:kashr/core/status.dart';

import '../../helpers/test_app.dart';
import '../../helpers/test_database.dart';

void main() {
  useInMemoryDatabase();

  group('projectedBalances', () {
    test('counts what is booked on the last day of the month it projects to',
        () async {
      final app = TestApp();
      addTearDown(app.dispose);
      final account = await app.givenAccount(openingBalance: '100');
      final tag = await app.givenTag();
      await app.givenTurnover(account, bookedOn: midThisMonth, amount: '-20');
      await app.givenTurnover(
        account,
        bookedOn: lastDayOfThisMonth,
        amount: '-10',
      );
      await app.givenPending(
        account,
        tag: tag,
        bookedOn: midThisMonth,
        amount: '-3',
      );
      await app.givenPending(
        account,
        tag: tag,
        bookedOn: lastDayOfThisMonth,
        amount: '-5',
      );

      final cubit = AccountCubit(
        app.accountRepository,
        app.balanceService,
        app.turnoverRepository,
        app.log,
      );
      addTearDown(cubit.close);
      await cubit.loadAccounts();

      expect(cubit.state.status, Status.success);
      // The balance is the control: it filters by no date at all, so it is
      // right today. Only the projection, which cuts off at the end of the
      // month, loses what was booked on that very day.
      expect(
        (
          balance: cubit.state.balances[account.id],
          projectedToMonthEnd: cubit.state.projectedBalances[account.id],
        ),
        (
          balance: Decimal.parse('70'),
          projectedToMonthEnd: Decimal.parse('62'),
        ),
      );
    });
  });
}
